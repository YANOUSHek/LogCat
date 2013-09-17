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

#define SEARCH_WITH_REGEX YES
#define USE_DARK_BACKGROUND NO

#define LOG_DATA_KEY @"logdata"
#define LOG_FILE_VERSION @"version"

#define DEFAULT_PREDICATE @"(app ==[cd] 'YOUR_APP_NAME') AND ((type ==[cd] 'E') OR (type ==[cd] 'W'))"

@interface LogCatAppDelegate () {
    CGFloat fontHeight;
    CGFloat fontPointSize;
    
    BOOL resizeCellHeightBasedOnFontSize;
    
    NSNumber* selectedLogMessage;
}

@property (strong, nonatomic) LogDatasource* logDatasource;
@property (strong, nonatomic) DeviceListDatasource* deviceSource;
@property (strong, nonatomic) NSArray* baseRowTemplates;
@property (strong, nonatomic) NSArray* logData;
@property (strong, nonatomic) NSPredicate* predicate;
@property (strong, nonatomic) NSArray* loadedLogData;
@property (nonatomic) NSInteger findIndex;
@property (strong, nonatomic) NSNumber* selectedLogMessage;


- (void)registerDefaults;
- (void)readSettings;
- (void)startAdb;
- (void) copySelectedRow: (BOOL) escapeSpecialChars :(BOOL) messageOnly;
- (NSDictionary*) dataForRow: (NSUInteger) rowIndex;
- (void) applySelectedFilters;

@end

@implementation LogCatAppDelegate

@synthesize logDatasource = _logDatasource;
@synthesize deviceSource = _deviceSource;
@synthesize baseRowTemplates = _baseRowTemplates;
@synthesize logData = _logData;
@synthesize predicate = _predicate;
@synthesize loadedLogData = _loadedLogData;
@synthesize findIndex = _findIndex;

@synthesize adbPath = _adbPath;
@synthesize remoteScreenMonitorButton = _remoteScreenMonitorButton;
@synthesize filterListTable = _filterListTable;
@synthesize window = _window;
@synthesize logDataTable = _logDataTable;
@synthesize textEntry = _textEntry;
@synthesize selectedLogMessage = _selectedLogMessage;

