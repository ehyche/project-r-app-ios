//
//  PJProjectorTableViewCell.h
//  ProjectR
//
//  Created by Eric Hyche on 5/19/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PJDefinitions.h"

@class PJProjector;
@protocol PJProjectorTableViewCellDelegate;

@interface PJProjectorTableViewCell : UITableViewCell

@property(nonatomic,strong) PJProjector*                         projector;
@property(nonatomic,weak)   id<PJProjectorTableViewCellDelegate> delegate;

+ (NSString*)reuseID;

+ (CGFloat)heightForProjector:(PJProjector*)projector containerWidth:(CGFloat)width;

@end
