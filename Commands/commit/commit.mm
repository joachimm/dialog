//
//  CommitWindowCommandLine.m
//  CommitWindow
//
//  Created by Chris Thomas on 6/24/06.
//  Copyright 2006 Chris Thomas. All rights reserved.
//

#import "commit.h"
#import "CommitWindowController.h"

#import "NSTask+CXAdditions.h"

@implementation TMDCommit
+ (void)load
{
	[TMDCommand registerObject:[self new] forCommand:@"commit"];
}
- (NSArray*)arrayFromPlistString:(NSArray*)plist
{
	if([plist isKindOfClass:[NSString class]])
	{
		return [NSPropertyListSerialization propertyListFromData:[(NSString*)plist dataUsingEncoding:NSUTF8StringEncoding] mutabilityOption:NSPropertyListImmutable format:nil errorDescription:NULL];
	}
	else
	{
		return plist;
	}
}
- (void)handleCommand:(CLIProxy*)proxy
{
	NSDictionary* args = [proxy parameters];
	arguments_t arguments;
	arguments.requestText     = [args objectForKey:@"ask"];
	arguments.commitMessage     = [args objectForKey:@"log"];
	arguments.diffCommand     = [args objectForKey:@"diff-cmd"];
	
	arguments.paths     = [self arrayFromPlistString:[args objectForKey:@"files"]];
	arguments.fileStatus     = [self arrayFromPlistString:[args objectForKey:@"statuses"]];
	NSArray* actionCommands     = [self arrayFromPlistString:[args objectForKey:@"action_commands"]];
	
	enumerate(actionCommands, NSString* actionCmd)
	{
			//
			// --action-cmd provides an action that may be performed on a file.
			// Provide multiple action commands by passing --action-cmd multiple times, each with a different command argument.
			//
			// The argument to --action-cmd is two comma-seperated lists separated by a colon, of the form "A,M,D:Revert,/usr/local/bin/svn,revert"
			//	
			//	On the left side of the colon is a list of status character or character sequences; a file must have one of these
			//	for this command to be enabled.
			//
			//	On the right side  is a list:
			//		Item 1 is the human-readable name of the command.
			//		Item 2 is the path (either absolute or accessible via $PATH) to the executable.
			//		Items 3 through n are the arguments to the executable.
			//		CommitWindow will append the file path as the last argument before executing the command.
			//		Multiple paths may be appended in the future.
			//
			//	The executable should return a single line of the form "<new status character(s)><whitespace><file path>" for each path.
			//
			//  For Subversion, commands might be:
			//		"?:Add,/usr/local/bin/svn,add"
			//		"A:Mark Executable,/usr/local/bin/svn,propset,svn:executable,true"
			//		"A,M,D,C:Revert,/usr/local/bin/svn,revert"
			//		"C:Resolved,/usr/local/bin/svn,resolved"
			//
			//	Only the first colon is significant, so that, for example, 'svn:executable' in the example above works as expected.
			//	This does scheme assume that neither comma nor colon will be used in status sequences. The file paths themselves may contain
			//	commas, since those are handled out of bounds. We could introduce comma or colon quoting if needed. But I hope not.
			//	
						
			// Get status strings
			NSString *	statusSubstringString;
			NSString *	commandArgumentString;
			NSArray *	statusSubstrings;
			NSArray *	commandArguments;
			NSRange		range;
			
			range = [actionCmd rangeOfString:@":"];
			if(range.location == NSNotFound)
			{
				fprintf(stdout, "commit window: missing ':' in --action-cmd\n");
			//	[self cancel:nil];
			}
			
			statusSubstringString	= [actionCmd substringToIndex:range.location];
			commandArgumentString	= [actionCmd substringFromIndex:NSMaxRange(range)];
			
			statusSubstrings	= [statusSubstringString componentsSeparatedByString:@","];
			commandArguments	= [commandArgumentString componentsSeparatedByString:@","];
			
			unsigned int	statusSubstringCount = [statusSubstrings count];
			
			// Add the command to each substring
			for(unsigned int index = 0; index < statusSubstringCount; index += 1)
			{
				NSString *	statusSubstring = [statusSubstrings objectAtIndex:index];
				arguments_t::action_t action;
				
				action.action = [commandArguments objectAtIndex:0];
				action.command = [commandArguments subarrayWithRange:NSMakeRange(1, [commandArguments count] - 1)];
				action.status = statusSubstring;
				
				arguments.actions.push_back(action);
						
			}
		}
	
		CommitWindowController* controller = [[CommitWindowController alloc] initWithArguments:arguments fileDescriptor:[proxy outputHandle]];
		[controller showWindow:self];
	//
	// Done processing arguments, now add status to each item
	// 								and choose default commit state
	//
		NSMutableDictionary* dict = [NSMutableDictionary dictionary];
		
		[dict setValue:arguments.paths forKey:@"paths"];     
		[dict setValue:arguments.fileStatus forKey:@"status"];
		[dict setValue:actionCommands forKey:@"action"];     
		[dict setValue:args forKey:@"parameters"];     

		//[TMDCommand writePropertyList:dict toFileHandle:[proxy outputHandle]];		

		//[[proxy outputHandle] close];
}
- (NSString *)commandDescription
{
	return @"Presents a scm commit window.";
}

- (NSString *)usageForInvocation:(NSString *)invocation;
{
	return [NSString stringWithFormat:@"\t%1$@ --diff-cmd <diff command>\n\t%1$@ --statuses <plist status>\n\t%1$@ --action_commands <plist action commands>\n\t%1$@ --files <plist files>'\n", invocation];
}

@end
