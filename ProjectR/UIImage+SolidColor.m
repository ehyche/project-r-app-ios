//
//  UIImage+SolidColor.m
//  ProjectR
//
//  Created by Eric Hyche on 5/11/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "UIImage+SolidColor.h"

@implementation UIImage (SolidColor)

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size {
    CGRect fillRect = CGRectMake(0.0, 0.0, size.width, size.height);
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, fillRect);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
