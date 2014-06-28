//
//  PJManualAddTableViewController.m
//  ProjectR
//
//  Created by Eric Hyche on 1/4/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJManualAddTableViewController.h"
#import "PJInterfaceInfo.h"
#import "PJDefinitions.h"
#import "PJProjector.h"
#import "AFPJLinkClient.h"
#import "PJURLProtocolRunLoop.h"
#import "PJProjectorManager.h"
#import "UIImage+SolidColor.h"
#import "TestFlight.h"

NSInteger const kPJManualAddIPPickerFontSize     =  17.0;
CGFloat   const kPJManualAddPickerComponentWidth =  50.0;
CGFloat   const kPJmanualAddPickerRowHeight      =  30.0;
CGFloat   const kPJManualAddRowHeightDefault     =  44.0;
CGFloat   const kPJManualAddRowHeightPicker      = 200.0;
CGFloat   const kPJManualAddDetectionTimeout     =   5.0;
NSInteger const kPJManualAddAlertTagSubnet       =  10;
NSInteger const kPJManualAddAlertTagPort         =  20;
NSInteger const kPJManualAddAlertTagNoDetect     =  40;
NSInteger const kPJManualAddAlertTagPostAdd      =  50;
CGFloat   const kPJManualAddButtonHeight         =  64.0;

@interface PJManualAddTableViewController () <UIPickerViewDataSource,
                                              UIPickerViewDelegate,
                                              UITextFieldDelegate,
                                              UIAlertViewDelegate>

@property(nonatomic,strong) UIPickerView*            ipAddressPickerView;
@property(nonatomic,strong) UITextField*             portTextField;
@property(nonatomic,copy)   NSString*                projectorHost;
@property(nonatomic,copy)   NSString*                deviceHost;
@property(nonatomic,copy)   NSString*                deviceNetMask;
@property(nonatomic,assign) BOOL                     showIPAddressPickerCell;
@property(nonatomic,strong) UIColor*                 hostColorNormal;
@property(nonatomic,strong) UIColor*                 hostColorWhenPickerDisplayed;
@property(nonatomic,strong) AFPJLinkClient*          pjlinkClient;
@property(nonatomic,strong) UIActivityIndicatorView* spinner;
@property(nonatomic,strong) UIBarButtonItem*         spinnerBarButtonItem;
@property(nonatomic,strong) UIButton*                addButton;

@end

