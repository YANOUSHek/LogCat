//
//  LogDatasource.m
//  LogCat
//
//  Created by Chris Wilson on 12/15/12.
//

#import "LogDatasource.h"
#import "AdbTaskHelper.h"
#import "NSString_Extension.h"

// 1 - adb logcat -v long
// 2 - adb logcat -v threadtime
// 3 - adb logcat -B  # Work in progress
#define LOG_FORMAT 2

@interface LogDatasource () {
    
    NSString* previousString;
    NSData* pendingData;
    
    NSThread* thread;
    
    NSMutableDictionary* pidMap;
    NSMutableArray* logData;
    NSMutableArray* filteredLogData;
    NSMutableArray* searchLogData;
    
    NSDictionary* filter;
    NSString* searchString;

    
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

- (void) onLogUpdated;
- (void) onLoggerStarted;
- (void) onLoggerStopped;

- (NSMutableArray*)findLogsMatching:(NSString*)string forKey:(NSString*)key;

- (void) applySearch;

@end


@implementation LogDatasource
@synthesize delegate = _delegate;
@synthesize deviceId;
@synthesize isLogging;


- (id)init {
    if (self = [super init]) {
        pidMap = [NSMutableDictionary dictionary];
        logData = [NSMutableArray arrayWithCapacity:0];
        searchLogData = [NSMutableArray arrayWithCapacity:0];
        text = [NSMutableString stringWithCapacity:0];
        keysArray = [NSArray arrayWithObjects: KEY_TIME, KEY_APP, KEY_PID, KEY_TID, KEY_TYPE, KEY_NAME, KEY_TEXT, nil];
        isLogging = NO;
    }
    return self;
}

- (void) startLogger {
    if (isLogging) {
        NSLog(@"ERROR: startLogger called but it was already running.");
    }
    [self clearLog];
    thread = [[NSThread alloc] initWithTarget:self selector:@selector(internalStartLogger) object:nil];
    [thread start];
}

- (void) stopLogger {
    isLogging = NO;
    [thread cancel];
}

- (void) internalStartLogger {
    
    [self loadPID];
    [self readLog:nil];
}

- (void) clearLog {
    [pidMap removeAllObjects];
    [searchLogData removeAllObjects];
    [filteredLogData removeAllObjects];
    [logData removeAllObjects];
    [self onLogUpdated];
    
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

- (void) setSearchString: (NSString*) search {
    NSLog(@"setSearchString: %@", search);
    if (search != nil && [search isEqualToString:searchString]) {
        NSLog(@"Search did not change abort re-scan");
        return;
    }
    
    searchString = search;
    if (searchString == nil || [searchString length] == 0) {
        [searchLogData removeAllObjects];
        [self onLogUpdated];
        
    } else {
        [self applySearch];
    }
}

- (void) applySearch {
    [searchLogData removeAllObjects];
    
    if (searchString == nil || [searchString length] == 0) {
        [self onLogUpdated];
        return;
    }
    
    NSMutableArray* rows = logData;
    if (filteredLogData != nil && [filteredLogData count] > 0) {
        rows = filteredLogData;
    }
    
    [searchLogData removeAllObjects];
    for (NSDictionary* row in rows) {
        if ([[row objectForKey:KEY_NAME] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [searchLogData addObject:[row copy]];
        } else if ([[row objectForKey:KEY_TEXT] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [searchLogData addObject:[row copy]];
        }
    }
    
    [self onLogUpdated];
}

- (void) setFilter: (NSDictionary*) newFilter {
    NSLog(@"setFilter: %@", newFilter);
        
    filter = newFilter;
    
    if (filter == nil) {
        filteredLogData = nil;
    } else {
        NSString* realType = [self getKeyFromType:[filter objectForKey:KEY_FILTER_TYPE]];
        filteredLogData = [self findLogsMatching:[filter objectForKey:KEY_FILTER_TEXT] forKey:realType];
    }
    
    [self applySearch];
}

- (NSMutableArray*)findLogsMatching:(NSString*)string forKey:(NSString*)key
{
    NSMutableArray* result = [NSMutableArray new];

    for (NSDictionary* logItem in logData) {
        if ([[logItem objectForKey:key] rangeOfString:string options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [result addObject:[logItem copy]];
        }
    }
    return result;
}

#pragma mark -
#pragma mark PID Loader
#pragma mark -

- (void) loadPID {
    NSArray *arguments = nil;
    if (deviceId == nil || deviceId.length == 0) {
        arguments = [NSArray arrayWithObjects: @"shell", @"ps", nil];
    } else {
        //NSLog(@"Will bind to: %@", deviceId);
        arguments = [NSArray arrayWithObjects: @"-s", [deviceId copy], @"shell", @"ps", nil];
    }
    
    
    NSTask *task = [AdbTaskHelper adbTask: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    [task setStandardError:pipe];
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
    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");
    
    Boolean isFirstLine = YES;
    
    NSArray* lines = [pidInfo componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
    
    for (NSString* line in lines) {
        if ([line hasPrefix:@"-"]) {
            continue;
        } else if ([line hasPrefix:@"error:"]) {
            NSLog(@"%@", line);
            if ([line isEqualToString:MULTIPLE_DEVICE_MSG]) {
                isLogging = NO;
                [self onMultipleDevicesConnected];
                return;
            } else if ([line isEqualToString:DEVICE_NOT_FOUND_MSG]) {
                isLogging = NO;
                [self onDeviceNotFound];
                return;
            }
            continue;
        }
        
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
    [self performSelectorOnMainThread:@selector(onLoggerStarted) withObject:nil waitUntilDone:NO];
    
    NSArray *arguments = nil;
    if (LOG_FORMAT == 1) {
        if (deviceId == nil || deviceId.length == 0) {
            arguments = [NSArray arrayWithObjects: @"logcat", @"-v", @"long", nil];
        } else {
            arguments = [NSArray arrayWithObjects: @"-s", deviceId, @"logcat", @"-v", @"long", nil];
        }
        
    } else if (LOG_FORMAT == 2) {
    
        if (deviceId == nil || deviceId.length == 0) {
            arguments = [NSArray arrayWithObjects: @"logcat", @"-v", @"threadtime", nil];
        } else {
            arguments = [NSArray arrayWithObjects: @"-s", deviceId, @"logcat", @"-v", @"threadtime", nil];
        }
    } else if (LOG_FORMAT == 3) {
        
        if (deviceId == nil || deviceId.length == 0) {
            arguments = [NSArray arrayWithObjects: @"logcat", @"-B", nil];
        } else {
            arguments = [NSArray arrayWithObjects: @"-s", deviceId, @"logcat", @"-B", nil];
        }
    }
    
    
    NSTask *task = [AdbTaskHelper adbTask:arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    [task setStandardError:pipe];
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
            if (LOG_FORMAT == 1) {
                [self performSelectorOnMainThread:@selector(appendLongLog:) withObject:string waitUntilDone:YES];
            } else if (LOG_FORMAT == 2) {
//                [self performSelectorOnMainThread:@selector(appendThreadtimeLog:) withObject:string waitUntilDone:YES];
                [self appendThreadtimeLog:string];
            } else if (LOG_FORMAT == 3) {
                [self performSelectorOnMainThread:@selector(appendBinaryLog:) withObject:data waitUntilDone:YES];
            }
        } else {
            NSLog(@"Data was nil...");
        }
    }
    
    [task terminate];
    
    isLogging = NO;
        [self performSelectorOnMainThread:@selector(onLoggerStopped) withObject:nil waitUntilDone:NO];
    
    NSLog(@"ADB Exited.");
}

- (void) appendBinaryLog: (NSData*) data {
    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");
    
    NSLog(@"Read %ld bytes", [data length]);
    /*
     Header (20 bytes total):
     [payloadlength]  2 bytes
     [unused padding] 2 bytes
     [PID]            4 bytes
     [Thread ID]      4 bytes
     [time seconds]   4 bytes
     [time nanosecs]  4 bytes
     [payload]        payloadlength bytes
     
     Payload section of the header is (payloadlength bytes total):
     [log priority]            1 byte
     [null terminated tag]     unknown length, < payloadlength
     [null terminated log msg] unknown length, < payloadlength
     */
    
     // TODO
    
}

- (void) appendThreadtimeLog: (NSString*) paramString {
//    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");

    NSMutableString* currentLine = [[NSMutableString alloc] initWithCapacity:1024];

    if (previousString != nil && [previousString length] > 0) {
        [currentLine appendString:previousString];
        previousString = nil;
    }
    
    for (int i = 0; i < [paramString length]; i++) {
        unichar currentChar = [paramString characterAtIndex:i];
        switch (currentChar) {
            case '\n':
                [currentLine appendString:@"\n"];
                [self parseThreadTimeLine:currentLine];
                [currentLine setString:@""];
                break;
            case '\r':
                // discard these
                break;
            default:
                [currentLine appendString:[NSString stringWithFormat:@"%C", currentChar]];
                break;
        }
    }
    
    previousString = currentLine;
    [self performSelectorOnMainThread:@selector(onLogUpdated) withObject:nil waitUntilDone:YES];

}

- (void) parseThreadTimeLine: (NSString*) line {
    
    if ([line hasPrefix:@"-"]) {
        return;
    } else if ([line hasPrefix:@"error:"]) {
        NSLog(@"%@", line);
        if ([line isEqualToString:MULTIPLE_DEVICE_MSG]) {
            isLogging = NO;
            [self onMultipleDevicesConnected];
            return;
        } else if ([line isEqualToString:DEVICE_NOT_FOUND_MSG]) {
            isLogging = NO;
            [self onMultipleDevicesConnected];
            return;
        }
        return;
    }
    previousString = line;
//        NSLog(@"Parsing \"%@\"", line);
    NSScanner* scanner = [NSScanner scannerWithString:line];
    NSString* dateVal;
    
    BOOL result = [scanner scanUpToString:@" " intoString:&dateVal];
    if (!result) {
        NSLog(@"1: Bad line: %@", line);
        return;
    }
    
    NSString* timeVal;
    result = [scanner scanUpToString:@" " intoString:&timeVal];
    if (!result) {
        NSLog(@"2: Bad line: %@", line);
        return;
    }
    
    NSString* fullTimeVal = [NSString stringWithFormat:@"%@ %@", dateVal, timeVal];

    
    NSString* pidVal;
    result = [scanner scanUpToString:@" " intoString:&pidVal];
    if (!result) {
        NSLog(@"3: Bad line: %@", line);
        return;
    }
    
    if ([pidVal isInteger] == false) {
        return;
    }
    
    NSString* appVal = [pidMap objectForKey:pidVal];
    if (appVal == nil) {
        NSLog(@"%@ not found in pid map.", pidVal);
        [self loadPID];
        appVal = [pidMap objectForKey:pidVal];
        if (app == nil) {
            // This is normal during startup because there can be log
            // messages from apps that are not running anymore.
            appVal = @"unknown";
            [pidMap setValue:appVal forKey:pidVal];
        }
    }
    
    NSString* tidVal;
    result = [scanner scanUpToString:@" " intoString:&tidVal];
    if (!result) {
        NSLog(@"4: Bad line: %@", line);
        return;
    }

    NSString* logLevelVal;
    result = [scanner scanUpToString:@" " intoString:&logLevelVal];
    if (!result) {
        NSLog(@"5: Bad line: %@", line);
        return;
    }

    NSString* tagVal;
    result = [scanner scanUpToString:@": " intoString:&tagVal];
    if (!result) {
        NSLog(@"6: Bad line: %@", line);
        return;
    }
    
    // Discard ": "
    [scanner scanString:@": " intoString:nil];

    NSString* msgVal;
    result = [scanner scanUpToString:@"\n" intoString:&msgVal];
    if (!result) {
//            NSLog(@"7: No msg on line: %@", line);
//        return;
        msgVal = @"";
    }

    //time, app, pid, tid, type, name, text, 
    NSArray* values = [NSArray arrayWithObjects: fullTimeVal, appVal, pidVal, tidVal, logLevelVal, tagVal, msgVal, nil];
    NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:keysArray];
    [self appendRow:row];

//    [self performSelectorOnMainThread:@selector(onLogUpdated) withObject:nil waitUntilDone:YES];
//    [self onLogUpdated];

}


- (void)appendLongLog:(NSString*)paramString
{
    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");
    
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
    
    NSArray* lines = [currentString componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
    
    if (![currentString hasSuffix:@"\n"]) {
        previousString = [[lines objectAtIndex:[lines count]-1] copy];
    }
    
    for (NSString* line in lines) {
        if ([line hasPrefix:@"-"]) {
            continue;
        } else if ([line hasPrefix:@"error:"]) {
            NSLog(@"%@", line);
            if ([line isEqualToString:MULTIPLE_DEVICE_MSG]) {
                isLogging = NO;
                [self onMultipleDevicesConnected];
                return;
            } else if ([line isEqualToString:DEVICE_NOT_FOUND_MSG]) {
                isLogging = NO;
                [self onMultipleDevicesConnected];
                return;
            }
            continue;
        }
        
        NSRegularExpression* expr = [NSRegularExpression regularExpressionWithPattern:
                                     @"^\\[\\s(\\d\\d-\\d\\d\\s\\d\\d:\\d\\d:\\d\\d.\\d+)\\s+(\\d*):(.*)\\s(.)/(.*)\\]$"
                                                                              options:0
                                                                                error:nil];
        
        NSTextCheckingResult* match = [expr firstMatchInString:line options:0 range:NSMakeRange(0, [line length])];
        if (match != nil) {
            // Header line of log
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
                    
                    [self appendRow:row];
                }
            } else {
                // NSLog(@"xxx--- 4 text: %@", text);
                
                NSArray* values = [NSArray arrayWithObjects: time, app, pid, tid, type, name, text, nil];
                NSDictionary* row = [NSDictionary dictionaryWithObjects:values
                                                                forKeys:keysArray];
                [self appendRow:row];                
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

    [self onLogUpdated];
    
}

- (void) appendRow: (NSDictionary*) row {
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

#pragma mark -
#pragma mark Filter and Search
#pragma mark -

- (BOOL)filterMatchesRow:(NSDictionary*)row
{
    if (filter == nil) {
        return NO;
    }
    
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
#pragma mark delegate wrapper
#pragma mark -

- (void) onLoggerStarted {
    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");

    if (self.delegate != nil) {
        [self.delegate onLoggerStarted];
    }
}

- (void) onLoggerStopped {
    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");
    
    if (self.delegate != nil) {
        [self.delegate onLoggerStopped];
    }
}

- (void) onLogUpdated {
    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");
    
    if (self.delegate != nil) {
        [self.delegate onLogUpdated];
    }
}

- (void) onMultipleDevicesConnected {
    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");
    if (self.delegate != nil) {
        [self.delegate onMultipleDevicesConnected];
    }
}

- (void) onDeviceNotFound {
    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");
    if (self.delegate != nil) {
        [self.delegate onDeviceNotFound];
    }
}

- (NSString*) description {
    return [NSString stringWithFormat:@"logDataSrouce: isLogging=%@", isLogging ? @"Yes" : @"No"];
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
