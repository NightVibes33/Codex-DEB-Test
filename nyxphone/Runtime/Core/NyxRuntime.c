#include "NyxRuntime.h"
#include "VPhoneKernelSurface.h"
#include "VPhoneRuntimeCore.h"

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>

struct NyxVM {
    VPRuntime *runtime;
    VPKernelSurface *surface;
    NyxLogCallback log_callback;
    void *log_context;
    int disk_fd;
    uint64_t disk_size;
};

static void nyx_emit(NyxVM *vm, const char *message) {
    if (!vm || !vm->log_callback || !message) return;
    vm->log_callback((const uint8_t *)message, strlen(message), vm->log_context);
}

const char *nyx_runtime_version(void) {
    return "NyxRuntime/0.5-nyxbus-storage";
}

uint32_t nyx_runtime_abi_version(void) {
    return NYX_RUNTIME_ABI_VERSION;
}

NyxVM *nyx_vm_create(const NyxVMConfig *config) {
    if (!config) return NULL;
    NyxVM *vm = (NyxVM *)calloc(1, sizeof(*vm));
    if (!vm) return NULL;
    vm->disk_fd = -1;
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
    if (vm->disk_fd >= 0) close(vm->disk_fd);
    if (vm->surface) vp_ksurface_destroy(vm->surface);
    if (vm->runtime) vp_runtime_destroy(vm->runtime);
    memset(vm, 0, sizeof(*vm));
    free(vm);
}

static VPStatus nyx_disk_read(uint64_t offset, void *dst, size_t length, void *context) {
    NyxVM *vm = (NyxVM *)context;
    if (!vm || vm->disk_fd < 0 || offset > vm->disk_size || length > vm->disk_size - offset) {
        return VP_STATUS_ADDRESS_OUT_OF_RANGE;
    }
    uint8_t *bytes = (uint8_t *)dst;
    size_t done = 0;
    while (done < length) {
        const ssize_t count = pread(vm->disk_fd, bytes + done, length - done, (off_t)(offset + done));
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return VP_STATUS_EXECUTION_FAULT;
        done += (size_t)count;
    }
    return VP_STATUS_OK;
}

static VPStatus nyx_disk_write(uint64_t offset, const void *src, size_t length, void *context) {
    NyxVM *vm = (NyxVM *)context;
    if (!vm || vm->disk_fd < 0 || offset > vm->disk_size || length > vm->disk_size - offset) {
        return VP_STATUS_ADDRESS_OUT_OF_RANGE;
    }
    const uint8_t *bytes = (const uint8_t *)src;
    size_t done = 0;
    while (done < length) {
        const ssize_t count = pwrite(vm->disk_fd, bytes + done, length - done, (off_t)(offset + done));
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return VP_STATUS_EXECUTION_FAULT;
        done += (size_t)count;
    }
    return VP_STATUS_OK;
}

static VPStatus nyx_disk_flush(void *context) {
    NyxVM *vm = (NyxVM *)context;
    return vm && vm->disk_fd >= 0 && fsync(vm->disk_fd) == 0 ? VP_STATUS_OK : VP_STATUS_EXECUTION_FAULT;
}

int32_t nyx_vm_mount_disk(NyxVM *vm, const char *path, uint64_t disk_size) {
    if (!vm || !path || !path[0] || disk_size == 0 || disk_size > INT64_MAX || vm->disk_fd >= 0) {
        return (int32_t)VP_STATUS_INVALID_ARGUMENT;
    }
    const int fd = open(path, O_RDWR | O_CREAT, 0600);
    if (fd < 0) return (int32_t)VP_STATUS_BACKEND_UNAVAILABLE;
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size < 0 ||
        ((uint64_t)st.st_size < disk_size && ftruncate(fd, (off_t)disk_size) != 0)) {
        close(fd);
        return (int32_t)VP_STATUS_BACKEND_UNAVAILABLE;
    }
    vm->disk_fd = fd;
    vm->disk_size = disk_size;
    vp_runtime_set_block_handlers(vm->runtime, nyx_disk_read, nyx_disk_write, nyx_disk_flush, vm);
    return (int32_t)VP_STATUS_OK;
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

int32_t nyx_vm_copy_framebuffer(
    NyxVM *vm, void *frame_buffer, size_t frame_capacity, NyxFramebufferInfo *frame_info
) {
    if (!vm || !frame_buffer || !frame_info) return (int32_t)VP_STATUS_INVALID_ARGUMENT;
    VPFramebufferInfo core_info = {0};
    const VPStatus status = vp_runtime_copy_framebuffer(vm->runtime, frame_buffer, frame_capacity, &core_info);
    if (status == VP_STATUS_OK) {
        frame_info->width = core_info.width;
        frame_info->height = core_info.height;
        frame_info->stride = core_info.stride;
        frame_info->pixel_format = core_info.pixel_format;
        frame_info->byte_length = core_info.byte_length;
    }
    return (int32_t)status;
}

int32_t nyx_vm_touch(NyxVM *vm, const NyxTouchEvent *event) {
    if (!vm || !event) return (int32_t)VP_STATUS_INVALID_ARGUMENT;
    const VPTouchEvent core_event = {event->id, event->x, event->y, event->pressure, event->phase};
    VPStatus status = vp_runtime_enqueue_touch(vm->runtime, &core_event);
    if (status != VP_STATUS_OK) return (int32_t)status;
    status = vp_runtime_signal_event(vm->runtime);
    return (int32_t)status;
}

