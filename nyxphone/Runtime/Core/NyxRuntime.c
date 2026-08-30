#include "NyxRuntime.h"
#include "VPhoneKernelSurface.h"
#include "VPhoneRuntimeCore.h"

#include <stdlib.h>
#include <string.h>

struct NyxVM {
    VPRuntime *runtime;
    VPKernelSurface *surface;
    NyxLogCallback log_callback;
    void *log_context;
};

static void nyx_emit(NyxVM *vm, const char *message) {
    if (!vm || !vm->log_callback || !message) return;
    vm->log_callback((const uint8_t *)message, strlen(message), vm->log_context);
}

const char *nyx_runtime_version(void) {
    return "NyxRuntime/0.2-interpreter";
}

uint32_t nyx_runtime_abi_version(void) {
    return NYX_RUNTIME_ABI_VERSION;
}

NyxVM *nyx_vm_create(const NyxVMConfig *config) {
    if (!config) return NULL;
    NyxVM *vm = (NyxVM *)calloc(1, sizeof(*vm));
    if (!vm) return NULL;
    VPMachineConfig core_config = {
        .cpu_count = config->cpu_count,
        .guest_physical_memory_size = config->guest_physical_memory_size,
        .screen_width = config->screen_width,
        .screen_height = config->screen_height,
        .pixels_per_inch = config->pixels_per_inch,
        .screen_scale = config->screen_scale,
    };
    vm->runtime = vp_runtime_create(&core_config);
    if (!vm->runtime) {
        free(vm);
        return NULL;
    }
    vm->surface = vp_ksurface_attach(vm->runtime);
    if (!vm->surface) {
        vp_runtime_destroy(vm->runtime);
        free(vm);
        return NULL;
    }
    return vm;
}

void nyx_vm_destroy(NyxVM *vm) {
    if (!vm) return;
    if (vm->surface) vp_ksurface_destroy(vm->surface);
    if (vm->runtime) vp_runtime_destroy(vm->runtime);
    memset(vm, 0, sizeof(*vm));
    free(vm);
}

void nyx_vm_set_log_callback(NyxVM *vm, NyxLogCallback callback, void *context) {
    if (!vm) return;
    vm->log_callback = callback;
    vm->log_context = context;
    vp_runtime_set_serial_callback(vm->runtime, callback, context);
    nyx_emit(vm, "[NYXRT] runtime initialized\n");
}

int32_t nyx_vm_load_kernel_bytes(
    NyxVM *vm,
    const void *bytes,
    size_t length,
    uint64_t load_address,
    uint64_t entry_address
) {
    if (!vm || !bytes || length == 0) return (int32_t)VP_STATUS_INVALID_ARGUMENT;
    VPStatus status = vp_runtime_memory_write(vm->runtime, load_address, bytes, length);
    if (status != VP_STATUS_OK) return (int32_t)status;
    status = vp_runtime_set_boot_vector(vm->runtime, entry_address);
    if (status == VP_STATUS_OK) nyx_emit(vm, "[NYXRT] Nyxian loaded\n");
    return (int32_t)status;
}

int32_t nyx_vm_start(NyxVM *vm) {
    if (!vm) return (int32_t)VP_STATUS_INVALID_ARGUMENT;
    return (int32_t)vp_runtime_boot(vm->runtime);
}

int32_t nyx_vm_stop(NyxVM *vm) {
    if (!vm) return (int32_t)VP_STATUS_INVALID_ARGUMENT;
    return (int32_t)vp_runtime_stop(vm->runtime);
}

uint32_t nyx_vm_state(const NyxVM *vm) {
    return vm && vm->runtime ? (uint32_t)vp_runtime_state(vm->runtime) : (uint32_t)VP_RUNTIME_FAILED;
}

uint64_t nyx_vm_instructions_retired(const NyxVM *vm) {
    return vm && vm->runtime ? vp_runtime_instructions_retired(vm->runtime) : 0;
}

typedef struct {
    char *bytes;
    size_t capacity;
    size_t length;
} NyxCaptureBuffer;

static void nyx_capture_log(const uint8_t *bytes, size_t length, void *context) {
    NyxCaptureBuffer *capture = (NyxCaptureBuffer *)context;
    if (!capture || !capture->bytes || capture->capacity == 0) return;
    size_t available = capture->capacity - 1u - capture->length;
    if (length > available) length = available;
    if (length) memcpy(capture->bytes + capture->length, bytes, length);
    capture->length += length;
    capture->bytes[capture->length] = 0;
}

int32_t nyx_vm_boot_kernel_capture(
    const void *bytes,
    size_t length,
    uint64_t load_address,
    uint64_t entry_address,
    char *log_buffer,
    size_t log_capacity,
    size_t *log_length
) {
    if (!bytes || length == 0 || !log_buffer || log_capacity == 0) {
        return (int32_t)VP_STATUS_INVALID_ARGUMENT;
    }
    NyxVMConfig config = {1, UINT64_C(16) * 1024u * 1024u, 1290, 2796, 460, 3.0};
    NyxVM *vm = nyx_vm_create(&config);
    if (!vm) return (int32_t)VP_STATUS_OUT_OF_MEMORY;
    NyxCaptureBuffer capture = {log_buffer, log_capacity, 0};
    log_buffer[0] = 0;
    nyx_vm_set_log_callback(vm, nyx_capture_log, &capture);
    int32_t status = nyx_vm_load_kernel_bytes(vm, bytes, length, load_address, entry_address);
    if (status == (int32_t)VP_STATUS_OK) status = nyx_vm_start(vm);
    if (log_length) *log_length = capture.length;
    nyx_vm_destroy(vm);
    return status;
}
