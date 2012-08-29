//
//  CommitWindowController.m
//
//  Created by Chris Thomas on 2/6/05.
//  Copyright 2005-2007 Chris Thomas. All rights reserved.
//	MIT license.
//

#import "CommitWindowController.h"
#import "CWTextView.h"

#import "CXTextWithButtonStripCell.h"
#import "NSString+StatusString.h"
#import "NSTask+CXAdditions.h"

#import "../Utilities/TextMate.h" // -insertSnippetWithOptions
#import "../../TMDCommand.h"

#define kStatusColumnWidthForSingleChar	13
#define kStatusColumnWidthForPadding	13

@interface CommitWindowController (Private)
- (void) populatePreviousSummaryMenu;
- (void) windowDidResize:(NSNotification *)notification;
- (void) summaryScrollViewDidResize:(NSNotification *)notification;
@end

// Forward string comparisons to NSString
@interface NSAttributedString (CommitWindowExtensions)
- (NSComparisonResult)compare:(id)anArgument;
@end

@implementation NSAttributedString (CommitWindowExtensions)
- (NSComparisonResult)compare:(id)aString
{
	return [[self string] compare:[aString string]];
}
@end


@implementation CommitWindowController
- (id)initWithArguments:(const arguments_t&)args fileDescriptor:(NSFileHandle*)handle;
{ 
	if(self = [super initWithWindowNibName:@"CommitWindow"]) {
		cliArguments = args;
		outputHandle = [handle retain];
	}
	return self;
}

- (void)windowDidLoad
{
	if(cliArguments.requestText)
		[fRequestText setStringValue:cliArguments.requestText];
	if(cliArguments.commitMessage)
		[fCommitMessage setString:cliArguments.commitMessage];
	
	fFileStatusStrings = cliArguments.fileStatus;
	fDiffCommand = [cliArguments.diffCommand retain];
	
	iterate(action, cliArguments.actions)
	{
		[self addAction:action->action
				command:action->command
				forStatus:action->status];
	}
	//last

	enumerate(cliArguments.paths, NSString* path)
	{
		NSMutableDictionary* dictionary	= [fFilesController newObject];
		[dictionary setObject:[path stringByAbbreviatingWithTildeInPath] forKey:@"path"];
		[fFilesController addObject:dictionary];
	}
	[self setupUserInterfaces];
}
// Not necessary while CommitWindow is a separate process, but it might be more integrated in the future.
- (void) dealloc
{
	// TODO: make sure the nib objects are being released properly
	
	[fDiffCommand release];
	[fActionCommands release];
	[fFileStatusStrings release];
	[outputHandle release];
	
	[super dealloc];
}

// Add a command to the array of commands available for the given status substring
- (void) addAction:(NSString *)name command:(NSArray *)commands forStatus:(NSString *)statusString
{
	NSArray *			commandArguments = [NSArray arrayWithObjects:name, commands, nil];
	NSMutableArray *	commandsForAction = nil;
	
	if(fActionCommands == nil)
	{
		fActionCommands = [[NSMutableDictionary alloc] init];
	}
	else
	{
		commandsForAction = [fActionCommands objectForKey:statusString];
	}
	
	if(commandsForAction == nil)
	{
		commandsForAction = [NSMutableArray array];
		[fActionCommands setObject:commandsForAction forKey:statusString];
	}
	
	[commandsForAction addObject:commandArguments];
}

- (BOOL)standardChosenStateForStatus:(NSString *)status
{
	BOOL	chosen = YES;

	// Deselect external commits and files not added by default
	// We intentionally do not deselect file conflicts by default
	// -- those are most likely to be a problem.

	if(	[status hasPrefix:@"X"]
	 ||	[status hasPrefix:@"?"])
	{
		chosen = NO;
	}
	
	return chosen;
}

