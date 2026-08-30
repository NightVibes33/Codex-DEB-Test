#ifndef VPHONE_AARCH64_H
#define VPHONE_AARCH64_H

#include "VPhoneRuntimeCore.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint64_t x[31];
    uint64_t sp;
    uint64_t pc;
    uint64_t pstate;
    uint64_t instructions_retired;
    uint64_t syscalls_retired;
    uint32_t halted;
} VPAArch64CPU;

typedef enum {
    VP_CPU_STEP_OK = 0,
    VP_CPU_STEP_HALTED = 1,
    VP_CPU_STEP_MEMORY_FAULT = 2,
    VP_CPU_STEP_UNIMPLEMENTED = 3,
    VP_CPU_STEP_SYSCALL_FAULT = 4,
} VPCPUStepResult;

void vp_aarch64_reset(VPAArch64CPU *cpu, uint64_t reset_vector);
VPCPUStepResult vp_aarch64_step(VPRuntime *runtime, VPAArch64CPU *cpu, uint32_t *instruction_out);

#ifdef __cplusplus
}
#endif

#endif
