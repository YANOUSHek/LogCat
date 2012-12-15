//
//  LogCatAppDelegate.m
//  LogCat
//
//  Created by Janusz Bossy on 16.11.2011.
//  Copyright (c) 2011 SplashSoftware.pl. All rights reserved.
//

#import "LogCatAppDelegate.h"
#import "LogCatPreferences.h"
#import "SelectableTableView.h"
#import "MenuDelegate.h"

#define KEY_TIME @"time"
#define KEY_APP @"app"
#define KEY_PID @"pid"
#define KEY_TID @"tid"
#define KEY_TYPE @"type"
#define KEY_NAME @"name"
#define KEY_TEXT @"text"

#define KEY_FILTER_TEXT @"text"
#define KEY_FILTER_NAME @"name"
#define KEY_FILTER_TYPE @"type"

#define KEY_PREFS_FILTERS @"filters"

@interface LogCatAppDelegate(private)
- (void)registerDefaults;
- (BOOL)filterMatchesRow:(NSDictionary*)row;
- (BOOL)searchMatchesRow:(NSDictionary*)row;
- (void)readSettings;
- (void)startAdb;
- (void) loadPid;
- (void) parsePID: (NSString*) pidInfo;
- (BOOL)isInteger:(NSString *)toCheck;
- (void) copySelectedRow: (BOOL) escapeSpecialChars;
- (NSDictionary*) dataForRow: (NSUInteger) rowIndex;
@end

@implementation LogCatAppDelegate

