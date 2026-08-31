#include "VPhoneRuntimeCore.h"
#include "VPhoneAArch64.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define VP_PAGE_BUCKETS 4096u

typedef struct VPPage {
    uint64_t index;
    struct VPPage *next;
    uint8_t bytes[VP_GUEST_PAGE_SIZE];
} VPPage;

struct VPRuntime {
    VPMachineConfig config;
    VPRuntimeState state;
    VPPage *buckets[VP_PAGE_BUCKETS];
    uint64_t committed_pages;
    VPSerialCallback serial_callback;
    void *serial_context;
    VPSyscallHandler syscall_handler;
    void *syscall_context;
    VPBlockReadHandler block_read_handler;
    VPBlockWriteHandler block_write_handler;
    VPBlockFlushHandler block_flush_handler;
    void *block_context;
    VPNetworkGetHandler network_get_handler;
    void *network_context;
    uint64_t boot_vector;
    uint64_t instruction_budget;
    uint64_t instructions_retired;
    VPAArch64CPU cpu;
    int cpu_initialized;
    int stop_requested;
    VPFramebufferInfo framebuffer;
    int framebuffer_ready;
    VPTouchEvent touch_queue[16];
    uint32_t touch_head;
    uint32_t touch_count;
};

static uint64_t vp_page_index(uint64_t address) {
    return address >> VP_GUEST_PAGE_SHIFT;
}

static uint32_t vp_bucket(uint64_t page_index) {
    page_index ^= page_index >> 33;
    page_index *= UINT64_C(0xff51afd7ed558ccd);
    page_index ^= page_index >> 33;
    return (uint32_t)(page_index & (VP_PAGE_BUCKETS - 1u));
}

static int vp_range_valid(const VPRuntime *runtime, uint64_t address, size_t length) {
    if (!runtime) return 0;
    if (length == 0) return address <= runtime->config.guest_physical_memory_size;
    if (address >= runtime->config.guest_physical_memory_size) return 0;
    if ((uint64_t)length > runtime->config.guest_physical_memory_size - address) return 0;
    return 1;
}

static VPPage *vp_find_page(VPRuntime *runtime, uint64_t index, int create) {
    const uint32_t bucket = vp_bucket(index);
    VPPage *page = runtime->buckets[bucket];
    while (page) {
        if (page->index == index) return page;
        page = page->next;
    }
    if (!create) return NULL;

    page = (VPPage *)calloc(1, sizeof(VPPage));
    if (!page) return NULL;
    page->index = index;
    page->next = runtime->buckets[bucket];
    runtime->buckets[bucket] = page;
    runtime->committed_pages++;
    return page;
}

static void vp_emit(VPRuntime *runtime, const char *message) {
    if (!runtime || !runtime->serial_callback || !message) return;
    runtime->serial_callback((const uint8_t *)message, strlen(message), runtime->serial_context);
}

static VPStatus vp_execution_failure(VPRuntime *runtime, const char *kind, const VPAArch64CPU *cpu, uint32_t insn) {
    char message[192];
    (void)snprintf(
        message,
        sizeof(message),
        "[VibePhone] %s at pc=0x%llx insn=0x%08x retired=%llu\n",
        kind,
        (unsigned long long)(cpu ? cpu->pc : 0),
        insn,
        (unsigned long long)(cpu ? cpu->instructions_retired : 0)
    );
    vp_emit(runtime, message);
    runtime->state = VP_RUNTIME_FAILED;
    return VP_STATUS_EXECUTION_FAULT;
}

static void vp_runtime_invalidate_cpu(VPRuntime *runtime) {
    if (!runtime) return;
    memset(&runtime->cpu, 0, sizeof(runtime->cpu));
    runtime->cpu_initialized = 0;
    runtime->instructions_retired = 0;
}

uint32_t vp_runtime_abi_version(void) {
    return VP_RUNTIME_ABI_VERSION;
}

