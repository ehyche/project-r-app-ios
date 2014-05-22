//
//  PJProjectorAccessoryView.m
//  ProjectR
//
//  Created by Eric Hyche on 5/20/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJProjectorAccessoryView.h"
#import "PJProjector.h"
#import "PJInputInfo.h"

CGFloat const kPJProjectorAccessoryViewFontSize               = 16.0;
CGFloat const kPJProjectorAccessoryViewPaddingTop             = 10.0;
CGFloat const kPJProjectorAccessoryViewPaddingBottom          =  5.0;
CGFloat const kPJProjectorAccessoryViewPaddingLeft            =  5.0;
CGFloat const kPJProjectorAccessoryViewPaddingRight           =  5.0;
CGFloat const kPJProjectorAccessoryViewPaddingBetween         =  5.0;
CGFloat const kPJProjectorAccessoryViewButtonPaddingLeftRight =  5.0;

@interface PJProjectorAccessoryView()

@property(nonatomic, readwrite, strong) UISwitch* powerStatusSwitch;
@property(nonatomic, readwrite, strong) UIButton* inputButton;
@property(nonatomic, strong)            UIColor*  normalOnTintColor;
@property(nonatomic, strong)            UIColor*  normalTintColor;

@end

@implementation PJProjectorAccessoryView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.powerStatusSwitch = [[UISwitch alloc] init];
        self.normalOnTintColor = self.powerStatusSwitch.onTintColor;
        [self addSubview:self.powerStatusSwitch];
        self.inputButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.inputButton.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:kPJProjectorAccessoryViewFontSize];
        [self.inputButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self addSubview:self.inputButton];
    }
    return self;
}

- (void)setProjector:(PJProjector *)projector {
    _projector = projector;
    [self dataDidChange];
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize switchSize = [self.powerStatusSwitch sizeThatFits:size];
    CGSize maxInputNameSize = [self maxSizeForInputNamesForProjector:self.projector];
    CGSize buttonSizeThatFits = [self.inputButton sizeThatFits:size];
    CGSize buttonSize = CGSizeMake(maxInputNameSize.width + (2.0 * kPJProjectorAccessoryViewButtonPaddingLeftRight), buttonSizeThatFits.height);
    CGFloat height = kPJProjectorAccessoryViewPaddingTop +
                     switchSize.height +
                     kPJProjectorAccessoryViewPaddingBetween +
                     buttonSize.height +
                     kPJProjectorAccessoryViewPaddingBottom;
    CGFloat switchLabelWidthMax = MAX(switchSize.width, buttonSize.width);
    CGFloat width = kPJProjectorAccessoryViewPaddingLeft + switchLabelWidthMax + kPJProjectorAccessoryViewPaddingRight;

    return CGSizeMake(width, height);
}

- (void)dataDidChange {
    [self updateSwitchFromPowerStatus];
    [self updateButtonFromInput];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    CGSize selfFrameSize = self.frame.size;

    [self.powerStatusSwitch sizeToFit];
    CGSize switchSize = self.powerStatusSwitch.frame.size;
    CGSize maxInputNameSize = [self maxSizeForInputNamesForProjector:self.projector];
    CGSize buttonSizeThatFits = [self.inputButton sizeThatFits:selfFrameSize];
    CGSize buttonSize = CGSizeMake(maxInputNameSize.width + (2.0 * kPJProjectorAccessoryViewButtonPaddingLeftRight), buttonSizeThatFits.height);
    
    CGRect switchFrame = CGRectMake(floorf((selfFrameSize.width - switchSize.width) / 2.0),
                                    kPJProjectorAccessoryViewPaddingTop,
                                    switchSize.width,
                                    switchSize.height);
    self.powerStatusSwitch.frame = switchFrame;

    CGRect buttonFrame = CGRectMake(floor((selfFrameSize.width - buttonSize.width) / 2.0),
                                    switchFrame.origin.y + switchFrame.size.height + kPJProjectorAccessoryViewPaddingBetween,
                                    buttonSize.width,
                                    buttonSize.height);
    self.inputButton.frame = buttonFrame;
}

- (void)updateSwitchFromPowerStatus {
    switch (self.projector.powerStatus) {
        case PJPowerStatusCooling:
            self.powerStatusSwitch.enabled = NO;
            self.powerStatusSwitch.on = NO;
            break;
        case PJPowerStatusLampOn:
            self.powerStatusSwitch.enabled = YES;
            self.powerStatusSwitch.on = YES;
            break;
        case PJPowerStatusStandby:
            self.powerStatusSwitch.enabled = YES;
            self.powerStatusSwitch.on = NO;
            self.powerStatusSwitch.onTintColor = self.normalOnTintColor;
            break;
        case PJPowerStatusWarmUp:
            self.powerStatusSwitch.enabled = NO;
            self.powerStatusSwitch.on = YES;
            self.powerStatusSwitch.onTintColor = [UIColor redColor];
            break;
        default:
            break;
    }
}

- (void)updateButtonFromInput {
    if (self.projector.activeInputIndex < [self.projector countOfInputs]) {
        PJInputInfo* inputInfo = [self.projector objectInInputsAtIndex:self.projector.activeInputIndex];
        NSString* inputName = [inputInfo description];
        [self.inputButton setTitle:inputName forState:UIControlStateNormal];
    }
}

- (CGSize)maxSizeForInputNamesForProjector:(PJProjector *)projector {
    CGSize maxSize = CGSizeZero;

    UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:kPJProjectorAccessoryViewFontSize];
    for (NSUInteger i = 0; i < [projector countOfInputs]; i++) {
        PJInputInfo* inputInfo = [projector objectInInputsAtIndex:i];
        NSString* inputName = [inputInfo description];
        CGSize inputNameSize = [inputName sizeWithFont:font];
        maxSize = CGSizeMake(MAX(inputNameSize.width, maxSize.width),
                             MAX(inputNameSize.height, maxSize.height));
    }

    return maxSize;
}

@end
