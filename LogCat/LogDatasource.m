//
//  LogDatasource.m
//  LogCat
//
//  Created by Chris Wilson on 12/15/12.
//

#import "LogDatasource.h"
#import "AdbTaskHelper.h"
#import "NSString_Extension.h"
#import "BinaryDataScanner.h"

// 1 - adb logcat -v long
// 2 - adb logcat -v threadtime
// 3 - adb logcat -B  # Work in progress: The binary streams seems to get corrupted and does not work reliably.
#define LOG_FORMAT 2


#define LOG_HEADER_LEN 20
#define LOG_HEADER_LEN2 18

@interface LogDatasource () {
    NSDate *startTime;
    
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
    
    NSUInteger counter;
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
- (NSArray*) argumentsForDevice: (NSArray*) args;

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
        
        counter = 0;
    }
    return self;
}

- (void) startLogger {
    if (isLogging) {
        NSLog(@"ERROR: startLogger called but it was already running.");
        return;
    }
    
    startTime = [NSDate date];
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

    // temp fix so log can be filtered when first starting and log messages
    // are runnig very fast. This can cause some data to be missed by the filter.
    for (NSDictionary* logItem in [logData copy]) {
        if ([self filterMatchesRow:logItem]) {
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
    arguments = [NSArray arrayWithObjects: @"shell", @"ps", nil];
    
    
    NSTask *task = [AdbTaskHelper adbTask: [self argumentsForDevice:arguments]];
    
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
        arguments = [NSArray arrayWithObjects: @"logcat", @"-v", @"long", nil];
        
    } else if (LOG_FORMAT == 2) {
    
        arguments = [NSArray arrayWithObjects: @"logcat", @"-v", @"threadtime", nil];
    } else if (LOG_FORMAT == 3) {
        
        arguments = [NSArray arrayWithObjects: @"logcat", @"-B", nil];
    }
    
    
    NSTask *task = [AdbTaskHelper adbTask:[self argumentsForDevice:arguments]];
    
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
//            NSLog(@"Data: %@", string);
            if (LOG_FORMAT == 1) {
                [self performSelectorOnMainThread:@selector(appendLongLog:) withObject:string waitUntilDone:YES];
                
            } else if (LOG_FORMAT == 2) {
                [self appendThreadtimeLog:string];
                
            } else if (LOG_FORMAT == 3) {
                [self appendBinaryLog:data];
                
            }
        } else {
            NSLog(@"Data was nil...");
        }
    }
    
    [task terminate];
    
    isLogging = NO;
    [pidMap removeAllObjects];
    
    [self logMessage:[NSString stringWithFormat:@"Disconnected. %@", deviceId]];
    
    [self performSelectorOnMainThread:@selector(onLoggerStopped) withObject:nil waitUntilDone:NO];
    
    NSLog(@"ADB Exited.");
}

- (void) logData:(NSData*) data {    
    NSUInteger capacity = [data length] * 2;
    NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:capacity];
    const unsigned char *dataBuffer = [data bytes];
    NSInteger i;
    for (i=0; i<[data length]; ++i) {
        [stringBuffer appendFormat:@"%02lX", (NSUInteger)dataBuffer[i]];
    }
    NSLog(@"Data: %@", stringBuffer);
}

/**
 The binary parsing code here is a mess. It seems adb gives a corrupted binary stream
 */
