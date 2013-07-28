//
//  PJAMXBeaconHost.m
//  ProjectR
//
//  Created by Eric Hyche on 7/13/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJAMXBeaconHost.h"

NSString* const kAMXKeyUUID       = @"-UUID";
NSString* const kAMXKeySDKClass   = @"-SDKClass";
NSString* const kAMXKeyMake       = @"-Make";
NSString* const kAMXKeyModel      = @"-Model";
NSString* const kAMXKeyRevision   = @"-Revision";
NSString* const kAMXKeyConfigName = @"Config-Name";
NSString* const kAMXKeyConfigURL  = @"Config-URL";
NSString* const kAMXBeaconHeader  = @"AMXB";
NSString* const kAMXDataOpen      = @"<";
NSString* const kAMXDataClose     = @">";

@interface PJAMXBeaconHost()

@property(nonatomic,readwrite,retain) NSString*     uuid;
@property(nonatomic,readwrite,retain) NSString*     sdkClass;
@property(nonatomic,readwrite,retain) NSString*     make;
@property(nonatomic,readwrite,retain) NSString*     model;
@property(nonatomic,readwrite,retain) NSString*     revision;
@property(nonatomic,readwrite,retain) NSString*     configName;
@property(nonatomic,readwrite,retain) NSString*     configURLString;
@property(nonatomic,readwrite,retain) NSString*     hostFromConfigURL;
@property(nonatomic,readwrite,retain) NSDictionary* data;

@end

@implementation PJAMXBeaconHost

+ (BOOL)isAMXBeaconReply:(NSString*)reply {
    return [reply hasPrefix:kAMXBeaconHeader];
}

+ (PJAMXBeaconHost*)beaconHostFromBeaconReply:(NSString*)reply {
    return [[PJAMXBeaconHost alloc] initWithBeaconReply:reply];
}

- (id)initWithBeaconReply:(NSString*)reply {
    self = [super init];
    if (self) {
        [self updateFromBeaconReply:reply];
    }

    return self;
}

- (void)updateFromBeaconReply:(NSString*)reply {
    // Make sure the first four characters are AMXB
    if ([reply hasPrefix:kAMXBeaconHeader]) {
        // Create a scanner
        NSScanner* scanner = [NSScanner scannerWithString:reply];
        // Skip the AMXB
        [scanner scanString:kAMXBeaconHeader intoString:NULL];
        // Now loop until we reach the end of the string
        NSMutableDictionary* tmp = [NSMutableDictionary dictionary];
        while (![scanner isAtEnd]) {
            // Scan up to the opening bracket
            [scanner scanUpToString:kAMXDataOpen intoString:NULL];
            // Scan the opening bracket
            [scanner scanString:kAMXDataOpen intoString:NULL];
            // Scan up to the closing bracket, putting the contents into a string
            NSString* dataStr = nil;
            if ([scanner scanUpToString:kAMXDataClose intoString:&dataStr]) {
                if ([dataStr length] > 0) {
                    // This is a name/value pair, separated by an =
                    NSArray* dataStrComponents = [dataStr componentsSeparatedByString:@"="];
                    // There better be two components
                    if ([dataStrComponents count] >= 2) {
                        // Get the name
                        NSString* nameComponent = [dataStrComponents objectAtIndex:0];
                        // Get the value
                        NSString* valueComponent = [dataStrComponents objectAtIndex:1];
                        // Trim any leading/trailing whitespace
                        NSCharacterSet* wsCharSet = [NSCharacterSet whitespaceCharacterSet];
                        NSString* nameTrimmed  = [nameComponent stringByTrimmingCharactersInSet:wsCharSet];
                        NSString* valueTrimmed = [valueComponent stringByTrimmingCharactersInSet:wsCharSet];
                        // Set these into the temporary dictionary
                        [tmp setObject:valueTrimmed forKey:nameTrimmed];
                    }
                }
            }
            // Skip the closing bracket
            [scanner scanString:kAMXDataClose intoString:NULL];
        }
        // Populate the known keys into the convenience properties
        NSString* uuid = [tmp objectForKey:kAMXKeyUUID];
        self.uuid = uuid;
        NSString* sdkClass = [tmp objectForKey:kAMXKeySDKClass];
        self.sdkClass = sdkClass;
        NSString* make = [tmp objectForKey:kAMXKeyMake];
        self.make = make;
        NSString* model = [tmp objectForKey:kAMXKeyModel];
        self.model = model;
        NSString* revision = [tmp objectForKey:kAMXKeyRevision];
        self.revision = revision;
        NSString* configName = [tmp objectForKey:kAMXKeyConfigName];
        self.configName = configName;
        NSString* configURLString = [tmp objectForKey:kAMXKeyConfigURL];
        self.configURLString = configURLString;
        NSString* hostFromConfigURL = nil;
        if ([configURLString length] > 0) {
            // We have a Config-URL property, which may be of the form:
            // <Config-URL=http://192.168.1.70>
            // If so, then it may have an IP address in it.
            NSURL* configURL = [NSURL URLWithString:configURLString];
            hostFromConfigURL = [configURL host];
        }
        self.hostFromConfigURL = hostFromConfigURL;
        // Put all of the parsed properties into an externally-accessible dictionary
        self.data = [NSDictionary dictionaryWithDictionary:tmp];
    }
}

// Override isEqual so we can determine if we already have this host
- (BOOL)isEqual:(id)object {
    BOOL ret = NO;

    if ([object isKindOfClass:[PJAMXBeaconHost class]]) {
        PJAMXBeaconHost* host = (PJAMXBeaconHost*)object;
        // Assume they are equal until we find some property that is different
        ret = YES;
        // We want to check everything that can't change,
        // and we assume that IP address *can* change, so
        // we don't want to check configURL
        if (ret && [self.uuid length] > 0 && [host.uuid length] > 0) {
            ret = [self.uuid isEqualToString:host.uuid];
        }
        if (ret && [self.sdkClass length] > 0 && [host.sdkClass length] > 0) {
            ret = [self.sdkClass isEqualToString:host.sdkClass];
        }
        if (ret && [self.make length] > 0 && [host.make length] > 0) {
            ret = [self.make isEqualToString:host.make];
        }
        if (ret && [self.model length] > 0 && [host.make length] > 0) {
            ret = [self.model isEqualToString:host.model];
        }
        if (ret && [self.revision length] > 0 && [host.revision length] > 0) {
            ret = [self.revision isEqualToString:host.revision];
        }
        if (ret && [self.configName length] > 0 && [host.configName length] > 0) {
            ret = [self.configName isEqualToString:host.configName];
        }
    }

    return ret;
}

@end
