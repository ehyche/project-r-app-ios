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

NSString* const kPJProjectorManagerKeyProjectors   = @"projectors";
NSString* const kPJProjectorManagerArchiveFileName = @"ProjectorManager.archive";

@interface PJProjectorManager()

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

- (void)dealloc {
    [self unsubscribeFromApplicationNotifications];
    [self unsubscribeToNotificationsForAllProjectors];
}

- (id)init {
    self = [super init];
    if (self) {
        // Create the mutable array of projectors
        self.mutableProjectors = [NSMutableArray array];
        // Create the map from IP address to PJProjector
        self.hostToProjectorMap = [NSMutableDictionary dictionary];
        // Subscribe to application notifications
        [self subscribeToApplicationNotifications];
        // Try loading the projectors from archive
        BOOL success = [self unarchiveProjectors];
        if (success) {
            // Subscribe to notifications for these projectors
            [self subscribeToNotificationsForAllProjectors];
        }
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
            }];
            // Issue the didChange notification
            [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:insertionIndexSet forKey:kPJProjectorManagerKeyProjectors];
            // We need to update the archive
            [self archiveProjectors];
            // Begin refreshing these projectors
            [tmp enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                PJProjector* addedProjector = (PJProjector*)obj;
                // Begin refreshing this projector
                [self beginRefreshingProjector:addedProjector forReason:PJRefreshReasonUserInteraction];
            }];
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
            // We need to update the archive
            [self archiveProjectors];
        }
    }
}

