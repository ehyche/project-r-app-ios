//
//  PJAMXBeaconListener.h
//  PJController
//
//  Created by Eric Hyche on 3/8/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* const PJAMXBeaconHostsDidChangeNotification;

@interface PJAMXBeaconListener : NSObject

// Array of PJAMXBeaconHosts
@property(nonatomic,readonly,copy)                      NSArray* hosts;
@property(nonatomic,readonly,assign,getter=isListening) BOOL     listening;

// Singleton access method
+(PJAMXBeaconListener*) sharedListener;

// Start listening
-(BOOL) startListening:(NSError**) pError;

// Stop listening
-(void) stopListening;

// Ping the multicast group with "AMX\r"
-(void) ping;

// KVO-compliant accessors
- (NSUInteger)countOfHosts;
- (id)objectInHostsAtIndex:(NSUInteger)index;
- (NSArray*)hostsAtIndexes:(NSIndexSet *)indexes;

@end
