//
//  PJMasterViewController.m
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJMasterViewController.h"
#import "PJDetailViewController.h"
#import "PJProjectorManager.h"
#import "PJProjector.h"
#import "PJAMXBeaconHost.h"
#import "PJAMXBeaconListener.h"
#import "PJLinkSubnetScanner.h"

@interface PJMasterViewController() <UIActionSheetDelegate>

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

    self.detailViewController = (PJDetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        //        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        //        NSDate *object = _objects[indexPath.row];
        //        [[segue destinationViewController] setDetailItem:object];
    }
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
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

    // Put the IP address in the textLabel
    cell.textLabel.text = projector.host;
    // Put the projector name or make/model in the detail text
    NSString* subTitle = projector.projectorName;
    if ([subTitle length] == 0) {
        if ([projector.beaconHost.make length] > 0 && [projector.beaconHost.model length] > 0) {
            subTitle = [NSString stringWithFormat:@"%@ %@", projector.beaconHost.make, projector.beaconHost.model];
        }
    }
    cell.detailTextLabel.text = subTitle;

    return cell;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        NSDate *object = _objects[indexPath.row];
//        self.detailViewController.detailItem = object;
//    }
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
