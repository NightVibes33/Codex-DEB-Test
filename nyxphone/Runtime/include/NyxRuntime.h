#ifndef NYX_RUNTIME_H
#define NYX_RUNTIME_H

#ifdef __cplusplus
extern "C" {
#endif

#define NYX_RUNTIME_ABI_VERSION 1u

/* Stable public identity used by Swift diagnostics and CI linkage checks. */
const char *nyx_runtime_version(void);
unsigned int nyx_runtime_abi_version(void);

#ifdef __cplusplus
}
#endif

#endif