// fFilesController and fFilesStatusStrings should be set up before calling setupUserInterface.
- (void) setupUserInterfaces
{
	CXTextWithButtonStripCell *		cell = (CXTextWithButtonStripCell *)[fPathColumn dataCell];
	
	if([cell respondsToSelector:@selector(setLineBreakMode:)])
	{
		[cell setLineBreakMode:NSLineBreakByTruncatingHead];		
	}

	//
	// Set up button strip
	//
	NSMutableArray *		buttonDefinitions = [NSMutableArray array];
	
	//	Diff command
	if( fDiffCommand != nil )
	{
		NSMethodSignature *		diffMethodSignature	= [self methodSignatureForSelector:@selector(doubleClickRowInTable:)];
		NSInvocation *			diffInvocation		= [NSInvocation invocationWithMethodSignature:diffMethodSignature];
		
		// Arguments 0 and 1
		[diffInvocation setTarget:self];
		[diffInvocation setSelector:@selector(doubleClickRowInTable:)];
		
		// Pretend the table view is the sender
		[diffInvocation setArgument:&fTableView atIndex:2];

		NSMutableDictionary* diffButtonDefinition = [NSMutableDictionary dictionary];
		[diffButtonDefinition setObject:@"Diff" forKey:@"title"];
		[diffButtonDefinition setObject:diffInvocation forKey:@"invocation"];

		[buttonDefinitions addObject:diffButtonDefinition];
	}

	// Action menu
	if(fActionCommands != nil)
	{
		NSMenu* itemActionMenu = [[NSMenu alloc] initWithTitle:@"Test"];
		[itemActionMenu setDelegate:self];
		
		NSMutableDictionary* actionMenuButtonDefinition = [NSMutableDictionary dictionaryWithObject:itemActionMenu forKey:@"menu"];
		[actionMenuButtonDefinition setObject:@"Modify" forKey:@"title"];

		[buttonDefinitions addObject:actionMenuButtonDefinition];
		
		[itemActionMenu release];
	}
	
	if( [buttonDefinitions count] > 0 )
	{
		[cell setButtonDefinitions:buttonDefinitions];
	}
	
	fPreviousSummaryFrame = [fSummaryScrollView frame];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(summaryScrollViewDidResize:)
		name:NSViewFrameDidChangeNotification
		object:fSummaryScrollView];
		
	//
	// Add status to each item and choose default commit state
	//
	if( fFileStatusStrings != nil )
	{
		NSArray *	files = [fFilesController arrangedObjects];
		int			count = MIN([files count], [fFileStatusStrings count]);
		
		UInt32		maxCharsToDisplay = 0;
		
		for(int i = 0; i < count; i += 1 )
		{
			NSMutableDictionary *	dictionary	= [files objectAtIndex:i];
			NSString *				status		= [fFileStatusStrings objectAtIndex:i];
			BOOL					itemSelectedForCommit;
			UInt32					statusLength;
			
			// Set high-water mark
			statusLength = [status length];
			if( statusLength > maxCharsToDisplay )
			{
				maxCharsToDisplay = statusLength;
			}
			
			[dictionary setObject:status forKey:@"status"];
			[dictionary setObject:[status attributedStatusString] forKey:@"attributedStatus"];

			itemSelectedForCommit = [self standardChosenStateForStatus:status];
			[dictionary setObject:[NSNumber numberWithBool:itemSelectedForCommit] forKey:@"commit"]; 
		}

		// Set status column size
		[fStatusColumn setWidth:12 + maxCharsToDisplay * kStatusColumnWidthForSingleChar + (maxCharsToDisplay-1) * kStatusColumnWidthForPadding];
	}
	
	//
	// Populate previous summary menu
	//
	[self populatePreviousSummaryMenu];

	[fTableView setTarget:self];
	[fTableView setDoubleAction:@selector(doubleClickRowInTable:)];

	//
	// Map the enter key to the OK button
	//
	[fOKButton setKeyEquivalent:@"\x03"];
	[fOKButton setKeyEquivalentModifierMask:0];
	
	[self setWindow:fWindow];
	[fWindow setLevel:NSModalPanelWindowLevel];
	[fWindow center];
	
	//
	// Grow the window to fit as much of the file list onscreen as possible
	//
	{
		NSTableView *	tableView	= [fPathColumn tableView];
		float			rowHeight	= [tableView rowHeight] + [tableView intercellSpacing].height;
		int				rowCount	= [[fFilesController arrangedObjects] count];
		float			idealVisibleHeight;
		float			currentVisibleHeight;
		float			deltaVisibleHeight;
		
		currentVisibleHeight	= [[tableView superview] frame].size.height;
		idealVisibleHeight		= (rowHeight * rowCount) + [[tableView headerView] frame].size.height;
		
		
		// Don't bother shrinking the window
		if(currentVisibleHeight < idealVisibleHeight)
		{
			deltaVisibleHeight = (idealVisibleHeight - currentVisibleHeight);

			NSRect			usableRect	= [[fWindow screen] visibleFrame];
			NSRect			windowRect	= [fWindow frame];

			// reasonable margin
			usableRect = NSInsetRect( usableRect, 20, 20 );
			windowRect = NSIntersectionRect(usableRect, NSInsetRect(windowRect, 0, ceilf(0.5f * -deltaVisibleHeight)));
						
			[fWindow setFrame:windowRect display:NO];
		}
	}
	
	// center again after resize
	[fWindow center];
	[fWindow makeKeyAndOrderFront:self];
	
}

