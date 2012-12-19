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

@interface LogCatAppDelegate () {
    LogDatasource* logDatasource;
    DeviceListDatasource* deviceSource;
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

- (void)registerDefaults
{
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
    [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor greenColor]] forKey:@"logInfoColor"];
    [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor orangeColor]] forKey:@"logWarningColor"];
    [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor redColor]] forKey:@"logErrorColor"];
    [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor redColor]] forKey:@"logFatalColor"];
    [defaults registerDefaults:s];
}


- (void)readSettings
{
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
    
    filters = [[NSUserDefaults standardUserDefaults] valueForKey:KEY_PREFS_FILTERS];
    if (filters == nil) {
        filters = [NSMutableArray new];
    } else {
        filters = [[NSMutableArray alloc] initWithArray:filters];
        [filterListTable reloadData];
    }
    [self sortFilters];
}

- (void) resetConnectButton {
    if ([logDatasource isLogging]) {
        [self.restartAdb setTitle:@"Disconnect"];
    } else {
        [self.restartAdb setTitle:@"Connect"];
    }
}

- (BOOL) windowShouldClose:(id) sender
{
    [self.window orderOut:self];
    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    [self.window makeKeyAndOrderFront:self];
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSLog(@"applicationDidFinishLaunching: %@", aNotification);
    
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

    //[self startAdb];
    
    [self.filterListTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    
    id clipView = [[self.logDataTable enclosingScrollView] contentView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(myBoundsChangeNotificationHandler:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:clipView];
}

- (void)startAdb
{
    [self.window makeKeyAndOrderFront:self];
    [logDatasource startLogger];

}

- (IBAction)remoteScreenMonitor:(id)sender {

    if (remoteScreen  == nil) {
        remoteScreen = [[RemoteScreenMonitorSheet alloc] init];
    }

    if(! [[remoteScreen window] isVisible] ) {
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

- (void)fontsChanged
{
    [self readSettings];
    [self.logDataTable reloadData];
}

- (void)myBoundsChangeNotificationHandler:(NSNotification *)aNotification
{
    if ([aNotification object] == [[self.logDataTable enclosingScrollView] contentView]) {
        NSRect visibleRect = [[[self.logDataTable enclosingScrollView] contentView] visibleRect];
        float maxy = 0;
        maxy = [logDatasource getDisplayCount] * 19;
        if (visibleRect.origin.y + visibleRect.size.height >= maxy) {
            scrollToBottom = YES;
        } else {
            scrollToBottom = NO;
        }
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    if (aTableView == logDataTable) {
        return [logDatasource getDisplayCount];
    }
    return [filters count] + 1;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    if (aTableView == logDataTable) {
        NSDictionary* row;
        row = [logDatasource valueForIndex: rowIndex];
        return [row objectForKey:[aTableColumn identifier]];
    }
    if (rowIndex == 0) {
        return @"All messages";
    } else {
        return [[filters objectAtIndex:rowIndex-1] valueForKey:KEY_FILTER_NAME];
    }
}


- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    if (tableView == filterListTable) {
        return [tableColumn dataCell];
    }

    NSTextFieldCell *aCell = [tableColumn dataCell];
    NSString* rowType;
    NSDictionary* data = [logDatasource valueForIndex: rowIndex];

    rowType = [data objectForKey:KEY_TYPE];
    [aCell setTextColor:[colors objectForKey:rowType]];
    [aCell setFont:[fonts objectForKey:rowType]];
    return aCell;
}

- (IBAction)search:(id)sender
{
    NSString* searchString = [[sender stringValue] copy];
    [logDatasource setSearchString:searchString];
}

/**
 A filter was selected
 **/
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
    if (aTableView != filterListTable) {
        return YES;
    }
    
    bool filterSelected = rowIndex != 0;
    if (filterSelected) {
        [filterToolbar setEnabled:filterSelected forSegment:1];
        NSDictionary* filter = [filters objectAtIndex:rowIndex-1];
        [logDatasource setFilter:filter];
    } else {
        [logDatasource setFilter:nil];
    }
    
    return YES;
}

- (IBAction)addFilter
{
    if (sheetAddFilter == nil) {
        [NSBundle loadNibNamed:FILTER_SHEET owner:self];
    }
    [tfFilterName becomeFirstResponder];
    
    [[sheetAddFilter filterName] setStringValue:@""];
    [[sheetAddFilter filterCriteria]  setStringValue:@""];
    
    [NSApp beginSheet:sheetAddFilter modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)removeFilter
{
    [filters removeObjectAtIndex:[[filterListTable selectedRowIndexes] firstIndex] - 1];
    [filterListTable reloadData];
    [[NSUserDefaults standardUserDefaults] setValue:filters forKey:KEY_PREFS_FILTERS];

}

- (void) sortFilters {
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:KEY_FILTER_NAME ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    [filters sortUsingDescriptors:sortDescriptors];
    
    [filterListTable reloadData];
}

- (IBAction)cancelSheet:(id)sender
{
    [NSApp endSheet:sheetAddFilter returnCode:NSCancelButton];
}

- (IBAction)acceptSheet:(id)sender
{
    [NSApp endSheet:sheetAddFilter returnCode:NSOKButton];
}

- (IBAction)preferences:(id)sender 
{
    [[LogCatPreferences sharedPrefsWindowController] showWindow:nil];
}

- (IBAction)clearLog:(id)sender 
{
//    [self clearLog];
    [logDatasource clearLog];
}

- (IBAction)restartAdb:(id)sender
{
    if ([logDatasource isLogging]) {
        [logDatasource stopLogger];
    } else {
        [self startAdb];
    }
}

- (IBAction)filterToolbarClicked:(NSSegmentedControl*)sender 
{
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
 I am being lazy and calling a perl script I wrote to send text typed in the terminal to the device.
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


- (void)deviceSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
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
- (void)remoteScreenDidEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    NSLog(@"Remote Screen Sheet Did End: %ld", returnCode);

}


/**
 FilterSheet closes to calls this method
 **/
- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    NSLog(@"didEndSheet: %ld", returnCode);

    [sheetAddFilter orderOut:self];
    if (returnCode == NSCancelButton) {
        return;
    }

    NSString* filterName = [tfFilterName stringValue];
    NSString* filterType = [puFilterField titleOfSelectedItem];
    NSString* filterText = [tfFilterText stringValue];
    
    NSDictionary* filter = (__bridge NSDictionary *)contextInfo;
    if (filter == nil) {
        filter = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filterName, filterType, filterText, nil]
                                        forKeys:[NSArray arrayWithObjects:KEY_FILTER_NAME, KEY_FILTER_TYPE, KEY_FILTER_TEXT, nil]];
        [filters addObject:filter];
        NSLog(@"Added filter: %@", filter);
    } else {
        [filters removeObject:filter];
        [filter setValue:filterName forKey:KEY_FILTER_NAME];
        [filter setValue:filterType forKey:KEY_FILTER_TYPE];
        [filter setValue:filterText forKey:KEY_FILTER_TEXT];
        NSLog(@"Filter changed to: %@", filter);
        
        [filters addObject:filter];
    }
    
    
    [[NSUserDefaults standardUserDefaults] setValue:filters forKey:KEY_PREFS_FILTERS];

    [tfFilterName setStringValue:@""];
    [puFilterField selectItemAtIndex:0];
    [tfFilterText setStringValue:@""];
    
    [self sortFilters];
}

- (IBAction)copyPlain:(id)sender {
    NSLog(@"copyPlain");
    [self copySelectedRow:NO: NO];
}

- (IBAction)copyMessageOnly:(id)sender {
    NSLog(@"copyMessageOnly");
    [self copySelectedRow:NO: YES];
    
}

- (void) editFilter:(id)sender {
    NSLog(@"editFilter: %ld, %ld [%@]", [filterListTable rightClickedColumn], [filterListTable rightClickedRow], sender);
    if ([filterListTable rightClickedRow] < 1) {
        return;
    }
    
    NSDictionary* filter = [filters objectAtIndex:[filterListTable rightClickedRow]-1];
    
    if (sheetAddFilter == nil) {
        [NSBundle loadNibNamed:FILTER_SHEET owner:self];
    }
    

    [[sheetAddFilter filterName] setStringValue:[filter objectForKey:KEY_FILTER_NAME]];
    [sheetAddFilter selectItemWithTitie:[filter objectForKey:KEY_FILTER_TYPE]];
    [[sheetAddFilter filterCriteria]  setStringValue:[filter objectForKey:KEY_FILTER_TEXT]];
    
    [NSApp beginSheet:sheetAddFilter modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:(__bridge void *)(filter)];
}

- (IBAction)filterBySelected:(id)sender {
    
    NSLog(@"filterBySelected: %ld, %ld [%@]", [logDataTable rightClickedColumn], [logDataTable rightClickedRow], sender);
    if (sheetAddFilter == nil) {
        [NSBundle loadNibNamed:FILTER_SHEET owner:self];
    }
    NSTableColumn* aColumn = [[logDataTable tableColumns] objectAtIndex:[logDataTable rightClickedColumn]];
    
    [tfFilterName becomeFirstResponder];
    NSDictionary* rowDetails = [self dataForRow: [logDataTable rightClickedRow]];
    
    NSString* columnName = [[aColumn headerCell] title];
    NSLog(@"ColumnName: %@", columnName);
    NSString* value = [rowDetails valueForKey:[aColumn identifier]];
    [[sheetAddFilter filterName] setStringValue:[NSString stringWithFormat:@"%@_%@", columnName, value]];
    [sheetAddFilter selectItemWithTitie:[aColumn identifier]];
    [[sheetAddFilter filterCriteria]  setStringValue:value];
    
    [NSApp beginSheet:sheetAddFilter modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];

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
        
        return menu;
    }
}

- (NSDictionary*) dataForRow: (NSUInteger) rowIndex {
    NSDictionary* rowDetails = [logDatasource valueForIndex:rowIndex];

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
    [self.logDataTable reloadData];
    if (scrollToBottom) {
        [self.logDataTable scrollRowToVisible:[logDatasource getDisplayCount]-1];
    }

}

- (void) onMultipleDevicesConnected {
    NSLog(@"LogcatDatasourceDelegate::onMultipleDevicesConnected");
    [deviceSource loadDeviceList];
}

- (void) onDeviceNotFound {
    NSLog(@"LogcatDatasourceDelegate::onDeviceNotFound");
    [logDatasource setDeviceId:nil];
}


@end
