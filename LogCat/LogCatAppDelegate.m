//
//  LogCatAppDelegate.m
//  LogCat
//
//  Created by Janusz Bossy on 16.11.2011.
//  Copyright (c) 2011 SplashSoftware.pl. All rights reserved.
//

#import "LogCatAppDelegate.h"
#import "LogDatasource.h"
#import "LogCatPreferences.h"
#import "SelectableTableView.h"
#import "MenuDelegate.h"
#import "NSString_Extension.h"
#import "DeviceListDatasource.h"

#define DARK_GREEN_COLOR [NSColor colorWithCalibratedRed:0 green:0.50 blue:0 alpha:1.0]

#define SEARCH_FORWARDS   1
#define SEARCH_BACKWARDS -1

#define USE_DARK_BACKGROUND NO

#define LOG_DATA_KEY @"logdata"
#define LOG_FILE_VERSION @"version"

@interface LogCatAppDelegate () {
    LogDatasource* logDatasource;
    DeviceListDatasource* deviceSource;
    NSArray* baseRowTemplates;
    NSArray* logData;
    NSPredicate* predicate;
    
    NSArray* loadedLogData;
    
    NSInteger findIndex;
}

- (void)registerDefaults;
- (void)readSettings;
- (void)startAdb;
- (void) copySelectedRow: (BOOL) escapeSpecialChars :(BOOL) messageOnly;
- (NSDictionary*) dataForRow: (NSUInteger) rowIndex;

@end

@implementation LogCatAppDelegate
@synthesize remoteScreenMonitorButton;

@synthesize filterListTable;
@synthesize window = _window;
@synthesize logDataTable;
@synthesize textEntry;

- (void)registerDefaults {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary* s = [NSMutableDictionary dictionary];
    [s setObject:[NSNumber numberWithInt:0] forKey:@"logVerboseBold"];
    [s setObject:[NSNumber numberWithInt:0] forKey:@"logDebugBold"];
    [s setObject:[NSNumber numberWithInt:0] forKey:@"logInfoBold"];
    [s setObject:[NSNumber numberWithInt:0] forKey:@"logWarningBold"];
    [s setObject:[NSNumber numberWithInt:0] forKey:@"logErrorBold"];
    [s setObject:[NSNumber numberWithInt:1] forKey:@"logFatalBold"];
    [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor blueColor]] forKey:@"logVerboseColor"];
    [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:@"logDebugColor"];
    [s setObject:[NSArchiver archivedDataWithRootObject:DARK_GREEN_COLOR] forKey:@"logInfoColor"];
    
    [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor orangeColor]] forKey:@"logWarningColor"];
    [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor redColor]] forKey:@"logErrorColor"];
    [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor redColor]] forKey:@"logFatalColor"];
    [defaults registerDefaults:s];
}

