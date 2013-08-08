//
//  PJMasterViewController.h
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PJProjectorDetailTableViewController;

@interface PJMasterViewController : UITableViewController

@property(nonatomic,strong) PJProjectorDetailTableViewController* projectorDetailTableViewController;

@end
