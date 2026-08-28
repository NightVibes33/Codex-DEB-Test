#include <errno.h>
#include <fcntl.h>
#include <net/if.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#define IFNAMSIZ_LOCAL 16
#define APPLE80211_IOC_CARD_SPECIFIC 0xffffffffu
#define WLC_GET_MONITOR 107
#define WLC_SET_MONITOR 108

#define MONITOR_DISABLED 0
#define MONITOR_IEEE80211 1
#define MONITOR_RADIOTAP 2

#define DLT_EN10MB 1u
#define DLT_RAW 12u
#define DLT_IEEE802_11 105u
#define DLT_IEEE802_11_RADIO 127u

/* Darwin/XNU BPF ABI subset. iPhoneOS exposes /dev/bpf but not net/bpf.h. */
struct timeval32_local {
    int32_t tv_sec;
    int32_t tv_usec;
};

struct bpf_hdr_local {
    struct timeval32_local bh_tstamp;
    uint32_t bh_caplen;
    uint32_t bh_datalen;
    uint16_t bh_hdrlen;
};

#pragma pack(push, 4)
struct bpf_dltlist_local {
    uint32_t bfl_len;
    union {
        uint32_t *bflu_list;
        uint64_t bflu_pad;
    } bfl_u;
};
#pragma pack(pop)
#define bfl_list bfl_u.bflu_list

#define BPF_ALIGNMENT ((size_t)sizeof(int32_t))
#define BPF_WORDALIGN_LOCAL(x) (((x) + (BPF_ALIGNMENT - 1)) & ~(BPF_ALIGNMENT - 1))
#define BPF_HDR_MIN_SIZE 18u
#define BIOCGBLEN       _IOR('B', 102, unsigned int)
#define BIOCPROMISC     _IO('B', 105)
#define BIOCGDLT        _IOR('B', 106, unsigned int)
#define BIOCSETIF       _IOW('B', 108, struct ifreq)
#define BIOCIMMEDIATE   _IOW('B', 112, unsigned int)
#define BIOCSDLT        _IOW('B', 120, unsigned int)
#define BIOCGDLTLIST    _IOWR('B', 121, struct bpf_dltlist_local)

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

struct pcap_file_header_local {
    uint32_t magic;
    uint16_t version_major;
    uint16_t version_minor;
    int32_t thiszone;
    uint32_t sigfigs;
    uint32_t snaplen;
    uint32_t network;
};

struct pcap_packet_header_local {
    uint32_t ts_sec;
    uint32_t ts_usec;
    uint32_t incl_len;
    uint32_t orig_len;
};

static volatile sig_atomic_t stop_capture = 0;

static void stop_handler(int sig) {
    (void)sig;
    stop_capture = 1;
}

