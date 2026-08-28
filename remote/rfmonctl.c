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

/* Darwin/XNU BPF ABI subset. */
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

#define BPF_ALIGNMENT ((size_t)sizeof(int32_t))
#define BPF_WORDALIGN_LOCAL(x) (((x) + (BPF_ALIGNMENT - 1)) & ~(BPF_ALIGNMENT - 1))
#define BPF_HDR_MIN_SIZE 18u
#define BIOCGBLEN     _IOR('B', 102, unsigned int)
#define BIOCPROMISC   _IO('B', 105)
#define BIOCGDLT      _IOR('B', 106, unsigned int)
#define BIOCSETIF     _IOW('B', 108, struct ifreq)
#define BIOCIMMEDIATE _IOW('B', 112, unsigned int)

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

static int get_monitor(const char *ifname) {
    return get_monitor_value(ifname, NULL);
}

static int set_monitor(const char *ifname, int enabled) {
    int value = enabled ? 1 : 0;
    int rc = broadcom_ioctl(ifname, WLC_SET_MONITOR, &value);
    if (rc == 0) printf("monitor_set=%d\n", enabled ? 1 : 0);
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
        if (errno != EBUSY && errno != EACCES && errno != ENOENT) {
            fprintf(stderr, "open %s failed: errno=%d (%s)\n", path, errno, strerror(errno));
        }
        if (errno == ENOENT && i > 16) break;
    }
    errno = last_errno;
    return -1;
}

static int bind_bpf(int fd, const char *ifname, unsigned int *dlt_out, unsigned int *buflen_out) {
    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));

    if (ioctl(fd, BIOCSETIF, &ifr) < 0) {
        fprintf(stderr, "BIOCSETIF(%s) failed: errno=%d (%s)\n", ifname, errno, strerror(errno));
        return -1;
    }

    unsigned int one = 1;
    if (ioctl(fd, BIOCIMMEDIATE, &one) < 0) {
        fprintf(stderr, "BIOCIMMEDIATE failed: errno=%d (%s)\n", errno, strerror(errno));
    }
    if (ioctl(fd, BIOCPROMISC, NULL) < 0) {
        fprintf(stderr, "BIOCPROMISC failed: errno=%d (%s)\n", errno, strerror(errno));
    }

    unsigned int dlt = 0;
    if (ioctl(fd, BIOCGDLT, &dlt) < 0) {
        fprintf(stderr, "BIOCGDLT failed: errno=%d (%s)\n", errno, strerror(errno));
        return -1;
    }
    unsigned int blen = 0;
    if (ioctl(fd, BIOCGBLEN, &blen) < 0 || blen == 0) {
        fprintf(stderr, "BIOCGBLEN failed: errno=%d (%s)\n", errno, strerror(errno));
        return -1;
    }

    printf("bpf_dlt=%u bpf_buffer_length=%u\n", dlt, blen);
    if (dlt_out) *dlt_out = dlt;
    if (buflen_out) *buflen_out = blen;
    return 0;
}

static int write_pcap_header(FILE *fp, unsigned int dlt) {
    struct pcap_file_header_local hdr;
    memset(&hdr, 0, sizeof(hdr));
    hdr.magic = 0xa1b2c3d4u;
    hdr.version_major = 2;
    hdr.version_minor = 4;
    hdr.snaplen = 65535u;
    hdr.network = dlt;
    return fwrite(&hdr, sizeof(hdr), 1, fp) == 1 ? 0 : -1;
}