- (void) appendBinaryLog: (NSData*) data {
//    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");
//    
//    if (counter > 40) {
//        NSLog(@"End of test data..");
//        return;
//    }
//    NSString* fileToLoad = [NSString stringWithFormat:@"/Users/chris/Desktop/binLogTest/binLog_%ld.bin", counter++];
//    NSLog(@"Loading: %@", fileToLoad);
//    data = [NSData dataWithContentsOfFile:fileToLoad];
//    NSLog(@"Loaded: %ld bytes", [data length]);
//    //    [data writeToFile:[NSString stringWithFormat:@"/Users/chris/Desktop/binLog_%ld.bin", counter++] atomically:NO];
//
//    
////    NSLog(@"--------------------------------");
////    NSLog(@"   Read %ld bytes", [data length]);
////    NSLog(@"0-------------------------------");
//
//    /*
//     Header (20 bytes total):
//     [payloadlength]  2 bytes
//     [unused padding] 2 bytes
//     [PID]            4 bytes
//     [Thread ID]      4 bytes
//     [time seconds]   4 bytes
//     [time nanosecs]  4 bytes
//     [payload]        payloadlength bytes
//     
//     Payload section of the header is (payloadlength bytes total):
//     [log priority]            1 byte
//     [null terminated tag]     unknown length, < payloadlength
//     [null terminated log msg] unknown length, < payloadlength
//     */
//    
////    NSLog(@"PreData: (%ld)", [data length]
////    [self logData:data];
//    if (pendingData != nil && [pendingData length] > 0) {
//        NSMutableData* newData = [NSMutableData dataWithData:pendingData];
//        [newData appendData:data];
//        data = newData;
//        pendingData = nil;
//    }
//
//
////    data = [NSData dataWithContentsOfFile:@"/Users/chris/Desktop/testLog1msg.bin"];
////    data = [NSData dataWithContentsOfFile:@"/Users/chris/Desktop/testBinLog2.bin"];
//    
//    NSLog(@"Post Data: (%ld)", [data length]);
//    [self logData:data];
//    BinaryDataScanner* binaryScanner = [BinaryDataScanner binaryDataScannerWithData:data littleEndian:YES defaultEncoding:NSUTF8StringEncoding];
//
//    NSUInteger bytesRead = 0;
//    NSUInteger bufferOffset = 0;
//    while ([binaryScanner remainingBytes] > LOG_HEADER_LEN) {
//        NSUInteger size = [binaryScanner readWord];
//        bytesRead = 2;
//        NSLog(@"Size: %lu", size);
//        
//        NSLog(@"Remianing: %ld, Size: %ld", [binaryScanner remainingBytes], size+(LOG_HEADER_LEN));
//        if (([binaryScanner remainingBytes]+bytesRead) < size+(LOG_HEADER_LEN)) {
//            // We don't have a full log entry so save remaining buffer and get more
//            
//            NSUInteger offset = bufferOffset;
//            NSUInteger len = [data length] - offset;
//            NSRange range = NSMakeRange(offset, len);
//            pendingData = [NSData dataWithData:[data subdataWithRange:range]];
//            NSLog(@"1. Insufficient data. remainingBytes: %ld length: %ld (offset=%ld, len=%ld)", [binaryScanner remainingBytes], [data length], offset, len);
//            return;
//        }
//        
//        NSUInteger offset = bufferOffset;
//        NSUInteger len = size + (LOG_HEADER_LEN);
//        NSRange range = NSMakeRange(offset, len);
//        NSData* dataToParse = [NSData dataWithData:[data subdataWithRange:range]];
//        NSLog(@"Will Parse: (%ld)", size);
//        [self logData:dataToParse];
//
//        [self parseBinaryLogEvent:dataToParse];
//        
//        bufferOffset += len;
//        NSLog(@"Skipping: %ld", len);
//        [binaryScanner skipBytes:len-bytesRead];
//    
//    }
//
//    if (pendingData == nil && [binaryScanner remainingBytes] > 0) {
//        NSUInteger offset = bufferOffset;
//        NSUInteger len = [data length] - offset;
//        NSRange range = NSMakeRange(offset, len);
//        pendingData = [NSData dataWithData:[data subdataWithRange:range]];
//        NSLog(@"2. Insufficient data. remainingBytes: %ld length: %ld (offset=%ld, len=%ld)", [binaryScanner remainingBytes], [data length], offset, len);
//        return;
//    }
}

//- (void) parseBinaryLogEvent: (NSData*) data {
//    /*
//     The binary log cat seems to be putting random bytes into the stream so this does not work.
//     */
//    
//    BinaryDataScanner* binaryScanner = [BinaryDataScanner binaryDataScannerWithData:data littleEndian:YES defaultEncoding:NSUTF8StringEncoding];
//    NSUInteger size = [binaryScanner readWord];
//    if (size == 0) {
//        NSLog(@"Did not expect a size of zero");
//    }
//    
//    NSUInteger padding = [binaryScanner readWord]; // unused padding
//    if (padding != 0) {
////        NSLog(@"Padding: %ld, %ld", padding, [binaryScanner remainingBytes]);
//    }
//    NSUInteger bPid = [binaryScanner readDoubleWord];
////    NSLog(@"PID: %ld", bPid);
//    pid = [NSString stringWithFormat:@"%ld", bPid];
//    
//    NSUInteger bTid = [binaryScanner readDoubleWord];
////    NSLog(@"TID: %ld", bTid);
//    tid = [NSString stringWithFormat:@"%ld", bTid];
//    
//    NSUInteger bSec = [binaryScanner readDoubleWord];
////    NSLog(@"SEC: %ld", bSec);
//    time = [NSString stringWithFormat:@"%ld", bSec];
//    
//    NSUInteger bnSec = [binaryScanner readDoubleWord];
//    NSLog(@"NSEC: %ld", bnSec); // Log this so we don't get the compiler warning
//    //        NSString* nanoSecs = [NSString stringWithFormat:@"%ld", bnSec];
//    
//    NSUInteger bPriority = [binaryScanner readByte];
////    NSLog(@"Priority: %ld", bPriority);
//    
//    NSString* bTag = [binaryScanner readNullTerminatedString];
////    NSLog(@"Tag: %@", bTag);
//    
//    NSString* bLogMsg = [binaryScanner readNullTerminatedString];
////    NSLog(@"Msg: %@", bLogMsg);
//    
//    app = [self appNameForPid:pid];
//    
//    NSString* logLevel = [self logLevelForValue:bPriority];
//    
//    NSArray* lines = [bLogMsg componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
//    for (NSString* line in lines) {
//        if ([line length] == 0) {
//            continue;
//        }
//        
//        if (bTag == nil) {
//            bTag = @"";
//        }
//        NSLog(@"%@ %@ %@ %@ %@ %@ %@", time, app, pid, tid, logLevel, bTag, line != nil ? line : @"");
//        NSArray* values = [NSArray arrayWithObjects: time, app, pid, tid, logLevel, bTag, line != nil ? line : @"", nil];
//        if ([values count] < 7) {
//            NSLog(@"Invalid Length. %ld", [values count]);
//        }
//        NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:keysArray];
//        [self appendRow:row];
//    }
//    
//    [self performSelectorOnMainThread:@selector(onLogUpdated) withObject:nil waitUntilDone:YES];
//}

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
    
    NSString* appVal = [self appNameForPid:pidVal];
    
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
        //NSLog(@"6: Bad line: %@", line);
        //return;
        tagVal = @"none";
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
//                    [pidMap setValue:app forKey:pid];
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

