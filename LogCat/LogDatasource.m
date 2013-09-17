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

#define MAX_EVENT 20000
#define PRUNE_COUNT 1000

@interface LogDatasource () {
}


@property (strong, nonatomic) NSDate *startTime;
@property (strong, nonatomic) NSData* pendingData;
@property (strong, nonatomic) NSThread* thread;
@property (strong, nonatomic) NSMutableDictionary* pidMap;
@property (strong, atomic) NSMutableArray* logData;
@property (strong, nonatomic) NSArray* keysArray;
@property (strong, nonatomic) NSString* time;
@property (strong, nonatomic) NSString* app;
@property (strong, nonatomic) NSString* pid;
@property (strong, nonatomic) NSString* tid;
@property (strong, nonatomic) NSString* type;
@property (strong, nonatomic) NSString* name;
@property (strong, nonatomic) NSMutableString* text;
@property (nonatomic) NSUInteger counter;
@property (strong, nonatomic) NSString* previousString;


- (void) parsePID: (NSString*) pidInfo;
- (void) loadPID;
- (NSString*) getKeyFromType: (NSString*) selectedType;
- (void) onLogUpdated;
- (void) onLoggerStarted;
- (void) onLoggerStopped;
- (NSArray*) argumentsForDevice: (NSArray*) args;
- (NSNumber*) getIndex;

@end


@implementation LogDatasource
@synthesize delegate = _delegate;
@synthesize deviceId = _deviceId;
@synthesize isLogging;
@synthesize skipPidLookup;

@synthesize previousString = _previousString;
@synthesize startTime = _startTime;
@synthesize pendingData = _pendingData;
@synthesize  thread = _thread;
@synthesize  pidMap = _pidMap;
@synthesize  logData = _logData;
@synthesize  keysArray = _keysArray;
@synthesize  time = _time;
@synthesize  app = _app;
@synthesize  pid = _pid;
@synthesize  tid = _tid;
@synthesize  type = _type;
@synthesize  name = _name;
@synthesize  text = _text;
@synthesize  counter = _counter;


- (id)init {
    if (self = [super init]) {
        self.skipPidLookup = false;
        self.pidMap = [NSMutableDictionary dictionary];
        self.logData = [NSMutableArray arrayWithCapacity:0];
        self.text = [NSMutableString stringWithCapacity:0];
        self.keysArray = @[KEY_IDX, KEY_TIME, KEY_APP, KEY_PID, KEY_TID, KEY_TYPE, KEY_NAME, KEY_TEXT];
        isLogging = NO;
        self.previousString = nil;
        self.counter = 0;
    }
    return self;
}

- (NSArray*) eventsForPredicate: (NSPredicate*) predicate {
//    NSLog(@"eventsForPredicate: %ld", [self.logData count]);
    @try {
        if (self.logData == nil) {
            return @[];
        }
    } @catch(NSException* ex) {
        NSLog(@"Bug captured");
    }
        
    NSArray* filteredEvents = [self.logData copy];
//    NSLog(@"eventsForPredicate::filteredEvents: %ld", [filteredEvents count]);
    if (predicate != nil && filteredEvents != nil && [filteredEvents count] > 0) {
        @try {
            filteredEvents = [filteredEvents filteredArrayUsingPredicate:predicate];
        } @catch(NSException* ex) {
            NSLog(@"Bug captured");
        }
    }
    
    if (filteredEvents == nil) {
        filteredEvents = @[];
    }
    
    return filteredEvents;
    
}


- (void) startLogger {
    if (isLogging) {
        NSLog(@"ERROR: startLogger called but it was already running.");
        return;
    }
    
    self.startTime = [NSDate date];
    //[self clearLog];
    if (self.thread == nil) {
        self.thread = [[NSThread alloc] initWithTarget:self selector:@selector(internalStartLogger) object:nil];
        [self.thread start];
    }
}

- (void) stopLogger {
    NSLog(@"Stop logging called.");
    isLogging = NO;
    [self.thread cancel];
    self.thread = nil;
}

- (void) internalStartLogger {
    
    [self loadPID];
    [self readLog:nil];
}

- (void) clearLog {
    [self.pidMap removeAllObjects];
    [self.logData removeAllObjects];
    [self onLogUpdated];
    
}

#pragma mark -
#pragma mark PID Loader
#pragma mark -

