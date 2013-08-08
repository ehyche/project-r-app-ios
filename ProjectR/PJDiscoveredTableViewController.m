//
//  PJDiscoveredTableViewController.m
//  ProjectR
//
//  Created by Eric Hyche on 8/3/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJDiscoveredTableViewController.h"
#import "PJAMXBeaconHost.h"
#import "PJAMXBeaconListener.h"
#import "PJLinkSubnetScanner.h"
#import "PJProjector.h"
#import "PJLinkAddProjectorDelegate.h"

@interface PJDiscoveredTableViewController ()

@property(strong, nonatomic) IBOutlet UIView *loadingView;
@property(weak, nonatomic) IBOutlet UIProgressView *progressView;
@property(strong,nonatomic) NSMutableArray* discoveredProjectors;
@property(strong,nonatomic) NSMutableDictionary* ipAddressToProjector;
@property(strong,nonatomic) NSMutableSet* selectedIPAddresses;

@end

@implementation PJDiscoveredTableViewController

- (void)dealloc {
    [self unsubscribeToNotifications];
}

- (void)awakeFromNib {
    _discoveredProjectors = [NSMutableArray array];
    _ipAddressToProjector = [NSMutableDictionary dictionary];
    _selectedIPAddresses = [NSMutableSet set];
    [self subscribeToNotifications];

}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.progressView.progress = 0.0;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.discoveredProjectors count];
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* ret = nil;

    if ([self.discoveredProjectors count] > 0) {
        ret = @"Discovered Projectors";
    } else {
        ret = @"No Discovered Projectors. Tap Scan to begin discovery.";
    }

    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"discoveredCellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    // Set the selection style
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    PJProjector* projector = [self.discoveredProjectors objectAtIndex:indexPath.row];
    cell.textLabel.text = projector.host;
    NSString* detailText = projector.projectorName;
    if (detailText == nil && projector.beaconHost != nil) {
        detailText = [NSString stringWithFormat:@"%@ %@", projector.beaconHost.make, projector.beaconHost.model];
    }
    // If the ip address selected, then put a checkmark
    BOOL isSelected = [self.selectedIPAddresses containsObject:projector.host];
    cell.accessoryType = (isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone);

    return cell;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Get the projector for this row
    PJProjector* projector = [self.discoveredProjectors objectAtIndex:indexPath.row];
    // Is the projector currently selected?
    BOOL isSelected = [self.selectedIPAddresses containsObject:projector.host];
    // Now toggle the selection state
    if (isSelected) {
        [self.selectedIPAddresses removeObject:projector.host];
    } else {
        [self.selectedIPAddresses addObject:projector.host];
    }
    // Re-load this cell
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - PJDiscoveredTableViewController private methods

- (IBAction)scanButtonTapped:(id)sender {
    self.loadingView.frame = self.navigationController.view.bounds;
    self.loadingView.alpha = 0.0;
    [self.navigationController.view addSubview:self.loadingView];
    [UIView animateWithDuration:0.5 animations:^{
        self.loadingView.alpha = 1.0;
    }];
    // Start listening for AMX beacons
    PJAMXBeaconListener* listener = [PJAMXBeaconListener sharedListener];
    NSError* listenError = nil;
    BOOL listenRet = [listener startListening:&listenError];
    if (!listenRet) {
        NSLog(@"PJXMXBeaconListener startListening returned error = %@", listenError);
    }
    // Send out an AMX ping. All AMX beacons should respond
    [listener ping];

    // Scan the subnet for projectors
    PJLinkSubnetScanner* scanner = [PJLinkSubnetScanner sharedScanner];
    [scanner start];
}

- (IBAction)doneButtonTapped:(id)sender {
    // Get the array of selected projectors
    NSMutableArray* selectedProjectors = [NSMutableArray arrayWithCapacity:[self.discoveredProjectors count]];
    for (PJProjector* discoveredProjector in self.discoveredProjectors) {
        if ([self.selectedIPAddresses containsObject:discoveredProjector.host]) {
            [selectedProjectors addObject:discoveredProjector];
        }
    }
    if ([selectedProjectors count] > 0) {
        // Call back to the delegate with the selected projectors
        [self.delegate pjlinkProjectorsWereAdded:selectedProjectors];
    }
    [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)cancelButtonTapped:(id)sender {
    [self finishScanning];
}

- (void)subscribeToNotifications {
    PJLinkSubnetScanner* scanner = [PJLinkSubnetScanner sharedScanner];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subnetScanningDidBegin:)
                                                 name:PJLinkSubnetScannerScanningDidBeginNotification
                                               object:scanner];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subnetScanningDidEnd:)
                                                 name:PJLinkSubnetScannerScanningDidEndNotification
                                               object:scanner];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subnetScanningDidProgress:)
                                                 name:PJLinkSubnetScannerScanningDidProgressNotification
                                               object:scanner];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subnetScanningProjectorHostsDidChange:)
                                                 name:PJLinkSubnetScannerDiscoveredProjectorHostsDidChangeNotification
                                               object:scanner];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(amxBeaconHostsDidChange:)
                                                 name:PJAMXBeaconHostsDidChangeNotification
                                               object:[PJAMXBeaconListener sharedListener]];
}

