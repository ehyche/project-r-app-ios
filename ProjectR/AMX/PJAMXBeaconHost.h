//
//  PJAMXBeaconHost.h
//  ProjectR
//
//  Created by Eric Hyche on 7/13/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const kAMXKeyUUID;
extern NSString* const kAMXKeySDKClass;
extern NSString* const kAMXKeyMake;
extern NSString* const kAMXKeyModel;
extern NSString* const kAMXKeyRevision;
extern NSString* const kAMXKeyConfigName;
extern NSString* const kAMXKeyConfigURL;

@interface PJAMXBeaconHost : NSObject

// Properties obtained by parsing the AMX beacon string
@property(nonatomic,readonly,retain) NSString*     uuid;
@property(nonatomic,readonly,retain) NSString*     sdkClass;
@property(nonatomic,readonly,retain) NSString*     make;
@property(nonatomic,readonly,retain) NSString*     model;
@property(nonatomic,readonly,retain) NSString*     revision;
@property(nonatomic,readonly,retain) NSString*     configName;
@property(nonatomic,readonly,retain) NSString*     configURLString;
@property(nonatomic,readonly,retain) NSString*     hostFromConfigURL;
@property(nonatomic,readonly,retain) NSDictionary* data;
// Properties set from the outside by the PJAMXBeaconListener
@property(nonatomic,copy) NSString* ipAddressFromSocket;
@property(nonatomic,copy) NSDate*   dateOfLastReception;

// Determines if the first four characters of the reply string are "AMXB"
+ (BOOL)isAMXBeaconReply:(NSString*)reply;

// Parses the AMX Beacon reply string and returns an PJAMXBeaconHost
+ (PJAMXBeaconHost*)beaconHostFromBeaconReply:(NSString*)reply;

// Initialize the object with an AMX beacon reply
- (id)initWithBeaconReply:(NSString*)reply;

// Update values from a beacon reply
- (void)updateFromBeaconReply:(NSString*)reply;

@end
