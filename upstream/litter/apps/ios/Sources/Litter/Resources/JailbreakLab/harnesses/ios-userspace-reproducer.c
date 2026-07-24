#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <unistd.h>

/*
 * Generic authorized-research harness template.
 *
 * Put only the smallest public API interaction needed to reproduce a crash in
 * run_case(). Do not add persistence, credential access, destructive storage
 * operations, or unattended kernel-memory writes.
 */

static volatile sig_atomic_t timed_out = 0;

static void timeout_handler(int signal_number) {
    (void)signal_number;
    timed_out = 1;
}

static int configure_limits(void) {
    struct rlimit files = {256, 256};
    if (setrlimit(RLIMIT_NOFILE, &files) != 0) {
        fprintf(stderr, "setrlimit(RLIMIT_NOFILE): %s\n", strerror(errno));
        return -1;
    }

    signal(SIGALRM, timeout_handler);
    alarm(15);
    return 0;
}

static int run_case(uint64_t seed) {
    /* Replace this body with one minimal, user-approved reproduction step. */
    printf("seed=%llu placeholder-case\n", (unsigned long long)seed);
    return 0;
}

int main(int argc, char **argv) {
    uint64_t seed = 1;
    if (argc == 2) {
        char *end = NULL;
        seed = strtoull(argv[1], &end, 0);
        if (!end || *end != '\0') {
            fprintf(stderr, "invalid seed\n");
            return 2;
        }
    }

    if (configure_limits() != 0) return 125;
    int result = run_case(seed);
    if (timed_out) {
        fprintf(stderr, "harness timeout\n");
        return 124;
    }
    return result;
}