- (void)readSettings {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSColor* v = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"logVerboseColor"]];
    NSColor* d = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"logDebugColor"]];
    NSColor* i = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"logInfoColor"]];
    NSColor* w = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"logWarningColor"]];
    NSColor* e = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"logErrorColor"]];
    NSColor* f = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"logFatalColor"]];
    
    NSArray* typeKeys = [NSArray arrayWithObjects:@"V", @"D", @"I", @"W", @"E", @"F", nil];
    
    colors = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:v, d, i, w, e, f, nil]
                                          forKeys:typeKeys];
    
    NSFont* vfont = [[defaults objectForKey:@"logVerboseBold"] boolValue] ? BOLD_FONT : REGULAR_FONT;
    NSFont* dfont = [[defaults objectForKey:@"logDebugBold"] boolValue] ? BOLD_FONT : REGULAR_FONT;
    NSFont* ifont = [[defaults objectForKey:@"logInfoBold"] boolValue] ? BOLD_FONT : REGULAR_FONT;
    NSFont* wfont = [[defaults objectForKey:@"logWarningBold"] boolValue] ? BOLD_FONT : REGULAR_FONT;
    NSFont* efont = [[defaults objectForKey:@"logErrorBold"] boolValue] ? BOLD_FONT : REGULAR_FONT;
    NSFont* ffont = [[defaults objectForKey:@"logFatalBold"] boolValue] ? BOLD_FONT : REGULAR_FONT;
    
    fonts = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:vfont, dfont, ifont, wfont, efont, ffont, nil]
                                         forKeys:typeKeys];
    
    // Load User Defined Filters
    filters = [NSMutableDictionary new];
    NSDictionary* loadedFilters = [[NSUserDefaults standardUserDefaults] valueForKey:KEY_PREFS_FILTERS];
    if (loadedFilters == nil) {
        NSArray* keys = [NSArray arrayWithObjects:
                         @"LogLevel Verbose",
                         @"LogLevel Info",
                         @"LogLevel Debug",
                         @"LogLevel Warn",
                         @"LogLevel Error", nil];
        
        NSArray* logLevels = [NSArray arrayWithObjects:
                 @"type ==[cd] 'V' OR type ==[cd] 'I' OR type ==[cd] 'W' OR type ==[cd] 'E' OR type ==[cd] 'F' OR type ==[cd] 'A'",
                 @"type ==[cd] 'I' OR type ==[cd] 'W' OR type ==[cd] 'E' OR type ==[cd] 'F' OR type ==[cd] 'A'",
                 @"type ==[cd] 'D' OR type ==[cd] 'I' OR type ==[cd] 'W' OR type ==[cd] 'E' OR type ==[cd] 'F' OR type ==[cd] 'A'",
                 @"type ==[cd] 'W' OR type CONTAINS[cd] 'E' OR type ==[cd] 'F'",
                 @"type ==[cd] 'E' OR type ==[cd] 'F' OR type ==[cd] 'A'",
                 nil];

        for(int i = 0; i < [keys count]; i++) {
            NSString* key = [keys objectAtIndex:i];
            NSString* value = [logLevels objectAtIndex:i];
            
            NSPredicate* savePredicate = [NSPredicate predicateWithFormat:value];
            [filters setObject:savePredicate forKey:key];
        }
        
    } else {
        NSArray *sortedKeys = [[loadedFilters allKeys] sortedArrayUsingSelector: @selector(compare:)];
        for (NSString* key in sortedKeys) {
            NSPredicate* savePredicate = [NSPredicate predicateWithFormat:[loadedFilters objectForKey:key]];
            [filters setObject:savePredicate forKey:key];
        }
    }
    
    if (USE_DARK_BACKGROUND) {
        [filterListTable setBackgroundColor:[NSColor blackColor]];
        [logDataTable setBackgroundColor:[NSColor blackColor]];
        
        //[logDataTable setGridStyleMask:NSTableViewGridNone];
        [logDataTable setGridColor:[NSColor darkGrayColor]];
    }
    
    [filterListTable reloadData];

}

- (void) updateStatus {

    NSString* status = @"";
    
    if (loadedLogData != nil) {
        status = [NSString stringWithFormat:@"viewing %ld of %ld", [logData count], [loadedLogData count]];
    } else {
        status = [NSString stringWithFormat:@"viewing %ld of %ld", [logData count], [logDatasource logEventCount]];
    }
    
    if (predicate != nil) {
        status = [NSString stringWithFormat:@"%@ \t\t\t filter: %@", status, [predicate description]];
    }
    
    [self.statusTextField setStringValue:status];
}

- (void) resetConnectButton {
    if ([logDatasource isLogging]) {
        [self.restartAdb setTitle:@"Disconnect"];
    } else {
        [self.restartAdb setTitle:@"Connect"];
    }
}

