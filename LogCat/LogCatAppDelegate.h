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

@class SelectableTableView;


@interface LogCatAppDelegate : NSObject <NSApplicationDelegate, MenuDelegate> {
    NSString* previousString;
    NSMutableArray* logcat;
    NSMutableArray* filtered;
    NSArray* keysArray;
    bool scrollToBottom;
    NSMutableArray* search;
    NSString* searchString;
    
    NSString* time;
    NSString* app;
    NSString* pid;
    NSString* tid;
    NSString* type;
    NSString* name;
    NSMutableString* text;
    
    NSMutableArray* filters;
    IBOutlet FilterSheet *sheetAddFilter;
    IBOutlet NSTextField *tfFilterName;
    IBOutlet NSPopUpButton *puFilterField;
    IBOutlet NSTextField *tfFilterText;
    IBOutlet NSSegmentedControl *filterToolbar;
    
    NSDictionary* colors;
    NSDictionary* fonts;
    
    NSMutableDictionary* pidMap;
    
    bool isRunning;
}

- (void)fontsChanged;

@property (weak) IBOutlet NSButton *restartAdb;
@property (weak) IBOutlet SelectableTableView *filterList;
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet SelectableTableView *table;
- (IBAction)search:(id)sender;
- (IBAction)addFilter;
- (IBAction)removeFilter;
- (IBAction)cancelSheet:(id)sender;
- (IBAction)acceptSheet:(id)sender;
- (IBAction)preferences:(id)sender;
- (IBAction)clearLog:(id)sender;
- (IBAction)restartAdb:(id)sender;
- (IBAction)filterToolbarClicked:(NSSegmentedControl*)sender;

@end
