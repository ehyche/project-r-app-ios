//
//  PJProjectorAccessoryView.h
//  ProjectR
//
//  Created by Eric Hyche on 5/20/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PJProjector;

@interface PJProjectorAccessoryView : UIView

@property(nonatomic, readonly,  strong) UISwitch*    powerStatusSwitch;
@property(nonatomic, readonly,  strong) UIButton*    inputButton;
@property(nonatomic, readwrite, strong) PJProjector* projector;

@end
