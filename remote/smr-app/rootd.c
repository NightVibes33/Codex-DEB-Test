/* Root-owned, command-whitelisted local service for Safe Mode Repair.
 * UNIX socket permissions restrict access to the mobile user. */
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <spawn.h>
#include <pwd.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

extern char **environ;
#define SOCKET_PATH "/var/mobile/Library/SafeModeRepair/rootd.sock"
#define SCRIPT "/var/jb/usr/local/bin/safemode-repair"
#define MAX_COMMAND 256
#define MAX_OUTPUT (512 * 1024)

static void send_all(int fd, const char *b, size_t n) {
    while (n) {
        ssize_t k = write(fd, b, n);
        if (k <= 0) return;
        n -= (size_t)k; b += k;
    }
}
static void send_text(int fd, const char *s) { send_all(fd, s, strlen(s)); }

static int valid_name(const char *name) {
    if (!name || !*name || strlen(name) > 128 || strstr(name, "..")) return 0;
    for (const unsigned char *p=(const unsigned char *)name; *p; p++) {
        if (!isalnum(*p) && *p!='_' && *p!='.' && *p!='+' && *p!='-') return 0;
    }
    return 1;
}

static void run_repair(int client, const char *subcommand, const char *name, int authorized) {
    int p[2];
    if (pipe(p)) { send_text(client, "ERROR: Cannot create process pipe.\n"); return; }
    posix_spawn_file_actions_t acts;
    posix_spawn_file_actions_init(&acts);
    posix_spawn_file_actions_adddup2(&acts, p[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&acts, p[1], STDERR_FILENO);
    posix_spawn_file_actions_addopen(&acts, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
    posix_spawn_file_actions_addclose(&acts, p[0]);
    posix_spawn_file_actions_addclose(&acts, p[1]);

    const char *shell = access("/var/jb/bin/sh", X_OK)==0 ? "/var/jb/bin/sh" : "/bin/sh";
    char *argv[6] = {(char *)shell, (char *)SCRIPT, (char *)subcommand, (char *)name, NULL};
    if (!name) argv[3] = NULL;
    if (authorized) setenv("SMR_GUI_APPROVED", "1", 1);
    pid_t pid = -1;
    int err = posix_spawn(&pid, shell, &acts, NULL, argv, environ);
    if (authorized) unsetenv("SMR_GUI_APPROVED");
    posix_spawn_file_actions_destroy(&acts);
    close(p[1]);
    if (err) {
        close(p[0]);
        send_text(client, "ERROR: Could not start repair utility.\n");
        return;
    }
    char buf[4096];
    ssize_t n; size_t total=0;
    while ((n=read(p[0],buf,sizeof(buf)))>0) {
        size_t count=(size_t)n;
        if (total+count>MAX_OUTPUT) count=MAX_OUTPUT-total;
        if (count) send_all(client,buf,count);
        total+=count;
        if (total>=MAX_OUTPUT) break;
    }
    close(p[0]);
    int status=0;
    waitpid(pid,&status,0);
    if (total>=MAX_OUTPUT) send_text(client,"\nERROR: Output truncated.\n");
    if (!WIFEXITED(status) || WEXITSTATUS(status)!=0) {
        send_text(client, "\nERROR: Command failed; inspect output.\n");
    }
}

static void handle(int client) {
    uid_t uid=0; gid_t gid=0;
    struct passwd *mobile=getpwnam("mobile");
    if (getpeereid(client,&uid,&gid)!=0 || (uid!=0 && (!mobile || uid!=mobile->pw_uid))) {
        send_text(client,"ERROR: Access denied.\n"); return;
    }
    char request[MAX_COMMAND]={0}; size_t used=0;
    while (used<sizeof(request)-1) {
        char c=0; ssize_t n=read(client,&c,1);
        if (n<=0 || c=='\n') break;
        if (c=='\r') continue;
        request[used++]=c;
    }
    if (used==sizeof(request)-1) { send_text(client,"ERROR: Command too long.\n"); return; }
    if (!strcmp(request,"SCAN")) { run_repair(client,"scan",NULL,0);return; }
    if (!strcmp(request,"DISABLED")) { run_repair(client,"list-disabled",NULL,0);return; }
    char *space=strchr(request,' ');
    if (!space) {send_text(client,"ERROR: Unknown command.\n");return;}
    *space=0;
    const char *name=space+1;
    if (!valid_name(name)) {send_text(client,"ERROR: Invalid tweak name.\n");return;}
    if (!strcmp(request,"DISABLE")) {run_repair(client,"disable",name,0);return;}
    if (!strcmp(request,"ENABLE")) {run_repair(client,"enable",name,0);return;}
    if (!strcmp(request,"UNINSTALL")) {run_repair(client,"uninstall",name,1);return;}
    send_text(client,"ERROR: Command not permitted.\n");
}

int main(void) {
    signal(SIGPIPE,SIG_IGN);
    if (geteuid()!=0) return 1;
    mkdir("/var/mobile/Library/SafeModeRepair",0755);
    chmod("/var/mobile/Library/SafeModeRepair",0755);
    int fd=socket(AF_UNIX,SOCK_STREAM,0);
    if (fd<0) return 2;
    struct sockaddr_un addr={0};
    addr.sun_family=AF_UNIX;
    strlcpy(addr.sun_path,SOCKET_PATH,sizeof(addr.sun_path));
    unlink(SOCKET_PATH);
    mode_t oldmask=umask(077);
    int rc=bind(fd,(struct sockaddr *)&addr,sizeof(addr));
    umask(oldmask);
    if (rc!=0) { close(fd);return 3; }
    struct passwd *mobile=getpwnam("mobile");
    if (!mobile || chown(SOCKET_PATH,mobile->pw_uid,mobile->pw_gid)!=0) {
        unlink(SOCKET_PATH);close(fd);return 4;
    }
    chmod(SOCKET_PATH,0600);
    if (listen(fd,8)!=0) {unlink(SOCKET_PATH);close(fd);return 5;}
    for (;;) {
        int client=accept(fd,NULL,NULL);
        if (client<0) { if (errno==EINTR) continue; break; }
        handle(client);
        close(client);
    }
    close(fd);
    unlink(SOCKET_PATH);
    return 0;
}