- (BOOL) windowShouldClose:(id) sender {
    [self.window orderOut:self];
    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    [self.window makeKeyAndOrderFront:self];
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"applicationDidFinishLaunching: %@", aNotification);
    findIndex = -1;
    baseRowTemplates = nil;
    
    logDatasource = [[LogDatasource alloc] init];
    [logDatasource setDelegate:self];
    
    [self.logDataTable setMenuDelegate:self];
    [self.filterListTable setMenuDelegate:self];
    
    [self registerDefaults];
    
    [self readSettings];
    
    previousString = nil;
    scrollToBottom = YES;
    
    deviceSource = [[DeviceListDatasource alloc] init];
    [deviceSource setDelegate:self];
    [deviceSource loadDeviceList];

    [self.filterListTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    
    id clipView = [[self.logDataTable enclosingScrollView] contentView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(myBoundsChangeNotificationHandler:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:clipView];
}

- (void)startAdb {
    [self.window makeKeyAndOrderFront:self];
    [logDatasource startLogger];

}

- (IBAction)remoteScreenMonitor:(id)sender {

    if (remoteScreen  == nil) {
        remoteScreen = [[RemoteScreenMonitorSheet alloc] init];
        [remoteScreen setDeviceId:[logDatasource deviceId]];
    }

    if(! [[remoteScreen window] isVisible] ) {
        NSLog(@"window: %@", [remoteScreen window]);
        [remoteScreen setDeviceId:[logDatasource deviceId]];
        [remoteScreen showWindow:self];
    }
}

- (IBAction)cancelDevicePicker:(id)sender {
    NSLog(@"cancelDevicePicker");
    [NSApp endSheet:sheetDevicePicker returnCode:NSCancelButton];
}

- (IBAction)startLogForDevice:(id)sender {
    NSLog(@"cancelDevicePicker");
    [NSApp endSheet:sheetDevicePicker returnCode:NSOKButton];
}

- (void)fontsChanged {
    [self readSettings];
    [self.logDataTable reloadData];
}

- (void)myBoundsChangeNotificationHandler:(NSNotification *)aNotification {
    if ([aNotification object] == [[self.logDataTable enclosingScrollView] contentView]) {
        NSRect visibleRect = [[[self.logDataTable enclosingScrollView] contentView] visibleRect];
        float maxy = 0;
        maxy = [logData count] * 19;
        if (visibleRect.origin.y + visibleRect.size.height >= maxy) {
            scrollToBottom = YES;
        } else {
            scrollToBottom = NO;
        }
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    if (aTableView == logDataTable) {
        return [logData count];
    }
    
    return [filters count] + 1;
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (USE_DARK_BACKGROUND) {
        [cell setBackgroundColor:[NSColor blackColor]];
        [cell setDrawsBackground: YES];
    }
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    if (aTableView == logDataTable) {
        NSDictionary* row;
        row = [logData objectAtIndex: rowIndex];
        return [row objectForKey:[aTableColumn identifier]];
    }
    if (rowIndex == 0) {
        return @"All messages";
    } else {
        NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(compare:)];
        return [sortedKeys objectAtIndex:rowIndex-1];
    }
}


- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    if (tableView == filterListTable) {        
        return [tableColumn dataCell];
    }

    NSTextFieldCell *aCell = [tableColumn dataCell];
    NSString* rowType;
    NSDictionary* data = [logData objectAtIndex: rowIndex];

    rowType = [data objectForKey:KEY_TYPE];
    NSIndexSet *selection = [tableView selectedRowIndexes];
    if ([selection containsIndex:rowIndex]) {
        // Make selected cell text selected color so it is easier to read
        [aCell setTextColor:[NSColor selectedControlTextColor]];
        [aCell setFont:[NSFont boldSystemFontOfSize:12]];
        
    } else {
        [aCell setTextColor:[colors objectForKey:rowType]];
        [aCell setFont:[fonts objectForKey:rowType]];
        
    }
    return aCell;
}

- (IBAction)search:(id)sender {
    NSString* searchString = [[sender stringValue] copy];
    [self doSearch:searchString : SEARCH_FORWARDS];
    
    
}

- (void) doSearch: (NSString*) searchString : (NSInteger) direction {
    if (logData == nil || searchString == nil || [searchString length] == 0) {
        scrollToBottom = YES;
        return;
    }
    
    [logDataTable deselectAll:self];
    NSLog(@"Search for: \"%@\" from index %ld direction=%ld", searchString, findIndex, direction);
    if (findIndex == -1) {
        findIndex = [[logDataTable selectedRowIndexes] lastIndex];
        if (findIndex > [logData count]) {
            findIndex = [logData count]-1;
        }
    }
    
    // TODO: allow for search up or down Command-G and Shift-Command-G
    NSInteger searchedRows = 0;
    while (true) {
        findIndex += direction;
        searchedRows++;
        findIndex = (findIndex%[logData count]);
        NSDictionary* logEvent = [logData objectAtIndex: findIndex ];
        NSString* stringToSearch = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@",
                                    [logEvent valueForKey:KEY_APP],
                                    [logEvent valueForKey:KEY_TEXT],
                                    [logEvent valueForKey:KEY_PID],
                                    [logEvent valueForKey:KEY_TID],
                                    [logEvent valueForKey:KEY_TYPE],
                                    [logEvent valueForKey:KEY_NAME]
                                    ];
        
        if ([stringToSearch rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) {
            NSLog(@"Row %ld matches", findIndex);
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:findIndex];
            [logDataTable selectRowIndexes:indexSet byExtendingSelection:NO];
            
            
            [self.logDataTable scrollRowToVisible:findIndex];
            return;
        }
        
        if (searchedRows >= [logData count]) {
            NSLog(@"No matches found");
            NSBeep();
            return;
        }
    }
}

