//
//  PJProjectorListViewController.m
//  ProjectR
//
//  Created by Eric Hyche on 1/4/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJProjectorListViewController.h"
#import "PJProjectorManager.h"
#import "PJProjector.h"
#import "PJInputInfo.h"
#import "PJResponseInfo.h"
#import "PJProjectorDetailViewController.h"
#import "PJManualAddTableViewController.h"
#import "NSIndexSet+NSIndexPath.h"
#import "PJSubnetScannerViewController.h"
#import "PJBeaconListenerViewController.h"
#import "PJNoProjectorsTableViewCell.h"
#import "PJProjectorTableViewCell.h"
#import "PJProjectorTableViewCellDelegate.h"
#import "PJInputPickerView.h"
@import extobjc;

@interface PJProjectorListViewController () <PJProjectorTableViewCellDelegate,
                                             PJInputPickerViewDelegate>

@property(nonatomic,strong) UIBarButtonItem*   addBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*   selectAllBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*   clearAllBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*   selectBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*   cancelBarButtonItem;
@property(nonatomic,strong) NSMutableArray*    selectedProjectors;
@property(nonatomic,strong) UIBarButtonItem*   inputBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*   powerStatusBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*   audioMuteBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*   videoMuteBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*   deleteBarButtonItem;
@property(nonatomic,strong) NSMutableArray*    inputNames;
@property(nonatomic,strong) PJInputPickerView* inputPickerView;

@end

@implementation PJProjectorListViewController

- (void)dealloc {
    [self unsubscribeFromKVONotifications];
}

