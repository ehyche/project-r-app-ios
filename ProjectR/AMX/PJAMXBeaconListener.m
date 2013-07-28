//
//  PJAMXBeaconListener.m
//  PJController
//
//  Created by Eric Hyche on 3/8/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>
#import "PJAMXBeaconListener.h"
#import "GCDAsyncUdpSocket.h"
#import "PJAMXBeaconHost.h"

#define AMX_BEACON_PORT     9131
#define AMX_MULTICAST_GROUP @"239.255.250.250"
#define AMX_PING            @"AMX\r"
#define AMX_TAG_PING        10


NSString* const PJAMXBeaconHostsDidChangeNotification = @"PJAMXBeaconHostsDidChangeNotification";

@interface PJAMXBeaconListener() <GCDAsyncUdpSocketDelegate>
{
    dispatch_queue_t   _queue;
	GCDAsyncUdpSocket* _socket;
    BOOL               _listening;
    NSMutableArray*    _beaconHosts;
}

@end

@implementation PJAMXBeaconListener

-(NSArray*) hosts
{
    __block NSArray* ret = nil;

    dispatch_sync(_queue, ^{
        ret = [NSArray arrayWithArray:_beaconHosts];
    });

    return ret;
}

-(BOOL) isListening
{
	__block BOOL ret;

	dispatch_sync(_queue, ^{
		ret = _listening;
	});

	return ret;
}

+(PJAMXBeaconListener*) sharedListener
{
    static PJAMXBeaconListener* g_sharedAMXBeaconListener = nil;
    static dispatch_once_t onceTokenListener;
    dispatch_once(&onceTokenListener, ^{
        g_sharedAMXBeaconListener = [[PJAMXBeaconListener alloc] init];
    });
    
    return g_sharedAMXBeaconListener;
}

-(id) init
{
    self = [super init];
    if (self)
    {
        // Create a serial dispatch queue to do fetches on
        _queue = dispatch_queue_create([@"PJAMXBeaconListenerQueue" UTF8String], DISPATCH_QUEUE_SERIAL);
        // Create the UDP socket to listen on
        _socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:_queue];
        // Create an empty dictionary initially
        _beaconHosts = [NSMutableArray array];
    }

    return self;
}

-(BOOL) startListening:(NSError**) pError
{
    __block BOOL     ret = NO;
    __block NSError* err = nil;

    dispatch_sync(_queue, ^{
        @autoreleasepool
        {
            if (!_listening)
            {
                // Bind the UDP socket to the port
                NSError* error = nil;
                if ([_socket bindToPort:AMX_BEACON_PORT error:&error])
                {
                    // Join the multicast group
                    if ([_socket joinMulticastGroup:AMX_MULTICAST_GROUP error:&error])
                    {
                        // Begin receiving datagrams on this port
                        if ([_socket beginReceiving:&error])
                        {
                            NSLog(@"Listen socket set up successfully, socket = %@", _socket);
                            // Set the flag saying we are now listening
                            _listening = YES;
                        }
                        else
                        {
                            NSLog(@"Could not begin receiving on UDP socket, error = %@", error);
                            [_socket close];
                        }
                    }
                    else
                    {
                        NSLog(@"Could not join multicast group, error = %@", error);
                        [_socket close];
                    }
                }
                else
                {
                    NSLog(@"Could not bind UDP socket to port, error = %@", error);
                }
                // Save the error (if there was one)
                err = error;
            }
            // Set the return value to the same as _isListening
            ret = _listening;
        }
    });

    if (pError)
    {
        *pError = err;
    }

    return ret;
}

-(void) stopListening
{
    dispatch_sync(_queue, ^{
        @autoreleasepool
        {
            if (_listening)
            {
                // Leave the multicast group
                NSError* error = nil;
                BOOL bLeaveRet = [_socket leaveMulticastGroup:AMX_MULTICAST_GROUP error:&error];
                if (!bLeaveRet)
                {
                    NSLog(@"Could not leave multicast group, error = %@", error);
                }
                // We just need to close the UDP socket
                [_socket close];
                // Clear the flag which says we are listening
                _listening = NO;
                NSLog(@"AMX Beacon Listening stopped.");
            }
        }
    });
}

-(void) ping
{
    dispatch_async(_queue, ^{
        // Create data for the "AMX\r" string
        NSData* pingData = [AMX_PING dataUsingEncoding:NSUTF8StringEncoding];
        // Send an "AMX\r" on the multicast address
        [_socket sendData:pingData
                   toHost:AMX_MULTICAST_GROUP
                     port:AMX_BEACON_PORT
              withTimeout:-1
                      tag:AMX_TAG_PING];
    });
}

