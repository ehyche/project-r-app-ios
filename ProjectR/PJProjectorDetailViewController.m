//
//  PJProjectorDetailViewController.m
//  ProjectR
//
//  Created by Eric Hyche on 1/2/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJProjectorDetailViewController.h"
#import "PJProjector.h"
#import "PJResponseInfo.h"
#import "PJInputInfo.h"
#import "PJLampStatus.h"

/*
 * Table view layout
 *
 * Connection
 *
 * Host                          <Host> (UITableViewCellStyleValue1)
 * Port                          <Port> (UITableViewCellStyleValue1)
 * State       <Text Connection Status> (UITableViewCellStyleValue1)
 *
 * Status
 *
 * Power            <Text Power Status> (UITableViewCellStyleValue1)
 * Toggle                      UISwitch (UITableViewCellStyleDefault)
 * Audio Mute                  UISwitch (UITableViewCellStyleDefault)
 * Video Mute                  UISwitch (UITableViewCellStyleDefault)
 *
 * Inputs
 *
 * <Input Name 0>                       (UITableViewCellStyleDefault)
 * <Input Name 1>                     X (UITableViewCellStyleDefault)
 *    ...
 * <Input Name N-1>                     (UITableViewCellStyleDefault)
 *
 * Errors
 *
 * Fan                 OK/Warning/Error (UITableViewCellStyleValue1)
 * Lamp                OK/Warning/Error (UITableViewCellStyleValue1)
 * Temperature         OK/Warning/Error (UITableViewCellStyleValue1)
 * Cover Open          OK/Warning/Error (UITableViewCellStyleValue1)
 * Filter              OK/Warning/Error (UITableViewCellStyleValue1)
 * Other               OK/Warning/Error (UITableViewCellStyleValue1)
 *
 * Lamps
 *
 * Lamp 0              On/Off (M hours) (UITableViewCellStyleValue1)
 * Lamp 1              On/Off (M hours) (UITableViewCellStyleValue1)
 * ...
 * Lamp N-1            On/Off (M hours) (UITableViewCellStyleValue1)
 *
 * Info
 *
 * Projector          <Projector Name> (UITableViewCellStyleValue1)
 * Manufacturer    <Manufacturer Name> (UITableViewCellStyleValue1)
 * Product              <Product Name> (UITableViewCellStyleValue1)
 * Other                  <Other Info> (UITableViewCellStyleValue1)
 * Class 2 Compatible           Yes/No (UITableViewCellStyleValue1)
 */

NSInteger const kPJProjectorDetailSectionCount              = 6;
NSInteger const kPJProjectorDetailSectionConnection         = 0;
NSInteger const kPJProjectorDetailSectionStatus             = 1;
NSInteger const kPJProjectorDetailSectionInputs             = 2;
NSInteger const kPJProjectorDetailSectionErrors             = 3;
NSInteger const kPJProjectorDetailSectionLamps              = 4;
NSInteger const kPJProjectorDetailSectionInfo               = 5;
NSInteger const kPJProjectorDetailConnectionSectionRowCount = 3;
NSInteger const kPJProjectorDetailStatusSectionRowCount     = 4;
NSInteger const kPJProjectorDetailErrorsSectionRowCount     = 6;
NSInteger const kPJProjectorDetailInfoSectionRowCount       = 5;
NSInteger const kPJProjectorDetailHostRow                   = 0;
NSInteger const kPJProjectorDetailPortRow                   = 1;
NSInteger const kPJProjectorDetailConnectionStateRow        = 2;
NSInteger const kPJProjectorDetailPowerStatusRow            = 0;
NSInteger const kPJProjectorDetailPowerToggleRow            = 1;
NSInteger const kPJProjectorDetailAudioMuteRow              = 2;
NSInteger const kPJProjectorDetailVideoMuteRow              = 3;
NSInteger const kPJProjectorDetailFanErrorRow               = 0;
NSInteger const kPJProjectorDetailLampErrorRow              = 1;
NSInteger const kPJProjectorDetailTemperatureErrorRow       = 2;
NSInteger const kPJProjectorDetailCoverOpenErrorRow         = 3;
NSInteger const kPJProjectorDetailFilterErrorRow            = 4;
NSInteger const kPJProjectorDetailOtherErrorRow             = 5;
NSInteger const kPJProjectorDetailProjectorInfoRow          = 0;
NSInteger const kPJProjectorDetailManufacturerInfoRow       = 1;
NSInteger const kPJProjectorDetailProductInfoRow            = 2;
NSInteger const kPJProjectorDetailOtherInfoRow              = 3;
NSInteger const kPJProjectorDetailClass2CompatibleRow       = 4;

