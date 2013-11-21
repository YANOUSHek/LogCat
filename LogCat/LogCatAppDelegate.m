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
#import "NSString_Extension.h"
#import "Constants.h"
#import <AppKit/NSNibLoading.h>

@interface LogCatAppDelegate(private)
- (void)registerDefaults;
- (BOOL)filterMatchesRow:(NSDictionary*)row;
- (BOOL)searchMatchesRow:(NSDictionary*)row;
- (void)readSettings;
- (void)startAdb;
- (void) loadPid;
- (void) parsePID: (NSString*) pidInfo;
- (void) copySelectedRow: (BOOL) escapeSpecialChars;
- (NSDictionary*) dataForRow: (NSUInteger) rowIndex;
@end

@implementation LogCatAppDelegate

@synthesize filterListTable;
@synthesize window = _window;
@synthesize logDataTable;
@synthesize textEntry;

- (void)registerDefaults
{
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary* s = [NSMutableDictionary dictionary];
  [s setObject:[NSNumber numberWithInt:0] forKey:PREFS_LOG_VERBOSE_BOLD];
  [s setObject:[NSNumber numberWithInt:0] forKey:PREFS_LOG_DEBUG_BOLD];
  [s setObject:[NSNumber numberWithInt:0] forKey:PREFS_LOG_INFO_BOLD];
  [s setObject:[NSNumber numberWithInt:0] forKey:PREFS_LOG_WARNING_BOLD];
  [s setObject:[NSNumber numberWithInt:0] forKey:PREFS_LOG_ERROR_BOLD];
  [s setObject:[NSNumber numberWithInt:1] forKey:PREFS_LOG_FATAL_BOLD];
  [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor blueColor]]   forKey:PREFS_LOG_VERBOSE_COLOR];
  [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor blackColor]]  forKey:PREFS_LOG_DEBUG_COLOR];
  [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor greenColor]]  forKey:PREFS_LOG_INFO_COLOR];
  [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor orangeColor]] forKey:PREFS_LOG_WARNING_COLOR];
  [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor redColor]]    forKey:PREFS_LOG_ERROR_COLOR];
  [s setObject:[NSArchiver archivedDataWithRootObject:[NSColor redColor]]    forKey:PREFS_LOG_FATAL_COLOR];
  [defaults registerDefaults:s];
}


- (void)readSettings
{
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSColor* v = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:PREFS_LOG_VERBOSE_COLOR]];
  NSColor* d = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:PREFS_LOG_DEBUG_COLOR]];
  NSColor* i = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:PREFS_LOG_INFO_COLOR]];
  NSColor* w = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:PREFS_LOG_WARNING_COLOR]];
  NSColor* e = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:PREFS_LOG_ERROR_COLOR]];
  NSColor* f = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:PREFS_LOG_FATAL_COLOR]];
  
  colors = [NSDictionary dictionaryWithObjects:@[v, d, i, w, e, f]
                                       forKeys:@[@"V", @"D", @"I", @"W", @"E", @"F"]];
  
  NSFont* vfont = [[defaults objectForKey:PREFS_LOG_VERBOSE_BOLD] boolValue] ? BOLD_FONT : REGULAR_FONT;
  NSFont* dfont = [[defaults objectForKey:PREFS_LOG_DEBUG_BOLD]   boolValue] ? BOLD_FONT : REGULAR_FONT;
  NSFont* ifont = [[defaults objectForKey:PREFS_LOG_INFO_BOLD]    boolValue] ? BOLD_FONT : REGULAR_FONT;
  NSFont* wfont = [[defaults objectForKey:PREFS_LOG_WARNING_BOLD] boolValue] ? BOLD_FONT : REGULAR_FONT;
  NSFont* efont = [[defaults objectForKey:PREFS_LOG_ERROR_BOLD]   boolValue] ? BOLD_FONT : REGULAR_FONT;
  NSFont* ffont = [[defaults objectForKey:PREFS_LOG_FATAL_BOLD]   boolValue] ? BOLD_FONT : REGULAR_FONT;
  
  fonts = [NSDictionary dictionaryWithObjects:@[vfont, dfont, ifont, wfont, efont, ffont]
                                      forKeys:@[@"V", @"D", @"I", @"W", @"E", @"F"]];
  
  filters = [[NSUserDefaults standardUserDefaults] valueForKey:KEY_PREFS_FILTERS];
  if (filters == nil) {
    filters = [NSMutableArray new];
  } else {
    filters = [[NSMutableArray alloc] initWithArray:filters];
    [filterListTable reloadData];
  }
  [self sortFilters];
}

