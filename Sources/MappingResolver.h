#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CRAppInfo : NSObject
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *dataContainerUUID;
@property (nonatomic, copy, nullable) NSString *dataContainerPath;
@end

@interface MappingResolver : NSObject

// Enumerate user-installed apps with their data container path resolved.
+ (NSArray<CRAppInfo *> *)installedUserApps;

// Resolve a single bundleID -> data container info.
+ (nullable CRAppInfo *)appInfoForBundleIdentifier:(NSString *)bundleID;

@end

NS_ASSUME_NONNULL_END
