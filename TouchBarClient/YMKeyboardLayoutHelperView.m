//
//  YMKeyboardLayoutHelperView.m
//  TouchBar
//
//  Created by Vincent Le Normand on 14/11/2016.
//  Copyright © 2016 Bikkelbroeders. All rights reserved.
//

#import "YMKeyboardLayoutHelperView.h"

@interface YMKeyboardLayoutHelperView ()
@property (nonatomic) CGFloat duration;
@property (nonatomic) UIViewAnimationCurve animationCurve;
@property (nonatomic) NSLayoutConstraint *heightConstraint;
@property (nonatomic) UIGestureRecognizer *tapRecognizer;
@property (nonatomic, weak) UIView *keyboard;
@end

@implementation YMKeyboardLayoutHelperView

- (id)init
{
	self = [super init];
	if (self) {

	}
	return self;
}

- (void) awakeFromNib {
	[super awakeFromNib];
	
	self.translatesAutoresizingMaskIntoConstraints = NO;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	
	NSDictionary *views = @{@"self": self};
	self.heightConstraint = [[NSLayoutConstraint constraintsWithVisualFormat:@"V:[self(0)]" options:0 metrics:nil views:views] lastObject];
	[self addConstraint:self.heightConstraint];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Keyboard Methods

- (void)keyboardWillShow:(NSNotification *)notification
{
	// Save the height of keyboard and animation duration
	NSDictionary *userInfo = [notification userInfo];
	CGRect keyboardRect = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
	CGRect convertedRect = [self convertRect:keyboardRect fromView:nil]; // Convert from window coordinates
	self.animationCurve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
	self.duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	self.heightConstraint.constant = CGRectGetHeight(convertedRect);
	
	
	[self animateSizeChange];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	self.heightConstraint.constant = 0.0f;
	
	[self animateSizeChange];
}

#pragma mark - Auto Layout

- (void)animateSizeChange
{
	[self setNeedsUpdateConstraints];
	
	// Left shift to change animationCurve to animationOptions
	// (see UIViewAnimationOptions docs/header for constants enum)
	UIViewAnimationOptions options = self.animationCurve << 16;
	
	// Animate transition
	[UIView animateWithDuration:self.duration delay:0 options:options animations:^{
		[self.superview layoutIfNeeded];
	} completion:nil];
}

@end
