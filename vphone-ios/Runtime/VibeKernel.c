#include "VibeKernel.h"

#include <stdlib.h>
#include <string.h>

struct VKRuntime {
    uint8_t *memory;
    size_t memory_size;
    VKCPUState cpu;
    VKStopReason stop_reason;
    uint32_t last_instruction;
    uint64_t instruction_count;
};

#if defined(__GNUC__)
__attribute__((used, visibility("default")))
#endif
static const char vk_build_marker[] = VK_BUILD_MARKER;

static int range_ok(const VKRuntime *rt, uint64_t address, size_t size) {
    if (!rt || !rt->memory) return 0;
    if (address > rt->memory_size) return 0;
    return size <= rt->memory_size - (size_t)address;
}

static uint32_t load_le32(const uint8_t *p) {
    return ((uint32_t)p[0]) |
           ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
}

static uint64_t load_le64(const uint8_t *p) {
    uint64_t value = 0;
    for (unsigned i = 0; i < 8; i++) value |= ((uint64_t)p[i]) << (i * 8);
    return value;
}

static void store_le32(uint8_t *p, uint32_t value) {
    for (unsigned i = 0; i < 4; i++) p[i] = (uint8_t)(value >> (i * 8));
}

static void store_le64(uint8_t *p, uint64_t value) {
    for (unsigned i = 0; i < 8; i++) p[i] = (uint8_t)(value >> (i * 8));
}

static int64_t sign_extend(uint64_t value, unsigned bits) {
    const uint64_t sign = 1ULL << (bits - 1);
    return (int64_t)((value ^ sign) - sign);
}

static uint64_t read_gpr(const VKCPUState *cpu, unsigned reg, int sp_allowed) {
    if (reg < 31) return cpu->x[reg];
    return sp_allowed ? cpu->sp : 0;
}

static void write_gpr(VKCPUState *cpu, unsigned reg, uint64_t value, int is64, int sp_allowed) {
    if (!is64) value = (uint32_t)value;
    if (reg < 31) {
        cpu->x[reg] = value;
    } else if (sp_allowed) {
        cpu->sp = value;
    }
}

VKRuntime *vk_runtime_create(size_t memory_size) {
    if (memory_size < 4096) return NULL;
    VKRuntime *rt = (VKRuntime *)calloc(1, sizeof(VKRuntime));
    if (!rt) return NULL;
    rt->memory = (uint8_t *)calloc(1, memory_size);
    if (!rt->memory) {
        free(rt);
        return NULL;
    }
    rt->memory_size = memory_size;
    rt->cpu.current_el = 1;
    return rt;
}

void vk_runtime_destroy(VKRuntime *rt) {
    if (!rt) return;
    free(rt->memory);
    memset(rt, 0, sizeof(*rt));
    free(rt);
}

int vk_runtime_load(VKRuntime *rt, const void *bytes, size_t size, uint64_t guest_address) {
    if (!bytes || !range_ok(rt, guest_address, size)) return -1;
    memcpy(rt->memory + guest_address, bytes, size);
    return 0;
}

int vk_runtime_reset(VKRuntime *rt, uint64_t pc, uint64_t sp) {
    if (!rt || !range_ok(rt, pc, 4) || sp > rt->memory_size) return -1;
    memset(&rt->cpu, 0, sizeof(rt->cpu));
    rt->cpu.pc = pc;
    rt->cpu.sp = sp;
    rt->cpu.current_el = 1;
    rt->stop_reason = VK_STOP_NONE;
    rt->last_instruction = 0;
    rt->instruction_count = 0;
    return 0;
}

int vk_runtime_read(VKRuntime *rt, uint64_t guest_address, void *out, size_t size) {
    if (!out || !range_ok(rt, guest_address, size)) return -1;
    memcpy(out, rt->memory + guest_address, size);
    return 0;
}

int vk_runtime_write(VKRuntime *rt, uint64_t guest_address, const void *bytes, size_t size) {
    return vk_runtime_load(rt, bytes, size, guest_address);
}