VPRuntime *vp_runtime_create(const VPMachineConfig *config) {
    if (!config || config->cpu_count == 0 || config->guest_physical_memory_size == 0) return NULL;
    VPRuntime *runtime = (VPRuntime *)calloc(1, sizeof(VPRuntime));
    if (!runtime) return NULL;
    runtime->config = *config;
    runtime->state = VP_RUNTIME_READY;
    runtime->instruction_budget = VP_DEFAULT_INSTRUCTION_BUDGET;
    return runtime;
}

void vp_runtime_destroy(VPRuntime *runtime) {
    if (!runtime) return;
    for (uint32_t i = 0; i < VP_PAGE_BUCKETS; i++) {
        VPPage *page = runtime->buckets[i];
        while (page) {
            VPPage *next = page->next;
            free(page);
            page = next;
        }
    }
    memset(runtime, 0, sizeof(*runtime));
    free(runtime);
}

VPRuntimeState vp_runtime_state(const VPRuntime *runtime) {
    return runtime ? runtime->state : VP_RUNTIME_FAILED;
}

const VPMachineConfig *vp_runtime_config(const VPRuntime *runtime) {
    return runtime ? &runtime->config : NULL;
}

void vp_runtime_set_serial_callback(VPRuntime *runtime, VPSerialCallback callback, void *context) {
    if (!runtime) return;
    runtime->serial_callback = callback;
    runtime->serial_context = context;
}

void vp_runtime_set_syscall_handler(VPRuntime *runtime, VPSyscallHandler handler, void *context) {
    if (!runtime || runtime->state == VP_RUNTIME_RUNNING) return;
    runtime->syscall_handler = handler;
    runtime->syscall_context = context;
}

void vp_runtime_set_block_handlers(
    VPRuntime *runtime, VPBlockReadHandler read_handler, VPBlockWriteHandler write_handler,
    VPBlockFlushHandler flush_handler, void *context
) {
    if (!runtime || runtime->state == VP_RUNTIME_RUNNING) return;
    runtime->block_read_handler = read_handler;
    runtime->block_write_handler = write_handler;
    runtime->block_flush_handler = flush_handler;
    runtime->block_context = context;
}

void vp_runtime_set_network_handler(
    VPRuntime *runtime, VPNetworkGetHandler get_handler, void *context
) {
    if (!runtime || runtime->state == VP_RUNTIME_RUNNING) return;
    runtime->network_get_handler = get_handler;
    runtime->network_context = context;
}

VPStatus vp_runtime_dispatch_syscall(
    VPRuntime *runtime,
    uint64_t number,
    const uint64_t args[8],
    uint64_t *result
) {
    if (!runtime || !result) return VP_STATUS_INVALID_ARGUMENT;
    if (!runtime->syscall_handler) return VP_STATUS_BACKEND_UNAVAILABLE;
    return runtime->syscall_handler(runtime, number, args, result, runtime->syscall_context);
}

VPStatus vp_runtime_memory_read(VPRuntime *runtime, uint64_t address, void *dst, size_t length) {
    if (!runtime || (!dst && length)) return VP_STATUS_INVALID_ARGUMENT;
    if (!vp_range_valid(runtime, address, length)) return VP_STATUS_ADDRESS_OUT_OF_RANGE;

    uint8_t *out = (uint8_t *)dst;
    size_t remaining = length;
    while (remaining) {
        const uint64_t index = vp_page_index(address);
        const size_t offset = (size_t)(address & (VP_GUEST_PAGE_SIZE - 1u));
        size_t chunk = VP_GUEST_PAGE_SIZE - offset;
        if (chunk > remaining) chunk = remaining;

        VPPage *page = vp_find_page(runtime, index, 0);
        if (page) memcpy(out, page->bytes + offset, chunk);
        else memset(out, 0, chunk);

        address += chunk;
        out += chunk;
        remaining -= chunk;
    }
    return VP_STATUS_OK;
}

