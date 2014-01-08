//
//  PJProjectorManager.h
//  ProjectR
//
//  Created by Eric Hyche on 7/14/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const PJProjectorManagerProjectorsDidChangeNotification;

@class PJProjector;

@interface PJProjectorManager : NSObject

@property(nonatomic,readonly,copy) NSArray* projectors;

+ (PJProjectorManager*)sharedManager;

// Add an array of PJProjector's
- (void)addProjectors:(NSArray*)projectors;
// Remove an array of PJProjector's
- (void)removeProjectors:(NSArray*)projectors;

// Look up a projector by its host name
- (PJProjector*)projectorForHost:(NSString*)host;

// KVO-compliant accessors for the .projectors property
- (NSUInteger)countOfProjectors;
- (id)objectInProjectorsAtIndex:(NSUInteger)index;
- (NSArray*)projectorsAtIndexes:(NSIndexSet *)indexes;

@end
