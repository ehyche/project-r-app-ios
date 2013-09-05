//
//  PJInputSelectTableViewController.h
//  ProjectR
//
//  Created by Eric Hyche on 8/8/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PJInputSelectTableViewController;
@class PJInputInfo;
@class PJProjector;

@protocol PJInputSelectTableViewControllerDelegate <NSObject>

@required
- (void)inputSelectController:(PJInputSelectTableViewController*)controller
               didSelectInput:(PJInputInfo*)input
                 forProjector:(PJProjector*)projector;

@end

@interface PJInputSelectTableViewController : UITableViewController

@property(nonatomic,strong) PJProjector* projector;

@end
