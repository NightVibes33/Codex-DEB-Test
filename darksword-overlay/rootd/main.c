#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define SOCKET_PATH "/var/jb/var/run/darksword-rootd.sock"
#define LOG_PATH "/var/jb/var/log/darksword-rootd.log"
#define OUTPUT_LIMIT (1024 * 1024)
#define REQUEST_MAGIC "DSR1"
#define APPROVE_MAGIC "DSA1"
#define DENY_MAGIC "DSD1"
#define STATUS_MAGIC "DSS1"
#define RESPONSE_MAGIC "DSO1"
#define APPROVAL_TTL_SECONDS 120

extern char **environ;

static uint64_t pending_hash = 0;
static char *pending_cwd = NULL;
static char *pending_command = NULL;
static uint32_t pending_timeout_ms = 0;
static uint64_t approved_hash = 0;
static time_t approved_until = 0;

static int read_full(int fd, void *buffer, size_t length) {
    unsigned char *cursor = buffer;
    while (length > 0) {
        ssize_t count = read(fd, cursor, length);
        if (count == 0) return -1;
        if (count < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        cursor += count;
        length -= (size_t)count;
    }
    return 0;
}

static int write_full(int fd, const void *buffer, size_t length) {
    const unsigned char *cursor = buffer;
    while (length > 0) {
        ssize_t count = write(fd, cursor, length);
        if (count < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        cursor += count;
        length -= (size_t)count;
    }
    return 0;
}

static uint32_t read_u32_le(const unsigned char bytes[4]) {
    return ((uint32_t)bytes[0]) |
           ((uint32_t)bytes[1] << 8) |
           ((uint32_t)bytes[2] << 16) |
           ((uint32_t)bytes[3] << 24);
}

static uint64_t read_u64_le(const unsigned char bytes[8]) {
    uint64_t value = 0;
    for (unsigned int i = 0; i < 8; i++) value |= ((uint64_t)bytes[i]) << (i * 8);
    return value;
}

static void write_u32_le(unsigned char bytes[4], uint32_t value) {
    bytes[0] = (unsigned char)(value & 0xff);
    bytes[1] = (unsigned char)((value >> 8) & 0xff);
    bytes[2] = (unsigned char)((value >> 16) & 0xff);
    bytes[3] = (unsigned char)((value >> 24) & 0xff);
}

static void write_i32_le(unsigned char bytes[4], int32_t value) {
    write_u32_le(bytes, (uint32_t)value);
}

static void send_response(int client, int32_t exit_code,
                          const unsigned char *output, uint32_t output_length) {
    unsigned char header[12];
    memcpy(header, RESPONSE_MAGIC, 4);
    write_i32_le(header + 4, exit_code);
    write_u32_le(header + 8, output_length);
    write_full(client, header, sizeof(header));
    if (output_length > 0) write_full(client, output, output_length);
}

static void send_text(int client, int32_t exit_code, const char *message) {
    send_response(client, exit_code, (const unsigned char *)message, (uint32_t)strlen(message));
}

static void append_audit(uid_t uid, const char *event, uint64_t hash,
                         const char *cwd, const char *command, int exit_code) {
    FILE *log = fopen(LOG_PATH, "a");
    if (!log) return;
    time_t now = time(NULL);
    fprintf(log, "%lld uid=%u event=%s hash=%016llx exit=%d cwd=%s command=",
            (long long)now,
            (unsigned int)uid,
            event,
            (unsigned long long)hash,
            exit_code,
            cwd ? cwd : "");
    if (command) {
        for (const unsigned char *p = (const unsigned char *)command; *p; p++) {
            if (*p == '\n' || *p == '\r' || *p == '\t') fputc(' ', log);
            else if (*p < 0x20) fputc('?', log);
            else fputc(*p, log);
        }
    }
    fputc('\n', log);
    fclose(log);
}

static int contains_case_insensitive(const char *haystack, const char *needle) {
    size_t needle_len = strlen(needle);
    if (needle_len == 0) return 1;
    for (const char *p = haystack; *p; p++) {
        size_t i = 0;
        while (i < needle_len && p[i]) {
            char a = p[i];
            char b = needle[i];
            if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
            if (b >= 'A' && b <= 'Z') b = (char)(b - 'A' + 'a');
            if (a != b) break;
            i++;
        }
        if (i == needle_len) return 1;
    }
    return 0;
}

/*
 * Approved commands have unrestricted filesystem, process, Git, compiler,
 * package, service, debugger and research access. These final emergency
 * stops only prevent commands whose primary effect is destroying the entire
 * device or raw storage rather than conducting a bounded experiment.
 */
static int command_is_emergency_blocked(const char *command) {
    static const char *blocked[] = {
        "rm -rf /",
        "rm -fr /",
        "newfs",
        "mkfs",
        "diskutil erase",
        "dd if=/dev/zero",
        "dd of=/dev/",
        NULL
    };
    for (size_t i = 0; blocked[i] != NULL; i++) {
        if (contains_case_insensitive(command, blocked[i])) return 1;
    }
    return 0;
}

static uint64_t fnv1a_update(uint64_t hash, const unsigned char *bytes, size_t length) {
    for (size_t i = 0; i < length; i++) {
        hash ^= bytes[i];
        hash *= UINT64_C(1099511628211);
    }
    return hash;
}

static uint64_t command_hash(const char *cwd, const char *command) {
    uint64_t hash = UINT64_C(1469598103934665603);
    if (cwd) hash = fnv1a_update(hash, (const unsigned char *)cwd, strlen(cwd));
    const unsigned char separator = 0;
    hash = fnv1a_update(hash, &separator, 1);
    if (command) hash = fnv1a_update(hash, (const unsigned char *)command, strlen(command));
    return hash;
}

static void clear_pending(void) {
    free(pending_cwd);
    free(pending_command);
    pending_cwd = NULL;
    pending_command = NULL;
    pending_timeout_ms = 0;
    pending_hash = 0;
}

static int set_pending(const char *cwd, const char *command, uint32_t timeout_ms, uint64_t hash) {
    char *next_cwd = strdup(cwd ? cwd : "");
    char *next_command = strdup(command ? command : "");
    if (!next_cwd || !next_command) {
        free(next_cwd);
        free(next_command);
        return -1;
    }
    clear_pending();
    pending_cwd = next_cwd;
    pending_command = next_command;
    pending_timeout_ms = timeout_ms;
    pending_hash = hash;
    return 0;
}

static char *single_line_copy(const char *source) {
    if (!source) return strdup("");
    size_t length = strlen(source);
    char *copy = calloc(length + 1, 1);
    if (!copy) return NULL;
    for (size_t i = 0; i < length; i++) {
        unsigned char c = (unsigned char)source[i];
        copy[i] = (c == '\n' || c == '\r' || c == '\t' || c < 0x20) ? ' ' : (char)c;
    }
    return copy;
}

static int append_output(unsigned char **buffer, size_t *length, size_t *capacity,
                         const unsigned char *data, size_t data_length) {
    if (*length >= OUTPUT_LIMIT) return 0;
    if (data_length > OUTPUT_LIMIT - *length) data_length = OUTPUT_LIMIT - *length;
    size_t needed = *length + data_length;
    if (needed > *capacity) {
        size_t next = *capacity == 0 ? 4096 : *capacity;
        while (next < needed) next *= 2;
        if (next > OUTPUT_LIMIT) next = OUTPUT_LIMIT;
        unsigned char *grown = realloc(*buffer, next);
        if (!grown) return -1;
        *buffer = grown;
        *capacity = next;
    }
    memcpy(*buffer + *length, data, data_length);
    *length += data_length;
    return 0;
}

static int run_command(const char *cwd, const char *command, uint32_t timeout_ms,
                       unsigned char **output, size_t *output_length) {
    int pipe_fds[2];
    if (pipe(pipe_fds) != 0) return 125;

    pid_t child = fork();
    if (child < 0) {
        close(pipe_fds[0]);
        close(pipe_fds[1]);
        return 125;
    }

    if (child == 0) {
        close(pipe_fds[0]);
        dup2(pipe_fds[1], STDOUT_FILENO);
        dup2(pipe_fds[1], STDERR_FILENO);
        if (pipe_fds[1] > STDERR_FILENO) close(pipe_fds[1]);

        if (cwd && *cwd && chdir(cwd) != 0) {
            dprintf(STDERR_FILENO, "DarkSword: cannot enter %s: %s\n", cwd, strerror(errno));
            _exit(126);
        }

        setenv("PATH", "/var/jb/usr/local/bin:/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin", 1);
        setenv("HOME", "/var/root", 1);
        setenv("USER", "root", 1);
        setenv("LOGNAME", "root", 1);
        setenv("PAGER", "cat", 1);

        execl("/bin/zsh", "zsh", "-lc", command, (char *)NULL);
        execl("/bin/sh", "sh", "-lc", command, (char *)NULL);
        dprintf(STDERR_FILENO, "DarkSword: no shell available: %s\n", strerror(errno));
        _exit(127);
    }

    close(pipe_fds[1]);
    int flags = fcntl(pipe_fds[0], F_GETFL, 0);
    fcntl(pipe_fds[0], F_SETFL, flags | O_NONBLOCK);

    struct timespec start;
    clock_gettime(CLOCK_MONOTONIC, &start);
    size_t capacity = 0;
    int status = 0;
    int child_done = 0;

    while (!child_done) {
        unsigned char chunk[4096];
        ssize_t count = read(pipe_fds[0], chunk, sizeof(chunk));
        if (count > 0 && append_output(output, output_length, &capacity, chunk, (size_t)count) != 0) {
            kill(child, SIGKILL);
        }

        pid_t waited = waitpid(child, &status, WNOHANG);
        if (waited == child) child_done = 1;

        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);
        uint64_t elapsed = (uint64_t)(now.tv_sec - start.tv_sec) * 1000ULL;
        if (now.tv_nsec >= start.tv_nsec) {
            elapsed += (uint64_t)(now.tv_nsec - start.tv_nsec) / 1000000ULL;
        } else {
            elapsed -= 1000ULL;
            elapsed += (uint64_t)(1000000000L + now.tv_nsec - start.tv_nsec) / 1000000ULL;
        }

        if (!child_done && elapsed >= timeout_ms) {
            kill(child, SIGKILL);
            waitpid(child, &status, 0);
            const char *message = "\nDarkSword: command timed out\n";
            append_output(output, output_length, &capacity,
                          (const unsigned char *)message, strlen(message));
            close(pipe_fds[0]);
            return 124;
        }
        if (!child_done) usleep(10000);
    }

    for (;;) {
        unsigned char chunk[4096];
        ssize_t count = read(pipe_fds[0], chunk, sizeof(chunk));
        if (count <= 0) break;
        append_output(output, output_length, &capacity, chunk, (size_t)count);
    }
    close(pipe_fds[0]);

    if (WIFEXITED(status)) return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
    return 125;
}

static void handle_status(int client) {
    int is_approved = approved_hash != 0 && approved_hash == pending_hash && time(NULL) <= approved_until;
    if (!pending_hash || !pending_command) {
        send_text(client, 0, "pending=0\napproved=0\n");
        return;
    }

    char *cwd = single_line_copy(pending_cwd);
    char *command = single_line_copy(pending_command);
    if (!cwd || !command) {
        free(cwd);
        free(command);
        send_text(client, 125, "DarkSword: unable to format pending approval\n");
        return;
    }

    size_t needed = strlen(cwd) + strlen(command) + 256;
    char *message = calloc(needed, 1);
    if (!message) {
        free(cwd);
        free(command);
        send_text(client, 125, "DarkSword: unable to allocate approval status\n");
        return;
    }
    snprintf(message, needed,
             "pending=1\napproved=%d\nhash=%016llx\ntimeout_ms=%u\ncwd=%s\ncommand=%s\n",
             is_approved,
             (unsigned long long)pending_hash,
             pending_timeout_ms,
             cwd,
             command);
    send_text(client, 0, message);
    free(message);
    free(cwd);
    free(command);
}

static void handle_approve(int client, uid_t peer_uid) {
    unsigned char hash_bytes[8];
    if (read_full(client, hash_bytes, sizeof(hash_bytes)) != 0) return;
    uint64_t requested_hash = read_u64_le(hash_bytes);
    if (!pending_hash || requested_hash != pending_hash) {
        send_text(client, 126, "DarkSword: approval does not match the pending command\n");
        append_audit(peer_uid, "approve-mismatch", requested_hash, NULL, NULL, 126);
        return;
    }
    approved_hash = requested_hash;
    approved_until = time(NULL) + APPROVAL_TTL_SECONDS;
    send_text(client, 0, "DarkSword: exact command approved once; retry within 120 seconds\n");
    append_audit(peer_uid, "approved", requested_hash, pending_cwd, pending_command, 0);
}

static void handle_deny(int client, uid_t peer_uid) {
    unsigned char hash_bytes[8];
    if (read_full(client, hash_bytes, sizeof(hash_bytes)) != 0) return;
    uint64_t requested_hash = read_u64_le(hash_bytes);
    if (pending_hash && requested_hash == pending_hash) {
        append_audit(peer_uid, "denied", requested_hash, pending_cwd, pending_command, 126);
        clear_pending();
        approved_hash = 0;
        approved_until = 0;
        send_text(client, 0, "DarkSword: pending command denied\n");
        return;
    }
    send_text(client, 126, "DarkSword: no matching pending command\n");
}

static void handle_command(int client, uid_t peer_uid) {
    unsigned char header[12];
    if (read_full(client, header, sizeof(header)) != 0) return;

    uint32_t timeout_ms = read_u32_le(header);
    uint32_t cwd_length = read_u32_le(header + 4);
    uint32_t command_length = read_u32_le(header + 8);
    if (timeout_ms < 1000) timeout_ms = 1000;
    if (timeout_ms > 300000) timeout_ms = 300000;
    if (cwd_length > 4096 || command_length > 262144) {
        send_text(client, 126, "DarkSword: request exceeds limits\n");
        return;
    }

    char *cwd = calloc((size_t)cwd_length + 1, 1);
    char *command = calloc((size_t)command_length + 1, 1);
    if (!cwd || !command ||
        read_full(client, cwd, cwd_length) != 0 ||
        read_full(client, command, command_length) != 0) {
        free(cwd);
        free(command);
        return;
    }

    uint64_t hash = command_hash(cwd, command);
    if (command_is_emergency_blocked(command)) {
        send_text(client, 126, "DarkSword: catastrophic whole-device storage destruction is not executable\n");
        append_audit(peer_uid, "emergency-block", hash, cwd, command, 126);
        free(cwd);
        free(command);
        return;
    }

    int approved = approved_hash == hash && pending_hash == hash && time(NULL) <= approved_until;
    if (!approved) {
        approved_hash = 0;
        approved_until = 0;
        if (set_pending(cwd, command, timeout_ms, hash) != 0) {
            send_text(client, 125, "DarkSword: unable to queue command approval\n");
        } else {
            char message[256];
            snprintf(message, sizeof(message),
                     "DarkSword approval required\nhash=%016llx\nOpen AlleyCat Labs > Tool Approval, approve the exact command, then retry.\n",
                     (unsigned long long)hash);
            send_text(client, 126, message);
            append_audit(peer_uid, "queued", hash, cwd, command, 126);
        }
        free(cwd);
        free(command);
        return;
    }

    approved_hash = 0;
    approved_until = 0;
    unsigned char *output = NULL;
    size_t output_length = 0;
    int exit_code = run_command(cwd, command, timeout_ms, &output, &output_length);
    send_response(client, exit_code, output, (uint32_t)output_length);
    append_audit(peer_uid, "executed", hash, cwd, command, exit_code);
    clear_pending();

    free(output);
    free(cwd);
    free(command);
}

static void handle_client(int client) {
    uid_t peer_uid = (uid_t)-1;
    gid_t peer_gid = (gid_t)-1;
    if (getpeereid(client, &peer_uid, &peer_gid) != 0 ||
        (peer_uid != 0 && peer_uid != 501)) {
        send_text(client, 126, "DarkSword: unauthorized local client\n");
        return;
    }

    unsigned char magic[4];
    if (read_full(client, magic, sizeof(magic)) != 0) return;
    if (memcmp(magic, REQUEST_MAGIC, 4) == 0) {
        handle_command(client, peer_uid);
    } else if (memcmp(magic, APPROVE_MAGIC, 4) == 0) {
        handle_approve(client, peer_uid);
    } else if (memcmp(magic, DENY_MAGIC, 4) == 0) {
        handle_deny(client, peer_uid);
    } else if (memcmp(magic, STATUS_MAGIC, 4) == 0) {
        handle_status(client);
    } else {
        send_text(client, 126, "DarkSword: unknown request type\n");
    }
}

int main(void) {
    signal(SIGPIPE, SIG_IGN);
    mkdir("/var/jb/var", 0755);
    mkdir("/var/jb/var/run", 0755);
    mkdir("/var/jb/var/log", 0755);
    unlink(SOCKET_PATH);

    int server = socket(AF_UNIX, SOCK_STREAM, 0);
    if (server < 0) return 1;

    struct sockaddr_un address;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    strlcpy(address.sun_path, SOCKET_PATH, sizeof(address.sun_path));

    if (bind(server, (struct sockaddr *)&address, sizeof(address)) != 0) return 2;
    chmod(SOCKET_PATH, 0660);
    chown(SOCKET_PATH, 0, 501);
    if (listen(server, 8) != 0) return 3;

    append_audit(0, "daemon-start", 0, NULL, NULL, 0);
    for (;;) {
        int client = accept(server, NULL, NULL);
        if (client < 0) {
            if (errno == EINTR) continue;
            sleep(1);
            continue;
        }
        handle_client(client);
        close(client);
    }
}