VPStatus vp_runtime_memory_write(VPRuntime *runtime, uint64_t address, const void *src, size_t length) {
    if (!runtime || (!src && length)) return VP_STATUS_INVALID_ARGUMENT;
    if (!vp_range_valid(runtime, address, length)) return VP_STATUS_ADDRESS_OUT_OF_RANGE;

    const uint8_t *in = (const uint8_t *)src;
    size_t remaining = length;
    while (remaining) {
        const uint64_t index = vp_page_index(address);
        const size_t offset = (size_t)(address & (VP_GUEST_PAGE_SIZE - 1u));
        size_t chunk = VP_GUEST_PAGE_SIZE - offset;
        if (chunk > remaining) chunk = remaining;

        VPPage *page = vp_find_page(runtime, index, 1);
        if (!page) return VP_STATUS_OUT_OF_MEMORY;
        memcpy(page->bytes + offset, in, chunk);

        address += chunk;
        in += chunk;
        remaining -= chunk;
    }
    return VP_STATUS_OK;
}

VPStatus vp_runtime_console_write(VPRuntime *runtime, uint64_t guest_address, size_t length) {
    if (!runtime) return VP_STATUS_INVALID_ARGUMENT;
    if (!vp_range_valid(runtime, guest_address, length)) return VP_STATUS_ADDRESS_OUT_OF_RANGE;
    uint8_t buffer[256];
    size_t remaining = length;
    while (remaining) {
        size_t chunk = remaining < sizeof(buffer) ? remaining : sizeof(buffer);
        VPStatus status = vp_runtime_memory_read(runtime, guest_address, buffer, chunk);
        if (status != VP_STATUS_OK) return status;
        if (runtime->serial_callback) {
            runtime->serial_callback(buffer, chunk, runtime->serial_context);
        }
        guest_address += chunk;
        remaining -= chunk;
    }
    return VP_STATUS_OK;
}

VPStatus vp_runtime_publish_framebuffer(
    VPRuntime *runtime, uint64_t guest_address, uint32_t width, uint32_t height, uint32_t stride
) {
    if (!runtime || width == 0 || height == 0 || width > UINT32_MAX / 4u || stride < width * 4u) {
        return VP_STATUS_INVALID_ARGUMENT;
    }
    const uint64_t byte_length = (uint64_t)stride * height;
    if (byte_length > SIZE_MAX || !vp_range_valid(runtime, guest_address, (size_t)byte_length)) {
        return VP_STATUS_ADDRESS_OUT_OF_RANGE;
    }
    runtime->framebuffer = (VPFramebufferInfo){
        .guest_address = guest_address,
        .width = width,
        .height = height,
        .stride = stride,
        .pixel_format = 1u, /* RGBA8888 */
        .byte_length = byte_length,
    };
    const int first_frame = !runtime->framebuffer_ready;
    runtime->framebuffer_ready = 1;
    vp_emit(runtime, first_frame ? "[NYXDISPLAY] first frame\n" : "[NYXDISPLAY] frame ready\n");
    return VP_STATUS_OK;
}

VPStatus vp_runtime_copy_framebuffer(
    VPRuntime *runtime, void *dst, size_t capacity, VPFramebufferInfo *info
) {
    if (!runtime || !dst || !info || !runtime->framebuffer_ready) return VP_STATUS_INVALID_STATE;
    if (runtime->framebuffer.byte_length > capacity) return VP_STATUS_INVALID_ARGUMENT;
    VPStatus status = vp_runtime_memory_read(
        runtime, runtime->framebuffer.guest_address, dst, (size_t)runtime->framebuffer.byte_length
    );
    if (status == VP_STATUS_OK) *info = runtime->framebuffer;
    return status;
}

VPStatus vp_runtime_enqueue_touch(VPRuntime *runtime, const VPTouchEvent *event) {
    if (!runtime || !event || event->x < 0.0f || event->x > 1.0f ||
        event->y < 0.0f || event->y > 1.0f || event->pressure < 0.0f || event->phase > 2u) {
        return VP_STATUS_INVALID_ARGUMENT;
    }
    if (runtime->touch_count == 16u) {
        runtime->touch_head = (runtime->touch_head + 1u) % 16u;
        runtime->touch_count--;
    }
    const uint32_t tail = (runtime->touch_head + runtime->touch_count) % 16u;
    runtime->touch_queue[tail] = *event;
    runtime->touch_count++;
    return VP_STATUS_OK;
}

