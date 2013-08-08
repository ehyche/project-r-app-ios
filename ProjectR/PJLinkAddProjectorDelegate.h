//
//  PJLinkAddProjectorDelegate.h
//  ProjectR
//
//  Created by Eric Hyche on 8/4/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PJLinkAddProjectorDelegate <NSObject>

@required

- (void)pjlinkProjectorsWereAdded:(NSArray*)projectors;

@end
