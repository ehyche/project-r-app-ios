//
//  PJInputPickerView.m
//  ProjectR
//
//  Created by Eric Hyche on 6/21/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import "PJInputPickerView.h"

CGFloat const kPJInputPickerViewToolbarHeight      =  44.0;
CGFloat const kPJInputPickerViewPickerHeight       = 160.0;
CGFloat const kPJInputPickerViewDimmedAlpha        =   0.5;
CGFloat const kPJInputPickerViewTransitionDuration =   0.25;

@interface PJInputPickerView() <UIPickerViewDataSource, UIPickerViewDelegate>

@property(nonatomic,strong) UIPickerView* pickerView;
@property(nonatomic,strong) UIToolbar*    toolbarView;
@property(nonatomic,strong) UIView*       containerView;
@property(nonatomic,strong) UIView*       dimmingView;

@end

@implementation PJInputPickerView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        CGRect dimmingFrame = CGRectMake(0.0, 0.0, frame.size.width, frame.size.height);
        _dimmingView = [[UIView alloc] initWithFrame:dimmingFrame];
        _dimmingView.backgroundColor = [UIColor blackColor];
        _dimmingView.alpha = 0.0;
        _dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_dimmingView];
        CGFloat containerHeight = kPJInputPickerViewToolbarHeight + kPJInputPickerViewPickerHeight;
        CGRect containerFrame = CGRectMake(0.0,
                                           frame.size.height,
                                           frame.size.width,
                                           containerHeight);
        _containerView = [[UIView alloc] initWithFrame:containerFrame];
        [self addSubview:_containerView];
        
        CGRect toolbarFrame = CGRectMake(0.0, 0.0, frame.size.width, kPJInputPickerViewToolbarHeight);
        _toolbarView = [[UIToolbar alloc] initWithFrame:toolbarFrame];
        _toolbarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        
        _toolbarView.items = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonAction:)],
                               [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
                               [[UIBarButtonItem alloc] initWithTitle:@"Select" style:UIBarButtonItemStylePlain target:self action:@selector(selectButtonAction:)]];
        [_containerView addSubview:_toolbarView];
        
        CGRect pickerFrame = CGRectMake(0.0, kPJInputPickerViewToolbarHeight, frame.size.width, kPJInputPickerViewPickerHeight);
        _pickerView = [[UIPickerView alloc] initWithFrame:pickerFrame];
        _pickerView.backgroundColor = [UIColor whiteColor];
        _pickerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _pickerView.delegate = self;
        _pickerView.dataSource = self;
        [_containerView addSubview:_pickerView];
    }
    
    return self;
}

- (void)showHide:(BOOL)show animated:(BOOL) animated withCompletion:(void (^)(BOOL finished))completion {
    CGFloat containerHeight = kPJInputPickerViewToolbarHeight + kPJInputPickerViewPickerHeight;
    CGRect containerFrameHidden = CGRectMake(0.0,
                                             self.frame.size.height,
                                             self.frame.size.width,
                                             containerHeight);
    CGRect containerFrameShown = CGRectMake(0.0,
                                            self.frame.size.height - containerHeight,
                                            self.frame.size.width,
                                            containerHeight);
    if (show) {
        if (animated) {
            self.dimmingView.alpha = 0.0;
            self.containerView.frame = containerFrameHidden;
            [UIView animateWithDuration:kPJInputPickerViewTransitionDuration
                             animations:^{
                                 self.dimmingView.alpha = kPJInputPickerViewDimmedAlpha;
                                 self.containerView.frame = containerFrameShown;
                             }
                             completion:^(BOOL finished) {
                                 if (completion) {
                                     completion(finished);
                                 }
                             }];
            
        } else {
            self.dimmingView.alpha = 0.0;
            self.containerView.frame = containerFrameShown;
        }
    } else {
        if (animated) {
            self.dimmingView.alpha = kPJInputPickerViewDimmedAlpha;
            self.containerView.frame = containerFrameShown;
            [UIView animateWithDuration:kPJInputPickerViewTransitionDuration
                             animations:^{
                                 self.dimmingView.alpha = 0.0;
                                 self.containerView.frame = containerFrameHidden;
                             }
                             completion:^(BOOL finished) {
                                 if (completion) {
                                     completion(finished);
                                 }
                             }];
            
        } else {
            self.dimmingView.alpha = 0.0;
            self.containerView.frame = containerFrameHidden;
        }
    }
}

#pragma mark - UIPickerViewDataSource methods

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [_inputNames count];
}

#pragma mark - UIPickerViewDelegate methods

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [_inputNames objectAtIndex:row];
}

#pragma mark - PJInputPickerView private methods

- (void)cancelButtonAction:(id)sender {
    [self.delegate inputPickerViewDidCancel:self];
}

- (void)selectButtonAction:(id)sender {
    NSInteger selectedRow = [self.pickerView selectedRowInComponent:0];
    NSString *selectedInputName = [_inputNames objectAtIndex:selectedRow];
    [self.delegate inputPickerView:self didSelectInputWithName:selectedInputName];
}

@end