VPStatus vp_runtime_dequeue_touch(VPRuntime *runtime, VPTouchEvent *event) {
    if (!runtime || !event) return VP_STATUS_INVALID_ARGUMENT;
    if (runtime->touch_count == 0) return VP_STATUS_INVALID_STATE;
    *event = runtime->touch_queue[runtime->touch_head];
    runtime->touch_head = (runtime->touch_head + 1u) % 16u;
    runtime->touch_count--;
    return VP_STATUS_OK;
}

VPStatus vp_runtime_block_read(VPRuntime *runtime, uint64_t guest_address, uint64_t offset, size_t length) {
    if (!runtime || !runtime->block_read_handler || length > 4096u) return VP_STATUS_BACKEND_UNAVAILABLE;
    if (!vp_range_valid(runtime, guest_address, length)) return VP_STATUS_ADDRESS_OUT_OF_RANGE;
    uint8_t buffer[4096];
    VPStatus status = runtime->block_read_handler(offset, buffer, length, runtime->block_context);
    if (status != VP_STATUS_OK) return status;
    return vp_runtime_memory_write(runtime, guest_address, buffer, length);
}

VPStatus vp_runtime_block_write(VPRuntime *runtime, uint64_t guest_address, uint64_t offset, size_t length) {
    if (!runtime || !runtime->block_write_handler || length > 4096u) return VP_STATUS_BACKEND_UNAVAILABLE;
    if (!vp_range_valid(runtime, guest_address, length)) return VP_STATUS_ADDRESS_OUT_OF_RANGE;
    uint8_t buffer[4096];
    VPStatus status = vp_runtime_memory_read(runtime, guest_address, buffer, length);
    if (status != VP_STATUS_OK) return status;
    return runtime->block_write_handler(offset, buffer, length, runtime->block_context);
}

VPStatus vp_runtime_block_flush(VPRuntime *runtime) {
    if (!runtime || !runtime->block_flush_handler) return VP_STATUS_BACKEND_UNAVAILABLE;
    return runtime->block_flush_handler(runtime->block_context);
}

VPStatus vp_runtime_network_https_get(
    VPRuntime *runtime, uint64_t url_address, size_t url_length,
    uint64_t response_address, size_t response_capacity, size_t *response_length
) {
    if (!runtime || !response_length || !runtime->network_get_handler ||
        url_length == 0 || url_length > 2047u || response_capacity == 0 || response_capacity > 4096u) {
        return VP_STATUS_INVALID_ARGUMENT;
    }
    if (!vp_range_valid(runtime, url_address, url_length) ||
        !vp_range_valid(runtime, response_address, response_capacity)) {
        return VP_STATUS_ADDRESS_OUT_OF_RANGE;
    }
    char url[2048];
    uint8_t response[4096];
    VPStatus status = vp_runtime_memory_read(runtime, url_address, url, url_length);
    if (status != VP_STATUS_OK) return status;
    url[url_length] = 0;
    if (url_length < 8u || memcmp(url, "https://", 8u) != 0) return VP_STATUS_INVALID_ARGUMENT;
    size_t received = 0;
    status = runtime->network_get_handler(
        url, response, response_capacity, &received, runtime->network_context
    );
    if (status != VP_STATUS_OK) return status;
    if (received == 0 || received > response_capacity) return VP_STATUS_EXECUTION_FAULT;
    status = vp_runtime_memory_write(runtime, response_address, response, received);
    if (status == VP_STATUS_OK) *response_length = received;
    return status;
}

uint64_t vp_runtime_committed_pages(const VPRuntime *runtime) {
    return runtime ? runtime->committed_pages : 0;
}

uint64_t vp_runtime_committed_bytes(const VPRuntime *runtime) {
    return vp_runtime_committed_pages(runtime) * (uint64_t)VP_GUEST_PAGE_SIZE;
}

static int vp_boot_image_valid(const VPRuntime *runtime, const VPBootImage *image) {
    if (!image) return 0;
    if (image->length == 0) return image->bytes == NULL;
    if (!image->bytes) return 0;
    return vp_range_valid(runtime, image->guest_address, image->length);
}

static int vp_boot_image_contains(const VPBootImage *image, uint64_t address) {
    if (!image || !image->bytes || image->length == 0) return 0;
    if (address < image->guest_address) return 0;
    return address - image->guest_address < (uint64_t)image->length;
}

