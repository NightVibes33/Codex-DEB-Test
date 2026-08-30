#include "../Runtime/VibeKernel.h"

#include <stdint.h>
#include <stdio.h>

static void put32le(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)v;
    p[1] = (uint8_t)(v >> 8);
    p[2] = (uint8_t)(v >> 16);
    p[3] = (uint8_t)(v >> 24);
}

int main(void) {
    uint8_t program[20];

    /* movz x0, #42 */
    put32le(program + 0, 0xD2800540U);
    /* add x0, x0, #8 */
    put32le(program + 4, 0x91002000U);
    /* str x0, [x1] */
    put32le(program + 8, 0xF9000020U);
    /* ldr x2, [x1] */
    put32le(program + 12, 0xF9400022U);
    /* svc #0 */
    put32le(program + 16, 0xD4000001U);

    VKRuntime *rt = vk_runtime_create(4096);
    if (!rt) return 10;
    if (vk_runtime_load(rt, program, sizeof(program), 0) != 0) return 11;
    if (vk_runtime_reset(rt, 0, 4096) != 0) return 12;
    if (vk_runtime_set_reg(rt, 1, 0x100) != 0) return 13;

    VKStopReason reason = vk_runtime_run(rt, 32);
    uint64_t result = vk_runtime_get_reg(rt, 2);

    printf("%s\n", vk_runtime_build_marker());
    printf("stop=%d instructions=%llu x2=%llu\n",
           (int)reason,
           (unsigned long long)vk_runtime_instruction_count(rt),
           (unsigned long long)result);

    vk_runtime_destroy(rt);

    if (reason != VK_STOP_SVC) return 20;
    if (result != 50) return 21;
    return 0;
}
