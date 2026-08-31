.section __TEXT,__text,regular,pure_instructions
.p2align 2
.globl _nyxian_entry
_nyxian_entry:
    adr x0, nyxian_entry_message
    mov x1, #30
    hvc #0x4e58

    // Draw a 64x96 RGBA8888 first frame into Nyxian guest memory.
    movz x0, #0x20, lsl #16
    movz w1, #0x40ff
    movk w1, #0xff20, lsl #16
    mov x2, #6144
nyxian_draw_frame:
    str w1, [x0]
    add x0, x0, #4
    sub x2, x2, #1
    cbnz x2, nyxian_draw_frame

    movz x0, #0x20, lsl #16
    mov x1, #64
    mov x2, #96
    mov x3, #256
    hvc #0x4e59

    adr x0, nyxinit
    msr elr_el1, x0
    msr spsr_el1, xzr
    eret

nyxinit:
    mrs x2, CurrentEL
    cbnz x2, nyxinit_wrong_el

    adr x0, nyxinit_started_message
    mov x1, #28
    mov x16, #0x7f00
    svc #0

    adr x0, userspace_hello_message
    mov x1, #28
    mov x16, #0x7f00
    svc #0
    wfi

nyxinit_wrong_el:
    hlt #1

nyxian_entry_message:
    .ascii "[NYXIAN] kernel entry reached\n"
nyxinit_started_message:
    .ascii "[NYXDARWIN] nyxinit started\n"
userspace_hello_message:
    .ascii "hello from Nyxian userspace\n"
.globl _nyxian_image_end
_nyxian_image_end:
