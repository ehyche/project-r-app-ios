//
//  PJProjector.m
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJProjector.h"
#import "PJInputInfo.h"
#import "PJAMXBeaconHost.h"
#import <PJLinkCocoa/PJResponseInfo.h>
#import <PJLinkCocoa/AFPJLinkClient.h>
#import <PJLinkCocoa/PJURLProtocolRunLoop.h>

#define kDefaultPJLinkPort 4352

NSString*      const PJProjectorRequestDidBeginNotification          = @"PJProjectorRequestDidBeginNotification";
NSString*      const PJProjectorRequestDidEndNotification            = @"PJProjectorRequestDidEndNotification";
NSString*      const PJProjectorDidChangeNotification                = @"PJProjectorDidChangeNotification";
NSString*      const PJProjectorConnectionStateDidChangeNotification = @"PJProjectorConnectionStateDidChangeNotification";
NSString*      const PJProjectorErrorKey                             = @"PJProjectorErrorKey";
NSString*      const kPJLinkCommandPowerOn                           = @"POWR 1\r";
NSString*      const kPJLinkCommandPowerOff                          = @"POWR 0\r";
NSTimeInterval const kDefaultRefreshTimerInterval                    = 60.0;

static NSArray* gInputTypeNames = nil;

@interface PJProjector()

// Readwrite versions of public readonly properties
@property(nonatomic,assign,readwrite) PJPowerStatus powerStatus;
@property(nonatomic,assign,readwrite,getter = isAudioMuted) BOOL audioMuted;
@property(nonatomic,assign,readwrite,getter = isVideoMuted) BOOL videoMuted;
@property(nonatomic,assign,readwrite) PJErrorStatus fanErrorStatus;
@property(nonatomic,assign,readwrite) PJErrorStatus lampErrorStatus;
@property(nonatomic,assign,readwrite) PJErrorStatus temperatureErrorStatus;
@property(nonatomic,assign,readwrite) PJErrorStatus coverOpenErrorStatus;
@property(nonatomic,assign,readwrite) PJErrorStatus filterErrorStatus;
@property(nonatomic,assign,readwrite) PJErrorStatus otherErrorStatus;
@property(nonatomic,copy,readwrite) NSArray* lampStatus; // NSArray of PJLampStatus
@property(nonatomic,copy,readwrite) NSArray* inputs; // NSArray of PJInputInfo
@property(nonatomic,copy,readwrite) NSString* projectorName;
@property(nonatomic,copy,readwrite) NSString* manufacturerName;
@property(nonatomic,copy,readwrite) NSString* productName;
@property(nonatomic,copy,readwrite) NSString* otherInformation;
@property(nonatomic,assign,readwrite,getter = isClass2Compatible) BOOL class2Compatible;
// Internal-only properties
@property(nonatomic,assign) NSUInteger activeInputIndex;
@property(nonatomic,assign) BOOL       modelChanged;
// Network client
@property(nonatomic,strong) AFPJLinkClient* pjlinkClient;
// Connection state
@property(nonatomic,assign,readwrite) PJConnectionState connectionState;
// Refresh timer
@property(nonatomic,strong) NSTimer* refreshTimer;

+ (NSString*)inputNameForInputType:(PJInputType)type;

@end

@implementation PJProjector

+(void) initialize {
    if (self == [PJProjector class]) {
        gInputTypeNames = @[@"RGB", @"Video", @"Digital", @"Storage", @"Network"];
    }
}

- (id)init {
    self = [super init];
    if (self) {
        // Set initial values
        _powerStatus            = PJPowerStatusStandby;
        _audioMuted             = NO;
        _videoMuted             = NO;
        _fanErrorStatus         = PJErrorStatusNoError;
        _lampErrorStatus        = PJErrorStatusNoError;
        _temperatureErrorStatus = PJErrorStatusNoError;
        _coverOpenErrorStatus   = PJErrorStatusNoError;
        _filterErrorStatus      = PJErrorStatusNoError;
        _otherErrorStatus       = PJErrorStatusNoError;
        _lampStatus             = @[];
        _inputs                 = @[];
        _projectorName          = @"";
        _manufacturerName       = @"";
        _productName            = @"";
        _otherInformation       = @"";
        _class2Compatible       = NO;
        // Set defaults for IP address and port
        _host                   = @"127.0.0.1";
        _port                   = kDefaultPJLinkPort;
        // The default connection state is discovered
        _connectionState        = PJConnectionStateDiscovered;
        // Default refresh timer interval
        _refreshTimerInterval   = kDefaultRefreshTimerInterval;
    }

    return self;
}

