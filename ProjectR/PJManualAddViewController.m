//
//  PJManualAddViewController.m
//  ProjectR
//
//  Created by Eric Hyche on 8/4/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJManualAddViewController.h"
#import "PJInterfaceInfo.h"
#import "PJProjector.h"
#import <PJLinkCocoa/AFPJLinkClient.h>
#import <PJLinkCocoa/PJURLProtocolRunLoop.h>
#import "PJLinkAddProjectorDelegate.h"

CGFloat const kPJManualAddViewControllerDetectionTimeout = 5.0;

@interface PJManualAddViewController ()

@property (weak, nonatomic) IBOutlet UITextField*     firstIP4TextField;
@property (weak, nonatomic) IBOutlet UITextField*     secondIP4TextField;
@property (weak, nonatomic) IBOutlet UITextField*     thirdIP4TextField;
@property (weak, nonatomic) IBOutlet UITextField*     fourthIP4TextField;
@property (weak, nonatomic) IBOutlet UITextField*     portTextField;
@property (weak, nonatomic) IBOutlet UIBarButtonItem* rightBarButtonItem;
@property (strong,nonatomic) PJProjector*             detectedProjector;
@property (strong,nonatomic) AFPJLinkClient*          pjlinkClient;
@property (assign,nonatomic) BOOL                     detectedIPAddress;
@property (weak, nonatomic) IBOutlet UIView*          detectionWaitingView;
@end

@implementation PJManualAddViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Get our IP address
    PJInterfaceInfo* info = [[PJInterfaceInfo alloc] init];
    NSString* ourHostAddress = info.host;
    // Split it into the 4 IP4 fields
    NSArray* ip4Components = [ourHostAddress componentsSeparatedByString:@"."];
    // There should be 4 of these
    if ([ip4Components count] == 4) {
        self.firstIP4TextField.text = [ip4Components objectAtIndex:0];
        self.secondIP4TextField.text = [ip4Components objectAtIndex:1];
        self.thirdIP4TextField.text = [ip4Components objectAtIndex:2];
        self.fourthIP4TextField.text = @"0";
        self.detectedIPAddress = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.detectedIPAddress) {
        [self.fourthIP4TextField becomeFirstResponder];
    } else {
        [self.firstIP4TextField becomeFirstResponder];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)addButtonTapped:(id)sender {
    // Dismiss the keyboard
    [self dismissKeyboard];
    // Detect the projector
    [self detectProjector];
}

- (IBAction)cancelButtonTapped:(id)sender {
    [self dismissKeyboard];
    [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)detectProjectorWithHost:(NSString*)host
                           port:(NSInteger)port
                        success:(void (^)(PJProjector* projector)) success
                        failure:(void (^)(NSError* error)) failure {
    // Create a PJLink client
    NSURL* baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"pjlink://%@:%d/", host, port]];
    self.pjlinkClient = [[AFPJLinkClient alloc] initWithBaseURL:baseURL];
    // Show the loading view
    [self showLoadingView];
    // Try a PJLink client call just to obtain the projector name
    [self.pjlinkClient makeRequestWithBody:@"NAME ?\r"
                                   timeout:kPJManualAddViewControllerDetectionTimeout
                                   success:^(AFPJLinkRequestOperation* operation, NSString* responseBody, NSArray* parsedResponses) {
                                       // Hide the loading view
                                       [self hideLoadingView];
                                       // We succeeded, so create a PJProjector with this host and port
                                       PJProjector* projector = [[PJProjector alloc] initWithHost:host port:port];
                                       // Pass this back to the block if we have one
                                       if (success) {
                                           success(projector);
                                       }
                                   }
                                   failure:^(AFPJLinkRequestOperation* operation, NSError* error) {
                                       // Hide the loading view
                                       [self hideLoadingView];
                                       // We may have failed due to a password error. If so,
                                       // then we still consider this success, since we were able
                                       // to detect a projector at this address.
                                       if ([error.domain isEqualToString:PJLinkErrorDomain] &&
                                           error.code == PJLinkErrorNoPasswordProvided) {
                                           // We succeeded, so create a PJProjector with this host and port
                                           PJProjector* projector = [[PJProjector alloc] initWithHost:host port:port];
                                           // Pass this back to the block if we have one
                                           if (success) {
                                               success(projector);
                                           }
                                       } else {
                                           if (failure) {
                                               failure(error);
                                           }
                                       }
                                   }];
}

