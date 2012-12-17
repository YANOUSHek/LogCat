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
#import "DeviceListDatasource.h"

@class LogDatasource;

@class SelectableTableView;


@interface LogCatAppDelegate : NSObject <NSApplicationDelegate, MenuDelegate, LogDatasourceDelegate, DeviceListDatasourceDelegate> {
    
    NSString* previousString;
    
    bool scrollToBottom;
    
    NSMutableArray* filters;
    IBOutlet FilterSheet *sheetAddFilter;
    IBOutlet NSTextField *tfFilterName;
    IBOutlet NSPopUpButton *puFilterField;
    IBOutlet NSTextField *tfFilterText;
    IBOutlet NSSegmentedControl *filterToolbar;
    
    NSDictionary* colors;
    NSDictionary* fonts;
    
    __weak NSTextField *textEntry;
}


@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet SelectableTableView *filterListTable;
@property (weak) IBOutlet SelectableTableView *logDataTable;
@property (weak) IBOutlet NSTextField *textEntry;
@property (weak) IBOutlet NSButton *restartAdb;

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
