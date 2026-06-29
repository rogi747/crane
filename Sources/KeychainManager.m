#import "KeychainManager.h"
#import <Security/Security.h>

// All keychain item classes we care about for app isolation.
static NSArray<NSString *> *CRKeychainClasses(void) {
    return @[(__bridge NSString *)kSecClassGenericPassword,
             (__bridge NSString *)kSecClassInternetPassword,
             (__bridge NSString *)kSecClassCertificate,
             (__bridge NSString *)kSecClassKey,
             (__bridge NSString *)kSecClassIdentity];
}

@implementation KeychainManager

+ (NSInteger)probeReadableItemCountForAccessGroup:(nullable NSString *)accessGroup
                                            error:(NSError **)error {
    NSInteger total = 0;
    for (NSString *cls in CRKeychainClasses()) {
        NSMutableDictionary *query = [@{
            (__bridge id)kSecClass: cls,
            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
            (__bridge id)kSecReturnAttributes: @YES,
        } mutableCopy];
        if (accessGroup) {
            query[(__bridge id)kSecAttrAccessGroup] = accessGroup;
        }
        CFTypeRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
        if (status == errSecSuccess && result) {
            if (CFGetTypeID(result) == CFArrayGetTypeID()) {
                total += CFArrayGetCount((CFArrayRef)result);
            } else {
                total += 1;
            }
        } else if (status != errSecItemNotFound) {
            // Hard failure (e.g. missing entitlement) on a class probe.
            if (error) {
                *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                             code:status
                                         userInfo:@{NSLocalizedDescriptionKey:
                                             [NSString stringWithFormat:@"SecItemCopyMatching failed for class %@ (OSStatus %d)", cls, (int)status]}];
            }
            if (result) CFRelease(result);
            return -1;
        }
        if (result) CFRelease(result);
    }
    return total;
}

+ (nullable NSData *)dumpItemsForAccessGroups:(nullable NSArray<NSString *> *)accessGroups
                                        error:(NSError **)error {
    NSMutableArray<NSDictionary *> *dumped = [NSMutableArray array];
    NSArray<NSString *> *groups = accessGroups ?: @[ (id)[NSNull null] ];
    for (id groupObj in groups) {
        NSString *accessGroup = [groupObj isKindOfClass:[NSString class]] ? groupObj : nil;
        for (NSString *cls in CRKeychainClasses()) {
            NSMutableDictionary *query = [@{
                (__bridge id)kSecClass: cls,
                (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
                (__bridge id)kSecReturnAttributes: @YES,
                (__bridge id)kSecReturnData: @YES,
            } mutableCopy];
            if (accessGroup) {
                query[(__bridge id)kSecAttrAccessGroup] = accessGroup;
            }
            CFTypeRef result = NULL;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
            if (status == errSecSuccess && result) {
                NSArray *items = (CFGetTypeID(result) == CFArrayGetTypeID())
                    ? (__bridge NSArray *)result
                    : @[ (__bridge id)result ];
                for (NSDictionary *attrs in items) {
                    NSMutableDictionary *entry = [attrs mutableCopy];
                    entry[@"__cls"] = cls;
                    [dumped addObject:entry];
                }
            } else if (status != errSecItemNotFound) {
                if (error) {
                    *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                                 code:status
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                 [NSString stringWithFormat:@"dump failed for class %@ (OSStatus %d)", cls, (int)status]}];
                }
                if (result) CFRelease(result);
                return nil;
            }
            if (result) CFRelease(result);
        }
    }
    return [NSKeyedArchiver archivedDataWithRootObject:dumped requiringSecureCoding:NO error:error];
}

+ (BOOL)deleteItemsForAccessGroups:(nullable NSArray<NSString *> *)accessGroups
                             error:(NSError **)error {
    NSArray<NSString *> *groups = accessGroups ?: @[ (id)[NSNull null] ];
    for (id groupObj in groups) {
        NSString *accessGroup = [groupObj isKindOfClass:[NSString class]] ? groupObj : nil;
        for (NSString *cls in CRKeychainClasses()) {
            NSMutableDictionary *query = [@{
                (__bridge id)kSecClass: cls,
            } mutableCopy];
            if (accessGroup) {
                query[(__bridge id)kSecAttrAccessGroup] = accessGroup;
            }
            OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
            if (status != errSecSuccess && status != errSecItemNotFound) {
                if (error) {
                    *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                                 code:status
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                 [NSString stringWithFormat:@"delete failed for class %@ (OSStatus %d)", cls, (int)status]}];
                }
                return NO;
            }
        }
    }
    return YES;
}

+ (BOOL)restoreItemsFromBlob:(NSData *)blob
                       error:(NSError **)error {
    NSArray<NSDictionary *> *dumped = [NSKeyedUnarchiver unarchivedObjectOfClasses:
        [NSSet setWithObjects:[NSArray class], [NSDictionary class], [NSString class], [NSData class], [NSNumber class], [NSDate class], nil]
                                                                          fromData:blob
                                                                             error:error];
    if (!dumped) return NO;
    for (NSDictionary *entry in dumped) {
        NSMutableDictionary *add = [entry mutableCopy];
        NSString *cls = add[@"__cls"];
        [add removeObjectForKey:@"__cls"];
        if (cls) {
            add[(__bridge id)kSecClass] = cls;
        }
        OSStatus status = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
        if (status != errSecSuccess && status != errSecDuplicateItem) {
            if (error) {
                *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                             code:status
                                         userInfo:@{NSLocalizedDescriptionKey:
                                             [NSString stringWithFormat:@"restore SecItemAdd failed (OSStatus %d)", (int)status]}];
            }
            return NO;
        }
    }
    return YES;
}

@end
