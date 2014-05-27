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

@interface PJProjectorListViewController () <UIActionSheetDelegate,
                                             PJProjectorTableViewCellDelegate>

@property(nonatomic,strong) UIActionSheet*   addActionSheet;
@property(nonatomic,strong) UIActionSheet*   inputActionSheet;
@property(nonatomic,strong) UIActionSheet*   powerStatusActionSheet;
@property(nonatomic,strong) UIBarButtonItem* addBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem* selectAllBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem* clearAllBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem* selectBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem* cancelBarButtonItem;
@property(nonatomic,strong) NSMutableArray*  selectedProjectors;
@property(nonatomic,strong) UIBarButtonItem* inputBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem* powerStatusBarButtonItem;
@property(nonatomic,strong) NSMutableArray*  inputNames;

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

- (void)awakeFromNib {
    [self commonInit];
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
    self.inputBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Input"
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(inputBarButtonItemAction:)];
    self.powerStatusBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Power"
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(powerStatusBarButtonItemAction:)];
    self.toolbarItems = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
                          self.inputBarButtonItem,
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
                          self.powerStatusBarButtonItem,
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL]];
    [self updateNavigationItemStateAnimated:NO];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    NSInteger ret = [mgr countOfProjectors];

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
    }

    return height;
}

#pragma mark - UIActionSheetDelegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet == self.addActionSheet) {
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            UIViewController* controller = nil;
            if (buttonIndex == 0) {
                // Manually add a projector
                controller = [[PJManualAddTableViewController alloc] init];
            } else if (buttonIndex == 1) {
                // Create a subnet scanner controller
                controller = [[PJSubnetScannerViewController alloc] init];
            } else if (buttonIndex == 2) {
                // Create an AMX Beacon listener view controller
                controller = [[PJBeaconListenerViewController alloc] init];
            }
            if (controller != nil) {
                // Wrap this in a UINavigationController
                UINavigationController* navController = [[UINavigationController alloc] initWithRootViewController:controller];
                // Present this controller
                [self presentViewController:navController animated:YES completion:nil];
            }
        }
    } else if (actionSheet == self.inputActionSheet) {
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
            [self changeSelectedProjectorsInputTo:buttonTitle];
        }
        [self.tableView setEditing:NO animated:YES];
        [self updateNavigationItemStateAnimated:YES];
        [self updateToolbarHiddenStateAnimated:YES];
    } else if (actionSheet == self.powerStatusActionSheet) {
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
            BOOL powerOn = [buttonTitle isEqualToString:@"On"];
            [self changeSelectedProjectorsPowerStatusTo:powerOn];
        }
        [self.tableView setEditing:NO animated:YES];
        [self updateNavigationItemStateAnimated:YES];
        [self updateToolbarHiddenStateAnimated:YES];
    }
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
        // Create a UIActionSheet with the available inputs for this projector
        self.inputActionSheet = [[UIActionSheet alloc] initWithTitle:@"Select Input"
                                                            delegate:self
                                                   cancelButtonTitle:@"Cancel"
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:nil];
        self.inputActionSheet.tag = projectorIndex;
        // Add titles for each input
        for (NSUInteger i = 0; i < [cell.projector countOfInputs]; i++) {
            PJInputInfo *ithInput = [cell.projector objectInInputsAtIndex:i];
            NSString *inputName = [ithInput description];
            [self.inputActionSheet addButtonWithTitle:inputName];
        }
        [self.inputActionSheet showInView:self.view];
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
    NSLog(@"XXXMEH projectorsDidChange");
    [self updateNavigationItemStateAnimated:YES];
    [self.tableView reloadData];
}

- (void)projectorsWereInserted:(NSIndexSet*)indexSet {
    NSLog(@"XXXMEH projectorsWereInserted:%@", indexSet);
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
    NSLog(@"XXXMEH projectorsWereRemoved:%@", indexSet);
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
    NSLog(@"XXXMEH projectorsWereUpdated:%@", indexSet);
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
    self.addActionSheet = [[UIActionSheet alloc] initWithTitle:@"Add A Projector"
                                                      delegate:self
                                             cancelButtonTitle:@"Cancel"
                                        destructiveButtonTitle:nil
                                             otherButtonTitles:@"Add Manually", @"Scan WiFi Network", @"Listen for AMX Beacons", nil];
    [self.addActionSheet showFromBarButtonItem:sender animated:YES];
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
    [self.tableView reloadData];
}

- (void)clearAllBarButtonItemAction:(id)sender {
    [self.selectedProjectors removeAllObjects];
    [self updateNavigationItemStateAnimated:YES];
    [self updateToolbarHiddenStateAnimated:YES];
    [self.tableView reloadData];
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
    // Create a UIActionSheet with the available inputs for this projector
    self.inputActionSheet = [[UIActionSheet alloc] initWithTitle:@"Select Input"
                                                        delegate:self
                                               cancelButtonTitle:@"Cancel"
                                          destructiveButtonTitle:nil
                                               otherButtonTitles:nil];
    for (NSString* inputName in self.inputNames) {
        [self.inputActionSheet addButtonWithTitle:inputName];
    }
    [self.inputActionSheet showFromBarButtonItem:sender animated:YES];
}

- (void)powerStatusBarButtonItemAction:(id)sender {
    self.powerStatusActionSheet = [[UIActionSheet alloc] initWithTitle:@"Turn Selected Projectors"
                                                              delegate:self
                                                     cancelButtonTitle:@"Cancel"
                                                destructiveButtonTitle:nil
                                                     otherButtonTitles:@"On", @"Off", nil];
    [self.powerStatusActionSheet showFromBarButtonItem:sender animated:YES];
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
