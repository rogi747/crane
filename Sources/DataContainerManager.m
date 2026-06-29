#import "DataContainerManager.h"

static NSString *const kCraneStoreDirName = @"CraneStore";

@implementation DataContainerManager

+ (NSString *)storeBaseDir {
    // Manager app's own Documents directory holds the container store.
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs = paths.firstObject;
    return [docs stringByAppendingPathComponent:kCraneStoreDirName];
}

+ (NSString *)storeRootForBundleIdentifier:(NSString *)bundleID {
    return [[self storeBaseDir] stringByAppendingPathComponent:bundleID];
}

+ (NSString *)pathForContainerNamed:(NSString *)name forBundleIdentifier:(NSString *)bundleID {
    return [[self storeRootForBundleIdentifier:bundleID] stringByAppendingPathComponent:name];
}

+ (BOOL)createContainerNamed:(NSString *)name
           forBundleIdentifier:(NSString *)bundleID
                         error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *containerPath = [self pathForContainerNamed:name forBundleIdentifier:bundleID];
    if ([fm fileExistsAtPath:containerPath]) {
        if (error) *error = [NSError errorWithDomain:@"crane" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Container already exists"}];
        return NO;
    }
    // Skeleton matching an iOS data container layout.
    NSArray<NSString *> *skeleton = @[@"Documents", @"Library", @"Library/Caches", @"Library/Preferences", @"Library/Cookies", @"tmp", @"SystemData"];
    for (NSString *sub in skeleton) {
        NSString *full = [containerPath stringByAppendingPathComponent:sub];
        if (![fm createDirectoryAtPath:full withIntermediateDirectories:YES attributes:nil error:error]) {
            return NO;
        }
    }
    return YES;
}

+ (BOOL)moveItemAtPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:dst]) {
        if (![fm removeItemAtPath:dst error:error]) return NO;
    }
    return [fm moveItemAtPath:src toPath:dst error:error];
}

+ (BOOL)swapLiveContainerForBundleIdentifier:(NSString *)bundleID
                                  liveDataPath:(NSString *)liveDataPath
                                fromContainer:(nullable NSString *)fromContainerName
                                  toContainer:(NSString *)toContainerName
                                         error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *toPath = [self pathForContainerNamed:toContainerName forBundleIdentifier:bundleID];
    if (![fm fileExistsAtPath:toPath]) {
        if (error) *error = [NSError errorWithDomain:@"crane" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Target container does not exist"}];
        return NO;
    }

    // Staging path for the currently-live data (so we can roll back).
    NSString *stagePath = [liveDataPath stringByAppendingPathExtension:@"crane-stage"];

    // Step 1: move live data aside to staging.
    if (![self moveItemAtPath:liveDataPath toPath:stagePath error:error]) {
        return NO;
    }

    // Step 2: move target container data into the live UUID path.
    if (![fm moveItemAtPath:toPath toPath:liveDataPath error:error]) {
        // Rollback: restore live data from staging.
        [self moveItemAtPath:stagePath toPath:liveDataPath error:nil];
        return NO;
    }

    // Step 3: archive the staged (previously live) data under fromContainer.
    if (fromContainerName) {
        NSString *fromPath = [self pathForContainerNamed:fromContainerName forBundleIdentifier:bundleID];
        if (![self moveItemAtPath:stagePath toPath:fromPath error:error]) {
            // Rollback step 2 + step 1.
            [self moveItemAtPath:liveDataPath toPath:toPath error:nil];
            [self moveItemAtPath:stagePath toPath:liveDataPath error:nil];
            return NO;
        }
    } else {
        // No origin container to preserve into; discard staging.
        [fm removeItemAtPath:stagePath error:nil];
    }
    return YES;
}

+ (BOOL)deleteContainerNamed:(NSString *)name
           forBundleIdentifier:(NSString *)bundleID
                         error:(NSError **)error {
    NSString *containerPath = [self pathForContainerNamed:name forBundleIdentifier:bundleID];
    return [[NSFileManager defaultManager] removeItemAtPath:containerPath error:error];
}

@end
