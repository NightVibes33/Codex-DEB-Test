#ifndef VPHONE_RUNTIME_CORE_H
#define VPHONE_RUNTIME_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define VP_GUEST_PAGE_SHIFT 14u
#define VP_GUEST_PAGE_SIZE  (1u << VP_GUEST_PAGE_SHIFT)
#define VP_RUNTIME_ABI_VERSION 3u
#define VP_DEFAULT_INSTRUCTION_BUDGET UINT64_C(1000000)

typedef enum {
    VP_STATUS_OK = 0,
    VP_STATUS_INVALID_ARGUMENT = 1,
    VP_STATUS_OUT_OF_MEMORY = 2,
    VP_STATUS_ADDRESS_OUT_OF_RANGE = 3,
    VP_STATUS_BACKEND_UNAVAILABLE = 4,
    VP_STATUS_INVALID_STATE = 5,
    VP_STATUS_EXECUTION_FAULT = 6,
    VP_STATUS_BUDGET_EXHAUSTED = 7,
    VP_STATUS_GUEST_WAITING = 8,
} VPStatus;

typedef enum {
    VP_RUNTIME_CREATED = 0,
    VP_RUNTIME_READY = 1,
    VP_RUNTIME_RUNNING = 2,
    VP_RUNTIME_STOPPED = 3,
    VP_RUNTIME_FAILED = 4,
    VP_RUNTIME_WAITING = 5,
    VP_RUNTIME_PAUSED = 6,
} VPRuntimeState;

typedef struct {
    uint32_t cpu_count;
    uint64_t guest_physical_memory_size;
    uint32_t screen_width;
    uint32_t screen_height;
    uint32_t pixels_per_inch;
    double screen_scale;
} VPMachineConfig;

typedef struct VPRuntime VPRuntime;

typedef void (*VPSerialCallback)(const uint8_t *bytes, size_t length, void *context);
typedef VPStatus (*VPSyscallHandler)(
    VPRuntime *runtime,
    uint64_t number,
    const uint64_t args[8],
    uint64_t *result,
    void *context
);

/* One Apple boot artifact and the guest-physical address where it is staged. */
typedef struct {
    const void *bytes;
    size_t length;
    uint64_t guest_address;
} VPBootImage;

/*
 * Physical layout for the vphone-style Apple boot chain. Images may be omitted
 * by setting bytes=NULL and length=0, but the selected entry image must exist.
 * This API only stages user-supplied Apple artifacts; it ships no Apple bytes.
 */
typedef struct {
    VPBootImage iboot;
    VPBootImage kernelcache;
    VPBootImage device_tree;
    VPBootImage trust_cache;
    VPBootImage ramdisk;
    uint64_t entry_address;
} VPBootImageLayout;

uint32_t vp_runtime_abi_version(void);
VPRuntime *vp_runtime_create(const VPMachineConfig *config);
void vp_runtime_destroy(VPRuntime *runtime);
VPRuntimeState vp_runtime_state(const VPRuntime *runtime);
const VPMachineConfig *vp_runtime_config(const VPRuntime *runtime);
void vp_runtime_set_serial_callback(VPRuntime *runtime, VPSerialCallback callback, void *context);
void vp_runtime_set_syscall_handler(VPRuntime *runtime, VPSyscallHandler handler, void *context);
VPStatus vp_runtime_dispatch_syscall(
    VPRuntime *runtime,
    uint64_t number,
    const uint64_t args[8],
    uint64_t *result
);

/*
 * Sparse guest-physical memory. The runtime presents the full guest address
 * range without allocating the full iPhone RAM size in the host process.
 * Unwritten pages read as zero and are committed only on first write.
 */
VPStatus vp_runtime_memory_read(VPRuntime *runtime, uint64_t guest_address, void *dst, size_t length);
VPStatus vp_runtime_memory_write(VPRuntime *runtime, uint64_t guest_address, const void *src, size_t length);
uint64_t vp_runtime_committed_bytes(const VPRuntime *runtime);
uint64_t vp_runtime_committed_pages(const VPRuntime *runtime);

/*
 * Atomically validates and stages an Apple guest boot set into sparse physical
 * memory, then selects entry_address as the next reset vector. This is the
 * native bridge used by the iOS host before the CPU executor begins.
 */
VPStatus vp_runtime_stage_boot_images(VPRuntime *runtime, const VPBootImageLayout *layout);

/* Custom interpreter execution configuration. */
VPStatus vp_runtime_set_boot_vector(VPRuntime *runtime, uint64_t guest_address);
void vp_runtime_set_instruction_budget(VPRuntime *runtime, uint64_t budget);
uint64_t vp_runtime_boot_vector(const VPRuntime *runtime);
uint64_t vp_runtime_instructions_retired(const VPRuntime *runtime);

/*
 * Runs or resumes guest AArch64 directly through VPhoneAArch64. CPU state is
 * persistent across instruction-budget yields and WFI/WFE waits. No generic
 * emulator process, companion computer, remote JIT service or macOS
 * Virtualization.framework is required.
 */
VPStatus vp_runtime_boot(VPRuntime *runtime);

/* Wake a guest stopped in WFI/WFE; the next vp_runtime_boot() resumes at its saved PC. */
VPStatus vp_runtime_signal_event(VPRuntime *runtime);
VPStatus vp_runtime_stop(VPRuntime *runtime);

#ifdef __cplusplus
}
#endif

#endif
