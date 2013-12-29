//
//  PJProjectorDetailTableViewController.m
//  ProjectR
//
//  Created by Eric Hyche on 8/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJProjectorDetailTableViewController.h"
#import "PJProjector.h"
#import "PJLampStatus.h"
#import "PJInputSelectTableViewController.h"

@interface PJProjectorDetailTableViewController ()

@property (weak, nonatomic) IBOutlet UILabel *powerStatusLabel;
@property (weak, nonatomic) IBOutlet UISwitch *powerStatusSwitch;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *powerStatusActivityIndicatorView;
@property (weak, nonatomic) IBOutlet UILabel *inputLabel;
@property (weak, nonatomic) IBOutlet UISwitch *audioMuteSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *videoMuteSwitch;
@property (weak, nonatomic) IBOutlet UILabel *lampStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *fanErrorLabel;
@property (weak, nonatomic) IBOutlet UILabel *temperatureErrorLabel;
@property (weak, nonatomic) IBOutlet UILabel *lampErrorLabel;
@property (weak, nonatomic) IBOutlet UILabel *coverOpenErrorLabel;
@property (weak, nonatomic) IBOutlet UILabel *filterErrorLabel;
@property (weak, nonatomic) IBOutlet UILabel *otherErrorLabel;
@property (weak, nonatomic) IBOutlet UILabel *projectorNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *manufacturerNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *productNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *otherInfoLabel;
@property (weak, nonatomic) IBOutlet UILabel *class2CompatibleLabel;
@property (weak, nonatomic) IBOutlet UILabel *amxBeaconLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *lampStatusCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *amxBeaconCell;

@end

@implementation PJProjectorDetailTableViewController

- (void)dealloc {
    [self unsubscribeToNotificationsForProjector:_projector];
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self dataDidChange];

}

- (void)setProjector:(PJProjector *)projector {
    if (_projector != projector) {
        // Unsubscribe to notifications for old projector
        [self unsubscribeToNotificationsForProjector:_projector];
        // Save the new projector
        _projector = projector;
        // Subscribe to notifications for new projector
        [self subscribeToNotificationsForProjector:projector];
        // Handle the projector change
        [self dataDidChange];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"inputSelectSegue"]) {
        [[segue destinationViewController] setProjector:self.projector];
    }
}

#pragma mark - UITableViewDataSource methods

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // De-select the row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - PJProjectorDetailTableViewController private methods

- (void)subscribeToNotificationsForProjector:(PJProjector*)projector {
    if (projector != nil) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(projectorDidChange:)
                                                     name:PJProjectorDidChangeNotification
                                                   object:projector];
    }
}

- (void)unsubscribeToNotificationsForProjector:(PJProjector*)projector {
    if (projector != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:PJProjectorDidChangeNotification
                                                      object:projector];
    }
}

- (void)projectorDidChange:(NSNotification*)notification {
    [self dataDidChange];
}

