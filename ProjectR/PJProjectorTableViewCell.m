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

CGFloat const kPJProjectorTableViewCellHeight                     = 88.0;
CGFloat const kPJProjectorTableViewCellSelectionButtonWidth       = 47.0;
CGFloat const kPJProjectorTableViewCellSelectionAnimationDuration =  0.3;

@interface PJProjectorTableViewCell()

@property(nonatomic,strong) PJProjectorInputPowerStatusView* projectorInputPowerStatusView;
@property(nonatomic,strong) PJProjectorConnectionStateView*  projectorConnectionStateView;
@property(nonatomic,strong) UIButton*                        selectionButton;

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
        // Create the selection button
        self.selectionButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.selectionButton addTarget:self action:@selector(selectionButtonWasTapped:) forControlEvents:UIControlEventTouchUpInside];
        UIImage* normalImage = [UIImage imageNamed:@"blue_circle.png"];
        UIImage* selectedImage = [UIImage imageNamed:@"blue_circle_selected.png"];
        [self.selectionButton setImage:normalImage forState:UIControlStateNormal];
        [self.selectionButton setImage:selectedImage forState:UIControlStateSelected];
        self.selectionButton.frame = CGRectMake(-kPJProjectorTableViewCellSelectionButtonWidth,
                                                0.0,
                                                kPJProjectorTableViewCellSelectionButtonWidth,
                                                kPJProjectorTableViewCellHeight);
        self.selectionButton.hidden = YES;
        [self addSubview:self.selectionButton];
    }

    return self;
}

- (void)setProjector:(PJProjector *)projector {
    _projector = projector;
    [self dataDidChange];
}

- (void)setMultiSelect:(BOOL)multiSelect {
    self.selectionButton.selected = multiSelect;
}

- (BOOL)multiSelect {
    return self.selectionButton.selected;
}

#pragma mark - UITableViewCell methods

- (void)setEditing:(BOOL)editing {
    NSLog(@"setEdting:%u", editing);
    [self setEditing:editing animated:NO];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    NSLog(@"setEdting:%u animated:%u", editing, animated);
    [super setEditing:editing animated:animated];
    CGRect selectionButtonFrameVisible = CGRectMake(0.0,
                                                    0.0,
                                                    kPJProjectorTableViewCellSelectionButtonWidth,
                                                    kPJProjectorTableViewCellHeight);
    CGRect selectionButtonFrameHidden = CGRectMake(-kPJProjectorTableViewCellSelectionButtonWidth,
                                                   0.0,
                                                   kPJProjectorTableViewCellSelectionButtonWidth,
                                                   kPJProjectorTableViewCellHeight);
    if (editing) {
        self.selectionButton.hidden = NO;
        if (animated) {
            self.selectionButton.alpha  = 0.0;
            self.selectionButton.frame  = selectionButtonFrameHidden;
            [UIView animateWithDuration:kPJProjectorTableViewCellSelectionAnimationDuration
                             animations:^{
                self.selectionButton.frame = selectionButtonFrameVisible;
                self.selectionButton.alpha = 1.0;
            }];
        } else {
            self.selectionButton.frame  = selectionButtonFrameVisible;
        }
    } else {
        if (animated) {
            self.selectionButton.hidden = NO;
            self.selectionButton.frame  = selectionButtonFrameVisible;
            self.selectionButton.alpha  = 1.0;
            [UIView animateWithDuration:kPJProjectorTableViewCellSelectionAnimationDuration
                             animations:^{
                                 self.selectionButton.frame = selectionButtonFrameHidden;
                                 self.selectionButton.alpha = 1.0;
                             }
                             completion:^(BOOL finished) {
                                 self.selectionButton.hidden = YES;
                             }];
            
        } else {
            self.selectionButton.frame  = selectionButtonFrameHidden;
            self.selectionButton.hidden = YES;
        }
    }
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

- (void)selectionButtonWasTapped:(id)sender {
    self.selectionButton.selected = !self.selectionButton.isSelected;
    [self.delegate projectorCellMultiSelectionStateChanged:self];
}

@end
