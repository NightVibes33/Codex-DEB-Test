#include <dlfcn.h>
#include <errno.h>
#include <glob.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef int (*krw_kbase_func_t)(uint64_t *addr);
typedef int (*krw_kread_func_t)(uint64_t from, void *to, size_t len);
typedef int (*krw_kwrite_func_t)(void *from, uint64_t to, size_t len);
typedef int (*krw_kmalloc_func_t)(uint64_t *addr, size_t size);
typedef int (*krw_kdealloc_func_t)(uint64_t addr, size_t size);
typedef int (*krw_kcall_func_t)(uint64_t func, size_t argc, const uint64_t *argv, uint64_t *ret);
typedef int (*krw_physread_func_t)(uint64_t from, void *to, size_t len, uint8_t granule);
typedef int (*krw_physwrite_func_t)(void *from, uint64_t to, size_t len, uint8_t granule);

struct krw_handlers_s {
    uint64_t version;
    krw_kbase_func_t kbase;
    krw_kread_func_t kread;
    krw_kwrite_func_t kwrite;
    krw_kmalloc_func_t kmalloc;
    krw_kdealloc_func_t kdealloc;
    krw_kcall_func_t kcall;
    krw_physread_func_t physread;
    krw_physwrite_func_t physwrite;
};
typedef struct krw_handlers_s *krw_handlers_t;
typedef int (*krw_plugin_initializer_t)(krw_handlers_t handlers);

static void *g_plugin;
static struct krw_handlers_s g_h;

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

static int load_krw(void) {
    glob_t gl = {0};
    const char *patterns[] = {
        "/var/jb/usr/lib/libkrw/*.dylib",
        "/usr/lib/libkrw/*.dylib",
    };
    memset(&g_h, 0, sizeof(g_h));
    g_h.version = 0;

    for (size_t p = 0; p < sizeof(patterns)/sizeof(patterns[0]); p++) {
        memset(&gl, 0, sizeof(gl));
        if (glob(patterns[p], 0, NULL, &gl) != 0) continue;
        for (size_t i = 0; i < gl.gl_pathc; i++) {
            void *h = dlopen(gl.gl_pathv[i], RTLD_NOW | RTLD_LOCAL);
            if (!h) continue;
            krw_plugin_initializer_t init = (krw_plugin_initializer_t)dlsym(h, "krw_initializer");
            krw_plugin_initializer_t kinit = (krw_plugin_initializer_t)dlsym(h, "kcall_initializer");
            if (!init) { dlclose(h); continue; }
            struct krw_handlers_s cand = {0};
            cand.version = 0;
            int rc = init(&cand);
            if (rc != 0) { dlclose(h); continue; }
            if (kinit) (void)kinit(&cand);
            if (cand.physread) {
                g_h = cand;
                g_plugin = h;
                printf("KRW_PLUGIN=%s\n", gl.gl_pathv[i]);
                globfree(&gl);
                return 0;
            }
            dlclose(h);
        }
        globfree(&gl);
    }
    fprintf(stderr, "ERROR=no usable Dopamine/libkrw provider\n");
    return ENOTSUP;
}

static int pr64(uint64_t pa, uint64_t *v) {
    if (!g_h.physread) return ENOTSUP;
    *v = 0;
    return g_h.physread(pa, v, sizeof(*v), 8);
}

static int pw64(uint64_t pa, uint64_t v) {
    if (!g_h.physwrite) return ENOTSUP;
    return g_h.physwrite(&v, pa, sizeof(v), 8);
}

static void dump_once(const char *tag) {
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
    usleep(30000);
    dump_once("AFTER_SAME");
    return rc;
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
    uint64_t maxcmd=command_for_pstate(original,8);
    rc=pw64(S8000_DVFS_BASE+DVFS_CMD,maxcmd);
    printf("MAX_WRITE_RC=%d\n",rc);
    if (rc) return rc;
    for (unsigned elapsed=0; elapsed<duration_ms; elapsed+=25) {
        usleep(25000);
        dump_once("PULSE");
    }
    uint64_t now=0;
    rc=wait_not_busy(&now);
    if (rc) return rc;
    uint64_t rollback=command_for_pstate(now,orig);
    int rr=pw64(S8000_DVFS_BASE+DVFS_CMD,rollback);
    printf("ROLLBACK_WRITE_RC=%d target=%u\n",rr,orig);
    usleep(50000);
    dump_once("AFTER_ROLLBACK");
    return rr;
}

int main(int argc, char **argv) {
    setvbuf(stdout,NULL,_IOLBF,0);
    if (geteuid()!=0) { fprintf(stderr,"ERROR=root required\n"); return 2; }
    int rc=load_krw();
    if (rc) return rc;
    uint64_t kb=0;
    if (g_h.kbase) printf("KBASE_RC=%d KBASE=0x%016" PRIx64 "\n",g_h.kbase(&kb),kb);
    if (argc < 2 || !strcmp(argv[1],"probe")) {
        printf("MODE=READ_ONLY\n");
        for (int i=0;i<12;i++) { dump_once("PROBE"); usleep(50000); }
        return 0;
    }
    if (!strcmp(argv[1],"same-state-write")) {
        printf("MODE=SAME_STATE_WRITE_ONLY\n");
        return same_state_write();
    }
    if (!strcmp(argv[1],"pulse-stock-max")) {
        unsigned ms=250;
        if (argc>=3) ms=(unsigned)strtoul(argv[2],NULL,0);
        return pulse_stock_max(ms);
    }
    fprintf(stderr,"usage: %s [probe|same-state-write|pulse-stock-max [ms]]\n",argv[0]);
    return 64;
}
