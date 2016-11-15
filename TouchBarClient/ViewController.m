//
//  ViewController.m
//  TouchBarClient
//
//  Created by Robbert Klarenbeek on 02/11/2016.
//  Copyright © 2016 Bikkelbroeders. All rights reserved.
//

#import "ViewController.h"

#import "Peertalk.h"
#import "Protocol.h"

static const NSTimeInterval kAnimationDuration = 0.5;

@interface FakeTextField : UITextField
@property BOOL ctrlPressed;
@property BOOL cmdPressed;
@property BOOL altPressed;
@end

@interface ViewController () <PTChannelDelegate,UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIView *backgroundView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *aspectRatioConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;
@property (weak, nonatomic) IBOutlet UILabel *instructionLabel;

@property FakeTextField * textField;
@end

@implementation ViewController {
    PTChannel *_listenChannel;
    PTChannel *_peerChannel;
    BOOL _active;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.textField = [[FakeTextField alloc] init];
	self.textField.delegate = self;
	[self.view addSubview:self.textField];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopListening) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startListening) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self startListening];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self stopListening];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    [super viewDidDisappear:animated];
}

- (void)startListening {
    [self stopListening];
    
    PTChannel *channel = [PTChannel channelWithDelegate:self];
    [channel listenOnPort:kProtocolPort IPv4Address:INADDR_LOOPBACK callback:^(NSError *error) {
        if (error != nil) {
            NSLog(@"Failed to listen on localhost:%d: %@", kProtocolPort, error);
        } else {
            _listenChannel = channel;
			[self.textField becomeFirstResponder];
        }
    }];
}

- (void)stopListening {
    [self deactivateTouchBar:NO];
    
    if (_listenChannel) {
        [_listenChannel close];
        _listenChannel = nil;
		[self.textField resignFirstResponder];
    }
    
    if (_peerChannel) {
        [_peerChannel close];
        _peerChannel = nil;
    }
}

- (void) sendMouseEvent:(MouseEvent)event withType:(ProtocolFrameType)type {
	// XXX hardcoded 2, because the touch bar is rendered @2x
	
	
	NSData* data = [NSData dataWithBytes:&event length:sizeof(event)];
	CFDataRef immutableSelf = CFBridgingRetain([data copy]);
	dispatch_data_t payload = dispatch_data_create(data.bytes, data.length, dispatch_get_main_queue(), ^{
		CFRelease(immutableSelf);
	});
	
	[_peerChannel sendFrameOfType:type tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
		if (error) {
			NSLog(@"Failed to send message: %@", error);
		}
	}];
}

