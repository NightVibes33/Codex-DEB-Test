.section __TEXT,__text,regular,pure_instructions
.p2align 2
.globl _nyxian_entry
_nyxian_entry:
    adr x0, nyxian_entry_message
    mov x1, #nyxian_entry_message_end - nyxian_entry_message
    hvc #0x4e58
    hlt #0

nyxian_entry_message:
    .ascii "[NYXIAN] kernel entry reached\n"
nyxian_entry_message_end:
.globl _nyxian_image_end
_nyxian_image_end:
