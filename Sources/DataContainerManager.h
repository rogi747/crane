#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DataContainerManager : NSObject

// Root of the crane container store for a given bundle identifier.
// Layout: <store>/<bundleID>/<containerName>/
+ (NSString *)storeRootForBundleIdentifier:(NSString *)bundleID;

// Create a fresh empty container (skeleton folders) for a bundle.
+ (BOOL)createContainerNamed:(NSString *)name
           forBundleIdentifier:(NSString *)bundleID
                         error:(NSError **)error;

// Swap-in-place: move the live data container into the store under
// fromContainerName, then move toContainerName's stored data into the
// live UUID path. Rolls back on any failure.
+ (BOOL)swapLiveContainerForBundleIdentifier:(NSString *)bundleID
                                  liveDataPath:(NSString *)liveDataPath
                                fromContainer:(nullable NSString *)fromContainerName
                                  toContainer:(NSString *)toContainerName
                                         error:(NSError **)error;

// Delete a stored container (never the live one).
+ (BOOL)deleteContainerNamed:(NSString *)name
           forBundleIdentifier:(NSString *)bundleID
                         error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