- (void) resetStatusColumnSize
{
	//
	// Add status to each item and choose default commit state
	//
	NSArray *	files = [fFilesController arrangedObjects];
	int			count = [files count];
	
	UInt32		maxCharsToDisplay = 0;
	
	for(int i = 0; i < count; i += 1 )
	{
		NSMutableDictionary *	dictionary	= [files objectAtIndex:i];
		NSString *				status		= [dictionary objectForKey:@"status"];
		UInt32					statusLength;
		
		// Set high-water mark
		statusLength = [status length];
		if( statusLength > maxCharsToDisplay )
		{
			maxCharsToDisplay = statusLength;
		}
	}

	// Set status column size
	[fStatusColumn setWidth:12 + maxCharsToDisplay * kStatusColumnWidthForSingleChar + (maxCharsToDisplay-1) * kStatusColumnWidthForPadding];
}

#if 0
#pragma mark -
#pragma mark Summary save/restore
#endif

#define kMaxSavedSummariesCount					5
#define kDisplayCharsOfSummaryInMenuItemCount	30
#define kPreviousSummariesKey					"prev-summaries"
#define kPreviousSummariesItemTitle				"Previous Summaries"

- (void) populatePreviousSummaryMenu
{
	NSUserDefaults *  	defaults		= [NSUserDefaults standardUserDefaults];
	NSArray *			summaries		= [defaults arrayForKey:@kPreviousSummariesKey];
	
	if( summaries == nil )
	{
		// No previous summaries, no menu
		[fPreviousSummaryPopUp setEnabled:NO];
		return;
	}
	
	NSMenu *			menu = [[NSMenu alloc] initWithTitle:@kPreviousSummariesItemTitle];
	NSMenuItem *		item;

	int	summaryCount = [summaries count];
	int	index;

	// PopUp title
	[menu addItemWithTitle:@kPreviousSummariesItemTitle action:@selector(restoreSummary:) keyEquivalent:@""];
	
	// Add items in reverse-chronological order
	for(index = (summaryCount - 1); index >= 0; index -= 1)
	{
		NSString *	summary = [summaries objectAtIndex:index];
		NSString *	itemName;
		
		itemName = summary;
		
		// Limit length of menu item names
		if( [itemName length] > kDisplayCharsOfSummaryInMenuItemCount )
		{
			itemName = [itemName substringToIndex:kDisplayCharsOfSummaryInMenuItemCount];
			
			// append ellipsis
			itemName = [itemName stringByAppendingFormat: @"%d", 0x2026];
		}

		item = [menu addItemWithTitle:itemName action:@selector(restoreSummary:) keyEquivalent:@""];
		[item setTarget:self];
		
		[item setRepresentedObject:summary];
	}

	[fPreviousSummaryPopUp setMenu:menu];
}

// To make redo work, we need to add a new undo each time
- (void) restoreTextForUndo:(NSString *)newSummary
{
	NSUndoManager *	undoManager = [[fCommitMessage window] undoManager];
    NSString *		oldSummary = [fCommitMessage string];
    
    [undoManager registerUndoWithTarget:self
                                            selector:@selector(restoreTextForUndo:)
                                            object:[[oldSummary copy] autorelease]];

	[fCommitMessage setString:newSummary];

}

- (void) restoreSummary:(id)sender
{
	NSString *		newSummary = [sender representedObject];
	
	[self restoreTextForUndo:newSummary];
}

