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

- (void)addProjectors:(NSArray *)projectors {
    if ([projectors count] > 0) {
        BOOL projectorsAdded = NO;
        for (PJProjector* projector in projectors) {
            // See if I can look up the projector
            PJProjector* projectorInMap = [self projectorForHost:projector.host];
            if (projectorInMap == nil) {
                // Add it to the mutable array
                [self.mutableProjectors addObject:projector];
                // Add it to the map
                [self.hostToProjectorMap setObject:projector forKey:projector.host];
                // Subscribe to notifications for this projector
                [self subscribeToNotificationsForProjector:projector];
                // Tell the projector to refresh itself
                [projector refreshAllQueries];
                // Turn on the refresh timer
                projector.refreshTimerOn = YES;
                // Set the flag saying we added projectors
                projectorsAdded = YES;
            }
        }
        // Did we add any projectors?
        if (projectorsAdded) {
            // Post the notification saying the number of projectors we are managing changed
            [self postProjectorsDidChangeNotification];
        }
    }
}

- (void)removeProjectors:(NSArray*)projectors {
    if ([projectors count] > 0) {
        BOOL projectorsRemoved = NO;
        for (PJProjector* projector in projectors) {
            // See if I can look up the projector
            PJProjector* projectorInMap = [self projectorForHost:projector.host];
            if (projectorInMap != nil) {
                // Unsubscribe to notifications for this projector
                [self unsubscribeToNotificationsForProjector:projectorInMap];
                // Remove it from the map
                [self.hostToProjectorMap removeObjectForKey:projectorInMap.host];
                // Remove it from the mutable array
                [self.mutableProjectors removeObject:projectorInMap];
                // Set the flag saying we removed projectors
                projectorsRemoved = YES;
            }
        }
        // Did we add any projectors?
        if (projectorsRemoved) {
            // Post the notification saying the number of projectors we are managing changed
            [self postProjectorsDidChangeNotification];
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

- (NSUInteger)countOfProjectors {
    return [self.mutableProjectors count];
}

- (id)objectInProjectorsAtIndex:(NSUInteger)index {
    return [self.mutableProjectors objectAtIndex:index];
}

- (NSArray*)projectorsAtIndexes:(NSIndexSet *)indexes {
    return [self.mutableProjectors objectsAtIndexes:indexes];
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
                    [self removeProjectors:@[projector]];
                }
            }
        }
    }
}

#pragma mark - PJProjectorManager private methods

- (void)subscribeToNotificationsForProjector:(PJProjector*)projector {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(projectorConnectionStateDidChange:)
                                                 name:PJProjectorConnectionStateDidChangeNotification
                                               object:projector];
}

- (void)unsubscribeToNotificationsForProjector:(PJProjector*)projector {
    [[NSNotificationCenter defaultCenter] removeObserver:self
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

- (void)postProjectorsDidChangeNotification {
    [self postManagerNotification:[NSNotification notificationWithName:PJProjectorManagerProjectorsDidChangeNotification object:self]];
}

- (void)postManagerNotification:(NSNotification*)notification {
    dispatch_block_t block = ^{
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    };
    // Ensure this is posted on the main thread
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@end