@synthesize filterList;
@synthesize window = _window;
@synthesize table;
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
    
    NSFont* vf = [[defaults objectForKey:@"logVerboseBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    NSFont* df = [[defaults objectForKey:@"logDebugBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    NSFont* ifont = [[defaults objectForKey:@"logInfoBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    NSFont* wf = [[defaults objectForKey:@"logWarningBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    NSFont* ef = [[defaults objectForKey:@"logErrorBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    NSFont* ff = [[defaults objectForKey:@"logFatalBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    
    fonts = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:vf, df, ifont, wf, ef, ff, nil] 
                                         forKeys:typeKeys];
    
    filters = [[NSUserDefaults standardUserDefaults] valueForKey:KEY_PREFS_FILTERS];
    if (filters == nil) {
        filters = [NSMutableArray new];
    } else {
        filters = [[NSMutableArray alloc] initWithArray:filters];
        [filterList reloadData];
    }
    [self sortFilters];
}

- (void) resetConnectButton {
    [self.restartAdb setEnabled:!isRunning];
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
    [table setMenuDelegate:self];
    [filterList setMenuDelegate:self];
    
    pidMap = [NSMutableDictionary dictionary];
    [self registerDefaults];
    isRunning = NO;
    [self resetConnectButton];
    [self readSettings];

    [self loadPID];
    [self startAdb];
    
    previousString = nil;
    scrollToBottom = YES;
    logcat = [NSMutableArray new];
    search = [NSMutableArray new];
    text = [NSMutableString new];
    keysArray = [NSArray arrayWithObjects: KEY_TIME, KEY_APP, KEY_PID, KEY_TID, KEY_TYPE, KEY_NAME, KEY_TEXT, nil];
    
    [filterList selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    
    id clipView = [[self.table enclosingScrollView] contentView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(myBoundsChangeNotificationHandler:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:clipView];
}

- (void) loadPID {
    NSTask *task;
    task = [[NSTask alloc] init];
    NSBundle *mainBundle=[NSBundle mainBundle];
    NSString *path=[mainBundle pathForResource:@"adb" ofType:nil];
    // NSLog(@"path: %@", path);
    [task setLaunchPath:path];
    
    NSArray *arguments = [NSArray arrayWithObjects: @"shell", @"ps", nil];
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    [task setStandardInput:[NSPipe pipe]];
//    [task setStandardError:pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSMutableData *readData = [[NSMutableData alloc] init];
    
    NSData *data = nil;
    while ((data = [file availableData]) && [data length]) {
        [readData appendData:data];
    }
    
    NSString *string;
    string = [[NSString alloc] initWithData: readData encoding: NSUTF8StringEncoding];
    [self performSelectorOnMainThread:@selector(parsePID:) withObject:string waitUntilDone:YES];
    
}

- (void) parsePID: (NSString*) pidInfo {
    Boolean isFirstLine = YES;
    
    NSArray* lines = [pidInfo componentsSeparatedByString:@"\n"];
    
    for (NSString* line in lines) {
        
        NSArray* args =  [line componentsSeparatedByString:@" "];
        if (isFirstLine) {
            isFirstLine = NO;
        } else if ([args count] < 4) {
            
        } else {
            
            NSString* aPid = @"";
            // find first integer and call that PID
            if (![self isInteger:aPid]) {
                for (NSString* arg in args) {
                    if ([self isInteger:arg]) {
                        aPid = arg;
                        break;
                    }
                }
            }
            
            NSString* aName = [args objectAtIndex:[args count]-1];
            //            NSLog(@"PID: %@  NAME: %@", aPid, aName);
            if ([self isInteger:aPid]) {
                [pidMap setValue:aName forKey:aPid];
            } else {
                NSLog(@"Could not get PID: %@", line);
            }
            
            
        }
    }
    
}

- (BOOL)isInteger:(NSString *)toCheck {
    if([toCheck intValue] != 0) {
        return true;
    } else if([toCheck isEqualToString:@"0"]) {
        return true;
    } else {
        return false;
    }
}

- (void)startAdb
{
    [self.window makeKeyAndOrderFront:self];
    NSThread* thread = [[NSThread alloc] initWithTarget:self selector:@selector(readLog:) object:nil];
    [thread start];
    isRunning = YES;
    [self resetConnectButton];
}

- (void)fontsChanged
{
    [self readSettings];
    [self.table reloadData];
}

- (void)myBoundsChangeNotificationHandler:(NSNotification *)aNotification
{
    if ([aNotification object] == [[self.table enclosingScrollView] contentView]) {
        NSRect visibleRect = [[[self.table enclosingScrollView] contentView] visibleRect];
        float maxy = 0;
        if ([searchString length] > 0) {
            maxy = [search count] * 19;
        } else if (filtered != nil) {
            maxy = [filtered count] * 19;
        } else {
            maxy = [logcat count] * 19;
        }
        
        if (visibleRect.origin.y + visibleRect.size.height >= maxy) {
            scrollToBottom = YES;
        } else {
            scrollToBottom = NO;
        }

    }
}

- (void)readLog:(id)param
{
    
    NSTask *task;
    task = [[NSTask alloc] init];
    NSBundle *mainBundle=[NSBundle mainBundle];
    NSString *path=[mainBundle pathForResource:@"adb" ofType:nil];
    // NSLog(@"path: %@", path);
    
    [task setLaunchPath:path];
    //[task setLaunchPath:@"/bin/cat"];
    
    NSArray *arguments = [NSArray arrayWithObjects: @"logcat", @"-v", @"long", nil];
    //NSArray* arguments = [NSArray arrayWithObjects:@"/Users/YANOUSHek/Desktop/htc_hero.log", nil];
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    [task setStandardInput:[NSPipe pipe]];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    while ([task isRunning]) {
        NSData *data = nil;
        while (data == nil) {
            data = [file availableData];
        }
        if (data != nil) {

            NSString *string;
            string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
            [self performSelectorOnMainThread:@selector(appendLog:) withObject:string waitUntilDone:YES];
        } else {
            NSLog(@"Data was nil...");
        }
    }
    
    isRunning = NO;
    [self resetConnectButton];
    NSLog(@"ADB Exited.");

}

- (void)appendLog:(NSString*)paramString
{
    NSString* currentString;
    if (previousString != nil) {
        currentString = [NSString stringWithFormat:@"%@%@", previousString, paramString];
        previousString = nil;
    } else {
        currentString = [NSString stringWithFormat:@"%@", paramString];
    }
    
    // NSLog(@"currentString: %@", currentString);
    
    if ([currentString rangeOfString:@"\n"].location == NSNotFound) {
        previousString = [currentString copy];
        return;
    }
    
    NSArray* lines = [currentString componentsSeparatedByString:@"\r\n"];
    
    if (![currentString hasSuffix:@"\r\n"]) {
        previousString = [[lines objectAtIndex:[lines count]-1] copy];
    }
    
    for (NSString* line in lines) {
        if ([line hasPrefix:@"--"]) {
            continue;
        }
        NSRegularExpression* expr = [NSRegularExpression regularExpressionWithPattern:
                                     @"^\\[\\s(\\d\\d-\\d\\d\\s\\d\\d:\\d\\d:\\d\\d.\\d+)\\s+(\\d*):(.*)\\s(.)/(.*)\\]$"
                                                                              options:0
                                                                                error:nil];
        
        NSTextCheckingResult* match = [expr firstMatchInString:line options:0 range:NSMakeRange(0, [line length])];
        if (match != nil) {
            time = [line substringWithRange:[match rangeAtIndex:1]];
            pid = [line substringWithRange:[match rangeAtIndex:2]];
            tid = [line substringWithRange:[match rangeAtIndex:3]];
            app = [pidMap objectForKey:pid];
            if (app == nil) {
                NSLog(@"%@ not found in pid map.", pid);
                [self loadPID];
                app = [pidMap objectForKey:pid];
                if (app == nil) {
                    // This is normal during startup because there can be log
                    // messages from apps that are not running anymore.
                    app = @"unknown";
                    [pidMap setValue:app forKey:pid];
                }
            }
            type = [line substringWithRange:[match rangeAtIndex:4]];
            name = [line substringWithRange:[match rangeAtIndex:5]];
            
            // NSLog(@"xxx--- 1 time: %@, app: %@, pid: %@, tid: %@, type: %@, name: %@", time, app, pid, tid, type, name);
        } else if (match == nil && [line length] != 0 && !([previousString length] > 0 && [line isEqualToString:previousString])) {
            [text appendString:@"\n"];
            [text appendString:line];
            
            // NSLog(@"xxx--- 2 text: %@", text);
        } else if ([line length] == 0 && time != nil) {
            // NSLog(@"xxx--- 3 text: %@", text);
            
            if ([text rangeOfString:@"\n"].location != NSNotFound) {
                // NSLog(@"JEST!");
                NSArray* linesOfText = [text componentsSeparatedByString:@"\n"];
                for (NSString* lineOfText in linesOfText) {
                    if ([lineOfText length] == 0) {
                        continue;
                    }
                    NSArray* values = [NSArray arrayWithObjects: time, app, pid, tid, type, name, lineOfText, nil];
                    NSDictionary* row = [NSDictionary dictionaryWithObjects:values
                                                                    forKeys:keysArray];
                    [logcat addObject:row];
                    
                    if (filtered != nil && [self filterMatchesRow:row]) {
                        if ([searchString length] > 0 && [self searchMatchesRow:row]) {
                            [search addObject:row];
                        } else {
                            [filtered addObject:row];
                        }
                    } else if (filtered == nil && [searchString length] > 0 && [self searchMatchesRow:row]) {
                        [search addObject:row];
                    }    
                }
            } else {
                // NSLog(@"xxx--- 4 text: %@", text);
                
                NSArray* values = [NSArray arrayWithObjects: time, app, pid, tid, type, name, text, nil];
                NSDictionary* row = [NSDictionary dictionaryWithObjects:values
                                                                forKeys:keysArray];
                [logcat addObject:row];
                
                if (filtered != nil && [self filterMatchesRow:row]) {
                    if ([searchString length] > 0 && [self searchMatchesRow:row]) {
                        [search addObject:row];
                    } else {
                        [filtered addObject:row];
                    }
                } else if (filtered == nil && [searchString length] > 0 && [self searchMatchesRow:row]) {
                    [search addObject:row];
                }
            }
            
            time = nil;
            app = nil;
            pid = nil;
            tid = nil;
            type = nil;
            name = nil;
            text = [NSMutableString new];
        }
    }
    [self.table reloadData];
    if (scrollToBottom) {
        if ([searchString length] > 0) {
            [self.table scrollRowToVisible:[search count]-1];
        } else if (filtered != nil) {
            [self.table scrollRowToVisible:[filtered count]-1];
        } else {
            [self.table scrollRowToVisible:[logcat count]-1];
        }
    }
}

- (BOOL)filterMatchesRow:(NSDictionary*)row
{
    NSDictionary* filter = [filters objectAtIndex:[filterList selectedRow]-1];
    NSString* selectedType = [filter objectForKey:KEY_FILTER_TYPE];
    NSString* realType = [self getKeyFromType:selectedType];
                          
    return [[row objectForKey:realType] rangeOfString:[filter objectForKey:KEY_FILTER_TEXT] options:NSCaseInsensitiveSearch].location != NSNotFound;
}

- (NSString*) getKeyFromType: (NSString*) selectedType {
    NSString* realType = KEY_TEXT;
    if ([selectedType isEqualToString:@"PID"]) {
        realType = KEY_PID;
    } else if ([selectedType isEqualToString:@"TID"]) {
        realType = KEY_TID;
    } else if ([selectedType isEqualToString:@"APP"]) {
        realType = KEY_APP;
    } else if ([selectedType isEqualToString:@"Tag"]) {
        realType = KEY_NAME;
    } else if ([selectedType isEqualToString:@"Type"]) {
        realType = KEY_TYPE;
    }
    
    return realType;
}

- (BOOL)searchMatchesRow:(NSDictionary*)row
{
    if ([[row objectForKey:KEY_NAME] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    } else if ([[row objectForKey:KEY_TEXT] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    }
    
    return NO;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    if ([[aTableView identifier] isEqualToString:@"logcat"]) {
        if ([searchString length] > 0) {
            return [search count];
        } else if (filtered != nil) {
            return [filtered count];
        } else {
            return [logcat count];
        }
    }
    return [filters count] + 1;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    if ([[aTableView identifier] isEqualToString:@"logcat"]) {
        NSDictionary* row;
        if ([searchString length] > 0) {
            row = [search objectAtIndex:rowIndex];
        } else if (filtered != nil) {
            row = [filtered objectAtIndex:rowIndex];
        } else {
            row = [logcat objectAtIndex:rowIndex];
        }
        return [row objectForKey:[aTableColumn identifier]];
    }
    if (rowIndex == 0) {
        return @"All messages";
    } else {
        return [[filters objectAtIndex:rowIndex-1] valueForKey:KEY_FILTER_NAME];
    }
}


- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    if ([[tableView identifier] isEqualToString:@"filters"]) {
        return [tableColumn dataCell];
    }

    NSTextFieldCell *aCell = [tableColumn dataCell];
    NSString* rowType;
    if ([searchString length] > 0) {
        rowType = [[search objectAtIndex:rowIndex] objectForKey:KEY_TYPE];
    } else if (filtered != nil) {
        rowType = [[filtered objectAtIndex:rowIndex] objectForKey:KEY_TYPE];
    } else {
        rowType = [[logcat objectAtIndex:rowIndex] objectForKey:KEY_TYPE];
    }
    
    [aCell setTextColor:[colors objectForKey:rowType]];
    [aCell setFont:[fonts objectForKey:rowType]];
    return aCell;
}

- (IBAction)search:(id)sender
{
    search = [NSMutableArray new];
    
    if (sender != nil) {
        searchString = [[sender stringValue] copy];
    }
    
    NSMutableArray* rows = logcat;
    if (filtered != nil) {
        rows = filtered;
    }
    
    for (NSDictionary* row in rows) {
        if ([[row objectForKey:KEY_NAME] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [search addObject:[row copy]];
        } else if ([[row objectForKey:KEY_TEXT] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [search addObject:[row copy]];
        }
    }
    [self.table reloadData];
    [self.table scrollRowToVisible:[search count]-1];
}

- (NSMutableArray*)findLogsMatching:(NSString*)string forKey:(NSString*)key
{
    NSMutableArray* result = [NSMutableArray new];
    
    for (NSDictionary* row in logcat) {
        if ([[row objectForKey:key] rangeOfString:string options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [result addObject:[row copy]];
        }
    }
    return result;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
    if (![[aTableView identifier] isEqualToString:@"filters"]) {
        return YES;
    }
    
    bool filterSelected = rowIndex != 0;
    [filterToolbar setEnabled:filterSelected forSegment:1];
    
    if (filterSelected) {
        NSDictionary* filter = [filters objectAtIndex:rowIndex-1];
        NSString* selectedType = [filter objectForKey:KEY_FILTER_TYPE];
        NSString* realType = [self getKeyFromType:selectedType];

        filtered = [self findLogsMatching:[filter objectForKey:KEY_FILTER_TEXT] forKey:realType];
    } else {
        filtered = nil;
    }
    if ([searchString length] > 0) {
        [self search:nil];
    }
    [table reloadData];
    [table scrollRowToVisible:[[table dataSource] numberOfRowsInTableView:table]-1];
    
    return YES;
}

- (IBAction)addFilter
{
    if (sheetAddFilter == nil) {
        [NSBundle loadNibNamed:@"Sheet" owner:self];
    }
    [tfFilterName becomeFirstResponder];
    
    [[sheetAddFilter filterName] setStringValue:@""];
    [[sheetAddFilter filterCriteria]  setStringValue:@""];
    
    
    
    [NSApp beginSheet:sheetAddFilter modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)removeFilter
{
    [filters removeObjectAtIndex:[[filterList selectedRowIndexes] firstIndex] - 1];
    [filterList reloadData];
    [[NSUserDefaults standardUserDefaults] setValue:filters forKey:KEY_PREFS_FILTERS];
    // [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) sortFilters {
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:KEY_FILTER_NAME ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    [filters sortUsingDescriptors:sortDescriptors];
    
    [filterList reloadData];
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
    [self clearLog];
}

- (IBAction)restartAdb:(id)sender
{
    [pidMap removeAllObjects];
    [self clearLog];
    [self startAdb];
}

- (void)clearLog
{
    logcat = [NSMutableArray new];
    if (filtered != nil) {
        filtered = [NSMutableArray new];
    }
    if ([searchString length] > 0) {
        search = [NSMutableArray new];
    }
    [self.table reloadData];
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

- (IBAction)openTypingTerminal:(id)sender {
    NSLog(@"openTypingTerminal");
    NSBundle *mainBundle=[NSBundle mainBundle];
    NSString *path=[mainBundle pathForResource:@"atext" ofType:nil];
    
    NSString *s = [NSString stringWithFormat: @"tell application \"Terminal\" to do script \"%@\"", path];
    
    NSAppleScript *as = [[NSAppleScript alloc] initWithSource: s];
    [as executeAndReturnError:nil];
    
    
}

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
    } else {
        [filter setValue:filterName forKey:KEY_FILTER_NAME];
        [filter setValue:filterType forKey:KEY_FILTER_TYPE];
        [filter setValue:filterText forKey:KEY_FILTER_TEXT];
        [filters removeObject:filter];
    }
    
    [filters addObject:filter];
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
    NSLog(@"editFilter: %ld, %ld [%@]", [filterList rightClickedColumn], [filterList rightClickedRow], sender);
    if ([filterList rightClickedRow] < 1) {
        return;
    }
    
    NSDictionary* filter = [filters objectAtIndex:[filterList rightClickedRow]-1];
    
//    NSDictionary* filter = [filters objectAtIndex:[filterList selectedRow]-1];
//    NSString* selectedType = [filter objectForKey:KEY_FILTER_TYPE];
    //NSString* realType = [self getKeyFromType:selectedType];
    
    if (sheetAddFilter == nil) {
        [NSBundle loadNibNamed:@"Sheet" owner:self];
    }
    
    //KEY_FILTER_NAME, KEY_FILTER_TYPE, KEY_FILTER_TEXT, 

    [[sheetAddFilter filterName] setStringValue:[filter objectForKey:KEY_FILTER_NAME]];
    [sheetAddFilter selectItemWithTitie:[filter objectForKey:KEY_FILTER_TYPE]];
    [[sheetAddFilter filterCriteria]  setStringValue:[filter objectForKey:KEY_FILTER_TEXT]];
    
    [NSApp beginSheet:sheetAddFilter modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:(__bridge void *)(filter)];
}

- (IBAction)filterBySelected:(id)sender {
    
    NSLog(@"filterBySelected: %ld, %ld [%@]", [table rightClickedColumn], [table rightClickedRow], sender);
    if (sheetAddFilter == nil) {
        [NSBundle loadNibNamed:@"Sheet" owner:self];
    }
    NSTableColumn* aColumn = [[table tableColumns] objectAtIndex:[table rightClickedColumn]];
    //NSCell *aCell = [aColumn dataCellForRow:[table rightClickedRow]];
    
    [tfFilterName becomeFirstResponder];
    NSDictionary* rowDetails = [self dataForRow: [table rightClickedRow]];
    
    NSString* columnName = [[aColumn headerCell] title];
    NSLog(@"ColumnName: %@", columnName);
    NSString* value = [rowDetails valueForKey:[aColumn identifier]];
    [[sheetAddFilter filterName] setStringValue:[NSString stringWithFormat:@"%@_%@", columnName, value]];
    [sheetAddFilter selectItemWithTitie:[aColumn identifier]];
    [[sheetAddFilter filterCriteria]  setStringValue:value];
    
    [NSApp beginSheet:sheetAddFilter modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];

}

- (NSMenu*) menuForTableView: (NSTableView*) tableView column:(NSInteger) column row:(NSInteger) row {
    
    if (tableView == table) {
        NSMenu *menu = [[NSMenu alloc] init];
        if ([table selectedRow] > 0) {
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
    NSDictionary* rowDetails = nil;
    
    if ([searchString length] > 0) {
        rowDetails = [search objectAtIndex:rowIndex];
    } else if (filtered != nil) {
        rowDetails = [filtered objectAtIndex:rowIndex];
    } else {
        rowDetails = [logcat objectAtIndex:rowIndex];
    }
    
    return rowDetails;
}

- (void) copy:(id)sender {
    NSLog(@"Copy Selected Rows");
    [self copySelectedRow: NO: NO];
}

- (void) copySelectedRow: (BOOL) escapeSpecialChars :(BOOL) messageOnly{
    
    int selectedRow = (int)[table selectedRow]-1;
    int	numberOfRows = (int)[table numberOfRows];
    
    NSLog(@"Selected Row: %d, Total Rows: %d", selectedRow, numberOfRows);
    
    NSIndexSet* indexSet = [table selectedRowIndexes];
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



@end
