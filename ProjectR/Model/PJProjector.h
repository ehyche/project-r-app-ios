//
//  PJProjector.h
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PJLinkCocoa/PJDefinitions.h>

extern NSString* const PJProjectorRequestDidBeginNotification;
extern NSString* const PJProjectorRequestDidEndNotification;
extern NSString* const PJProjectorDidChangeNotification;
extern NSString* const PJProjectorConnectionStateDidChangeNotification;

extern NSString* const PJProjectorErrorKey;

@class PJInput;
@class PJInputInfo;
@class PJAMXBeaconHost;

enum {
    PJConnectionStateDiscovered,       // Initial state - No PJLink network connections attempted yet
    PJConnectionStateConnecting,       // First PJLink network connection attempt is in progress
    PJConnectionStatePasswordError,    // First PJLink network connection attempt resulted in password failure
    PJConnectionStateConnectionError,  // First PJLink network connection attempt resulted in network error other than password
    PJConnectionStateConnected,        // First and subsequent PJLink network connection attempts succeeded
    NumPJConnectionStates
};

typedef NSUInteger PJConnectionState;

@interface PJProjector : NSObject

@property(nonatomic,assign,readonly) PJPowerStatus powerStatus;
@property(nonatomic,assign,readonly) PJInputType activeInputType;
@property(nonatomic,assign,readonly) NSUInteger activeInputNumber;
@property(nonatomic,copy,readonly) NSString* activeInputName;
@property(nonatomic,assign,readonly) NSUInteger activeInputIndex;
@property(nonatomic,assign,readonly,getter = isAudioMuted) BOOL audioMuted;
@property(nonatomic,assign,readonly,getter = isVideoMuted) BOOL videoMuted;
@property(nonatomic,assign,readonly) PJErrorStatus fanErrorStatus;
@property(nonatomic,assign,readonly) PJErrorStatus lampErrorStatus;
@property(nonatomic,assign,readonly) PJErrorStatus temperatureErrorStatus;
@property(nonatomic,assign,readonly) PJErrorStatus coverOpenErrorStatus;
@property(nonatomic,assign,readonly) PJErrorStatus filterErrorStatus;
@property(nonatomic,assign,readonly) PJErrorStatus otherErrorStatus;
@property(nonatomic,assign,readonly) NSUInteger numberOfLamps;
@property(nonatomic,copy,readonly) NSArray* lampStatus; // NSArray of PJLampStatus
@property(nonatomic,copy,readonly) NSArray* inputs; // NSArray of PJInput
@property(nonatomic,copy,readonly) NSString* projectorName;
@property(nonatomic,copy,readonly) NSString* manufacturerName;
@property(nonatomic,copy,readonly) NSString* productName;
@property(nonatomic,copy,readonly) NSString* otherInformation;
@property(nonatomic,assign,readonly,getter = isClass2Compatible) BOOL class2Compatible;

// Host IP address and port
@property(nonatomic,copy,readonly)   NSString* host;
@property(nonatomic,assign,readonly) NSInteger port;

// Optional password
@property(nonatomic,copy) NSString* password;

// Connection state
@property(nonatomic,assign,readonly) PJConnectionState connectionState;

// AMX beacon host
@property(nonatomic,strong,readonly) PJAMXBeaconHost* beaconHost;

// Refresh timer
@property(nonatomic,assign)                         NSTimeInterval refreshTimerInterval;
@property(nonatomic,assign,getter=isRefreshTimerOn) BOOL           refreshTimerOn;

// Init with just an IP address and optional port
- (id)initWithHost:(NSString*)host;
- (id)initWithHost:(NSString*)host port:(NSInteger)port;
// Init with a PJAMXBeaconHost object
- (id)initWithBeaconHost:(PJAMXBeaconHost*)beaconHost;

// Refresh the specified queries
- (void)refreshQueries:(NSArray*)queries;
// Refresh all queries
- (void)refreshAllQueries;
// Refresh the power status
- (void)refreshPowerStatus;
// Refresh the input status
- (void)refreshInputStatus;
// Refresh the mute status
- (void)refreshMuteStatus;
// Refresh the status of the queries that
// we can directly set (power, input, mute).
- (void)refreshSettableQueries;
// For certain queries, we do not expect them to change very
// often. For instance, we do not expect the product name or the manufacturer
// name to change much, if ever. These queries can be refreshed
// very infrequently.
- (void)refreshQueriesWeExpectToChange;

// Turn the projector on or off. This method returns YES
// if the we initiated a state change, and NO if we
// did not. We may have not initiated a state change
// if the current state was not compatible with the
// change. For instance, if the power status was
// warming up, then the projector is being turned on
// already, so we would not do anything in that case.
- (BOOL)requestPowerStateChange:(BOOL)powerOn;

// Change the mute state of audio, video, or both.
// If the projector is already in the requested mute
// state, then no request is made and this method
// returns NO. Otherwise, a request is made and
// the method returns YES.
- (BOOL)requestMuteStateChange:(BOOL)muteOn forTypes:(PJMuteType)type;

// Change the projector input. If the projector is already on
// the requested input, then the methods return NO, and no
// request is made. If the projector is not on the requested
// input, then the network request is made and the
// methods return YES.
- (BOOL)requestInputChangeToInput:(PJInput*)input;
- (BOOL)requestInputChangeToInputIndex:(NSUInteger)inputIndex;
- (BOOL)requestInputChangeToInputType:(PJInputType)type number:(NSUInteger)number;

// Get the friendly name for a projector input
+ (NSString*)displayNameForInput:(PJInputInfo*)input;

@end