- (IBAction)find:(id)sender {
    [self.searchField becomeFirstResponder];
}

- (IBAction)findNext:(id)sender {
    NSString* searchString = [[self.searchFieldCell stringValue] copy];
    if (searchString == nil || [searchString length] == 0) {
        [self.searchField becomeFirstResponder];
        return;
    }
    [self doSearch:searchString : SEARCH_FORWARDS];
}

- (IBAction)findPrevious:(id)sender {
    NSString* searchString = [[self.searchFieldCell stringValue] copy];
    [self doSearch:searchString : SEARCH_BACKWARDS];
}

/**
 A filter was selected
 **/
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
    if (aTableView != filterListTable) {
        findIndex = rowIndex;
        return YES;
    }
    
    bool filterSelected = rowIndex != 0;
    if (!filterSelected) {
        predicate = nil;
        NSLog(@"Clear Filter");
        [filterListTable deselectAll:self];
    }
    scrollToBottom = YES;
    
    return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    NSLog(@"Selected Did Change... %@", aNotification);
    NSTableView* tv = [aNotification object];
    if (tv != filterListTable) {
        return;
    }
    
    NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(compare:)];

    NSMutableArray* predicates = [NSMutableArray arrayWithCapacity:1];
    if ([filterListTable selectedRow] > 0) {
        NSLog(@"Filter by %ld predicate", [filterListTable selectedRow]);

        NSIndexSet* selectedIndexes = [filterListTable selectedRowIndexes];
        if ([selectedIndexes count] == 1) {
            NSUInteger index = [selectedIndexes firstIndex];
            NSString* key = [sortedKeys objectAtIndex:index-1];
            predicate = [filters objectForKey:key];
        } else {

            NSUInteger index = [selectedIndexes firstIndex];
            while (index != NSNotFound) {
                NSString* key = [sortedKeys objectAtIndex: (index-1) ];
                [predicates addObject:[filters objectForKey:key]];
                index = [selectedIndexes indexGreaterThanIndex:index];
            }
            predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
        }
     } else {
         NSLog(@"No Predicated Selected");
     }

    NSLog(@"Filter By: %@", [predicate description]);
    if (loadedLogData != nil) {
        logData = [loadedLogData filteredArrayUsingPredicate: predicate];
    } else {
        logData = [logDatasource eventsForPredicate:predicate];
    }
    [logDataTable reloadData];
    [self updateStatus];
}

- (IBAction)addFilter {
    NSString* unamedFilter = @"unamed";
    
    NSPredicate* filter = [filters objectForKey:unamedFilter];
    if (filter != nil) {
        NSUInteger unamedCounter = 0;
        while (filter != nil) {
            // Find a filter name that has not been used yet
            unamedFilter = [NSString stringWithFormat:@"unamed_%ld", unamedCounter];
            filter = [filters objectForKey:unamedFilter];
        }
    }
    
    [self.savePredicateName setStringValue:unamedFilter];
    [self showPredicateEditor:self];
    
}

- (IBAction)removeFilter {
    NSIndexSet* selectedIndexes = [filterListTable selectedRowIndexes];
    if ([selectedIndexes count] > 1) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Delete Failed"
                                         defaultButton:@"OK" alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"Select one filter at a time to delete."];
        [alert runModal];
        return;
    }
    
    NSInteger selectedIndex = [[filterListTable selectedRowIndexes] firstIndex]-1;
    if (selectedIndex < 0) {
        // Can't remove "All Messages"
        return;
    }
    
    NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(compare:)];
    NSString* sortKey = [sortedKeys objectAtIndex:selectedIndex];

    [filters removeObjectForKey:sortKey];
    [self saveFilters];
    [filterListTable reloadData];
}

- (IBAction)cancelSheet:(id)sender {
    [NSApp endSheet:sheetAddFilter returnCode:NSCancelButton];
}

- (IBAction)acceptSheet:(id)sender {
    [NSApp endSheet:sheetAddFilter returnCode:NSOKButton];
}

- (IBAction)preferences:(id)sender {
    [[LogCatPreferences sharedPrefsWindowController] showWindow:nil];
}

- (IBAction)clearLog:(id)sender {
    [logDatasource clearLog];
    logData = [NSArray array];
}

- (IBAction)restartAdb:(id)sender {
    if ([logDatasource isLogging]) {
        [logDatasource stopLogger];
    } else {
        [self startAdb];
    }
}