int vk_runtime_set_reg(VKRuntime *rt, unsigned reg, uint64_t value) {
    if (!rt || reg > 31) return -1;
    if (reg == 31) rt->cpu.sp = value;
    else rt->cpu.x[reg] = value;
    return 0;
}

uint64_t vk_runtime_get_reg(const VKRuntime *rt, unsigned reg) {
    if (!rt || reg > 31) return 0;
    return reg == 31 ? rt->cpu.sp : rt->cpu.x[reg];
}

static int stop(VKRuntime *rt, VKStopReason reason) {
    rt->stop_reason = reason;
    return 1;
}

int vk_runtime_step(VKRuntime *rt) {
    if (!rt || rt->stop_reason != VK_STOP_NONE) return -1;
    if (!range_ok(rt, rt->cpu.pc, 4)) return stop(rt, VK_STOP_MEMORY_FAULT);

    const uint64_t pc = rt->cpu.pc;
    const uint32_t insn = load_le32(rt->memory + pc);
    rt->last_instruction = insn;
    rt->instruction_count++;

    /* NOP */
    if (insn == 0xD503201F) {
        rt->cpu.pc = pc + 4;
        return 0;
    }

    /* WFI */
    if (insn == 0xD503207F) {
        rt->cpu.pc = pc + 4;
        return stop(rt, VK_STOP_WFI);
    }

    /* SVC #imm16 */
    if ((insn & 0xFFE0001FU) == 0xD4000001U) {
        rt->cpu.pc = pc + 4;
        return stop(rt, VK_STOP_SVC);
    }

    /* MOVZ */
    if ((insn & 0x7F800000U) == 0x52800000U) {
        const int is64 = (insn >> 31) & 1;
        const unsigned hw = (insn >> 21) & 3;
        const uint64_t imm16 = (insn >> 5) & 0xFFFFU;
        const unsigned rd = insn & 31U;
        if (!is64 && hw > 1) return stop(rt, VK_STOP_ILLEGAL_INSTRUCTION);
        write_gpr(&rt->cpu, rd, imm16 << (hw * 16), is64, 0);
        rt->cpu.pc = pc + 4;
        return 0;
    }

    /* MOVK */
    if ((insn & 0x7F800000U) == 0x72800000U) {
        const int is64 = (insn >> 31) & 1;
        const unsigned hw = (insn >> 21) & 3;
        const uint64_t imm16 = (insn >> 5) & 0xFFFFU;
        const unsigned rd = insn & 31U;
        if (!is64 && hw > 1) return stop(rt, VK_STOP_ILLEGAL_INSTRUCTION);
        uint64_t old = read_gpr(&rt->cpu, rd, 0);
        const uint64_t mask = 0xFFFFULL << (hw * 16);
        uint64_t value = (old & ~mask) | (imm16 << (hw * 16));
        write_gpr(&rt->cpu, rd, value, is64, 0);
        rt->cpu.pc = pc + 4;
        return 0;
    }

    /* ADD/SUB (immediate), S=0 only for the seed core. */
    if ((insn & 0x1F000000U) == 0x11000000U) {
        const int is64 = (insn >> 31) & 1;
        const int subtract = (insn >> 30) & 1;
        const int set_flags = (insn >> 29) & 1;
        const int shift12 = (insn >> 22) & 1;
        const uint64_t imm12 = (insn >> 10) & 0xFFFU;
        const unsigned rn = (insn >> 5) & 31U;
        const unsigned rd = insn & 31U;
        if (set_flags) return stop(rt, VK_STOP_ILLEGAL_INSTRUCTION);
        uint64_t lhs = read_gpr(&rt->cpu, rn, 1);
        uint64_t rhs = imm12 << (shift12 ? 12 : 0);
        uint64_t result = subtract ? lhs - rhs : lhs + rhs;
        write_gpr(&rt->cpu, rd, result, is64, 1);
        rt->cpu.pc = pc + 4;
        return 0;
    }

    /* B / BL immediate. */
    if ((insn & 0x7C000000U) == 0x14000000U) {
        const int link = (insn >> 31) & 1;
        const int64_t offset = sign_extend(insn & 0x03FFFFFFU, 26) << 2;
        if (link) rt->cpu.x[30] = pc + 4;
        rt->cpu.pc = (uint64_t)((int64_t)pc + offset);
        return 0;
    }

    /* BR Xn */
    if ((insn & 0xFFFFFC1FU) == 0xD61F0000U) {
        const unsigned rn = (insn >> 5) & 31U;
        rt->cpu.pc = read_gpr(&rt->cpu, rn, 0);
        return 0;
    }

    /* RET Xn */
    if ((insn & 0xFFFFFC1FU) == 0xD65F0000U) {
        const unsigned rn = (insn >> 5) & 31U;
        rt->cpu.pc = read_gpr(&rt->cpu, rn, 0);
        return 0;
    }

    /* STR/LDR Xt, [Xn, #imm12 * 8] */
    if ((insn & 0xFFC00000U) == 0xF9000000U ||
        (insn & 0xFFC00000U) == 0xF9400000U) {
        const int load = (insn & 0x00400000U) != 0;
        const uint64_t imm = ((insn >> 10) & 0xFFFU) * 8ULL;
        const unsigned rn = (insn >> 5) & 31U;
        const unsigned rtreg = insn & 31U;
        const uint64_t address = read_gpr(&rt->cpu, rn, 1) + imm;
        if (!range_ok(rt, address, 8)) return stop(rt, VK_STOP_MEMORY_FAULT);
        if (load) {
            write_gpr(&rt->cpu, rtreg, load_le64(rt->memory + address), 1, 0);
        } else {
            store_le64(rt->memory + address, read_gpr(&rt->cpu, rtreg, 0));
        }
        rt->cpu.pc = pc + 4;
        return 0;
    }

    /* STR/LDR Wt, [Xn, #imm12 * 4] */
    if ((insn & 0xFFC00000U) == 0xB9000000U ||
        (insn & 0xFFC00000U) == 0xB9400000U) {
        const int load = (insn & 0x00400000U) != 0;
        const uint64_t imm = ((insn >> 10) & 0xFFFU) * 4ULL;
        const unsigned rn = (insn >> 5) & 31U;
        const unsigned rtreg = insn & 31U;
        const uint64_t address = read_gpr(&rt->cpu, rn, 1) + imm;
        if (!range_ok(rt, address, 4)) return stop(rt, VK_STOP_MEMORY_FAULT);
        if (load) {
            write_gpr(&rt->cpu, rtreg, load_le32(rt->memory + address), 0, 0);
        } else {
            store_le32(rt->memory + address, (uint32_t)read_gpr(&rt->cpu, rtreg, 0));
        }
        rt->cpu.pc = pc + 4;
        return 0;
    }

    return stop(rt, VK_STOP_ILLEGAL_INSTRUCTION);
}

VKStopReason vk_runtime_run(VKRuntime *rt, uint64_t instruction_limit) {
    if (!rt) return VK_STOP_MEMORY_FAULT;
    if (rt->stop_reason != VK_STOP_NONE) return rt->stop_reason;
    for (uint64_t i = 0; i < instruction_limit; i++) {
        if (vk_runtime_step(rt) != 0) return rt->stop_reason;
    }
    rt->stop_reason = VK_STOP_INSTRUCTION_LIMIT;
    return rt->stop_reason;
}

VKStopReason vk_runtime_stop_reason(const VKRuntime *rt) {
    return rt ? rt->stop_reason : VK_STOP_MEMORY_FAULT;
}

uint32_t vk_runtime_last_instruction(const VKRuntime *rt) {
    return rt ? rt->last_instruction : 0;
}

uint64_t vk_runtime_instruction_count(const VKRuntime *rt) {
    return rt ? rt->instruction_count : 0;
}

const VKCPUState *vk_runtime_cpu(const VKRuntime *rt) {
    return rt ? &rt->cpu : NULL;
}

#if defined(__GNUC__)
__attribute__((used, visibility("default")))
#endif
const char *vk_runtime_build_marker(void) {
    return vk_build_marker;
}
