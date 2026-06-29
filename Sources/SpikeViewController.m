#import "SpikeViewController.h"
#import "MappingResolver.h"
#import "DataContainerManager.h"
#import "KeychainManager.h"

// Phase 0 spike UI.
//
// C-1 (mapping) and C-3 (keychain probe) run from the "Run" button.
// C-2 (data swap) runs from the "Apps" button and is DRY-RUN ONLY: it lists
// installed apps, lets you pick one, creates a test container, and prints the
// exact swap plan (paths) WITHOUT moving anything. Real swap stays disabled
// until paths are verified on-device.
//
// Keychain isolation is DISABLED: the C-3 cross-app probe failed on TrollStore,
// so the project is locked to fallback (a): data + cookie isolation, shared
// keychain. The probe is kept only for diagnostics.

static NSString *const kSpikeTestContainerName = @"__crane_spike_test";

@interface SpikeViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) NSArray<CRAppInfo *> *pickerApps;
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
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Apps"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(showAppPicker)];
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
    [self log:@"\n[C-2] Tap 'Apps' (top-left) to pick a target app for a DRY-RUN swap plan."];
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

#pragma mark - C-3 Keychain probe (diagnostic only)

- (void)runC3KeychainProbe {
    [self log:@"\n[C-3] Keychain cross-app probe (diagnostic)"];
    [self log:@"  NOTE: isolation locked to fallback (a): shared keychain."];
    NSError *err = nil;
    NSInteger ownCount = [KeychainManager probeReadableItemCountForAccessGroup:nil error:&err];
    if (ownCount < 0) {
        [self log:@"  own-keychain probe FAILED: %@", err.localizedDescription];
    } else {
        [self log:@"  own/default keychain readable items: %ld", (long)ownCount];
    }
    NSError *err2 = nil;
    NSInteger appleCount = [KeychainManager probeReadableItemCountForAccessGroup:@"apple" error:&err2];
    if (appleCount < 0) {
        [self log:@"  cross-group probe FAILED (expected): %@", err2.localizedDescription];
    } else {
        [self log:@"  cross-group readable items: %ld", (long)appleCount];
    }
}

#pragma mark - C-2 Data swap (DRY-RUN app picker)

- (void)showAppPicker {
    UITableViewController *picker = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    picker.title = @"Pick target app (dry-run)";
    picker.tableView.dataSource = self;
    picker.tableView.delegate = self;
    self.pickerApps = [MappingResolver installedUserApps];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    picker.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                      target:self
                                                      action:@selector(dismissPicker)];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)dismissPicker {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self pickerApps].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"c"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
    CRAppInfo *info = [self pickerApps][indexPath.row];
    cell.textLabel.text = info.displayName;
    cell.detailTextLabel.text = info.bundleIdentifier;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CRAppInfo *info = [self pickerApps][indexPath.row];
    [self dismissViewControllerAnimated:YES completion:^{
        [self runC2DryRunForApp:info];
    }];
}

- (void)runC2DryRunForApp:(CRAppInfo *)info {
    [self log:@"\n[C-2] DRY-RUN swap plan for %@", info.bundleIdentifier];
    [self log:@"  display: %@", info.displayName];
    [self log:@"  live data path: %@", info.dataContainerPath ?: @"(nil)"];
    if (!info.dataContainerPath) {
        [self log:@"  ABORT: no live data path resolved."];
        return;
    }

    NSString *storeRoot = [DataContainerManager storeRootForBundleIdentifier:info.bundleIdentifier];
    [self log:@"  store root: %@", storeRoot];

    // Create the test container for real (safe: it only makes folders in the
    // manager's own Documents, never touches the target app).
    NSError *err = nil;
    BOOL created = [DataContainerManager createContainerNamed:kSpikeTestContainerName
                                          forBundleIdentifier:info.bundleIdentifier
                                                        error:&err];
    if (created) {
        [self log:@"  created test container '%@' OK", kSpikeTestContainerName];
    } else {
        [self log:@"  test container create: %@", err ? err.localizedDescription : @"already exists / skipped"];
    }

    NSString *toPath = [[storeRoot stringByAppendingPathComponent:kSpikeTestContainerName] copy];
    [self log:@"  --- planned swap (NOT executed) ---"];
    [self log:@"  1. move live -> store/<active>:"];
    [self log:@"       %@", info.dataContainerPath];
    [self log:@"  2. move target -> live UUID path:"];
    [self log:@"       %@", toPath];
    [self log:@"       -> %@", info.dataContainerPath];
    [self log:@"  3. write metadata active=%@", kSpikeTestContainerName];
    [self log:@"  --- end plan (dry-run, nothing moved) ---"];
    [self log:@"  Verify both paths above look correct before enabling real swap."];
}

@end