- (IBAction)filterToolbarClicked:(NSSegmentedControl*)sender {
    NSInteger segment = [sender selectedSegment];
    switch (segment) {
        case 0:
            [self addFilter];
            break;
        case 1:
            [self removeFilter];
            
        default:
            break;
    }
}

/**
 ChrisW: I am being lazy and calling a perl script I wrote to send text typed in the terminal to the device.
 It would be ncie to do it all in ObjC.
 **/
- (IBAction)openTypingTerminal:(id)sender {
    NSLog(@"openTypingTerminal");
    NSBundle *mainBundle=[NSBundle mainBundle];
    NSString *path=[mainBundle pathForResource:@"atext" ofType:nil];
    
    NSString *s = [NSString stringWithFormat: @"tell application \"Terminal\" to do script \"%@\"", path];
    
    NSAppleScript *as = [[NSAppleScript alloc] initWithSource: s];
    [as executeAndReturnError:nil];
    
    
}

- (IBAction)newWindow:(id)sender {
    
    // This is a quick hack to try out multiple logger windows.
    NSTask *task;
    task = [[NSTask alloc] init];
    NSBundle *mainBundle=[NSBundle mainBundle];
    
    NSString *path = @"/usr/bin/open";
    [task setLaunchPath:path];
    
    NSArray* arguments = [NSArray arrayWithObjects: @"-n", [mainBundle bundlePath], nil];
    [task setArguments: arguments];
    [task launch];

}


- (void)deviceSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    NSLog(@"Device Picker Sheet Finished %ld", returnCode);
    [sheetDevicePicker orderOut:self];
    if (returnCode == NSCancelButton) {
        return;
    }
    
    NSInteger index = [[sheetDevicePicker deviceButton] indexOfSelectedItem];
    
    NSDictionary* device = [[sheetDevicePicker devices] objectAtIndex:index];
    if (device != nil) {
        [logDatasource setDeviceId:[device valueForKey:DEVICE_ID_KEY]];
        [[self window] setTitle:[[sheetDevicePicker deviceButton] titleOfSelectedItem]];
        [self startAdb];
    }
}

/*
 Called when RemoteScreenSheet ends
 */
- (void)remoteScreenDidEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    NSLog(@"Remote Screen Sheet Did End: %ld", returnCode);

}


- (IBAction)copyPlain:(id)sender {
    NSLog(@"copyPlain");
    [self copySelectedRow:NO: NO];
}

- (IBAction)copyMessageOnly:(id)sender {
    NSLog(@"copyMessageOnly");
    [self copySelectedRow:NO: YES];
    
}

- (void) newFilterFromSelected:(id)sender {
    NSLog(@"newFilterFromSelected: %ld, %ld [%@]", [filterListTable rightClickedColumn], [filterListTable rightClickedRow], sender);
    if (predicate == nil) {
        NSLog(@"newFilterFromSelected: No predicate set.");
        return;
    }
//    NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(compare:)];
//    NSInteger selected = [filterListTable rightClickedRow]-1;
    
//    NSString* key = [sortedKeys objectAtIndex:selected];
//    NSPredicate* savedPredicate = [filters objectForKey:key];
    [self.predicateEditor setObjectValue:predicate];
    
    [self.savePredicateName setStringValue:[self newUnusedPredicateName]];
    
    NSLog(@"showPredicateEditor");
    [NSApp beginSheet:self.predicateSheet
	   modalForWindow:nil
		modalDelegate:nil
	   didEndSelector:NULL
		  contextInfo:nil];
}

- (void) editFilter:(id)sender {
    NSLog(@"editFilter: %ld, %ld [%@]", [filterListTable rightClickedColumn], [filterListTable rightClickedRow], sender);
    if ([filterListTable rightClickedRow] < 1) {
        return;
    }
    NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(compare:)];
    NSInteger selected = [filterListTable rightClickedRow]-1;
    
    NSString* key = [sortedKeys objectAtIndex:selected];
    NSPredicate* savedPredicate = [filters objectForKey:key];
    [self.predicateEditor setObjectValue:savedPredicate];
    [self.savePredicateName setStringValue:key];
    
    NSLog(@"showPredicateEditor");
    [NSApp beginSheet:self.predicateSheet
	   modalForWindow:nil
		modalDelegate:nil
	   didEndSelector:NULL
		  contextInfo:nil];
    
}

