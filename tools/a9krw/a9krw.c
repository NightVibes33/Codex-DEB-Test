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
typedef uint64_t (*jb_u64_func_t)(void);
typedef void (*jb_flush_tlb_t)(void);

static void *g_jb;

#define S8000_DVFS_BASE 0x202220000ULL
#define DVFS_CMD         0x20ULL
#define DVFS_LAST_CHG    0x38ULL
#define DVFS_STATUS      0x50ULL
#define DVFS_PLL_STATUS  0xc0ULL
#define DVFS_PLL_FACTOR  0xc8ULL

/* Matches Dopamine/XNU arm64 PTE encodings. */
#define PTE_NON_GLOBAL       (1ULL << 11)
#define PTE_AF               (1ULL << 10)
#define PTE_LEVEL3_TYPE      0x3ULL
#define PTE_PNX              0x0020000000000000ULL
#define PTE_NX               0x0040000000000000ULL
#define PTE_KRW_URW_PERM     0x0060000000000040ULL
#define PTE_ATTRIDX_DISABLE  (3ULL << 2) /* XNU device memory, no cache/no buffer */
#define PTE_DEVICE_RW_USER   (PTE_KRW_URW_PERM | PTE_NON_GLOBAL | PTE_AF | PTE_LEVEL3_TYPE | PTE_PNX | PTE_NX | PTE_ATTRIDX_DISABLE)

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
    if (!init) {
        fprintf(stderr, "ERROR=missing jbclient_initialize_primitives_internal\n");
        return ENOSYS;
    }

    stage("PTE_INIT_BEGIN");
    int rc = init(true);
    printf("PTE_INIT_RC=%d\n", rc);
    if (rc != 0) return rc;
    stage("PTE_INIT_OK");
    return 0;
}

struct pte_layout {
    uint64_t page_size;
    uint64_t l1_block_size;
    uint64_t l1_block_count;
    uintptr_t magic_pt_addr;
    volatile uint64_t *magic_pt;
    jb_flush_tlb_t flush_tlb;
};

static int get_pte_layout(struct pte_layout *o, bool require_empty_slot2) {
    if (!g_jb || !o) return EINVAL;
    memset(o, 0, sizeof(*o));

    jb_u64_func_t get_page_size = (jb_u64_func_t)dlsym(g_jb, "get_vm_real_kernel_page_size");
    jb_u64_func_t get_l1_size = (jb_u64_func_t)dlsym(g_jb, "get_l1_block_size");
    jb_u64_func_t get_l1_count = (jb_u64_func_t)dlsym(g_jb, "get_l1_block_count");
    o->flush_tlb = (jb_flush_tlb_t)dlsym(g_jb, "flush_tlb");
    if (!get_page_size || !get_l1_size || !get_l1_count || !o->flush_tlb) {
        fprintf(stderr, "ERROR=missing PTE layout symbols page=%d l1size=%d l1count=%d flush=%d\n",
                !!get_page_size, !!get_l1_size, !!get_l1_count, !!o->flush_tlb);
        return ENOSYS;
    }

    o->page_size = get_page_size();
    o->l1_block_size = get_l1_size();
    o->l1_block_count = get_l1_count();
    if (o->page_size != 0x4000ULL) {
        fprintf(stderr, "REFUSE=unexpected kernel page size 0x%llx\n", (unsigned long long)o->page_size);
        return ERANGE;
    }
    if (o->l1_block_size == 0 || o->l1_block_count < 4 || o->l1_block_count > 64) {
        fprintf(stderr, "REFUSE=unexpected L1 geometry size=0x%llx count=%llu\n",
                (unsigned long long)o->l1_block_size, (unsigned long long)o->l1_block_count);
        return ERANGE;
    }
    __uint128_t magic128 = (__uint128_t)o->l1_block_size * (__uint128_t)(o->l1_block_count - 3);
    if (magic128 > UINTPTR_MAX) return EOVERFLOW;
    o->magic_pt_addr = (uintptr_t)magic128;
    o->magic_pt = (volatile uint64_t *)o->magic_pt_addr;

    /* Slots 0/1 are owned by Dopamine; slot 2 must be unused before we borrow it. */
    uint64_t e0 = o->magic_pt[0];
    uint64_t e1 = o->magic_pt[1];
    uint64_t e2 = o->magic_pt[2];
    printf("PTE_LAYOUT page=0x%llx l1_size=0x%llx l1_count=%llu magic=0x%llx entry0=0x%016llx entry1=0x%016llx entry2=0x%016llx\n",
           (unsigned long long)o->page_size,
           (unsigned long long)o->l1_block_size,
           (unsigned long long)o->l1_block_count,
           (unsigned long long)o->magic_pt_addr,
           (unsigned long long)e0,
           (unsigned long long)e1,
           (unsigned long long)e2);
    fflush(stdout);

    if (require_empty_slot2 && e2 != 0) {
        fprintf(stderr, "REFUSE=magic PTE slot2 already in use\n");
        return EBUSY;
    }
    return 0;
}

