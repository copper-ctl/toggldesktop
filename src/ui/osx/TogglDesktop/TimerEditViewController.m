
//
//  TimerEditViewController.m
//  Toggl Desktop on the Mac
//
//  Created by Tanel Lebedev on 19/09/2013.
//  Copyright (c) 2013 TogglDesktop developers. All rights reserved.
//
#import "TimerEditViewController.h"
#import "UIEvents.h"
#import "AutocompleteItem.h"
#import "AutocompleteDataSource.h"
#import "ConvertHexColor.h"
#import "NSComboBox_Expansion.h"
#import "TimeEntryViewItem.h"
#import "NSTextFieldClickable.h"
#import "NSCustomComboBoxCell.h"
#import "NSCustomComboBox.h"
#import "NSCustomTimerComboBox.h"
#import "DisplayCommand.h"

@interface TimerEditViewController ()
@property AutocompleteDataSource *autocompleteDataSource;
@property TimeEntryViewItem *time_entry;
@property NSTimer *timer;
@property BOOL constraintsAdded;
@end

@implementation TimerEditViewController

extern void *ctx;

NSString *kTrackingColor = @"#d0d0d0";
NSString *kInactiveTimerColor = @"#999999";

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self)
	{
		self.autocompleteDataSource = [[AutocompleteDataSource alloc] initWithNotificationName:kDisplayTimeEntryAutocomplete];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(startDisplayTimerState:)
													 name:kDisplayTimerState
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(startDisplayTimeEntryList:)
													 name:kDisplayTimeEntryList
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(focusTimer:)
													 name:kFocusTimer
												   object:nil];

		self.time_entry = [[TimeEntryViewItem alloc] init];

		self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
													  target:self
													selector:@selector(timerFired:)
													userInfo:nil
													 repeats:YES];
		self.constraintsAdded = NO;
	}

	return self;
}

- (void)viewDidLoad
{
	self.autocompleteDataSource.combobox = self.descriptionComboBox;

	[self.autocompleteDataSource setFilter:@""];
	NSFont *descriptionFont = [NSFont fontWithName:@"Lucida Grande" size:13.0];
	NSFont *durationFont = [NSFont fontWithName:@"Lucida Grande" size:16.0];
	NSColor *color = [ConvertHexColor hexCodeToNSColor:kTrackingColor];
	NSDictionary *descriptionDictionary = @{
		NSFontAttributeName : descriptionFont,
		NSForegroundColorAttributeName : color
	};
	NSDictionary *durationDictionary = @{
		NSFontAttributeName : durationFont,
		NSForegroundColorAttributeName : color
	};

	NSAttributedString *descriptionLightString = [[NSAttributedString alloc] initWithString:@"What are you doing?"
																				 attributes:descriptionDictionary];

	NSAttributedString *durationLightString = [[NSAttributedString alloc] initWithString:@"00:00:00"
																			  attributes:durationDictionary];

	[[self.durationTextField cell] setPlaceholderAttributedString:durationLightString];
	[[self.descriptionLabel cell] setPlaceholderAttributedString:descriptionLightString];
	[[self.descriptionComboBox cell] setPlaceholderAttributedString:descriptionLightString];
}

- (void)loadView
{
	[super loadView];
	[self viewDidLoad];
}

- (void)focusTimer:(NSNotification *)notification
{
	if (self.time_entry.duration_in_seconds < 0)
	{
		[self.startButton becomeFirstResponder];
	}
	else
	{
		[self.descriptionComboBox becomeFirstResponder];
	}
}

- (void)startDisplayTimeEntryList:(NSNotification *)notification
{
	[self performSelectorOnMainThread:@selector(displayTimeEntryList:)
						   withObject:notification.object
						waitUntilDone:NO];
}

- (void)displayTimeEntryList:(DisplayCommand *)cmd
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

	if (cmd.open && self.time_entry && self.time_entry.duration_in_seconds >= 0)
	{
		[self.descriptionComboBox becomeFirstResponder];
	}
}

- (void)startDisplayTimerState:(NSNotification *)notification
{
	[self performSelectorOnMainThread:@selector(displayTimerState:)
						   withObject:notification.object
						waitUntilDone:NO];
}

