//
//  PJProjectorManager.h
//  ProjectR
//
//  Created by Eric Hyche on 7/14/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PJLinkCocoa/PJDefinitions.h>

@class PJProjector;

extern NSString* const kPJProjectorManagerKeyProjectors;

@interface PJProjectorManager : NSObject

@property(nonatomic,readonly,copy) NSArray* projectors;

+ (PJProjectorManager*)sharedManager;

// Add an array of PJProjector's
- (BOOL)addProjectorsToManager:(NSArray*)projectors;
// Remove an array of PJProjector's
- (void)removeProjectorsFromManager:(NSArray*)projectors;
// Start refreshing all projectors
- (void)beginRefreshingAllProjectorsForReason:(PJRefreshReason)reason;

// Look up a projector by its host name
- (PJProjector*)projectorForHost:(NSString*)host;
// Look up the index of a projector by its host name
- (NSInteger)indexOfProjectorForHost:(NSString*)host;

// KVO-compliant accessors for the .projectors property
- (NSUInteger)countOfProjectors;
- (id)objectInProjectorsAtIndex:(NSUInteger)index;
- (NSArray*)projectorsAtIndexes:(NSIndexSet *)indexes;

// Provide a display name for the projector
// XXXMEH - this should get moved to PJProjector
+ (NSString*)displayNameForProjector:(PJProjector*)projector;

// Get the string for the connection state
+ (NSString*)stringForConnectionState:(PJConnectionState)state;

@end
