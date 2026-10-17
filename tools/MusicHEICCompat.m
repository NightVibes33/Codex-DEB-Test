#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <math.h>
#import <stdio.h>

/// Preserve the iOS 15 artwork preference interface on later runtimes.
/// This adds a real ObjC setter, stores its value, and forwards it to a
/// recognized compatible replacement when one exists. It does not modify
/// artwork content or affect playback.
static const char kHEICRatioKey;

static void musicSetMaxHEICPercentage(id object, SEL selector, double percentage) {
    if (!isfinite(percentage)) percentage = 0.0;
    double bounded = fmax(0.0, fmin(1.0, percentage));
    objc_setAssociatedObject(object, &kHEICRatioKey, @(bounded), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Only bridge to a method with the matching floating-point calling
    // convention. Never invoke unknown private methods by guessing ABI.
    const char *names[] = {
        "setHEICRequestPercentage:",
        "setPreferredHEICRequestPercentage:",
        "setMaximumHEICRequestPercentage:"
    };
    for (unsigned i = 0; i < sizeof(names)/sizeof(names[0]); i++) {
        SEL alt = sel_registerName(names[i]);
        Method method = class_getInstanceMethod(object_getClass(object), alt);
        if (!method || sel_isEqual(alt, selector)) continue;
        char type[256] = {0};
        method_getArgumentType(method, 2, type, sizeof(type));
        if (type[0] == 'd') {
            ((void(*)(id,SEL,double))objc_msgSend)(object, alt, bounded);
            return;
        }
        if (type[0] == 'f') {
            ((void(*)(id,SEL,float))objc_msgSend)(object, alt, (float)bounded);
            return;
        }
    }
}

static double musicGetMaxHEICPercentage(id object, SEL selector) {
    NSNumber *number = objc_getAssociatedObject(object, &kHEICRatioKey);
    return number ? number.doubleValue : 0.0;
}

__attribute__((visibility("default")))
double MUSICCompatMaxHEICPercentage(id object) {
    return musicGetMaxHEICPercentage(object, NULL);
}

__attribute__((visibility("default")))
int MUSICCompatInstall(void) {
    Class artwork = objc_getClass("MPStoreArtworkDataSource");
    if (!artwork) {
        dlopen("/System/Library/Frameworks/MediaPlayer.framework/MediaPlayer", RTLD_LAZY | RTLD_GLOBAL);
        artwork = objc_getClass("MPStoreArtworkDataSource");
    }
    if (!artwork) {
        fprintf(stderr, "MPStoreArtworkCompat: MPStoreArtworkDataSource not loaded\n");
        return 0;
    }
    SEL setter = sel_registerName("setMaxHEICRequestPercentage:");
    if (!class_getInstanceMethod(artwork, setter)) {
        if (!class_addMethod(artwork, setter, (IMP)musicSetMaxHEICPercentage, "v@:d")) {
            fprintf(stderr, "MPStoreArtworkCompat: failed to add setter\n");
            return -1;
        }
    }
    SEL getter = sel_registerName("maxHEICRequestPercentage");
    if (!class_getInstanceMethod(artwork, getter)) {
        class_addMethod(artwork, getter, (IMP)musicGetMaxHEICPercentage, "d@:");
    }
    fprintf(stderr, "MPStoreArtworkCompat: compatible HEIC setter installed\n");
    return 1;
}

__attribute__((constructor))
static void musicCompatEntry(void) {
    MUSICCompatInstall();
}
