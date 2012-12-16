//
//  LogDatasource.m
//  LogCat
//
//  Created by Chris Wilson on 12/15/12.
//  Copyright (c) 2012 SplashSoftware.pl. All rights reserved.
//

#import "LogDatasource.h"
#import "AdbTaskHelper.h"
#import "NSString_Extension.h"

@interface LogDatasource () {

    
    
    NSString* previousString;
    
    NSMutableDictionary* pidMap;
    NSMutableArray* logData;
    NSMutableArray* filteredLogData;
    NSMutableArray* searchLogData;
    
    NSArray* keysArray;
    
    NSString* time;
    NSString* app;
    NSString* pid;
    NSString* tid;
    NSString* type;
    NSString* name;
    NSMutableString* text;
}


- (void) parsePID: (NSString*) pidInfo;
- (void) loadPID;

- (BOOL)filterMatchesRow:(NSDictionary*)row;
- (BOOL)searchMatchesRow:(NSDictionary*)row;

- (NSString*) getKeyFromType: (NSString*) selectedType;

@end


@implementation LogDatasource

@synthesize delegate = _delegate;

@synthesize filter = _filter;
@synthesize searchString = _searchString;
@synthesize deviceId = _deviceId;
@synthesize isLogging = _isLogging;


- (id)init {
    if (self = [super init]) {
        pidMap = [NSMutableDictionary dictionary];
        logData = [NSMutableArray arrayWithCapacity:0];
        searchLogData = [NSMutableArray arrayWithCapacity:0];
        text = [NSMutableString stringWithCapacity:0];
        keysArray = [NSArray arrayWithObjects: KEY_TIME, KEY_APP, KEY_PID, KEY_TID, KEY_TYPE, KEY_NAME, KEY_TEXT, nil];
    }
    return self;
}

- (void) startLogger {
    [self loadPID];
    [self readLog:nil];
}

- (void) stopLogger {
    isLogging = false;
}

- (void) clearLog {
    [pidMap removeAllObjects];
    
}

- (NSUInteger) getDisplayCount {
    if ([searchString length] > 0) {
        return [searchLogData count];
    } else if (filteredLogData != nil) {
        return [filteredLogData count];
    } else {
        return [logData count];
    }
}

- (NSDictionary*) valueForIndex: (NSUInteger) index {
    NSDictionary* row;
    if ([searchString length] > 0) {
        row = [searchLogData objectAtIndex:index];
    } else if (filteredLogData != nil) {
        row = [filteredLogData objectAtIndex:index];
    } else {
        row = [logData objectAtIndex:index];
    }
    return row;
}


#pragma mark -
#pragma mark PID Loader
#pragma mark -

- (void) loadPID {
    NSArray *arguments = [NSArray arrayWithObjects: @"shell", @"ps", nil];
    NSTask *task = [AdbTaskHelper adbTask: arguments];
    
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

#pragma mark -
#pragma mark Log Loader
#pragma mark -

- (void)readLog:(id)param
{
    isLogging = YES;
    
    NSArray *arguments = [NSArray arrayWithObjects: @"logcat", @"-v", @"long", nil];
    
    NSTask *task = [AdbTaskHelper adbTask:arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    [task setStandardInput:[NSPipe pipe]];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    while (isLogging && [task isRunning]) {
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
    
    isLogging = NO;
    //[self resetConnectButton];
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
                    [logData addObject:row];
                    
                    if (filteredLogData != nil && [self filterMatchesRow:row]) {
                        if ([searchString length] > 0 && [self searchMatchesRow:row]) {
                            [searchLogData addObject:row];
                        } else {
                            [filteredLogData addObject:row];
                        }
                    } else if (filteredLogData == nil && [searchString length] > 0 && [self searchMatchesRow:row]) {
                        [searchLogData addObject:row];
                    }
                }
            } else {
                // NSLog(@"xxx--- 4 text: %@", text);
                
                NSArray* values = [NSArray arrayWithObjects: time, app, pid, tid, type, name, text, nil];
                NSDictionary* row = [NSDictionary dictionaryWithObjects:values
                                                                forKeys:keysArray];
                [logData addObject:row];
                
                if (filteredLogData != nil && [self filterMatchesRow:row]) {
                    if ([searchString length] > 0 && [self searchMatchesRow:row]) {
                        [searchLogData addObject:row];
                    } else {
                        [filteredLogData addObject:row];
                    }
                } else if (filteredLogData == nil && [searchString length] > 0 && [self searchMatchesRow:row]) {
                    [searchLogData addObject:row];
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

    if (self.delegate != nil) {
        [self.delegate onLogUpdated];
    }
//    [self.logDataTable reloadData];
//    if (scrollToBottom) {
//        if ([searchString length] > 0) {
//            [self.logDataTable scrollRowToVisible:[searchLogData count]-1];
//        } else if (filteredLogData != nil) {
//            [self.logDataTable scrollRowToVisible:[filteredLogData count]-1];
//        } else {
//            [self.logDataTable scrollRowToVisible:[logData count]-1];
//        }
//    }
    
}

#pragma mark -
#pragma mark Filter and Search
#pragma mark -

- (BOOL)filterMatchesRow:(NSDictionary*)row
{
//    NSDictionary* filter = [filters objectAtIndex:[filterListTable selectedRow]-1];
    NSString* selectedType = [filter objectForKey:KEY_FILTER_TYPE];
    NSString* realType = [self getKeyFromType:selectedType];
    
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


#pragma mark -
#pragma mark Others
#pragma mark -

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


@end
