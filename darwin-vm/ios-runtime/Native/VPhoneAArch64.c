#include "VPhoneAArch64.h"

#include <string.h>

static int64_t vp_sign_extend(uint64_t value, unsigned bits) {
    const uint64_t sign = UINT64_C(1) << (bits - 1u);
    return (int64_t)((value ^ sign) - sign);
}

static uint64_t vp_reg_read(const VPAArch64CPU *cpu, uint32_t reg, int sp_allowed) {
    if (reg < 31u) return cpu->x[reg];
    return sp_allowed ? cpu->sp : 0;
}

static void vp_reg_write(VPAArch64CPU *cpu, uint32_t reg, uint64_t value, int is64, int sp_allowed) {
    if (!is64) value = (uint32_t)value;
    if (reg < 31u) cpu->x[reg] = value;
    else if (sp_allowed) cpu->sp = value;
}

void vp_aarch64_reset(VPAArch64CPU *cpu, uint64_t reset_vector) {
    if (!cpu) return;
    memset(cpu, 0, sizeof(*cpu));
    cpu->pc = reset_vector;
}

VPCPUStepResult vp_aarch64_step(VPRuntime *runtime, VPAArch64CPU *cpu, uint32_t *instruction_out) {
    if (!runtime || !cpu) return VP_CPU_STEP_MEMORY_FAULT;
    if (cpu->halted) return VP_CPU_STEP_HALTED;

    uint32_t insn = 0;
    if (vp_runtime_memory_read(runtime, cpu->pc, &insn, sizeof(insn)) != VP_STATUS_OK) {
        return VP_CPU_STEP_MEMORY_FAULT;
    }
    if (instruction_out) *instruction_out = insn;

    const uint64_t current_pc = cpu->pc;
    uint64_t next_pc = current_pc + 4u;

    /* NOP */
    if (insn == UINT32_C(0xD503201F)) {
        cpu->pc = next_pc;
        cpu->instructions_retired++;
        return VP_CPU_STEP_OK;
    }

    /* HLT #imm16 -- useful for deterministic interpreter tests. */
    if ((insn & UINT32_C(0xFFE0001F)) == UINT32_C(0xD4400000)) {
        cpu->halted = 1;
        cpu->instructions_retired++;
        return VP_CPU_STEP_HALTED;
    }

    /* B / BL immediate. */
    const uint32_t branch_class = insn & UINT32_C(0xFC000000);
    if (branch_class == UINT32_C(0x14000000) || branch_class == UINT32_C(0x94000000)) {
        const int64_t offset = vp_sign_extend(insn & UINT32_C(0x03FFFFFF), 26) << 2;
        if (branch_class == UINT32_C(0x94000000)) cpu->x[30] = next_pc;
        cpu->pc = (uint64_t)((int64_t)current_pc + offset);
        cpu->instructions_retired++;
        return VP_CPU_STEP_OK;
    }

    /* RET Xn. */
    if ((insn & UINT32_C(0xFFFFFC1F)) == UINT32_C(0xD65F0000)) {
        const uint32_t rn = (insn >> 5) & 31u;
        cpu->pc = vp_reg_read(cpu, rn, 0);
        cpu->instructions_retired++;
        return VP_CPU_STEP_OK;
    }

    /* MOVZ / MOVK (wide immediate), 32- and 64-bit. */
    const uint32_t wide_class = insn & UINT32_C(0x7F800000);
    if (wide_class == UINT32_C(0x52800000) || wide_class == UINT32_C(0x72800000)) {
        const int is64 = (int)((insn >> 31) & 1u);
        const uint32_t hw = (insn >> 21) & 3u;
        if (!is64 && hw > 1u) return VP_CPU_STEP_UNIMPLEMENTED;
        const uint32_t shift = hw * 16u;
        const uint64_t imm = (uint64_t)((insn >> 5) & UINT32_C(0xFFFF)) << shift;
        const uint32_t rd = insn & 31u;
        uint64_t value = imm;
        if (wide_class == UINT32_C(0x72800000)) {
            const uint64_t mask = ~(UINT64_C(0xFFFF) << shift);
            value = (vp_reg_read(cpu, rd, 0) & mask) | imm;
        }
        vp_reg_write(cpu, rd, value, is64, 0);
        cpu->pc = next_pc;
        cpu->instructions_retired++;
        return VP_CPU_STEP_OK;
    }

    /* ADD/SUB (immediate), without flags. X31 is SP in this encoding. */
    const uint32_t addsub_class = insn & UINT32_C(0x7F000000);
    if (addsub_class == UINT32_C(0x11000000) || addsub_class == UINT32_C(0x51000000)) {
        const int is64 = (int)((insn >> 31) & 1u);
        const uint32_t shift = (insn >> 22) & 1u;
        uint64_t imm = (insn >> 10) & UINT32_C(0xFFF);
        if (shift) imm <<= 12;
        const uint32_t rn = (insn >> 5) & 31u;
        const uint32_t rd = insn & 31u;
        const uint64_t lhs = vp_reg_read(cpu, rn, 1);
        const uint64_t result = addsub_class == UINT32_C(0x51000000) ? lhs - imm : lhs + imm;
        vp_reg_write(cpu, rd, result, is64, 1);
        cpu->pc = next_pc;
        cpu->instructions_retired++;
        return VP_CPU_STEP_OK;
    }

    /* STR/LDR unsigned immediate for W/X registers. */
    const uint32_t ls_class = insn & UINT32_C(0xFFC00000);
    if (ls_class == UINT32_C(0xF9000000) || ls_class == UINT32_C(0xF9400000) ||
        ls_class == UINT32_C(0xB9000000) || ls_class == UINT32_C(0xB9400000)) {
        const int is64 = (ls_class & UINT32_C(0x40000000)) != 0;
        const int is_load = (ls_class & UINT32_C(0x00400000)) != 0;
        const uint32_t rn = (insn >> 5) & 31u;
        const uint32_t rt = insn & 31u;
        const uint64_t scale = is64 ? 8u : 4u;
        const uint64_t address = vp_reg_read(cpu, rn, 1) + (((insn >> 10) & UINT32_C(0xFFF)) * scale);
        if (is_load) {
            uint64_t value = 0;
            const size_t width = is64 ? 8u : 4u;
            if (vp_runtime_memory_read(runtime, address, &value, width) != VP_STATUS_OK) {
                return VP_CPU_STEP_MEMORY_FAULT;
            }
            vp_reg_write(cpu, rt, value, is64, 0);
        } else {
            uint64_t value = vp_reg_read(cpu, rt, 0);
            const size_t width = is64 ? 8u : 4u;
            if (vp_runtime_memory_write(runtime, address, &value, width) != VP_STATUS_OK) {
                return VP_CPU_STEP_MEMORY_FAULT;
            }
        }
        cpu->pc = next_pc;
        cpu->instructions_retired++;
        return VP_CPU_STEP_OK;
    }

    return VP_CPU_STEP_UNIMPLEMENTED;
}
