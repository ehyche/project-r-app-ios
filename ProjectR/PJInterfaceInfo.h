//
//  PJInterfaceInfo.h
//  ProjectR
//
//  Created by Eric Hyche on 8/4/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PJInterfaceInfo : NSObject

+ (uint32_t)integerHostForHost:(NSString*)host;

@property(nonatomic,copy) NSString* host;
@property(nonatomic,copy) NSString* netmask;

@end
