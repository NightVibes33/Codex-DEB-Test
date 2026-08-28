#include <arpa/inet.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

#define IFNAMSIZ_LOCAL 16
#define APPLE80211_IOC_CARD_SPECIFIC 0xffffffffu
#define WLC_GET_MONITOR 107
#define WLC_SET_MONITOR 108

#pragma pack(push, 4)
struct apple80211req {
    char req_if_name[IFNAMSIZ_LOCAL];
    int32_t req_type;
    int32_t req_val;
    uint64_t req_len;
    void *req_data;
};
#pragma pack(pop)

#define SIOCSA80211 _IOW('i', 200, struct apple80211req)

static int broadcom_ioctl(const char *ifname, int command, int *value) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) {
        fprintf(stderr, "socket failed: %s\n", strerror(errno));
        return -1;
    }

    struct apple80211req req;
    memset(&req, 0, sizeof(req));
    strlcpy(req.req_if_name, ifname, sizeof(req.req_if_name));
    req.req_type = (int32_t)APPLE80211_IOC_CARD_SPECIFIC;
    req.req_val = command;
    req.req_len = sizeof(*value);
    req.req_data = value;

    errno = 0;
    int rc = ioctl(fd, SIOCSA80211, &req);
    int saved_errno = errno;
    close(fd);

    printf("ioctl command=%d request=0x%lx rc=%d errno=%d (%s) value=%d\n",
           command, (unsigned long)SIOCSA80211, rc, saved_errno,
           saved_errno ? strerror(saved_errno) : "ok", *value);
    return rc;
}

static int get_monitor(const char *ifname) {
    int value = 0;
    int rc = broadcom_ioctl(ifname, WLC_GET_MONITOR, &value);
    if (rc == 0) printf("monitor_value=%d\n", value);
    return rc;
}

static int set_monitor(const char *ifname, int enabled) {
    int value = enabled ? 1 : 0;
    int rc = broadcom_ioctl(ifname, WLC_SET_MONITOR, &value);
    if (rc == 0) printf("monitor_set=%d\n", enabled ? 1 : 0);
    return rc;
}

static void usage(const char *argv0) {
    fprintf(stderr, "usage: %s [en0] get|on|off|pulse [seconds]\n", argv0);
}

int main(int argc, char **argv) {
    const char *ifname = "en0";
    const char *cmd = NULL;
    int argi = 1;

    if (argc > 2 && argv[1][0] != '-') {
        ifname = argv[1];
        argi = 2;
    }
    if (argc <= argi) {
        usage(argv[0]);
        return 2;
    }
    cmd = argv[argi];

    printf("rfmonctl interface=%s sizeof_req=%zu SIOCSA80211=0x%lx\n",
           ifname, sizeof(struct apple80211req), (unsigned long)SIOCSA80211);

    if (strcmp(cmd, "get") == 0) return get_monitor(ifname) == 0 ? 0 : 1;
    if (strcmp(cmd, "on") == 0) return set_monitor(ifname, 1) == 0 ? 0 : 1;
    if (strcmp(cmd, "off") == 0) return set_monitor(ifname, 0) == 0 ? 0 : 1;
    if (strcmp(cmd, "pulse") == 0) {
        int seconds = 2;
        if (argc > argi + 1) {
            seconds = atoi(argv[argi + 1]);
            if (seconds < 1) seconds = 1;
            if (seconds > 10) seconds = 10;
        }
        int rc_on = set_monitor(ifname, 1);
        if (rc_on != 0) return 1;
        printf("monitor_pulse_seconds=%d\n", seconds);
        fflush(stdout);
        sleep((unsigned)seconds);
        int rc_off = set_monitor(ifname, 0);
        return rc_off == 0 ? 0 : 1;
    }

    usage(argv[0]);
    return 2;
}
