//
//  PJLinkSubnetScanner.h
//  ProjectR
//
//  Created by Eric Hyche on 8/2/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* const PJLinkSubnetScannerScanningDidBeginNotification;
NSString* const PJLinkSubnetScannerScanningDidEndNotification;
NSString* const PJLinkSubnetScannerScanningDidProgressNotification;
NSString* const PJLinkSubnetScannerScannedHostDidChangeNotification;
NSString* const PJLinkSubnetScannerDiscoveredProjectorHostsDidChangeNotification;

NSString* const PJLinkSubnetScannerProgressKey;
NSString* const PJLinkSubnetScannerNormalFinishKey;
NSString* const PJLinkSubnetScannerScannedHostKey;

@interface PJLinkSubnetScanner : NSObject

@property(nonatomic,readonly,getter=isScanning) BOOL      scanning;
@property(nonatomic,readonly,assign)            CGFloat   progress; // In the range [0.0,1.0]
@property(nonatomic,readonly,copy)              NSString* scannedHost;
@property(nonatomic,readonly,copy)              NSArray*  projectorHosts; // Array of NSString's containing IP addresses like @"192.168.0.124"

+ (PJLinkSubnetScanner*)sharedScanner;

- (void)start;
- (void)stop;

@end
