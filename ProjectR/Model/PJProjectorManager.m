//
//  PJProjectorManager.m
//  ProjectR
//
//  Created by Eric Hyche on 7/14/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJProjectorManager.h"
#import "PJAMXBeaconListener.h"
#import "PJAMXBeaconHost.h"
#import "PJProjector.h"

NSString* const PJProjectorManagerProjectorsDidChangeNotification = @"PJProjectorManagerProjectorsDidChangeNotification";

@interface PJProjectorManager()
{
    NSMutableArray* _projectors;
}

@end

@implementation PJProjectorManager

+ (PJProjectorManager*)sharedManager {
    static PJProjectorManager* g_sharedProjectorManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_sharedProjectorManager = [[PJProjectorManager alloc] init];
    });

    return g_sharedProjectorManager;
}

- (void)dealloc {
    [self unsubscribeToNotifications];
}

- (id)init {
    self = [super init];
    if (self) {
        // Create the array of projectors
        _projectors = [NSMutableArray array];
        // Subscribe to notifications
        [self subscribeToNotifications];
    }

    return self;
}

- (NSArray*)projectors {
    return [NSArray arrayWithArray:_projectors];
}

- (NSUInteger)countOfProjectors {
    return [_projectors count];
}

- (id)objectInProjectorsAtIndex:(NSUInteger)index {
    return [_projectors objectAtIndex:index];
}

- (NSArray*)projectorsAtIndexes:(NSIndexSet *)indexes {
    return [_projectors objectsAtIndexes:indexes];
}

#pragma mark - PJProjectorManager private methods

- (void)subscribeToNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(beaconHostsDidChange:)
                                                 name:PJAMXBeaconHostsDidChangeNotification
                                               object:nil];
}

- (void)unsubscribeToNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PJAMXBeaconHostsDidChangeNotification
                                                  object:nil];
}

- (void)beaconHostsDidChange:(NSNotification*)notification {
    [self reconcileBeaconHostsAgainstProjectors];
}

- (void)reconcileBeaconHostsAgainstProjectors {
    // Loop through the AMX beacon hosts in the beacon listeners
    NSArray* hosts = [[PJAMXBeaconListener sharedListener] hosts];
    for (PJAMXBeaconHost* host in hosts) {
        // Check if we already have a projector with this host
        BOOL found = NO;
        for (PJProjector* projector in self.projectors) {
            if ([projector.beaconHost isEqual:host]) {
                found = YES;
                break;
            }
        }
        // If we did not find this beacon host, then create a projector object for it.
        if (!found) {
            PJProjector* projector = [[PJProjector alloc] initWithBeaconHost:host];
            // Add this projector to the array of projectors
            [_projectors addObject:projector];
            // Send the notification
            [[NSNotificationCenter defaultCenter] postNotificationName:PJProjectorManagerProjectorsDidChangeNotification object:self];
        }
    }
}

@end