static int broadcom_ioctl(const char *ifname, int command, int *value) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) {
        fprintf(stderr, "socket failed: errno=%d (%s)\n", errno, strerror(errno));
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

static int get_monitor_value(const char *ifname, int *out_value) {
    int value = 0;
    int rc = broadcom_ioctl(ifname, WLC_GET_MONITOR, &value);
    if (rc == 0) {
        printf("monitor_value=%d\n", value);
        if (out_value) *out_value = value;
    }
    return rc;
}

static int set_monitor_value(const char *ifname, int mode) {
    int value = mode;
    int rc = broadcom_ioctl(ifname, WLC_SET_MONITOR, &value);
    if (rc == 0) printf("monitor_set=%d\n", mode);
    return rc;
}

static int open_bpf_device(char *chosen, size_t chosen_len) {
    int last_errno = ENOENT;
    for (int i = 0; i < 256; i++) {
        char path[32];
        snprintf(path, sizeof(path), "/dev/bpf%d", i);
        int fd = open(path, O_RDWR);
        if (fd >= 0) {
            strlcpy(chosen, path, chosen_len);
            return fd;
        }
        last_errno = errno;
        if (errno == ENOENT && i > 16) break;
    }
    errno = last_errno;
    return -1;
}

static int bpf_get_dlt(int fd, unsigned int *dlt) {
    if (ioctl(fd, BIOCGDLT, dlt) < 0) {
        fprintf(stderr, "BIOCGDLT failed: errno=%d (%s)\n", errno, strerror(errno));
        return -1;
    }
    return 0;
}

static int bpf_set_dlt(int fd, unsigned int dlt) {
    unsigned int value = dlt;
    errno = 0;
    int rc = ioctl(fd, BIOCSDLT, &value);
    int saved_errno = errno;
    printf("BIOCSDLT candidate=%u rc=%d errno=%d (%s)\n",
           dlt, rc, saved_errno, saved_errno ? strerror(saved_errno) : "ok");
    if (rc < 0) return -1;

    unsigned int got = 0;
    if (bpf_get_dlt(fd, &got) < 0) return -1;
    printf("bpf_selected_dlt=%u\n", got);
    return got == dlt ? 0 : -1;
}

static int bpf_get_dlt_list(int fd, uint32_t **list_out, uint32_t *count_out) {
    struct bpf_dltlist_local dl;
    memset(&dl, 0, sizeof(dl));
    if (ioctl(fd, BIOCGDLTLIST, &dl) < 0 || dl.bfl_len == 0 || dl.bfl_len > 256) {
        fprintf(stderr, "BIOCGDLTLIST(count) failed: errno=%d (%s) len=%u\n",
                errno, strerror(errno), dl.bfl_len);
        return -1;
    }

    uint32_t *list = calloc(dl.bfl_len, sizeof(uint32_t));
    if (!list) return -1;

    uint32_t capacity = dl.bfl_len;
    dl.bfl_list = list;
    dl.bfl_len = capacity;
    if (ioctl(fd, BIOCGDLTLIST, &dl) < 0) {
        fprintf(stderr, "BIOCGDLTLIST(data) failed: errno=%d (%s)\n", errno, strerror(errno));
        free(list);
        return -1;
    }

    printf("bpf_available_dlt_count=%u bpf_available_dlts=", dl.bfl_len);
    for (uint32_t i = 0; i < dl.bfl_len; i++) {
        printf("%s%u", i ? "," : "", list[i]);
    }
    printf("\n");

    *list_out = list;
    *count_out = dl.bfl_len;
    return 0;
}

static int dlt_in_list(const uint32_t *list, uint32_t count, uint32_t dlt) {
    for (uint32_t i = 0; i < count; i++) {
        if (list[i] == dlt) return 1;
    }
    return 0;
}

static int bind_bpf(int fd, const char *ifname, uint32_t **dlts_out,
                    uint32_t *dlt_count_out, unsigned int *blen_out) {
    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));

    if (ioctl(fd, BIOCSETIF, &ifr) < 0) {
        fprintf(stderr, "BIOCSETIF(%s) failed: errno=%d (%s)\n",
                ifname, errno, strerror(errno));
        return -1;
    }

    unsigned int initial = 0;
    if (bpf_get_dlt(fd, &initial) == 0) printf("bpf_initial_dlt=%u\n", initial);
    if (bpf_get_dlt_list(fd, dlts_out, dlt_count_out) < 0) return -1;

    unsigned int one = 1;
    if (ioctl(fd, BIOCIMMEDIATE, &one) < 0) {
        fprintf(stderr, "BIOCIMMEDIATE failed: errno=%d (%s)\n", errno, strerror(errno));
    }
    if (ioctl(fd, BIOCPROMISC, NULL) < 0) {
        fprintf(stderr, "BIOCPROMISC failed: errno=%d (%s)\n", errno, strerror(errno));
    }

    unsigned int blen = 0;
    if (ioctl(fd, BIOCGBLEN, &blen) < 0 || blen == 0) {
        fprintf(stderr, "BIOCGBLEN failed: errno=%d (%s)\n", errno, strerror(errno));
        free(*dlts_out);
        *dlts_out = NULL;
        return -1;
    }

    *blen_out = blen;
    return 0;
}

static int write_pcap_header(FILE *fp, unsigned int dlt) {
    struct pcap_file_header_local h;
    memset(&h, 0, sizeof(h));
    h.magic = 0xa1b2c3d4u;
    h.version_major = 2;
    h.version_minor = 4;
    h.snaplen = 65535u;
    h.network = dlt;
    return fwrite(&h, sizeof(h), 1, fp) == 1 ? 0 : -1;
}

