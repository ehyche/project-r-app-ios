//
//  PJProjector.m
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJProjector.h"
#import "PJInputInfo.h"
#import <PJLinkCocoa/PJResponseInfo.h>
#import <PJLinkCocoa/AFPJLinkClient.h>

NSString* const PJProjectorRequestDidBeginNotification = @"PJProjectorRequestDidBeginNotification";
NSString* const PJProjectorRequestDidEndNotification   = @"PJProjectorRequestDidEndNotification";
NSString* const PJProjectorDidChangeNotification       = @"PJProjectorDidChangeNotification";
NSString* const PJProjectorErrorKey                    = @"PJProjectorErrorKey";
NSInteger const kDefaultPJLinkPort                     = 4352;
NSString* const kPJLinkCommandPowerOn                  = @"POWR 1\r";
NSString* const kPJLinkCommandPowerOff                 = @"POWR 0\r";

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
        // Set initial status
        PJLampStatus* lampStatus = [[PJLampStatus alloc] init];
        _lampStatus  = @[lampStatus];
        // Set up the default inputs
        PJInput* inputRGB1     = [[PJInput alloc] init];
        inputRGB1.inputType    = PJInputTypeRGB;
        inputRGB1.inputNumber  = 1;
        PJInput* inputRGB2     = [[PJInput alloc] init];
        inputRGB1.inputType    = PJInputTypeRGB;
        inputRGB1.inputNumber  = 2;
        PJInput* inputRGB3     = [[PJInput alloc] init];
        inputRGB1.inputType    = PJInputTypeRGB;
        inputRGB1.inputNumber  = 3;
        PJInput* inputVideo1   = [[PJInput alloc] init];
        inputRGB1.inputType    = PJInputTypeVideo;
        inputRGB1.inputNumber  = 1;
        PJInput* inputVideo2   = [[PJInput alloc] init];
        inputRGB1.inputType    = PJInputTypeVideo;
        inputRGB1.inputNumber  = 2;
        PJInput* inputDigital1 = [[PJInput alloc] init];
        inputRGB1.inputType    = PJInputTypeDigital;
        inputRGB1.inputNumber  = 1;
        PJInput* inputStorage1 = [[PJInput alloc] init];
        inputRGB1.inputType    = PJInputTypeStorage;
        inputRGB1.inputNumber  = 1;
        PJInput* inputNetwork1 = [[PJInput alloc] init];
        inputRGB1.inputType    = PJInputTypeNetwork;
        inputRGB1.inputNumber  = 1;
        _inputs = @[inputRGB1, inputRGB2, inputRGB3, inputVideo1, inputVideo2, inputDigital1, inputStorage1, inputNetwork1];
        // Set up all the default names
        _projectorName    = @"Projector Name";
        _manufacturerName = @"Manufacturer Name";
        _productName      = @"Product Name";
        _otherInformation = @"Other Information";
        // Set defaults for IP address and port
        _host = @"127.0.0.1";
        _port = kDefaultPJLinkPort;
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

- (void)setHost:(NSString *)host {
    if (![_host isEqualToString:host]) {
        _host = [host copy];
        [self rebuildPJLinkClient];
    }
}

- (void)setPort:(NSInteger)port {
    if (_port != port) {
        _port = port;
        [self rebuildPJLinkClient];
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
        // Send the request
        [self.pjlinkClient makeRequestWithBody:requestBody
                                       success:^(AFPJLinkRequestOperation* operation, NSString* responseBody, NSArray* parsedResponses) {
                                           // Send the request-did-end notification
                                           [self postRequestDidEndNotificationWithError:nil];
                                           // Process the responses
                                           [self handleResponses:parsedResponses];
                                       }
                                       failure:^(AFPJLinkRequestOperation* operation, NSError* error) {
                                           // Send the request-did-end notification
                                           [self postRequestDidEndNotificationWithError:error];
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

@end