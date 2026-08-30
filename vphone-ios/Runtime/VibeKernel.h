#ifndef VIBE_KERNEL_H
#define VIBE_KERNEL_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define VK_BUILD_MARKER "VIBEKERNEL-AARCH64-INTERPRETER-v0"

typedef enum VKStopReason {
    VK_STOP_NONE = 0,
    VK_STOP_WFI = 1,
    VK_STOP_SVC = 2,
    VK_STOP_ILLEGAL_INSTRUCTION = 3,
    VK_STOP_MEMORY_FAULT = 4,
    VK_STOP_INSTRUCTION_LIMIT = 5
} VKStopReason;

typedef struct VKCPUState {
    uint64_t x[31];
    uint64_t sp;
    uint64_t pc;
    uint32_t pstate;
    uint8_t current_el;
} VKCPUState;

typedef struct VKRuntime VKRuntime;

VKRuntime *vk_runtime_create(size_t memory_size);
void vk_runtime_destroy(VKRuntime *runtime);
int vk_runtime_load(VKRuntime *runtime, const void *bytes, size_t size, uint64_t guest_address);
int vk_runtime_reset(VKRuntime *runtime, uint64_t pc, uint64_t sp);
int vk_runtime_step(VKRuntime *runtime);
VKStopReason vk_runtime_run(VKRuntime *runtime, uint64_t instruction_limit);
VKStopReason vk_runtime_stop_reason(const VKRuntime *runtime);
uint32_t vk_runtime_last_instruction(const VKRuntime *runtime);
uint64_t vk_runtime_instruction_count(const VKRuntime *runtime);
const VKCPUState *vk_runtime_cpu(const VKRuntime *runtime);
int vk_runtime_set_reg(VKRuntime *runtime, unsigned reg, uint64_t value);
uint64_t vk_runtime_get_reg(const VKRuntime *runtime, unsigned reg);
int vk_runtime_read(VKRuntime *runtime, uint64_t guest_address, void *out, size_t size);
int vk_runtime_write(VKRuntime *runtime, uint64_t guest_address, const void *bytes, size_t size);
const char *vk_runtime_build_marker(void);

#ifdef __cplusplus
}
#endif

#endif
