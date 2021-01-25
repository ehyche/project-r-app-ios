//
//  PJLinkSubnetScanner.h
//  ProjectR
//
//  Created by Eric Hyche on 8/2/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const PJLinkSubnetScannerScanningDidBeginNotification;
extern NSString* const PJLinkSubnetScannerScanningDidEndNotification;
extern NSString* const PJLinkSubnetScannerScanningDidProgressNotification;
extern NSString* const PJLinkSubnetScannerScannedHostDidChangeNotification;
extern NSString* const PJLinkSubnetScannerDiscoveredProjectorHostsDidChangeNotification;

extern NSString* const PJLinkSubnetScannerProgressKey;
extern NSString* const PJLinkSubnetScannerNormalFinishKey;
extern NSString* const PJLinkSubnetScannerScannedHostKey;

@interface PJLinkSubnetScanner : NSObject

// This should be set to YES if we should include the
// device address in the set of IP addresses we scan.
// Mostly this would just be used for testing when using
// the simulator and the emulator on the same machine.
@property(nonatomic,assign) BOOL shouldIncludeDeviceAddress;

@property(nonatomic,readonly,getter=isScanning) BOOL      scanning;
@property(nonatomic,readonly,assign)            CGFloat   progress; // In the range [0.0,1.0]
@property(nonatomic,readonly,copy)              NSString* scannedHost;
@property(nonatomic,readonly,copy)              NSArray*  projectorHosts; // Array of NSString's containing IP addresses like @"192.168.0.124"

+ (PJLinkSubnetScanner*)sharedScanner;

- (void)start;
- (void)stop;

// KVO compliant accessors for .projectorHosts
- (NSUInteger)countOfProjectorHosts;
- (id)objectInProjectorHostsAtIndex:(NSUInteger)index;
- (NSArray*)projectorHostsAtIndexes:(NSIndexSet *)indexes;

@end
