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

@property(nonatomic,readwrite,retain) NSDictionary* data;

@end

@implementation PJAMXBeaconHost

+ (BOOL)isAMXBeaconReply:(NSString*)reply {
    return [reply hasPrefix:kAMXBeaconHeader];
}

+ (PJAMXBeaconHost*)beaconHostFromBeaconReply:(NSString*)reply {
    PJAMXBeaconHost* ret = nil;

    // Make sure the first four characters are AMXB
    if ([reply hasPrefix:kAMXBeaconHeader]) {
        // Create the PJAMXBeaconHost object
        ret = [[PJAMXBeaconHost alloc] init];
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
        if ([uuid length] > 0) {
            ret.uuid = uuid;
        }
        NSString* sdkClass = [tmp objectForKey:kAMXKeySDKClass];
        if ([sdkClass length] > 0) {
            ret.sdkClass = sdkClass;
        }
        NSString* make = [tmp objectForKey:kAMXKeyMake];
        if ([make length] > 0) {
            ret.make = make;
        }
        NSString* model = [tmp objectForKey:kAMXKeyModel];
        if ([model length] > 0) {
            ret.model = model;
        }
        NSString* revision = [tmp objectForKey:kAMXKeyRevision];
        if ([revision length] > 0) {
            ret.revision = revision;
        }
        NSString* configName = [tmp objectForKey:kAMXKeyConfigName];
        if ([configName length] > 0) {
            ret.configName = configName;
        }
        NSString* configURL = [tmp objectForKey:kAMXKeyConfigURL];
        if ([configURL length] > 0) {
            ret.configURL = configURL;
        }
        // Put all of the parsed properties into an externally-accessible dictionary
        ret.data = [NSDictionary dictionaryWithDictionary:tmp];
    }

    return ret;
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