static int capture_monitor(const char *ifname, const char *outfile, int seconds) {
    if (seconds < 1) seconds = 1;
    if (seconds > 20) seconds = 20;
    printf("capture_interface=%s capture_file=%s capture_seconds=%d\n", ifname, outfile, seconds);

    int initial_monitor = 0;
    if (get_monitor_value(ifname, &initial_monitor) != 0) return 1;
    if (initial_monitor != 0) {
        printf("capture_preflight=monitor-was-on-forcing-off\n");
        if (set_monitor(ifname, 0) != 0) return 1;
        usleep(250000);
    }

    if (set_monitor(ifname, 1) != 0) return 1;
    usleep(250000);

    int live_monitor = -1;
    if (get_monitor_value(ifname, &live_monitor) != 0 || live_monitor == 0) {
        fprintf(stderr, "capture_preflight=monitor-did-not-latch\n");
        set_monitor(ifname, 0);
        return 1;
    }

    char bpf_path[32] = {0};
    int bpf = open_bpf_device(bpf_path, sizeof(bpf_path));
    if (bpf < 0) {
        fprintf(stderr, "open_bpf_device failed: errno=%d (%s)\n", errno, strerror(errno));
        set_monitor(ifname, 0);
        return 1;
    }
    printf("bpf_device=%s\n", bpf_path);

    unsigned int dlt = 0, blen = 0;
    if (bind_bpf(bpf, ifname, &dlt, &blen) != 0) {
        close(bpf);
        set_monitor(ifname, 0);
        return 1;
    }

    FILE *fp = fopen(outfile, "wb");
    if (!fp) {
        fprintf(stderr, "fopen(%s) failed: errno=%d (%s)\n", outfile, errno, strerror(errno));
        close(bpf);
        set_monitor(ifname, 0);
        return 1;
    }
    if (write_pcap_header(fp, dlt) != 0) {
        fprintf(stderr, "write pcap header failed\n");
        fclose(fp);
        close(bpf);
        set_monitor(ifname, 0);
        return 1;
    }

    unsigned char *buf = malloc(blen);
    if (!buf) {
        fprintf(stderr, "malloc(%u) failed\n", blen);
        fclose(fp);
        close(bpf);
        set_monitor(ifname, 0);
        return 1;
    }

    signal(SIGINT, stop_handler);
    signal(SIGTERM, stop_handler);

    struct timeval start, now;
    gettimeofday(&start, NULL);
    uint64_t packet_count = 0;
    uint64_t payload_bytes = 0;
    int result = 0;

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
            size_t record_len = hdrlen + caplen;

            struct pcap_packet_header_local ph;
            ph.ts_sec = (uint32_t)bh->bh_tstamp.tv_sec;
            ph.ts_usec = (uint32_t)bh->bh_tstamp.tv_usec;
            ph.incl_len = (uint32_t)bh->bh_caplen;
            ph.orig_len = (uint32_t)bh->bh_datalen;

            if (fwrite(&ph, sizeof(ph), 1, fp) != 1 ||
                (caplen != 0 && fwrite(ptr + hdrlen, caplen, 1, fp) != 1)) {
                fprintf(stderr, "pcap packet write failed\n");
                result = 1;
                stop_capture = 1;
                break;
            }

            packet_count++;
            payload_bytes += caplen;
            size_t advance = BPF_WORDALIGN_LOCAL(record_len);
            if (advance == 0 || advance > (size_t)(end - ptr)) break;
            ptr += advance;
        }
        fflush(fp);
    }

    free(buf);
    fclose(fp);
    close(bpf);

    printf("capture_packets=%llu capture_payload_bytes=%llu capture_dlt=%u\n",
           (unsigned long long)packet_count,
           (unsigned long long)payload_bytes,
           dlt);

    int off_rc = set_monitor(ifname, 0);
    printf("capture_monitor_off_rc=%d\n", off_rc);
    if (off_rc != 0) result = 1;

    int final_monitor = -1;
    if (get_monitor_value(ifname, &final_monitor) == 0) {
        printf("capture_final_monitor=%d\n", final_monitor);
        if (final_monitor != 0) result = 1;
    }

    return result;
}

static void usage(const char *argv0) {
    fprintf(stderr,
            "usage: %s [en0] get|on|off|pulse [seconds]\n"
            "       %s [en0] capture <output.pcap> [seconds]\n",
            argv0, argv0);
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
    if (strcmp(cmd, "capture") == 0) {
        if (argc <= argi + 1) {
            usage(argv[0]);
            return 2;
        }
        const char *outfile = argv[argi + 1];
        int seconds = 4;
        if (argc > argi + 2) seconds = atoi(argv[argi + 2]);
        return capture_monitor(ifname, outfile, seconds);
    }

    usage(argv[0]);
    return 2;
}
