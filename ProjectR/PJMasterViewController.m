//
//  PJMasterViewController.m
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJMasterViewController.h"
#import "PJProjectorManager.h"
#import "PJProjector.h"
#import "PJAMXBeaconHost.h"
#import "PJAMXBeaconListener.h"
#import "PJLinkSubnetScanner.h"
#import "PJLinkAddProjectorDelegate.h"
#import "PJProjectorDetailTableViewController.h"

@interface PJMasterViewController() <UIActionSheetDelegate, PJLinkAddProjectorDelegate>

@end

@implementation PJMasterViewController

- (void)dealloc {
    [self unsubscribeToNotifications];
}

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    }
    [self subscribeToNotifications];
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.projectorDetailTableViewController = (PJProjectorDetailTableViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        // Get the projector for this cell
        PJProjectorManager* mgr = [PJProjectorManager sharedManager];
        PJProjector* projector = [mgr objectInProjectorsAtIndex:indexPath.row];
        [[segue destinationViewController] setProjector:projector];
    }
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Managed Projectors";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    return [mgr countOfProjectors];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* cellIdentifier = @"ProjectorMasterCell";
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    // Get the projector for this cell
    PJProjectorManager* mgr = [PJProjectorManager sharedManager];
    PJProjector* projector = [mgr objectInProjectorsAtIndex:indexPath.row];

    // Construct the cell title
    NSString* title = [NSString stringWithFormat:@"%@ (%@)", projector.projectorName, projector.host];
    // Put the IP address in the textLabel
    cell.textLabel.text = title;
    // Get a string representation of the power status
    NSString* powerStatusStr = nil;
    switch (projector.powerStatus) {
        case PJPowerStatusCooling:
            powerStatusStr = @"Cooling Down";
            break;
        case PJPowerStatusLampOn:
            powerStatusStr = @"Lamp On";
            break;
        case PJPowerStatusStandby:
            powerStatusStr = @"Standby";
            break;
        case PJPowerStatusWarmUp:
            powerStatusStr = @"Warming Up";
            break;
        default:
            break;
    }
    // Construct the subtitle
    NSString* subtitle = [NSString stringWithFormat:@"%@,%@", powerStatusStr, projector.activeInputName];
    cell.detailTextLabel.text = subtitle;

    return cell;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        // Get the projector for this cell
        PJProjectorManager* mgr = [PJProjectorManager sharedManager];
        PJProjector* projector = [mgr objectInProjectorsAtIndex:indexPath.row];
        self.projectorDetailTableViewController.projector = projector;
    }
}

#pragma mark - UIActionSheetDelegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != actionSheet.cancelButtonIndex) {
        if (buttonIndex == actionSheet.firstOtherButtonIndex) {
            // Scan for projectors
            [self performSegueWithIdentifier:@"scanSegue" sender:self];
        } else {
            // Add a projector manually
            [self performSegueWithIdentifier:@"manualAddSegue" sender:self];
        }
    }
}

#pragma mark - PJLinkAddProjectorDelegate methods

- (void)pjlinkProjectorsWereAdded:(NSArray*)projectors {
    // Add these projectors to the PJProjectorManager
    [[PJProjectorManager sharedManager] addProjectors:projectors];
}

#pragma mark - PJMasterViewController private methods

-(void)subscribeToNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(projectorsDidChange:)
                                                 name:PJProjectorManagerProjectorsDidChangeNotification
                                               object:[PJProjectorManager sharedManager]];
}

- (void)unsubscribeToNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PJProjectorManagerProjectorsDidChangeNotification
                                                  object:[PJProjectorManager sharedManager]];
}

- (void)projectorsDidChange:(NSNotification*)notification {
    [self.tableView reloadData];
}

- (IBAction)refreshButtonTapped:(id)sender {
}

- (IBAction)addButtonTapped:(id)sender {
    UIActionSheet* actionSheet = [[UIActionSheet alloc] initWithTitle:@"Add Projectors"
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:@"Scan For Projectors", @"Add Manually", nil];
    [actionSheet showFromBarButtonItem:sender animated:YES];
}

@end