- (void) resetConnectButton
{
  if (isRunning) {
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

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
  [self.window makeKeyAndOrderFront:self];
  return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  [logDataTable setMenuDelegate:self];
  [filterListTable setMenuDelegate:self];
  
  pidMap = [NSMutableDictionary dictionary];
  [self registerDefaults];
  isRunning = NO;
  [self resetConnectButton];
  [self readSettings];

  NSString* adbPath = [[NSUserDefaults standardUserDefaults] objectForKey:PREFS_ADB_PATH];
  if (adbPath && [[NSFileManager defaultManager] fileExistsAtPath:adbPath]) {
    [self loadPID];
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
  logcat = [NSMutableArray new];
  search = [NSMutableArray new];
  text = [NSMutableString new];
  keysArray = @[KEY_TIME, KEY_APP, KEY_PID, KEY_TID, KEY_TYPE, KEY_NAME, KEY_TEXT];
  
  [filterListTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
  
  id clipView = [[self.logDataTable enclosingScrollView] contentView];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(myBoundsChangeNotificationHandler:)
                                               name:NSViewBoundsDidChangeNotification
                                             object:clipView];
}

- (void) loadPID
{
  NSArray *arguments = @[@"shell", @"ps"];
  NSTask *task = [self adbTask: arguments];
  
  NSPipe *pipe;
  pipe = [NSPipe pipe];
  [task setStandardOutput: pipe];
  [task setStandardInput:[NSPipe pipe]];
  
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

- (void) parsePID: (NSString*) pidInfo
{
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
      if (![aPid isInteger]) {
        for (NSString* arg in args) {
          if ([arg isInteger]) {
            aPid = arg;
            break;
          }
        }
      }
      
      NSString* aName = [args objectAtIndex:[args count]-1];
      if ([aPid isInteger]) {
        [pidMap setValue:aName forKey:aPid];
      } else {
        NSLog(@"Could not get PID: %@", line);
      }
    }
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

- (void)adbPathChanged
{
  if (isRunning) {
    [self restartAdb];
  } else {
    [self loadPID];
    [self startAdb];
  }
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
  NSArray *arguments = @[@"logcat", @"-v", @"long"];
  
  NSTask *task = [self adbTask:arguments];
  
  NSPipe *pipe;
  pipe = [NSPipe pipe];
  [task setStandardOutput: pipe];
  [task setStandardInput:[NSPipe pipe]];
  
  NSFileHandle *file;
  file = [pipe fileHandleForReading];
  
  [task launch];
  
  while (isRunning && [task isRunning]) {
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
  
  [task terminate];
  
  isRunning = NO;
  [self resetConnectButton];
  NSLog(@"ADB Exited.");
}

- (NSTask*) adbTask: (NSArray*) arguments
{
  NSTask* task;
  task = [[NSTask alloc] init];
  NSString* path= [[NSUserDefaults standardUserDefaults] objectForKey:PREFS_ADB_PATH];
  
  [task setLaunchPath:path];
  [task setArguments: arguments];
  
  return task;
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
      
    } else if (match == nil && [line length] != 0 && !([previousString length] > 0 && [line isEqualToString:previousString])) {
      [text appendString:@"\n"];
      [text appendString:line];
      
    } else if ([line length] == 0 && time != nil) {
      
      if ([text rangeOfString:@"\n"].location != NSNotFound) {
        NSArray* linesOfText = [text componentsSeparatedByString:@"\n"];
        for (NSString* lineOfText in linesOfText) {
          if ([lineOfText length] == 0) {
            continue;
          }
          NSArray* values = @[time, app, pid, tid, type, name, lineOfText];
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
        NSArray* values = @[time, app, pid, tid, type, name, text];
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
  
  [self.logDataTable reloadData];
  if (scrollToBottom) {
    if ([searchString length] > 0) {
      [self.logDataTable scrollRowToVisible:[search count]-1];
    } else if (filtered != nil) {
      [self.logDataTable scrollRowToVisible:[filtered count]-1];
    } else {
      [self.logDataTable scrollRowToVisible:[logcat count]-1];
    }
  }
  
}

- (BOOL)filterMatchesRow:(NSDictionary*)row
{
  NSDictionary* filter = [filters objectAtIndex:[filterListTable selectedRow]-1];
  NSString* selectedType = [filter objectForKey:KEY_FILTER_TYPE];
  NSString* realType = [self getKeyFromType:selectedType];
  
  return [[row objectForKey:realType] rangeOfString:[filter objectForKey:KEY_FILTER_TEXT] options:NSCaseInsensitiveSearch].location != NSNotFound;
}

- (NSString*) getKeyFromType: (NSString*) selectedType
{
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
  if (aTableView == logDataTable) {
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
  if (aTableView == logDataTable) {
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


- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
  if (tableView == filterListTable) {
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
  [self.logDataTable reloadData];
  [self.logDataTable scrollRowToVisible:[search count]-1];
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
  if (aTableView != filterListTable) {
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
  [logDataTable reloadData];
  [logDataTable scrollRowToVisible:[[logDataTable dataSource] numberOfRowsInTableView:logDataTable]-1];
  
  return YES;
}

- (IBAction)addFilter
{
  if (sheetAddFilter == nil) {
    NSArray* array;
    [[NSBundle mainBundle] loadNibNamed:FILTER_SHEET owner:self topLevelObjects:&array];
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
  NSArray *sortDescriptors = @[sortDescriptor];
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
  [self clearLog];
}

- (IBAction)restartAdb:(id)sender
{
  if (isRunning) {
    isRunning = NO;
  } else {
    [pidMap removeAllObjects];
    [self clearLog];
    [self startAdb];
  }
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
  [self.logDataTable reloadData];
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
  
  NSDictionary* filter = (__bridge NSDictionary *)contextInfo;
  if (filter == nil) {
    filter = [NSDictionary dictionaryWithObjects:@[filterName, filterType, filterText]
                                         forKeys:@[KEY_FILTER_NAME, KEY_FILTER_TYPE, KEY_FILTER_TEXT]];
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

- (IBAction)copyPlain:(id)sender
{
  [self copySelectedRow:NO: NO];
}

- (IBAction)copyMessageOnly:(id)sender
{
  [self copySelectedRow:NO: YES];
  
}

- (void) editFilter:(id)sender
{
  if ([filterListTable rightClickedRow] < 1) {
    return;
  }
  
  NSDictionary* filter = [filters objectAtIndex:[filterListTable rightClickedRow]-1];
  
  if (sheetAddFilter == nil) {
    NSArray* array;
    [[NSBundle mainBundle] loadNibNamed:FILTER_SHEET owner:self topLevelObjects:&array];
  }
  
  
  [[sheetAddFilter filterName] setStringValue:[filter objectForKey:KEY_FILTER_NAME]];
  [sheetAddFilter selectItemWithTitie:[filter objectForKey:KEY_FILTER_TYPE]];
  [[sheetAddFilter filterCriteria]  setStringValue:[filter objectForKey:KEY_FILTER_TEXT]];
  
  [NSApp beginSheet:sheetAddFilter modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:(__bridge void *)(filter)];
}

- (IBAction)filterBySelected:(id)sender
{
  if (sheetAddFilter == nil) {
    NSArray* array;
    [[NSBundle mainBundle] loadNibNamed:FILTER_SHEET owner:self topLevelObjects:&array];
  }
  NSTableColumn* aColumn = [[logDataTable tableColumns] objectAtIndex:[logDataTable rightClickedColumn]];
  //NSCell *aCell = [aColumn dataCellForRow:[table rightClickedRow]];
  
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

- (NSMenu*) menuForTableView: (NSTableView*) tableView column:(NSInteger) column row:(NSInteger) row
{
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

- (NSDictionary*) dataForRow: (NSUInteger) rowIndex
{
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

- (void) copy:(id)sender
{
  [self copySelectedRow: NO: NO];
}

- (void) copySelectedRow: (BOOL) escapeSpecialChars :(BOOL) messageOnly
{
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
        [rowType appendFormat:@"%@", rowDetails[KEY_TEXT]];
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

@end