- (void)beginRefreshingAllProjectorsForReason:(PJRefreshReason)reason {
    if ([self.mutableProjectors count] > 0) {
        for (PJProjector* projector in self.mutableProjectors) {
            [self beginRefreshingProjector:projector forReason:reason];
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

+ (NSString*)stringForConnectionState:(PJConnectionState)state {
    NSString* ret = nil;

    switch (state) {
        case PJConnectionStateDiscovered:      ret = @"Discovered";     break;
        case PJConnectionStateConnecting:      ret = @"Connecting";     break;
        case PJConnectionStateConnectionError: ret = @"Not Connected";  break;
        case PJConnectionStatePasswordError:   ret = @"Needs Password"; break;
        case PJConnectionStateConnected:       ret = @"Connected";      break;
        default:                               ret = @"Unknown";        break;
    }

    return ret;
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

- (void)subscribeToNotificationsForAllProjectors {
    if ([self.mutableProjectors count] > 0) {
        for (PJProjector* projector in self.mutableProjectors) {
            [self subscribeToNotificationsForProjector:projector];
        }
    }
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
    // Post a KVO notification
    [self postProjectorReplacedForProjector:projector];
}

- (void)projectorConnectionStateDidChange:(NSNotification*)notification {
    PJProjector* projector = [notification object];
    // Post a KVO notification
    [self postProjectorReplacedForProjector:projector];
    // We only want to present an alert view to the user
    // if the refresh was due to user interaction
    if (projector.lastRefreshReason == PJRefreshReasonUserInteraction) {
        // If this is a general connection error, then we just pop up a UIAlertController to inform
        // the user that there was a connection problem.
        if (projector.connectionState == PJConnectionStateConnectionError) {
            // Construct the message
            NSString* message = [NSString stringWithFormat:@"A network error encountered while trying to reach projector at %@.", projector.host];
            UIViewController* rootViewController = nil;
            for (UIWindow* window in [UIApplication sharedApplication].windows) {
                if (window.isKeyWindow) {
                    rootViewController = window.rootViewController;
                    break;
                }
            }
            if (rootViewController != nil) {
                UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* retryAction = [UIAlertAction actionWithTitle:@"Retry"
                                                                      style:UIAlertActionStyleDefault
                                                                    handler:^(UIAlertAction* action) {
                    // The user chose to retry, so refresh the projector
                    [projector refreshAllQueriesForReason:PJRefreshReasonUserInteraction];
                    [rootViewController dismissViewControllerAnimated:YES completion:nil];
                }];
                UIAlertAction* deleteAction = [UIAlertAction actionWithTitle:@"Delete"
                                                                       style:UIAlertActionStyleDestructive
                                                                     handler:^(UIAlertAction* action) {
                    // The user chose to delete the projector, so remove it
                    [self removeProjectorsFromManager:@[projector]];
                    [rootViewController dismissViewControllerAnimated:YES completion:nil];
                }];
                UIAlertAction* dismissAction = [UIAlertAction actionWithTitle:@"Dismiss"
                                                                       style:UIAlertActionStyleCancel
                                                                     handler:^(UIAlertAction* action) {
                    [rootViewController dismissViewControllerAnimated:YES completion:nil];
                }];
                [alert addAction:retryAction];
                [alert addAction:deleteAction];
                [alert addAction:dismissAction];
                [rootViewController presentViewController:alert animated:YES completion:nil];
            }
        }
    }
}

- (void)subscribeToApplicationNotifications {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
}

- (void)unsubscribeFromApplicationNotifications {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self
                                  name:UIApplicationDidEnterBackgroundNotification
                                object:nil];
}

- (void)applicationDidEnterBackground:(NSNotification*)notification {
    [self archiveProjectors];
}

- (void)archiveProjectors {
    // Get the URL for the archive
    NSURL* archiveURL = [self urlForProjectorsArchive];
    // Get the file manager
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    // Does the archive file exist?
    if ([fileMgr fileExistsAtPath:[archiveURL path]]) {
        // Remove any existing archive
        NSError* removeError = nil;
        BOOL removed = [fileMgr removeItemAtURL:archiveURL error:&removeError];
        if (removed) {
            NSLog(@"Existing archive removed at %@", archiveURL);
        } else {
            NSLog(@"Error removing existing archive at %@", archiveURL);
        }
    } else {
        NSLog(@"No existing archive at %@", archiveURL);
    }
    // Do we have any projectors?
    if ([self.mutableProjectors count] > 0) {
        // Now archive the projectors
        NSError* archiveError = nil;
        NSData* data = [NSKeyedArchiver archivedDataWithRootObject:self.mutableProjectors
                                             requiringSecureCoding:NO
                                                             error:&archiveError];
        if (archiveError == nil) {
            NSError* writeError = nil;
            [data writeToURL:archiveURL
                     options:0
                       error:&writeError];
            if (writeError == nil) {
                NSLog(@"Projectors archive created successfully at %@", archiveURL);
            } else {
                NSLog(@"FAILED to write archive data: %@", writeError.localizedDescription);
            }
        } else {
            NSLog(@"FAILED to archive data: %@", archiveError.localizedDescription);
        }
    }
}

- (BOOL)unarchiveProjectors {
    BOOL ret = NO;

    // Do we have any projectors?
    if ([self.mutableProjectors count] == 0) {
        // Get the URL for the archive
        NSURL* archiveURL = [self urlForProjectorsArchive];
        // Get the file manager
        NSFileManager* fileMgr = [NSFileManager defaultManager];
        // Does an archive exist?
        if ([fileMgr fileExistsAtPath:[archiveURL path]]) {
            NSLog(@"Projectors archive exists at %@", archiveURL);
            // We have an archive, so unarchive the projectors array from that
            NSError* readError = nil;
            NSData* fileData = [NSData dataWithContentsOfURL:archiveURL
                                                     options:0
                                                       error:&readError];
            if (readError == nil) {
                NSArray* projectors = [NSKeyedUnarchiver unarchivedArrayOfObjectsOfClass:[PJProjector class]
                                                                                fromData:fileData
                                                                                   error:&readError];
                if (readError == nil) {
                    if ([projectors count] > 0) {
                        NSLog(@"Unarchived %@ projectors from archive", @([projectors count]));
                        // Set these projectors into the mutable array
                        [self.mutableProjectors setArray:projectors];
                        // Set the return value
                        ret = YES;
                        // XXXMEH - workaround for PJProjector bug. When unarchiving, then
                        // if the projector has a password, then the default credential
                        // needs to be set into the PJLink client. Manually setting the
                        // password accomplishes the same thing.
                        for (PJProjector* projector in projectors) {
                            if ([projector.password length] > 0) {
                                NSString* password = projector.password;
                                projector.password = nil;
                                projector.password = password;
                            }
                        }
                    }
                } else {
                    NSLog(@"Could not unarchive projectors from data: %@", readError.localizedDescription);
                }
            } else {
                NSLog(@"Could not read archive file data from %@", archiveURL);
            }
        } else {
            // No archive exists
            NSLog(@"No projectors archive exists at %@", archiveURL);
        }
    }

    return ret;
}

- (NSURL*)urlForProjectorsArchive {
    NSURL* ret = nil;

    // Get the file manager
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    // Get the URL for the Document directory
    NSError* docDirectoryURLError = nil;
    NSURL*   docDirectoryURL = [fileMgr URLForDirectory:NSDocumentDirectory
                                               inDomain:NSUserDomainMask
                                      appropriateForURL:nil
                                                 create:YES
                                                  error:&docDirectoryURLError];
    if (docDirectoryURL != nil) {
        // Append the file name to the documents directory
        ret = [docDirectoryURL URLByAppendingPathComponent:kPJProjectorManagerArchiveFileName];
    } else {
        NSLog(@"Error occurred getting Documents directory, error = %@", docDirectoryURLError);
    }

    return ret;
}

- (void)beginRefreshingProjector:(PJProjector*)projector forReason:(PJRefreshReason)reason {
    if (projector.connectionState != PJConnectionStateConnected &&
        projector.connectionState != PJConnectionStateConnecting) {
        // Tell the projector to refresh itself
        [projector refreshAllQueriesForReason:reason];
        // Turn on the refresh timer
        projector.refreshTimerOn = YES;
    }
}

- (void)postProjectorReplacedForProjector:(PJProjector*)projector {
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

@end
