#include <dlfcn.h>
#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef int (*jb_init_internal_t)(bool physrwPTE);
typedef int (*jb_physreadbuf_t)(uint64_t physaddr, void *output, size_t size);
typedef int (*jb_physwritebuf_t)(uint64_t physaddr, const void *input, size_t size);

typedef int (*jb_kreadbuf_t)(uint64_t kaddr, void *output, size_t size);

typedef int (*jb_kbase_func_t)(uint64_t *addr);

static void *g_jb;
static jb_physreadbuf_t g_physread;
static jb_physwritebuf_t g_physwrite;

#define S8000_DVFS_BASE 0x202220000ULL
#define DVFS_CMD         0x20ULL
#define DVFS_LAST_CHG    0x38ULL
#define DVFS_STATUS      0x50ULL
#define DVFS_PLL_STATUS  0xc0ULL
#define DVFS_PLL_FACTOR  0xc8ULL
#define CMD_BUSY         (1ULL << 31)
#define CMD_SET          (1ULL << 25)
#define CMD_PS1_MASK     0x1fULL
#define CMD_PS2_MASK     (0xfULL << 12)

static void stage(const char *s) {
    printf("STAGE=%s\n", s);
    fflush(stdout);
}

static int load_single_pte(void) {
    stage("DLOPEN_BEGIN");
    g_jb = dlopen("/var/jb/basebin/libjailbreak.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!g_jb) {
        fprintf(stderr, "ERROR=dlopen libjailbreak: %s\n", dlerror());
        return ENOENT;
    }
    stage("DLOPEN_OK");

    jb_init_internal_t init = (jb_init_internal_t)dlsym(g_jb, "jbclient_initialize_primitives_internal");
    g_physread = (jb_physreadbuf_t)dlsym(g_jb, "physreadbuf");
    g_physwrite = (jb_physwritebuf_t)dlsym(g_jb, "physwritebuf");
    if (!init || !g_physread || !g_physwrite) {
        fprintf(stderr, "ERROR=missing libjailbreak symbols init=%p read=%p write=%p\n", init, g_physread, g_physwrite);
        return ENOSYS;
    }
    printf("LIBJAILBREAK_SYMBOLS=OK init=%p read=%p write=%p\n", init, g_physread, g_physwrite);
    stage("PTE_INIT_BEGIN");
    int rc = init(true);
    printf("PTE_INIT_RC=%d\n", rc);
    if (rc != 0) return rc;
    stage("PTE_INIT_OK");
    return 0;
}

static int pr64(uint64_t pa, uint64_t *v) {
    if (!g_physread) return ENOTSUP;
    *v = 0;
    return g_physread(pa, v, sizeof(*v));
}

static int pw64(uint64_t pa, uint64_t v) {
    if (!g_physwrite) return ENOTSUP;
    return g_physwrite(pa, &v, sizeof(v));
}

static int dump_once(const char *tag) {
    uint64_t cmd=0, last=0, status=0, pll=0, factor=0;
    int a=pr64(S8000_DVFS_BASE+DVFS_CMD,&cmd);
    int b=pr64(S8000_DVFS_BASE+DVFS_LAST_CHG,&last);
    int c=pr64(S8000_DVFS_BASE+DVFS_STATUS,&status);
    int d=pr64(S8000_DVFS_BASE+DVFS_PLL_STATUS,&pll);
    int e=pr64(S8000_DVFS_BASE+DVFS_PLL_FACTOR,&factor);
    unsigned cur=(unsigned)((status>>4)&0xf), tgt=(unsigned)(status&0xf);
    unsigned ps1=(unsigned)(cmd&0x1f), ps2=(unsigned)((cmd>>12)&0xf);
    printf("%s cmd_rc=%d cmd=0x%016" PRIx64 " ps1=%u ps2=%u busy=%u status_rc=%d status=0x%016" PRIx64 " cur=%u tgt=%u last_rc=%d last=0x%016" PRIx64 " pll_rc=%d pll=0x%016" PRIx64 " factor_rc=%d factor=0x%016" PRIx64 "\n",
           tag,a,cmd,ps1,ps2,(unsigned)((cmd>>31)&1),c,status,cur,tgt,b,last,d,pll,e,factor);
    fflush(stdout);
    if (a || b || c || d || e) return EIO;
    if (ps1 > 8 || ps2 > 8 || cur > 8 || tgt > 8) return ERANGE;
    return 0;
}

static int wait_not_busy(uint64_t *cmd_out) {
    for (int i=0;i<250;i++) {
        uint64_t cmd=0;
        int rc=pr64(S8000_DVFS_BASE+DVFS_CMD,&cmd);
        if (rc) return rc;
        if (!(cmd & CMD_BUSY)) { *cmd_out=cmd; return 0; }
        usleep(2000);
    }
    return ETIMEDOUT;
}