int32_t nyx_vm_touch_capture_frame(
    NyxVM *vm, const NyxTouchEvent *event,
    void *frame_buffer, size_t frame_capacity, NyxFramebufferInfo *frame_info
) {
    int32_t status = nyx_vm_touch(vm, event);
    if (status == (int32_t)VP_STATUS_OK) status = nyx_vm_start(vm);
    if (status == (int32_t)VP_STATUS_GUEST_WAITING) status = (int32_t)VP_STATUS_OK;
    if (status == (int32_t)VP_STATUS_OK) {
        status = nyx_vm_copy_framebuffer(vm, frame_buffer, frame_capacity, frame_info);
    }
    return status;
}

static int32_t nyx_vm_boot_kernel_device_internal(
    const void *bytes,
    size_t length,
    uint64_t load_address,
    uint64_t entry_address,
    char *log_buffer,
    size_t log_capacity,
    size_t *log_length,
    void *frame_buffer,
    size_t frame_capacity,
    NyxFramebufferInfo *frame_info,
    const char *disk_path, uint64_t disk_size, NyxVM **vm_out
) {
    if (!bytes || length == 0 || !log_buffer || log_capacity == 0 || !vm_out) {
        return (int32_t)VP_STATUS_INVALID_ARGUMENT;
    }
    *vm_out = NULL;
    NyxVMConfig config = {1, UINT64_C(16) * 1024u * 1024u, 1290, 2796, 460, 3.0};
    NyxVM *vm = nyx_vm_create(&config);
    if (!vm) return (int32_t)VP_STATUS_OUT_OF_MEMORY;
    if (disk_path) {
        const int32_t mount_status = nyx_vm_mount_disk(vm, disk_path, disk_size);
        if (mount_status != (int32_t)VP_STATUS_OK) {
            nyx_vm_destroy(vm);
            return mount_status;
        }
    }
    NyxCaptureBuffer capture = {log_buffer, log_capacity, 0};
    log_buffer[0] = 0;
    nyx_vm_set_log_callback(vm, nyx_capture_log, &capture);
    int32_t status = nyx_vm_load_kernel_bytes(vm, bytes, length, load_address, entry_address);
    if (status == (int32_t)VP_STATUS_OK) status = nyx_vm_start(vm);
    if (status == (int32_t)VP_STATUS_GUEST_WAITING) status = (int32_t)VP_STATUS_OK;
    if (status == (int32_t)VP_STATUS_OK && frame_buffer && frame_info) {
        status = nyx_vm_copy_framebuffer(vm, frame_buffer, frame_capacity, frame_info);
    }
    if (log_length) *log_length = capture.length;
    if (status == (int32_t)VP_STATUS_OK) {
        nyx_vm_set_log_callback(vm, NULL, NULL);
        *vm_out = vm;
    }
    else nyx_vm_destroy(vm);
    return status;
}

int32_t nyx_vm_boot_kernel_device(
    const void *bytes, size_t length, uint64_t load_address, uint64_t entry_address,
    char *log_buffer, size_t log_capacity, size_t *log_length,
    void *frame_buffer, size_t frame_capacity, NyxFramebufferInfo *frame_info, NyxVM **vm_out
) {
    return nyx_vm_boot_kernel_device_internal(
        bytes, length, load_address, entry_address, log_buffer, log_capacity, log_length,
        frame_buffer, frame_capacity, frame_info, NULL, 0, vm_out
    );
}

int32_t nyx_vm_boot_kernel_device_storage(
    const void *bytes, size_t length, uint64_t load_address, uint64_t entry_address,
    const char *disk_path, uint64_t disk_size,
    char *log_buffer, size_t log_capacity, size_t *log_length,
    void *frame_buffer, size_t frame_capacity, NyxFramebufferInfo *frame_info, NyxVM **vm_out
) {
    if (!disk_path) return (int32_t)VP_STATUS_INVALID_ARGUMENT;
    return nyx_vm_boot_kernel_device_internal(
        bytes, length, load_address, entry_address, log_buffer, log_capacity, log_length,
        frame_buffer, frame_capacity, frame_info, disk_path, disk_size, vm_out
    );
}

int32_t nyx_vm_boot_kernel_capture_frame(
    const void *bytes, size_t length, uint64_t load_address, uint64_t entry_address,
    char *log_buffer, size_t log_capacity, size_t *log_length,
    void *frame_buffer, size_t frame_capacity, NyxFramebufferInfo *frame_info
) {
    NyxVM *vm = NULL;
    const int32_t status = nyx_vm_boot_kernel_device(
        bytes, length, load_address, entry_address, log_buffer, log_capacity, log_length,
        frame_buffer, frame_capacity, frame_info, &vm
    );
    nyx_vm_destroy(vm);
    return status;
}

int32_t nyx_vm_boot_kernel_capture(
    const void *bytes, size_t length, uint64_t load_address, uint64_t entry_address,
    char *log_buffer, size_t log_capacity, size_t *log_length
) {
    return nyx_vm_boot_kernel_capture_frame(
        bytes, length, load_address, entry_address, log_buffer, log_capacity, log_length, NULL, 0, NULL
    );
}
