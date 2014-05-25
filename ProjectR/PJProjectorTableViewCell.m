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
#import "PJProjectorConnectionStateView.h"

static NSString* const kPJProjectorTableViewCellReuseID = @"kPJProjectorTableViewCellReuseID";

CGFloat const kPJProjectorTableViewCellHeight = 88.0;

@interface PJProjectorTableViewCell()

@property(nonatomic,strong) PJProjectorInputPowerStatusView* projectorInputPowerStatusView;
@property(nonatomic,strong) PJProjectorConnectionStateView*  projectorConnectionStateView;

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
        self.projectorInputPowerStatusView = [[PJProjectorInputPowerStatusView alloc] init];
        [self.projectorInputPowerStatusView.inputButton addTarget:self
                                                           action:@selector(buttonWasTapped:)
                                                 forControlEvents:UIControlEventTouchUpInside];
        [self.projectorInputPowerStatusView.powerStatusSwitch addTarget:self
                                                                 action:@selector(switchValueDidChange:)
                                                       forControlEvents:UIControlEventValueChanged];
        self.projectorConnectionStateView = [[PJProjectorConnectionStateView alloc] init];
        [self.projectorConnectionStateView sizeToFit];
    }

    return self;
}

- (void)setProjector:(PJProjector *)projector {
    _projector = projector;
    [self dataDidChange];
}

#pragma mark - PJProjectorTableViewCell private methods

- (void)dataDidChange {
    [self updateProjectorDisplayName];
    [self updateAccessoryView];
}

- (void)updateProjectorDisplayName {
    self.textLabel.text = [PJProjectorManager displayNameForProjector:self.projector];
}

- (void)updateAccessoryView {
    UIView *viewToUse = nil;
    if (self.projector.connectionState == PJConnectionStateConnected) {
        self.projectorInputPowerStatusView.projector = self.projector;
        [self.projectorInputPowerStatusView sizeToFit];
        viewToUse = self.projectorInputPowerStatusView;
    } else {
        self.projectorConnectionStateView.connectionState = self.projector.connectionState;
        viewToUse = self.projectorConnectionStateView;
    }
    self.accessoryView = viewToUse;
}

- (void)switchValueDidChange:(id)sender {
    [self.delegate projectorCell:self switchValueChangedTo:self.projectorInputPowerStatusView.powerStatusSwitch.isOn];
}

- (void)buttonWasTapped:(id)sender {
    [self.delegate projectorCellInputButtonWasSelected:self];
}

@end