- (id)initWithHost:(NSString*)host {
    return [self initWithHost:host port:kDefaultPJLinkPort];
}

- (id)initWithHost:(NSString*)host port:(NSInteger)port {
    // Note that this is intentionally [self init] and not [super init]
    self = [self init];
    if (self) {
        // Save the host and port
        _host = host;
        _port = port;
        // Create the AFPJLinkClient
        [self rebuildPJLinkClient];
    }

    return self;
}

- (id)initWithBeaconHost:(PJAMXBeaconHost*)beaconHost {
    self = [self initWithHost:beaconHost.ipAddressFromSocket];
    if (self) {
        // Save the AMX beacon host
        _beaconHost = beaconHost;
    }

    return self;
}


- (void)setPowerStatus:(PJPowerStatus)powerStatus {
    if (_powerStatus != powerStatus) {
        _powerStatus = powerStatus;
        self.modelChanged = YES;
    }
}

- (PJInputType)activeInputType {
    PJInputType ret = PJInputTypeRGB;

    if (self.activeInputIndex < [self.inputs count]) {
        PJInputInfo* inputInfo = [self.inputs objectAtIndex:self.activeInputIndex];
        ret = inputInfo.inputType;
    }

    return ret;
}

- (NSUInteger)activeInputNumber {
    NSUInteger ret = 1;

    if (self.activeInputIndex < [self.inputs count]) {
        PJInputInfo* inputInfo = [self.inputs objectAtIndex:self.activeInputIndex];
        ret = inputInfo.inputNumber;
    }

    return ret;
}

- (NSString*)activeInputName {
    NSString* ret = @"Unknown 0";

    if (self.activeInputIndex < [self.inputs count]) {
        PJInputInfo* inputInfo = [self.inputs objectAtIndex:self.activeInputIndex];
        NSString* inputName = [PJProjector inputNameForInputType:inputInfo.inputType];
        ret = [NSString stringWithFormat:@"%@ %u", inputName, inputInfo.inputNumber];
    }

    return ret;
}

- (void)setAudioMuted:(BOOL)audioMuted {
    if (_audioMuted != audioMuted) {
        _audioMuted = audioMuted;
        self.modelChanged = YES;
    }
}

- (void)setVideoMuted:(BOOL)videoMuted {
    if (_videoMuted != videoMuted) {
        _videoMuted = videoMuted;
        self.modelChanged = YES;
    }
}

- (void)setFanErrorStatus:(PJErrorStatus)fanErrorStatus {
    if (_fanErrorStatus != fanErrorStatus) {
        _fanErrorStatus = fanErrorStatus;
        self.modelChanged = YES;
    }
}

- (void)setLampErrorStatus:(PJErrorStatus)lampErrorStatus {
    if (_lampErrorStatus != lampErrorStatus) {
        _lampErrorStatus = lampErrorStatus;
        self.modelChanged = YES;
    }
}

- (void)setTemperatureErrorStatus:(PJErrorStatus)temperatureErrorStatus {
    if (_temperatureErrorStatus != temperatureErrorStatus) {
        _temperatureErrorStatus = temperatureErrorStatus;
        self.modelChanged = YES;
    }
}

- (void)setCoverOpenErrorStatus:(PJErrorStatus)coverOpenErrorStatus {
    if (_coverOpenErrorStatus != coverOpenErrorStatus) {
        _coverOpenErrorStatus = coverOpenErrorStatus;
        self.modelChanged = YES;
    }
}

- (void)setFilterErrorStatus:(PJErrorStatus)filterErrorStatus {
    if (_filterErrorStatus != filterErrorStatus) {
        _filterErrorStatus = filterErrorStatus;
        self.modelChanged = YES;
    }
}

- (void)setOtherErrorStatus:(PJErrorStatus)otherErrorStatus {
    if (_otherErrorStatus != otherErrorStatus) {
        _otherErrorStatus = otherErrorStatus;
        self.modelChanged = YES;
    }
}

- (NSUInteger)numberOfLamps {
    return [self.lampStatus count];
}

- (void)setLampStatus:(NSArray *)lampStatus {
    if (![_lampStatus isEqualToArray:lampStatus]) {
        _lampStatus = [lampStatus copy];
        self.modelChanged = YES;
    }
}

