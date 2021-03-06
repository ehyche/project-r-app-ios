//
//  PJSubnetScannerProgressView.m
//  ProjectR
//
//  Created by Eric Hyche on 5/11/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJLabeledProgressView.h"

CGFloat const kPJSubnetScannerProgressViewHeight                  = 56.0;
CGFloat const kPJSubnetScannerProgressViewMarginLeftRight         = 10.0;
CGFloat const kPJSubnetScannerProgressViewMarginBottom            = 10.0;
CGFloat const kPJSubnetScannerProgressViewMarginTop               = 20.0;
CGFloat const kPJSubnetScannerProgressViewBetweenLabelAndProgress =  5.0;

@interface PJLabeledProgressView()

@property(nonatomic,strong) UIProgressView* progressView;
@property(nonatomic,strong) UILabel*        label;

@end

@implementation PJLabeledProgressView

- (void)setProgress:(CGFloat)progress {
    if (_progress != progress) {
        _progress = progress;
        [self progressDidChange];
    }
}

- (void)setProgressText:(NSString *)progressText {
    if (![_progressText isEqualToString:progressText]) {
        _progressText = [progressText copy];
        [self progressTextDidChange];
    }
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        [self addSubview:_progressView];
        _label = [[UILabel alloc] init];
        _label.textColor = [UIColor blackColor];
        _label.font = [UIFont fontWithName:@"HelveticaNeue" size:17.0];
        _label.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_label];
    }

    return self;
}

- (CGSize)sizeThatFits:(CGSize)size {
    // Get the height of the progress view
    [self.progressView sizeToFit];
    CGFloat progressViewHeight = self.progressView.frame.size.height;

    // Get the height of the label
    NSString* text = self.label.text;
    if ([text length] == 0) {
        text = @"Scanning";
    }
    CGSize textSize = [text sizeWithAttributes:@{NSFontAttributeName: self.label.font}];
    
    // Compute the overall height of the view
    CGFloat viewHeight = kPJSubnetScannerProgressViewMarginTop +
                         textSize.height +
                         kPJSubnetScannerProgressViewBetweenLabelAndProgress +
                         progressViewHeight +
                         kPJSubnetScannerProgressViewMarginBottom;
    CGSize retSize = CGSizeMake(self.frame.size.width, viewHeight);

    return retSize;
}

- (void)layoutSubviews {
    CGSize selfFrameSize = self.frame.size;

    CGFloat labelProgressWidth = selfFrameSize.width - (2.0 * kPJSubnetScannerProgressViewMarginLeftRight);
    CGSize textSize = [self.label.text sizeWithAttributes:@{NSFontAttributeName: self.label.font}];
    CGRect labelFrame = CGRectMake(kPJSubnetScannerProgressViewMarginLeftRight,
                                   kPJSubnetScannerProgressViewMarginTop,
                                   labelProgressWidth,
                                   textSize.height);
    self.label.frame = labelFrame;

    [self.progressView sizeToFit];
    CGRect progressViewFrame = self.progressView.frame;
    CGFloat progressViewOriginY = labelFrame.origin.y + labelFrame.size.height + kPJSubnetScannerProgressViewBetweenLabelAndProgress;
    progressViewFrame = CGRectMake(kPJSubnetScannerProgressViewMarginLeftRight,
                                   progressViewOriginY,
                                   labelProgressWidth,
                                   progressViewFrame.size.height);
    self.progressView.frame = progressViewFrame;
}

- (void)progressDidChange {
    self.progressView.progress = self.progress;
    [self setNeedsDisplay];
}

- (void)progressTextDidChange {
    self.label.text = self.progressText;
    [self setNeedsLayout];
}

@end