// Save, in a MRU list, the most recent commit summary
- (void) saveSummary
{
	NSString *			latestSummary	= [fCommitMessage string];
	
	// avoid empty string
	if(  [latestSummary isEqualToString:@""] )
	{
		return;
	}
	
	NSUserDefaults *  	defaults		= [NSUserDefaults standardUserDefaults];
	NSArray *			oldSummaries = [defaults arrayForKey:@kPreviousSummariesKey];
	NSMutableArray *	newSummaries;

	if( oldSummaries != nil )
	{
		unsigned int	oldIndex;
		
		newSummaries = [oldSummaries mutableCopy];
		
		// Already in the array? Move it to latest position
		oldIndex = [newSummaries indexOfObject:latestSummary];
		if( oldIndex != NSNotFound )
		{
			[newSummaries exchangeObjectAtIndex:oldIndex withObjectAtIndex:[newSummaries count] - 1];
		}
		else
		{
			// Add object, remove oldest object
			[newSummaries addObject:latestSummary];
			if( [newSummaries count] > kMaxSavedSummariesCount )
			{
				[newSummaries removeObjectAtIndex:0];
			}
		}
	}
	else
	{
		// First time
		newSummaries = [NSMutableArray arrayWithObject:latestSummary];
	}

	[defaults setObject:newSummaries forKey:@kPreviousSummariesKey];

	// Write the defaults to disk
	[defaults synchronize];
	
}

#if 0
#pragma mark -
#pragma mark File action menu
#endif



- (void) chooseAllItems:(BOOL)chosen
{
	NSArray *	files = [fFilesController arrangedObjects];
	int			count = [files count];
	
	for(int i = 0; i < count; i += 1 )
	{
		NSMutableDictionary *	dictionary	= [files objectAtIndex:i];
		[dictionary setObject:[NSNumber numberWithBool:chosen] forKey:@"commit"]; 
	}
}

- (void) choose:(BOOL)chosen itemsWithStatus:(NSString *)status
{
	NSArray *	files = [fFilesController arrangedObjects];
	int			count = [files count];
	
	for(int i = 0; i < count; i += 1 )
	{
		NSMutableDictionary *	dictionary	= [files objectAtIndex:i];
		
		if( [[dictionary objectForKey:@"status"] hasPrefix:status] )
		{
			[dictionary setObject:[NSNumber numberWithBool:chosen] forKey:@"commit"]; 
		}
	}
}

- (IBAction) chooseAllFiles:(id)sender
{
	[self chooseAllItems:YES];
}

- (IBAction) chooseNoFiles:(id)sender
{
	[self chooseAllItems:NO];
}

- (IBAction) revertToStandardChosenState:(id)sender
{
	NSArray *	files = [fFilesController arrangedObjects];
	int			count = [files count];
	
	for(int i = 0; i < count; i += 1 )
	{
		NSMutableDictionary *	dictionary	= [files objectAtIndex:i];
		BOOL					itemChosen = YES;
		NSString *				status = [dictionary objectForKey:@"status"];

		itemChosen = [self standardChosenStateForStatus:status];
		[dictionary setObject:[NSNumber numberWithBool:itemChosen] forKey:@"commit"]; 
	}
}

#if 0
#pragma mark -
#pragma mark Summary view resize
#endif

- (void) summaryScrollViewDidResize:(NSNotification *)notification
{
	// Adjust the size of the lower controls
	NSRect	currentSummaryFrame			= [fSummaryScrollView frame];
	NSRect	currentLowerControlsFrame	= [fLowerControlsView frame];

	float	deltaV = currentSummaryFrame.size.height - fPreviousSummaryFrame.size.height;
	
	[fLowerControlsView setNeedsDisplayInRect:[fLowerControlsView bounds]];
	
	currentLowerControlsFrame.size.height	-= deltaV;
	
	[fLowerControlsView setFrame:currentLowerControlsFrame];
	
	fPreviousSummaryFrame = currentSummaryFrame;
}

#if 0
#pragma mark -
#pragma mark Command utilities
#endif

