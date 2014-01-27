//
//  PJSubnetScannerViewController.m
//  ProjectR
//
//  Created by Eric Hyche on 1/20/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJSubnetScannerViewController.h"
#import "PJLinkSubnetScanner.h"
#import "PJProjector.h"
#import "PJProjectorManager.h"
#import "PJInterfaceInfo.h"

@interface PJSubnetScannerViewController ()

@property(nonatomic,strong) PJLinkSubnetScanner* scanner;
@property(nonatomic,strong) UIBarButtonItem*     startBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*     cancelBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*     addBarButtonItem;
@property(nonatomic,strong) UIProgressView*      progressView;
@property(nonatomic,copy)   NSString*            deviceHost;
@property(nonatomic,copy)   NSString*            deviceNetMask;

@end

@implementation PJSubnetScannerViewController

- (void)dealloc {
    [self unsubscribeFromNotifications];
}

- (id)init {
    return [self initWithStyle:UITableViewStyleGrouped];
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Get the WiFi host and netmask
        PJInterfaceInfo* interfaceInfo = [[PJInterfaceInfo alloc] init];
        self.deviceHost    = interfaceInfo.host;
        self.deviceNetMask = interfaceInfo.netmask;
        // Create the subnet scanner
        _scanner = [[PJLinkSubnetScanner alloc] init];
        // Subscribe to notifications
        [self subscribeToNotifications];
        // Create the bar button items
        _startBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Start"
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(startScanButtonTapped:)];
        _cancelBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                             target:self
                                                                             action:@selector(cancelScanButtonTapped:)];
        _addBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                          target:self
                                                                          action:@selector(addProjectorsButtonTapped:)];
        // Create the progress view
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        _progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_progressView sizeToFit];
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Update the right bar button item
    [self updateRightBarButtonItem];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger ret = 2;

    return ret;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger ret = 0;

    if (section == 0) {
        ret = 2;
        if (self.scanner.isScanning) {
            ret += 1;
        }
    } else if (section == 1) {
        ret = [self.scanner countOfProjectorHosts];
    }

    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* CellIdentifierDefault = @"DefaultCellReuseID";
    static NSString* CellIdentifierValue1  = @"Value1CellReuseID";

    NSString*            cellReuseID = CellIdentifierDefault;
    UITableViewCellStyle cellStyle   = UITableViewCellStyleDefault;
    if (indexPath.section == 0) {
        cellReuseID = CellIdentifierValue1;
        cellStyle   = UITableViewCellStyleValue1;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellReuseID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:cellStyle reuseIdentifier:cellReuseID];
    }

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Device IP";
            cell.detailTextLabel.text = self.deviceHost;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Device Netmask";
            cell.detailTextLabel.text = self.deviceNetMask;
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Currently Scanning";
            cell.detailTextLabel.text = self.scanner.scannedHost;
        }
    } else if (indexPath.section == 1) {
        NSString* projectorHost = [self.scanner objectInProjectorHostsAtIndex:indexPath.row];
        cell.textLabel.text = projectorHost;
    }

    return cell;
}

#pragma mark - UITableViewDelegate methods

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* ret = nil;

    if (section == 0) {
        ret = @"Device Subnet Info";
    } else if (section == 1 && [self.scanner countOfProjectorHosts] > 0) {
        ret = @"Discovered Projectors";
    }

    return ret;
}

- (NSString*)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString* ret = nil;

    if (section == 0) {
        // If we are not scanning, then show some instructions in the footer
        if (!self.scanner.isScanning && [self.scanner countOfProjectorHosts] == 0) {
            ret = @"Tap Start to begin scanning";
        }
    }

    return ret;
}

#pragma mark - PJSubnetScannerViewCotroller private methods

- (void)subscribeToNotifications {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(scanningDidBegin:)
                               name:PJLinkSubnetScannerScanningDidBeginNotification
                             object:self.scanner];
    [notificationCenter addObserver:self
                           selector:@selector(scanningDidEnd:)
                               name:PJLinkSubnetScannerScanningDidEndNotification
                             object:self.scanner];
    [notificationCenter addObserver:self
                           selector:@selector(scanningDidProgress:)
                               name:PJLinkSubnetScannerScanningDidProgressNotification
                             object:self.scanner];
    [notificationCenter addObserver:self
                           selector:@selector(scannedHostDidChange:)
                               name:PJLinkSubnetScannerScannedHostDidChangeNotification
                             object:self.scanner];
    [notificationCenter addObserver:self
                           selector:@selector(scannerProjectorHostsDidChange:)
                               name:PJLinkSubnetScannerDiscoveredProjectorHostsDidChangeNotification
                             object:self.scanner];
}

