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

    // Request HTTPS through nyx0; DNS, TCP and TLS terminate in the native host transport.
    adr x0, network_test_url
    mov x1, #20
    movz x2, #0x50, lsl #16
    mov x3, #512
    mov x16, #0x7f20
    svc #0
    cbz x0, nyx_network_failed
    adr x0, network_complete_message
    mov x1, #32
    mov x16, #0x7f00
    svc #0
    b nyx_network_done
nyx_network_failed:
    adr x0, network_failed_message
    mov x1, #30
    mov x16, #0x7f00
    svc #0
nyx_network_done:

    // Mount the NyxBus block root and persist a boot counter at disk offset zero.
    movz x4, #0x40, lsl #16
    add x0, x4, #0
    mov x1, #0
    mov x2, #8
    mov x16, #0x7f10
    svc #0
    ldr x5, [x4]
    add x5, x5, #1
    str x5, [x4]
    add x0, x4, #0
    mov x1, #0
    mov x2, #8
    mov x16, #0x7f11
    svc #0
    mov x16, #0x7f12
    svc #0

    adr x0, storage_mounted_message
    mov x1, #26
    mov x16, #0x7f00
    svc #0

nyx_touch_wait:
    wfi
    movz x0, #0x30, lsl #16
    mov x16, #0x7f01
    svc #0
    cbz x0, nyx_touch_wait

    adr x0, touch_delivered_message
    mov x1, #27
    mov x16, #0x7f00
    svc #0

    movz x0, #0x20, lsl #16
    movz w1, #0xff40
    movk w1, #0xff20, lsl #16
    mov x2, #6144
nyxian_draw_touch_frame:
    str w1, [x0]
    add x0, x0, #4
    sub x2, x2, #1
    cbnz x2, nyxian_draw_touch_frame

    movz x0, #0x20, lsl #16
    mov x1, #64
    mov x2, #96
    mov x3, #256
    mov x16, #0x7f02
    svc #0
    b nyx_touch_wait

nyxinit_wrong_el:
    hlt #1

nyxian_entry_message:
    .ascii "[NYXIAN] kernel entry reached\n"
nyxinit_started_message:
    .ascii "[NYXDARWIN] nyxinit started\n"
userspace_hello_message:
    .ascii "hello from Nyxian userspace\n"
touch_delivered_message:
    .ascii "[NYXTOUCH] event delivered\n"
storage_mounted_message:
    .ascii "[NYXSTORAGE] root mounted\n"
network_test_url:
    .ascii "https://example.com/"
network_complete_message:
    .ascii "[NYXNET] HTTPS request complete\n"
network_failed_message:
    .ascii "[NYXNET] HTTPS request failed\n"
.globl _nyxian_image_end
_nyxian_image_end:
