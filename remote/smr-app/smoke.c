/* Read-only protocol smoke test for Safe Mode Repair's privileged local service. */
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#define PATH "/var/mobile/Library/SafeModeRepair/rootd.sock"
int main(void) {
    int fd=socket(AF_UNIX,SOCK_STREAM,0);
    if(fd<0){perror("socket");return 1;}
    struct sockaddr_un a={0};
    a.sun_family=AF_UNIX;
    strlcpy(a.sun_path,PATH,sizeof(a.sun_path));
    if(connect(fd,(void *)&a,sizeof(a))!=0){perror("connect");close(fd);return 2;}
    const char *request="DIAGNOSTICS\n";
    if(write(fd,request,strlen(request))!=(ssize_t)strlen(request)){perror("write");close(fd);return 3;}
    shutdown(fd,SHUT_WR);
    char response[8192];ssize_t n=read(fd,response,sizeof(response)-1);
    close(fd);
    if(n<=0){fprintf(stderr,"No response from service\n");return 4;}
    response[n]=0;
    puts(response);
    if(!strstr(response,"=== DEVICE DIAGNOSTICS ===")) {
        fprintf(stderr,"Root daemon did not return expected diagnostics\n");
        return 5;
    }
    puts("SMR_ROOT_SERVICE_SMOKE_PASS=1");
    return 0;
}
