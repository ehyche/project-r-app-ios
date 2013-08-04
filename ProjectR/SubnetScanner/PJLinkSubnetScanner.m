//
//  PJLinkSubnetScanner.m
//  ProjectR
//
//  Created by Eric Hyche on 8/2/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJLinkSubnetScanner.h"
#import "PJProjector.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
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

#define kDefaultPJLinkPort 4352

NSString* const PJLinkSubnetScannerScanningDidBeginNotification                  = @"PJLinkSubnetScannerScanningDidBeginNotification";
NSString* const PJLinkSubnetScannerScanningDidEndNotification                    = @"PJLinkSubnetScannerScanningDidEndNotification";
NSString* const PJLinkSubnetScannerScanningDidProgressNotification               = @"PJLinkSubnetScannerScanningDidProgressNotification";
NSString* const PJLinkSubnetScannerDiscoveredProjectorHostsDidChangeNotification = @"PJLinkSubnetScannerDiscoveredProjectorHostsDidChangeNotification";

NSString* const PJLinkSubnetScannerProgressKey     = @"PJLinkSubnetScannerProgressKey";
NSString* const PJLinkSubnetScannerNormalFinishKey = @"PJLinkSubnetScannerNormalFinishKey";

NSTimeInterval const kDefaultPJLinkScanningTimeout       = 1.0;
NSInteger      const kPJLinkScannerProjectorChallengeTag = 10;

@interface PJLinkSubnetScanner()
{
    BOOL             _scanning;
    BOOL             _abort;
    NSMutableArray*  _mutableProjectorHosts;
    NSMutableArray*  _mutableSubnetHosts;
    NSUInteger       _originalSubnetHostsCount;
    dispatch_queue_t _queue;
    GCDAsyncSocket*  _socket;
}

@end

@implementation PJLinkSubnetScanner

+ (PJLinkSubnetScanner*)sharedScanner {
    static PJLinkSubnetScanner* g_sharedPJLinkScanner = nil;
    static dispatch_once_t onceTokenPJLinkScanner;
    dispatch_once(&onceTokenPJLinkScanner, ^{
        g_sharedPJLinkScanner = [[PJLinkSubnetScanner alloc] init];
    });

    return g_sharedPJLinkScanner;
}

- (id)init {
    self = [super init];
    if (self) {
        _scanning              = NO;
        _abort                 = NO;
        _mutableProjectorHosts = [NSMutableArray array];
        _mutableSubnetHosts    = [NSMutableArray array];
        _queue                 = dispatch_queue_create([@"PJLinkSubnetScannerQueue" UTF8String], NULL);
        _socket                = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_queue];
    }

    return self;
}

- (BOOL)isScanning {
    __block BOOL ret = NO;

    dispatch_sync(_queue, ^{
        ret = _scanning;
    });

    return ret;
}

- (NSArray*)projectorHosts {
    __block NSArray* ret = nil;

    dispatch_sync(_queue, ^{
        ret = [NSArray arrayWithArray:_mutableProjectorHosts];
    });

    return ret;
}

- (void)start {
    dispatch_async(_queue, ^{
        if (!_scanning) {
            // Get the array of host addresses on our subnet
            // For example, if we are on WiFi address 192.168.100.43 and
            // our netmask is 255.255.255.0 then our list of addresses
            // would be 192.168.100.0, 192.168.100.1, 192.168.100.2, etc.
            // We exclude our own address from the list.
            NSArray* subnetHosts = [self hostsInSubnet];
            // Get the number of subnet hosts to scan
            _originalSubnetHostsCount = [subnetHosts count];
            // We have to have non-zero hosts to scan before we start
            if (_originalSubnetHostsCount > 0) {
                // Set the flag saying we are scanning
                _scanning = YES;
                // Save the hosts into the mutable array
                [_mutableSubnetHosts setArray:subnetHosts];
                // Send the notification saying we are beginning scanning
                [self postScanningDidBeginNotification];
                // Begin by scanning the next host in the queue
                [self scanNextHost];
            }
        }
    });
}

- (void)stop {
    dispatch_async(_queue, ^{
        if (_scanning) {
            _abort = YES;
        }
    });
}

#pragma mark - GCDAsyncSocketDelegate methods

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"socket:didConnectToHost:%@ port:%u", host, port);
    [_socket readDataToData:[GCDAsyncSocket CRData]
                withTimeout:kDefaultPJLinkScanningTimeout
                        tag:kPJLinkScannerProjectorChallengeTag];

}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"socket:didReadData:withTag:%ld length=%u", tag, [data length]);
    BOOL isProjector = NO;
    if ([data length] > 0) {
        // Convert to a string
        NSString* challenge = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        // If this is a PJLink projector, then the response has to start with "PJLINK"
        if ([challenge length] >= 6) {
            if ([challenge hasPrefix:@"PJLINK"]) {
                isProjector = YES;
            }
        }
    }
    [self handleScanResultForCurrentHost:isProjector];
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock
shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    NSLog(@"socket:shouldTimeoutReadWithTag:%ld elapsed:%.1f bytesDone:%u", tag, elapsed, length);
    return 0.0;
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    NSLog(@"socket:shouldTimeoutWriteWithTag:%ld elapsed:%.1f bytesDone:%u", tag, elapsed, length);
    return 0.0;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"socketDidDisconnect:withError:%@", err);
    [self handleScanResultForCurrentHost:NO];
}

#pragma mark - PJLinkSubnetScanner private methods