@implementation PJManualAddTableViewController

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
        // Now compute the initial value for the projector host
        self.projectorHost = [self initialProjectorPortForDeviceHostAddress:self.deviceHost];
        // Configure the IP address picker view
        self.ipAddressPickerView = [[UIPickerView alloc] init];
        self.ipAddressPickerView.delegate   = self;
        self.ipAddressPickerView.dataSource = self;
        // Configure the host address colors
        self.hostColorNormal              = [UIColor colorWithRed:0.556863 green:0.556863 blue:0.576471 alpha:1.0];
        self.hostColorWhenPickerDisplayed = [UIColor redColor];
        // Set up the port address text field
        self.portTextField = [[UITextField alloc] init];
        self.portTextField.keyboardType  = UIKeyboardTypeNumberPad;
        self.portTextField.textAlignment = NSTextAlignmentRight;
        self.portTextField.textColor     = self.hostColorNormal;
        // We initially set the width to accomodate 5 digits
        self.portTextField.text = @"00000";
        self.portTextField.font = [UIFont fontWithName:@"Helvetica Neue" size:kPJManualAddIPPickerFontSize];
        [self.portTextField sizeToFit];
        // Now set it to be the default PJLink port
        self.portTextField.text = [[NSNumber numberWithInteger:kDefaultPJLinkPort] stringValue];
        // Create the spinner
        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [self.spinner sizeToFit];
        // Create the bar button item out of the spinner
        self.spinnerBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.spinner];
        // Set up the title
        self.navigationItem.title = @"Manual Add";
        // Put the add button up initially
        [self showHideActivityIndicator:NO];
        // Create the add button
        self.addButton = [UIButton buttonWithType:UIButtonTypeCustom];
        CGSize imageSize = CGSizeMake(8.0, 8.0);
        [self.addButton setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0] size:imageSize] forState:UIControlStateNormal];
        [self.addButton setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithRed:0.0 green:0.6 blue:0.0 alpha:1.0] size:imageSize] forState:UIControlStateHighlighted];
        [self.addButton setTitle:@"Add Projector" forState:UIControlStateNormal];
        [self.addButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self.addButton addTarget:self action:@selector(addButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonTapped:)];

    self.addButton.frame = CGRectMake(0.0, 0.0, self.tableView.frame.size.width, kPJManualAddButtonHeight);
    self.tableView.tableFooterView = self.addButton;
    [TestFlight passCheckpoint:@"PageView:ManualAdd"];
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
        ret = 2;
        if (self.showIPAddressPickerCell) {
            ret += 1;
        }
    } else if (section == 1) {
        ret = 2;
    }

    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* reuseIDValue1  = @"PJManualAddCellValue1";
    static NSString* reuseIDDefault = @"PJManualAddCellDefault";
    static NSString* reuseIDPicker  = @"PJManualAddCellPicker";

    // Determine which reuse ID to use
    NSString*            cellReuseID = nil;
    UITableViewCellStyle cellStyle   = UITableViewCellStyleDefault;
    if (indexPath.section == 0) {
        if (self.showIPAddressPickerCell) {
            if (indexPath.row == 0) {
                cellReuseID = reuseIDValue1;
                cellStyle   = UITableViewCellStyleValue1;
            } else if (indexPath.row == 1) {
                cellReuseID = reuseIDPicker;
                cellStyle   = UITableViewCellStyleDefault;
            } else if (indexPath.row == 2) {
                cellReuseID = reuseIDDefault;
                cellStyle   = UITableViewCellStyleDefault;
            }
        } else {
            if (indexPath.row == 0) {
                cellReuseID = reuseIDValue1;
                cellStyle   = UITableViewCellStyleValue1;
            } else if (indexPath.row == 1) {
                cellReuseID = reuseIDDefault;
                cellStyle   = UITableViewCellStyleDefault;
            }
        }
    } else if (indexPath.section == 1) {
        cellReuseID = reuseIDValue1;
        cellStyle   = UITableViewCellStyleValue1;
    }

    // De-queue or create the cell
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellReuseID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:cellStyle reuseIdentifier:cellReuseID];
    }

    // Configure the cell defaults
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    // Configure the cell
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text       = @"Host";
            cell.detailTextLabel.text = self.projectorHost;
            cell.detailTextLabel.textColor = (self.showIPAddressPickerCell ? self.hostColorWhenPickerDisplayed : self.hostColorNormal);
        } else if (indexPath.row == 1) {
            if (self.showIPAddressPickerCell) {
                self.ipAddressPickerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                self.ipAddressPickerView.frame            = cell.contentView.bounds;
                [cell.contentView addSubview:self.ipAddressPickerView];
            } else {
                cell.textLabel.text = @"Port";
                cell.accessoryView  = self.portTextField;
            }
        } else if (indexPath.row == 2 && self.showIPAddressPickerCell) {
            cell.textLabel.text = @"Port";
            cell.accessoryView  = self.portTextField;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text       = @"IP Address";
            cell.detailTextLabel.text = self.deviceHost;
        } else if (indexPath.row == 1) {
            cell.textLabel.text       = @"NetMask";
            cell.detailTextLabel.text = self.deviceNetMask;
        }
    }

    return cell;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* ret = nil;

    if (section == 0) {
        ret = @"Projector To Add";
    } else if (section == 1) {
        ret = @"iOS Device WiFi Info";
    }

    return ret;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // Dismiss the keyboard if necessary
    [self portTextFieldResignFirstResponderIfNeeded];

    // Is this the host row?
    if (indexPath.section == 0 && indexPath.row == 0) {
        NSIndexPath* hostCellIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        NSIndexPath* pickerCellIndexPath = [NSIndexPath indexPathForRow:1 inSection:0];
        // Are we already showing the IP address picker cell?
        if (self.showIPAddressPickerCell) {
            // We are already showing it, so clear the flag
            self.showIPAddressPickerCell = NO;
            // Remove the picker cell
            [tableView deleteRowsAtIndexPaths:@[pickerCellIndexPath] withRowAnimation:UITableViewRowAnimationTop];
            // Reload the host cell
            [tableView reloadRowsAtIndexPaths:@[hostCellIndexPath] withRowAnimation:UITableViewRowAnimationNone];
        } else {
            // We are not showing it, so set the flag and insert the cell
            self.showIPAddressPickerCell = YES;
            // Set the picker to the current value of the host cell
            [self updatePickerFromHost];
            // Insert the picker cell
            [tableView insertRowsAtIndexPaths:@[pickerCellIndexPath] withRowAnimation:UITableViewRowAnimationTop];
            // Reload the host cell
            [tableView reloadRowsAtIndexPaths:@[hostCellIndexPath] withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat ret = kPJManualAddRowHeightDefault;

    if (indexPath.section == 0 && indexPath.row == 1 && self.showIPAddressPickerCell) {
        ret = kPJManualAddRowHeightPicker;
    }

    return ret;
}

#pragma mark - UIPickerViewDataSource methods

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 4;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 256;
}

#pragma mark - UIPickerViewDelegate methods

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    return kPJManualAddPickerComponentWidth;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    return kPJmanualAddPickerRowHeight;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [[NSNumber numberWithInteger:row] stringValue];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    // Dismiss the keyboard for the port text field if needed
    [self portTextFieldResignFirstResponderIfNeeded];
    // Update the host from the picker
    [self updateHostFromPicker];
    // Re-load the host cell
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != alertView.cancelButtonIndex) {
        if (alertView.tag == kPJManualAddAlertTagSubnet) {
            [self addProjectorToManager];
            [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

#pragma mark - PJManualAddTableViewController private methods

- (NSString*)initialProjectorPortForDeviceHostAddress:(NSString*)deviceHost {
    NSString* ret = [deviceHost copy];

    // Assume this is an IP4 address, so split apart using "." as the delimiter
    NSArray* components = [deviceHost componentsSeparatedByString:@"."];
    if ([components count] == 4) {
        // Use the first 3 components, but use "0" for the last component
        NSArray* newComponents = @[components[0], components[1], components[2], @"0"];
        // Rejoin them with the same "." delimiter
        ret = [newComponents componentsJoinedByString:@"."];
    }

    return ret;
}

- (void)addButtonTapped:(id)sender {
    [self portTextFieldResignFirstResponderIfNeeded];
    // Get the port as an integer
    NSInteger portFieldInteger = [self.portTextField.text integerValue];
    // Validate the port value
    if (portFieldInteger > 1024 && portFieldInteger <= 32767) {
        // Is the host on the same subnet as the projector?
        if ([self isHostOnSameSubnetAsDevice]) {
            // Get the projector IP address
            NSString* projectorIPAddress = self.projectorHost;
            // Detect the projector
            [self detectProjectorWithHost:projectorIPAddress
                                     port:portFieldInteger
                                  success:^{
                                      // We found a projector, so we can add it to the manager
                                      [self addProjectorToManager];
                                      // Now dismiss ourself
                                      [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
                                  }
                                  failure:^(NSError* error) {
                                      // Construct the message
                                      NSString* message = [NSString stringWithFormat:@"No projector detected at %@:%@. Re-enter the IP address and port.",
                                                           projectorIPAddress, @(portFieldInteger)];
                                      // Pop up the alert view saying we detected the projector
                                      UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"No Projector Detected"
                                                                                          message:message
                                                                                         delegate:nil
                                                                                cancelButtonTitle:@"Dismiss"
                                                                                otherButtonTitles:nil];
                                      alertView.tag = kPJManualAddAlertTagNoDetect;
                                      [alertView show];
                                  }];
        } else {
            // Host is not on the same subnet, so ask the user if they really want to add this address
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Projector Address"
                                                                message:@"Projector address is not on the subnet as the device, so it cannot be detected. Add anyway?"
                                                               delegate:self
                                                      cancelButtonTitle:@"Cancel"
                                                      otherButtonTitles:@"Add", nil];
            alertView.tag = kPJManualAddAlertTagSubnet;
            [alertView show];
        }
    } else {
        // Show an alert and ask the user to correct the port
        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Port Error"
                                                            message:@"Port must be between 1025 and 32767 inclusive. Please re-enter."
                                                           delegate:nil
                                                  cancelButtonTitle:@"Dismiss"
                                                  otherButtonTitles:nil];
        alertView.tag = kPJManualAddAlertTagPort;
        [alertView show];
    }
}

- (void)cancelButtonTapped:(id)sender {
    [self portTextFieldResignFirstResponderIfNeeded];
    [self.pjlinkClient.operationQueue cancelAllOperations];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)updatePickerFromHost {
    // Split the host apart
    NSArray* hostComponents = [self.projectorHost componentsSeparatedByString:@"."];
    // Get the number of components
    NSUInteger hostComponentCount = [hostComponents count];
    // There better be 4
    if (hostComponentCount == 4) {
        for (NSUInteger i = 0; i < hostComponentCount; i++) {
            NSString* ithHostComponent = [hostComponents objectAtIndex:i];
            // Get the integer value
            NSInteger ithHostComponentInt = [ithHostComponent integerValue];
            // Make sure it is valid
            if (ithHostComponentInt >= 0 && ithHostComponentInt <= 255) {
                [self.ipAddressPickerView selectRow:ithHostComponentInt inComponent:i animated:NO];
            }
        }
    }
}

- (void)updateHostFromPicker {
    if (self.ipAddressPickerView.numberOfComponents == 4) {
        NSMutableArray* tmp = [NSMutableArray arrayWithCapacity:4];
        for (NSInteger i = 0; i < 4; i++) {
            NSInteger selectedRowForIthComponent = [self.ipAddressPickerView selectedRowInComponent:i];
            if (selectedRowForIthComponent >= 0 && selectedRowForIthComponent <= 255) {
                NSString* selectedRowStr = [[NSNumber numberWithInteger:selectedRowForIthComponent] stringValue];
                [tmp addObject:selectedRowStr];
            }
        }
        // Re-construct the host address
        self.projectorHost = [tmp componentsJoinedByString:@"."];
    }
}

- (void)portTextFieldResignFirstResponderIfNeeded {
    if ([self.portTextField isFirstResponder]) {
        [self.portTextField resignFirstResponder];
    }
}

- (BOOL)isHostOnSameSubnetAsDevice {
    // Get the net mask
    unsigned long netMask = [self numericAddressFromIP4HostAddress:self.deviceNetMask];
    // Get the device address
    unsigned long deviceAddress = [self numericAddressFromIP4HostAddress:self.deviceHost];
    // Get the projector host address
    unsigned long projetorAddress = [self numericAddressFromIP4HostAddress:self.projectorHost];
    // Get the AND of netMask and device address
    unsigned long maskedDeviceAddress = deviceAddress & netMask;
    // Get the AND of netMask and the projector address
    unsigned long maskedProjectorAddress = projetorAddress & netMask;

    // If the projector and device are on the same subnet, then these two values should be the same
    return (maskedDeviceAddress == maskedProjectorAddress);
}

- (unsigned long)numericAddressFromIP4HostAddress:(NSString*)host {
    unsigned long ret = 0;

    // Split the AAA.BBB.CCC.DDD address with the "." delimiter
    NSArray* hostComponents = [host componentsSeparatedByString:@"."];
    // Make sure there are 4 components
    NSUInteger hostComponentsCount = [hostComponents count];
    if (hostComponentsCount == 4) {
        // Iterate through all 4 components
        for (NSUInteger i = 0; i < hostComponentsCount; i++) {
            // Get the i-th host component
            NSString* ithHostComponent = [hostComponents objectAtIndex:i];
            // Convert to an integer
            NSInteger ithHostComponentInt = [ithHostComponent integerValue];
            // Make sure the value is in [0,255] inclusive
            if (ithHostComponentInt >= 0 && ithHostComponentInt <= 255) {
                // Get the component as an unsigned long
                unsigned long ithCompUL = (unsigned long) ithHostComponentInt;
                // Determine the number of bits to shift by
                unsigned long ithShift = (hostComponentsCount - 1 - i) * 8;
                // Shift the component by the number of bits
                unsigned long ithCompShifted = ithCompUL << ithShift;
                // OR the shifted component into the result
                ret |= ithCompShifted;
            }
        }
    }

    return ret;
}

- (void)detectProjectorWithHost:(NSString*)host
                           port:(NSInteger)port
                        success:(void (^)(void)) success
                        failure:(void (^)(NSError* error)) failure {
    // Show activity indicator
    [self showHideActivityIndicator:YES];
    // Create a PJLink client
    NSURL* baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"pjlink://%@:%@/", host, @(port)]];
    self.pjlinkClient = [[AFPJLinkClient alloc] initWithBaseURL:baseURL];
    // Try a PJLink client call just to obtain the projector name
    [self.pjlinkClient makeRequestWithBody:@"NAME ?\r"
                                   timeout:kPJManualAddDetectionTimeout
                                   success:^(AFPJLinkRequestOperation* operation, NSString* responseBody, NSArray* parsedResponses) {
                                       // Hide the activity indicator
                                       [self showHideActivityIndicator:NO];
                                       // Pass this back to the block if we have one
                                       if (success) {
                                           success();
                                       }
                                   }
                                   failure:^(AFPJLinkRequestOperation* operation, NSError* error) {
                                       // Hide the activity indicator
                                       [self showHideActivityIndicator:NO];
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

- (void)showHideActivityIndicator:(BOOL)show {
    if (show) {
        // Start spinning
        [self.spinner startAnimating];
        // Make the right bar button the spinner
        self.navigationItem.rightBarButtonItem = self.spinnerBarButtonItem;
    } else {
        // Stop spinning
        [self.spinner stopAnimating];
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (BOOL)addProjectorToManager {
    // Get the port
    NSInteger portInteger = [self.portTextField.text integerValue];
    // Create a projector
    PJProjector* projector = [[PJProjector alloc] initWithHost:self.projectorHost port:portInteger];
    [TestFlight passCheckpoint:@"Action:AddProjectorManually"];
    // Add the projector to the projector manager
    BOOL added = [[PJProjectorManager sharedManager] addProjectorsToManager:@[projector]];
    
    return added;
}

@end
