//
//  PJBeaconListenerViewController.m
//  ProjectR
//
//  Created by Eric Hyche on 1/26/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJBeaconListenerViewController.h"
#import "PJAMXBeaconListener.h"
#import "AFPJLinkClient.h"
#import "PJURLProtocolRunLoop.h"
#import "PJAMXBeaconHost.h"
#import "PJDefinitions.h"
#import "PJProjector.h"
#import "PJProjectorManager.h"
#import "PJInterfaceInfo.h"

typedef NS_ENUM(NSInteger, PJProjectorDetectionStatus) {
    PJProjectorDetectionStatusUnknown,
    PJProjectorDetectionStatusDetectionInProgress,
    PJProjectorDetectionStatusPJLinkNotSupported,
    PJProjectorDetectionStatusPJLinkSupported,
    PJProjectorDetectionStatusCount
};

// Time interval constants
NSTimeInterval const kPJBeaconListenerViewControllerScanDuration            = 60.0;
NSTimeInterval const kPJBeaconListenerViewControllerProgressInterval        =  0.5;
NSTimeInterval const kPJBeaconListenerViewControllerPingInterval            = 10.0;
NSTimeInterval const kPJBeaconListenerViewControllerProjectorTimeoutInterval = 2.0;
// Layout constants
CGFloat const kPJBeaconListenerViewControllerLabelInsetTop           = 10.0;
CGFloat const kPJBeaconListenerViewControllerLabelInsetLeft          = 20.0;
CGFloat const kPJBeaconListenerViewControllerLabelInsetBottom        =  5.0;
CGFloat const kPJBeaconListenerViewControllerLabelInsetRight         = 20.0;
CGFloat const kPJBeaconListenerViewControllerProgressViewInsetTop    =  5.0;
CGFloat const kPJBeaconListenerViewControllerProgressViewInsetLeft   = 20.0;
CGFloat const kPJBeaconListenerViewControllerProgressViewInsetBottom = 10.0;
CGFloat const kPJBeaconListenerViewConrtollerProgressViewInsetRight  = 20.0;

@interface PJBeaconListenerViewController ()

@property(nonatomic,strong) UIView*              headerView;
@property(nonatomic,strong) UILabel*             headerLabel;
@property(nonatomic,strong) UIProgressView*      headerProgressView;
@property(nonatomic,strong) PJAMXBeaconListener* amxBeaconListener;
@property(nonatomic,strong) UIBarButtonItem*     scanBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*     cancelBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*     addBarButtonItem;
@property(nonatomic,strong) NSTimer*             progressTimer;
@property(nonatomic,strong) NSTimer*             pingTimer;
@property(nonatomic,strong) NSString*            preScanHeaderText;
@property(nonatomic,strong) NSString*            addDiscoveredHeaderText;
@property(nonatomic,strong) NSDate*              listenStartDate;
@property(nonatomic,strong) NSMutableDictionary* hostStatus;
@property(nonatomic,strong) NSMutableArray*      projectorHosts;

@end

@implementation PJBeaconListenerViewController

- (void)dealloc {
    [self.amxBeaconListener stopListening];
    [self unsubscribeFromNotifications];
}

