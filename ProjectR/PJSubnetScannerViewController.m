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
#import "UIImage+SolidColor.h"
#import "PJSubnetScannerProgressView.h"

CGFloat const kPJSubnetScannerButtonHeight = 64.0;

@interface PJSubnetScannerViewController ()

@property(nonatomic,strong) PJLinkSubnetScanner*         scanner;
@property(nonatomic,strong) UIButton*                    button;
@property(nonatomic,strong) PJSubnetScannerProgressView* progressView;

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
        // Create the subnet scanner
        _scanner = [[PJLinkSubnetScanner alloc] init];
        _scanner.shouldIncludeDeviceAddress = YES;
        // Subscribe to notifications
        [self subscribeToNotifications];
        // Create the bar button items
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                              target:self
                                                                                              action:@selector(doneButtonTapped:)];
        // Give a title to this view controller
        self.navigationItem.title = @"Scan WiFi Network";
        // Create the add button
        self.button = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        CGSize imageSize = CGSizeMake(8.0, 8.0);
        [self.button setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0] size:imageSize]
                               forState:UIControlStateNormal];
        [self.button setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithRed:0.0 green:0.6 blue:0.0 alpha:1.0] size:imageSize]
                               forState:UIControlStateHighlighted];
        [self.button setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:1.0] size:imageSize]
                               forState:UIControlStateSelected];
        [self.button setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithRed:0.7 green:0.0 blue:0.0 alpha:1.0] size:imageSize]
                               forState:UIControlStateSelected | UIControlStateHighlighted];
        [self.button setTitle:@"Start Scanning" forState:UIControlStateNormal];
        [self.button setTitle:@"Start Scanning" forState:UIControlStateHighlighted];
        [self.button setTitle:@"Cancel Scanning" forState:UIControlStateSelected];
        [self.button setTitle:@"Cancel Scanning" forState:UIControlStateSelected | UIControlStateHighlighted];
        [self.button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        // Create the progress view
        self.progressView = [[PJSubnetScannerProgressView alloc] init];
        [self.progressView sizeToFit];
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.button.frame = CGRectMake(0.0, 0.0, self.view.frame.size.width, kPJSubnetScannerButtonHeight);
    self.tableView.tableFooterView = self.button;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self updateFooterButtonState];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger ret = [self.scanner countOfProjectorHosts];

    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* CellIdentifierDefault = @"DefaultCellReuseID";

    NSString*            cellReuseID = CellIdentifierDefault;
    UITableViewCellStyle cellStyle   = UITableViewCellStyleDefault;

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellReuseID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:cellStyle reuseIdentifier:cellReuseID];
    }

    NSString* projectorHost = [self.scanner objectInProjectorHostsAtIndex:indexPath.row];
    cell.textLabel.text = projectorHost;

    return cell;
}

#pragma mark - UITableViewDelegate methods

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* ret = nil;

    if ([self.scanner countOfProjectorHosts] > 0) {
        ret = @"Discovered Projectors";
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
    [self updateFooterButtonState];
//    // Reload the table view
//    [self.tableView reloadData];
}

- (void)scanningDidEnd:(NSNotification*)notification {
    // Hide the progress bar
    [self showHideProgressView:NO];
    [self updateFooterButtonState];
//    // Reload the table view
//    [self.tableView reloadData];
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
    NSString* progressText = [NSString stringWithFormat:@"Scanning %@ (%.0f%%)", self.scanner.scannedHost, self.progressView.progress * 100.0];
    self.progressView.progressText = progressText;
}

- (void)scannerProjectorHostsDidChange:(NSNotification*)notification {
    [self.tableView reloadData];
}

- (void)doneButtonTapped:(id)sender {
    // Stop scanning
    [self.scanner stop];
    // Dismiss ourself
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)buttonTapped:(id)sender {
    if (self.scanner.isScanning) {
        // Stop scanning
        [self.scanner stop];
    } else {
        if ([self.scanner countOfProjectorHosts] > 0) {
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
            [[PJProjectorManager sharedManager] addProjectorsToManager:tmpProjectors];
            // Now dismiss ourself
            [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        } else {
            // Start scanning
            [self.scanner start];
        }
    }
}

- (void)showHideProgressView:(BOOL)show {
    if (show) {
        CGSize progressViewSizeThatFits = [self.progressView sizeThatFits:self.tableView.frame.size];
        CGRect progressViewFrame = CGRectMake(0.0, 0.0, self.tableView.frame.size.width, progressViewSizeThatFits.height);
        self.progressView.frame = progressViewFrame;
        self.tableView.tableHeaderView = self.progressView;
    } else {
        self.tableView.tableHeaderView = nil;
    }
}

- (void)updateFooterButtonState {
    if (self.scanner.isScanning) {
        self.button.selected = YES;
    } else {
        NSString* title = ([self.scanner countOfProjectorHosts] > 0 ? @"Add Projectors" : @"Start Scanning");
        self.button.selected = NO;
        [self.button setTitle:title forState:UIControlStateNormal];
        [self.button setTitle:title forState:UIControlStateHighlighted];
    }
}

@end