- (void) loadPID {
    if (self.skipPidLookup) {
        return;
    }
    NSArray *arguments = nil;
    arguments = @[@"shell", @"ps"];
    
    NSTask *task = [AdbTaskHelper adbTask: [self argumentsForDevice:arguments]];
    @try {
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
    } @catch(NSException* ex) {
        // NSTask::launch Raises an NSInvalidArgumentException if the
        // launch path has not been set or is invalid or if it fails
        // to create a process.
        NSLog(@"************\n* Failed to get PID list from device because %@\n***********************", ex);
        NSBeep();
    }
    
}

- (void) parsePID: (NSString*) pidInfo {
    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");
    
    Boolean isFirstLine = YES;
    
    NSArray* lines = [pidInfo componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
    
    for (NSString* line in lines) {
        if ([line length] == 0) {
            // skip blank lines
            continue;
        } else if ([line hasPrefix:@"-"]) {
            continue;
        } else if ([line hasPrefix:@"error:"]) {
            NSLog(@"parsePID: %@", line);
            if ([line isEqualToString:MULTIPLE_DEVICE_MSG]) {
                NSLog(@"Multiple devices. Abort. (1)");
                isLogging = NO;
                [self onMultipleDevicesConnected];
                [self stopLogger];
                return;
            } else if ([line isEqualToString:DEVICE_NOT_FOUND_MSG]) {
                NSLog(@"Device not found. Abort. (1)");
                isLogging = NO;
                [self onDeviceNotFound];
                [self stopLogger];
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
            
            NSString* aName = args[[args count]-1];
            if ([aPid isInteger]) {
                [self.pidMap setValue:aName forKey:aPid];
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
    if (param != nil) {
        // assume caller is passing the arguments we need
        self.skipPidLookup = YES;
        arguments = param;
        
    } else if (LOG_FORMAT == 1) {
        arguments = @[@"logcat", @"-v", @"long"];
        
    } else if (LOG_FORMAT == 2) {
    
        arguments = @[@"logcat", @"-v", @"threadtime"];
    } else if (LOG_FORMAT == 3) {
        
        arguments = @[@"logcat", @"-B"];
    }
    
    @try {
    
        NSTask *task = nil;
        if (param != nil) {
            task = [[NSTask alloc] init];
            
            NSString *catPath = @"/bin/cat";
            
            [task setLaunchPath:catPath];
            [task setArguments: arguments];

        } else {
        
            task = [AdbTaskHelper adbTask:[self argumentsForDevice:arguments]];
        }
        
        NSPipe *pipe;
        pipe = [NSPipe pipe];
        [task setStandardOutput: pipe];
        [task setStandardError:pipe];
        [task setStandardInput:[NSPipe pipe]];
        
        NSFileHandle *file;
        file = [pipe fileHandleForReading];
        
        [task launch];
        //NSLog(@"Task isRunning: %d", task.isRunning);
        
        NSData *data = nil;
        while (isLogging && (((data = [file availableData]) != nil) || [task isRunning])) {
            //NSLog(@"Task: %d, data=%@", [task isRunning], data);
            while (data == nil || [data length] == 0) {
                data = [file availableData];
                if ((data == nil || [data length] == 0) && ![task isRunning]) {
                    isLogging = NO;
                    break;
                }
            }
            
            if (data != nil) {
                
                NSString *string;
                string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    //            NSLog(@"Data: %@", string);
                if (param != nil) {
                    NSLog(@"Parse: %@", string);
                    [self appendThreadtimeLog:string];
                } else if (LOG_FORMAT == 1) {
                    [self performSelectorOnMainThread:@selector(appendLongLog:) withObject:string waitUntilDone:YES];
                    
                } else if (LOG_FORMAT == 2) {
    //                [self performSelectorOnMainThread:@selector(appendThreadtimeLog:) withObject:string waitUntilDone:YES];
                    [self appendThreadtimeLog:string];
                    
                } else if (LOG_FORMAT == 3) {
                    [self appendBinaryLog:data];
                    
                }
            } else {
                NSLog(@"Data was nil...");
            }
            data = nil;
        }
        
        [task terminate];
    } @catch(NSException* ex) {
        // NSTask::launch Raises an NSInvalidArgumentException if the
        // launch path has not been set or is invalid or if it fails
        // to create a process.
        NSLog(@"************\n* Failed to get read log from device because %@\n***********************", ex);
        NSBeep();
    }
    
    NSLog(@"Exited readlog loop.");
    isLogging = NO;
    [self.pidMap removeAllObjects];
    
    [self logMessage:[NSString stringWithFormat:@"Disconnected. %@", self.deviceId]];
    
    [self performSelectorOnMainThread:@selector(onLoggerStopped) withObject:nil waitUntilDone:NO];
    
    [self stopLogger];
    NSLog(@"ADB Exited.");
    self.skipPidLookup = NO;
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

- (NSUInteger) logEventCount {
    return [self.logData count];
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
//    NSLog(@"appendThreadtimeLog on thread: %@", [NSThread currentThread]);
    NSMutableString* currentLine = [NSMutableString string];
    
    NSString* defCopy = [self.previousString copy];
    if (defCopy != nil && [defCopy length] > 0) {
        [currentLine appendString:defCopy];
        self.previousString = nil;
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
    
    self.previousString = currentLine;
    [self performSelectorOnMainThread:@selector(onLogUpdated) withObject:nil waitUntilDone:YES];
    
    if ([self.previousString length] > 0 && [self.previousString hasPrefix:@"0"] == NO) {
        NSLog(@"x Invalid previous line: \"%@\"", self.previousString);
    }

}

- (void) parseThreadTimeLine: (NSString*) line {
    
    
    if ([line hasPrefix:@"-appPID"] || [line hasPrefix:@"- appPID"]) {
        NSArray *strings = [line componentsSeparatedByString:@","];
        if ([strings count] == 3) {
            NSString* pid = [strings[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString* app = [strings[2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSLog(@"Adding PID \"%@\" for app \"%@\"", pid, app);
            [self.pidMap setValue:app forKey:pid];
        }
        
        return;
    } else if ([line hasPrefix:@"-"]) {
        return;
    } else if ([line hasPrefix:@"error:"]) {
        NSLog(@"parseThreadTimeLine: \"%@\", %@", line, self);
        if ([line hasPrefix:MULTIPLE_DEVICE_MSG]) {
            isLogging = NO;
            NSLog(@"parseThreadTimeLine: %@, %@", line, self);
            [self performSelectorOnMainThread:@selector(onMultipleDevicesConnected) withObject:nil waitUntilDone:YES];
//            [self onMultipleDevicesConnected];
            return;
        } else if ([line hasPrefix:DEVICE_NOT_FOUND_MSG]) {
            NSLog(@"Device Not Found. Abort Logcat.");
            isLogging = NO;
            [self performSelectorOnMainThread:@selector(onMultipleDevicesConnected) withObject:nil waitUntilDone:YES];
//            [self onMultipleDevicesConnected];
            return;
        }
        return;
    }
    self.previousString = line;
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
    NSArray* values = @[[self getIndex], fullTimeVal, appVal, pidVal, tidVal, logLevelVal, tagVal, msgVal];
    NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:self.keysArray];
    [self appendRow:row];

}

- (NSNumber*) getIndex {
    return [NSNumber numberWithUnsignedInteger:self.counter++];
}


- (void)appendLongLog:(NSString*)paramString
{
    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");
    
    NSString* currentString;
    if (self.previousString != nil) {
        currentString = [NSString stringWithFormat:@"%@%@", self.previousString, paramString];
        self.previousString = nil;
    } else {
        currentString = [NSString stringWithFormat:@"%@", paramString];
    }
    
    if ([currentString rangeOfString:@"\n"].location == NSNotFound) {
        self.previousString = [currentString copy];
        return;
    }
    
    NSArray* lines = [currentString componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
    
    if (![currentString hasSuffix:@"\n"]) {
        self.previousString = [lines[[lines count]-1] copy];
    }
    
    for (NSString* line in lines) {
        
        if ([line hasPrefix:@"-appPID"] || [line hasPrefix:@"- appPID"]) {
            NSArray *strings = [line componentsSeparatedByString:@","];
            if ([strings count] == 3) {
                [self.pidMap setValue:strings[2] forKey:strings[1]];
            }
            
            continue;
        } else if ([line hasPrefix:@"-"]) {
            
            
            continue;
        } else if ([line hasPrefix:@"error:"]) {
            NSLog(@"appendLongLog: %@", line);
            if ([line isEqualToString:MULTIPLE_DEVICE_MSG]) {
                NSLog(@"Mulitple devices. Abort.");
                isLogging = NO;
                [self onMultipleDevicesConnected];
                return;
            } else if ([line isEqualToString:DEVICE_NOT_FOUND_MSG]) {
                NSLog(@"Device not found. Abort.");
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
            self.time = [line substringWithRange:[match rangeAtIndex:1]];
            self.pid = [line substringWithRange:[match rangeAtIndex:2]];
            self.tid = [line substringWithRange:[match rangeAtIndex:3]];
            self.app = (self.pidMap)[self.pid];
            if (self.app == nil) {
                NSLog(@"%@ not found in pid map. (1)", self.pid);
                [self loadPID];
                self.app = (self.pidMap)[self.pid];
                if (self.app == nil) {
                    // This is normal during startup because there can be log
                    // messages from apps that are not running anymore.
                    self.app = @"unknown";
//                    [pidMap setValue:app forKey:pid];
                }
            }
            self.type = [line substringWithRange:[match rangeAtIndex:4]];
            self.name = [line substringWithRange:[match rangeAtIndex:5]];
            
            // NSLog(@"xxx--- 1 time: %@, app: %@, pid: %@, tid: %@, type: %@, name: %@", time, app, pid, tid, type, name);
        } else if (match == nil && [line length] != 0 && !([self.previousString length] > 0 && [line isEqualToString:self.previousString])) {
            [self.text appendString:@"\n"];
            [self.text appendString:line];
            
            // NSLog(@"xxx--- 2 text: %@", text);
        } else if ([line length] == 0 && time != nil) {
            // NSLog(@"xxx--- 3 text: %@", text);
            
            if ([self.text rangeOfString:@"\n"].location != NSNotFound) {
                // NSLog(@"JEST!");
                NSArray* linesOfText = [self.text componentsSeparatedByString:@"\n"];
                for (NSString* lineOfText in linesOfText) {
                    if ([lineOfText length] == 0) {
                        continue;
                    }
                    NSArray* values = @[[self getIndex], self.time, self.app, self.pid, self.tid, self.type, self.name, lineOfText];
                    NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:self.keysArray];
                    
                    [self appendRow:row];
                }
            } else {
                // NSLog(@"xxx--- 4 text: %@", text);
                
                NSArray* values = @[[self getIndex] ,self.time, self.app, self.pid, self.tid, self.type, self.name, self.text];
                NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:self.keysArray];
                [self appendRow:row];                
            }
            
            self.time = nil;
            self.app = nil;
            self.pid = nil;
            self.tid = nil;
            self.type = nil;
            self.name = nil;
            self.text = [NSMutableString new];
        }
    }

    [self onLogUpdated];
    
}

- (void) appendRow: (NSDictionary*) row {
    NSTimeInterval elapsedTime = -[self.startTime timeIntervalSinceNow];
    if (elapsedTime < 30 && self.logData != nil && [self.logData count] > 0) {
        NSDictionary* lastItem = [self.logData lastObject];
        if ([row[KEY_TIME] compare:lastItem[KEY_TIME]] == NSOrderedAscending) {
//            NSLog(@"Event is older: row=%@, last=%@", [row objectForKey:KEY_TIME], [lastItem objectForKey:KEY_TIME]);
        } else {
            [self.logData addObject:row];
        }
    } else {
        [self.logData addObject:row];
    }
    
    if ([self.logData count] > MAX_EVENT) {
        NSLog(@"Prune event. %ld > %d", [self.logData count], MAX_EVENT);
        // Make room for more events
        while ([self.logData count] > (MAX_EVENT-PRUNE_COUNT)) {
            [self.logData removeObjectAtIndex:0];
        }
    }
}

- (void) logMessage: (NSString*) message {
    NSArray* values = @[[self getIndex], @"----", @"LogCat", @"---", @"---", @"I", @"---", message];
    NSDictionary* row = [NSDictionary dictionaryWithObjects:values
                                                    forKeys:self.keysArray];
    
    [self appendRow:row];
    [self performSelectorOnMainThread:@selector(onLogUpdated) withObject:nil waitUntilDone:YES];
    
}

- (NSString*) appNameForPid:(NSString*) pidVal {
    
    NSString* appVal = (self.pidMap)[pidVal];
    if (appVal == nil) {
        NSLog(@"%@ not found in pid map. (2)", pidVal);
        if (!self.skipPidLookup) {
            [self loadPID];
        }
        appVal = (self.pidMap)[pidVal];
        if (appVal == nil) {
            // This is normal during startup because there can be log
            // messages from apps that are not running anymore.
            appVal = @"unknown";
            NSTimeInterval elapsedTime = -[self.startTime timeIntervalSinceNow];
            // NSLog(@"Elapsed: %f", elapsedTime);
            if (elapsedTime < 30) {
                // There are potentially a lot of these when we first start reading the cached log
                [self.pidMap setValue:appVal forKey:pidVal];
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
    if (self.deviceId == nil || [self.deviceId length] == 0) {
        return args;
    }
    
    NSMutableArray* newArgs = [NSMutableArray arrayWithObjects: @"-s", self.deviceId, nil];
    return [newArgs arrayByAddingObjectsFromArray:args];
}

@end
