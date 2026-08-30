#include "NyxRuntime.h"

const char *nyx_runtime_version(void) {
    return "NyxRuntime/0.1-interpreter";
}

unsigned int nyx_runtime_abi_version(void) {
    return NYX_RUNTIME_ABI_VERSION;
}