static inline void full_barrier(void) {
    __asm__ volatile("dmb sy" ::: "memory");
}

static int pte_layout_probe(void) {
    struct pte_layout l;
    stage("PTE_LAYOUT_BEGIN");
    int rc = get_pte_layout(&l, true);
    if (rc) return rc;
    stage("PTE_LAYOUT_OK");
    printf("RESULT=PTE_LAYOUT_OK\n");
    return 0;
}

static bool allowed_read_offset(uint64_t off) {
    return off == DVFS_CMD || off == DVFS_LAST_CHG || off == DVFS_STATUS ||
           off == DVFS_PLL_STATUS || off == DVFS_PLL_FACTOR;
}

static int device_mmio_read32(uint64_t pa, uint32_t *value) {
    if (!value) return EINVAL;
    struct pte_layout l;
    int rc = get_pte_layout(&l, true);
    if (rc) return rc;

    uint64_t page_mask = l.page_size - 1;
    uint64_t page_pa = pa & ~page_mask;
    uint64_t page_off = pa & page_mask;
    if (page_off + sizeof(uint32_t) > l.page_size) return EINVAL;

    const unsigned slot = 2;
    volatile uint64_t *entry = &l.magic_pt[slot];
    uintptr_t mapped_page = l.magic_pt_addr + ((uintptr_t)slot * (uintptr_t)l.page_size);
    volatile uint32_t *mapped_reg = (volatile uint32_t *)(mapped_page + (uintptr_t)page_off);
    uint64_t pte = page_pa | PTE_DEVICE_RW_USER;

    printf("DEVICE_MAP_PREP pa=0x%016llx page=0x%016llx off=0x%llx slot=%u pte=0x%016llx attridx=3 sh=none access=read32\n",
           (unsigned long long)pa,
           (unsigned long long)page_pa,
           (unsigned long long)page_off,
           slot,
           (unsigned long long)pte);
    fflush(stdout);

    *entry = pte;
    full_barrier();
    l.flush_tlb();
    full_barrier();

    stage("DEVICE_MMIO_READ32_ARMED");
    printf("DEVICE_READ_BEGIN pa=0x%016llx\n", (unsigned long long)pa);
    fflush(stdout);

    uint32_t v = *mapped_reg;
    full_barrier();

    printf("DEVICE_READ_RETURNED pa=0x%016llx value=0x%08x\n", (unsigned long long)pa, v);
    fflush(stdout);

    *entry = 0;
    full_barrier();
    l.flush_tlb();
    full_barrier();

    *value = v;
    stage("DEVICE_MMIO_READ32_OK");
    return 0;
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IOLBF, 0);
    setvbuf(stderr, NULL, _IOLBF, 0);
    printf("A9KRW_START pid=%d euid=%d\n", getpid(), geteuid());
    if (geteuid() != 0) {
        fprintf(stderr, "ERROR=root required\n");
        return 2;
    }

    int rc = load_single_pte();
    if (rc) {
        printf("RESULT=INIT_FAILED rc=%d\n", rc);
        return rc;
    }

    if (argc >= 2 && !strcmp(argv[1], "init-only")) {
        printf("RESULT=SINGLE_PTE_INIT_OK\n");
        return 0;
    }

    if (argc >= 2 && !strcmp(argv[1], "pte-layout")) {
        rc = pte_layout_probe();
        if (rc) printf("RESULT=PTE_LAYOUT_FAILED rc=%d\n", rc);
        return rc;
    }

    if (argc >= 2 && !strcmp(argv[1], "mmio-device-read32")) {
        uint64_t off = DVFS_CMD;
        if (argc >= 3) off = strtoull(argv[2], NULL, 0);
        if (!allowed_read_offset(off)) {
            fprintf(stderr, "REFUSE=offset 0x%llx is not in read-only DVFS allowlist\n", (unsigned long long)off);
            return EINVAL;
        }
        printf("MODE=DEVICE_MMIO_READ32 offset=0x%llx KERNEL_WRITES=0 CLOCK_WRITES=0 VOLTAGE_WRITES=0\n",
               (unsigned long long)off);
        uint32_t value = 0;
        rc = device_mmio_read32(S8000_DVFS_BASE + off, &value);
        if (rc) {
            printf("RESULT=DEVICE_MMIO_READ32_FAILED rc=%d\n", rc);
            return rc;
        }
        printf("RESULT=DEVICE_MMIO_READ32_OK offset=0x%llx value=0x%08x\n",
               (unsigned long long)off, value);
        return 0;
    }

    if (argc >= 2 && (!strcmp(argv[1], "probe") ||
                      !strcmp(argv[1], "same-state-write") ||
                      !strcmp(argv[1], "pulse-stock-max"))) {
        fprintf(stderr, "REFUSE=legacy generic physrw MMIO mode disabled after confirmed reboot\n");
        printf("RESULT=LEGACY_MMIO_DISABLED\n");
        return ENOTSUP;
    }

    fprintf(stderr, "usage: %s [init-only|pte-layout|mmio-device-read32 [offset]]\n", argv[0]);
    return 64;
}