- (void)showLoadingView {
    self.detectionWaitingView.frame = self.navigationController.view.bounds;
    [self.navigationController.view addSubview:self.detectionWaitingView];
}

- (void)hideLoadingView {
    [self.detectionWaitingView removeFromSuperview];
}

- (void)dismissKeyboard {
    if ([self.firstIP4TextField isFirstResponder]) {
        [self.firstIP4TextField resignFirstResponder];
    }
    if ([self.secondIP4TextField isFirstResponder]) {
        [self.secondIP4TextField resignFirstResponder];
    }
    if ([self.thirdIP4TextField isFirstResponder]) {
        [self.thirdIP4TextField resignFirstResponder];
    }
    if ([self.fourthIP4TextField isFirstResponder]) {
        [self.fourthIP4TextField resignFirstResponder];
    }
    if ([self.portTextField isFirstResponder]) {
        [self.portTextField resignFirstResponder];
    }
}

- (void)detectProjector {
    // Validate the IP4 fields
    NSInteger firstFieldInteger  = [self.firstIP4TextField.text integerValue];
    NSInteger secondFieldInteger = [self.secondIP4TextField.text integerValue];
    NSInteger thirdFieldInteger  = [self.thirdIP4TextField.text integerValue];
    NSInteger fourthFieldInteger = [self.fourthIP4TextField.text integerValue];
    if (firstFieldInteger  >= 0 && firstFieldInteger  <= 255 &&
        secondFieldInteger >= 0 && secondFieldInteger <= 255 &&
        thirdFieldInteger  >= 0 && thirdFieldInteger  <= 255 &&
        fourthFieldInteger >= 0 && fourthFieldInteger <= 255) {
        // Validate the port
        NSInteger portFieldInteger   = [self.portTextField.text integerValue];
        if (portFieldInteger > 1024 && portFieldInteger <= 32767) {
            // Construct the address from the four fields
            NSString* hostAddress = [NSString stringWithFormat:@"%d.%d.%d.%d", firstFieldInteger, secondFieldInteger, thirdFieldInteger, fourthFieldInteger];
            // Detect the projector
            [self detectProjectorWithHost:hostAddress
                                     port:portFieldInteger
                                  success:^(PJProjector* projector) {
                                      // We detected the projector successfully, so save it.
                                      self.detectedProjector = projector;
                                      // Go ahead and refresh the projector
                                      [projector refreshAllQueries];
                                      // Construct the message
                                      NSString* message = [NSString stringWithFormat:@"Projector detected at %@:%d. Tap Add to add the projector.",
                                                           hostAddress, portFieldInteger];
                                      // Pop up the alert view saying we detected the projector
                                      UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Projector Detected"
                                                                                          message:message
                                                                                         delegate:self
                                                                                cancelButtonTitle:@"Cancel"
                                                                                otherButtonTitles:@"Add", nil];
                                      [alertView show];
                                  }
                                  failure:^(NSError* error) {
                                      // Construct the message
                                      NSString* message = [NSString stringWithFormat:@"No projector detected at %@:%d. Re-enter the IP address and port.",
                                                           hostAddress, portFieldInteger];
                                      // Pop up the alert view saying we detected the projector
                                      UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"No Projector Detected"
                                                                                          message:message
                                                                                         delegate:nil
                                                                                cancelButtonTitle:@"Dismiss"
                                                                                otherButtonTitles:nil];
                                      [alertView show];
                                  }];
        } else {
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Port Error"
                                                                message:@"Port must be between 1025 and 32767 inclusive. Please re-enter."
                                                               delegate:nil
                                                      cancelButtonTitle:@"Dismiss"
                                                      otherButtonTitles:nil];
            [alertView show];
        }
    } else {
        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"IP Address Error"
                                                            message:@"All IP4 address components must be between 0 and 255 inclusive. Please re-enter."
                                                           delegate:nil
                                                  cancelButtonTitle:@"Dismiss"
                                                  otherButtonTitles:nil];
        [alertView show];
    }
}

#pragma mark - UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != alertView.cancelButtonIndex) {
        // If we have a detected projector, then call back to the delegate with it
        if (self.detectedProjector != nil) {
            [self.delegate pjlinkProjectorsWereAdded:@[self.detectedProjector]];
        }
        // Dismiss ourself
        [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
