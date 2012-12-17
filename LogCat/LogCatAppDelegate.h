//
//  LogCatAppDelegate.h
//  LogCat
//
//  Created by Janusz Bossy on 16.11.2011.
//  Copyright (c) 2011 SplashSoftware.pl. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MenuDelegate.h"
#import "FilterSheet.h"
#import "LogDatasource.h"

@class LogDatasource;

@class SelectableTableView;


@interface LogCatAppDelegate : NSObject <NSApplicationDelegate, MenuDelegate, LogDatasourceDelegate> {
    
    NSString* previousString;
    
//    NSMutableArray* logData;
//    NSMutableArray* filteredLogData;
//    NSMutableArray* searchLogData;
    
//    NSString* searchString;
    
//    NSArray* keysArray;
    bool scrollToBottom;
    
//    NSString* time;
//    NSString* app;
//    NSString* pid;
//    NSString* tid;
//    NSString* type;
//    NSString* name;
//    NSMutableString* text;
    
    NSMutableArray* filters;
    IBOutlet FilterSheet *sheetAddFilter;
    IBOutlet NSTextField *tfFilterName;
    IBOutlet NSPopUpButton *puFilterField;
    IBOutlet NSTextField *tfFilterText;
    IBOutlet NSSegmentedControl *filterToolbar;
    
    NSDictionary* colors;
    NSDictionary* fonts;
    
//    NSMutableDictionary* pidMap;
    
//    bool isRunning;
    __weak NSTextField *textEntry;
}


@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet SelectableTableView *filterListTable;
@property (weak) IBOutlet SelectableTableView *logDataTable;
@property (weak) IBOutlet NSTextField *textEntry;
@property (weak) IBOutlet NSButton *restartAdb;
//@property (strong, atomic) LogDatasource* logDatasource;

- (void)fontsChanged;
- (IBAction)search:(id)sender;
- (IBAction)addFilter;
- (IBAction)removeFilter;
- (IBAction)cancelSheet:(id)sender;
- (IBAction)acceptSheet:(id)sender;
- (IBAction)preferences:(id)sender;
- (IBAction)clearLog:(id)sender;
- (IBAction)restartAdb:(id)sender;
- (IBAction)filterToolbarClicked:(NSSegmentedControl*)sender;
- (IBAction)openTypingTerminal:(id)sender;

@end
