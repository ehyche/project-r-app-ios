//
//  PJProjectorTableViewCellDelegate.h
//  ProjectR
//
//  Created by Eric Hyche on 5/20/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PJProjectorTableViewCell;

@protocol PJProjectorTableViewCellDelegate <NSObject>

@required

- (void)projectorCell:(PJProjectorTableViewCell*)cell switchValueChangedTo:(BOOL)isOn;

- (void)projectorCellInputButtonWasSelected:(PJProjectorTableViewCell*)cell;

@end