+ (NSString *)hostFromSockaddr4:(const struct sockaddr_in *)pSockaddr4
{
	char addrBuf[INET_ADDRSTRLEN];

	if (inet_ntop(AF_INET, &pSockaddr4->sin_addr, addrBuf, (socklen_t)sizeof(addrBuf)) == NULL)
	{
		addrBuf[0] = '\0';
	}

	return [NSString stringWithCString:addrBuf encoding:NSASCIIStringEncoding];
}

- (NSArray*)hostsInSubnet {
    NSArray* ret = @[];

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
        NSString* selfHost = [PJLinkSubnetScanner hostFromSockaddr4:&wifiAddress];
        // Copy our address and netmask into new structs
        struct sockaddr_in subnetAddress;
        memcpy(&subnetAddress, &wifiAddress, sizeof(wifiAddress));
        // Compute the AND of the address and netmask
        uint32_t address           = wifiAddress.sin_addr.s_addr;
        uint32_t netmask           = wifiNetmask.sin_addr.s_addr;
        uint32_t netmaskCompHost   = ~netmask;
        uint32_t addressNetmaskAND = address & netmask;
        // Compute the number of addresses we need to scan
        uint32_t netmaskCompNative = htonl(netmaskCompHost);
        NSUInteger numSubnetAddresses = netmaskCompNative + 1;
        NSMutableArray* tmp = [NSMutableArray arrayWithCapacity:numSubnetAddresses];
        // Compute each of the adddresses in the subnet
        for (NSUInteger i = 0; i < numSubnetAddresses; i++) {
            uint32_t addr_host = ntohl(i);
            uint32_t s_addr = addressNetmaskAND | addr_host;
            subnetAddress.sin_addr.s_addr = s_addr;
            NSString* hostStr = [PJLinkSubnetScanner hostFromSockaddr4:&subnetAddress];
            if ([hostStr length] > 0 && ![hostStr isEqualToString:selfHost]) {
                [tmp addObject:hostStr];
            }
        }
        ret = [NSArray arrayWithArray:tmp];
    }

    return ret;
}

- (void)postScanningDidBeginNotification {
    [self postScannerNotification:[NSNotification notificationWithName:PJLinkSubnetScannerScanningDidBeginNotification object:self]];
}

- (void)postScanningDidEndNotification:(BOOL)abort {
    BOOL normalFinish = !abort;
    [self postScannerNotification:[NSNotification notificationWithName:PJLinkSubnetScannerScanningDidEndNotification
                                                                object:self
                                                              userInfo:@{PJLinkSubnetScannerNormalFinishKey : @(normalFinish)}]];
}

- (void)postScanningDidProgressNotificationWithProgress:(CGFloat)progress {
    [self postScannerNotification:[NSNotification notificationWithName:PJLinkSubnetScannerScanningDidProgressNotification
                                                                object:self
                                                              userInfo:@{PJLinkSubnetScannerProgressKey: @(progress)}]];
}

- (void)postProjectorHostsDidChangeNotification {
    [self postScannerNotification:[NSNotification notificationWithName:PJLinkSubnetScannerDiscoveredProjectorHostsDidChangeNotification object:self]];
}

- (void)postScannerNotification:(NSNotification*)notification {
    dispatch_block_t block = ^{
        NSLog(@"postNotification:%@", notification);
        [[NSNotificationCenter defaultCenter] postNotification:notification];
	};
    // Ensure that we post the notification on the main thread
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)scanNextHost {
    if ([_mutableSubnetHosts count] > 0 && !_abort) {
        // Peek at the next host
        NSString* host = [_mutableSubnetHosts objectAtIndex:0];
        NSLog(@"scanNextHost %@", host);
        // Try to connect the socket to this host on the default PJLink port
        NSError* connectError = nil;
        BOOL connectRet = [_socket connectToHost:host
                                          onPort:kDefaultPJLinkPort
                                     withTimeout:kDefaultPJLinkScanningTimeout
                                           error:&connectError];
        if (!connectRet) {
            dispatch_async(_queue, ^{
                [self handleScanResultForCurrentHost:NO];
            });
        }
    } else {
        // Clear the flag saying we are scanning
        _scanning = NO;
        // Post the notification
        [self postScanningDidEndNotification:_abort];
    }
}

- (void)handleScanResultForCurrentHost:(BOOL)success {
    // Sanity check - there better be a host in the queue
    if ([_mutableSubnetHosts count] > 0) {
        // Dequeue the current host
        NSString* host = [_mutableSubnetHosts objectAtIndex:0];
        [_mutableSubnetHosts removeObjectAtIndex:0];
        NSLog(@"handleScanResultForCurrentHost:%u host=%@", success, host);
        // If we succeded, add it to the list of successful hosts
        if (success) {
            [_mutableProjectorHosts addObject:host];
            // Send out a notification saying our list of projectors found has changed
            [self postProjectorHostsDidChangeNotification];
        }
        // Compute the progress we've made
        NSUInteger numScanned = _originalSubnetHostsCount - [_mutableSubnetHosts count];
        CGFloat progress = ((CGFloat)numScanned) / ((CGFloat) _originalSubnetHostsCount);
        // Send out a notification of our progress
        [self postScanningDidProgressNotificationWithProgress:progress];
        // Safely disconnect the socket
        [_socket setDelegate:nil];
        [_socket disconnect];
        [_socket setDelegate:self];
        // Dispatch a new block to scan the next host
        dispatch_async(_queue, ^{
            [self scanNextHost];
        });
    }
}

@end