- (void)displayTimerState:(TimeEntryViewItem *)te
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

	if (!te)
	{
		te = [[TimeEntryViewItem alloc] init];
	}
	self.time_entry = te;

	// Start/stop button title and color depend on
	// whether time entry is running
	if (self.time_entry.duration_in_seconds < 0)
	{
		self.startButton.toolTip = @"Stop";
		[self.startButton setImage:[NSImage imageNamed:@"stop_button.pdf"]];
	}
	else
	{
		self.startButton.toolTip = @"Start";
		[self.startButton setImage:[NSImage imageNamed:@"start_button.pdf"]];
	}

	// Description and duration cannot be edited
	// while time entry is running
	if (self.time_entry.duration_in_seconds < 0)
	{
		[self.durationTextField setDelegate:self];
		self.descriptionLabel.stringValue = self.time_entry.Description;
		self.descriptionLabel.toolTip = self.time_entry.Description;
		[self.descriptionComboBox setHidden:YES];
		[self.descriptionLabel setHidden:NO];
		[self.durationTextField setEditable:NO];
		[self.durationTextField setSelectable:NO];
		[self.descriptionLabel setTextColor:[ConvertHexColor hexCodeToNSColor:kTrackingColor]];

		[self.durationTextField setTextColor:[ConvertHexColor hexCodeToNSColor:kTrackingColor]];
	}
	else
	{
		[self.descriptionComboBox setHidden:NO];
		[self.descriptionLabel setHidden:YES];
		[self.durationTextField setEditable:YES];
		[self.durationTextField setSelectable:YES];
		[self.descriptionLabel setTextColor:[ConvertHexColor hexCodeToNSColor:kInactiveTimerColor]];

		[self.durationTextField setTextColor:[ConvertHexColor hexCodeToNSColor:kInactiveTimerColor]];
	}

	[self checkProjectConstraints];

	// Display project name
	if (self.time_entry.ProjectAndTaskLabel != nil)
	{
		[self.projectTextField setAttributedStringValue:[self setProjectClientLabel:self.time_entry]];
		self.projectTextField.toolTip = self.time_entry.ProjectAndTaskLabel;
	}
	else
	{
		self.projectTextField.stringValue = @"";
		self.projectTextField.toolTip = nil;
	}
	self.projectTextField.backgroundColor =
		[ConvertHexColor hexCodeToNSColor:self.time_entry.ProjectColor];

	// Display duration
	if (self.time_entry.duration != nil)
	{
		self.durationTextField.stringValue = self.time_entry.duration;
	}
	else
	{
		self.durationTextField.stringValue = @"";
	}
}

- (void)checkProjectConstraints
{
	// If a project is assigned, then project name
	// is visible.
	if (self.time_entry.ProjectID || self.time_entry.ProjectGUID || [self.time_entry.ProjectAndTaskLabel length])
	{
		if (![self.projectComboConstraint count])
		{
			[self createConstraints];
		}
		if (!self.constraintsAdded)
		{
			[self.view addConstraints:self.projectComboConstraint];
			[self.view addConstraints:self.projectLabelConstraint];
			self.constraintsAdded = YES;
		}

		[self.projectTextField setHidden:NO];
	}
	else
	{
		[self.projectTextField setHidden:YES];
		if (self.constraintsAdded)
		{
			[self.view removeConstraints:self.projectComboConstraint];
			[self.view removeConstraints:self.projectLabelConstraint];
			self.constraintsAdded = NO;
		}
	}
}

- (NSMutableAttributedString *)setProjectClientLabel:(TimeEntryViewItem *)view_item
{
	NSMutableAttributedString *clientName = [[NSMutableAttributedString alloc] initWithString:view_item.ClientLabel];
	NSColor *color = [ConvertHexColor hexCodeToNSColor:@"#666666"];

	[clientName setAttributes:
	 @{
		 NSFontAttributeName : [NSFont systemFontOfSize:[NSFont systemFontSize]],
		 NSForegroundColorAttributeName:color
	 }
						range:NSMakeRange(0, [clientName length])];
	NSMutableAttributedString *string;
	if (view_item.TaskID != 0)
	{
		string = [[NSMutableAttributedString alloc] initWithString:[view_item.TaskLabel stringByAppendingString:@". "]];

		[string setAttributes:
		 @{
			 NSFontAttributeName : [NSFont systemFontOfSize:[NSFont systemFontSize]],
			 NSForegroundColorAttributeName:color
		 }
						range:NSMakeRange(0, [string length])];

		NSMutableAttributedString *projectName = [[NSMutableAttributedString alloc] initWithString:[view_item.ProjectLabel stringByAppendingString:@" "]];

		[string appendAttributedString:projectName];
	}
	else
	{
		string = [[NSMutableAttributedString alloc] initWithString:[view_item.ProjectLabel stringByAppendingString:@" "]];
	}

	[string appendAttributedString:clientName];
	return string;
}

- (void)textFieldClicked:(id)sender
{
	[self.descriptionComboBox becomeFirstResponder];

	[[NSNotificationCenter defaultCenter] postNotificationName:kResetEditPopoverSize
														object:nil
													  userInfo:nil];

	if (nil == self.time_entry || nil == self.time_entry.GUID)
	{
		if (sender == self.durationTextField)
		{
			char *guid = toggl_start(ctx,
									 [self.descriptionComboBox.stringValue UTF8String],
									 "0",
									 self.time_entry.TaskID,
									 self.time_entry.ProjectID);
			[self clear];
			self.time_entry = [[TimeEntryViewItem alloc] init];
			NSString *GUID = [NSString stringWithUTF8String:guid];
			free(guid);

			toggl_edit(ctx, [GUID UTF8String], false, kFocusedFieldNameDuration);
		}
		return;
	}

	const char *focusField = kFocusedFieldNameDescription;
	if (sender == self.projectTextField)
	{
		focusField = kFocusedFieldNameProject;
	}
	else if (sender == self.durationTextField)
	{
		focusField = kFocusedFieldNameDuration;
	}

	toggl_edit(ctx, [self.time_entry.GUID UTF8String], false, focusField);
}