- (IBAction)trackpadRecognizerFired:(UIGestureRecognizer*)recognizer {
	if (!_peerChannel || !_active) return;
	
	MouseEvent event;
	CGPoint location = [recognizer locationInView:_imageView];
	CGFloat scale = 2 * _imageView.frame.size.width / _imageView.image.size.width;
	event.x = location.x / scale;
	event.y = location.y / scale;

	if([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
		if (recognizer.state == UIGestureRecognizerStateBegan) {
		} else if (recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateEnded) {
			event.type = MouseEventTypeDown;
			[self sendMouseEvent:event withType:ProtocolFrameTypeTrackpadEvent];
			event.type = MouseEventTypeUp;
			[self sendMouseEvent:event withType:ProtocolFrameTypeTrackpadEvent];

//		} else if (recognizer.state == UIGestureRecognizerStateChanged) {
//			event.type = MouseEventTypeDragged;
		} else {
			return;
		}
	}
	else {
		static MouseEventType eventType;
		if (recognizer.state == UIGestureRecognizerStateBegan) {
			event.type = MouseEventTypeDown;
			if(recognizer.numberOfTouches==2) {
				eventType = MouseEventTypeScroll;
			}
			else if (recognizer.numberOfTouches==1) {
				eventType = MouseEventTypeDragged;
			}
			
		} else if (recognizer.state == UIGestureRecognizerStateChanged) {
			if(recognizer.numberOfTouches==2) {
				eventType = MouseEventTypeScroll;
			}
			event.type = eventType;
		} else {
			return;
		}
		[self sendMouseEvent:event withType:ProtocolFrameTypeTrackpadEvent];
	}
	
}

- (IBAction)recognizerFired:(UIGestureRecognizer*)recognizer {
    if (!_peerChannel || !_active) return;
    
    MouseEvent event;

    if (recognizer.state == UIGestureRecognizerStateBegan) {
        event.type = MouseEventTypeDown;
    } else if (recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateEnded) {
        event.type = MouseEventTypeUp;
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        event.type = MouseEventTypeDragged;
    } else {
        return;
    }

    // XXX hardcoded 2, because the touch bar is rendered @2x
    CGFloat scale = 2 * _imageView.frame.size.width / _imageView.image.size.width;
    CGPoint location = [recognizer locationInView:_imageView];

    event.x = location.x / scale;
    event.y = location.y / scale;

	[self sendMouseEvent:event withType:ProtocolFrameTypeMouseEvent];
}

- (void)activateTouchBar:(BOOL)animated {
    [self.view layoutIfNeeded];
    _bottomConstraint.constant = 0;
    _active = YES;

    if (animated) {
        [UIView animateWithDuration:kAnimationDuration animations:^{
            _instructionLabel.alpha = 0;
            [self.view layoutIfNeeded];
        }];
    } else {
        _instructionLabel.alpha = 0;
    }
}

- (void)deactivateTouchBar:(BOOL)animated {
    [self.view layoutIfNeeded];
    _bottomConstraint.constant = -_backgroundView.frame.size.height;
    _active = NO;

    if (animated) {
        [UIView animateWithDuration:kAnimationDuration animations:^{
            _instructionLabel.alpha = 1;
            [self.view layoutIfNeeded];
        }];
    } else {
        _instructionLabel.alpha = 1;
    }
}

#pragma mark - PTChannelDelegate

- (void)ioFrameChannel:(PTChannel*)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(PTData*)payload {
    switch (type) {
        case ProtocolFrameTypeImage: {
            if (payload.data == nil) break;
            UIImage *image = [UIImage imageWithData:[NSData dataWithBytes:payload.data length:payload.length]];
            _imageView.image = image;
            
            [_imageView removeConstraint:_aspectRatioConstraint];
            _aspectRatioConstraint = [NSLayoutConstraint constraintWithItem:_aspectRatioConstraint.firstItem
                                                                  attribute:_aspectRatioConstraint.firstAttribute
                                                                  relatedBy:_aspectRatioConstraint.relation
                                                                     toItem:_aspectRatioConstraint.secondItem
                                                                  attribute:_aspectRatioConstraint.secondAttribute
                                                                 multiplier:image.size.width / image.size.height
                                                                   constant:0.0];
            [_imageView addConstraint:_aspectRatioConstraint];
            break;
        }
        default:
            break;
    }
}

- (void)ioFrameChannel:(PTChannel*)channel didEndWithError:(NSError*)error {
    if (channel == _listenChannel && error) {
        [self startListening];
    }
    [self deactivateTouchBar:YES];
}

- (void)ioFrameChannel:(PTChannel*)channel didAcceptConnection:(PTChannel*)otherChannel fromAddress:(PTAddress*)address {
    if (_peerChannel) {
        [_peerChannel close];
        _peerChannel = nil;
    }

    _peerChannel = otherChannel;
    _peerChannel.userInfo = address;
    [self activateTouchBar:YES];
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
	return _listenChannel==nil;
}

- (void) sendKeyboardString:(NSString*)string {
	NSData* data = [NSPropertyListSerialization dataWithPropertyList:@{@"string":string,@"ctrl":@(self.textField.ctrlPressed),@"alt":@(self.textField.altPressed),@"cmd":@(self.textField.cmdPressed)} format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
	CFDataRef immutableSelf = CFBridgingRetain([data copy]);
	dispatch_data_t payload = dispatch_data_create(data.bytes, data.length, dispatch_get_main_queue(), ^{
		CFRelease(immutableSelf);
	});

	[_peerChannel sendFrameOfType:ProtocolFrameTypeKeyEvent tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
		if (error) {
			NSLog(@"Failed to send message: %@", error);
		}
	}];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	if(range.length == 1 && string.length == 0) {
		[self sendKeyboardString:@"␡"];
	}
	else {
		[self sendKeyboardString:string];
	}
	return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[self sendKeyboardString:@"\r"];
	return NO;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
	[self sendKeyboardString:@"␡"];
	return NO;
}
@end


@implementation  FakeTextField : UITextField
- (instancetype)init
{
	self = [super init];
	if (self) {
		self.text = @" ";
		self.keyboardAppearance = UIKeyboardAppearanceDark;
		self.autocorrectionType = UITextAutocorrectionTypeNo;
		self.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.keyboardType = UIKeyboardTypeASCIICapable;
		
		UIToolbar *toolBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f,
																		 0.0f,
																		 200.,
																		 44.0f)];
		toolBar.translucent = NO;
		toolBar.tintColor = [UIColor lightGrayColor];
		toolBar.barTintColor = [UIColor colorWithWhite:0.05 alpha:1.0];
		toolBar.items =   @[ [[UIBarButtonItem alloc] initWithTitle:@"ctrl"
															  style:UIBarButtonItemStylePlain
															 target:self
															 action:@selector(ctrlPressed:)],
							 [[UIBarButtonItem alloc] initWithTitle:@"alt"
															  style:UIBarButtonItemStylePlain
															 target:self
															 action:@selector(altPressed:)],
							 [[UIBarButtonItem alloc] initWithTitle:@"cmd"
															  style:UIBarButtonItemStylePlain
															 target:self
															 action:@selector(cmdPressed:)],
							 [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
							 [[UIBarButtonItem alloc] initWithTitle:@"tab"
															  style:UIBarButtonItemStylePlain
															 target:self
															 action:@selector(tabPressed:)],
							 ];
		self.inputAccessoryView = toolBar;
	}
	return self;
}

- (IBAction)ctrlPressed:(UIBarButtonItem*)sender {
	self.ctrlPressed = !self.ctrlPressed;
	if(self.ctrlPressed) {
		sender.tintColor = [UIColor whiteColor];
	}
	else {
		sender.tintColor = nil;
	}
}

- (IBAction)altPressed:(UIBarButtonItem*)sender {
	self.altPressed = !self.altPressed;
	if(self.altPressed) {
		sender.tintColor = [UIColor whiteColor];
	}
	else {
		sender.tintColor = nil;
	}
}

- (IBAction)tabPressed:(UIBarButtonItem*)sender {
	[self.delegate textField:self shouldChangeCharactersInRange:NSMakeRange(0, 0) replacementString:@"\t"];
}

- (IBAction)cmdPressed:(UIBarButtonItem*)sender {
	self.cmdPressed = !self.cmdPressed;
	if(self.cmdPressed) {
		sender.tintColor = [UIColor whiteColor];
	}
	else {
		sender.tintColor = nil;
	}
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
	return false;
}
@end