- (void)dataDidChange {
    if (self.projector != nil) {
        // Set the power status
        NSString* powerStatusText = nil;
        BOOL switchEnabled = NO;
        BOOL switchOn      = NO;
        switch (self.projector.powerStatus) {
            case PJPowerStatusWarmUp:
                powerStatusText = @"Warming Up";
                break;
            case PJPowerStatusCooling:
                powerStatusText = @"Cooling Down";
                break;
            case PJPowerStatusLampOn:
                powerStatusText = @"Lamp On";
                switchEnabled = YES;
                switchOn      = YES;
                break;
            case PJPowerStatusStandby:
                powerStatusText = @"Standby";
                switchEnabled = YES;
                break;
            default:
                break;
        }
        self.powerStatusLabel.text = powerStatusText;
        self.powerStatusSwitch.enabled = switchEnabled;
        self.powerStatusSwitch.on = switchOn;
        // Determine if we should be animating
        BOOL animating = !switchEnabled;
        if (animating && !self.powerStatusActivityIndicatorView.isAnimating) {
            [self.powerStatusActivityIndicatorView startAnimating];
        } else if (!animating && self.powerStatusActivityIndicatorView.isAnimating) {
            [self.powerStatusActivityIndicatorView stopAnimating];
        }
        // Handle the input label
        self.inputLabel.text = self.projector.activeInputName;
        // Handle the mute switches
        self.audioMuteSwitch.on = self.projector.isAudioMuted;
        self.videoMuteSwitch.on = self.projector.isVideoMuted;
        // If there is only one lamp (which is the usual case), then we
        // put the number of hours in the detail text and disable the
        // accessory chevron.
        if (self.projector.numberOfLamps == 1) {
            PJLampStatus* lampStatus = [self.projector.lampStatus objectAtIndex:0];
            self.lampStatusLabel.text = [NSString stringWithFormat:@"%@ (%u hours)",
                                         (lampStatus.lampOn ? @"On" : @"Off"), lampStatus.cumulativeLightingTime];
            self.lampStatusCell.accessoryType = UITableViewCellAccessoryNone;
        } else if (self.projector.numberOfLamps > 1) {
            self.lampStatusLabel.text = [NSString stringWithFormat:@"%u Lamps", self.projector.numberOfLamps];
        }
        // Set the error statuses
        self.fanErrorLabel.text = [PJProjectorDetailTableViewController textForErrorStatus:self.projector.fanErrorStatus];
        self.temperatureErrorLabel.text = [PJProjectorDetailTableViewController textForErrorStatus:self.projector.lampErrorStatus];
        self.lampErrorLabel.text = [PJProjectorDetailTableViewController textForErrorStatus:self.projector.temperatureErrorStatus];
        self.coverOpenErrorLabel.text = [PJProjectorDetailTableViewController textForErrorStatus:self.projector.coverOpenErrorStatus];
        self.filterErrorLabel.text = [PJProjectorDetailTableViewController textForErrorStatus:self.projector.filterErrorStatus];
        self.otherErrorLabel.text = [PJProjectorDetailTableViewController textForErrorStatus:self.projector.otherErrorStatus];
        // Set the general projector information
        self.projectorNameLabel.text = self.projector.projectorName;
        self.manufacturerNameLabel.text = self.projector.manufacturerName;
        self.productNameLabel.text = self.projector.productName;
        self.otherInfoLabel.text = self.projector.otherInformation;
        self.class2CompatibleLabel.text = (self.projector.isClass2Compatible ? @"Yes" : @"No");
        // Fill in the AMX Beacon information.
        // If we have an AMX Beacon, then we leave the accessory
        // chevron in place and fill in a "Yes" in the detail text view.
        // If we do not have an AMX beacon, then we just put "None"
        // in the detail text for this cell and remove the accessory
        // chevron from the cell.
        if (self.projector.beaconHost != nil) {
            self.amxBeaconLabel.text = @"Yes";
            self.amxBeaconCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            self.amxBeaconLabel.text = @"None";
            self.amxBeaconCell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
}

- (IBAction)powerSwitchDidChange:(id)sender {
    [self.projector requestPowerStateChange:self.powerStatusSwitch.isOn];
}

- (IBAction)audioMuteSwitchDidChange:(id)sender {
    [self.projector requestMuteStateChange:self.audioMuteSwitch.isOn forTypes:PJMuteTypeAudio];
}

- (IBAction)videoMuteSwitchDidChange:(id)sender {
    [self.projector requestMuteStateChange:self.videoMuteSwitch.isOn forTypes:PJMuteTypeVideo];
}

+ (NSString*)textForErrorStatus:(PJErrorStatus)status {
    NSString* ret = @"No Error";
    if (status == PJErrorStatusError) {
        ret = @"Error";
    } else if (status == PJErrorStatusWarning) {
        ret = @"Warning";
    }
    return ret;
}


@end
