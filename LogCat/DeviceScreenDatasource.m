//
//  DeviceScreenDatasource.m
//  LogCat
//
//  Created by Chris Wilson on 12/19/12.
//  Copyright (c) 2012 SplashSoftware.pl. All rights reserved.
//

#import "DeviceScreenDatasource.h"
#import "AdbTaskHelper.h"
#import "RGBHelper.h"

@interface DeviceScreenDatasource () {
    uint32_t width;
    uint32_t height;
    uint32_t bitsPerPixel;
    
    NSThread* screenUpdateThread;
    BOOL isRunning;
}

@end

@implementation DeviceScreenDatasource

@synthesize delegate;

- (id)init {
    if (self = [super init]) {
        width = 0U;
        height = 0U;
        bitsPerPixel = 0U;
    }
    return self;
}

- (void) startMonitoring {
    isRunning = YES;
    screenUpdateThread = [[NSThread alloc] initWithTarget:self selector:@selector(internalStartMonitoring) object:nil];
    [screenUpdateThread start];
}

- (void) stopMonitoring {
    isRunning = NO;
    if (screenUpdateThread != nil) {
        [screenUpdateThread cancel];
        screenUpdateThread = nil;
    }
}

- (void) internalStartMonitoring {
    // TODO: support multple devices. There needs a more general purpose way of handling this...
    
    if (width == 0 || height == 0 || bitsPerPixel == 0) {
        [self loadDeviceConfiguration];
    }
    
    if (width == 0 || height == 0 || bitsPerPixel == 0) {
        NSLog(@"ERROR: failed to load device configuration.");
        return;
    }
    
    while (isRunning && [screenUpdateThread isCancelled] == false) {
        [self pullScreenFromDevice];
        
        
        [NSThread sleepForTimeInterval:3]; // poll every N seconds
    }
    
}

/*
 Command:
    adb shell ioctl -rl 28 /dev/graphics/fb0 17920  

 Example output:
    sending ioctl 0x4600 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
    return buf: d0 02 00 00 00 05 00 00 d0 02 00 00 00 0a 00 00 00 00 00 00 00 05 00 00 20 00 00 00
 
 Format:
    0 - int32 - width
    1 - int32 - height
    7 - int32 - bitsPerPixel
 
 Reference:
    https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&ved=0CDEQFjAA&url=http%3A%2F%2Fnativedriver.googlecode.com%2Ffiles%2FScreenshot_on_Android_Internals.pdf&ei=AAPRULaOB8a2yAGIx4FY&usg=AFQjCNEY-gcxKRYrSEtwRVVZSt9XF8DItQ&bvm=bv.1355534169,d.aWM&cad=rja
 */
- (void) loadDeviceConfiguration {
    
    NSArray *arguments = [NSArray arrayWithObjects: @"shell", @"ioctl", @"-rl", @"28", @"/dev/graphics/fb0", @"17920", nil];
    
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

- (void) pullScreenFromDevice {
    NSLog(@"pullScreenFromDevice");
    
    

    NSFileManager *fileManager = [NSFileManager defaultManager];
    // TODO: Need better naming once we support multi-device
    [fileManager removeItemAtPath:@"/tmp/logcat.fb0" error:NULL];
    
    NSArray *arguments = [NSArray arrayWithObjects: @"pull", @"/dev/graphics/fb0", @"/tmp/logcat.fb0", nil];
    
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
    
    
    NSLog(@"Screen pulled: %@", string);
    
    // Transcode data
    BOOL exists = [fileManager fileExistsAtPath:@"/tmp/logcat.fb0"];
    if (!exists) {
        return;
    }

    NSImage* image = nil;
    
    NSData* nsData = [NSData dataWithContentsOfFile:@"/tmp/logcat.fb0"];
    NSLog(@"Data size: %ld, us=%ld", [nsData length], sizeof(unsigned int));

    if (bitsPerPixel == 32) {
        image = [[[RGBHelper alloc] init] convertRGB32toNSImage: [nsData bytes] width:width  height: height];
    } else {
        image = [[[RGBHelper alloc] init] convertRGBtoNSImage: [nsData bytes] width:width  height: height format:RGB565toRGBA_FORMAT];
    }
    
    if (image != nil) {
        [self performSelectorOnMainThread:@selector(updateImage:) withObject:image waitUntilDone:YES];
    }
}

- (void) updateImage: (NSImage*) image {
    if (delegate != nil) {
        [delegate onScreenUpdate:@"TODO:" :image];
    }
}


@end