- (void)registerDefaults {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary* s = [NSMutableDictionary dictionary];
    s[@"logVerboseBold"] = @0;
    s[@"logDebugBold"] = @0;
    s[@"logInfoBold"] = @0;
    s[@"logWarningBold"] = @0;
    s[@"logErrorBold"] = @0;
    s[@"logFatalBold"] = @1;
    s[@"logVerboseColor"] = [NSArchiver archivedDataWithRootObject:[NSColor blueColor]];
    s[@"logDebugColor"] = [NSArchiver archivedDataWithRootObject:[NSColor blackColor]];
    s[@"logInfoColor"] = [NSArchiver archivedDataWithRootObject:DARK_GREEN_COLOR];
    
    s[@"logWarningColor"] = [NSArchiver archivedDataWithRootObject:[NSColor orangeColor]];
    s[@"logErrorColor"] = [NSArchiver archivedDataWithRootObject:[NSColor redColor]];
    s[@"logFatalColor"] = [NSArchiver archivedDataWithRootObject:[NSColor redColor]];
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
    
    NSArray* typeKeys = @[@"V", @"D", @"I", @"W", @"E", @"F"];
    
    colors = [NSDictionary dictionaryWithObjects:@[v, d, i, w, e, f]
                                          forKeys:typeKeys];
    
    
    fontPointSize = [defaults floatForKey:FONT_SIZE_KEY];
    if (fontPointSize == 0) {
        NSLog(@"Will use font size 11 as default");
        fontPointSize = 11;
    }
    
    NSFont* vfont = [[defaults objectForKey:@"logVerboseBold"] boolValue] ? BOLD_FONT(fontPointSize) : REGULAR_FONT(fontPointSize);
    NSFont* dfont = [[defaults objectForKey:@"logDebugBold"] boolValue] ? BOLD_FONT(fontPointSize) : REGULAR_FONT(fontPointSize);
    NSFont* ifont = [[defaults objectForKey:@"logInfoBold"] boolValue] ? BOLD_FONT(fontPointSize) : REGULAR_FONT(fontPointSize);
    NSFont* wfont = [[defaults objectForKey:@"logWarningBold"] boolValue] ? BOLD_FONT(fontPointSize) : REGULAR_FONT(fontPointSize);
    NSFont* efont = [[defaults objectForKey:@"logErrorBold"] boolValue] ? BOLD_FONT(fontPointSize) : REGULAR_FONT(fontPointSize);
    NSFont* ffont = [[defaults objectForKey:@"logFatalBold"] boolValue] ? BOLD_FONT(fontPointSize) : REGULAR_FONT(fontPointSize);
    
    fonts = [NSDictionary dictionaryWithObjects:@[vfont, dfont, ifont, wfont, efont, ffont]
                                         forKeys:typeKeys];
    
    fontHeight = [vfont pointSize]*1.5;
    
    // Load User Defined Filters
    filters = [NSMutableDictionary new];
    NSDictionary* loadedFilters = [[NSUserDefaults standardUserDefaults] valueForKey:KEY_PREFS_FILTERS];
    if (loadedFilters == nil) {
        NSArray* keys = @[@"LogLevel Verbose",
                         @"LogLevel Info",
                         @"LogLevel Debug",
                         @"LogLevel Warn",
                         @"LogLevel Error"];
        
        NSArray* logLevels = @[
                 @"type IN[cd] 'V,I,W,E,F,A'",
                 @"type IN[cd] 'I,W,E,F,A'",
                 @"type IN[cd] 'D,I,W,E,F,A'",
                 @"type IN[cd] 'W,E,F,A'",
                 @"type IN[cd] 'E,F,A"];

        for(int i = 0; i < [keys count]; i++) {
            NSString* key = keys[i];
            NSString* value = logLevels[i];
            
            NSPredicate* savePredicate = [NSPredicate predicateWithFormat:value];
            filters[key] = savePredicate;
        }
        
    } else {
        NSArray *sortedKeys = [[loadedFilters allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
        for (NSString* key in sortedKeys) {
            NSPredicate* savePredicate = [NSPredicate predicateWithFormat:loadedFilters[key]];
            filters[key] = savePredicate;
        }
    }
    
    if (USE_DARK_BACKGROUND) {
        [self.filterListTable setBackgroundColor:[NSColor blackColor]];
        [self.logDataTable setBackgroundColor:[NSColor blackColor]];
        
        //[logDataTable setGridStyleMask:NSTableViewGridNone];
        [self.logDataTable setGridColor:[NSColor darkGrayColor]];
    }
    
    [self.filterListTable reloadData];
    self.adbPath = [defaults objectForKey:@"adbPath"];
    if (self.adbPath == nil && [self.adbPath length] == 0) {
        // Use built in adb
        //NSBundle *mainBundle = [NSBundle mainBundle];
        //self.adbPath = [mainBundle pathForResource:@"adb" ofType:nil];
    }
    
//    NSLog(@"Will use ADB: [%@]", self.adbPath);
}

- (void) updateStatus {

    NSString* status = @"";
    
    if (self.loadedLogData != nil) {
        status = [NSString stringWithFormat:@"viewing %ld of %ld", [self.logData count], [self.loadedLogData count]];
    } else {
        status = [NSString stringWithFormat:@"viewing %ld of %ld", [self.logData count], [self.logDatasource logEventCount]];
    }
    
    if (self.predicate != nil) {
        status = [NSString stringWithFormat:@"%@ \t\t\t filter: %@", status, [self.predicate description]];
    }
    
    [self.statusTextField setStringValue:status];
}

- (void) resetConnectButton {
    if ([self.logDatasource isLogging]) {
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
    resizeCellHeightBasedOnFontSize = NO;
    self.findIndex = -1;
    self.baseRowTemplates = nil;
    
    self.logDatasource = [[LogDatasource alloc] init];
    [self.logDatasource setDelegate:self];
    
    [self.logDataTable setMenuDelegate:self];
    [self.filterListTable setMenuDelegate:self];
    
    [self registerDefaults];
    
    [self readSettings];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.adbPath]) {
        [self startAdb];
    } else {
        NSAlert* alert = [NSAlert alertWithMessageText:@"ADB executable not found"
                                         defaultButton:@"OK" alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"Please check your preferences and make sure the path is correct. By default, it's located in the platform-tools folder inside Android SDK."];
        [alert runModal];
        [self.window orderOut:self];
        [[LogCatPreferences sharedPrefsWindowController] showWindow:nil];
    }
    
    previousString = nil;
    scrollToBottom = YES;
    
    self.deviceSource = [[DeviceListDatasource alloc] init];
    [self.deviceSource setDelegate:self];
    [self.deviceSource loadDeviceList];

    [self.filterListTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    
    id clipView = [[self.logDataTable enclosingScrollView] contentView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(myBoundsChangeNotificationHandler:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:clipView];
}

- (void)startAdb {
    [self.window makeKeyAndOrderFront:self];
    [self.logDatasource startLogger];
}


- (IBAction)remoteScreenMonitor:(id)sender {

    if (remoteScreen  == nil) {
        remoteScreen = [[RemoteScreenMonitorSheet alloc] init];
        [remoteScreen setDeviceId:[self.logDatasource deviceId]];
    }

    if(! [[remoteScreen window] isVisible] ) {
        NSLog(@"window: %@", [remoteScreen window]);
        [remoteScreen setDeviceId:[self.logDatasource deviceId]];
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

- (void)adbPathChanged:(NSString*)newPath {
    self.adbPath = newPath;
}


- (void)myBoundsChangeNotificationHandler:(NSNotification *)aNotification {
    if (resizeCellHeightBasedOnFontSize) {
        // This is not working properly when the cell heights are dynamically adjusted.
        // TODO: fix this calculation
        if ([aNotification object] == [[self.logDataTable enclosingScrollView] contentView]) {
            NSRect visibleRect = [[[self.logDataTable enclosingScrollView] contentView] visibleRect];
            float maxy = ([self.logData count] * (fontHeight)) - (fontHeight * 10);
            float location = (visibleRect.origin.y + visibleRect.size.height);
            //        NSLog(@"loc : %f", location);
            //        NSLog(@"maxy: %f", maxy);
            if (location > maxy) {
                scrollToBottom = YES;
            } else {
                scrollToBottom = NO;
            }
        }
        
    } else {
        // Assume the cell heights are fixed.
        if ([aNotification object] == [[self.logDataTable enclosingScrollView] contentView]) {
            NSRect visibleRect = [[[self.logDataTable enclosingScrollView] contentView] visibleRect];
            float maxy = 0;
            maxy = [self.logData count] * 19;
            if (visibleRect.origin.y + visibleRect.size.height >= maxy) {
                scrollToBottom = YES;
            } else {
                scrollToBottom = NO;
            }
        }

    }
    
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    if (aTableView == self.logDataTable) {
        return [self.logData count];
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
    if (aTableView == self.logDataTable) {
        NSDictionary* row;
        row = (self.logData)[rowIndex];
        return row[[aTableColumn identifier]];
    }
    if (rowIndex == 0) {
        return @"All messages";
    } else {
        NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
        return sortedKeys[rowIndex-1];
    }
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (resizeCellHeightBasedOnFontSize) {
    
        if (tableView == self.logDataTable) {
            NSDictionary* data = (self.logData)[row];
            NSString* rowType = data[KEY_TYPE];
            NSFont* font = fonts[rowType];
            fontHeight = [font pointSize]*1.5;
        //        NSLog(@"Height: %f", height);
            return fontHeight; //
        }
    }
    return [tableView rowHeight];
}


- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    if (tableView == self.filterListTable) {        
        return [tableColumn dataCell];
    }

    NSTextFieldCell *aCell = [tableColumn dataCell];
    NSString* rowType;
    NSDictionary* data = (self.logData)[rowIndex];

    rowType = data[KEY_TYPE];
    NSIndexSet *selection = [tableView selectedRowIndexes];
    if ([selection containsIndex:rowIndex]) {
        NSFont* font = fonts[rowType];
        
        // Make selected cell text selected color so it is easier to read
        [aCell setTextColor:[NSColor selectedControlTextColor]];
        [aCell setFont:[NSFont boldSystemFontOfSize:[font pointSize]]];
        
    } else {
        [aCell setTextColor:colors[rowType]];
        [aCell setFont:fonts[rowType]];
        
    }
    return aCell;
}

- (IBAction)search:(id)sender {
    NSString* searchString = [[sender stringValue] copy];
    [self doSearch:searchString : SEARCH_FORWARDS];
    
    
}

- (void) doSearch: (NSString*) searchString : (NSInteger) direction {
    if (self.logData == nil || searchString == nil || [searchString length] == 0) {
        scrollToBottom = YES;
        return;
    }
    
    [self.logDataTable deselectAll:self];
    NSLog(@"Search for: \"%@\" from index %ld direction=%ld", searchString, self.findIndex, direction);
    if (self.findIndex == -1) {
        self.findIndex = [[self.logDataTable selectedRowIndexes] lastIndex];
        if (self.findIndex > [self.logData count]) {
            self.findIndex = [self.logData count]-1;
        }
    }
    
    // TODO: allow for search up or down Command-G and Shift-Command-G
    NSInteger searchedRows = 0;
    while (true) {
        self.findIndex += direction;
        searchedRows++;
        self.findIndex = (self.findIndex%[self.logData count]);
        NSDictionary* logEvent = (self.logData)[self.findIndex];
        NSString* stringToSearch = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@",
                                    [logEvent valueForKey:KEY_APP],
                                    [logEvent valueForKey:KEY_TEXT],
                                    [logEvent valueForKey:KEY_PID],
                                    [logEvent valueForKey:KEY_TID],
                                    [logEvent valueForKey:KEY_TYPE],
                                    [logEvent valueForKey:KEY_NAME]
                                    ];
        if (SEARCH_WITH_REGEX) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:searchString options:0 error:NULL];
            NSTextCheckingResult *match = [regex firstMatchInString:stringToSearch options:0 range:NSMakeRange(0, [stringToSearch length])];
            if (match != nil && [match range].location != NSNotFound) {
                NSLog(@"Row %ld matches", self.findIndex);
                NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:self.findIndex];
                [self.logDataTable selectRowIndexes:indexSet byExtendingSelection:NO];
                
                [self.logDataTable scrollRowToVisible:self.findIndex];
                return;
            }
        } else {
            if ([stringToSearch rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) {
                NSLog(@"Row %ld matches", self.findIndex);
                NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:self.findIndex];
                [self.logDataTable selectRowIndexes:indexSet byExtendingSelection:NO];
                
                
                [self.logDataTable scrollRowToVisible:self.findIndex];
                return;
            }
        }
        
        if (searchedRows >= [self.logData count]) {
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
    if (aTableView != self.filterListTable) {
        self.findIndex = rowIndex;
        return YES;
    }
    
    bool filterSelected = rowIndex != 0;
    if (!filterSelected) {
        self.predicate = nil;
        NSLog(@"Clear Filter");
        [self.filterListTable deselectAll:self];
    }
    scrollToBottom = YES;
    
    return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    NSLog(@"Selected Did Change... %@", aNotification);
    NSTableView* tv = [aNotification object];
    if (tv == self.logDataTable) {
        
        NSInteger selectedItem = [self.logDataTable selectedRow];
        if (self.logData != nil && selectedItem >= 0 && selectedItem < [self.logData count]) {
            NSLog(@"Selected logDataTable row: %ld", selectedItem);
            NSDictionary* selectedItem = [self.logData objectAtIndex:[self.logDataTable selectedRow]];
            selectedLogMessage = [selectedItem objectForKey:KEY_IDX];
            
        } else {
            selectedLogMessage = nil;
        }
        
        NSLog(@"Selected Log item: %@", selectedLogMessage);
        return;
    } else if (tv != self.filterListTable) {
        return;
    }
    
    [self applySelectedFilters];
}

- (void) applySelectedFilters {
    NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];

    NSMutableArray* predicates = [NSMutableArray arrayWithCapacity:1];
    if ([self.filterListTable selectedRow] > 0) {
        NSLog(@"Filter by %ld predicate", [self.filterListTable selectedRow]);

        NSIndexSet* selectedIndexes = [self.filterListTable selectedRowIndexes];
        if ([selectedIndexes count] == 1) {
            NSUInteger index = [selectedIndexes firstIndex];
            NSString* key = sortedKeys[index-1];
            [predicates addObject:filters[key]];
        } else {

            NSUInteger index = [selectedIndexes firstIndex];
            while (index != NSNotFound) {
                NSString* key = sortedKeys[(index-1)];
                [predicates addObject:filters[key]];
                index = [selectedIndexes indexGreaterThanIndex:index];
            }
        }
     } else {
         NSLog(@"No Predicated Selected");
     }
    
    NSString* quickFilter = [[self quickFilter] stringValue];
    if (quickFilter != nil && [quickFilter length] > 0) {
        if ([quickFilter hasPrefix:@"p: "]) {
            // User interested predicate
            NSString* userPredicate = [quickFilter substringFromIndex:2];
            [predicates addObject:[NSPredicate predicateWithFormat:userPredicate]];
        } else {
            [predicates addObject:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"(name CONTAINS[cd] '%@' OR text CONTAINS[cd] '%@')", quickFilter, quickFilter]]];
        }
    }
    
    self.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    
    NSLog(@"Filter By: %@", [predicates description]);
    if (self.loadedLogData != nil) {
        self.logData = [self.loadedLogData filteredArrayUsingPredicate: self.predicate];
    } else {
        self.logData = [self.logDatasource eventsForPredicate:self.predicate];
    }
    [self.logDataTable reloadData];
    [self updateStatus];
}

