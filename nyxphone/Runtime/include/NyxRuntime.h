#ifndef NYX_RUNTIME_H
#define NYX_RUNTIME_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NYX_RUNTIME_ABI_VERSION 2u

typedef struct NyxVM NyxVM;

typedef struct {
    uint32_t cpu_count;
    uint64_t guest_physical_memory_size;
    uint32_t screen_width;
    uint32_t screen_height;
    uint32_t pixels_per_inch;
    double screen_scale;
} NyxVMConfig;

typedef void (*NyxLogCallback)(const uint8_t *bytes, size_t length, void *context);

const char *nyx_runtime_version(void);
uint32_t nyx_runtime_abi_version(void);
NyxVM *nyx_vm_create(const NyxVMConfig *config);
void nyx_vm_destroy(NyxVM *vm);
void nyx_vm_set_log_callback(NyxVM *vm, NyxLogCallback callback, void *context);
int32_t nyx_vm_load_kernel_bytes(
    NyxVM *vm,
    const void *bytes,
    size_t length,
    uint64_t load_address,
    uint64_t entry_address
);
int32_t nyx_vm_start(NyxVM *vm);
int32_t nyx_vm_stop(NyxVM *vm);
uint32_t nyx_vm_state(const NyxVM *vm);
uint64_t nyx_vm_instructions_retired(const NyxVM *vm);

#ifdef __cplusplus
}
#endif

#endif