- (void) logMessage: (NSString*) message {
    NSArray* values = [NSArray arrayWithObjects: @"----", @"LogCat", @"---", @"---", @"I", @"---", message, nil];
    NSDictionary* row = [NSDictionary dictionaryWithObjects:values
                                                    forKeys:keysArray];
    
    [self appendRow:row];
    [self performSelectorOnMainThread:@selector(onLogUpdated) withObject:nil waitUntilDone:YES];
    
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
    if ([realType isEqualToString:KEY_TYPE]) {
        NSInteger filterLevel = [self getLogLevelForValue:[filter objectForKey:KEY_FILTER_TEXT]];
        NSInteger logItemLevel = [self getLogLevelForValue:[row objectForKey:realType]];
        
        if (logItemLevel >= filterLevel) {
            return YES;
        }
        return NO;
    
    } else {
        return [[row objectForKey:realType] rangeOfString:[filter objectForKey:KEY_FILTER_TEXT] options:NSCaseInsensitiveSearch].location != NSNotFound;
    }
}

- (NSString*) appNameForPid:(NSString*) pidVal {
    NSString* appVal = [pidMap objectForKey:pidVal];
    if (appVal == nil) {
        NSLog(@"%@ not found in pid map.", pidVal);
        [self loadPID];
        appVal = [pidMap objectForKey:pidVal];
        if (appVal == nil) {
            // This is normal during startup because there can be log
            // messages from apps that are not running anymore.
            appVal = @"unknown";
            NSTimeInterval elapsedTime = -[startTime timeIntervalSinceNow];
            // NSLog(@"Elapsed: %f", elapsedTime);
            if (elapsedTime < 30) {
                // There are potentially a lot of these when we first start reading the cached log
                [pidMap setValue:appVal forKey:pidVal];
            }
        }
    }
    
    return appVal;
    
}

- (NSInteger) getLogLevelForValue: (NSString*) logLevel {
    /*
     Java Log Levels:
     
        public static final int VERBOSE = 2;
        public static final int DEBUG = 3;
        public static final int INFO = 4;
        public static final int WARN = 5;
        public static final int ERROR = 6;
        public static final int ASSERT = 7;
    */
    if ([logLevel isEqualToString:@"V"]) {
        return 2;
        
    } else if ([logLevel isEqualToString:@"D"]) {
        return 3;
        
    } else if ([logLevel isEqualToString:@"I"]) {
        return 4;
        
    } else if ([logLevel isEqualToString:@"W"]) {
        return 5;
        
    } else if ([logLevel isEqualToString:@"E"]) {
        return 6;
        
    } else if ([logLevel isEqualToString:@"A"]) {
        return 7;
        
    } else {
        // Unknown ???
        return 2;
    }
}

- (NSString*) logLevelForValue: (NSUInteger) level {
    /*
     Java Log Levels:
     
     public static final int VERBOSE = 2;
     public static final int DEBUG = 3;
     public static final int INFO = 4;
     public static final int WARN = 5;
     public static final int ERROR = 6;
     public static final int ASSERT = 7;
     */
    switch (level) {
        case 2:
            return @"V";

        case 3:
            return @"D";

        case 4:
            return @"I";

        case 5:
            return @"W";

        case 6:
            return @"E";

        case 7:
            return @"A";

        default:
            return [NSString stringWithFormat:@"%ld", level];
    }
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

- (NSArray*) argumentsForDevice: (NSArray*) args {
    if (deviceId == nil || [deviceId length] == 0) {
        return args;
    }
    
    NSMutableArray* newArgs = [NSMutableArray arrayWithObjects: @"-s", deviceId, nil];
    
    return [newArgs arrayByAddingObjectsFromArray:args];
}

@end