static VPStatus vp_stage_one_boot_image(VPRuntime *runtime, const VPBootImage *image) {
    if (!image || image->length == 0) return VP_STATUS_OK;
    return vp_runtime_memory_write(runtime, image->guest_address, image->bytes, image->length);
}

VPStatus vp_runtime_stage_boot_images(VPRuntime *runtime, const VPBootImageLayout *layout) {
    if (!runtime || !layout) return VP_STATUS_INVALID_ARGUMENT;
    if (runtime->state == VP_RUNTIME_RUNNING) return VP_STATUS_INVALID_STATE;

    const VPBootImage *images[] = {
        &layout->iboot,
        &layout->kernelcache,
        &layout->device_tree,
        &layout->trust_cache,
        &layout->ramdisk,
    };

    int has_image = 0;
    int entry_is_staged = 0;
    for (size_t i = 0; i < sizeof(images) / sizeof(images[0]); i++) {
        if (!vp_boot_image_valid(runtime, images[i])) return VP_STATUS_ADDRESS_OUT_OF_RANGE;
        if (images[i]->length != 0) has_image = 1;
        if (vp_boot_image_contains(images[i], layout->entry_address)) entry_is_staged = 1;
    }
    if (!has_image || !entry_is_staged) return VP_STATUS_INVALID_ARGUMENT;

    for (size_t i = 0; i < sizeof(images) / sizeof(images[0]); i++) {
        const VPStatus status = vp_stage_one_boot_image(runtime, images[i]);
        if (status != VP_STATUS_OK) return status;
    }

    runtime->boot_vector = layout->entry_address;
    runtime->framebuffer_ready = 0;
    memset(&runtime->framebuffer, 0, sizeof(runtime->framebuffer));
    runtime->touch_head = 0;
    runtime->touch_count = 0;
    vp_runtime_invalidate_cpu(runtime);
    runtime->state = VP_RUNTIME_READY;
    vp_emit(runtime, "[VibePhone] staged Apple boot image set into guest physical memory\n");
    return VP_STATUS_OK;
}

VPStatus vp_runtime_set_boot_vector(VPRuntime *runtime, uint64_t guest_address) {
    if (!runtime) return VP_STATUS_INVALID_ARGUMENT;
    if (runtime->state == VP_RUNTIME_RUNNING) return VP_STATUS_INVALID_STATE;
    if (!vp_range_valid(runtime, guest_address, sizeof(uint32_t))) return VP_STATUS_ADDRESS_OUT_OF_RANGE;
    runtime->boot_vector = guest_address;
    runtime->framebuffer_ready = 0;
    memset(&runtime->framebuffer, 0, sizeof(runtime->framebuffer));
    runtime->touch_head = 0;
    runtime->touch_count = 0;
    vp_runtime_invalidate_cpu(runtime);
    runtime->state = VP_RUNTIME_READY;
    return VP_STATUS_OK;
}

void vp_runtime_set_instruction_budget(VPRuntime *runtime, uint64_t budget) {
    if (!runtime || runtime->state == VP_RUNTIME_RUNNING) return;
    runtime->instruction_budget = budget ? budget : VP_DEFAULT_INSTRUCTION_BUDGET;
}

uint64_t vp_runtime_boot_vector(const VPRuntime *runtime) {
    return runtime ? runtime->boot_vector : 0;
}

uint64_t vp_runtime_instructions_retired(const VPRuntime *runtime) {
    return runtime ? runtime->instructions_retired : 0;
}

