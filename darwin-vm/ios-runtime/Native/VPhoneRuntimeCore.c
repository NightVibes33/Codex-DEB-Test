#include "VPhoneRuntimeCore.h"

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

uint32_t vp_runtime_abi_version(void) {
    return VP_RUNTIME_ABI_VERSION;
}

VPRuntime *vp_runtime_create(const VPMachineConfig *config) {
    if (!config || config->cpu_count == 0 || config->guest_physical_memory_size == 0) return NULL;
    VPRuntime *runtime = (VPRuntime *)calloc(1, sizeof(VPRuntime));
    if (!runtime) return NULL;
    runtime->config = *config;
    runtime->state = VP_RUNTIME_READY;
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

uint64_t vp_runtime_committed_pages(const VPRuntime *runtime) {
    return runtime ? runtime->committed_pages : 0;
}

uint64_t vp_runtime_committed_bytes(const VPRuntime *runtime) {
    return vp_runtime_committed_pages(runtime) * (uint64_t)VP_GUEST_PAGE_SIZE;
}

VPStatus vp_runtime_boot(VPRuntime *runtime) {
    if (!runtime) return VP_STATUS_INVALID_ARGUMENT;
    if (runtime->state != VP_RUNTIME_READY && runtime->state != VP_RUNTIME_STOPPED) {
        return VP_STATUS_INVALID_STATE;
    }
    vp_emit(runtime, "[DarwinVM] vphone600ap machine core ready; ARM64 execution backend pending\n");
    return VP_STATUS_BACKEND_UNAVAILABLE;
}

VPStatus vp_runtime_stop(VPRuntime *runtime) {
    if (!runtime) return VP_STATUS_INVALID_ARGUMENT;
    if (runtime->state == VP_RUNTIME_RUNNING) runtime->state = VP_RUNTIME_STOPPED;
    return VP_STATUS_OK;
}
