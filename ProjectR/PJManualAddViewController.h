//
//  PJManualAddViewController.h
//  ProjectR
//
//  Created by Eric Hyche on 8/4/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PJLinkAddProjectorDelegate;

@interface PJManualAddViewController : UIViewController

@property(nonatomic,weak) id<PJLinkAddProjectorDelegate> delegate;

@end