- (IBAction)quickFilter:(id)sender {
    NSLog(@"quick filter %@", sender);    
    [self applySelectedFilters];
    
    if (self.logData && selectedLogMessage != nil) {
        int rowIndex = 0;
        for (NSDictionary* logLine in self.logData) {
            if (selectedLogMessage == [logLine objectForKey:KEY_IDX]) {
                NSRect rowRect = [self.logDataTable rectOfRow:rowIndex];
                NSRect viewRect = [[self.logDataTable superview] frame];
                NSPoint scrollOrigin = rowRect.origin;
                scrollOrigin.y = scrollOrigin.y + (rowRect.size.height - viewRect.size.height) / 2;
                if (scrollOrigin.y < 0) {
                    scrollOrigin.y = 0;
                }
                [[[self.logDataTable superview] animator] setBoundsOrigin:scrollOrigin];

                // Select the row again
                NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:rowIndex];
                [self.logDataTable selectRowIndexes:indexSet byExtendingSelection:NO];

                [self.window makeFirstResponder: self.logDataTable];
                break;
            }
            rowIndex++;
        }
    }
    
}

- (IBAction)addFilter {
    NSString* unamedFilter = @"unamed";
    
    NSPredicate* filter = filters[unamedFilter];
    if (filter != nil) {
        NSUInteger unamedCounter = 0;
        while (filter != nil) {
            // Find a filter name that has not been used yet
            unamedFilter = [NSString stringWithFormat:@"unamed_%ld", unamedCounter];
            filter = filters[unamedFilter];
        }
    }
    
    [self.savePredicateName setStringValue:unamedFilter];
    [self showPredicateEditor:self];
    
}

