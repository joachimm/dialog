//
//  DocPopup.h
//  Dialog2
//
//  Created by Joachim Mårtensson on 2009-01-11.
//  Copyright 2009 Chalmers. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../tooltip/TMDHTMLTips.h"


@interface DocPopup : TMDHTMLTip{

}
- (void)runUntilUserActivity;
- (BOOL)shouldCloseForMousePosition:(NSPoint)aPoint;
- (void)close;
@end
