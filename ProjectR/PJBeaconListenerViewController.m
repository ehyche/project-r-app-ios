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
#import "UIImage+SolidColor.h"
#import "PJLabeledProgressView.h"

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
CGFloat const kPJBeaconListenerViewControllerProgressViewInsetRight  = 20.0;
CGFloat const kPJBeaconListenerViewControllerButtonHeight            = 64.0;


@interface PJBeaconListenerViewController ()

@property(nonatomic,strong) UIButton*              button;
@property(nonatomic,strong) PJLabeledProgressView* progressView;
@property(nonatomic,strong) PJAMXBeaconListener*   amxBeaconListener;
@property(nonatomic,strong) NSTimer*               progressTimer;
@property(nonatomic,strong) NSTimer*               pingTimer;
@property(nonatomic,strong) NSDate*                listenStartDate;
@property(nonatomic,strong) NSMutableDictionary*   hostStatus;
@property(nonatomic,strong) NSMutableArray*        projectorHosts;

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
        // Create the footer button
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
        // Initialize a host status dictionary
        _hostStatus = [NSMutableDictionary dictionary];
        // Initialize the array of projector hosts
        _projectorHosts = [NSMutableArray array];
        // Give a title to this view controller
        self.navigationItem.title = @"AMX Beacon Scan";
        // Set the cancel button in the upper left
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                              target:self
                                                                                              action:@selector(cancelButtonTapped:)];
        // Create the progress view
        self.progressView = [[PJLabeledProgressView alloc] init];
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.button.frame = CGRectMake(0.0, 0.0, self.view.frame.size.width, kPJBeaconListenerViewControllerButtonHeight);
    self.tableView.tableFooterView = self.button;

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
    [self.amxBeaconListener addObserver:self
                             forKeyPath:@"listening"
                                options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                context:NULL];
}

- (void)unsubscribeFromNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PJAMXBeaconHostsDidChangeNotification
                                                  object:self.amxBeaconListener];
    [self.amxBeaconListener removeObserver:self
                                forKeyPath:@"listening"
                                   context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"listening"]) {
        BOOL oldListening = [[change objectForKey:NSKeyValueChangeOldKey] boolValue];
        BOOL newListening = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (oldListening != newListening) {
            [self listeningDidChange];
        }
    }
}

- (void)listeningDidChange {
    if (self.amxBeaconListener.isListening) {
        // We just started listening, so start the timers
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
    } else {
        // We stopped listening, so kill the timers
        [self stopPingTimer];
        [self stopProgressTimer];
    }
    [self updateUIState];
}

- (void)beaconHostsDidChange:(NSNotification *)notification {
    [self updateHostsStatusFromBeaconHosts];
}

- (void)buttonTapped:(id)sender {
    // Are we currently listening?
    if (self.amxBeaconListener.isListening) {
        // Stop listening
        [self.amxBeaconListener stopListening];
    } else {
        // We are not scanning. Do we have any discovered projectors?
        if ([self.projectorHosts count] > 0) {
            // Add the array of PJProjectors to the projector manager
            [[PJProjectorManager sharedManager] addProjectorsToManager:self.projectorHosts];
            // Dismiss ourself
            [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        } else {
            // Save the date we started listening
            self.listenStartDate = [NSDate date];
            // Start listening
            [self.amxBeaconListener startListening:nil];
        }
    }
}

- (void)cancelButtonTapped:(id)sender {
    // Stop listening and stop the timers
    [self stopListenerAndTimers];
    // Dismiss ourself
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
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

- (void)updateUIState {
    [self showHideProgressView:self.amxBeaconListener.isListening];
    self.button.selected = self.amxBeaconListener.isListening;
    if (!self.amxBeaconListener.isListening) {
        NSString* buttonTitle = ([self.projectorHosts count] > 0 ? @"Add Projectors" : @"Start Scanning");
        [self.button setTitle:buttonTitle forState:UIControlStateNormal];
        [self.button setTitle:buttonTitle forState:UIControlStateHighlighted];
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
    self.progressView.progress = listeningProgress;
    self.progressView.progressText = [NSString stringWithFormat:@"Listening (%.0f%%)", listeningProgress * 100.0];
    // If we have exceeded the scan duration, then we should quit listening
    if (listeningProgress >= 1.0 && self.amxBeaconListener.isListening) {
        [self.amxBeaconListener stopListening];
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
