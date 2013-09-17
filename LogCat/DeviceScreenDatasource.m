//
//  DeviceScreenDatasource.m
//  LogCat
//
//  Created by Chris Wilson on 12/19/12.
//

#import "DeviceScreenDatasource.h"
#import "AdbTaskHelper.h"
#import "RGBHelper.h"

#define SCREEN_CAP_SCREENCAP 1
#define SCREEN_CAP_FB0 2

#define SCREEN_CAP_TYPE SCREEN_CAP_SCREENCAP

#define SCREEN_CAP_FILE @"/mnt/sdcard/.logcatPNG"

@interface DeviceScreenDatasource () {
    uint32_t width;
    uint32_t height;
    uint32_t bitsPerPixel;
    
   
    BOOL isRunning;
}

@property (nonatomic, strong)  NSThread* screenUpdateThread;

@end

@implementation DeviceScreenDatasource

@synthesize screenUpdateThread = _screenUpdateThread;
@synthesize delegate = _delegate;
@synthesize deviceId = _deviceId;

- (id)init {
    if (self = [super init]) {
        width = 0U;
        height = 0U;
        bitsPerPixel = 0U;
    }
    return self;
}

- (void) startMonitoring {
    if (isRunning) {
        return;
    }
    isRunning = YES;
    
    if (self.screenUpdateThread == nil) {
        self.screenUpdateThread = [[NSThread alloc] initWithTarget:self selector:@selector(internalStartMonitoring) object:nil];
    }
    
    if (![self.screenUpdateThread isExecuting]) {
        NSLog(@"start monitoring screen");
        [self.screenUpdateThread start];
    }
}

- (void) stopMonitoring {
    isRunning = NO;
    if (self.screenUpdateThread != nil) {
        [self.screenUpdateThread cancel];
        self.screenUpdateThread = nil;
    }
}

- (void) internalStartMonitoring {
    // TODO: support multple devices. There needs a more general purpose way of handling this...
    
    if (SCREEN_CAP_TYPE == SCREEN_CAP_FB0) {
    
        if (width == 0 || height == 0 || bitsPerPixel == 0) {
            [self loadDeviceConfiguration];
        }
        
        if (width == 0 || height == 0 || bitsPerPixel == 0) {
            NSLog(@"ERROR: failed to load device configuration.");
            return;
        }
        
        while (isRunning && [self.screenUpdateThread isCancelled] == false) {
            [self pullScreenFromDevice];
            
            
            [NSThread sleepForTimeInterval:3]; // poll every N seconds
        }
    } else if (SCREEN_CAP_TYPE == SCREEN_CAP_SCREENCAP) {
        while (isRunning && [self.screenUpdateThread isCancelled] == false) {
            [self pullScreenFromDeviceWithScreenCap];
            
            
            [NSThread sleepForTimeInterval:3]; // poll every N seconds
        }
    } else {
        NSLog(@"ERROR: Unknow screen capture type.");
    }
    
}

/*
 Command:
    adb shell ioctl -rl 28 /dev/graphics/fb0 17920  

 Example output:
 Note:
    sending ioctl 0x4600 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
    return buf: d0 02 00 00 00 05 00 00 d0 02 00 00 00 0a 00 00 00 00 00 00 00 05 00 00 20 00 00 00
 
 Galaxy SIII
     sending ioctl 0x4600 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
     return buf: d0 02 00 00 00 05 00 00 d0 02 00 00 00 0f 00 00 00 00 00 00 00 0a 00 00 20 00 00 00
 
 Format:
    0 - int32 - width
    1 - int32 - height
    7 - int32 - bitsPerPixel
 
 Reference:
    https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&ved=0CDEQFjAA&url=http%3A%2F%2Fnativedriver.googlecode.com%2Ffiles%2FScreenshot_on_Android_Internals.pdf&ei=AAPRULaOB8a2yAGIx4FY&usg=AFQjCNEY-gcxKRYrSEtwRVVZSt9XF8DItQ&bvm=bv.1355534169,d.aWM&cad=rja
 */
