//
//  PJProjectorManager.h
//  ProjectR
//
//  Created by Eric Hyche on 7/14/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* const PJProjectorManagerProjectorsDidChangeNotification;

@interface PJProjectorManager : NSObject

+ (PJProjectorManager*)sharedManager;

- (NSArray*)projectors;

- (NSUInteger)countOfProjectors;
- (id)objectInProjectorsAtIndex:(NSUInteger)index;
- (NSArray*)projectorsAtIndexes:(NSIndexSet *)indexes;

@end
