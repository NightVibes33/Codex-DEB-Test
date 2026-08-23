#ifndef TWEAKMEDIC_COMPAT_LIBPROC_H
#define TWEAKMEDIC_COMPAT_LIBPROC_H

#include <dlfcn.h>
#include <stdint.h>

#ifndef PROC_PIDPATHINFO_MAXSIZE
#define PROC_PIDPATHINFO_MAXSIZE 4096
#endif

/*
 * The stripped-down Theos iPhoneOS SDK used by CI does not provide
 * <libproc.h>, although libproc is present on the target OS. Resolve the two
 * routines TweakMedic needs at runtime so the daemon keeps exact executable
 * path matching without taking a build-time libproc dependency.
 */
static inline void *tm_libproc_handle(void) {
    static void *handle = NULL;
    if (!handle) {
        handle = dlopen("/usr/lib/libproc.dylib", RTLD_LAZY | RTLD_LOCAL);
        if (!handle) handle = dlopen("/usr/lib/system/libsystem_kernel.dylib", RTLD_LAZY | RTLD_LOCAL);
    }
    return handle;
}

static inline int proc_listallpids(void *buffer, int buffersize) {
    typedef int (*fn_t)(void *, int);
    static fn_t fn = NULL;
    if (!fn) {
        void *handle = tm_libproc_handle();
        if (handle) fn = (fn_t)dlsym(handle, "proc_listallpids");
    }
    return fn ? fn(buffer, buffersize) : -1;
}

static inline int proc_pidpath(int pid, void *buffer, uint32_t buffersize) {
    typedef int (*fn_t)(int, void *, uint32_t);
    static fn_t fn = NULL;
    if (!fn) {
        void *handle = tm_libproc_handle();
        if (handle) fn = (fn_t)dlsym(handle, "proc_pidpath");
    }
    return fn ? fn(pid, buffer, buffersize) : 0;
}

#endif