- (id)init {
    return [self initWithStyle:UITableViewStyleGrouped];
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Create a beacon listener object
        _amxBeaconListener = [[PJAMXBeaconListener alloc] init];
        // Subscribe to notifications from the beacon listener
        [self subscribeToNotifications];
        // Create the bar button items
        _scanBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Scan"
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(scanButtonTapped:)];
        _cancelBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                             target:self
                                                                             action:@selector(cancelButtonTapped:)];
        _addBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                          target:self
                                                                          action:@selector(addButtonTapped:)];
        // Create the header label
        _headerLabel = [[UILabel alloc] init];
        _headerLabel.textAlignment = NSTextAlignmentCenter;
        _headerLabel.numberOfLines = 0;
        // Create the progress view
        _headerProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        // Initialize the text
        _preScanHeaderText       = @"Tap Scan to begin listening for AMX beacons.";
        _addDiscoveredHeaderText = @"Tap + to add discovered projectors";
        // Initialize a host status dictionary
        _hostStatus = [NSMutableDictionary dictionary];
        // Initialize the array of projector hosts
        _projectorHosts = [NSMutableArray array];
        // Give a title to this view controller
        self.navigationItem.title = @"AMX Beacon Scan";
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Get the table view width
    CGFloat tableViewWidth = self.tableView.frame.size.width;
    // Compute the width available to the label
    CGFloat labelWidth = tableViewWidth - kPJBeaconListenerViewControllerLabelInsetLeft - kPJBeaconListenerViewControllerLabelInsetRight;
    // Get the constrained size
    CGSize constrainedSize = CGSizeMake(labelWidth, 2000.0);
    // Compute the size of the pre-scan header text and the add discovered text
    CGSize preScanHeaderTextSize = [self.preScanHeaderText sizeWithFont:self.headerLabel.font
                                                      constrainedToSize:constrainedSize
                                                          lineBreakMode:NSLineBreakByWordWrapping];
    CGSize addDiscoveredTextSize = [self.addDiscoveredHeaderText sizeWithFont:self.headerLabel.font
                                                            constrainedToSize:constrainedSize
                                                                lineBreakMode:NSLineBreakByWordWrapping];
    // Take the max of the two
    CGFloat maxHeight = MAX(preScanHeaderTextSize.height, addDiscoveredTextSize.height);
    // Make this an integer height
    maxHeight = ceilf(maxHeight);
    // Compute the width for the progress view
    CGFloat progressViewWidth = tableViewWidth -
                                kPJBeaconListenerViewControllerProgressViewInsetLeft -
                                kPJBeaconListenerViewConrtollerProgressViewInsetRight;
    // Get the size that fits for the progress view
    CGSize progressViewSizeThatFits = [self.headerProgressView sizeThatFits:CGSizeMake(progressViewWidth, 2000.0)];
    CGFloat progressViewHeight = ceilf(progressViewSizeThatFits.height);
    // Compute the overall height for the header view
    CGFloat headerViewHeight = ceilf(kPJBeaconListenerViewControllerLabelInsetTop +
                                     maxHeight +
                                     kPJBeaconListenerViewControllerLabelInsetBottom +
                                     kPJBeaconListenerViewControllerProgressViewInsetTop +
                                     progressViewHeight +
                                     kPJBeaconListenerViewControllerProgressViewInsetBottom);
    // Create the header view
    CGRect headerViewFrame = CGRectMake(0.0, 0.0, tableViewWidth, headerViewHeight);
    self.headerView = [[UIView alloc] initWithFrame:headerViewFrame];
    // Compute the frame for the header label
    CGRect headerLabelFrame = CGRectMake(kPJBeaconListenerViewControllerLabelInsetLeft,
                                         kPJBeaconListenerViewControllerLabelInsetTop,
                                         labelWidth,
                                         maxHeight);
    self.headerLabel.frame = headerLabelFrame;
    self.headerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.headerView addSubview:self.headerLabel];
    // Compute the frame for the progress view
    CGFloat progressViewOriginY = headerLabelFrame.origin.y + headerLabelFrame.size.height +
                                  kPJBeaconListenerViewControllerLabelInsetBottom +
                                  kPJBeaconListenerViewControllerProgressViewInsetTop;
    CGRect progressViewFrame = CGRectMake(kPJBeaconListenerViewControllerProgressViewInsetLeft,
                                          progressViewOriginY,
                                          progressViewWidth,
                                          progressViewHeight);
    self.headerProgressView.frame = progressViewFrame;
    self.headerProgressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.headerView addSubview:self.headerProgressView];

    // Set the header view into the table header view
    self.tableView.tableHeaderView = self.headerView;

    // Update the UI state
    [self updateUIState];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.projectorHosts count];
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* ret = nil;

    if ([self.projectorHosts count] > 0) {
        ret = @"Discovered Projectors";
    }

    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"AMXBeaconProjectorCellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    // Get the projector for this row
    PJProjector* projector = [self.projectorHosts objectAtIndex:indexPath.row];
    // Use the host address for the text label
    cell.textLabel.text = projector.host;

    return cell;
}

#pragma mark - UITableViewDelegate methods

#pragma mark - PJBeaconListenerViewController private methods

- (void)subscribeToNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(beaconHostsDidChange:)
                                                 name:PJAMXBeaconHostsDidChangeNotification
                                               object:self.amxBeaconListener];
}

- (void)unsubscribeFromNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PJAMXBeaconHostsDidChangeNotification
                                                  object:self.amxBeaconListener];
}

- (void)beaconHostsDidChange:(NSNotification *)notification {
    [self updateHostsStatusFromBeaconHosts];
}

- (void)scanButtonTapped:(id)sender {
    // Save the date we started listening
    self.listenStartDate = [NSDate date];
    // Start listening
    [self.amxBeaconListener startListening:nil];
    // Issue an AMX ping
    [self.amxBeaconListener ping];
    // Start the progress timer
    [self.progressTimer invalidate];
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:kPJBeaconListenerViewControllerProgressInterval
                                                          target:self
                                                        selector:@selector(timerFired:)
                                                        userInfo:nil
                                                         repeats:YES];
    // Start the ping timer
    [self.pingTimer invalidate];
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:kPJBeaconListenerViewControllerPingInterval
                                                      target:self
                                                    selector:@selector(timerFired:)
                                                    userInfo:nil
                                                     repeats:YES];
    // Update the UI state
    [self updateUIState];
}

