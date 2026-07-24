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
#define OUTPUT_LIMIT (1024 * 1024)
#define REQUEST_MAGIC "DSR1"
#define RESPONSE_MAGIC "DSO1"

extern char **environ;

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

static void write_u32_le(unsigned char bytes[4], uint32_t value) {
    bytes[0] = (unsigned char)(value & 0xff);
    bytes[1] = (unsigned char)((value >> 8) & 0xff);
    bytes[2] = (unsigned char)((value >> 16) & 0xff);
    bytes[3] = (unsigned char)((value >> 24) & 0xff);
}

static void write_i32_le(unsigned char bytes[4], int32_t value) {
    write_u32_le(bytes, (uint32_t)value);
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

static int command_is_blocked(const char *command) {
    static const char *blocked[] = {
        "rm -rf /",
        "rm -fr /",
        "newfs",
        "mkfs",
        "diskutil erase",
        "launchctl reboot",
        "shutdown",
        "reboot",
        "halt",
        "nvram -d",
        "dd if=/dev/zero",
        "dd of=/dev/",
        NULL
    };
    for (size_t i = 0; blocked[i] != NULL; i++) {
        if (contains_case_insensitive(command, blocked[i])) return 1;
    }
    return 0;
}

static int append_output(unsigned char **buffer, size_t *length, size_t *capacity,
                         const unsigned char *data, size_t data_length) {
    if (*length >= OUTPUT_LIMIT) return 0;
    if (data_length > OUTPUT_LIMIT - *length) {
        data_length = OUTPUT_LIMIT - *length;
    }
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
        if (count > 0) {
            if (append_output(output, output_length, &capacity, chunk, (size_t)count) != 0) {
                kill(child, SIGKILL);
            }
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

static void send_response(int client, int32_t exit_code,
                          const unsigned char *output, uint32_t output_length) {
    unsigned char header[12];
    memcpy(header, RESPONSE_MAGIC, 4);
    write_i32_le(header + 4, exit_code);
    write_u32_le(header + 8, output_length);
    write_full(client, header, sizeof(header));
    if (output_length > 0) write_full(client, output, output_length);
}

static void handle_client(int client) {
    uid_t peer_uid = (uid_t)-1;
    gid_t peer_gid = (gid_t)-1;
    if (getpeereid(client, &peer_uid, &peer_gid) != 0 ||
        (peer_uid != 0 && peer_uid != 501)) {
        const char *message = "DarkSword: unauthorized local client\n";
        send_response(client, 126, (const unsigned char *)message, (uint32_t)strlen(message));
        return;
    }

    unsigned char header[16];
    if (read_full(client, header, sizeof(header)) != 0 ||
        memcmp(header, REQUEST_MAGIC, 4) != 0) {
        return;
    }

    uint32_t timeout_ms = read_u32_le(header + 4);
    uint32_t cwd_length = read_u32_le(header + 8);
    uint32_t command_length = read_u32_le(header + 12);
    if (timeout_ms < 1000) timeout_ms = 1000;
    if (timeout_ms > 300000) timeout_ms = 300000;
    if (cwd_length > 4096 || command_length > 262144) {
        const char *message = "DarkSword: request exceeds limits\n";
        send_response(client, 126, (const unsigned char *)message, (uint32_t)strlen(message));
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

    if (command_is_blocked(command)) {
        const char *message = "DarkSword: command blocked by device-safety policy\n";
        send_response(client, 126, (const unsigned char *)message, (uint32_t)strlen(message));
        free(cwd);
        free(command);
        return;
    }

    unsigned char *output = NULL;
    size_t output_length = 0;
    int exit_code = run_command(cwd, command, timeout_ms, &output, &output_length);
    send_response(client, exit_code, output, (uint32_t)output_length);

    free(output);
    free(cwd);
    free(command);
}

int main(void) {
    signal(SIGPIPE, SIG_IGN);
    mkdir("/var/jb/var", 0755);
    mkdir("/var/jb/var/run", 0755);
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
