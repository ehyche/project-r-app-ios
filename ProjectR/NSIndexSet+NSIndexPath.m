//
//  NSIndexSet+NSIndexPath.m
//  ProjectR
//
//  Created by Eric Hyche on 1/9/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "NSIndexSet+NSIndexPath.h"

@implementation NSIndexSet (NSIndexPath)

- (NSArray*) indexPathsForSection:(NSInteger)section {
    NSMutableArray* tmp = [NSMutableArray arrayWithCapacity:[self count]];

    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL* stop) {
        [tmp addObject:[NSIndexPath indexPathForRow:idx inSection:section]];
    }];

    return [NSArray arrayWithArray:tmp];
}

@end