- (void)setInputs:(NSArray *)inputs {
    if (![_inputs isEqualToArray:inputs]) {
        _inputs = [inputs copy];
        self.modelChanged = YES;
    }
}

- (void)setProjectorName:(NSString *)projectorName {
    if ([_projectorName isEqualToString:projectorName]) {
        _projectorName = [projectorName copy];
        self.modelChanged = YES;
    }
}

- (void)setManufacturerName:(NSString *)manufacturerName {
    if ([_manufacturerName isEqualToString:manufacturerName]) {
        _manufacturerName = [manufacturerName copy];
        self.modelChanged = YES;
    }
}

- (void)setProductName:(NSString *)productName {
    if ([_productName isEqualToString:productName]) {
        _productName = [productName copy];
        self.modelChanged = YES;
    }
}

- (void)setOtherInformation:(NSString *)otherInformation {
    if ([_otherInformation isEqualToString:otherInformation]) {
        _otherInformation = [otherInformation copy];
        self.modelChanged = YES;
    }
}

- (void)setActiveInputIndex:(NSUInteger)activeInputIndex {
    if (_activeInputIndex != activeInputIndex) {
        _activeInputIndex = activeInputIndex;
        self.modelChanged = YES;
    }
}

- (void)setClass2Compatible:(BOOL)class2Compatible {
    if (_class2Compatible != class2Compatible) {
        _class2Compatible = class2Compatible;
        self.modelChanged = YES;
    }
}

- (void)setPassword:(NSString *)password {
    if (![_password isEqualToString:password]) {
        _password = [password copy];
        // Create an NSURLCredential with this password.
        // PJLink does not require (or use) a username, so we just
        // supply a dummy username.
        NSURLCredential* credential = [NSURLCredential credentialWithUser:@"user"
                                                                 password:_password
                                                              persistence:NSURLCredentialPersistenceForSession];
        // Set this credential as the default credential for our AFPJLinkClient
        [self.pjlinkClient setDefaultCredential:credential];
    }
}

- (void)setConnectionState:(PJConnectionState)connectionState {
    if (_connectionState != connectionState) {
        _connectionState = connectionState;
        // Post a connection state did change notification
        [self postConnectionStateDidChangeNotification];
    }
}

- (void)setRefreshTimerInterval:(NSTimeInterval)refreshTimerInterval {
    if (_refreshTimerInterval != refreshTimerInterval) {
        // Save the new refresh timer interval
        _refreshTimerInterval = refreshTimerInterval;
        // If we are currently refreshing, then we need to tear down the timer and re-build
        if (_refreshTimerOn) {
            // Invalidate the old timer
            [self.refreshTimer invalidate];
            // Create a new one
            self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:_refreshTimerInterval
                                                                 target:self
                                                               selector:@selector(refreshTimerFired:)
                                                               userInfo:nil
                                                                repeats:YES];
        }
    }
}

- (void)setRefreshTimerOn:(BOOL)refreshTimerOn {
    if (_refreshTimerOn && !refreshTimerOn) {
        // Invalidate and destroy the refresh timer
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    } else if (!_refreshTimerOn && refreshTimerOn) {
        // Create a repeating refresh timer
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:self.refreshTimerInterval
                                                             target:self
                                                           selector:@selector(refreshTimerFired:)
                                                           userInfo:nil
                                                            repeats:YES];
    }
}

- (void)refreshQueries:(NSArray*)queries {
    if ([queries count] > 0) {
        // Construct the query string
        NSMutableString* tmp = [NSMutableString string];
        for (NSNumber* query in queries) {
            NSUInteger queryInt = [query unsignedIntegerValue];
            NSString*  queryStr = nil;
            switch (queryInt) {
                case PJCommandPower:                 queryStr = @"POWR ?\r"; break;
                case PJCommandInput:                 queryStr = @"INPT ?\r"; break;
                case PJCommandAVMute:                queryStr = @"AVMT ?\r"; break;
                case PJCommandErrorQuery:            queryStr = @"ERST ?\r"; break;
                case PJCommandLampQuery:             queryStr = @"LAMP ?\r"; break;
                case PJCommandInputListQuery:        queryStr = @"INST ?\r"; break;
                case PJCommandProjectorNameQuery:    queryStr = @"NAME ?\r"; break;
                case PJCommandManufacturerNameQuery: queryStr = @"INF1 ?\r"; break;
                case PJCommandProductNameQuery:      queryStr = @"INF2 ?\r"; break;
                case PJCommandOtherInfoQuery:        queryStr = @"INFO ?\r"; break;
                case PJCommandClassInfoQuery:        queryStr = @"CLSS ?\r"; break;
            }
            if (queryStr != nil) {
                [tmp appendString:queryStr];
            }
        }
        // Make the request and handle the responses.
        // This method already handles the case where
        // tmp is zero length.
        [self handleResponsesForCommandRequestBody:tmp];
    }
}

