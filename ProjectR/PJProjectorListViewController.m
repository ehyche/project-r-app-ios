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

@interface PJProjectorListViewController ()

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

    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateEditButtonVisibilityAnimated:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger ret = 0;

    if (section == 0) {
        PJProjectorManager* mgr = [PJProjectorManager sharedManager];
        ret = [mgr countOfProjectors];
    } else if (section == 1) {
        ret = 3;
    }

    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* cellReuseIDDefault   = @"PJProjectorListCellIDDefault";
    static NSString* cellReuseIDProjector = @"PJProjectorListCellIDProjector";

    // Determine which cell reuse ID to use
    NSString*            cellReuseID = nil;
    UITableViewCellStyle cellStyle   = UITableViewCellStyleDefault;
    if (indexPath.section == 0) {
        cellReuseID = cellReuseIDProjector;
        cellStyle   = UITableViewCellStyleSubtitle;
    } else if (indexPath.section == 1) {
        cellReuseID = cellReuseIDDefault;
        cellStyle   = UITableViewCellStyleDefault;
    }

    // Re-use or create the cell
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellReuseID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:cellStyle reuseIdentifier:cellReuseID];
    }

    // Configure the cell defaults
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    // Configure the cell
    if (indexPath.section == 0) {
        // Get the projector for this row
        PJProjectorManager* mgr = [PJProjectorManager sharedManager];
        PJProjector* projector = (PJProjector*) [mgr objectInProjectorsAtIndex:indexPath.row];
        // The title label is the display name of the projector
        cell.textLabel.text = [PJProjectorManager displayNameForProjector:projector];
        // Construct the detail text
        NSString* activeInputName = @"";
        if (projector.activeInputIndex < [projector countOfInputs]) {
            PJInputInfo* inputInfo = (PJInputInfo*) [projector objectInInputsAtIndex:projector.activeInputIndex];
            activeInputName = [inputInfo description];
        }
        NSString* powerStatusName = [PJResponseInfoPowerStatusQuery stringForPowerStatus:projector.powerStatus];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@,%@", powerStatusName, activeInputName];
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Add Manually";
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Scan WiFi Network";
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Listen for AMX Beacons";
        }
    }

    return cell;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* ret = nil;

    if (section == 0) {
        ret = @"Projectors";
    } else if (section == 1) {
        ret = @"Add Projectors";
    }

    return ret;
}

- (NSString*)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString* ret = nil;

    if (section == 0) {
        // If we don't have any projectors, then use a footer. Otherwise, do not.
        PJProjectorManager* mgr = [PJProjectorManager sharedManager];
        if ([mgr countOfProjectors] == 0) {
            ret = @"None";
        }
    }

    return ret;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 0 ? YES : NO);
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        PJProjectorManager* mgr = [PJProjectorManager sharedManager];
        // Get the projector for this row
        PJProjector* projector = [mgr objectInProjectorsAtIndex:indexPath.row];
        // Delete this projector
        [mgr removeProjectorsFromManager:@[projector]];
    }
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
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
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            // Manually add a projector
            //
            // Create a view controller to manually add a projector
            PJManualAddTableViewController* controller = [[PJManualAddTableViewController alloc] init];
            // Push this onto the navigation stack
            [self.navigationController pushViewController:controller animated:YES];
        } else if (indexPath.row == 1) {
            // Create a subnet scanner controller
            PJSubnetScannerViewController* controller = [[PJSubnetScannerViewController alloc] init];
            // Push this controller onto the navigation stack
            [self.navigationController pushViewController:controller animated:YES];
        } else if (indexPath.row == 2) {
            // Scan using AMX beacons
        }
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCellEditingStyle ret = UITableViewCellEditingStyleNone;

    if (indexPath.section == 0) {
        ret = UITableViewCellEditingStyleDelete;
    }

    return ret;
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
    [self.tableView reloadData];
    [self checkToDismissEditingMode];
    [self updateEditButtonVisibilityAnimated:NO];
}

- (void)projectorsWereInserted:(NSIndexSet*)indexSet {
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
    [self updateEditButtonVisibilityAnimated:NO];
}

- (void)projectorsWereRemoved:(NSIndexSet*)indexSet {
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    if ([mgr countOfProjectors] == 0) {
        // If the last projectors were removed, then we need
        // reload the whole section so that we will show the footer
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
    } else {
        [self.tableView deleteRowsAtIndexPaths:[indexSet indexPathsForSection:0] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    [self checkToDismissEditingMode];
    [self updateEditButtonVisibilityAnimated:NO];

}

- (void)projectorsWereUpdated:(NSIndexSet*)indexSet {
    [self.tableView reloadRowsAtIndexPaths:[indexSet indexPathsForSection:0] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)commonInit {
    [self subscribeToKVONotifications];
    self.navigationItem.title = @"ProjectR";
}

- (void)updateEditButtonVisibilityAnimated:(BOOL)animated {
    // If we have at least one projector, then we need an Edit button.
    // Otherwise, we don't.
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    BOOL showEditButton = ([mgr countOfProjectors] > 0);
    [self showHideEditButton:showEditButton animated:animated];
}

- (void)showHideEditButton:(BOOL)show animated:(BOOL)animated {
    if (show) {
        [self.navigationItem setRightBarButtonItem:self.editButtonItem animated:animated];
    } else {
        [self.navigationItem setRightBarButtonItem:nil animated:animated];
    }
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

@end
