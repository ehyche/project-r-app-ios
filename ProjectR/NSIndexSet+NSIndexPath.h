//
//  NSIndexSet+NSIndexPath.h
//  ProjectR
//
//  Created by Eric Hyche on 1/9/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSIndexSet (NSIndexPath)

- (NSArray*) indexPathsForSection:(NSInteger)section;

@end
