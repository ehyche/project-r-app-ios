//
//  PJProjectorTableViewCell.m
//  ProjectR
//
//  Created by Eric Hyche on 5/19/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJProjectorTableViewCell.h"
#import "PJProjector.h"
#import "PJProjectorManager.h"

static NSString* const kPJProjectorTableViewCellReuseID = @"kPJProjectorTableViewCellReuseID";

NSTimeInterval const kPJProjectorTableViewCellAnimationDuration =  2.0;
CGFloat        const kPJProjectorTableViewCellHeight            = 44.0;

@interface PJProjectorTableViewCell()

@property(nonatomic,strong) UIImage* imageDisconnected;
@property(nonatomic,strong) UIImage* imageConnected;
@property(nonatomic,strong) UIImage* imageConnecting;

@end

@implementation PJProjectorTableViewCell

+ (NSString*)reuseID {
    return kPJProjectorTableViewCellReuseID;
}

+ (CGFloat)heightForProjector:(PJProjector*)projector containerWidth:(CGFloat)width {
    return kPJProjectorTableViewCellHeight;
}

- (void)dealloc {
    [self unsubscribeFromAllNotifications];
}

- (id)init {
    return [self initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[PJProjectorTableViewCell reuseID]];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.imageConnected    = [UIImage imageNamed:@"projector_connected"];
        self.imageDisconnected = [UIImage imageNamed:@"projector_disconnected"];
        self.imageConnecting   = [UIImage animatedImageNamed:@"projector_connecting" duration:kPJProjectorTableViewCellAnimationDuration];
        self.accessoryType     = UITableViewCellAccessoryDisclosureIndicator;
    }

    return self;
}

- (void)setProjector:(PJProjector *)projector {
    if (_projector != projector) {
        [self unsubscribeFromNotificationsForProjector:_projector];
        _projector = projector;
        [self subscribeToNotificationsForProjector:_projector];
        [self dataDidChange];
    }
}

#pragma mark - PJProjectorTableViewCell private methods

- (void)subscribeToNotificationsForProjector:(PJProjector*)projector {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(projectorConnectionStateDidChange:)
                                                 name:PJProjectorConnectionStateDidChangeNotification
                                               object:projector];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(projectorDidChange:)
                                                 name:PJProjectorDidChangeNotification
                                               object:projector];
}

- (void)unsubscribeFromNotificationsForProjector:(PJProjector*)projector {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PJProjectorConnectionStateDidChangeNotification
                                                  object:projector];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PJProjectorDidChangeNotification
                                                  object:projector];
}

- (void)unsubscribeFromAllNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dataDidChange {
    [self updateConnectionImage];
    self.textLabel.text = [PJProjectorManager displayNameForProjector:self.projector];
}

- (void)updateConnectionImage {
    UIImage* image = nil;
    switch (self.projector.connectionState) {
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

- (void)projectorDidChange:(NSNotification*)notification {
}

- (void)projectorConnectionStateDidChange:(NSNotification*)notification {
    [self updateConnectionImage];
    self.detailTextLabel.text = [PJProjectorManager stringForConnectionState:self.projector.connectionState];
}

@end
