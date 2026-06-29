#import "SpikeViewController.h"
#import "MappingResolver.h"
#import "DataContainerManager.h"
#import "KeychainManager.h"

@interface SpikeViewController ()
@property (nonatomic, strong) UITextView *logView;
@end

@implementation SpikeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Crane Phase 0 Spike";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.logView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.logView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logView.editable = NO;
    self.logView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.logView.alwaysBounceVertical = YES;
    [self.view addSubview:self.logView];

    [NSLayoutConstraint activateConstraints:@[
        [self.logView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.logView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.logView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [self.logView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Run"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(runSpikes)];
}

- (void)log:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logView.text = [self.logView.text stringByAppendingFormat:@"%@\n", line];
    });
}

- (void)runSpikes {
    self.logView.text = @"";
    [self log:@"=== Crane Phase 0 Spike ==="];
    [self runC1Mapping];
    [self runC3KeychainProbe];
    [self log:@"\nDone. C-2 data swap requires picking a target app; see runC2 note."];
}

#pragma mark - C-1 Mapping

- (void)runC1Mapping {
    [self log:@"\n[C-1] Mapping bundleID -> data container"];
    NSArray<CRAppInfo *> *apps = [MappingResolver installedUserApps];
    [self log:@"  enumerated %lu user apps", (unsigned long)apps.count];
    NSUInteger shown = 0;
    for (CRAppInfo *info in apps) {
        if (shown++ >= 8) break;
        [self log:@"  - %@\n      uuid=%@", info.bundleIdentifier, info.dataContainerUUID ?: @"(nil)"];
    }
    if (apps.count == 0) {
        [self log:@"  WARN: 0 apps. LSApplicationWorkspace likely blocked by missing entitlement."];
    }
}

#pragma mark - C-3 Keychain probe

- (void)runC3KeychainProbe {
    [self log:@"\n[C-3] Keychain cross-app probe"];
    NSError *err = nil;
    NSInteger ownCount = [KeychainManager probeReadableItemCountForAccessGroup:nil error:&err];
    if (ownCount < 0) {
        [self log:@"  own-keychain probe FAILED: %@", err.localizedDescription];
    } else {
        [self log:@"  own/default keychain readable items: %ld", (long)ownCount];
    }

    // Probe a well-known Apple access group to test cross-app reach.
    NSError *err2 = nil;
    NSInteger appleCount = [KeychainManager probeReadableItemCountForAccessGroup:@"apple" error:&err2];
    if (appleCount < 0) {
        [self log:@"  cross-group ('apple') probe FAILED: %@", err2.localizedDescription];
        [self log:@"  => likely NO cross-app keychain access. Fallback (a): shared keychain."];
    } else {
        [self log:@"  cross-group ('apple') readable items: %ld", (long)appleCount];
        [self log:@"  => cross-app keychain MIGHT be possible. Verify with a real target app group."];
    }
}

@end
