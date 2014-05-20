//
//  PJNoProjectorsTableViewCell.m
//  ProjectR
//
//  Created by Eric Hyche on 5/15/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJNoProjectorsTableViewCell.h"

@implementation PJNoProjectorsTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.text = @"No Projectors";
    }
    return self;
}

- (void)layoutSubviews {
    CGSize selfFrameSize = self.frame.size;
    self.contentView.frame = self.bounds;
    
    [self.textLabel sizeToFit];
    CGSize textLabelSize = self.textLabel.frame.size;
    CGRect textLabelFrame = CGRectMake(floorf((selfFrameSize.width - textLabelSize.width) / 2.0),
                                       floorf((selfFrameSize.height - textLabelSize.height) / 2.0),
                                       textLabelSize.width,
                                       textLabelSize.height);
    self.textLabel.frame = textLabelFrame;
}


@end
