#include "NyxRuntime.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char logs[4096];
static size_t logs_length;

static void capture(const uint8_t *bytes, size_t length, void *context) {
    (void)context;
    size_t available = sizeof(logs) - 1 - logs_length;
    if (length > available) length = available;
    memcpy(logs + logs_length, bytes, length);
    logs_length += length;
    logs[logs_length] = 0;
}

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    FILE *file = fopen(argv[1], "rb");
    if (!file) return 3;
    if (fseek(file, 0, SEEK_END) != 0) return 4;
    long file_size = ftell(file);
    if (file_size <= 0 || fseek(file, 0, SEEK_SET) != 0) return 5;
    uint8_t *image = (uint8_t *)malloc((size_t)file_size);
    if (!image) return 6;
    if (fread(image, 1, (size_t)file_size, file) != (size_t)file_size) return 7;
    fclose(file);

    NyxVMConfig config = {1, 16u * 1024u * 1024u, 1290, 2796, 460, 3.0};
    NyxVM *vm = nyx_vm_create(&config);
    if (!vm) return 8;
    nyx_vm_set_log_callback(vm, capture, NULL);
    if (nyx_vm_load_kernel_bytes(vm, image, (size_t)file_size, 0x100000, 0x100000) != 0) return 9;
    if (nyx_vm_start(vm) != 0) return 10;
    if (nyx_vm_instructions_retired(vm) < 4) return 11;
    if (!strstr(logs, "[NYXRT] runtime initialized")) return 12;
    if (!strstr(logs, "[NYXRT] Nyxian loaded")) return 13;
    if (!strstr(logs, "[NYXIAN] kernel entry reached")) return 14;
    fputs(logs, stdout);
    nyx_vm_destroy(vm);
    free(image);
    return 0;
}