- (NSUInteger)countOfHosts {
    __block NSUInteger ret = 0;

    dispatch_sync(_queue, ^{
        ret = [_beaconHosts count];
    });

    return ret;
}

- (id)objectInHostsAtIndex:(NSUInteger)index {
    __block id ret = nil;

    dispatch_sync(_queue, ^{
        ret = [_beaconHosts objectAtIndex:index];
    });

    return ret;
}

- (NSArray*)hostsAtIndexes:(NSIndexSet *)indexes {
    __block NSArray* ret = nil;

    dispatch_sync(_queue, ^{
        ret = [_beaconHosts objectsAtIndexes:indexes];
    });

    return ret;
}

#pragma mark -
#pragma mark GCDAsyncUdpSocketDelegate methods

-(void) udpSocket:(GCDAsyncUdpSocket*) sock didConnectToAddress:(NSData*) address
{
    NSLog(@"udpSocket:%@ didConnectToAddress:%@", sock, address);
}

-(void) udpSocket:(GCDAsyncUdpSocket*) sock didNotConnect:(NSError*) error
{
    NSLog(@"udpSocket:%@ didNotConnect:%@", sock, error);
}

-(void) udpSocket:(GCDAsyncUdpSocket*) sock didSendDataWithTag:(long) tag
{
    NSLog(@"udpSocket:%@ didSendDataWithTag:%ld", sock, tag);
}

-(void) udpSocket:(GCDAsyncUdpSocket*) sock didNotSendDataWithTag:(long) tag dueToError:(NSError*) error
{
    NSLog(@"udpSocket:%@ didNotSendDataWithTag:%ld dueToError:%@", sock, tag, error);
}

-(void)   udpSocket:(GCDAsyncUdpSocket*) sock
     didReceiveData:(NSData*) data
        fromAddress:(NSData*) address
  withFilterContext:(id) filterContext
{
    // Convert the data to a string
    NSString* dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"udpSocket:%@ didReceiveData:\"%@\" fromAddress:%@ withFilterContext:%@", sock, dataStr, address, filterContext);
    // Create a PJAMXBeaconHost from this data string
    PJAMXBeaconHost* beaconHost = [PJAMXBeaconHost beaconHostFromBeaconReply:dataStr];
    // Get the host from the address
    NSString* host = nil;
    BOOL bConvertRet = [GCDAsyncUdpSocket getHost:&host port:NULL fromAddress:address];
    if (bConvertRet)
    {
        // We were able to convert the address so set these into the host object
        beaconHost.ipAddressFromSocket = host;
    }
    // Are we already tracking this beacon?
    // We have overridden isEqual on PJAMXBeaconHost so that we
    // only check things that should not change (things that are
    // properties of the hardware like UUID).
    BOOL sendNotification = NO;
    // Get the index of the existing host from the array
    NSUInteger hostIndex = [_beaconHosts indexOfObject:beaconHost];
    if (hostIndex != NSNotFound) {
        PJAMXBeaconHost* existingHost = [_beaconHosts objectAtIndex:hostIndex];
        // Update the existing host with the reply string
        [existingHost updateFromBeaconReply:dataStr];
        // Update the IP address
        if (![existingHost.ipAddressFromSocket isEqualToString:beaconHost.ipAddressFromSocket]) {
            existingHost.ipAddressFromSocket = beaconHost.ipAddressFromSocket;
            sendNotification = YES;
        }
        // Update the date of last reception
        existingHost.dateOfLastReception = [NSDate date];
    } else {
        // Set the last date on this object
        beaconHost.dateOfLastReception = [NSDate date];
        // We don't have this host at all, so add it
        // to the array and definitely send the notification
        [_beaconHosts addObject:beaconHost];
        sendNotification = YES;
    }
    // Are we supposed to send out a notification?
    if (sendNotification)
    {
        // Re-sort the array
        [_beaconHosts sortUsingComparator:^(id obj1, id obj2) {
            PJAMXBeaconHost* host1 = (PJAMXBeaconHost*)obj1;
            PJAMXBeaconHost* host2 = (PJAMXBeaconHost*)obj2;
            return [host1.ipAddressFromSocket compare:host2.ipAddressFromSocket];
        }];
        // Send it out on the main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:PJAMXBeaconHostsDidChangeNotification object:self];
        });
    }
}

-(void) udpSocketDidClose:(GCDAsyncUdpSocket*) sock withError:(NSError*) error
{
    NSLog(@"udpSocketDidClose:%@ withError:%@", sock, error);
}

@end