- (IBAction)removeFilter {
    NSIndexSet* selectedIndexes = [self.filterListTable selectedRowIndexes];
    if ([selectedIndexes count] > 1) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Delete Failed"
                                         defaultButton:@"OK" alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"Select one filter at a time to delete."];
        [alert runModal];
        return;
    }
    
    NSInteger selectedIndex = [[self.filterListTable selectedRowIndexes] firstIndex]-1;
    if (selectedIndex < 0) {
        // Can't remove "All Messages"
        return;
    }
    
    NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    NSString* sortKey = sortedKeys[selectedIndex];

    // This is a destructive action. Give user a chance to back out.
    NSAlert *alert = [NSAlert alertWithMessageText:@"Delete Filter?"
                                     defaultButton:@"Yes" alternateButton:@"No"
                                       otherButton:nil
                         informativeTextWithFormat:@"Are you sure you want to delete the filter named \"%@\"", sortKey];
    
    if ([alert runModal] ==  NSAlertDefaultReturn) {
        [filters removeObjectForKey:sortKey];
        [self saveFilters];
        [self.filterListTable reloadData];
    }
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
    self.loadedLogData = nil;
    [self.logDatasource clearLog];
    self.logData = @[];
    
    [[self logDataTable] reloadData];
}

- (IBAction)restartAdb:(id)sender {
    if ([self.logDatasource isLogging]) {
        [self.logDatasource stopLogger];
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

//    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//    NSString *adbPath = [defaults objectForKey:@"adbPath"];

    // TODO: pass the ADB that the app is currently configured to use.
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
    
    NSArray* arguments = @[@"-n", [mainBundle bundlePath]];
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
    
    NSDictionary* device = [sheetDevicePicker devices][index];
    if (device != nil) {
        [self.logDatasource setDeviceId:[device valueForKey:DEVICE_ID_KEY]];
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

- (IBAction) exportSelectedFilters:(id)sender {
    NSIndexSet* selectedRows = [self.filterListTable selectedRowIndexes];
    if ([selectedRows count] == 0) {
        // TODO: show alert about selecting filters to export
        return;
    }
    
    NSUInteger currentIndex = [selectedRows firstIndex];
    
    NSMutableDictionary* dataToExport = [NSMutableDictionary dictionaryWithCapacity:[selectedRows count]];
    
    NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    
    while (currentIndex != NSNotFound) {
        if (currentIndex == 0) {
            currentIndex = [selectedRows indexGreaterThanIndex: currentIndex];
            continue;
        }
        
        NSString* key = sortedKeys[currentIndex-1];
        NSPredicate* aPredicate = filters[key];
        dataToExport[key] = [aPredicate predicateFormat];
        
        // Next Index
        currentIndex = [selectedRows indexGreaterThanIndex: currentIndex];
        
    }
    
    NSSavePanel* saveDlg = [NSSavePanel savePanel];
    NSArray* extensions = @[@"filters"];
    [saveDlg setAllowedFileTypes:extensions];
    
    if ( [saveDlg runModal] == NSOKButton ) {
        
        NSURL*  saveDocPath = [saveDlg URL];
        NSLog(@"Save filter to: %@", saveDocPath);
        [dataToExport writeToURL:saveDocPath atomically:NO];
    }
    
}

- (IBAction)biggerFont:(id)sender {
    NSLog(@"biggerFont");
    NSMutableDictionary* scratchFonts = [NSMutableDictionary dictionary];
    
    fontPointSize += 1;
    if (fontPointSize > 30) {
        fontPointSize = 11;
    }
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:fontPointSize forKey:FONT_SIZE_KEY];
    
    NSArray* keys = [fonts allKeys];
    for (NSString* key in keys) {
        NSFont* font = fonts[key];
        NSFont* newFont = [[NSFontManager sharedFontManager] convertFont:font toSize:fontPointSize];
        scratchFonts[key] = newFont;
    }

    
        
    fonts = scratchFonts;
    
    [self.logDataTable reloadData];
}

- (IBAction)smallerFont:(id)sender {
    NSLog(@"smallerFont");
    NSMutableDictionary* scratchFonts = [NSMutableDictionary dictionary];
    
    fontPointSize -= 1;
    if (fontPointSize < 1) {
        fontPointSize = 11;
    }
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:fontPointSize forKey:FONT_SIZE_KEY];
    
    NSArray* keys = [fonts allKeys];
    for (NSString* key in keys) {
        NSFont* font = fonts[key];
        NSFont* newFont = [[NSFontManager sharedFontManager] convertFont:font toSize:fontPointSize];
        scratchFonts[key] = newFont;
    }
    
    fonts = scratchFonts;
    
    [self.logDataTable reloadData];
}

- (void) newFilterFromSelected:(id)sender {
    NSLog(@"newFilterFromSelected: %ld, %ld [%@]", [self.filterListTable rightClickedColumn], [self.filterListTable rightClickedRow], sender);
    if (self.predicate == nil) {
        NSLog(@"newFilterFromSelected: No predicate set.");
        return;
    }

    [self.predicateEditor setObjectValue:self.predicate];
    [self.savePredicateName setStringValue:[self newUnusedPredicateName]];
    
    NSLog(@"showPredicateEditor");
    [NSApp beginSheet:self.predicateSheet
	   modalForWindow:nil
		modalDelegate:nil
	   didEndSelector:NULL
		  contextInfo:nil];
}

- (void) editFilter:(id)sender {
    NSLog(@"editFilter: %ld, %ld [%@]", [self.filterListTable rightClickedColumn], [self.filterListTable rightClickedRow], sender);
    if ([self.filterListTable rightClickedRow] < 1) {
        return;
    }
    NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    NSInteger selected = [self.filterListTable rightClickedRow]-1;
    
    NSString* key = sortedKeys[selected];
    NSPredicate* savedPredicate = filters[key];
    [self.predicateEditor setObjectValue:savedPredicate];
    [self.savePredicateName setStringValue:key];
    
    [self.predicateText setStringValue:[self.predicateEditor objectValue]];
    
    NSLog(@"showPredicateEditor");
    [NSApp beginSheet:self.predicateSheet
	   modalForWindow:nil
		modalDelegate:nil
	   didEndSelector:NULL
		  contextInfo:nil];
    
}

- (IBAction)filterBySelected:(id)sender {
    NSLog(@"filterBySelected: %ld, %ld [%@]", [self.logDataTable rightClickedColumn], [self.logDataTable rightClickedRow], sender);

    NSTableColumn* aColumn = [self.logDataTable tableColumns][[self.logDataTable rightClickedColumn]];
    NSDictionary* rowDetails = [self dataForRow: [self.logDataTable rightClickedRow]];

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
    
    if (tableView == self.logDataTable) {
        NSMenu *menu = [[NSMenu alloc] init];
        if ([self.logDataTable selectedRow] > 0) {
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
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Export Selected..." action:@selector(exportSelectedFilters:) keyEquivalent:@""]];
        return menu;
    }
}

- (NSDictionary*) dataForRow: (NSUInteger) rowIndex {
    NSDictionary* rowDetails = (self.logData)[rowIndex];

    return rowDetails;
}

- (void) copy:(id)sender {
    NSLog(@"Copy Selected Rows");
    [self copySelectedRow: NO: NO];
}

- (void) copySelectedRow: (BOOL) escapeSpecialChars :(BOOL) messageOnly{
    
    int selectedRow = (int)[self.logDataTable selectedRow]-1;
    int	numberOfRows = (int)[self.logDataTable numberOfRows];
    
    NSLog(@"Selected Row: %d, Total Rows: %d", selectedRow, numberOfRows);
    
    NSIndexSet* indexSet = [self.logDataTable selectedRowIndexes];
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
                         rowDetails[KEY_TEXT]];
                
            } else {
                [rowType appendFormat:@"%@\t%@\t%@\t%@\t%@\t%@\t%@",
                 rowDetails[KEY_TIME],
                 rowDetails[KEY_APP],
                 rowDetails[KEY_PID],
                 rowDetails[KEY_TID],
                 rowDetails[KEY_TYPE],
                 rowDetails[KEY_NAME],
                 rowDetails[KEY_TEXT]];
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
    
    if ([devices count] == 1) {
        NSDictionary* device = devices[0];
        if (device != nil) {
            [self.logDatasource setDeviceId:[device valueForKey:DEVICE_ID_KEY]];
            //[[self window] setTitle:[device objectForKey:@"id"]];
            [self startAdb];
        }
        return;
    }
    
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

- (void) onDeviceModel: (NSString*) deviceId model:(NSString*) model {
    NSLog(@"DeviceID: %@, Model: %@", deviceId, model);
    [[self window] setTitle:[NSString stringWithFormat:@"%@ - %@", model, deviceId]];
}


#pragma mark -
#pragma mark LogcatDatasourceDelegate
#pragma mark -

- (void) onLoggerStarted {
    NSLog(@"LogcatDatasourceDelegate::onLoggerStarted");
    [self resetConnectButton];
    
    NSString* deviceId = [self.logDatasource deviceId];
    if (deviceId != nil && [deviceId length] > 0) {
        [self.deviceSource requestDeviceModel:deviceId];
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
    self.loadedLogData = nil;
    self.logData = [self.logDatasource eventsForPredicate:self.predicate];
    [self.logDataTable reloadData];
    
    if (scrollToBottom) {
        [self.logDataTable scrollRowToVisible:[self.logData count]-1];
    }
    
    [self updateStatus];
}

- (void) onMultipleDevicesConnected {
    NSLog(@"LogcatDatasourceDelegate::onMultipleDevicesConnected");
    [self.deviceSource loadDeviceList];
}

- (void) onDeviceNotFound {
    NSLog(@"LogcatDatasourceDelegate::onDeviceNotFound");
    [self.logDatasource setDeviceId:nil];
}

- (IBAction)saveDocument:(id)sender {
    NSSavePanel* saveDlg = [NSSavePanel savePanel];
    NSArray* extensions = @[@"logcat"];
    [saveDlg setAllowedFileTypes:extensions];
    
    if ( [saveDlg runModal] == NSOKButton ) {
        
        NSURL*  saveDocPath = [saveDlg URL];
        NSLog(@"Save document to: %@", saveDocPath);
        
        NSMutableDictionary* saveDict = [NSMutableDictionary dictionaryWithCapacity:1];
        saveDict[LOG_FILE_VERSION] = @"1";
        saveDict[LOG_DATA_KEY] = self.logData;
        [saveDict writeToURL:saveDocPath atomically:NO];
    }
}

- (IBAction)saveDocumentAsText:(id)sender {
    
    NSSavePanel* saveDlg = [NSSavePanel savePanel];
    NSArray* extensions = @[@"log"];
    [saveDlg setAllowedFileTypes:extensions];
    
    if ( [saveDlg runModal] == NSOKButton ) {
        
        NSURL*  saveDocPath = [saveDlg URL];
        NSLog(@"saveDocumentAsText to: %@", saveDocPath);
        
        NSMutableString* logDataToSave = [NSMutableString stringWithCapacity:0];
        
        for (NSDictionary* data in [self.logDatasource eventsForPredicate:nil]) {
            // Example:
            //     01-25 12:19:59.739 24323 24323 D ViewRootImpl: [ViewRootImpl] action cancel - 1, s:70
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_TIME]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_APP]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_PID]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_TID]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_TYPE]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_NAME]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_TEXT]];
            
            
            [logDataToSave appendFormat:@"\n"];
        }
        
        
        [logDataToSave writeToURL:saveDocPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
    }

}

