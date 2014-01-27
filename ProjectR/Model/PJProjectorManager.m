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

NSString* const kPJProjectorManagerKeyProjectors = @"projectors";

@interface PJProjectorAlertView : UIAlertView

@property(nonatomic,copy) NSString* host;

@end

@implementation PJProjectorAlertView

@end

@interface PJProjectorManager() <UIAlertViewDelegate>

@property(nonatomic,strong) NSMutableArray*      mutableProjectors;
@property(nonatomic,strong) NSMutableDictionary* hostToProjectorMap;

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

- (id)init {
    self = [super init];
    if (self) {
        // Create the mutable array of projectors
        self.mutableProjectors = [NSMutableArray array];
        // Create the map from IP address to PJProjector
        self.hostToProjectorMap = [NSMutableDictionary dictionary];
    }

    return self;
}

- (NSArray*)projectors {
    return [NSArray arrayWithArray:self.mutableProjectors];
}

- (BOOL)addProjectorsToManager:(NSArray *)projectors {
    BOOL ret = NO;

    NSUInteger projectorsCount = [projectors count];
    if (projectorsCount > 0) {
        NSMutableArray* tmp = [NSMutableArray arrayWithCapacity:projectorsCount];
        for (PJProjector* projector in projectors) {
            // See if I can look up the projector
            PJProjector* projectorInMap = [self projectorForHost:projector.host];
            if (projectorInMap == nil) {
                // This projector is not already present, so add it.
                [tmp addObject:projector];
            }
        }
        // Get the count of projectors we will add
        NSUInteger tmpCount = [tmp count];
        // Did we add any projectors?
        if (tmpCount > 0) {
            // Set the return value
            ret = YES;
            // Get the current number of projectors
            NSUInteger currentCount = [self countOfProjectors];
            // Construct the insertion index set
            NSIndexSet* insertionIndexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(currentCount, tmpCount)];
            // Issue the willChange notification
            [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:insertionIndexSet forKey:kPJProjectorManagerKeyProjectors];
            // Iterate through each projector we will add
            [tmp enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                PJProjector* addedProjector = (PJProjector*)obj;
                // Add it to the mutable array
                [self.mutableProjectors addObject:addedProjector];
                // Add it to the map
                [self.hostToProjectorMap setObject:addedProjector forKey:addedProjector.host];
                // Subscribe to notifications for this projector
                [self subscribeToNotificationsForProjector:addedProjector];
                // Tell the projector to refresh itself
                [addedProjector refreshAllQueries];
                // Turn on the refresh timer
                addedProjector.refreshTimerOn = YES;
            }];
            // Issue the didChange notification
            [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:insertionIndexSet forKey:kPJProjectorManagerKeyProjectors];
        }
    }

    return ret;
}

- (void)removeProjectorsFromManager:(NSArray*)projectors {
    // Get the count to remove
    NSUInteger projectorsCount = [projectors count];
    if (projectorsCount > 0) {
        // Construct the index set of the projectors we will remove
        NSMutableIndexSet* mutableIndexSet = [NSMutableIndexSet indexSet];
        for (PJProjector* projector in projectors) {
            // Get the index of this projector
            NSInteger projectorIndex = [self indexOfProjectorForHost:projector.host];
            if (projectorIndex != NSNotFound) {
                [mutableIndexSet addIndex:projectorIndex];
            }
        }
        // Are we actually removing any projectors
        if ([mutableIndexSet count] > 0) {
            // Issue the willChange notification
            [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:mutableIndexSet forKey:kPJProjectorManagerKeyProjectors];
            // Iterate through the indexes
            [mutableIndexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                // Look up this projector
                PJProjector* projectorToRemove = (PJProjector*) [self objectInProjectorsAtIndex:idx];
                // Unsubscribe to notifications for this projector
                [self unsubscribeToNotificationsForProjector:projectorToRemove];
                // Remove it from the map
                [self.hostToProjectorMap removeObjectForKey:projectorToRemove.host];
            }];
            // Remove the projectors from the mutable array
            [self.mutableProjectors removeObjectsAtIndexes:mutableIndexSet];
            // Issue the didChange notification
            [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:mutableIndexSet forKey:kPJProjectorManagerKeyProjectors];
        }
    }
}

- (PJProjector*)projectorForHost:(NSString*)host {
    PJProjector* ret = nil;

    if ([host length] > 0) {
        ret = [self.hostToProjectorMap objectForKey:host];
    }

    return ret;
}

- (NSInteger)indexOfProjectorForHost:(NSString*)host {
    NSInteger ret = NSNotFound;

    if ([host length] > 0) {
        NSUInteger projectorCount = [self countOfProjectors];
        for (NSUInteger i = 0; i < projectorCount; i++) {
            PJProjector* projector = (PJProjector*)[self objectInProjectorsAtIndex:i];
            if ([host isEqualToString:projector.host]) {
                ret = i;
                break;
            }
        }
    }

    return ret;
}

- (NSUInteger)countOfProjectors {
    return [self.mutableProjectors count];
}

- (id)objectInProjectorsAtIndex:(NSUInteger)index {
    return [self.mutableProjectors objectAtIndex:index];
}

