//
//  PJSubnetScannerProgressView.h
//  ProjectR
//
//  Created by Eric Hyche on 5/11/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PJLabeledProgressView : UIView

@property(nonatomic,copy)   NSString* progressText;
@property(nonatomic,assign) CGFloat   progress;

@end
