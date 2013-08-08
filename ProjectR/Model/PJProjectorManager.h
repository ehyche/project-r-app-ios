//
//  PJProjectorManager.h
//  ProjectR
//
//  Created by Eric Hyche on 7/14/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* const PJProjectorManagerProjectorsDidChangeNotification;

@class PJProjector;

@interface PJProjectorManager : NSObject

@property(nonatomic,copy) NSArray* projectors;

+ (PJProjectorManager*)sharedManager;

- (void)addProjectors:(NSArray*)projectors;
- (void)removeProjectors:(NSArray*)projectors;

- (PJProjector*)projectorForHost:(NSString*)host;

- (NSUInteger)countOfProjectors;
- (id)objectInProjectorsAtIndex:(NSUInteger)index;
- (NSArray*)projectorsAtIndexes:(NSIndexSet *)indexes;

@end
