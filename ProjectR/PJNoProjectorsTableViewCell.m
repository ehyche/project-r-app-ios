//
//  PJNoProjectorsTableViewCell.m
//  ProjectR
//
//  Created by Eric Hyche on 5/15/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJNoProjectorsTableViewCell.h"

CGFloat kNoProjectorsCellHeight          = 400.0;
CGFloat kNoProjectorsCellVerticalPadding =  20.0;

@implementation PJNoProjectorsTableViewCell

+ (CGFloat)preferredHeight {
    return kNoProjectorsCellHeight;
}

+ (NSString*)reuseID {
    return NSStringFromClass([self class]);
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.textLabel.text = @"No Projectors";
        self.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:20.0];
        self.detailTextLabel.text = @"Tap the + button to add projectors.";
        self.detailTextLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16.0];
        self.detailTextLabel.numberOfLines = 2;
    }
    return self;
}

- (void)layoutSubviews {
    self.contentView.frame = self.bounds;
    CGSize contentViewSize = self.contentView.frame.size;
    
    CGSize textLabelSize = [self.textLabel.text sizeWithFont:self.textLabel.font];
    CGSize detailTextLabelSize = [self.detailTextLabel.text sizeWithFont:self.detailTextLabel.font
                                                       constrainedToSize:CGSizeMake(contentViewSize.width - 20.0, 2009.0)
                                                           lineBreakMode:NSLineBreakByWordWrapping];
    CGFloat totalHeight = textLabelSize.height + kNoProjectorsCellVerticalPadding + detailTextLabelSize.height;
    
    CGRect textLabelFrame = CGRectMake(floorf((contentViewSize.width - textLabelSize.width) / 2.0),
                                       floorf((contentViewSize.height - totalHeight) / 2.0),
                                       textLabelSize.width,
                                       textLabelSize.height);
    CGRect detailTextLabelFrame = CGRectMake(floorf((contentViewSize.width - detailTextLabelSize.width) / 2.0),
                                             textLabelFrame.origin.y + textLabelFrame.size.height + kNoProjectorsCellVerticalPadding,
                                             detailTextLabelSize.width,
                                             detailTextLabelSize.height);
    self.textLabel.frame = textLabelFrame;
    self.detailTextLabel.frame = detailTextLabelFrame;
}


@end
