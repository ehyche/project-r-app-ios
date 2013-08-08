//
//  PJDiscoveredTableViewController.h
//  ProjectR
//
//  Created by Eric Hyche on 8/3/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PJLinkAddProjectorDelegate;

@interface PJDiscoveredTableViewController : UITableViewController

@property(nonatomic,weak) id<PJLinkAddProjectorDelegate> delegate;

@end