- (void)cancelButtonTapped:(id)sender {
    // Stop listening and stop the timers
    [self stopListenerAndTimers];
    // Update the UI state
    [self updateUIState];
}

- (void)addButtonTapped:(id)sender {
    NSUInteger projectorHostsCount = [self.projectorHosts count];
    if (projectorHostsCount > 0) {
        // Add the array of PJProjectors to the projector manager
        BOOL added = [[PJProjectorManager sharedManager] addProjectorsToManager:self.projectorHosts];
        // Was the projector added successfully?
        NSString* title   = nil;
        NSString* message = nil;
        if (added) {
            // The projector was added successfully.
            title   = @"Projectors Added";
            message = @"Projectors were added successfully.";
        } else {
            // The only reason it would not be added is if it was already present.
            // So in this case show an alert to the user saying the projector
            // was already present.
            title   = @"Projectors Not Added";
            message = @"These projectors have already been added";
        }
        // Show an alert view with the result
        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    }
}

- (void)updateUIState {
    // Are we currently listening?
    if (self.amxBeaconListener.isListening) {
        // We are listening
        //
        // Make sure the progress view is visible
        self.headerProgressView.hidden = NO;
        // Provide a way to cancel
        self.navigationItem.rightBarButtonItem = self.cancelBarButtonItem;
        // Update the progress view and label
        [self updateProgress];
    } else {
        // Hide the progress view
        self.headerProgressView.hidden = YES;
        // We are not scanning. Do we have any discovered projectors?
        if ([self.projectorHosts count] > 0) {
            // We have some discovered projectors
            self.navigationItem.rightBarButtonItem = self.addBarButtonItem;
            self.headerLabel.text = self.addDiscoveredHeaderText;
        } else {
            // We have no discovered projectors
            self.headerLabel.text = self.preScanHeaderText;
            self.navigationItem.rightBarButtonItem = self.scanBarButtonItem;
        }
    }
}

- (void)timerFired:(NSTimer*)timer {
    if (timer == self.progressTimer) {
        // Update the progress
        [self updateProgress];
    } else if (timer == self.pingTimer) {
        // Issue an AMX ping
        [self.amxBeaconListener ping];
    }
}

- (void)updateProgress {
    // How long have we been listening?
    NSTimeInterval timeIntervalSinceStart = 0.0;
    if (self.listenStartDate != nil) {
        timeIntervalSinceStart = [[NSDate date] timeIntervalSinceDate:self.listenStartDate];
    }
    // Compute the fraction of this time over the listening duration
    CGFloat listeningProgress = timeIntervalSinceStart / kPJBeaconListenerViewControllerScanDuration;
    // Cap this at 1.0
    listeningProgress = MIN(listeningProgress, 1.0);
    // Update the progress view
    self.headerProgressView.progress = listeningProgress;
    // Compute the progress as a percent
    CGFloat listeningProgressPercent = listeningProgress * 100.0;
    NSUInteger listeningProgressPercentInt = (NSUInteger) ceilf(listeningProgressPercent);
    // Update the label
    NSString* listeningLabelText = [NSString stringWithFormat:@"Listening %u%%", listeningProgressPercentInt];
    self.headerLabel.text = listeningLabelText;
    // If we have exceeded the scan duration, then we should quit listening
    if (listeningProgress >= 1.0) {
        // Stop listening and stop timing
        [self stopListenerAndTimers];
        // Update our UI
        [self updateUIState];
    }
}

- (void)detectProjectorWithHost:(NSString*)host
                           port:(NSInteger)port
                        success:(void (^)(void)) success
                        failure:(void (^)(NSError* error)) failure {
    // Create a PJLink client
    NSURL* baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"pjlink://%@:%d/", host, port]];
    AFPJLinkClient* pjlinkClient = [[AFPJLinkClient alloc] initWithBaseURL:baseURL];
    // Try a PJLink client call just to obtain the projector name
    [pjlinkClient makeRequestWithBody:@"NAME ?\r"
                              timeout:kPJBeaconListenerViewControllerProjectorTimeoutInterval
                              success:^(AFPJLinkRequestOperation* operation, NSString* responseBody, NSArray* parsedResponses) {
                                  // Pass this back to the block if we have one
                                  if (success) {
                                      success();
                                  }
                              }
                              failure:^(AFPJLinkRequestOperation* operation, NSError* error) {
                                  // We may have failed due to a password error. If so,
                                  // then we still consider this success, since we were able
                                  // to detect a projector at this address.
                                  if ([error.domain isEqualToString:PJLinkErrorDomain] &&
                                       error.code == PJLinkErrorNoPasswordProvided) {
                                      // Pass this back to the block if we have one
                                      if (success) {
                                          success();
                                      }
                                  } else {
                                      if (failure) {
                                          failure(error);
                                      }
                                  }
                              }];
}

