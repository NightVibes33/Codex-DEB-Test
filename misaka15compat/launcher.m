#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>

typedef int (*SBSLaunchApplicationWithIdentifierFn)(CFStringRef identifier, Boolean suspended);

int main(void) {
    @autoreleasepool {
        void *h = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
        if (!h) {
            fprintf(stderr, "SpringBoardServices unavailable: %s\n", dlerror());
            return 2;
        }
        SBSLaunchApplicationWithIdentifierFn launch = (SBSLaunchApplicationWithIdentifierFn)dlsym(h, "SBSLaunchApplicationWithIdentifier");
        if (!launch) {
            fprintf(stderr, "SBSLaunchApplicationWithIdentifier unavailable\n");
            dlclose(h);
            return 3;
        }
        int rc = launch(CFSTR("com.straight-tamago.misakaRS"), false);
        printf("misaka_launch_rc=%d\n", rc);
        dlclose(h);
        return rc == 0 ? 0 : 4;
    }
}
