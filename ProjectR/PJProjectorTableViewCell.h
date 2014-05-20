//
//  PJProjectorTableViewCell.h
//  ProjectR
//
//  Created by Eric Hyche on 5/19/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PJProjector;

@interface PJProjectorTableViewCell : UITableViewCell

@property(nonatomic,strong) PJProjector *projector;

+ (NSString*)reuseID;
+ (CGFloat)heightForProjector:(PJProjector*)projector containerWidth:(CGFloat)width;

@end
