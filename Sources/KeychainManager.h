#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Optional, pluggable module. The core engine (data + cookie isolation) does
// NOT depend on this. If the Phase 0 cross-app keychain spike fails, the app
// falls back to shared-keychain mode and this module is left disabled.
@interface KeychainManager : NSObject

// Phase 0 spike: probe whether this (TrollStore-signed) process can read
// keychain items belonging to another app's access group. Returns the number
// of items readable, or -1 with error populated on hard failure.
+ (NSInteger)probeReadableItemCountForAccessGroup:(nullable NSString *)accessGroup
                                            error:(NSError **)error;

// Dump all keychain items for the given access groups into a serializable blob.
+ (nullable NSData *)dumpItemsForAccessGroups:(nullable NSArray<NSString *> *)accessGroups
                                        error:(NSError **)error;

// Delete all keychain items for the given access groups from the live keychain.
+ (BOOL)deleteItemsForAccessGroups:(nullable NSArray<NSString *> *)accessGroups
                             error:(NSError **)error;

// Restore items from a previously dumped blob into the live keychain.
+ (BOOL)restoreItemsFromBlob:(NSData *)blob
                       error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