- (NSArray*)projectorsAtIndexes:(NSIndexSet *)indexes {
    return [self.mutableProjectors objectsAtIndexes:indexes];
}

+ (NSString*)displayNameForProjector:(PJProjector*)projector {
    NSString* ret = projector.projectorName;
    if ([ret length] == 0) {
        ret = projector.host;
    }
    return ret;
}

#pragma mark - UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != alertView.cancelButtonIndex) {
        if ([alertView isKindOfClass:[PJProjectorAlertView class]]) {
            PJProjectorAlertView* projectorAlertView = (PJProjectorAlertView*)alertView;
            // Get the projector associated with this host
            PJProjector* projector = [self projectorForHost:projectorAlertView.host];
            // Switch depending upon the connection state
            if (projector.connectionState == PJConnectionStatePasswordError) {
                // Get the password
                NSString* password = [[alertView textFieldAtIndex:0] text];
                if ([password length] > 0) {
                    // A non-zero length password was supplied. So set this password into the
                    // PJProjector and have it try again.
                    projector.password = password;
                    // Try again to refresh
                    [projector refreshAllQueries];
                }
            } else if (projector.connectionState == PJConnectionStateConnectionError) {
                // The user could have chosen to retry or delete the projector.
                // Get the index of first "other" button.
                NSInteger firstOtherButtonIndex = alertView.firstOtherButtonIndex;
                if (buttonIndex == firstOtherButtonIndex) {
                    // The user chose to retry, so refresh the projector
                    [projector refreshAllQueries];
                } else {
                    // The user chose to delete the projector, so remove it
                    [self removeProjectorsFromManager:@[projector]];
                }
            }
        }
    }
}

#pragma mark - PJProjectorManager private methods

- (void)subscribeToNotificationsForProjector:(PJProjector*)projector {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(projectorDidChange:)
                               name:PJProjectorDidChangeNotification
                             object:projector];
    [notificationCenter addObserver:self
                           selector:@selector(projectorConnectionStateDidChange:)
                               name:PJProjectorConnectionStateDidChangeNotification
                             object:projector];
}

- (void)unsubscribeToNotificationsForProjector:(PJProjector*)projector {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self
                                  name:PJProjectorDidChangeNotification
                                object:projector];
    [notificationCenter removeObserver:self
                                  name:PJProjectorConnectionStateDidChangeNotification
                                object:projector];
}

- (void)unsubscribeToNotificationsForAllProjectors {
    if ([self.mutableProjectors count] > 0) {
        for (PJProjector* projector in self.mutableProjectors) {
            [self unsubscribeToNotificationsForProjector:projector];
        }
    }
}

- (void)projectorDidChange:(NSNotification*)notification {
    // Get the projector that issued this notification
    PJProjector* projector = (PJProjector*) [notification object];
    // Get the index of this projector
    NSInteger projectorIndex = [self indexOfProjectorForHost:projector.host];
    if (projectorIndex != NSNotFound) {
        // Get the index set for just this projector
        NSIndexSet* changedIndexSet = [NSIndexSet indexSetWithIndex:projectorIndex];
        // Issue the willChange notification
        [self willChange:NSKeyValueChangeReplacement valuesAtIndexes:changedIndexSet forKey:kPJProjectorManagerKeyProjectors];
        // Issue the didChange notification
        [self didChange:NSKeyValueChangeReplacement valuesAtIndexes:changedIndexSet forKey:kPJProjectorManagerKeyProjectors];
    }
}

- (void)projectorConnectionStateDidChange:(NSNotification*)notification {
    PJProjector* projector = [notification object];
    // If we encountered a no password error, then we need to pop up
    // a UIAlertView to ask the user for a password. If this is a general
    // connection error, then we just pop up a UIAlertView to inform
    // the user that there was a connection problem.
    if (projector.connectionState == PJConnectionStatePasswordError) {
        // Construct the message
        NSString* message = [NSString stringWithFormat:@"The projector at %@ requires a password. Please enter it below", projector.host];
        PJProjectorAlertView* alertView = [[PJProjectorAlertView alloc] initWithTitle:@"Password Needed"
                                                                              message:message
                                                                             delegate:self
                                                                    cancelButtonTitle:@"Cancel"
                                                                    otherButtonTitles:@"Submit", nil];
        // Save the host with the alert view
        alertView.host = projector.host;
        // Set the style so that the UIAlertView provides a field for the password
        alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
        // Show the alert view
        [alertView show];
    } else if (projector.connectionState == PJConnectionStateConnectionError) {
        // Construct the message
        NSString* message = [NSString stringWithFormat:@"A network error encountered while trying to reach projector at %@.", projector.host];
        PJProjectorAlertView* alertView = [[PJProjectorAlertView alloc] initWithTitle:@"Error"
                                                                              message:message
                                                                             delegate:self
                                                                    cancelButtonTitle:@"Dimiss"
                                                                    otherButtonTitles:@"Retry", @"Delete", nil];
        // Save the host with the alert view
        alertView.host = projector.host;
        // Show the alert view
        [alertView show];
    }
}

@end