- (void)updateHostsStatusFromBeaconHosts {
    // Get the number of beacon hosts detected
    NSUInteger beaconHostsCount = [self.amxBeaconListener countOfHosts];
    if (beaconHostsCount > 0) {
        // Loop through the beacon hosts
        for (NSUInteger i = 0; i < beaconHostsCount; i++) {
            // Get the i-th beacon host
            PJAMXBeaconHost* ithBeaconHost = (PJAMXBeaconHost*) [self.amxBeaconListener objectInHostsAtIndex:i];
            // Get the IP address we detected from the beacon socket
            NSString* ithBeaconHostAddress = ithBeaconHost.ipAddressFromSocket;
            if ([ithBeaconHostAddress length] > 0) {
                // Get the host status
                PJProjectorDetectionStatus detectionStatus = PJProjectorDetectionStatusUnknown;
                NSNumber* ithBeaconStatusNum = [self.hostStatus objectForKey:ithBeaconHostAddress];
                if (ithBeaconStatusNum != nil) {
                    detectionStatus = (PJProjectorDetectionStatus) [ithBeaconStatusNum integerValue];
                }
                // Is the detection status unknown?
                if (detectionStatus == PJProjectorDetectionStatusUnknown) {
                    // We have not yet tried to detect a projector for this host address,
                    // so set the status to be in-progress
                    [self.hostStatus setObject:@(PJProjectorDetectionStatusDetectionInProgress)
                                        forKey:ithBeaconHostAddress];
                    // Lots of different A/V devices implement AMX beacons. So just
                    // because we get an AMX beacon detected, it doesn't mean that
                    // this is projector. So we have to try and detect if the projector
                    // implements PJLink before we know it's a projector.
                    //
                    // So try to detect a projector at this address
                    [self detectProjectorWithHost:ithBeaconHostAddress
                                             port:kDefaultPJLinkPort
                                          success:^{
                                              // We detected a projector at this host address
                                              //
                                              // Set the status to PJProjectorDetectionStatusPJLinkSupported
                                              [self.hostStatus setObject:@(PJProjectorDetectionStatusPJLinkSupported)
                                                                  forKey:ithBeaconHostAddress];
                                              // Add this projector
                                              [self addProjectorToHostsWithAddress:ithBeaconHostAddress];
                                          }
                                          failure:^(NSError* error) {
                                              // Set the status to PJProjectorDetectionStatusPJLinkNotSupported.
                                              // This is most likely some other type of A/V equipment
                                              [self.hostStatus setObject:@(PJProjectorDetectionStatusPJLinkNotSupported)
                                                                  forKey:ithBeaconHostAddress];
                                          }];
                }
            }
        }
    }
}

- (void)addProjectorToHostsWithAddress:(NSString*)projectorHostAddress {
    if ([projectorHostAddress length] > 0) {
        // Create a PJProjector at this address
        PJProjector* projector = [[PJProjector alloc] initWithHost:projectorHostAddress];
        // Add this projector to our array of hosts
        [self.projectorHosts addObject:projector];
        // Sort the array by host address
        [self.projectorHosts sortUsingComparator:^(id obj1, id obj2) {
            PJProjector* proj1 = (PJProjector*)obj1;
            PJProjector* proj2 = (PJProjector*)obj2;
            // Convert the host addresses like "192.168.1.13" to an integer
            NSNumber* proj1HostNum = [NSNumber numberWithUnsignedInt:[PJInterfaceInfo integerHostForHost:proj1.host]];
            NSNumber* proj2HostNum = [NSNumber numberWithUnsignedInt:[PJInterfaceInfo integerHostForHost:proj2.host]];
            // Compare the integers
            return [proj1HostNum compare:proj2HostNum];
        }];
        // Reload the table data
        [self.tableView reloadData];
    }
}

- (void)stopProgressTimer {
    // Cancel the progress timer
    [self.progressTimer invalidate];
    self.progressTimer = nil;
}

- (void)stopPingTimer {
    // Cancel the ping timer
    [self.pingTimer invalidate];
    self.pingTimer = nil;
}

- (void)stopListenerAndTimers {
    // Stop the timers
    [self stopProgressTimer];
    [self stopPingTimer];
    // Stop listening
    [self.amxBeaconListener stopListening];
}

@end