- (IBAction)filterBySelected:(id)sender {
    NSLog(@"filterBySelected: %ld, %ld [%@]", [logDataTable rightClickedColumn], [logDataTable rightClickedRow], sender);

    NSTableColumn* aColumn = [[logDataTable tableColumns] objectAtIndex:[logDataTable rightClickedColumn]];
    NSDictionary* rowDetails = [self dataForRow: [logDataTable rightClickedRow]];

    NSString* columnName = [[aColumn headerCell] title];
    NSLog(@"ColumnName: %@", columnName);
    NSString* value = [rowDetails valueForKey:[aColumn identifier]];
    
    NSPredicate* newPredicate = [NSPredicate predicateWithFormat:@"%K ==[cd] %@", [aColumn identifier], value];
    
    [self.predicateEditor setObjectValue:newPredicate];
    [self.savePredicateName setStringValue:[NSString stringWithFormat:@"%@_%@", columnName, value]];
    
    NSLog(@"showPredicateEditor");
    [NSApp beginSheet:self.predicateSheet
	   modalForWindow:nil
		modalDelegate:nil
	   didEndSelector:NULL
		  contextInfo:nil];
    
}

- (NSMenu*) menuForTableView: (NSTableView*) tableView column:(NSInteger) column row:(NSInteger) row {
    
    if (tableView == logDataTable) {
        NSMenu *menu = [[NSMenu alloc] init];
        if ([logDataTable selectedRow] > 0) {
            [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"C"]];
            [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Copy Message" action:@selector(copyMessageOnly:) keyEquivalent:@""]];
        }
        
        if (column != 0) {
            [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Add Filter..." action:@selector(filterBySelected:) keyEquivalent:@""]];
        }
        return menu;
    } else {
        if (row < 0) {
            return nil;
        }
        NSMenu *menu = [[NSMenu alloc] init];

        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Edit Filter..." action:@selector(editFilter:) keyEquivalent:@""]];
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"New Filter From Selected..." action:@selector(newFilterFromSelected:) keyEquivalent:@""]];
        
        return menu;
    }
}

- (NSDictionary*) dataForRow: (NSUInteger) rowIndex {
    NSDictionary* rowDetails = [logData objectAtIndex:rowIndex];

    return rowDetails;
}

- (void) copy:(id)sender {
    NSLog(@"Copy Selected Rows");
    [self copySelectedRow: NO: NO];
}

