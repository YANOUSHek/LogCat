//
//  LogCatAppDelegate.m
//  LogCat
//
//  Created by Janusz Bossy on 16.11.2011.
//  Copyright (c) 2011 SplashSoftware.pl. All rights reserved.
//

#import "LogCatAppDelegate.h"
#import "LogCatPreferences.h"

#define KEY_TIME @"time"
#define KEY_PID @"pid"
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
@end

@implementation LogCatAppDelegate

@synthesize filterList;
@synthesize window = _window;
@synthesize table;

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

- (void)dealloc
{
    [logcat release];
    [previousString release];
    [keysArray release];
    [search release];
    [colors release];
    [fonts release];
    [filters release];
    [filtered release];
    [super dealloc];
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
    
    colors = [[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:v, d, i, w, e, f, nil] 
                                          forKeys:typeKeys] retain];
    
    NSFont* vf = [[defaults objectForKey:@"logVerboseBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    NSFont* df = [[defaults objectForKey:@"logDebugBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    NSFont* ifont = [[defaults objectForKey:@"logInfoBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    NSFont* wf = [[defaults objectForKey:@"logWarningBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    NSFont* ef = [[defaults objectForKey:@"logErrorBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    NSFont* ff = [[defaults objectForKey:@"logFatalBold"] boolValue] ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    
    fonts = [[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:vf, df, ifont, wf, ef, ff, nil] 
                                         forKeys:typeKeys] retain];
    
    filters = [[NSUserDefaults standardUserDefaults] valueForKey:KEY_PREFS_FILTERS];
    if (filters == nil) {
        filters = [NSMutableArray new];
    } else {
        filters = [[NSMutableArray alloc] initWithArray:filters];
        [filterList reloadData];
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
    [self registerDefaults];
    isRunning = NO;
    [self readSettings];

    [self startAdb];
    
    previousString = nil;
    scrollToBottom = YES;
    logcat = [NSMutableArray new];
    search = [NSMutableArray new];
    text = [NSMutableString new];
    keysArray = [[NSArray arrayWithObjects: KEY_TIME, KEY_PID, KEY_TYPE, KEY_NAME, KEY_TEXT, nil] retain];
    
    [filterList selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    
    id clipView = [[self.table enclosingScrollView] contentView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(myBoundsChangeNotificationHandler:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:clipView];
}

- (void)startAdb
{
    [self.window makeKeyAndOrderFront:self];
    NSThread* thread = [[NSThread alloc] initWithTarget:self selector:@selector(readLog:) object:nil];
    [thread start];
    [thread release];
    isRunning = YES;
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
    
    while (true) {
        NSData *data = nil;
        while (data == nil) {
            data = [file availableData];
        }

        NSString *string;
        string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        [self performSelectorOnMainThread:@selector(appendLog:) withObject:string waitUntilDone:YES];
        [string release];
    }

    [task release];
}

- (void)appendLog:(NSString*)paramString
{
    NSString* currentString;
    if (previousString != nil) {
        currentString = [NSString stringWithFormat:@"%@%@", previousString, paramString];
        [previousString release];
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
                                     @"^\\[\\s(\\d\\d-\\d\\d\\s\\d\\d:\\d\\d:\\d\\d.\\d+)\\s+(\\d*):\\s+(\\d*)\\s(.)/(.*)\\]$"
                                                                              options:0
                                                                                error:nil];
        
        NSTextCheckingResult* match = [expr firstMatchInString:line options:0 range:NSMakeRange(0, [line length])];
        if (match != nil) {
            time = [[line substringWithRange:[match rangeAtIndex:1]] retain];
            pid = [[line substringWithRange:[match rangeAtIndex:2]] retain];
            type = [[line substringWithRange:[match rangeAtIndex:4]] retain];
            name = [[line substringWithRange:[match rangeAtIndex:5]] retain];
            
            // NSLog(@"xxx--- 1 time: %@, pid: %@, type: %@, name: %@", time, pid, type, name);
        } else if (match == nil && [line length] != 0 && !([previousString length] > 0 && [line isEqualToString:previousString])) {
            [text appendString:@"\n"];
            [text appendString:line];
            
            // NSLog(@"xxx--- 2 text: %@", text);
        } else if ([line length] == 0 && time != nil) {
            // NSLog(@"xxx--- 3 text: %@", text);
            
            if ([text rangeOfString:@"\n"].location != NSNotFound) {
                NSLog(@"JEST!");
                NSArray* linesOfText = [text componentsSeparatedByString:@"\n"];
                for (NSString* lineOfText in linesOfText) {
                    if ([lineOfText length] == 0) {
                        continue;
                    }
                    NSArray* values = [NSArray arrayWithObjects: time, pid, type, name, lineOfText, nil];
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
                
                NSArray* values = [NSArray arrayWithObjects: time, pid, type, name, text, nil];
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
            
            [time release];
            [pid release];
            [type release];
            [name release];
            time = nil;
            pid = nil;
            type = nil;
            name = nil;
            [text release];
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
    NSString* realType = KEY_TEXT;
    if ([selectedType isEqualToString:@"PID"]) {
        realType = KEY_PID;
    } else if ([selectedType isEqualToString:@"Tag"]) {
        realType = KEY_NAME;
    } else if ([selectedType isEqualToString:@"Type"]) {
        realType = KEY_TYPE;
    }
    return [[row objectForKey:realType] rangeOfString:[filter objectForKey:KEY_FILTER_TEXT] options:NSCaseInsensitiveSearch].location != NSNotFound;
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
    [search release];
    search = [NSMutableArray new];
    
    if (sender != nil) {
        [searchString release];
        searchString = [[sender stringValue] copy];
    }
    
    NSMutableArray* rows = logcat;
    if (filtered != nil) {
        rows = filtered;
    }
    
    for (NSDictionary* row in rows) {
        if ([[row objectForKey:KEY_NAME] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [search addObject:[[row copy] autorelease]];
        } else if ([[row objectForKey:KEY_TEXT] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [search addObject:[[row copy] autorelease]];
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
            [result addObject:[[row copy] autorelease]];
        }
    }
    return [result autorelease];
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
        [filtered release];
        NSString* selectedType = [filter objectForKey:KEY_FILTER_TYPE];
        NSString* realType = KEY_TEXT;
        if ([selectedType isEqualToString:@"PID"]) {
            realType = KEY_PID;
        } else if ([selectedType isEqualToString:@"Tag"]) {
            realType = KEY_NAME;
        } else if ([selectedType isEqualToString:@"Type"]) {
            realType = KEY_TYPE;
        }
        filtered = [[self findLogsMatching:[filter objectForKey:KEY_FILTER_TEXT] forKey:realType] retain];
    } else {
        [filtered release];
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
    
    [NSApp beginSheet:sheetAddFilter modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)removeFilter
{
    [filters removeObjectAtIndex:[[filterList selectedRowIndexes] firstIndex] - 1];
    [filterList reloadData];
    [[NSUserDefaults standardUserDefaults] setValue:filters forKey:KEY_PREFS_FILTERS];
    // [[NSUserDefaults standardUserDefaults] synchronize];
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
    [logcat release];
    logcat = [NSMutableArray new];
    if (filtered != nil) {
        [filtered release];
        filtered = [NSMutableArray new];
    }
    if ([searchString length] > 0) {
        [search release];
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

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [sheetAddFilter orderOut:self];
    if (returnCode == NSCancelButton) {
        return;
    }

    NSString* filterName = [tfFilterName stringValue];
    NSString* filterType = [puFilterField titleOfSelectedItem];
    NSString* filterText = [tfFilterText stringValue];
    
    NSDictionary* filter = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filterName, filterType, filterText, nil]
                                                       forKeys:[NSArray arrayWithObjects:KEY_FILTER_NAME, KEY_FILTER_TYPE, KEY_FILTER_TEXT, nil]];
    
    [filters addObject:filter];
    [filterList reloadData];
    [[NSUserDefaults standardUserDefaults] setValue:filters forKey:KEY_PREFS_FILTERS];
    
    [tfFilterName setStringValue:@""];
    [puFilterField selectItemAtIndex:0];
    [tfFilterText setStringValue:@""];
}

@end
