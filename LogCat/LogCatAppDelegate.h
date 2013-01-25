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
#import "RemoteScreenMonitorSheet.h"
#import "DevicePickerSheet.h"
#import "LogDatasource.h"
#import "DeviceListDatasource.h"

@class LogDatasource;

@class SelectableTableView;


@interface LogCatAppDelegate : NSObject <NSApplicationDelegate, MenuDelegate, LogDatasourceDelegate, DeviceListDatasourceDelegate> {
    
    NSString* previousString;
    
    bool scrollToBottom;
    
    __weak NSSearchField *_quickFilter;
    NSMutableDictionary* filters;
    IBOutlet FilterSheet *sheetAddFilter;
    IBOutlet DevicePickerSheet* sheetDevicePicker;
    IBOutlet RemoteScreenMonitorSheet* remoteScreen;
    IBOutlet NSTextField *tfFilterName;
    IBOutlet NSPopUpButton *puFilterField;
    IBOutlet NSTextField *tfFilterText;
    IBOutlet NSSegmentedControl *filterToolbar;
    __unsafe_unretained NSWindow *_predicateSheet;
    __weak NSTextField *_predicateText;
    
    NSDictionary* colors;
    NSDictionary* fonts;
    
    __weak NSTextField *textEntry;
    __weak NSButtonCell *remoteScreenMonitorButton;
    __weak NSTextField *_statusTextField;
}
- (IBAction)saveDocumentAsText:(id)sender;
- (IBAction)saveDocumentVisableAsText:(id)sender;

- (IBAction)remoteScreenMonitor:(id)sender;
- (IBAction)cancelDevicePicker:(id)sender;
- (IBAction)startLogForDevice:(id)sender;
- (IBAction)openLogcatFile:(id)sender;
- (IBAction)toggleAutoFollow:(id)sender;
- (IBAction)quickFilter:(id)sender;

- (void)fontsChanged;
- (IBAction)search:(id)sender;
- (IBAction)find:(id)sender;
- (IBAction)findNext:(id)sender;
- (IBAction)findPrevious:(id)sender;
- (IBAction)addFilter;
- (IBAction)removeFilter;
- (IBAction)cancelSheet:(id)sender;
- (IBAction)acceptSheet:(id)sender;
- (IBAction)preferences:(id)sender;
- (IBAction)clearLog:(id)sender;
- (IBAction)restartAdb:(id)sender;
- (IBAction)filterToolbarClicked:(NSSegmentedControl*)sender;
- (IBAction)openTypingTerminal:(id)sender;
- (IBAction)newWindow:(id)sender;

- (IBAction)showPredicateEditor:(id)sender;
- (IBAction)onPredicateEdited:(id)sender;
- (IBAction)closePredicateSheet:(id)sender;
- (IBAction)cancelPredicateEditing:(id)sender;
- (IBAction)applyPredicate:(id)sender;
- (IBAction)importFilters:(id)sender;
- (IBAction) exportSelectedFilters:(id)sender;

- (IBAction)biggerFont:(id)sender;
- (IBAction)smallerFont:(id)sender;

@property (strong, nonatomic) NSString* adbPath;
@property (unsafe_unretained) IBOutlet NSWindow *predicateSheet;
@property (weak) IBOutlet NSTextField *predicateText;
@property (weak) IBOutlet NSTextField *statusTextField;
@property (strong) IBOutlet NSWindow *window;
@property (weak) IBOutlet SelectableTableView *filterListTable;
@property (weak) IBOutlet SelectableTableView *logDataTable;
@property (weak) IBOutlet NSTextField *textEntry;
@property (weak) IBOutlet NSButton *restartAdb;
@property (weak) IBOutlet NSButtonCell *remoteScreenMonitorButton;
@property (weak) IBOutlet NSPredicateEditor *predicateEditor;
@property (weak) IBOutlet NSTextField *savePredicateName;
@property (weak) IBOutlet NSSearchFieldCell *searchFieldCell;
@property (weak) IBOutlet NSSearchField *searchField;
@property (weak) IBOutlet NSSearchField *quickFilter;

- (void)adbPathChanged:(NSString*)newPath;


@end