- (IBAction)saveDocumentVisableAsText:(id)sender {
    if (self.logDatasource != nil && [self.logDatasource isLogging]) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Cannot save."
                                         defaultButton:@"OK" alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"Disconnect from device and try again."];
        [alert runModal];
        return;
    }
    
    NSSavePanel* saveDlg = [NSSavePanel savePanel];
    NSArray* extensions = @[@"log"];
    [saveDlg setAllowedFileTypes:extensions];
    
    if ( [saveDlg runModal] == NSOKButton ) {
        
        NSURL*  saveDocPath = [saveDlg URL];
        NSLog(@"saveDocumentVisableAsText to: %@", saveDocPath);
        
        NSMutableString* logDataToSave = [NSMutableString stringWithCapacity:0];
        
        for (NSDictionary* data in self.logData) {
            // Example:
            //     01-25 12:19:59.739 24323 24323 D ViewRootImpl: [ViewRootImpl] action cancel - 1, s:70
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_TIME]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_APP]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_PID]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_TID]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_TYPE]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_NAME]];
            [logDataToSave appendFormat:@"%@ ", [data valueForKey:KEY_TEXT]];
            
            
            [logDataToSave appendFormat:@"\n"];
        }
        
        
        [logDataToSave writeToURL:saveDocPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
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
            if (self.logDatasource != nil && [self.logDatasource isLogging]) {
                [self.logDatasource stopLogger];
                self.logDatasource = nil;
            }
            
            NSURL* url = urls[0];
            NSLog(@"Open url: %@", url);
            NSDictionary* savedData = [NSDictionary dictionaryWithContentsOfURL:url];
            self.loadedLogData = [savedData valueForKey:LOG_DATA_KEY];
            self.logData = self.loadedLogData;
            [self.logDataTable reloadData];
        }
    }
}

