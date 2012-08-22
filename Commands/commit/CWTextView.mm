//
//  CWTextView.m
//  CommitWindow
//
//  Created by Chris Thomas on 3/7/05.
//  Copyright 2005-2006 Chris Thomas. All rights reserved.
//  MIT license.
//

#import "CWTextView.h"

@implementation CWTextView
#if 0
#pragma mark -
#pragma mark Do not eat the enter key
#endif

- (void) keyDown:(NSEvent *)event
{
	// don't let the textview eat the enter key
	if( [[event characters] isEqualToString:@"\x03"] )
	{
		[[self nextResponder] keyDown:event];
	}
	else
	{
		NSEventType t = [event type];
		
		if(t == NSKeyDown)
		{
			
			unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
		 	if(key == NSTabCharacter) {
		 	  if (([event modifierFlags] & NSAlternateKeyMask) == NSAlternateKeyMask) {
			  	[super keyDown:event];
		      return;
		     }
		     [[self window] selectKeyViewFollowingView:self];
		     return;
		    }
		    else if(key == NSBackTabCharacter) {
		    	[[self window] selectPreviousKeyView:self];
		    	return;
		    }
		}
		[super keyDown:event];
	}
}

@end
