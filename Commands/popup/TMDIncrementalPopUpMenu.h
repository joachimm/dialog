//
//  TMDIncrementalPopUpMenu.h
//
//  Created by Joachim Mårtensson on 2007-08-10.
//

#import <Cocoa/Cocoa.h>
#import "CLIProxy.h"
#import "DocPopup.h"

#define MAX_ROWS 15

@interface TMDIncrementalPopUpMenu : NSWindow<NSTableViewDataSource>
{
	NSFileHandle* outputHandle;
	NSArray* suggestions;
	NSMutableString* mutablePrefix;
	NSString* staticPrefix;
	NSArray* filtered;
	DocPopup* htmlTooltip;
	NSPoint caretPos;
	BOOL isAbove;
	BOOL closeMe;
	BOOL caseSensitive;

	NSMutableCharacterSet* textualInputCharacters;	
}
- (id)initWithItems:(NSArray*)someSuggestions alreadyTyped:(NSString*)aUserString staticPrefix:(NSString*)aStaticPrefix additionalWordCharacters:(NSString*)someAdditionalWordCharacters caseSensitive:(BOOL)isCaseSensitive writeChoiceToFileDescriptor:(NSFileHandle*)aFileDescriptor;
- (void)setCaretPos:(NSPoint)aPos;
@end
