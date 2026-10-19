/* End-to-end protocol smoke test for the iOS privileged service.
 * Reject short, killed, errored, or partial diagnostics output. */
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/time.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#define SMR_SOCKET "/var/mobile/Library/SafeModeRepair/rootd.sock"
int main(void) {
    int fd=socket(AF_UNIX,SOCK_STREAM,0);
    if(fd<0){perror("socket");return 1;}
    struct sockaddr_un a={0};
    a.sun_family=AF_UNIX;
    strlcpy(a.sun_path,SMR_SOCKET,sizeof(a.sun_path));
    struct timeval tv={.tv_sec=45,.tv_usec=0};
    setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));
    if(connect(fd,(void *)&a,sizeof(a))!=0){perror("connect");close(fd);return 2;}
    const char *request="DIAGNOSTICS\n";
    if(write(fd,request,strlen(request))!=(ssize_t)strlen(request)){perror("write");close(fd);return 3;}
    shutdown(fd,SHUT_WR);
    char response[32768];
    size_t length=0;
    while(length<sizeof(response)-1) {
        ssize_t n=read(fd,response+length,sizeof(response)-1-length);
        if(n==0)break;
        if(n<0){perror("read");close(fd);return 4;}
        length+=(size_t)n;
    }
    close(fd);
    if(length==0){fprintf(stderr,"ERROR: daemon returned empty response\n");return 5;}
    response[length]=0;
    puts(response);
    const char *required[]={
        "=== DEVICE DIAGNOSTICS ===",
        "device=iPhone8,1",
        "available_tweaks=",
        "=== LATEST SPRINGBOARD CRASH ===",
        "=== TEST STATE ===",
        "active_test=",
        "=== PREVIOUS TEST RESULTS ==="
    };
    for(size_t i=0;i<sizeof(required)/sizeof(required[0]);i++){
        if(!strstr(response,required[i])){
            fprintf(stderr,"ERROR: incomplete service response: missing %s\n",required[i]);
            return 6;
        }
    }
    if(strstr(response,"ERROR:")){
        fprintf(stderr,"ERROR: privileged service reported an operation failure\n");
        return 7;
    }
    puts("SMR_ROOT_SERVICE_SMOKE_PASS=1");
    return 0;
}
