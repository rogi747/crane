#import "MappingResolver.h"
#import <objc/runtime.h>

// Private API surface from MobileCoreServices / LaunchServices.
@interface LSApplicationProxy : NSObject
+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSURL *dataContainerURL;
@property (nonatomic, readonly) NSString *applicationType;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allApplications;
@end

@implementation CRAppInfo
@end

@implementation MappingResolver

+ (CRAppInfo *)appInfoFromProxy:(LSApplicationProxy *)proxy {
    if (!proxy) return nil;
    CRAppInfo *info = [CRAppInfo new];
    info.bundleIdentifier = proxy.applicationIdentifier;
    info.displayName = proxy.localizedName ?: proxy.applicationIdentifier;
    NSURL *dataURL = proxy.dataContainerURL;
    if (dataURL) {
        info.dataContainerPath = dataURL.path;
        info.dataContainerUUID = dataURL.path.lastPathComponent;
    }
    return info;
}

+ (NSArray<CRAppInfo *> *)installedUserApps {
    NSMutableArray<CRAppInfo *> *result = [NSMutableArray array];
    LSApplicationWorkspace *ws = [objc_getClass("LSApplicationWorkspace") defaultWorkspace];
    NSArray *apps = [ws allApplications];
    for (LSApplicationProxy *proxy in apps) {
        // Only user apps have a data container we can swap.
        if (![proxy.applicationType isEqualToString:@"User"]) continue;
        CRAppInfo *info = [self appInfoFromProxy:proxy];
        if (info.dataContainerPath) [result addObject:info];
    }
    return result;
}

+ (CRAppInfo *)appInfoForBundleIdentifier:(NSString *)bundleID {
    LSApplicationProxy *proxy = [objc_getClass("LSApplicationProxy") applicationProxyForIdentifier:bundleID];
    return [self appInfoFromProxy:proxy];
}

@end