- (id)init {
    return [self initWithStyle:UITableViewStyleGrouped];
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        [self commonInit];
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Tell the projector manager to start refreshing
    [[PJProjectorManager sharedManager] beginRefreshingAllProjectorsForReason:PJRefreshReasonAppStateChange];
    
    self.selectBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Select"
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(selectButtonAction:)];
    self.cancelBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(selectButtonAction:)];
    self.addBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                          target:self
                                                                          action:@selector(addButtonAction:)];
    self.selectAllBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Select All"
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(selectAllBarButtonItemAction:)];
    self.clearAllBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear All"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(clearAllBarButtonItemAction:)];
    // Set up the toolbar
    self.powerStatusBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"mypower"]
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(powerStatusBarButtonItemAction:)];
    self.inputBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"703-download"]
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(inputBarButtonItemAction:)];
    self.audioMuteBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"771-sound-muted"]
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(audioMuteBarButtonItemAction:)];
    self.videoMuteBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"733-video-camera-mute"]
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(videoMuteBarButtonItemAction:)];
    self.deleteBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                             target:self
                                                                             action:@selector(deleteBarButtonItemAction:)];
    self.toolbarItems = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
                          self.powerStatusBarButtonItem,
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
                          self.inputBarButtonItem,
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
                          self.audioMuteBarButtonItem,
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
                          self.videoMuteBarButtonItem,
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
                          self.deleteBarButtonItem,
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL]];
    [self updateNavigationItemStateAnimated:NO];
    // Create the input picker view
    self.inputPickerView = [[PJInputPickerView alloc] initWithFrame:self.view.bounds];
    self.inputPickerView.delegate = self;
    
    // Load the table view
    [self reloadTableViewData];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    NSUInteger projectorCount = [mgr countOfProjectors];
    
    NSInteger ret = (projectorCount > 0 ? projectorCount : 1);
    
    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;

    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    NSUInteger projectorCount = [mgr countOfProjectors];
    
    if (projectorCount > 0) {
        PJProjectorTableViewCell* projectorCell = (PJProjectorTableViewCell*) [tableView dequeueReusableCellWithIdentifier:[PJProjectorTableViewCell reuseID]];
        if (projectorCell == nil) {
            projectorCell = [[PJProjectorTableViewCell alloc] init];
            projectorCell.delegate = self;
        }
        // Get the projector for this row
        PJProjector* projector = (PJProjector*) [mgr objectInProjectorsAtIndex:indexPath.row];
        projectorCell.projector = projector;
        projectorCell.multiSelect = [self.selectedProjectors containsObject:projector];
        cell = projectorCell;
    } else {
        PJNoProjectorsTableViewCell* noProjectorsCell = (PJNoProjectorsTableViewCell*) [tableView dequeueReusableCellWithIdentifier:[PJNoProjectorsTableViewCell reuseID]];
        if (noProjectorsCell == nil) {
            noProjectorsCell = [[PJNoProjectorsTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:[PJNoProjectorsTableViewCell reuseID]];
        }
        cell = noProjectorsCell;
    }

    return cell;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* ret = nil;
    
    // If we have any projectors, then use a section header. Otherwise, do not.
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    if ([mgr countOfProjectors] > 0) {
        ret = @"Projectors";
    }

    return ret;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    // Get the projector for this row
    PJProjector* projector = [mgr objectInProjectorsAtIndex:indexPath.row];
    // Delete this projector
    [mgr removeProjectorsFromManager:@[projector]];
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    NSUInteger projectorsCount = [mgr countOfProjectors];
    if (indexPath.row < projectorsCount) {
        PJProjector* projector = (PJProjector*) [mgr objectInProjectorsAtIndex:indexPath.row];
        // Create a detail view controller
        PJProjectorDetailViewController* controller = [[PJProjectorDetailViewController alloc] init];
        // Assign the projector to the controller
        controller.projector = projector;
        // Push this controller
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCellEditingStyle ret = UITableViewCellEditingStyleNone;

    return ret;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height = 0.0;

    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    if ([mgr countOfProjectors] > 0) {
        // Get the projector for this row
        PJProjector* projector = [mgr objectInProjectorsAtIndex:indexPath.row];
        height = [PJProjectorTableViewCell heightForProjector:projector containerWidth:self.tableView.frame.size.width];
    } else {
        height = [PJNoProjectorsTableViewCell preferredHeight];
    }

    return height;
}

#pragma mark - PJInputPickerViewDelegate methods

- (void)inputPickerViewDidCancel:(PJInputPickerView *)inputPicker {
    [self.tableView setEditing:NO animated:YES];
    [self updateNavigationItemStateAnimated:YES];
    [self updateToolbarHiddenStateAnimated:YES];
    [self.inputPickerView showHide:NO animated:YES withCompletion:^(BOOL finished) {
        [self.inputPickerView removeFromSuperview];
    }];
}

- (void)inputPickerView:(PJInputPickerView *)inputPicker didSelectInputWithName:(NSString *)inputName {
    [self changeSelectedProjectorsInputTo:inputName];
    [self.tableView setEditing:NO animated:YES];
    [self updateNavigationItemStateAnimated:YES];
    [self updateToolbarHiddenStateAnimated:YES];
    [self.inputPickerView showHide:NO animated:YES withCompletion:^(BOOL finished) {
        [self.inputPickerView removeFromSuperview];
    }];
}

#pragma mark - PJProjectorTableViewCellDelegate methods

- (void)projectorCell:(PJProjectorTableViewCell*)cell switchValueChangedTo:(BOOL)isOn {
    // Request a power status change
    [cell.projector requestPowerStateChange:isOn];
}

- (void)projectorCellInputButtonWasSelected:(PJProjectorTableViewCell*)cell {
    // Find out which projector in the projector manager this is. Initially
    // we set the projector index to an invalid value, and then look for a match.
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    NSUInteger projectorsCount = [mgr countOfProjectors];
    NSUInteger projectorIndex = projectorsCount;
    for (NSUInteger i = 0; i < projectorsCount; i++) {
        PJProjector *ithProjector = [mgr objectInProjectorsAtIndex:i];
        if (ithProjector == cell.projector) {
            projectorIndex = i;
            break;
        }
    }
    if (projectorIndex < projectorsCount) {
        // Create a UIAlertController with the available inputs for this projector
        UIAlertController* controller = [UIAlertController alertControllerWithTitle:@"Select Input"
                                                                            message:nil
                                                                     preferredStyle:UIAlertControllerStyleActionSheet];
        @weakify(self);
        // Add titles for each input
        for (NSUInteger i = 0; i < [cell.projector countOfInputs]; i++) {
            PJInputInfo *ithInput = [cell.projector objectInInputsAtIndex:i];
            NSString* inputName = [ithInput description];
            UIAlertAction* ithInputAction = [UIAlertAction actionWithTitle:inputName
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * _Nonnull action) {
                @strongify(self);
                [self changeSelectedProjectorsInputTo:inputName];
                [self.tableView setEditing:NO animated:YES];
                [self updateNavigationItemStateAnimated:YES];
                [self updateToolbarHiddenStateAnimated:YES];
                [self dismissViewControllerAnimated:YES completion:nil];
            }];
            [controller addAction:ithInputAction];
        }
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];
        [controller addAction:cancelAction];

        [self presentViewController:controller animated:YES completion:nil];
    }
}

