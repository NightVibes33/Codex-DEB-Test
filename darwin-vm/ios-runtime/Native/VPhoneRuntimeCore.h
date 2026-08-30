#ifndef VPHONE_RUNTIME_CORE_H
#define VPHONE_RUNTIME_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define VP_GUEST_PAGE_SHIFT 14u
#define VP_GUEST_PAGE_SIZE  (1u << VP_GUEST_PAGE_SHIFT)
#define VP_RUNTIME_ABI_VERSION 1u

typedef enum {
    VP_STATUS_OK = 0,
    VP_STATUS_INVALID_ARGUMENT = 1,
    VP_STATUS_OUT_OF_MEMORY = 2,
    VP_STATUS_ADDRESS_OUT_OF_RANGE = 3,
    VP_STATUS_BACKEND_UNAVAILABLE = 4,
    VP_STATUS_INVALID_STATE = 5,
} VPStatus;

typedef enum {
    VP_RUNTIME_CREATED = 0,
    VP_RUNTIME_READY = 1,
    VP_RUNTIME_RUNNING = 2,
    VP_RUNTIME_STOPPED = 3,
    VP_RUNTIME_FAILED = 4,
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

uint32_t vp_runtime_abi_version(void);
VPRuntime *vp_runtime_create(const VPMachineConfig *config);
void vp_runtime_destroy(VPRuntime *runtime);
VPRuntimeState vp_runtime_state(const VPRuntime *runtime);
const VPMachineConfig *vp_runtime_config(const VPRuntime *runtime);
void vp_runtime_set_serial_callback(VPRuntime *runtime, VPSerialCallback callback, void *context);

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
 * Execution is intentionally a separate backend. This call will return
 * VP_STATUS_BACKEND_UNAVAILABLE until the ARM64/vphone600ap CPU backend is
 * installed; keeping the boundary explicit prevents the host UI from being
 * coupled to a generic emulator frontend.
 */
VPStatus vp_runtime_boot(VPRuntime *runtime);
VPStatus vp_runtime_stop(VPRuntime *runtime);

#ifdef __cplusplus
}
#endif

#endif