- (void)unsubscribeFromNotifications {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self
                                  name:PJLinkSubnetScannerScanningDidBeginNotification
                                object:self.scanner];
    [notificationCenter removeObserver:self
                                  name:PJLinkSubnetScannerScanningDidEndNotification
                                object:self.scanner];
    [notificationCenter removeObserver:self
                                  name:PJLinkSubnetScannerScanningDidProgressNotification
                                object:self.scanner];
    [notificationCenter removeObserver:self
                                  name:PJLinkSubnetScannerScannedHostDidChangeNotification
                                object:self.scanner];
    [notificationCenter removeObserver:self
                                  name:PJLinkSubnetScannerDiscoveredProjectorHostsDidChangeNotification
                                object:self.scanner];
}

- (void)scanningDidBegin:(NSNotification*)notification {
    // Show the progress bar
    [self showHideProgressView:YES];
    // Update the right bar button item
    [self updateRightBarButtonItem];
    // Reload the table view
    [self.tableView reloadData];
}

- (void)scanningDidEnd:(NSNotification*)notification {
    // Hide the progress bar
    [self showHideProgressView:NO];
    // Update the right bar button item
    [self updateRightBarButtonItem];
    // Reload the table view
    [self.tableView reloadData];
}

- (void)scanningDidProgress:(NSNotification*)notification {
    // Get the user info
    NSDictionary* userInfo = [notification userInfo];
    // Get the progress value
    CGFloat progress = [[userInfo objectForKey:PJLinkSubnetScannerProgressKey] floatValue];
    // Update the progress bar
    self.progressView.progress = progress;
}

- (void)scannedHostDidChange:(NSNotification*)notification {
    // Reload the first section
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)scannerProjectorHostsDidChange:(NSNotification*)notification {
    // Reload the second section
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)updateRightBarButtonItem {
    // Are we scanning or not?
    if (self.scanner.isScanning) {
        // If we are scanning, then the right bar button says Cancel
        self.navigationItem.rightBarButtonItem = self.cancelBarButtonItem;
    } else {
        // If we are not scanning and we have some discovered projectors,
        // then our right bar button item says "Add". Otherwise, it says "Start".
        if ([self.scanner countOfProjectorHosts] > 0) {
            self.navigationItem.rightBarButtonItem = self.addBarButtonItem;
        } else {
            self.navigationItem.rightBarButtonItem = self.startBarButtonItem;
        }
    }
}

- (void)startScanButtonTapped:(id)sender {
    // Start scanning
    [self.scanner start];
}

- (void)cancelScanButtonTapped:(id)sender {
    // Stop scanning
    [self.scanner stop];
}

- (void)addProjectorsButtonTapped:(id)sender {
    // Create projectors for the discovered projectors
    NSUInteger projectorHostsCount = [self.scanner countOfProjectorHosts];
    NSMutableArray* tmpProjectors = [NSMutableArray arrayWithCapacity:projectorHostsCount];
    for (NSUInteger i = 0; i < projectorHostsCount; i++) {
        // Get the i-th projector host
        NSString* projectorHost = [self.scanner objectInProjectorHostsAtIndex:i];
        // Create a PJProjector
        PJProjector* ithProjector = [[PJProjector alloc] initWithHost:projectorHost];
        // Add the projector
        [tmpProjectors addObject:ithProjector];
    }
    // Add projectors to the projector manager
    BOOL added = [[PJProjectorManager sharedManager] addProjectorsToManager:tmpProjectors];
    // Was the projector added successfully?
    NSString* title   = nil;
    NSString* message = nil;
    if (added) {
        // The projector was added successfully.
        title   = @"Projector Added";
        message = @"Projector was added successfully.";
    } else {
        // The only reason it would not be added is if it was already present.
        // So in this case show an alert to the user saying the projector
        // was already present.
        title   = @"Projector Not Added";
        message = @"This projector has already been added";
    }
    // Show an alert view with the result
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)showHideProgressView:(BOOL)show {
    if (show) {
        self.tableView.tableHeaderView = self.progressView;
    } else {
        self.tableView.tableHeaderView = nil;
    }
}

@end
