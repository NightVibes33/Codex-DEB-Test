#include "VPhoneKernelSurface.h"

#include <errno.h>
#include <stdlib.h>
#include <string.h>

struct VPKernelSurface {
    VPRuntime *runtime;
    VPProcessIdentity identity;
    uint64_t handled;
    uint64_t rejected;
    uint32_t mode;
    uint32_t build_type;
};

static uint64_t vp_errno_result(int value) {
    return (uint64_t)(int64_t)-value;
}

VPKernelSurface *vp_ksurface_create(VPRuntime *runtime) {
    if (!runtime) return NULL;
    VPKernelSurface *surface = (VPKernelSurface *)calloc(1, sizeof(VPKernelSurface));
    if (!surface) return NULL;
    surface->runtime = runtime;
    surface->identity.pid = 1;
    surface->identity.ppid = 0;
    surface->identity.uid = 0;
    surface->identity.gid = 0;
    surface->identity.euid = 0;
    surface->identity.egid = 0;
    surface->identity.task_handle = UINT64_C(0x4E595849414E0001);
    surface->mode = VP_KSURFACE_MODE_NORMAL;
#ifdef DEBUG
    surface->build_type = VP_KSURFACE_BUILD_DEBUG;
#else
    surface->build_type = VP_KSURFACE_BUILD_RELEASE;
#endif
    return surface;
}

VPKernelSurface *vp_ksurface_attach(VPRuntime *runtime) {
    VPKernelSurface *surface = vp_ksurface_create(runtime);
    if (!surface) return NULL;
    vp_runtime_set_syscall_handler(runtime, vp_ksurface_handle_syscall, surface);
    return surface;
}

void vp_ksurface_destroy(VPKernelSurface *surface) {
    if (!surface) return;
    memset(surface, 0, sizeof(*surface));
    free(surface);
}

void vp_ksurface_set_identity(VPKernelSurface *surface, const VPProcessIdentity *identity) {
    if (!surface || !identity) return;
    surface->identity = *identity;
}

VPProcessIdentity vp_ksurface_identity(const VPKernelSurface *surface) {
    VPProcessIdentity empty;
    memset(&empty, 0, sizeof(empty));
    return surface ? surface->identity : empty;
}

uint64_t vp_ksurface_syscalls_handled(const VPKernelSurface *surface) {
    return surface ? surface->handled : 0;
}

uint64_t vp_ksurface_syscalls_rejected(const VPKernelSurface *surface) {
    return surface ? surface->rejected : 0;
}

static VPStatus vp_pectl(VPKernelSurface *surface, const uint64_t args[8], uint64_t *result) {
    const uint64_t category = args ? args[0] : UINT64_MAX;
    const uint64_t operation = args ? args[1] : UINT64_MAX;

    if (category == VP_PECTL_CATEGORY_USERSPACE && operation == VP_PECTL_USERSPACE_GETMODE) {
        *result = surface->mode;
        return VP_STATUS_OK;
    }
    if (category == VP_PECTL_CATEGORY_MISC && operation == VP_PECTL_MISC_GETBUILDTYPE) {
        *result = surface->build_type;
        return VP_STATUS_OK;
    }
    if (category == VP_PECTL_CATEGORY_USERSPACE && operation == VP_PECTL_USERSPACE_REBOOT) {
        *result = vp_errno_result(EPERM);
        return VP_STATUS_OK;
    }

    *result = vp_errno_result(ENOTSUP);
    return VP_STATUS_OK;
}

VPStatus vp_ksurface_handle_syscall(
    VPRuntime *runtime,
    uint64_t number,
    const uint64_t args[8],
    uint64_t *result,
    void *context
) {
    VPKernelSurface *surface = (VPKernelSurface *)context;
    if (!runtime || !surface || surface->runtime != runtime || !result) {
        return VP_STATUS_INVALID_ARGUMENT;
    }

    switch (number) {
        case VP_DARWIN_SYS_GETPID:
            *result = (uint64_t)(uint32_t)surface->identity.pid;
            break;
        case VP_DARWIN_SYS_GETUID:
            *result = surface->identity.uid;
            break;
        case VP_DARWIN_SYS_GETEUID:
            *result = surface->identity.euid;
            break;
        case VP_DARWIN_SYS_GETGID:
            *result = surface->identity.gid;
            break;
        case VP_DARWIN_SYS_GETEGID:
            *result = surface->identity.egid;
            break;
        case VP_NYX_SYS_GETTASK:
        case VP_NYX_SYS_WAITTASK:
            *result = surface->identity.task_handle;
            break;
        case VP_NYX_SYS_PECTL:
            surface->handled++;
            return vp_pectl(surface, args, result);
        case VP_NYX_SYS_PROCPATH:
        case VP_NYX_SYS_HANDOFFEP:
        case VP_NYX_SYS_SIGN:
            *result = vp_errno_result(ENOTSUP);
            surface->rejected++;
            return VP_STATUS_OK;
        default:
            *result = vp_errno_result(ENOSYS);
            surface->rejected++;
            return VP_STATUS_OK;
    }

    surface->handled++;
    return VP_STATUS_OK;
}