- (IBAction)toggleAutoFollow:(id)sender {
    NSLog(@"toggleAutoFollow");
    scrollToBottom = !scrollToBottom;
    if (scrollToBottom) {
        [self.logDataTable scrollRowToVisible:[self.logData count]-1];
    }
}

#pragma -
#pragma mark Predicate/Filter Editor
#pragma -

- (IBAction)showPredicateEditor:(id)sender {

    NSLog(@"Filter Name: %@", @"This will be used for saved predicates");
    BOOL isFirstRun = NO;
    if (self.baseRowTemplates == nil)
    {
        self.baseRowTemplates = [self.predicateEditor rowTemplates];
        NSLog(@"Existing Templates: [%@]", self.baseRowTemplates);
        isFirstRun = YES;
    }
    
    NSMutableArray* allTemplates = [NSMutableArray arrayWithArray:self.baseRowTemplates];
	
    [self.predicateEditor setRowTemplates:allTemplates];
    if (isFirstRun)
    {
        NSPredicate* defaultPredicate = [NSPredicate predicateWithFormat:DEFAULT_PREDICATE];
        [self.predicateEditor setObjectValue:defaultPredicate];
        [self.predicateEditor addRow:self];
    }
    
    [self.predicateText setStringValue:[self.predicateEditor objectValue]];
    
    if ([self.savePredicateName stringValue] == nil || [[self.savePredicateName stringValue] length] == 0) {
        NSString* unamedFilter = [self newUnusedPredicateName];
        [self.savePredicateName setStringValue:unamedFilter];
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

    NSString* filterName = [self.savePredicateName stringValue];
    if (filterName == nil || [filterName length] == 0) {
        filterName = [self newUnusedPredicateName];
    }
    if (filters[filterName] != nil) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Filter already exists"
                                         defaultButton:@"Overwrite" alternateButton:@"Cancel"
                                           otherButton:nil
                             informativeTextWithFormat:@"Are you sure you want to overwrite the filter with the name \"%@\"", filterName];
        if ([alert runModal] == NSAlertAlternateReturn) {
            // User pressed cancel so don't overwrite filter...
            return;
        }
    }
    
    filters[filterName] = [self.predicateEditor predicate];
    [self saveFilters];
    [self.filterListTable reloadData];
    
    [self.savePredicateName setStringValue:@""];
    [NSApp endSheet:self.predicateSheet];
	[self.predicateSheet orderOut:sender];
    
}