static uint64_t command_for_pstate(uint64_t cmd, unsigned ps) {
    cmd &= ~(CMD_PS1_MASK | CMD_PS2_MASK);
    cmd |= ((uint64_t)ps & 0x1fULL);
    cmd |= (((uint64_t)ps & 0xfULL) << 12);
    cmd |= CMD_SET;
    return cmd;
}

static int same_state_write(void) {
    uint64_t cmd=0;
    int rc=wait_not_busy(&cmd);
    if (rc) return rc;
    unsigned ps=(unsigned)(cmd & 0x1f);
    unsigned ps2=(unsigned)((cmd>>12)&0xf);
    if (ps > 8 || ps2 > 8) {
        fprintf(stderr,"REFUSE=unexpected command pstate ps1=%u ps2=%u\n",ps,ps2);
        return ERANGE;
    }
    uint64_t out=command_for_pstate(cmd,ps);
    printf("SAME_STATE_WRITE target=%u original_cmd=0x%016" PRIx64 " write_cmd=0x%016" PRIx64 "\n",ps,cmd,out);
    rc=pw64(S8000_DVFS_BASE+DVFS_CMD,out);
    printf("PHYSWRITE_RC=%d\n",rc);
    fflush(stdout);
    if (rc) return rc;
    usleep(30000);
    return dump_once("AFTER_SAME");
}

static int pulse_stock_max(unsigned duration_ms) {
    if (duration_ms > 1000) {
        fprintf(stderr,"REFUSE=duration too long\n");
        return EINVAL;
    }
    uint64_t original=0;
    int rc=wait_not_busy(&original);
    if (rc) return rc;
    unsigned orig=(unsigned)(original & 0x1f);
    if (orig > 8) {
        fprintf(stderr,"REFUSE=unexpected original pstate %u\n",orig);
        return ERANGE;
    }
    printf("PULSE_STOCK_MAX=8 duration_ms=%u rollback_target=%u\n",duration_ms,orig);
    fflush(stdout);
    uint64_t maxcmd=command_for_pstate(original,8);
    rc=pw64(S8000_DVFS_BASE+DVFS_CMD,maxcmd);
    printf("MAX_WRITE_RC=%d\n",rc);
    fflush(stdout);
    if (rc) return rc;
    for (unsigned elapsed=0; elapsed<duration_ms; elapsed+=25) {
        usleep(25000);
        rc=dump_once("PULSE");
        if (rc) break;
    }

    uint64_t now=0;
    int waitrc=wait_not_busy(&now);
    if (waitrc) {
        fprintf(stderr,"ROLLBACK_WAIT_RC=%d\n",waitrc);
        return waitrc;
    }
    uint64_t rollback=command_for_pstate(now,orig);
    int rr=pw64(S8000_DVFS_BASE+DVFS_CMD,rollback);
    printf("ROLLBACK_WRITE_RC=%d target=%u\n",rr,orig);
    fflush(stdout);
    usleep(50000);
    int dr=dump_once("AFTER_ROLLBACK");
    return rr ? rr : (rc ? rc : dr);
}

int main(int argc, char **argv) {
    setvbuf(stdout,NULL,_IOLBF,0);
    setvbuf(stderr,NULL,_IOLBF,0);
    printf("A9KRW_START pid=%d euid=%d\n",getpid(),geteuid());
    if (geteuid()!=0) { fprintf(stderr,"ERROR=root required\n"); return 2; }

    int rc=load_single_pte();
    if (rc) {
        printf("RESULT=INIT_FAILED rc=%d\n",rc);
        return rc;
    }

    if (argc >= 2 && !strcmp(argv[1],"init-only")) {
        printf("RESULT=SINGLE_PTE_INIT_OK\n");
        return 0;
    }

    if (argc < 2 || !strcmp(argv[1],"probe")) {
        printf("MODE=READ_ONLY\n");
        stage("MMIO_PROBE_BEGIN");
        for (int i=0;i<12;i++) {
            rc=dump_once("PROBE");
            if (rc) {
                printf("RESULT=MMIO_PROBE_FAILED rc=%d\n",rc);
                return rc;
            }
            usleep(50000);
        }
        stage("MMIO_PROBE_OK");
        printf("RESULT=READ_ONLY_COMPLETE\n");
        return 0;
    }
    if (!strcmp(argv[1],"same-state-write")) {
        printf("MODE=SAME_STATE_WRITE_ONLY\n");
        rc=same_state_write();
        printf("RESULT=SAME_STATE_%s rc=%d\n",rc?"FAILED":"OK",rc);
        return rc;
    }
    if (!strcmp(argv[1],"pulse-stock-max")) {
        unsigned ms=250;
        if (argc>=3) ms=(unsigned)strtoul(argv[2],NULL,0);
        rc=pulse_stock_max(ms);
        printf("RESULT=STOCK_P8_PULSE_%s rc=%d\n",rc?"FAILED":"OK",rc);
        return rc;
    }
    fprintf(stderr,"usage: %s [init-only|probe|same-state-write|pulse-stock-max [ms]]\n",argv[0]);
    return 64;
}