- (void)unsubscribeToNotifications {
    PJLinkSubnetScanner* scanner = [PJLinkSubnetScanner sharedScanner];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PJLinkSubnetScannerScanningDidBeginNotification
                                                  object:scanner];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PJLinkSubnetScannerScanningDidEndNotification
                                                  object:scanner];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PJLinkSubnetScannerScanningDidProgressNotification
                                                  object:scanner];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PJLinkSubnetScannerDiscoveredProjectorHostsDidChangeNotification
                                                  object:scanner];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PJAMXBeaconHostsDidChangeNotification
                                                  object:[PJAMXBeaconListener sharedListener]];
}

- (void)subnetScanningDidBegin:(NSNotification*)notification {
    NSLog(@"subnetScanningDidBegin:%@", notification);

}

- (void)subnetScanningDidEnd:(NSNotification*)notification {
    NSLog(@"subnetScanningDidEnd:%@", notification);
    [self finishScanning];
}

- (void)subnetScanningDidProgress:(NSNotification*)notification {
    NSLog(@"subnetScanningDidProgress:%@", notification);
    // Get the user info dictionary
    NSDictionary* userInfo = [notification userInfo];
    // Get the progress value
    NSNumber* progressNum = [userInfo objectForKey:PJLinkSubnetScannerProgressKey];
    // Get the progress as a float
    CGFloat progress = [progressNum floatValue];
    // Update the progress bar
    self.progressView.progress = progress;
}

- (void)subnetScanningProjectorHostsDidChange:(NSNotification*)notification {
    NSLog(@"subnetScanningProjectorHostsDidChange:%@", notification);
    // Loop through the IP addresses that we found a projector at
    BOOL projectorAdded = NO;
    NSArray* projectorHosts = [[PJLinkSubnetScanner sharedScanner] projectorHosts];
    for (NSString* projectorHost in projectorHosts) {
        // Do we already have a projector with this IP address?
        PJProjector* projector = [self.ipAddressToProjector objectForKey:projectorHost];
        if (projector == nil) {
            // This is a new projector, so create a PJProjector for it
            projector = [[PJProjector alloc] initWithHost:projectorHost];
            // Add this projector
            [self addProjector:projector atHost:projectorHost];
            // Set the flag saying we added a projector
            projectorAdded = YES;
        }
    }
    if (projectorAdded) {
        [self projectorsDidChange];
    }
}

- (void)amxBeaconHostsDidChange:(NSNotification*)notification {
    NSLog(@"amxBeaconHostsDidChange:%@", notification);
    // Loop through the AMX Beacon Hosts
    BOOL projectorAdded = NO;
    NSArray* beaconHosts = [[PJAMXBeaconListener sharedListener] hosts];
    for (PJAMXBeaconHost* beaconHost in beaconHosts) {
        // Do we already have a PJProjector with this IP address?
        PJProjector* projector = [self.ipAddressToProjector objectForKey:beaconHost.ipAddressFromSocket];
        if (projector == nil) {
            // This is a new projector, so create a PJProjector for it
            projector = [[PJProjector alloc] initWithBeaconHost:beaconHost];
            // Add this projector
            [self addProjector:projector atHost:beaconHost.ipAddressFromSocket];
            // Set the flag saying we added a projector
            projectorAdded = YES;
        }
    }
    if (projectorAdded) {
        [self projectorsDidChange];
    }
}

- (void)finishScanning {
    [UIView animateWithDuration:0.5
                     animations:^{
                         self.loadingView.alpha = 0.0;
                     }
                     completion:^(BOOL finished) {
                         [self.loadingView removeFromSuperview];
                     }];
    // Stop listening for AMX beacons
    [[PJAMXBeaconListener sharedListener] stopListening];

    // Stop scanning
    [[PJLinkSubnetScanner sharedScanner] stop];
}

- (void)addProjector:(PJProjector*)projector atHost:(NSString*)host {
    // Add this projector to the mutable array
    [self.discoveredProjectors addObject:projector];
    // Enter this projector into the IP Address map
    [self.ipAddressToProjector setObject:projector forKey:host];
    // Initially we select the projector
    [self.selectedIPAddresses addObject:host];
}

- (void)projectorsDidChange {
    // Sort the array by IP address
    [self.discoveredProjectors sortUsingComparator:^(id obj1, id obj2) {
        PJProjector* proj1 = (PJProjector*)obj1;
        PJProjector* proj2 = (PJProjector*)obj2;
        NSString* ipAddress1 = proj1.host;
        NSString* ipAddress2 = proj2.host;
        return [ipAddress1 compare:ipAddress2];
    }];
    // Tell the table view to reload
    [self.tableView reloadData];
}

@end