- (void) copySelectedRow: (BOOL) escapeSpecialChars :(BOOL) messageOnly{
    
    int selectedRow = (int)[logDataTable selectedRow]-1;
    int	numberOfRows = (int)[logDataTable numberOfRows];
    
    NSLog(@"Selected Row: %d, Total Rows: %d", selectedRow, numberOfRows);
    
    NSIndexSet* indexSet = [logDataTable selectedRowIndexes];
    if (indexSet != nil && [indexSet firstIndex] != NSNotFound) {
        NSPasteboard	*pb = [NSPasteboard generalPasteboard];
        NSMutableString *tabsBuf = [NSMutableString string];
        NSMutableString *textBuf = [NSMutableString string];
        
        // Step through and copy data from each of the selected rows
        NSUInteger currentIndex = [indexSet firstIndex];
        
        while (currentIndex != NSNotFound) {
            NSDictionary* rowDetails = nil;
            
            NSMutableString* rowType = [NSMutableString string];
            rowDetails = [self dataForRow: currentIndex];
            
            if (messageOnly) {
                [rowType appendFormat:@"%@",
                         [rowDetails objectForKey:KEY_TEXT]];
                
            } else {
                [rowType appendFormat:@"%@\t%@\t%@\t%@\t%@\t%@\t%@",
                 [rowDetails objectForKey:KEY_TIME],
                 [rowDetails objectForKey:KEY_APP],
                 [rowDetails objectForKey:KEY_PID],
                 [rowDetails objectForKey:KEY_TID],
                 [rowDetails objectForKey:KEY_TYPE],
                 [rowDetails objectForKey:KEY_NAME],
                 [rowDetails objectForKey:KEY_TEXT]];
            }
            
            NSString* value = rowType;
            value = [[value stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByReplacingOccurrencesOfString:@"\r" withString:@" "];

            
            [textBuf appendFormat:@"%@\n", value];
            [tabsBuf appendFormat:@"%@\n", value];
            // delete the last tab. (But don't delete the last CR)
            if ([tabsBuf length]) {
                [tabsBuf deleteCharactersInRange:NSMakeRange([tabsBuf length]-1, 1)];
            }
            
            // Next Index
            currentIndex = [indexSet indexGreaterThanIndex: currentIndex];
        }
        [pb declareTypes:@[NSStringPboardType] owner:nil];
        [pb setString:[NSString stringWithString:textBuf] forType:NSStringPboardType];
    }
}

#pragma mark -
#pragma mark DeviceListDatasourceDelegate
#pragma mark -

- (void) onDevicesConneceted: (NSArray*) devices {
    NSLog(@"Connected Devices: %@", devices);
    
    if (sheetDevicePicker == nil) {
        [NSBundle loadNibNamed:DEVICE_PICKER_SHEET owner:self];
    }
    
    [NSApp beginSheet:sheetDevicePicker modalForWindow:self.window modalDelegate:self didEndSelector:@selector(deviceSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
    NSPopUpButton* devicePicker = [sheetDevicePicker deviceButton];
    [devicePicker removeAllItems];
    [sheetDevicePicker setDevices:devices];

    NSMutableArray* titles = [NSMutableArray arrayWithCapacity:[devices count]];
    for (NSDictionary* device in devices) {
        NSString* title = [NSString stringWithFormat:@"%@ - %@", [device valueForKey:DEVICE_TYPE_KEY], [device valueForKey:DEVICE_ID_KEY]];
        
        [titles addObject:title];
    }
        
    [devicePicker addItemsWithTitles:titles];    
}

- (void) onDeviceModel: (NSString*) deviceId: (NSString*) model {
    NSLog(@"DeviceID: %@, Model: %@", deviceId, model);
    [[self window] setTitle:[NSString stringWithFormat:@"%@ - %@", model, deviceId]];
}


#pragma mark -
#pragma mark LogcatDatasourceDelegate
#pragma mark -

- (void) onLoggerStarted {
    NSLog(@"LogcatDatasourceDelegate::onLoggerStarted");
    [self resetConnectButton];
    
    NSString* deviceId = [logDatasource deviceId];
    if (deviceId != nil && [deviceId length] > 0) {
        [deviceSource requestDeviceModel:deviceId];
    }
}

- (void) onLoggerStopped {
    NSLog(@"LogcatDatasourceDelegate::onLoggerStopped");
    [self resetConnectButton];
}

- (void) onLogUpdated {
    /*
     This reloads the table for every log message. It is performming well right now. Maybe as multiple devices
     are supported it may get sluggish. If so we should set a flag and periodically reload the veiw.
     */
    loadedLogData = nil;
    logData = [logDatasource eventsForPredicate:predicate];
    [self.logDataTable reloadData];
    
    if (scrollToBottom) {
        [self.logDataTable scrollRowToVisible:[logData count]-1];
    }
    
    [self updateStatus];
}

- (void) onMultipleDevicesConnected {
    NSLog(@"LogcatDatasourceDelegate::onMultipleDevicesConnected");
    [deviceSource loadDeviceList];
}

- (void) onDeviceNotFound {
    NSLog(@"LogcatDatasourceDelegate::onDeviceNotFound");
    [logDatasource setDeviceId:nil];
}

- (IBAction)saveDocument:(id)sender {
    if (logDatasource != nil && [logDatasource isLogging]) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Cannot save."
                                         defaultButton:@"OK" alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"Disconnect from device and try again."];
        [alert runModal];
        return;
    }
    
    NSSavePanel* saveDlg = [NSSavePanel savePanel];
    NSArray* extensions = [[NSArray alloc] initWithObjects:@"logcat", nil];
    [saveDlg setAllowedFileTypes:extensions];
    
    if ( [saveDlg runModal] == NSOKButton ) {
        
        NSURL*  saveDocPath = [saveDlg URL];
        NSLog(@"Save document to: %@", saveDocPath);
        
        NSMutableDictionary* saveDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [saveDict setObject:@"1" forKey:LOG_FILE_VERSION];
        [saveDict setObject:logData forKey:LOG_DATA_KEY];
        [saveDict writeToURL:saveDocPath atomically:NO];
    }
}

- (IBAction)openLogcatFile:(id)sender {
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:YES];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setCanChooseDirectories:NO];
    
    if ( [openDlg runModal] == NSOKButton )
    {
        NSArray* urls = [openDlg URLs];
        if (urls != nil && [urls count] > 0) {
            if (logDatasource != nil && [logDatasource isLogging]) {
                [logDatasource stopLogger];
                logDatasource = nil;
            }
            
            NSURL* url = [urls objectAtIndex:0];
            NSLog(@"Open url: %@", url);
            NSDictionary* savedData = [NSDictionary dictionaryWithContentsOfURL:url];
            loadedLogData = [savedData valueForKey:LOG_DATA_KEY];
            logData = loadedLogData;
            [logDataTable reloadData];
        }
    }
}

