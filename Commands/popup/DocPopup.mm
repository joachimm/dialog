//
//  DocPopup.m
//  Dialog2
//
//  Created by Joachim Mårtensson on 2009-01-11.
//  Copyright 2009 Chalmers. All rights reserved.
//

#import "DocPopup.h"


@implementation DocPopup
- (id)init
{
    if( (self = [super init]) ) {

    }
    return self;
}
- (void)runUntilUserActivity
{
	return;
}
- (BOOL)shouldCloseForMousePosition:(NSPoint)aPoint
{
	return NO;
}
- (void) close 
{
	[webView setFrameLoadDelegate:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:self];
	[super close];
}

- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame;
{
		[self sizeToContent];
		[self orderFront:self];
	}
@end