- (IBAction)cancelPredicateEditing:(id)sender {
    NSLog(@"cancelPredicateEditing");

    self.predicate = nil;
    self.logData = [self.logDatasource eventsForPredicate: self.predicate];
    [self.logDataTable reloadData];
    
    [NSApp endSheet:self.predicateSheet];
	[self.predicateSheet orderOut:sender];
}

- (IBAction)applyPredicate:(id)sender {
    NSLog(@"applyPredicate: %@", [self.predicateEditor predicate]);
    self.predicate = [self.predicateEditor predicate];
    
    [self.predicateText setStringValue:[self.predicateEditor objectValue]];
    self.logData = [self.logDatasource eventsForPredicate: self.predicate];
    [self.logDataTable reloadData];
}

- (IBAction)importTextLog:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:YES];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setCanChooseDirectories:NO];
    
    if ( [openDlg runModal] == NSOKButton )
    {
        [self.logDatasource stopLogger];
        
        NSArray* urls = [openDlg URLs];
        if (urls != nil && [urls count] > 0) {
            if (self.logDatasource != nil && [self.logDatasource isLogging]) {
                [self.logDatasource stopLogger];
                self.logDatasource = nil;
            }
            
            NSURL* url = urls[0];
            NSLog(@"Open url: %@", url);
            [openDlg close];
            
            NSArray *arguments = nil;
            arguments = @[[url path]];
            NSLog(@"Will get log from: %@", arguments);
            [self clearLog:nil];
            [self.logDatasource readLog:arguments];
            
//            NSDictionary* filtersToImport = [NSDictionary dictionaryWithContentsOfURL:url];
//            
//            NSArray* keys = [filtersToImport keysSortedByValueUsingSelector:@selector(caseInsensitiveCompare:)];
//            for (NSString* key in keys) {
//                NSString* filter = filtersToImport[key];
//                // TODO: figure out what to do for filters that already exist. For now just overwrite
//                filters[key] = [NSPredicate predicateWithFormat:filter];
//            }
//            
//            [self saveFilters];
//            [self.filterListTable reloadData];
        }
    }

    
}

