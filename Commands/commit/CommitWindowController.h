//
//  CommitWindowController.h
//
//  Created by Chris Thomas on 2/6/05.
//  Copyright 2005 Chris Thomas. All rights reserved.
//	MIT license.
//

#import <Cocoa/Cocoa.h>
#import "../../Dialog2.h"

@class CWTextView;
@class CXMenuButton;

struct arguments_t
{
	struct action_t
	{
		NSString* action;
		NSArray* command;
		NSString* status;	
	};
	NSString* requestText;
	NSString* commitMessage;
	NSString* diffCommand;
	NSArray* fileStatus;
	NSArray* paths;
	std::vector<action_t> actions;
};
@interface CommitWindowController : NSWindowController <NSMenuDelegate>
{
	arguments_t							cliArguments;
//	NSMutableArray *	fFiles;		// {@"commit", @"path"}
	IBOutlet NSArrayController *	fFilesController;

	IBOutlet NSWindow *				fWindow;
	IBOutlet NSTextField *			textView;

	IBOutlet NSTextField *			fRequestText;
	IBOutlet CWTextView *			fCommitMessage;
	IBOutlet NSPopUpButton *		fPreviousSummaryPopUp;
	IBOutlet NSButton *			fFileListActionPopUp;

	IBOutlet NSButton *				fCancelButton;
	IBOutlet NSButton *				fOKButton;

	IBOutlet NSTableView *			fTableView;
	IBOutlet NSTableColumn *		fCheckBoxColumn;
	IBOutlet NSTableColumn *		fStatusColumn;
	IBOutlet NSTableColumn *		fPathColumn;

	IBOutlet NSScrollView *			fSummaryScrollView;
	NSRect							fPreviousSummaryFrame;
	IBOutlet NSView *				fLowerControlsView;

	NSString *						fDiffCommand;
	NSMutableDictionary *			fActionCommands;
	
	NSArray *						fFileStatusStrings;
	NSFileHandle* outputHandle;
	NSMutableDictionary* debug;
}
- (id) initWithArguments:(arguments_t const&)arguments fileDescriptor:(NSFileHandle*)outputHandle;
- (IBAction) commit:(id) sender;
- (IBAction) cancel:(id) sender;

- (void) addAction:(NSString *)name command:(NSArray *)commands forStatus:(NSString *)statusString;
- (void) setupUserInterfaces;
- (void) resetStatusColumnSize;

- (void) saveSummary;

- (IBAction) chooseAllFiles:(id)sender;
- (IBAction) chooseNoFiles:(id)sender;
- (IBAction) revertToStandardChosenState:(id)sender;

- (NSString *) absolutePathForPath:(NSString *)path;
- (void) checkExitStatus:(int)exitStatus forCommand:(NSArray *)arguments errorText:(NSString *)errorText;

@end