- (void) loadDeviceConfiguration {
    
    NSArray *arguments = @[@"shell", @"ioctl", @"-rl", @"28", @"/dev/graphics/fb0", @"17920"];
    
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
    
    NSArray* lines = [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    for (NSString* line in lines) {
        if ([line hasPrefix:@"return buf:"]) {
            NSLog(@"TODO: parse: %@", line);
            NSScanner* scanner = [NSScanner scannerWithString:line];
            [scanner scanUpToString:@": " intoString:nil];
            [scanner scanString:@": " intoString:nil];
            
            width = [self scantBytesToInt:scanner];
            height = [self scantBytesToInt:scanner];
            [self scantBytesToInt:scanner]; // discard
            [self scantBytesToInt:scanner]; // discard
            [self scantBytesToInt:scanner]; // discard
            [self scantBytesToInt:scanner]; // discard
            bitsPerPixel = [self scantBytesToInt:scanner];
            break;
        }
    }
    NSLog(@"IOCTL: w=%d, h=%d, bpp=%d", width, height, bitsPerPixel);
    
    if (bitsPerPixel == 0) {
        NSLog(@"Failed to parse: %@", lines);
    }
    
}

- (uint32_t) scantBytesToInt: (NSScanner*) scanner {
    uint32_t a, b, c, d;
    
    [scanner scanHexInt:&a];
    [scanner scanHexInt:&b];
    [scanner scanHexInt:&c];
    [scanner scanHexInt:&d];
    uint32_t result =
            (a & 0x000000FFU) << 0  |
            (b & 0x000000FFU) << 8  |
            (d & 0x000000FFU) << 16 |
            (c & 0x000000FFU) << 24 ;
    
    //NSLog(@"Result: %d, 0x%4X", result, result);
    return result;
}

- (void) pullScreenFromDeviceWithScreenCap {
//    NSLog(@"pullScreenFromDeviceWithScreenCap");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // TODO: Need better naming once we support multi-device
    [fileManager removeItemAtPath:@"/tmp/logcat.png" error:NULL];
    [self doScreenshot];
    
    
    NSArray *arguments = @[@"pull", SCREEN_CAP_FILE, @"/tmp/logcat.png"];
    @try {
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
        /*
         Crashing here some times because of: NSFileHandleOperationException "Bad file descriptor"
         
         NSFileHandle::availableData
         This method raises NSFileHandleOperationException if attempts to determine the file-handle 
         type fail or if attempts to read from the file or channel fail.
         **/
        while ((data = [file availableData]) && [data length]) {
            [readData appendData:data];
        }
        
        NSString *string;
        string = [[NSString alloc] initWithData: readData encoding: NSUTF8StringEncoding];
        
        
//        NSLog(@"Screen pulled: %@", string);
        
        // Transcode data
        BOOL exists = [fileManager fileExistsAtPath:@"/tmp/logcat.png"];
        if (!exists) {
            return;
        }
        
        NSImage* image = [[NSImage alloc] initWithContentsOfFile:@"/tmp/logcat.png"];
        if (image != nil) {
            [self updateImage:image];
        }
    } @catch(NSException* ex) {
        // NSTask::launch Raises an NSInvalidArgumentException if the
        // launch path has not been set or is invalid or if it fails
        // to create a process.
        NSLog(@"************\n* Failed to get screen capture from device because %@\n***********************", ex);
        NSBeep();
    }

}

- (void) doScreenshot {
    NSArray *arguments = @[@"shell", @"/system/bin/screencap", @"-p", SCREEN_CAP_FILE];
    @try {
    
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
        
        // Just assume it worked and we will find out when we try to pull the file
        NSString *string;
        string = [[NSString alloc] initWithData: readData encoding: NSUTF8StringEncoding];
        
//        NSLog(@"screen shot result: %@", string);
    } @catch(NSException* ex) {
        NSLog(@"Failed to get screen capture from device because %@", ex);
    }
}


- (void) pullScreenFromDevice {
    NSLog(@"pullScreenFromDevice");

    NSFileManager *fileManager = [NSFileManager defaultManager];
    // TODO: Need better naming once we support multi-device
    [fileManager removeItemAtPath:@"/tmp/logcat.fb0" error:NULL];
    
    NSArray *arguments = @[@"pull", @"/dev/graphics/fb0", @"/tmp/logcat.fb0"];
    
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
    
    
    NSLog(@"Screen pulled: %@", string);
    
    // Transcode data
    BOOL exists = [fileManager fileExistsAtPath:@"/tmp/logcat.fb0"];
    if (!exists) {
        return;
    }

    NSImage* image = nil;
    
    NSData* nsData = [NSData dataWithContentsOfFile:@"/tmp/logcat.fb0"];
    NSLog(@"Data size: %ld, bits/pixel=%d", [nsData length], bitsPerPixel);

    if (bitsPerPixel == 32) {
        image = [[[RGBHelper alloc] init] convertRGB32toNSImage: [nsData bytes] width:width  height: height];
    } else if (bitsPerPixel == 16) {
        image = [[[RGBHelper alloc] init] convertRGBtoNSImage: [nsData bytes] width:width  height: height format:RGB565toRGBA_FORMAT];
    } else {
        image = [[[RGBHelper alloc] init] convertRGBtoNSImage: [nsData bytes] width:width  height: height format:RGB565toRGBA_FORMAT];
    }
    
    if (image != nil) {
        [self performSelectorOnMainThread:@selector(updateImage:) withObject:image waitUntilDone:YES];
    }
}

- (void) updateImage: (NSImage*) image {
    if (self.delegate != nil) {
        [self.delegate onScreenUpdate:@"TODO:" screen:image];
    }
}

- (NSArray*) argumentsForDevice: (NSArray*) args {
    if (self.deviceId == nil || [self.deviceId length] == 0) {
        return args;
    }
    
    NSMutableArray* newArgs = [NSMutableArray arrayWithObjects: @"-s", self.deviceId, nil];
    
    return [newArgs arrayByAddingObjectsFromArray:args];
}


@end
