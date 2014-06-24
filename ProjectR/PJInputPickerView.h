//
//  PJInputPickerView.h
//  ProjectR
//
//  Created by Eric Hyche on 6/21/14.
//  Copyright (c) 2014 Eric Hyche. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PJInputPickerView;

@protocol PJInputPickerViewDelegate <NSObject>

@required
- (void)inputPickerViewDidCancel:(PJInputPickerView *)inputPicker;
- (void)inputPickerView:(PJInputPickerView *)inputPicker didSelectInputWithName:(NSString *)inputName;

@end

@interface PJInputPickerView : UIView

@property(nonatomic,weak) id<PJInputPickerViewDelegate> delegate;
@property(nonatomic,copy) NSArray*                      inputNames;

- (void)showHide:(BOOL)show animated:(BOOL) animated withCompletion:(void (^)(BOOL finished))completion;

@end