static int capture_monitor(const char *ifname, const char *outfile, int seconds) {
    if (seconds < 1) seconds = 1;
    if (seconds > 20) seconds = 20;

    printf("capture_sequence=dlt127-plus-wlc-monitor-mode2\n");
    printf("capture_interface=%s capture_file=%s capture_seconds=%d\n",
           ifname, outfile, seconds);

    int result = 0;
    int monitor_before = 0;
    if (get_monitor_value(ifname, &monitor_before) != 0) return 1;
    if (monitor_before != MONITOR_DISABLED) {
        printf("capture_preflight=forcing-monitor-off\n");
        if (set_monitor_value(ifname, MONITOR_DISABLED) != 0) return 1;
        usleep(300000);
    }

    char bpf_path[32] = {0};
    int bpf = open_bpf_device(bpf_path, sizeof(bpf_path));
    if (bpf < 0) {
        fprintf(stderr, "open_bpf_device failed: errno=%d (%s)\n", errno, strerror(errno));
        return 1;
    }
    printf("bpf_device=%s\n", bpf_path);

    uint32_t *dlts = NULL;
    uint32_t dlt_count = 0;
    unsigned int blen = 0;
    if (bind_bpf(bpf, ifname, &dlts, &dlt_count, &blen) != 0) {
        close(bpf);
        return 1;
    }

    unsigned int wireless_dlt = 0;
    int monitor_mode = MONITOR_DISABLED;
    if (dlt_in_list(dlts, dlt_count, DLT_IEEE802_11_RADIO)) {
        wireless_dlt = DLT_IEEE802_11_RADIO;
        monitor_mode = MONITOR_RADIOTAP;
    } else if (dlt_in_list(dlts, dlt_count, DLT_IEEE802_11)) {
        wireless_dlt = DLT_IEEE802_11;
        monitor_mode = MONITOR_IEEE80211;
    } else {
        fprintf(stderr, "No 802.11 BPF DLT exposed by %s\n", ifname);
        free(dlts);
        close(bpf);
        return 1;
    }

    printf("capture_wireless_dlt=%u monitor_mode_request=%d\n",
           wireless_dlt, monitor_mode);
    if (bpf_set_dlt(bpf, wireless_dlt) != 0) {
        free(dlts);
        close(bpf);
        return 1;
    }

    if (set_monitor_value(ifname, monitor_mode) != 0) {
        fprintf(stderr, "WLC_SET_MONITOR mode %d failed\n", monitor_mode);
        if (dlt_in_list(dlts, dlt_count, DLT_EN10MB)) bpf_set_dlt(bpf, DLT_EN10MB);
        free(dlts);
        close(bpf);
        return 1;
    }
    usleep(500000);

    int live_monitor = -1;
    if (get_monitor_value(ifname, &live_monitor) != 0) {
        result = 1;
    } else {
        printf("capture_monitor_live=%d expected=%d\n", live_monitor, monitor_mode);
        if (live_monitor != monitor_mode) result = 1;
    }

    printf("bpf_dlt=%u bpf_buffer_length=%u\n", wireless_dlt, blen);

    FILE *fp = fopen(outfile, "wb");
    if (!fp) {
        fprintf(stderr, "fopen(%s) failed: errno=%d (%s)\n", outfile, errno, strerror(errno));
        result = 1;
        goto cleanup_bpf;
    }
    if (write_pcap_header(fp, wireless_dlt) != 0) {
        fprintf(stderr, "write PCAP header failed\n");
        fclose(fp);
        result = 1;
        goto cleanup_bpf;
    }

    unsigned char *buf = malloc(blen);
    if (!buf) {
        fclose(fp);
        result = 1;
        goto cleanup_bpf;
    }

    stop_capture = 0;
    signal(SIGINT, stop_handler);
    signal(SIGTERM, stop_handler);

    struct timeval start, now;
    gettimeofday(&start, NULL);
    uint64_t packets = 0;
    uint64_t payload_bytes = 0;

    while (!stop_capture) {
        gettimeofday(&now, NULL);
        double elapsed = (double)(now.tv_sec - start.tv_sec) +
                         (double)(now.tv_usec - start.tv_usec) / 1000000.0;
        if (elapsed >= (double)seconds) break;

        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(bpf, &rfds);
        struct timeval tv = {0, 250000};
        int sr = select(bpf + 1, &rfds, NULL, NULL, &tv);
        if (sr < 0) {
            if (errno == EINTR) continue;
            fprintf(stderr, "select failed: errno=%d (%s)\n", errno, strerror(errno));
            result = 1;
            break;
        }
        if (sr == 0) continue;

        ssize_t n = read(bpf, buf, blen);
        if (n < 0) {
            if (errno == EINTR) continue;
            fprintf(stderr, "bpf read failed: errno=%d (%s)\n", errno, strerror(errno));
            result = 1;
            break;
        }

        unsigned char *ptr = buf;
        unsigned char *end = buf + n;
        while ((size_t)(end - ptr) >= BPF_HDR_MIN_SIZE) {
            const struct bpf_hdr_local *bh = (const struct bpf_hdr_local *)ptr;
            size_t hdrlen = (size_t)bh->bh_hdrlen;
            size_t caplen = (size_t)bh->bh_caplen;
            if (hdrlen < BPF_HDR_MIN_SIZE || hdrlen > (size_t)(end - ptr)) break;
            if (caplen > (size_t)(end - ptr) - hdrlen) break;

            struct pcap_packet_header_local ph;
            ph.ts_sec = (uint32_t)bh->bh_tstamp.tv_sec;
            ph.ts_usec = (uint32_t)bh->bh_tstamp.tv_usec;
            ph.incl_len = bh->bh_caplen;
            ph.orig_len = bh->bh_datalen;

            if (fwrite(&ph, sizeof(ph), 1, fp) != 1 ||
                (caplen != 0 && fwrite(ptr + hdrlen, caplen, 1, fp) != 1)) {
                fprintf(stderr, "PCAP packet write failed\n");
                result = 1;
                stop_capture = 1;
                break;
            }

            packets++;
            payload_bytes += caplen;
            size_t advance = BPF_WORDALIGN_LOCAL(hdrlen + caplen);
            if (advance == 0 || advance > (size_t)(end - ptr)) break;
            ptr += advance;
        }
        fflush(fp);
    }

    free(buf);
    fclose(fp);
    printf("capture_packets=%llu capture_payload_bytes=%llu capture_dlt=%u\n",
           (unsigned long long)packets,
           (unsigned long long)payload_bytes,
           wireless_dlt);

cleanup_bpf:
    printf("capture_monitor_restore=wlc-mode-0\n");
    int off_rc = set_monitor_value(ifname, MONITOR_DISABLED);
    printf("capture_monitor_off_rc=%d\n", off_rc);
    if (off_rc != 0) result = 1;

    if (dlt_in_list(dlts, dlt_count, DLT_EN10MB)) {
        bpf_set_dlt(bpf, DLT_EN10MB);
    } else if (dlt_in_list(dlts, dlt_count, DLT_RAW)) {
        bpf_set_dlt(bpf, DLT_RAW);
    }

    free(dlts);
    close(bpf);
    usleep(300000);

    int final_monitor = -1;
    if (get_monitor_value(ifname, &final_monitor) == 0) {
        printf("capture_final_monitor=%d\n", final_monitor);
        if (final_monitor != MONITOR_DISABLED) result = 1;
    } else {
        result = 1;
    }

    return result;
}