VPStatus vp_runtime_boot(VPRuntime *runtime) {
    if (!runtime) return VP_STATUS_INVALID_ARGUMENT;
    if (runtime->state != VP_RUNTIME_READY &&
        runtime->state != VP_RUNTIME_STOPPED &&
        runtime->state != VP_RUNTIME_PAUSED &&
        runtime->state != VP_RUNTIME_WAITING) {
        return VP_STATUS_INVALID_STATE;
    }

    if (runtime->state == VP_RUNTIME_WAITING && runtime->cpu.waiting) {
        return VP_STATUS_GUEST_WAITING;
    }

    if (!runtime->cpu_initialized ||
        runtime->state == VP_RUNTIME_READY ||
        runtime->state == VP_RUNTIME_STOPPED) {
        vp_aarch64_reset(&runtime->cpu, runtime->boot_vector);
        runtime->cpu_initialized = 1;
        runtime->instructions_retired = 0;
        vp_emit(runtime, "[VibePhone] custom AArch64 runtime entered guest execution\n");
    } else {
        vp_emit(runtime, "[VibePhone] resuming saved guest CPU state\n");
    }

    runtime->state = VP_RUNTIME_RUNNING;
    runtime->stop_requested = 0;
    const uint64_t start_retired = runtime->cpu.instructions_retired;
    const uint64_t budget = runtime->instruction_budget ? runtime->instruction_budget : VP_DEFAULT_INSTRUCTION_BUDGET;

    while (!runtime->stop_requested &&
           runtime->cpu.instructions_retired - start_retired < budget) {
        uint32_t insn = 0;
        const VPCPUStepResult step = vp_aarch64_step(runtime, &runtime->cpu, &insn);
        runtime->instructions_retired = runtime->cpu.instructions_retired;
        if (step == VP_CPU_STEP_OK) continue;
        if (step == VP_CPU_STEP_HALTED) {
            runtime->state = VP_RUNTIME_STOPPED;
            runtime->cpu_initialized = 0;
            vp_emit(runtime, "[VibePhone] guest execution halted cleanly\n");
            return VP_STATUS_OK;
        }
        if (step == VP_CPU_STEP_WAITING) {
            runtime->state = VP_RUNTIME_WAITING;
            vp_emit(runtime, "[VibePhone] guest CPU entered WFI/WFE wait state\n");
            return VP_STATUS_GUEST_WAITING;
        }
        if (step == VP_CPU_STEP_SYSCALL_FAULT) {
            return vp_execution_failure(runtime, "userspace kernel syscall fault", &runtime->cpu, insn);
        }
        if (step == VP_CPU_STEP_MEMORY_FAULT) {
            return vp_execution_failure(runtime, "guest memory fault", &runtime->cpu, insn);
        }
        if (step == VP_CPU_STEP_SYSTEM_REGISTER_FAULT) {
            return vp_execution_failure(runtime, "unimplemented AArch64 system register", &runtime->cpu, insn);
        }
        return vp_execution_failure(runtime, "unimplemented AArch64 instruction", &runtime->cpu, insn);
    }

    runtime->instructions_retired = runtime->cpu.instructions_retired;
    if (runtime->stop_requested) {
        runtime->state = VP_RUNTIME_STOPPED;
        runtime->cpu_initialized = 0;
        vp_emit(runtime, "[VibePhone] guest execution stopped by host\n");
        return VP_STATUS_OK;
    }

    runtime->state = VP_RUNTIME_PAUSED;
    vp_emit(runtime, "[VibePhone] instruction budget exhausted; saved CPU state yielded to host\n");
    return VP_STATUS_BUDGET_EXHAUSTED;
}

VPStatus vp_runtime_signal_event(VPRuntime *runtime) {
    if (!runtime) return VP_STATUS_INVALID_ARGUMENT;
    if (runtime->state != VP_RUNTIME_WAITING && runtime->state != VP_RUNTIME_PAUSED) {
        return VP_STATUS_INVALID_STATE;
    }
    vp_aarch64_wake(&runtime->cpu);
    runtime->state = VP_RUNTIME_PAUSED;
    vp_emit(runtime, "[VibePhone] guest wait state signaled; CPU ready to resume\n");
    return VP_STATUS_OK;
}

VPStatus vp_runtime_stop(VPRuntime *runtime) {
    if (!runtime) return VP_STATUS_INVALID_ARGUMENT;
    runtime->stop_requested = 1;
    if (runtime->state != VP_RUNTIME_RUNNING) {
        runtime->state = VP_RUNTIME_STOPPED;
        vp_runtime_invalidate_cpu(runtime);
    }
    return VP_STATUS_OK;
}