- (void)refreshAllQueries {
    [self refreshQueries:@[@(PJCommandPower),
                           @(PJCommandInput),
                           @(PJCommandAVMute),
                           @(PJCommandErrorQuery),
                           @(PJCommandLampQuery),
                           @(PJCommandInputListQuery),
                           @(PJCommandProjectorNameQuery),
                           @(PJCommandManufacturerNameQuery),
                           @(PJCommandProductNameQuery),
                           @(PJCommandOtherInfoQuery),
                           @(PJCommandClassInfoQuery)]];
}

- (void)refreshPowerStatus {
    [self refreshQueries:@[@(PJCommandPower)]];
}

- (void)refreshInputStatus {
    [self refreshQueries:@[@(PJCommandInput)]];
}

- (void)refreshMuteStatus {
    [self refreshQueries:@[@(PJCommandAVMute)]];
}

- (void)refreshSettableQueries {
    [self refreshQueries:@[@(PJCommandPower),
                           @(PJCommandInput),
                           @(PJCommandAVMute)]];
}

- (void)refreshQueriesWeExpectToChange {
    [self refreshQueries:@[@(PJCommandPower),
                           @(PJCommandInput),
                           @(PJCommandAVMute),
                           @(PJCommandErrorQuery),
                           @(PJCommandLampQuery),
                           @(PJCommandInputListQuery)]];
}

- (BOOL)requestPowerStateChange:(BOOL)powerOn {
    NSString* commandBody = nil;
    if (powerOn) {
        // We only want to turn the power on if we are in standby
        if (self.powerStatus == PJPowerStatusStandby) {
            commandBody = kPJLinkCommandPowerOn;
        }
    } else {
        // We only want to turn the power off if we in lamp on status
        if (self.powerStatus == PJPowerStatusLampOn) {
            commandBody = kPJLinkCommandPowerOff;
        }
    }
    // Process the command body (if it is present)
    [self handleResponsesForCommandRequestBody:commandBody];

    return (commandBody != nil ? YES : NO);
}

- (BOOL)requestMuteStateChange:(BOOL)muteOn forTypes:(PJMuteType)type {
    BOOL ret = NO;

    // Determine if we actually need to change anything
    if (type == PJMuteTypeAudio) {
        ret = self.isAudioMuted != muteOn;
    } else if (type == PJMuteTypeVideo) {
        ret = self.isVideoMuted != muteOn;
    } else if (type == PJMuteTypeAudioAndVideo) {
        ret = (self.isAudioMuted != muteOn || self.isVideoMuted != muteOn);
    }
    if (ret) {
        [self handleResponsesForCommandRequestBody:[self muteCommandBodyForType:type state:muteOn]];
    }

    return ret;
}

- (BOOL)requestInputChangeToInput:(PJInput*)input {
    BOOL ret = NO;

    // Make sure this is one of the valid inputs
    BOOL valid = NO;
    for (PJInput* validInput in self.inputs) {
        if (validInput.inputType   == input.inputType &&
            validInput.inputNumber == input.inputNumber) {
            valid = YES;
            break;
        }
    }
    if (valid) {
        // Make sure we are not already on this input
        if (input.inputType   != self.activeInputType ||
            input.inputNumber != self.activeInputNumber) {
            // We will be making a request
            ret = YES;
            // Construct the command and issue the request
            NSString* commandBody = [NSString stringWithFormat:@"INPT %u%u\r", input.inputType, input.inputNumber];
            [self handleResponsesForCommandRequestBody:commandBody];
        }
    }

    return ret;
}

- (BOOL)requestInputChangeToInputIndex:(NSUInteger)inputIndex {
    BOOL ret = NO;

    if (inputIndex < [self.inputs count]) {
        PJInput* input = [self.inputs objectAtIndex:inputIndex];
        ret = [self requestInputChangeToInput:input];
    }

    return ret;
}

