//
//  PJProjectorTableViewCell.m
//  ProjectR
//
//  Created by Eric Hyche on 5/19/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJProjectorTableViewCell.h"
#import "PJProjector.h"
#import "PJProjectorManager.h"
#import "PJProjectorInputPowerStatusView.h"
#import "PJProjectorTableViewCellDelegate.h"

static NSString* const kPJProjectorTableViewCellReuseID = @"kPJProjectorTableViewCellReuseID";

NSTimeInterval const kPJProjectorTableViewCellAnimationDuration =  2.0;
CGFloat        const kPJProjectorTableViewCellHeight            = 88.0;

@interface PJProjectorTableViewCell()

@property(nonatomic,strong) UIImage*                  imageDisconnected;
@property(nonatomic,strong) UIImage*                  imageConnected;
@property(nonatomic,strong) UIImage*                  imageConnecting;
@property(nonatomic,strong) PJProjectorInputPowerStatusView* projectorAccessoryView;

@end

@implementation PJProjectorTableViewCell

+ (NSString*)reuseID {
    return kPJProjectorTableViewCellReuseID;
}

+ (CGFloat)heightForProjector:(PJProjector*)projector containerWidth:(CGFloat)width {
    return kPJProjectorTableViewCellHeight;
}

- (id)init {
    return [self initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[PJProjectorTableViewCell reuseID]];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.numberOfLines = 0;
        self.imageConnected    = [UIImage imageNamed:@"projector_connected"];
        self.imageDisconnected = [UIImage imageNamed:@"projector_disconnected"];
        self.imageConnecting   = [UIImage animatedImageNamed:@"projector_connecting" duration:kPJProjectorTableViewCellAnimationDuration];
        self.projectorAccessoryView = [[PJProjectorInputPowerStatusView alloc] init];
        [self.projectorAccessoryView.inputButton addTarget:self
                                                    action:@selector(buttonWasTapped:)
                                          forControlEvents:UIControlEventTouchUpInside];
        [self.projectorAccessoryView.powerStatusSwitch addTarget:self
                                                          action:@selector(switchValueDidChange:)
                                                forControlEvents:UIControlEventValueChanged];
    }

    return self;
}

- (void)setProjector:(PJProjector *)projector {
    _projector = projector;
    [self dataDidChange];
}

#pragma mark - PJProjectorTableViewCell private methods

- (void)dataDidChange {
    [self updateConnectionImage];
    [self updateProjectorDisplayName];
    [self updateAccessoryView];
}

- (void)updateConnectionImage {
    UIImage* image = nil;
    switch (self.projector.connectionState) {
        case PJConnectionStateConnected:
            image = self.imageConnected;
            break;
        case PJConnectionStateConnecting:
            image = self.imageConnecting;
            break;
        case PJConnectionStateConnectionError:
            image = self.imageDisconnected;
            break;
        case PJConnectionStateDiscovered:
            image = self.imageDisconnected;
            break;
        case PJConnectionStatePasswordError:
            image = self.imageDisconnected;
            break;
        default:
            image = self.imageDisconnected;
            break;
    }
    if (image != nil) {
        self.imageView.image = image;
    }
}

- (void)updateProjectorDisplayName {
    self.textLabel.text = [PJProjectorManager displayNameForProjector:self.projector];
}

- (void)updateAccessoryView {
    self.projectorAccessoryView.projector = self.projector;
    [self.projectorAccessoryView sizeToFit];
    self.accessoryView = self.projectorAccessoryView;
}

- (void)switchValueDidChange:(id)sender {
    [self.delegate projectorCell:self switchValueChangedTo:self.projectorAccessoryView.powerStatusSwitch.isOn];
}

- (void)buttonWasTapped:(id)sender {
    [self.delegate projectorCellInputButtonWasSelected:self];
}

@end
