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

@property(nonatomic,strong) UIButton      *addButton;
@property(nonatomic,strong) UIActionSheet *addActionSheet;
@property(nonatomic,strong) UIActionSheet *inputActionSheet;

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

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addButtonAction:)];
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
    UITableViewCellEditingStyle ret = UITableViewCellEditingStyleDelete;

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
    } else if (actionSheet == self.inputActionSheet) {
        PJProjectorManager *mgr = [PJProjectorManager sharedManager];
        NSUInteger projectorsCount = [mgr countOfProjectors];
        // Look up the projector
        NSUInteger projectorIndex = actionSheet.tag;
        if (projectorIndex < projectorsCount) {
            PJProjector* projector = [mgr objectInProjectorsAtIndex:projectorIndex];
            // Find out which input this button refers to
            NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
            NSUInteger inputsCount = [projector countOfInputs];
            NSUInteger selectedInputIndex = inputsCount;
            for (NSUInteger i = 0; i < inputsCount; i++) {
                PJInputInfo *ithInputInfo = [projector objectInInputsAtIndex:i];
                NSString *ithInputName = [ithInputInfo description];
                if ([buttonTitle isEqualToString:ithInputName]) {
                    selectedInputIndex = i;
                    break;
                }
            }
            if (selectedInputIndex < inputsCount) {
                // We found the selected input. Is this different than the active input index
                if (selectedInputIndex != projector.activeInputIndex) {
                    [projector requestInputChangeToInputIndex:selectedInputIndex];
                }
            }
        }
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
    [self.tableView reloadData];
    [self checkToDismissEditingMode];
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
    [self checkToDismissEditingMode];
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
    [self checkToDismissEditingMode];

}

- (void)projectorsWereUpdated:(NSIndexSet*)indexSet {
    NSLog(@"XXXMEH projectorsWereUpdated:%@", indexSet);
    [self.tableView reloadRowsAtIndexPaths:[indexSet indexPathsForSection:0] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)commonInit {
    [self subscribeToKVONotifications];
    self.navigationItem.title = @"ProjectR";
}

- (void)checkToDismissEditingMode {
    if (self.editing) {
        // We are in editing mode. If we don't have any more projectors
        // (which could happen if we just deleted our last one), then
        // come out of editing mode.
        PJProjectorManager* mgr = [PJProjectorManager sharedManager];
        if ([mgr countOfProjectors] == 0) {
            self.editing = NO;
        }
    }
}

- (void)addButtonAction:(id)sender {
    self.addActionSheet = [[UIActionSheet alloc] initWithTitle:@"Add A Projector"
                                                      delegate:self
                                             cancelButtonTitle:@"Cancel"
                                        destructiveButtonTitle:nil
                                             otherButtonTitles:@"Add Manually", @"Scan WiFi Network", @"Listen for AMX Beacons", nil];
    [self.addActionSheet showFromBarButtonItem:sender animated:YES];
}

@end