- (BOOL)requestInputChangeToInputType:(PJInputType)type number:(NSUInteger)number {
    BOOL ret = NO;

    PJInput* selectedInput = nil;
    for (PJInput* input in self.inputs) {
        if (input.inputType == type && input.inputNumber == number) {
            selectedInput = input;
            break;
        }
    }
    if (selectedInput != nil) {
        ret = [self requestInputChangeToInput:selectedInput];
    }

    return ret;
}

#pragma mark - PJProjector private methods

+ (NSString*)inputNameForInputType:(PJInputType)type {
    NSString* ret = @"Unknown";

    if (type < [gInputTypeNames count]) {
        ret = [gInputTypeNames objectAtIndex:type];
    }

    return ret;
}

- (void)setActiveInputWithType:(PJInputType)type number:(uint8_t)number {
    NSArray*   inputs    = self.inputs;
    NSUInteger numInputs = [inputs count];
    NSUInteger i         = 0;
    for (i = 0; i < numInputs; i++) {
        PJInput* input = [inputs objectAtIndex:i];
        if (input.inputType == type && input.inputNumber == number) {
            break;
        }
    }
    if (i < numInputs) {
        self.activeInputIndex = i;
    }
}

- (void)handleResponses:(NSArray*)responses {
    if ([responses count] > 0) {
        // Clear the flag saying that the model changed
        self.modelChanged = NO;
        // Process all the responses
        for (PJResponseInfo* response in responses) {
            [self handleResponse:response];
        }
        // If the model changed, then issue the did-change notification
        if (self.modelChanged) {
            self.modelChanged = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:PJProjectorDidChangeNotification object:self];
        }
    }
}

- (void)handleResponse:(PJResponseInfo*)responseInfo {
    // Make sure we didn't encounter an error
    if (responseInfo.error == PJErrorOK) {
        if ([responseInfo isKindOfClass:[PJResponseInfoPowerStatusQuery class]]) {
            PJResponseInfoPowerStatusQuery* powerStatusQuery = (PJResponseInfoPowerStatusQuery*)responseInfo;
            self.powerStatus = powerStatusQuery.powerStatus;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoInputSwitchQuery class]]) {
            PJResponseInfoInputSwitchQuery* inputSwitchQuery = (PJResponseInfoInputSwitchQuery*)responseInfo;
            PJInput* input = inputSwitchQuery.input;
            [self setActiveInputWithType:input.inputType number:input.inputNumber];
        } else if ([responseInfo isKindOfClass:[PJResponseInfoMuteStatusQuery class]]) {
            PJResponseInfoMuteStatusQuery* muteStatusQuery = (PJResponseInfoMuteStatusQuery*)responseInfo;
            if (muteStatusQuery.muteType & PJMuteTypeAudio) {
                self.audioMuted = muteStatusQuery.muteOn;
            }
            if (muteStatusQuery.muteType & PJMuteTypeVideo) {
                self.videoMuted = muteStatusQuery.muteOn;
            }
        } else if ([responseInfo isKindOfClass:[PJResponseInfoErrorStatusQuery class]]) {
            PJResponseInfoErrorStatusQuery* errorStatusQuery = (PJResponseInfoErrorStatusQuery*) responseInfo;
            self.fanErrorStatus = errorStatusQuery.fanError;
            self.lampErrorStatus = errorStatusQuery.lampError;
            self.temperatureErrorStatus = errorStatusQuery.temperatureError;
            self.coverOpenErrorStatus = errorStatusQuery.coverOpenError;
            self.filterErrorStatus = errorStatusQuery.filterError;
            self.otherErrorStatus = errorStatusQuery.otherError;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoLampQuery class]]) {
            PJResponseInfoLampQuery* lampQuery = (PJResponseInfoLampQuery*) responseInfo;
            self.lampStatus = lampQuery.lampStatuses;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoInputTogglingListQuery class]]) {
            PJResponseInfoInputTogglingListQuery* inputListQuery = (PJResponseInfoInputTogglingListQuery*)responseInfo;
            self.inputs = inputListQuery.inputs;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoProjectorNameQuery class]]) {
            PJResponseInfoProjectorNameQuery* projectorNameQuery = (PJResponseInfoProjectorNameQuery*)responseInfo;
            self.projectorName = projectorNameQuery.projectorName;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoManufacturerNameQuery class]]) {
            PJResponseInfoManufacturerNameQuery* manufacturerNameQuery = (PJResponseInfoManufacturerNameQuery*)responseInfo;
            self.manufacturerName = manufacturerNameQuery.manufacturerName;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoProductNameQuery class]]) {
            PJResponseInfoProductNameQuery* productNameQuery = (PJResponseInfoProductNameQuery*)responseInfo;
            self.productName = productNameQuery.productName;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoOtherInfoQuery class]]) {
            PJResponseInfoOtherInfoQuery* otherInfoQuery = (PJResponseInfoOtherInfoQuery*)responseInfo;
            self.otherInformation = otherInfoQuery.otherInfo;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoClassInfoQuery class]]) {
            PJResponseInfoClassInfoQuery* classInfoQuery = (PJResponseInfoClassInfoQuery*)responseInfo;
            self.class2Compatible = classInfoQuery.class2Compatible;
        }
    }
}