- (void)projectorCellMultiSelectionStateChanged:(PJProjectorTableViewCell *)cell {
    if (cell.multiSelect) {
        [self.selectedProjectors addObject:cell.projector];
    } else {
        [self.selectedProjectors removeObject:cell.projector];
    }
    [self updateNavigationItemStateAnimated:YES];
    [self updateToolbarHiddenStateAnimated:YES];
}

#pragma mark - PJProjectorListViewController private methods

- (void)reloadTableViewData {
    [self updateTableViewState];
    [self.tableView reloadData];
}

- (void)updateTableViewState {
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    if ([mgr countOfProjectors] > 0) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.tableView.scrollEnabled = YES;
    } else {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.scrollEnabled = NO;
    }
}

- (void)subscribeToKVONotifications {
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    [mgr addObserver:self
          forKeyPath:kPJProjectorManagerKeyProjectors
             options:NSKeyValueObservingOptionNew
             context:NULL];
}

- (void)unsubscribeFromKVONotifications {
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    [mgr removeObserver:self forKeyPath:kPJProjectorManagerKeyProjectors context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    // Make sure the object is the projector manager
    if (object == mgr) {
        // Make sure this is the ".projectors" keypath
        if ([keyPath isEqualToString:kPJProjectorManagerKeyProjectors]) {
            // Get the change kind
            NSKeyValueChange changeKind = [[change objectForKey:NSKeyValueChangeKindKey] integerValue];
            // Switch on the kind of change it is
            if (changeKind == NSKeyValueChangeSetting) {
                [self projectorsDidChange];
            } else if (changeKind == NSKeyValueChangeInsertion) {
                // Get the index set that were inserted
                NSIndexSet* indexSet = [change objectForKey:NSKeyValueChangeIndexesKey];
                [self projectorsWereInserted:indexSet];
            } else if (changeKind == NSKeyValueChangeRemoval) {
                // Get the index set that were removed
                NSIndexSet* indexSet = [change objectForKey:NSKeyValueChangeIndexesKey];
                [self projectorsWereRemoved:indexSet];
            } else if (changeKind == NSKeyValueChangeReplacement) {
                // Even though the change kind is "replacement", this just
                // means that a projector changed.
                // Get the index set that were changed
                NSIndexSet* indexSet = [change objectForKey:NSKeyValueChangeIndexesKey];
                [self projectorsWereUpdated:indexSet];
            }
        }
    }
}

- (void)projectorsDidChange {
    [self updateNavigationItemStateAnimated:YES];
    [self reloadTableViewData];
}

- (void)projectorsWereInserted:(NSIndexSet*)indexSet {
    [self updateTableViewState];
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    BOOL firstProjectorsAdded = ([indexSet count] == [mgr countOfProjectors]);
    if (firstProjectorsAdded) {
        // If this was the first projector added, then we need to reload
        // the whole section so that we get rid of the footer
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
    } else {
        [self.tableView insertRowsAtIndexPaths:[indexSet indexPathsForSection:0] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    [self updateNavigationItemStateAnimated:YES];
}

- (void)projectorsWereRemoved:(NSIndexSet*)indexSet {
    [self updateTableViewState];
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    if ([mgr countOfProjectors] == 0) {
        // If the last projectors were removed, then we need
        // reload the whole section so that we will show the footer
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
    } else {
        [self.tableView deleteRowsAtIndexPaths:[indexSet indexPathsForSection:0] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    [self updateNavigationItemStateAnimated:YES];
}

- (void)projectorsWereUpdated:(NSIndexSet*)indexSet {
    [self updateTableViewState];
    [self.tableView reloadRowsAtIndexPaths:[indexSet indexPathsForSection:0] withRowAnimation:UITableViewRowAnimationNone];
    [self updateNavigationItemStateAnimated:YES];
}

- (void)commonInit {
    [self subscribeToKVONotifications];
    self.selectedProjectors = [NSMutableArray array];
    self.inputNames         = [NSMutableArray array];
    self.navigationItem.title = @"ProjectR";
}

- (void)addButtonAction:(id)sender {
    UIAlertController* controller = [UIAlertController alertControllerWithTitle:@"Add A Projector"
                                                                        message:@"Choose an option"
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    @weakify(self);
    UIAlertAction* addAction = [UIAlertAction actionWithTitle:@"Add Manually"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self);
        // Manually add a projector
        PJManualAddTableViewController* addController = [[PJManualAddTableViewController alloc] init];
        // Wrap this in a UINavigationController
        UINavigationController* navController = [[UINavigationController alloc] initWithRootViewController:addController];
        // Present this controller
        [self presentViewController:navController animated:YES completion:nil];
    }];
    UIAlertAction* scanAction = [UIAlertAction actionWithTitle:@"Scan WiFi Network"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self);
        // Create a subnet scanner controller
        PJSubnetScannerViewController* scanController = [[PJSubnetScannerViewController alloc] init];
        // Wrap this in a UINavigationController
        UINavigationController* navController = [[UINavigationController alloc] initWithRootViewController:scanController];
        // Present this controller
        [self presentViewController:navController animated:YES completion:nil];
    }];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [controller addAction:addAction];
    [controller addAction:scanAction];
    [controller addAction:cancelAction];

    [self presentViewController:controller animated:YES completion:nil];
}

- (void)selectButtonAction:(id)sender {
    BOOL newEditingMode = !self.tableView.isEditing;
    [self.tableView setEditing:newEditingMode animated:YES];
    [self updateNavigationItemStateAnimated:YES];
    [self updateToolbarHiddenStateAnimated:YES];
}

- (void)selectAllBarButtonItemAction:(id)sender {
    [self.selectedProjectors removeAllObjects];
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    for (NSUInteger i = 0; i < [mgr countOfProjectors]; i++) {
        PJProjector* ithProjector = [mgr objectInProjectorsAtIndex:i];
        [self.selectedProjectors addObject:ithProjector];
    }
    [self updateNavigationItemStateAnimated:YES];
    [self updateToolbarHiddenStateAnimated:YES];
    [self reloadTableViewData];
}

- (void)clearAllBarButtonItemAction:(id)sender {
    [self.selectedProjectors removeAllObjects];
    [self updateNavigationItemStateAnimated:YES];
    [self updateToolbarHiddenStateAnimated:YES];
    [self reloadTableViewData];
}

- (void)inputBarButtonItemAction:(id)sender {
    [self.inputNames removeAllObjects];
    for (PJProjector *selectedProjector in self.selectedProjectors) {
        for (NSUInteger i = 0; i < [selectedProjector countOfInputs]; i++) {
            PJInputInfo *ithInput = [selectedProjector objectInInputsAtIndex:i];
            NSString *inputName = [ithInput description];
            if (![self.inputNames containsObject:inputName]) {
                [self.inputNames addObject:inputName];
            }
        }
    }
    self.inputPickerView.inputNames = self.inputNames;
    [self.inputPickerView showHide:NO animated:NO withCompletion:nil];
    self.inputPickerView.frame = self.navigationController.view.bounds;
    self.inputPickerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.navigationController.view addSubview:self.inputPickerView];
    [self.inputPickerView showHide:YES animated:YES withCompletion:nil];
}

- (void)powerStatusBarButtonItemAction:(id)sender {
    UIAlertController* controller = [UIAlertController alertControllerWithTitle:@"Turn Selected Projectors"
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    @weakify(self);
    UIAlertAction* onAction = [UIAlertAction actionWithTitle:@"On"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self);
        [self changeSelectedProjectorsPowerStatusTo:YES];
        [self.tableView setEditing:NO animated:YES];
        [self updateNavigationItemStateAnimated:YES];
        [self updateToolbarHiddenStateAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    UIAlertAction* offAction = [UIAlertAction actionWithTitle:@"Off"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self);
        [self changeSelectedProjectorsPowerStatusTo:NO];
        [self.tableView setEditing:NO animated:YES];
        [self updateNavigationItemStateAnimated:YES];
        [self updateToolbarHiddenStateAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [controller addAction:onAction];
    [controller addAction:offAction];
    [controller addAction:cancelAction];

    [self presentViewController:controller animated:YES completion:nil];
}

- (void)audioMuteBarButtonItemAction:(id)sender {
    UIAlertController* controller = [UIAlertController alertControllerWithTitle:@"Turn Audio Mute"
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    @weakify(self);
    UIAlertAction* onAction = [UIAlertAction actionWithTitle:@"On"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self);
        [self changeSelectedProjectorsAudioMuteTo:YES];
        [self.tableView setEditing:NO animated:YES];
        [self updateNavigationItemStateAnimated:YES];
        [self updateToolbarHiddenStateAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    UIAlertAction* offAction = [UIAlertAction actionWithTitle:@"Off"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self);
        [self changeSelectedProjectorsAudioMuteTo:NO];
        [self.tableView setEditing:NO animated:YES];
        [self updateNavigationItemStateAnimated:YES];
        [self updateToolbarHiddenStateAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [controller addAction:onAction];
    [controller addAction:offAction];
    [controller addAction:cancelAction];

    [self presentViewController:controller animated:YES completion:nil];
}

- (void)videoMuteBarButtonItemAction:(id)sender {
    UIAlertController* controller = [UIAlertController alertControllerWithTitle:@"Turn Video Mute"
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    @weakify(self);
    UIAlertAction* onAction = [UIAlertAction actionWithTitle:@"On"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self);
        [self changeSelectedProjectorsVideoMuteTo:YES];
        [self.tableView setEditing:NO animated:YES];
        [self updateNavigationItemStateAnimated:YES];
        [self updateToolbarHiddenStateAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    UIAlertAction* offAction = [UIAlertAction actionWithTitle:@"Off"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self);
        [self changeSelectedProjectorsVideoMuteTo:NO];
        [self.tableView setEditing:NO animated:YES];
        [self updateNavigationItemStateAnimated:YES];
        [self updateToolbarHiddenStateAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [controller addAction:onAction];
    [controller addAction:offAction];
    [controller addAction:cancelAction];

    [self presentViewController:controller animated:YES completion:nil];
}

- (void)deleteBarButtonItemAction:(id)sender {
    UIAlertController* controller = [UIAlertController alertControllerWithTitle:@"Delete Selected Projectors?"
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    @weakify(self);
    UIAlertAction* confirmAction = [UIAlertAction actionWithTitle:@"Confirm"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self);
        PJProjectorManager *mgr = [PJProjectorManager sharedManager];
        [mgr removeProjectorsFromManager:self.selectedProjectors];
        [self.tableView setEditing:NO animated:YES];
        [self updateNavigationItemStateAnimated:YES];
        [self updateToolbarHiddenStateAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [controller addAction:confirmAction];
    [controller addAction:cancelAction];

    [self presentViewController:controller animated:YES completion:nil];
}

- (void)changeSelectedProjectorsInputTo:(NSString*)inputName {
    for (PJProjector* selectedProjector in self.selectedProjectors) {
        NSUInteger inputsCount = [selectedProjector countOfInputs];
        NSUInteger selectedInputIndex = inputsCount;
        for (NSUInteger i = 0; i < inputsCount; i++) {
            PJInputInfo *ithInputInfo = [selectedProjector objectInInputsAtIndex:i];
            NSString *ithInputName = [ithInputInfo description];
            if ([inputName isEqualToString:ithInputName]) {
                selectedInputIndex = i;
                break;
            }
        }
        if (selectedInputIndex < inputsCount) {
            if (selectedInputIndex != selectedProjector.activeInputIndex) {
                [selectedProjector requestInputChangeToInputIndex:selectedInputIndex];
            }
        }
    }
}

- (void)changeSelectedProjectorsPowerStatusTo:(BOOL)requestOn {
    for (PJProjector* selectedProjector in self.selectedProjectors) {
        [selectedProjector requestPowerStateChange:requestOn];
    }
}

- (void)changeSelectedProjectorsAudioMuteTo:(BOOL)muteOn {
    for (PJProjector* selectedProjector in self.selectedProjectors) {
        [selectedProjector requestMuteStateChange:muteOn forTypes:PJMuteTypeAudio];
    }
}

- (void)changeSelectedProjectorsVideoMuteTo:(BOOL)muteOn {
    for (PJProjector* selectedProjector in self.selectedProjectors) {
        [selectedProjector requestMuteStateChange:muteOn forTypes:PJMuteTypeVideo];
    }
}

- (void)updateNavigationItemStateAnimated:(BOOL)animated {
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    NSUInteger projectorCount = [mgr countOfProjectors];
    if (self.tableView.isEditing) {
        [self.navigationItem setLeftBarButtonItem:self.cancelBarButtonItem animated:animated];
        BOOL allProjectorsSelected = YES;
        for (NSUInteger i = 0; i < projectorCount; i++) {
            PJProjector* ithProjector = [mgr objectInProjectorsAtIndex:i];
            if (![self.selectedProjectors containsObject:ithProjector]) {
                allProjectorsSelected = NO;
                break;
            }
        }
        UIBarButtonItem* rightItem = (allProjectorsSelected ? self.clearAllBarButtonItem : self.selectAllBarButtonItem);
        [self.navigationItem setRightBarButtonItem:rightItem animated:animated];
    } else {
        [self.navigationItem setRightBarButtonItem:self.addBarButtonItem animated:animated];
        UIBarButtonItem* leftItem = (projectorCount > 0 ? self.selectBarButtonItem : nil);
        [self.navigationItem setLeftBarButtonItem:leftItem animated:animated];
    }
}

- (void)updateToolbarHiddenStateAnimated:(BOOL)animated {
    if (self.tableView.isEditing) {
        BOOL isToolbarHidden = self.navigationController.toolbarHidden;
        BOOL shouldToolbarBeHidden = ([self.selectedProjectors count] > 0 ? NO : YES);
        if (isToolbarHidden != shouldToolbarBeHidden) {
            [self.navigationController setToolbarHidden:shouldToolbarBeHidden animated:animated];
        }
    } else {
        [self.navigationController setToolbarHidden:YES animated:animated];
    }
}

@end
