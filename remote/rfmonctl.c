#include <arpa/inet.h>
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
#define DLT_EN10MB 1u
#define DLT_RAW 12u
#define DLT_IEEE802_11 105u
#define DLT_IEEE802_11_RADIO 127u

/* Darwin/XNU BPF ABI subset; iPhoneOS exposes /dev/bpf but hides net/bpf.h. */
struct timeval32_local { int32_t tv_sec; int32_t tv_usec; };
struct bpf_hdr_local {
    struct timeval32_local bh_tstamp;
    uint32_t bh_caplen;
    uint32_t bh_datalen;
    uint16_t bh_hdrlen;
};
#pragma pack(push, 4)
struct bpf_dltlist_local {
    uint32_t bfl_len;
    union { uint32_t *bflu_list; uint64_t bflu_pad; } bfl_u;
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
static void stop_handler(int sig) { (void)sig; stop_capture = 1; }

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

static int get_monitor_value(const char *ifname, int *out_value) {
    int value = 0;
    int rc = broadcom_ioctl(ifname, WLC_GET_MONITOR, &value);
    if (rc == 0) {
        printf("monitor_value=%d\n", value);
        if (out_value) *out_value = value;
    }
    return rc;
}
static int get_monitor(const char *ifname) { return get_monitor_value(ifname, NULL); }
static int set_monitor(const char *ifname, int enabled) {
    int value = enabled ? 1 : 0;
    int rc = broadcom_ioctl(ifname, WLC_SET_MONITOR, &value);
    if (rc == 0) printf("monitor_set=%d\n", value);
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
    for (uint32_t i = 0; i < dl.bfl_len; i++) printf("%s%u", i ? "," : "", list[i]);
    printf("\n");
    *list_out = list;
    *count_out = dl.bfl_len;
    return 0;
}

static int dlt_in_list(const uint32_t *list, uint32_t count, uint32_t dlt) {
    for (uint32_t i = 0; i < count; i++) if (list[i] == dlt) return 1;
    return 0;
}

static int bpf_set_dlt(int fd, unsigned int dlt) {
    unsigned int value = dlt;
    errno = 0;
    int rc = ioctl(fd, BIOCSDLT, &value);
    printf("BIOCSDLT candidate=%u rc=%d errno=%d (%s)\n",
           value, rc, errno, errno ? strerror(errno) : "ok");
    if (rc < 0) return -1;
    unsigned int got = 0;
    if (bpf_get_dlt(fd, &got) < 0) return -1;
    printf("bpf_selected_dlt=%u\n", got);
    return got == dlt ? 0 : -1;
}

static int bind_bpf_station(int fd, const char *ifname, uint32_t **dlts_out,
                            uint32_t *dlt_count_out, unsigned int *blen_out) {
    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
    if (ioctl(fd, BIOCSETIF, &ifr) < 0) {
        fprintf(stderr, "BIOCSETIF(%s) failed: errno=%d (%s)\n", ifname, errno, strerror(errno));
        return -1;
    }
    unsigned int initial = 0;
    if (bpf_get_dlt(fd, &initial) == 0) printf("bpf_initial_dlt=%u\n", initial);
    if (bpf_get_dlt_list(fd, dlts_out, dlt_count_out) < 0) return -1;

    unsigned int one = 1;
    if (ioctl(fd, BIOCIMMEDIATE, &one) < 0)
        fprintf(stderr, "BIOCIMMEDIATE failed: errno=%d (%s)\n", errno, strerror(errno));
    if (ioctl(fd, BIOCPROMISC, NULL) < 0)
        fprintf(stderr, "BIOCPROMISC failed: errno=%d (%s)\n", errno, strerror(errno));

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
    struct pcap_file_header_local h = {0xa1b2c3d4u, 2, 4, 0, 0, 65535u, dlt};
    return fwrite(&h, sizeof(h), 1, fp) == 1 ? 0 : -1;
}

static int capture_monitor(const char *ifname, const char *outfile, int seconds) {
    if (seconds < 1) seconds = 1;
    if (seconds > 20) seconds = 20;
    printf("capture_sequence=apple-bpf-dlt-activates-monitor\n");
    printf("capture_interface=%s capture_file=%s capture_seconds=%d\n", ifname, outfile, seconds);

    /* Apple/libpcap sequence: start in station mode, bind BPF, then selecting
       an 802.11 DLT activates rfmon.  Do not pre-enable WLC monitor. */
    int initial_monitor = 0;
    if (get_monitor_value(ifname, &initial_monitor) != 0) return 1;
    if (initial_monitor != 0) {
        printf("capture_preflight=forcing-monitor-off\n");
        if (set_monitor(ifname, 0) != 0) return 1;
        usleep(300000);
    }

    char bpf_path[32] = {0};
    int bpf = open_bpf_device(bpf_path, sizeof(bpf_path));
    if (bpf < 0) {
        fprintf(stderr, "open_bpf_device failed: errno=%d (%s)\n", errno, strerror(errno));
        return 1;
    }
    printf("bpf_device=%s\n", bpf_path);

    uint32_t *dlts = NULL, dlt_count = 0;
    unsigned int blen = 0;
    if (bind_bpf_station(bpf, ifname, &dlts, &dlt_count, &blen) != 0) {
        close(bpf);
        return 1;
    }

    unsigned int wireless_dlt = 0;
    if (dlt_in_list(dlts, dlt_count, DLT_IEEE802_11_RADIO)) wireless_dlt = DLT_IEEE802_11_RADIO;
    else if (dlt_in_list(dlts, dlt_count, DLT_IEEE802_11)) wireless_dlt = DLT_IEEE802_11;
    if (!wireless_dlt) {
        fprintf(stderr, "No raw 802.11 BPF DLT exposed.\n");
        free(dlts); close(bpf); return 1;
    }

    printf("capture_monitor_activation=select-dlt-%u\n", wireless_dlt);
    if (bpf_set_dlt(bpf, wireless_dlt) != 0) {
        free(dlts); close(bpf); set_monitor(ifname, 0); return 1;
    }
    usleep(500000);

    int monitor_after_dlt = -1;
    if (get_monitor_value(ifname, &monitor_after_dlt) == 0)
        printf("monitor_after_biocsdlt=%d\n", monitor_after_dlt);
    printf("bpf_dlt=%u bpf_buffer_length=%u\n", wireless_dlt, blen);

    FILE *fp = fopen(outfile, "wb");
    if (!fp || write_pcap_header(fp, wireless_dlt) != 0) {
        fprintf(stderr, "pcap open/header failed: %s\n", strerror(errno));
        if (fp) fclose(fp);
        if (dlt_in_list(dlts, dlt_count, DLT_EN10MB)) bpf_set_dlt(bpf, DLT_EN10MB);
        free(dlts); close(bpf); set_monitor(ifname, 0); return 1;
    }
    unsigned char *buf = malloc(blen);
    if (!buf) {
        fclose(fp);
        if (dlt_in_list(dlts, dlt_count, DLT_EN10MB)) bpf_set_dlt(bpf, DLT_EN10MB);
        free(dlts); close(bpf); set_monitor(ifname, 0); return 1;
    }

    signal(SIGINT, stop_handler);
    signal(SIGTERM, stop_handler);
    struct timeval start, now;
    gettimeofday(&start, NULL);
    uint64_t packets = 0, bytes = 0;
    int result = 0;

    while (!stop_capture) {
        gettimeofday(&now, NULL);
        double elapsed = (double)(now.tv_sec - start.tv_sec) + (double)(now.tv_usec - start.tv_usec) / 1000000.0;
        if (elapsed >= seconds) break;
        fd_set rfds;
        FD_ZERO(&rfds); FD_SET(bpf, &rfds);
        struct timeval tv = {0, 250000};
        int sr = select(bpf + 1, &rfds, NULL, NULL, &tv);
        if (sr < 0) { if (errno == EINTR) continue; result = 1; break; }
        if (sr == 0) continue;
        ssize_t n = read(bpf, buf, blen);
        if (n < 0) { if (errno == EINTR) continue; result = 1; break; }

        unsigned char *ptr = buf, *end = buf + n;
        while ((size_t)(end - ptr) >= BPF_HDR_MIN_SIZE) {
            const struct bpf_hdr_local *bh = (const struct bpf_hdr_local *)ptr;
            size_t hdrlen = bh->bh_hdrlen, caplen = bh->bh_caplen;
            if (hdrlen < BPF_HDR_MIN_SIZE || hdrlen > (size_t)(end - ptr) || caplen > (size_t)(end - ptr) - hdrlen) break;
            struct pcap_packet_header_local ph = {
                (uint32_t)bh->bh_tstamp.tv_sec, (uint32_t)bh->bh_tstamp.tv_usec,
                bh->bh_caplen, bh->bh_datalen
            };
            if (fwrite(&ph, sizeof(ph), 1, fp) != 1 || (caplen && fwrite(ptr + hdrlen, caplen, 1, fp) != 1)) {
                result = 1; stop_capture = 1; break;
            }
            packets++; bytes += caplen;
            size_t advance = BPF_WORDALIGN_LOCAL(hdrlen + caplen);
            if (!advance || advance > (size_t)(end - ptr)) break;
            ptr += advance;
        }
        fflush(fp);
    }

    free(buf); fclose(fp);
    printf("capture_packets=%llu capture_payload_bytes=%llu capture_dlt=%u\n",
           (unsigned long long)packets, (unsigned long long)bytes, wireless_dlt);

    /* Selecting a non-802.11 DLT is Apple/libpcap's normal way back to
       non-monitor mode. WLC_SET_MONITOR=0 remains a recovery fallback. */
    if (dlt_in_list(dlts, dlt_count, DLT_EN10MB)) {
        printf("capture_monitor_restore=select-dlt-1\n");
        bpf_set_dlt(bpf, DLT_EN10MB);
    } else if (dlt_in_list(dlts, dlt_count, DLT_RAW)) {
        printf("capture_monitor_restore=select-dlt-12\n");
        bpf_set_dlt(bpf, DLT_RAW);
    }
    free(dlts);
    close(bpf);
    usleep(300000);

    int final_monitor = -1;
    if (get_monitor_value(ifname, &final_monitor) == 0)
        printf("capture_monitor_after_dlt_restore=%d\n", final_monitor);
    if (final_monitor != 0) {
        int off_rc = set_monitor(ifname, 0);
        printf("capture_wlc_monitor_off_fallback_rc=%d\n", off_rc);
        if (off_rc != 0) result = 1;
    }
    int verify = -1;
    if (get_monitor_value(ifname, &verify) == 0) {
        printf("capture_final_monitor=%d\n", verify);
        if (verify != 0) result = 1;
    }
    return result;
}

static void usage(const char *p) {
    fprintf(stderr, "usage: %s [en0] get|on|off|pulse [seconds]\n       %s [en0] capture <output.pcap> [seconds]\n", p, p);
}

int main(int argc, char **argv) {
    const char *ifname = "en0";
    int argi = 1;
    if (argc > 2 && argv[1][0] != '-') { ifname = argv[1]; argi = 2; }
    if (argc <= argi) { usage(argv[0]); return 2; }
    const char *cmd = argv[argi];
    printf("rfmonctl interface=%s sizeof_req=%zu SIOCSA80211=0x%lx\n",
           ifname, sizeof(struct apple80211req), (unsigned long)SIOCSA80211);
    if (!strcmp(cmd, "get")) return get_monitor(ifname) == 0 ? 0 : 1;
    if (!strcmp(cmd, "on")) return set_monitor(ifname, 1) == 0 ? 0 : 1;
    if (!strcmp(cmd, "off")) return set_monitor(ifname, 0) == 0 ? 0 : 1;
    if (!strcmp(cmd, "pulse")) {
        int s = argc > argi + 1 ? atoi(argv[argi + 1]) : 2;
        if (s < 1) s = 1;
        if (s > 10) s = 10;
        if (set_monitor(ifname, 1) != 0) return 1;
        sleep((unsigned)s);
        return set_monitor(ifname, 0) == 0 ? 0 : 1;
    }
    if (!strcmp(cmd, "capture")) {
        if (argc <= argi + 1) { usage(argv[0]); return 2; }
        int s = argc > argi + 2 ? atoi(argv[argi + 2]) : 4;
        return capture_monitor(ifname, argv[argi + 1], s);
    }
    usage(argv[0]);
    return 2;
}
