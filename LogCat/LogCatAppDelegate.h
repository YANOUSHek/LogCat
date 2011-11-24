//
//  LogCatAppDelegate.h
//  LogCat
//
//  Created by Janusz Bossy on 16.11.2011.
//  Copyright (c) 2011 SplashSoftware.pl. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LogCatAppDelegate : NSObject <NSApplicationDelegate> {
    NSString* previousString;
    NSMutableArray* logcat;
    NSMutableArray* filtered;
    NSArray* keysArray;
    bool scrollToBottom;
    NSMutableArray* search;
    NSString* searchString;
    
    NSString* time;
    NSString* pid;
    NSString* type;
    NSString* name;
    NSMutableString* text;
    
    NSMutableArray* filters;
    IBOutlet NSWindow *sheetAddFilter;
    IBOutlet NSTextField *tfFilterName;
    IBOutlet NSPopUpButton *puFilterField;
    IBOutlet NSTextField *tfFilterText;
    IBOutlet NSSegmentedControl *filterToolbar;
    
    NSDictionary* colors;
    NSDictionary* fonts;
    NSString* adbPath;
    
    bool isRunning;
}

- (void)adbPathChanged:(NSString*)newPath;
- (void)fontsChanged;

@property (assign) IBOutlet NSTableView *filterList;
@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTableView *table;
- (IBAction)search:(id)sender;
- (IBAction)addFilter;
- (IBAction)removeFilter;
- (IBAction)cancelSheet:(id)sender;
- (IBAction)acceptSheet:(id)sender;
- (IBAction)preferences:(id)sender;
- (IBAction)clearLog:(id)sender;
- (IBAction)filterToolbarClicked:(NSSegmentedControl*)sender;

@end