@interface PJProjectorDetailViewController ()

@property(nonatomic,strong) UISwitch*                powerSwitch;
@property(nonatomic,strong) UISwitch*                audioMuteSwitch;
@property(nonatomic,strong) UISwitch*                videoMuteSwitch;
@property(nonatomic,strong) UIActivityIndicatorView* spinner;
@property(nonatomic,strong) UIBarButtonItem*         spinnerBarButtonItem;
@property(nonatomic,strong) UIBarButtonItem*         refreshBarButtonItem;
@property(nonatomic,assign) NSInteger                pendingActiveInputIndex;
@property(nonatomic,strong) UIActivityIndicatorView* activityIndicatorView;
@property(nonatomic,strong) UIColor*                 detailTextColorErrorCellOK;
@property(nonatomic,strong) UIColor*                 detailTextColorErrorCellWarning;
@property(nonatomic,strong) UIColor*                 detailTextColorErrorCellError;
@property(nonatomic,strong) UIColor*                 detailTextColorNonErrorCell;

@end

@implementation PJProjectorDetailViewController

- (void)dealloc {
    [self unsubscribeFromNotificationsForProjector:_projector];
}

- (id)init {
    return [self initWithStyle:UITableViewStyleGrouped];
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Create the switches
        self.powerSwitch     = [[UISwitch alloc] init];
        self.audioMuteSwitch = [[UISwitch alloc] init];
        self.videoMuteSwitch = [[UISwitch alloc] init];
        // Tell each switch to take on its default size
        [self.powerSwitch sizeToFit];
        [self.audioMuteSwitch sizeToFit];
        [self.videoMuteSwitch sizeToFit];
        // Add the target/action for each switch
        [self.powerSwitch     addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
        [self.audioMuteSwitch addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
        [self.videoMuteSwitch addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
        // Create a spinner to be used in the right bar button item
        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [self.spinner sizeToFit];
        // Create a bar button item with the spinner in it
        self.spinnerBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.spinner];
        // Create a manual refreh bar button item
        self.refreshBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                  target:self
                                                                                  action:@selector(refreshBarButtonItemTapped:)];
        // Initially show the refresh button
        self.navigationItem.rightBarButtonItem = self.refreshBarButtonItem;
        // Init the pending active input index
        self.pendingActiveInputIndex = -1;
        // Create the spinner for changing the input
        self.activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [self.activityIndicatorView sizeToFit];
        // Set the title
        self.navigationItem.title = self.projector.displayName;
        // Configure the colors
        self.detailTextColorErrorCellOK      = [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0];
        self.detailTextColorErrorCellWarning = [UIColor colorWithRed:0.7 green:0.7 blue:0.0 alpha:1.0];
        self.detailTextColorErrorCellError   = [UIColor colorWithRed:0.7 green:0.0 blue:0.0 alpha:1.0];
        self.detailTextColorNonErrorCell     = [UIColor colorWithRed:0.55686274509804 green:0.55686274509804 blue:0.57647058823529 alpha:1.0];
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Ensure we have loaded the table view
    [self dataDidChange];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)setProjector:(PJProjector *)projector {
    if (projector != _projector) {
        // Unsubscribe from notifications for the old projector
        [self unsubscribeFromNotificationsForProjector:_projector];
        // Save the new projector
        _projector = projector;
        // Subscribe to notifications for the new projector
        [self subscribeToNotificationsForProjector:projector];
        // Update the data
        [self dataDidChange];
    }
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kPJProjectorDetailSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger ret = 0;

    if (section == kPJProjectorDetailSectionConnection) {
        ret = kPJProjectorDetailConnectionSectionRowCount;
    } else if (section == kPJProjectorDetailSectionStatus) {
        ret = kPJProjectorDetailStatusSectionRowCount;
    } else if (section == kPJProjectorDetailSectionInputs) {
        ret = [self.projector countOfInputs];
    } else if (section == kPJProjectorDetailSectionErrors) {
        ret = kPJProjectorDetailErrorsSectionRowCount;
    } else if (section == kPJProjectorDetailSectionLamps) {
        ret = [self.projector countOfLampStatus];
    } else if (section == kPJProjectorDetailSectionInfo) {
        ret = kPJProjectorDetailInfoSectionRowCount;
    }

    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Define the two cell ID's we will use
    static NSString* cellIDDefault = @"PJProjectorDetailCellIDDefault";
    static NSString* cellIDValue1  = @"PJProjectorDetailCellIDValue1";

    // Determine which cell reuse ID to use
    NSString*            cellReuseID = cellIDValue1;
    UITableViewCellStyle cellStyle   = UITableViewCellStyleValue1;
    if (indexPath.section == kPJProjectorDetailSectionStatus) {
        if (indexPath.row != kPJProjectorDetailPowerStatusRow) {
            cellReuseID = cellIDDefault;
            cellStyle   = UITableViewCellStyleDefault;
        }
    } else if (indexPath.section == kPJProjectorDetailSectionInputs) {
        cellReuseID = cellIDDefault;
        cellStyle   = UITableViewCellStyleDefault;
    }

    // Create/Re-use the cell
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellReuseID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:cellStyle reuseIdentifier:cellReuseID];
    }

    // Configure the default cell properties
    // By default, we use the default detailTextLabel color
    UIColor* detailTextColor = self.detailTextColorNonErrorCell;

    // Configure the per-section cell properties
    if (indexPath.section == kPJProjectorDetailSectionConnection) {
        //
        // Connection section
        //
        if (indexPath.row == kPJProjectorDetailHostRow) {
            cell.textLabel.text       = @"Host";
            cell.detailTextLabel.text = self.projector.host;
        } else if (indexPath.row == kPJProjectorDetailPortRow) {
            cell.textLabel.text       = @"Port";
            cell.detailTextLabel.text = [[NSNumber numberWithInteger:self.projector.port] stringValue];
        } else if (indexPath.row == kPJProjectorDetailConnectionStateRow) {
            cell.textLabel.text       = @"State";
            cell.detailTextLabel.text = [PJProjector stringForConnectionState:self.projector.connectionState];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == kPJProjectorDetailSectionStatus) {
        //
        // Status section
        //
        if (indexPath.row == kPJProjectorDetailPowerStatusRow) {
            cell.textLabel.text       = @"Power Status";
            cell.detailTextLabel.text = [PJResponseInfoPowerStatusQuery stringForPowerStatus:self.projector.powerStatus];
        } else if (indexPath.row == kPJProjectorDetailPowerToggleRow) {
            cell.textLabel.text = @"Power Toggle";
            cell.accessoryView  = self.powerSwitch;
        } else if (indexPath.row == kPJProjectorDetailAudioMuteRow) {
            cell.textLabel.text = @"Audio Mute";
            cell.accessoryView  = self.audioMuteSwitch;
        } else if (indexPath.row == kPJProjectorDetailVideoMuteRow) {
            cell.textLabel.text = @"Video Mute";
            cell.accessoryView  = self.videoMuteSwitch;
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == kPJProjectorDetailSectionInputs) {
        //
        // Input section
        //
        // Get the input name for this row
        NSString* inputName = @"";
        if (indexPath.row < [self.projector countOfInputs]) {
            PJInputInfo* inputInfo = [self.projector objectInInputsAtIndex:indexPath.row];
            inputName = [inputInfo description];
        }
        cell.textLabel.text = inputName;
        // If this is the active input, then use a checkmark for the accesory type.
        // If this is the pending active input, then put a spinner.
        // Otherwise, nothing will be in accessory view.
        // The active input take precedence over pending active input
        if (indexPath.row == self.projector.activeInputIndex) {
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else if (indexPath.row == self.pendingActiveInputIndex) {
            cell.accessoryView = self.activityIndicatorView;
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        cell.accessoryType = (indexPath.row == self.projector.activeInputIndex ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone);
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if (indexPath.section == kPJProjectorDetailSectionErrors) {
        //
        // Error section
        //
        PJErrorStatus errorStatus = NumPJErrorStatuses;
        if (indexPath.row == kPJProjectorDetailFanErrorRow) {
            cell.textLabel.text = @"Fan";
            errorStatus         = self.projector.fanErrorStatus;
        } else if (indexPath.row == kPJProjectorDetailLampErrorRow) {
            cell.textLabel.text = @"Lamp";
            errorStatus         = self.projector.lampErrorStatus;
        } else if (indexPath.row == kPJProjectorDetailTemperatureErrorRow) {
            cell.textLabel.text = @"Temperature";
            errorStatus         = self.projector.temperatureErrorStatus;
        } else if (indexPath.row == kPJProjectorDetailCoverOpenErrorRow) {
            cell.textLabel.text = @"Cover Open";
            errorStatus         = self.projector.coverOpenErrorStatus;
        } else if (indexPath.row == kPJProjectorDetailFilterErrorRow) {
            cell.textLabel.text = @"Filter";
            errorStatus         = self.projector.filterErrorStatus;
        } else if (indexPath.row == kPJProjectorDetailOtherErrorRow) {
            cell.textLabel.text = @"Other";
            errorStatus         = self.projector.otherErrorStatus;
        }
        // Get the detail label text
        cell.detailTextLabel.text = [PJResponseInfoErrorStatusQuery stringForErrorStatus:errorStatus];
        // Try different colors for the error status
        if (errorStatus == PJErrorStatusNoError) {
            detailTextColor = self.detailTextColorErrorCellOK;
        } else if (errorStatus == PJErrorStatusWarning) {
            detailTextColor = self.detailTextColorErrorCellWarning;
        } else if (errorStatus == PJErrorStatusError) {
            detailTextColor = self.detailTextColorErrorCellError;
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == kPJProjectorDetailSectionLamps) {
        //
        // Lamp status section
        //
        // Get the text and detail text
        NSString* lampName   = @"";
        NSString* lampDetail = @"";
        if (indexPath.row < [self.projector countOfLampStatus]) {
            // Get the lamp name, which is just Lamp 0, Lamp 1, etc.
            lampName = [NSString stringWithFormat:@"Lamp %d", indexPath.row];
            // Get the lamp detail, which is something like "Off (20 hours)"
            PJLampStatus* lampStatus = (PJLampStatus*) [self.projector objectInLampStatusAtIndex:indexPath.row];
            NSString* onOff = (lampStatus.lampOn ? @"On" : @"Off");
            lampDetail = [NSString stringWithFormat:@"%@ (%u hours)", onOff, lampStatus.cumulativeLightingTime];
        }
        cell.textLabel.text       = lampName;
        cell.detailTextLabel.text = lampDetail;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == kPJProjectorDetailSectionInfo) {
        //
        // Info section
        //
        if (indexPath.row == kPJProjectorDetailProjectorInfoRow) {
            cell.textLabel.text       = @"Projector";
            cell.detailTextLabel.text = self.projector.projectorName;
        } else if (indexPath.row == kPJProjectorDetailManufacturerInfoRow) {
            cell.textLabel.text       = @"Manufacturer";
            cell.detailTextLabel.text = self.projector.manufacturerName;
        } else if (indexPath.row == kPJProjectorDetailProductInfoRow) {
            cell.textLabel.text       = @"Product";
            cell.detailTextLabel.text = self.projector.productName;
        } else if (indexPath.row == kPJProjectorDetailOtherInfoRow) {
            cell.textLabel.text       = @"Other";
            cell.detailTextLabel.text = self.projector.otherInformation;
        } else if (indexPath.row == kPJProjectorDetailClass2CompatibleRow) {
            cell.textLabel.text       = @"Class 2 Compatible";
            cell.detailTextLabel.text = (self.projector.isClass2Compatible ? @"Yes" : @"No");
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    // Assign the detail text label color
    cell.detailTextLabel.textColor = detailTextColor;

    return cell;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* ret = nil;

    if (section == kPJProjectorDetailSectionConnection) {
        ret = @"Connection";
    } else if (section == kPJProjectorDetailSectionStatus) {
        ret = @"Status";
    } else if (section == kPJProjectorDetailSectionInputs) {
        ret = @"Inputs";
    } else if (section == kPJProjectorDetailSectionErrors) {
        ret = @"Errors";
    } else if (section == kPJProjectorDetailSectionLamps) {
        ret = @"Lamps";
    } else if (section == kPJProjectorDetailSectionInfo) {
        ret = @"Info";
    }

    return ret;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // De-select the row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // The only section which has tappable rows is the input section,
    // since you switch inputs by tapping on the new input row you want.
    if (indexPath.section == kPJProjectorDetailSectionInputs) {
        // Is the projector already on this input?
        if (indexPath.row != self.projector.activeInputIndex) {
            // Save the pending active input row
            self.pendingActiveInputIndex = indexPath.row;
            // Start animating the activity indicator
            [self.activityIndicatorView startAnimating];
            // Reload the row at this index path
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            // A change in the input is requested
            [self.projector requestInputChangeToInputIndex:indexPath.row];
        }
    }
}

#pragma mark - PJProjectorDetailViewController private methods

- (void)switchValueChanged:(id)sender {
    if (sender == self.powerSwitch) {
        // Request a power change
        [self.projector requestPowerStateChange:self.powerSwitch.isOn];
    } else if (sender == self.audioMuteSwitch) {
        // Request a change to the audio mute state
        [self.projector requestMuteStateChange:self.audioMuteSwitch.isOn forTypes:PJMuteTypeAudio];
    } else if (sender == self.videoMuteSwitch) {
        // Request a change to the video mute state
        [self.projector requestMuteStateChange:self.videoMuteSwitch.isOn forTypes:PJMuteTypeVideo];
    }
}

- (void)refreshBarButtonItemTapped:(id)sender {
    // Refresh all the projector properties
    [self.projector refreshAllQueries];
}

- (void)projectorRequestDidBegin:(NSNotification*)notification {
    // When we begin a request, we put the spinner for the right bar button item
    [self.spinner startAnimating];
    self.navigationItem.rightBarButtonItem = self.spinnerBarButtonItem;
}

- (void)projectorRequestDidEnd:(NSNotification*)notification {
    // When we end the requestm we put the manual refresh button back as the right bar button item
    [self.spinner stopAnimating];
    self.navigationItem.rightBarButtonItem = self.refreshBarButtonItem;
}

- (void)projectorDidChange:(NSNotification*)notification {
    [self dataDidChange];
}

- (void)projectorConnectionStateDidChange:(NSNotification*)notification {
    // Get the index path for the connection state row
    NSIndexPath* connectionStateIndexPath = [NSIndexPath indexPathForRow:kPJProjectorDetailConnectionStateRow inSection:kPJProjectorDetailSectionConnection];
    // Reload the connection state row
    [self.tableView reloadRowsAtIndexPaths:@[connectionStateIndexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)subscribeToNotificationsForProjector:(PJProjector*)projector {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(projectorRequestDidBegin:)
                               name:PJProjectorRequestDidBeginNotification
                             object:projector];
    [notificationCenter addObserver:self
                           selector:@selector(projectorRequestDidEnd:)
                               name:PJProjectorRequestDidEndNotification
                             object:projector];
    [notificationCenter addObserver:self
                           selector:@selector(projectorDidChange:)
                               name:PJProjectorDidChangeNotification
                             object:projector];
    [notificationCenter addObserver:self
                           selector:@selector(projectorConnectionStateDidChange:)
                               name:PJProjectorConnectionStateDidChangeNotification
                             object:projector];
}

- (void)unsubscribeFromNotificationsForProjector:(PJProjector*)projector {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self
                                  name:PJProjectorRequestDidBeginNotification
                                object:projector];
    [notificationCenter removeObserver:self
                                  name:PJProjectorRequestDidEndNotification
                                object:projector];
    [notificationCenter removeObserver:self
                                  name:PJProjectorDidChangeNotification
                                object:projector];
    [notificationCenter removeObserver:self
                                  name:PJProjectorConnectionStateDidChangeNotification
                                object:projector];
}

- (void)updatePowerSwitchState {
    BOOL isOn    = NO;
    BOOL enabled = NO;
    switch (self.projector.powerStatus) {
        case PJPowerStatusCooling:
            isOn    = NO;
            enabled = NO;
            break;
        case PJPowerStatusWarmUp:
            isOn    = YES;
            enabled = NO;
            break;
        case PJPowerStatusLampOn:
            isOn    = YES;
            enabled = YES;
            break;
        case PJPowerStatusStandby:
            isOn    = NO;
            enabled = YES;
            break;
        default:
            break;
    }
    self.powerSwitch.on      = isOn;
    self.powerSwitch.enabled = enabled;
}

- (void)updateAudioMuteSwitchState {
    self.audioMuteSwitch.on = self.projector.isAudioMuted;
}

- (void)updateVideoMuteSwitchState {
    self.videoMuteSwitch.on = self.projector.isVideoMuted;
}

- (void)dataDidChange {
    [self updatePowerSwitchState];
    [self updateAudioMuteSwitchState];
    [self updateVideoMuteSwitchState];
    [self.tableView reloadData];
    // If the pending input is now the same as the active input,
    // then re-set the active input index back to -1
    // and stop animating the activity indicator view
    if (self.pendingActiveInputIndex == self.projector.activeInputIndex) {
        self.pendingActiveInputIndex = -1;
        [self.activityIndicatorView stopAnimating];
    }
}

@end