- (NSString *) absolutePathForPath:(NSString *)path
{
	if([path hasPrefix:@"/"])
		return path;

	NSString *			absolutePath = nil;
	NSString *			errorText;
	int					exitStatus;
	NSArray *			args = [NSArray arrayWithObjects:@"/usr/bin/which", path, nil];

	exitStatus = [NSTask executeTaskWithArguments:args
		    					input:nil
		                        outputString:&absolutePath
		                        errorString:&errorText];
	
	[self checkExitStatus:exitStatus forCommand:args errorText:errorText];

	// Trim whitespace
	absolutePath = [absolutePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	return absolutePath;
}

- (void) checkExitStatus:(int)exitStatus forCommand:(NSArray *)arguments errorText:(NSString *)errorText
{
	if( exitStatus != 0 )
	{
		// This error dialog text sucks for an isolated end user, but allows us to diagnose the problem accurately.
		NSRunAlertPanel(errorText, @"Exit status (%d) while executing %@", @"OK", nil, nil, exitStatus, arguments);
		[NSException raise:@"ProcessFailed" format:@"Subprocess %@ unsuccessful.", arguments];
	}	
}


#if 0
#pragma mark -
#pragma mark ButtonStrip action menu delegate
#endif

- (void)chooseActionCommand:(id)sender
{
	NSMutableArray *		arguments		= [[sender representedObject] mutableCopy];
	NSString *				pathToCommand;
	NSMutableDictionary *	fileDictionary	= [[fFilesController arrangedObjects] objectAtIndex:[fTableView selectedRow]];
	NSString *				filePath		= [[fileDictionary objectForKey:@"path"] stringByStandardizingPath];
	NSString *				errorText;
	NSString *				outputStatus;
	int						exitStatus;
	
	// make sure we have an absolute path
	pathToCommand = [self absolutePathForPath:[arguments objectAtIndex:0]];
	[arguments replaceObjectAtIndex:0 withObject:pathToCommand];
	
	[arguments addObject:filePath];
	
	exitStatus = [NSTask executeTaskWithArguments:arguments
		    					input:nil
		                        outputString:&outputStatus
		                        errorString:&errorText];
	[self checkExitStatus:exitStatus forCommand:arguments errorText:errorText];
	
	//
	// Set the file status to the new status
	//
	NSRange		rangeOfStatus;
	NSString *	newStatus;
	
	rangeOfStatus = [outputStatus rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if( rangeOfStatus.location == NSNotFound)
	{
		NSRunAlertPanel(@"Cannot understand output from command", @"Command %@ returned '%@'", @"OK", nil, nil, arguments, outputStatus);
		[NSException raise:@"CannotUnderstandReturnValue" format:@"Don't understand %@", outputStatus];
	}
	
	newStatus = [outputStatus substringToIndex:rangeOfStatus.location];

	[fileDictionary setObject:newStatus forKey:@"status"];
	[fileDictionary setObject:[newStatus attributedStatusString] forKey:@"attributedStatus"];
	[fileDictionary setObject:[NSNumber numberWithBool:[self standardChosenStateForStatus:newStatus]] forKey:@"commit"];
	
	[self resetStatusColumnSize];
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	//
	// Remove old items
	//
	UInt32 itemCount = [menu numberOfItems];
	for( UInt32 i = 0; i < itemCount; i += 1 )
	{
		[menu removeItemAtIndex:0];
	}
	
	//
	// Find action items usable for the selected row
	//
	NSArray *		keys = [fActionCommands allKeys];
	NSString *		fileStatus	= [[[fFilesController arrangedObjects] objectAtIndex:[fTableView selectedRow]] objectForKey:@"status"];

	unsigned int	possibleStatusCount = [keys count];

	for(unsigned int index = 0; index < possibleStatusCount; index += 1)
	{
		NSString *	possibleStatus = [keys objectAtIndex:index];

		if( [fileStatus rangeOfString:possibleStatus].location != NSNotFound )
		{	
			// Add all the commands we find for this status
			NSArray *		commands		= [fActionCommands objectForKey:possibleStatus];
			unsigned int	commandCount	= [commands count];

			for(unsigned int arrayOfCommandsIndex = 0; arrayOfCommandsIndex < commandCount; arrayOfCommandsIndex += 1)
			{
				NSArray *	commandArguments = [commands objectAtIndex:arrayOfCommandsIndex];

				NSMenuItem *	item = [menu addItemWithTitle:[commandArguments objectAtIndex:0]
												action:@selector(chooseActionCommand:)
												keyEquivalent:@""];
				
				[item setRepresentedObject:[commandArguments objectAtIndex:1]];
				[item setTarget:self];
			}
		}
	}
}


#if 0
#pragma mark -
#pragma mark Actions
#endif



- (IBAction) commit:(id) sender
{
	NSArray *			objects = [fFilesController arrangedObjects];
	int					pathsToCommitCount = 0;
	NSMutableString *	commitString;
	
	[self saveSummary];
	
	//
	// Quote any single-quotes in the commit message
	// \' doesn't work with bash. We must use string concatenation.
	// This sort of thing is why the Unix Hater's Handbook exists.
	//
	commitString = [[[fCommitMessage string] mutableCopy] autorelease];
	[commitString replaceOccurrencesOfString:@"'" withString:@"'\"'\"'" options:0 range:NSMakeRange(0, [commitString length])];
	NSMutableDictionary* output = [NSMutableDictionary dictionary];
	[output setObject:commitString forKey:@"commitMessage"];
	
	NSMutableArray* filesToCommit = [NSMutableArray array];
	//
	// Return only the files we care about
	//
	for( int i = 0; i < [objects count]; i += 1 )
	{		
		NSMutableDictionary* dictionary	= [objects objectAtIndex:i];
		NSNumber* commit		= [dictionary objectForKey:@"commit"];
		
		if( commit == nil || [commit boolValue] )	// missing commit key defaults to true
		{
			//
			// Quote any single-quotes in the path
			//
			NSMutableString* path = [dictionary objectForKey:@"path"];
			path = [[[path stringByStandardizingPath] mutableCopy] autorelease];
			[filesToCommit addObject:path];
			pathsToCommitCount += 1;
		}
	}
	[output setObject:filesToCommit forKey:@"filesToCommit"];
	
	//
	// SVN will commit the current directory, recursively, if we don't specify files.
	// So, to prevent surprises, if the user's unchecked all the boxes, let's be on the safe side and cancel.
	//
	if( pathsToCommitCount == 0 )
	{
		[self cancel:nil];
	}
	[TMDCommand writePropertyList:[output description] toFileHandle:outputHandle];
	[outputHandle closeFile];	

	[self close];
}

- (IBAction) cancel:(id) sender
{
	[self saveSummary];
	// write an empty dictionary when cancelling
	[TMDCommand writePropertyList:[[NSDictionary dictionary] description] toFileHandle:outputHandle];
	
	[outputHandle closeFile];
	[self close];
	
	//exit(-128);
}


- (IBAction) doubleClickRowInTable:(id)sender
{
	if( fDiffCommand != nil )
	{
		static NSString *	sCommandAbsolutePath = nil;

		NSMutableArray *	arguments	= [[fDiffCommand componentsSeparatedByString:@","] mutableCopy];
		NSString *			filePath	= [[[[fFilesController arrangedObjects] objectAtIndex:[sender selectedRow]] objectForKey:@"path"] stringByStandardizingPath];
		NSData *			diffData;
		NSString *			errorText;
		int					exitStatus;
		
		// Resolve the command to an absolute path (only do this once per launch)
		if(sCommandAbsolutePath == nil)
		{
			sCommandAbsolutePath = [[self absolutePathForPath:[arguments objectAtIndex:0]] retain];
		}
		[arguments replaceObjectAtIndex:0 withObject:sCommandAbsolutePath];

		// Run the diff
		[arguments addObject:filePath];
		exitStatus = [NSTask executeTaskWithArguments:arguments
			    					input:nil
			                        outputData:&diffData
			                        errorString:&errorText];
		[self checkExitStatus:exitStatus forCommand:arguments errorText:errorText];

		// Success, send the diff to TextMate
		arguments = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%s/bin/mate", getenv("TM_SUPPORT_PATH")], @"-a", nil];
		
		exitStatus = [NSTask executeTaskWithArguments:arguments
			    					input:diffData
			                        outputData:nil
			                        errorString:&errorText];
		[self checkExitStatus:exitStatus forCommand:arguments errorText:errorText];
	}
}


@end
