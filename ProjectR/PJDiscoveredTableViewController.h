//
//  PJDiscoveredTableViewController.h
//  ProjectR
//
//  Created by Eric Hyche on 8/3/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PJDiscoveredTableViewController;

@protocol PJDiscoveredTableViewControllerDelegate <NSObject>

@required
- (void)discoveryControllerDidDiscoverProjectors:(NSArray*)projectors; // NSArray of PJProjector's

@end

@interface PJDiscoveredTableViewController : UITableViewController

@property(nonatomic,weak) id<PJDiscoveredTableViewControllerDelegate> delegate;

@end