- (void)rebuildPJLinkClient {
    NSString* pjlinkURLStr = [NSString stringWithFormat:@"pjlink://%@:%d/", self.host, self.port];
    NSURL*    pjlinkURL    = [NSURL URLWithString:pjlinkURLStr];
    self.pjlinkClient = [[AFPJLinkClient alloc] initWithBaseURL:pjlinkURL];
}

- (void)handleResponsesForCommandRequestBody:(NSString*)requestBody {
    if ([requestBody length] > 0 && self.pjlinkClient != nil) {
        // Send the request did begin notification
        [[NSNotificationCenter defaultCenter] postNotificationName:PJProjectorRequestDidBeginNotification object:self];
        // Update the connection state if necessary.
        [self updateConnectionStatePreRequest];
        // Send the request
        [self.pjlinkClient makeRequestWithBody:requestBody
                                       success:^(AFPJLinkRequestOperation* operation, NSString* responseBody, NSArray* parsedResponses) {
                                           // Send the request-did-end notification
                                           [self postRequestDidEndNotificationWithError:nil];
                                           // Update the connection state
                                           [self updateConnectionStatePostRequestWithError:nil];
                                           // Process the responses
                                           [self handleResponses:parsedResponses];
                                       }
                                       failure:^(AFPJLinkRequestOperation* operation, NSError* error) {
                                           // Send the request-did-end notification
                                           [self postRequestDidEndNotificationWithError:error];
                                           // Update the connection state
                                           [self updateConnectionStatePostRequestWithError:error];
                                       }];
    }
}

- (void)postRequestDidEndNotificationWithError:(NSError*)error {
    NSDictionary* userInfo = nil;
    if (error != nil) {
        userInfo = @{PJProjectorErrorKey : error};
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:PJProjectorRequestDidEndNotification object:self userInfo:userInfo];
}

- (NSString*)muteCommandBodyForType:(PJMuteType)type state:(BOOL)muteOn {
    NSString* ret = nil;

    NSString* muteTypeStr = nil;
    switch (type) {
        case PJMuteTypeVideo:         muteTypeStr = @"1"; break;
        case PJMuteTypeAudio:         muteTypeStr = @"2"; break;
        case PJMuteTypeAudioAndVideo: muteTypeStr = @"3"; break;
    }
    if (muteTypeStr != nil) {
        ret = [NSString stringWithFormat:@"AVMT %@%u\r", muteTypeStr, (muteOn ? 1 : 0)];
    }

    return ret;
}

- (void)postConnectionStateDidChangeNotification {
    dispatch_block_t block = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PJProjectorConnectionStateDidChangeNotification object:self];
	};
    // Ensure that we post the notification on the main thread
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)updateConnectionStatePreRequest {
    // If we are already connected, then we will assume we stay connected.
    // If we are not already connected, then we will change state to connecting.
    if (self.connectionState != PJConnectionStateConnected) {
        self.connectionState = PJConnectionStateConnecting;
    }
}

- (void)updateConnectionStatePostRequestWithError:(NSError*)error {
    if (error != nil) {
        // We had an error. If it is a password error, then we
        // set ourselves into the password error connection state.
        // This tells observers that we need to provide a password.
        // Otherwise, we go to the connection error connection state.
        if ([error.domain isEqualToString:PJLinkErrorDomain]) {
            if (error.code == PJLinkErrorNoPasswordProvided) {
                self.connectionState = PJConnectionStatePasswordError;
            } else {
                self.connectionState = PJConnectionStateConnectionError;
            }
        } else {
            self.connectionState = PJConnectionStateConnectionError;
        }
    } else {
        // No error, so we go to the connected state
        self.connectionState = PJConnectionStateConnected;
    }
}

- (void)refreshTimerFired:(NSTimer*)timer {
    [self refreshAllQueries];
}

@end