- (void)createConstraints
{
	NSDictionary *viewsDict = NSDictionaryOfVariableBindings(_descriptionComboBox, _projectTextField);

	self.projectComboConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[_descriptionComboBox]-2@1000-[_projectTextField]"
																		  options:0
																		  metrics:nil
																			views:viewsDict];

	NSDictionary *viewsDict_ = NSDictionaryOfVariableBindings(_descriptionLabel, _projectTextField);
	self.projectLabelConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[_descriptionLabel]-0@1000-[_projectTextField]"
																		  options:0
																		  metrics:nil
																			views:viewsDict_];
}

- (void)clear
{
	self.durationTextField.stringValue = @"";
	self.descriptionComboBox.stringValue = @"";
	self.projectTextField.stringValue = @"";
	[self.projectTextField setHidden:YES];
}

- (IBAction)startButtonClicked:(id)sender
{
	if (self.time_entry.duration_in_seconds < 0)
	{
		[self clear];
		[[NSNotificationCenter defaultCenter] postNotificationName:kCommandStop
															object:nil];
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:kForceCloseEditPopover
														object:nil];

	// resign current firstResponder
	[self.durationTextField.window makeFirstResponder:[self.durationTextField superview]];
	self.time_entry.Duration = self.durationTextField.stringValue;
	self.time_entry.Description = self.descriptionComboBox.stringValue;
	[[NSNotificationCenter defaultCenter] postNotificationName:kCommandNew
														object:self.time_entry];

	// Reset autocomplete filter
	[self.autocompleteDataSource setFilter:@""];

	if (self.time_entry.duration_in_seconds >= 0)
	{
		[self clear];
		self.time_entry = [[TimeEntryViewItem alloc] init];
	}
}

- (IBAction)durationFieldChanged:(id)sender
{
	if (![self.durationTextField.stringValue length])
	{
		return;
	}

	// Parse text into seconds
	const char *duration_string = [self.durationTextField.stringValue UTF8String];
	int64_t seconds = toggl_parse_duration_string_into_seconds(duration_string);

	// Format seconds as text again
	char *str = toggl_format_tracking_time_duration(seconds);
	NSString *newValue = [NSString stringWithUTF8String:str];
	free(str);
	[self.durationTextField setStringValue:newValue];
}

- (IBAction)descriptionComboBoxChanged:(id)sender
{
	NSString *key = [self.descriptionComboBox stringValue];
	AutocompleteItem *item = [self.autocompleteDataSource get:key];

	// User has entered free text
	if (item == nil)
	{
		self.time_entry.Description = [self.descriptionComboBox stringValue];
		return;
	}

	// User has selected a autocomplete item.
	// It could be a time entry, a task or a project.
	self.time_entry.ProjectID = item.ProjectID;
	self.time_entry.TaskID = item.TaskID;
	self.time_entry.ProjectAndTaskLabel = item.ProjectAndTaskLabel;
	self.time_entry.TaskLabel = item.TaskLabel;
	self.time_entry.ProjectLabel = item.ProjectLabel;
	self.time_entry.ClientLabel = item.ClientLabel;
	self.time_entry.ProjectColor = item.ProjectColor;
	self.time_entry.Description = item.Description;

	self.descriptionComboBox.stringValue = self.time_entry.Description;
	if (item.ProjectID)
	{
		[self.projectTextField setAttributedStringValue:[self setProjectClientLabel:self.time_entry]];
		self.projectTextField.toolTip = self.time_entry.ProjectAndTaskLabel;
	}
	[self checkProjectConstraints];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	if ([[aNotification object] isKindOfClass:[NSTextFieldDuration class]])
	{
		return;
	}
	NSComboBox *box = [aNotification object];
	NSString *filter = [box stringValue];

	[self.autocompleteDataSource setFilter:filter];

	// Hide dropdown if filter is empty or nothing was found
	if (!filter || ![filter length] || !self.autocompleteDataSource.count)
	{
		if ([box isExpanded] == YES)
		{
			[box setExpanded:NO];
		}
		return;
	}

	if ([box isExpanded] == NO)
	{
		[box setExpanded:YES];
	}
}

- (void)timerFired:(NSTimer *)timer
{
	if (self.time_entry == nil || self.time_entry.duration_in_seconds >= 0)
	{
		return;
	}

	char *str = toggl_format_tracking_time_duration(self.time_entry.duration_in_seconds);
	NSString *newValue = [NSString stringWithUTF8String:str];
	free(str);

	[self.durationTextField setStringValue:newValue];
}

@end