#pragma -
#pragma mark Predicate/Filter Editor
#pragma -

- (IBAction)showPredicateEditor:(id)sender {

    NSLog(@"Filter Name: %@", @"This will be used for saved predicates");
    BOOL isFirstRun = NO;
    if (baseRowTemplates == nil)
    {
        baseRowTemplates = [self.predicateEditor rowTemplates];
        NSLog(@"Existing Templates: [%@]", baseRowTemplates);
        isFirstRun = YES;
    }
    
    NSMutableArray* allTemplates = [NSMutableArray arrayWithArray:baseRowTemplates];
	
    [self.predicateEditor setRowTemplates:allTemplates];
    if (isFirstRun)
    {
        NSPredicate* defaultPredicate = [NSPredicate predicateWithFormat:@"(app ==[cd] 'YOUR_APP_NAME') AND ((type ==[cd] 'E') OR (type ==[cd] 'W'))"];
        [self.predicateEditor setObjectValue:defaultPredicate];
        [self.predicateEditor addRow:self];
    }
    
    NSLog(@"showPredicateEditor");
    [NSApp beginSheet:self.predicateSheet
	   modalForWindow:nil
		modalDelegate:nil
	   didEndSelector:NULL
		  contextInfo:nil];
}

- (IBAction)onPredicateEdited:(id)sender {
    NSLog(@"onPredicateEdited: %@", [self.predicateEditor objectValue]);
}

- (IBAction)closePredicateSheet:(id)sender {
    NSLog(@"closePredicateSheet");
    [self applyPredicate:sender];

    [self.savePredicateName setStringValue:@""];
    [NSApp endSheet:self.predicateSheet];
	[self.predicateSheet orderOut:sender];
    
}

- (IBAction)cancelPredicateEditing:(id)sender {
    NSLog(@"cancelPredicateEditing");

    predicate = nil;
    logData = [logDatasource eventsForPredicate: predicate];
    [self.logDataTable reloadData];
    
    [NSApp endSheet:self.predicateSheet];
	[self.predicateSheet orderOut:sender];
}

- (IBAction)applyPredicate:(id)sender {
    NSLog(@"applyPredicate: %@", [self.predicateEditor predicate]);
    predicate = [self.predicateEditor predicate];
    
    [self.predicateText setStringValue:[self.predicateEditor objectValue]];
    logData = [logDatasource eventsForPredicate: predicate];
    [self.logDataTable reloadData];
}

- (IBAction)savePredicate:(id)sender {
    NSString* filterName = [self.savePredicateName stringValue];
    if (filterName == nil || [filterName length] == 0) {
        filterName = [self newUnusedPredicateName];
    }
    
    [filters setObject:[self.predicateEditor predicate] forKey: filterName];
    [self saveFilters];
    [filterListTable reloadData];
}

- (IBAction)importFilters:(id)sender {
    // TODO: popup file broswer for selecting from list of filters
}

- (IBAction)exportFilters:(id)sender {
    // TODO: popup list of filters to for user to select from
}

- (void) saveFilters {
    NSMutableDictionary* filtersToSave = [NSMutableDictionary dictionaryWithCapacity:[filters count]];
    NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(compare:)];
    for(NSString* key in sortedKeys) {
        NSPredicate* aPredicate = [filters objectForKey:key];
        [filtersToSave setObject:[aPredicate predicateFormat] forKey:key];
    }
    
    [[NSUserDefaults standardUserDefaults] setValue:filtersToSave forKey:KEY_PREFS_FILTERS];
}

- (NSString*) newUnusedPredicateName {
    NSString* unamedFilter = @"unamed";
    
    NSPredicate* filter = [filters objectForKey:unamedFilter];
    if (filter != nil) {
        NSUInteger unamedCounter = 0;
        while (filter != nil) {
            // Find a filter name that has not been used yet
            unamedFilter = [NSString stringWithFormat:@"unamed_%ld", unamedCounter];
            filter = [filters objectForKey:unamedFilter];
        }
    }
    
    return unamedFilter;
}

@end
