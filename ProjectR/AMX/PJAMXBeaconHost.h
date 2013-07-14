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

@property(nonatomic,copy)            NSString*     uuid;
@property(nonatomic,copy)            NSString*     sdkClass;
@property(nonatomic,copy)            NSString*     make;
@property(nonatomic,copy)            NSString*     model;
@property(nonatomic,copy)            NSString*     revision;
@property(nonatomic,copy)            NSString*     configName;
@property(nonatomic,copy)            NSString*     configURL;
@property(nonatomic,copy)            NSString*     ipAddressFromFromConfigURL;
@property(nonatomic,copy)            NSString*     ipAddressFromSocket;
@property(nonatomic,assign)          uint16_t      portFromSocket;
@property(nonatomic,copy)            NSDate*       dateOfLastReception;
@property(nonatomic,readonly,retain) NSDictionary* data;

// Determines if the first four characters of the reply string are "AMXB"
+ (BOOL)isAMXBeaconReply:(NSString*)reply;

// Parses the AMX Beacon reply string and returns an PJAMXBeaconHost
+ (PJAMXBeaconHost*)beaconHostFromBeaconReply:(NSString*)reply;

@end