static void usage(const char *p) {
    fprintf(stderr,
            "usage: %s [en0] get|off|on|raw|mode <value>\n"
            "       %s [en0] pulse [seconds] [mode]\n"
            "       %s [en0] capture <output.pcap> [seconds]\n",
            p, p, p);
}

int main(int argc, char **argv) {
    const char *ifname = "en0";
    int argi = 1;

    if (argc > 2 && argv[1][0] != '-') {
        ifname = argv[1];
        argi = 2;
    }
    if (argc <= argi) {
        usage(argv[0]);
        return 2;
    }

    const char *cmd = argv[argi];
    printf("rfmonctl interface=%s sizeof_req=%zu SIOCSA80211=0x%lx\n",
           ifname, sizeof(struct apple80211req), (unsigned long)SIOCSA80211);

    if (!strcmp(cmd, "get")) {
        return get_monitor_value(ifname, NULL) == 0 ? 0 : 1;
    }
    if (!strcmp(cmd, "off")) {
        return set_monitor_value(ifname, MONITOR_DISABLED) == 0 ? 0 : 1;
    }
    if (!strcmp(cmd, "on")) {
        return set_monitor_value(ifname, MONITOR_RADIOTAP) == 0 ? 0 : 1;
    }
    if (!strcmp(cmd, "raw")) {
        return set_monitor_value(ifname, MONITOR_IEEE80211) == 0 ? 0 : 1;
    }
    if (!strcmp(cmd, "mode")) {
        if (argc <= argi + 1) {
            usage(argv[0]);
            return 2;
        }
        int mode = atoi(argv[argi + 1]);
        if (mode < 0 || mode > 5) {
            fprintf(stderr, "monitor mode must be 0..5\n");
            return 2;
        }
        return set_monitor_value(ifname, mode) == 0 ? 0 : 1;
    }
    if (!strcmp(cmd, "pulse")) {
        int seconds = argc > argi + 1 ? atoi(argv[argi + 1]) : 2;
        int mode = argc > argi + 2 ? atoi(argv[argi + 2]) : MONITOR_RADIOTAP;
        if (seconds < 1) seconds = 1;
        if (seconds > 10) seconds = 10;
        if (mode < 1 || mode > 5) mode = MONITOR_RADIOTAP;
        if (set_monitor_value(ifname, mode) != 0) return 1;
        sleep((unsigned)seconds);
        return set_monitor_value(ifname, MONITOR_DISABLED) == 0 ? 0 : 1;
    }
    if (!strcmp(cmd, "capture")) {
        if (argc <= argi + 1) {
            usage(argv[0]);
            return 2;
        }
        int seconds = argc > argi + 2 ? atoi(argv[argi + 2]) : 4;
        return capture_monitor(ifname, argv[argi + 1], seconds);
    }

    usage(argv[0]);
    return 2;
}
