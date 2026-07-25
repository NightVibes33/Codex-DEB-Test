#ifndef GIF2ANI_MINIMAL_XPC_H
#define GIF2ANI_MINIMAL_XPC_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *xpc_object_t;
typedef void *xpc_connection_t;
typedef const struct _xpc_type_s *xpc_type_t;
typedef void *dispatch_queue_t;
typedef void (^xpc_handler_t)(xpc_object_t event);

extern const struct _xpc_type_s _xpc_type_error;
#define XPC_TYPE_ERROR ((xpc_type_t)&_xpc_type_error)
#define XPC_ERROR_KEY_DESCRIPTION "XPCErrorDescription"

xpc_connection_t xpc_connection_create_mach_service(
    const char *name,
    dispatch_queue_t targetq,
    uint64_t flags
);
void xpc_connection_set_event_handler(xpc_connection_t connection, xpc_handler_t handler);
void xpc_connection_activate(xpc_connection_t connection);
void xpc_connection_cancel(xpc_connection_t connection);
xpc_object_t xpc_connection_send_message_with_reply_sync(
    xpc_connection_t connection,
    xpc_object_t message
);

xpc_object_t xpc_dictionary_create(
    const char * const *keys,
    const xpc_object_t *values,
    size_t count
);
void xpc_dictionary_set_uint64(xpc_object_t dictionary, const char *key, uint64_t value);
int64_t xpc_dictionary_get_int64(xpc_object_t dictionary, const char *key);
const char *xpc_dictionary_get_string(xpc_object_t dictionary, const char *key);

xpc_type_t xpc_get_type(xpc_object_t object);
void xpc_release(xpc_object_t object);

#ifdef __cplusplus
}
#endif

#endif
