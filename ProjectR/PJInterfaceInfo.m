//
//  PJInterfaceInfo.m
//  ProjectR
//
//  Created by Eric Hyche on 8/4/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJInterfaceInfo.h"
#import <CFNetwork/CFNetwork.h>
#import <arpa/inet.h>
#import <fcntl.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <netinet/in.h>
#import <net/if.h>
#import <sys/socket.h>
#import <sys/types.h>
#import <sys/ioctl.h>
#import <sys/poll.h>
#import <sys/uio.h>
#import <unistd.h>

@implementation PJInterfaceInfo

- (id)init {
    self = [super init];
    if (self) {
        // Initialize address and netmask
        struct sockaddr_in wifiAddress;
        struct sockaddr_in wifiNetmask;
        wifiAddress.sin_len = 0;
        wifiNetmask.sin_len = 0;
        // First, find the IP4 address and netmask of the WiFi interface
        struct ifaddrs*       addrs  = NULL;
        const struct ifaddrs* cursor = NULL;
        int                   getRet = getifaddrs(&addrs);
        if (getRet == 0) {
            // Set the cursor to the beginning
            cursor = addrs;
            while (cursor != NULL) {
                if (strcmp(cursor->ifa_name, "en0") == 0 && cursor->ifa_addr->sa_family == AF_INET) {
                    memcpy(&wifiAddress, cursor->ifa_addr, sizeof(wifiAddress));
                    memcpy(&wifiNetmask, cursor->ifa_netmask, sizeof(wifiNetmask));
                    break;
                }
                cursor = cursor->ifa_next;
            }
            freeifaddrs(addrs);
        }
        // Did we find a WiFi address and netmask
        if (wifiAddress.sin_len > 0 && wifiNetmask.sin_len > 0) {
            // Get a string representation of our address
            _host    = [PJInterfaceInfo hostFromSockaddr4:&wifiAddress];
            _netmask = [PJInterfaceInfo hostFromSockaddr4:&wifiNetmask];
        }
    }

    return self;
}

+ (uint32_t)integerHostForHost:(NSString*)host {
    uint32_t ret = 0;

    if ([host length] > 0) {
        NSArray* hostComponents = [host componentsSeparatedByString:@"."];
        NSUInteger hostComponentsCount = [hostComponents count];
        if (hostComponentsCount == 4) {
            for (NSUInteger i = 0; i < hostComponentsCount; i++) {
                NSString* ithComponent = [hostComponents objectAtIndex:i];
                uint32_t ithComponentInt = [ithComponent integerValue];
                // Shift this value up by the appropriate number of bits
                uint32_t ithComponentIntShifted = ithComponentInt << ((3-i)*8);
                ret |= ithComponentIntShifted;
            }
        }
    }

    return ret;
}

#pragma mark - PJInterfaceInfo private methods

+ (NSString *)hostFromSockaddr4:(const struct sockaddr_in *)pSockaddr4
{
	char addrBuf[INET_ADDRSTRLEN];

	if (inet_ntop(AF_INET, &pSockaddr4->sin_addr, addrBuf, (socklen_t)sizeof(addrBuf)) == NULL)
	{
		addrBuf[0] = '\0';
	}

	return [NSString stringWithCString:addrBuf encoding:NSASCIIStringEncoding];
}

@end
