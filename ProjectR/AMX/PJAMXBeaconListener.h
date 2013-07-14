//
//  PJAMXBeaconListener.h
//  PJController
//
//  Created by Eric Hyche on 3/8/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const PJAMXBeaconHostsDidChangeNotification;

@interface PJAMXBeaconListener : NSObject

// Singleton access method
+(PJAMXBeaconListener*) sharedListener;

// Determine if we are listening or not
- (BOOL)isListening;

// Start listening
-(BOOL) startListening:(NSError**) pError;

// Stop listening
-(void) stopListening;

// Ping the multicast group with "AMX\r"
-(void) ping;

// Return an array of PJAMXBeaconHosts, sorted by ip address
- (NSArray*)hosts;

@end
