//
//  PJProjectorConnectionStateView.m
//  ProjectR
//
//  Created by Eric Hyche on 5/25/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJProjectorConnectionStateView.h"

NSTimeInterval const kPJProjectorConnectingAnimationDuration =  2.0;

@interface PJProjectorConnectionStateView()

@property(nonatomic, strong) UIImage*     imageDisconnected;
@property(nonatomic, strong) UIImage*     imageConnected;
@property(nonatomic, strong) UIImage*     imageConnecting;
@property(nonatomic, assign) CGSize       viewSizeThatFits;
@property(nonatomic, strong) UIImageView* imageView;

@end

@implementation PJProjectorConnectionStateView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.imageConnected    = [UIImage imageNamed:@"projector_connected"];
        self.imageDisconnected = [UIImage imageNamed:@"projector_disconnected"];
        self.imageConnecting   = [UIImage animatedImageNamed:@"projector_connecting" duration:kPJProjectorConnectingAnimationDuration];
        // Compute the maximum size of these three images
        CGSize connectedSize    = [self.imageConnected size];
        CGSize disconnectedSize = [self.imageDisconnected size];
        CGSize connectingSize   = [self.imageConnecting size];
        CGSize viewSize = CGSizeZero;
        viewSize = CGSizeMake(MAX(viewSize.width, connectedSize.width),    MAX(viewSize.height, connectedSize.height));
        viewSize = CGSizeMake(MAX(viewSize.width, disconnectedSize.width), MAX(viewSize.height, disconnectedSize.height));
        viewSize = CGSizeMake(MAX(viewSize.width, connectingSize.width),   MAX(viewSize.height, connectingSize.height));
        self.viewSizeThatFits = viewSize;
        // Create the image view
        self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, frame.size.width, frame.size.height)];
        self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:self.imageView];
        // Set the initial connection state to an invalid value
        // so that the first time that setConnectionState: will
        // detect a change.
        _connectionState = NumPJConnectionStates;
    }

    return self;
}

- (void)setConnectionState:(PJConnectionState)connectionState {
    if (_connectionState != connectionState) {
        _connectionState = connectionState;
        [self updateConnectionImage];
    }
}

- (CGSize)sizeThatFits:(CGSize)size {
    return self.viewSizeThatFits;
}

#pragma mark - PJProjectorConnectionStateView private methods

- (void)updateConnectionImage {
    UIImage* image = nil;
    switch (self.connectionState) {
        case PJConnectionStateConnected:
            image = self.imageConnected;
            break;
        case PJConnectionStateConnecting:
            image = self.imageConnecting;
            break;
        case PJConnectionStateConnectionError:
            image = self.imageDisconnected;
            break;
        case PJConnectionStateDiscovered:
            image = self.imageDisconnected;
            break;
        case PJConnectionStatePasswordError:
            image = self.imageDisconnected;
            break;
        default:
            image = self.imageDisconnected;
            break;
    }
    if (image != nil) {
        self.imageView.image = image;
    }
}

@end