- (IBAction)importFilters:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:YES];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setCanChooseDirectories:NO];
    
    if ( [openDlg runModal] == NSOKButton )
    {
        NSArray* urls = [openDlg URLs];
        if (urls != nil && [urls count] > 0) {
            if (self.logDatasource != nil && [self.logDatasource isLogging]) {
                [self.logDatasource stopLogger];
                self.logDatasource = nil;
            }
            
            NSURL* url = urls[0];
            NSLog(@"Open url: %@", url);
            NSDictionary* filtersToImport = [NSDictionary dictionaryWithContentsOfURL:url];
            
            NSArray* keys = [filtersToImport keysSortedByValueUsingSelector:@selector(caseInsensitiveCompare:)];
            for (NSString* key in keys) {
                NSString* filter = filtersToImport[key];
                // TODO: figure out what to do for filters that already exist. For now just overwrite
                filters[key] = [NSPredicate predicateWithFormat:filter];
            }
            
            [self saveFilters];
            [self.filterListTable reloadData];
        }
    }
}

- (void) saveFilters {
    NSMutableDictionary* filtersToSave = [NSMutableDictionary dictionaryWithCapacity:[filters count]];
    NSArray *sortedKeys = [[filters allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    for(NSString* key in sortedKeys) {
        NSPredicate* aPredicate = filters[key];
        filtersToSave[key] = [aPredicate predicateFormat];
    }
    
    [[NSUserDefaults standardUserDefaults] setValue:filtersToSave forKey:KEY_PREFS_FILTERS];
}

- (NSString*) newUnusedPredicateName {
    NSString* unamedFilter = @"unamed";
    
    NSPredicate* filter = filters[unamedFilter];
    if (filter != nil) {
        NSUInteger unamedCounter = 0;
        while (filter != nil) {
            // Find a filter name that has not been used yet
            unamedFilter = [NSString stringWithFormat:@"unamed_%ld", unamedCounter];
            filter = filters[unamedFilter];
        }
    }
    
    return unamedFilter;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    NSLog(@"openFile: %@", filename);
    NSString* lowerCaseFilename = [filename lowercaseString];
    
    if ([[lowerCaseFilename lowercaseString] hasSuffix:@"logcat"]) {
        if (self.logDatasource != nil && [self.logDatasource isLogging]) {
            [self.logDatasource stopLogger];
            self.logDatasource = nil;
        }
        
        NSDictionary* savedData = [NSDictionary dictionaryWithContentsOfFile:filename];
        self.loadedLogData = [savedData valueForKey:LOG_DATA_KEY];
        self.logData = self.loadedLogData;
        [[self logDataTable] reloadData];
        return YES;
        
    } else if ([lowerCaseFilename hasSuffix:@"filters"]) {
        NSDictionary* filtersToImport = [NSDictionary dictionaryWithContentsOfFile:filename];
        
        NSArray* keys = [filtersToImport keysSortedByValueUsingSelector:@selector(caseInsensitiveCompare:)];
        for (NSString* key in keys) {
            NSString* filter = filtersToImport[key];
            // TODO: figure out what to do for filters that already exist. For now just overwrite
            filters[key] = [NSPredicate predicateWithFormat:filter];
        }
        
        [self saveFilters];
        [self.filterListTable reloadData];
        return YES;
    }
    
    return NO;
}

@end
