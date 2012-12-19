//
//  DeviceListDatasource.m
//  LogCat
//
//  Created by Chris Wilson on 12/16/12.
//

#import "DeviceListDatasource.h"
#import "AdbTaskHelper.h"

@interface DeviceListDatasource () {
    NSMutableArray* deviceList;
}

- (void) internalLoadDeviceList;

@end


/**
 It would be nice to somehow monitor USB and automatically detect when a device
 is connected or disconnect and update a list of available devices rather than
 this poll it when we get ready to start a capture.
 **/

// Device Information: adb shell cat /system/build.prop
// Device List: adb devices
@implementation DeviceListDatasource

@synthesize delegate;

- (void) loadDeviceList {
    deviceList = [NSMutableArray arrayWithCapacity:0];
    
    NSThread* thread = [[NSThread alloc] initWithTarget:self selector:@selector(internalLoadDeviceList) object:nil];
    [thread start];
    
}

- (void) internalLoadDeviceList {
    [self fetchDevices];
    
    [self performSelectorOnMainThread:@selector(onDevicesConneceted:) withObject:deviceList waitUntilDone:NO];
}

- (void) fetchDevices {
    NSArray *arguments = [NSArray arrayWithObjects: @"devices", nil];
    
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
    [self performSelectorOnMainThread:@selector(parseDeviceList:) withObject:string waitUntilDone:YES];
}

- (void) parseDeviceList: (NSString*) pidInfo {
    NSAssert([NSThread isMainThread], @"Method can only be called on main thread!");
    NSArray* lines = [pidInfo componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
    
    BOOL isFirstLine = YES;
    for (NSString* line in lines) {
        if (isFirstLine) {
            isFirstLine = NO;
            continue;
        } else if ([line hasPrefix:@"-"]) {
            continue;
        } else if ([line hasPrefix:@"error:"]) {
            NSLog(@"%@", line);
            continue;
        } else if ([line length] == 0) {
            continue;
        }
        
        NSArray* args =  [line componentsSeparatedByString:@"\t"];
        NSLog(@"Device: %@", args);
        NSMutableDictionary* deviceInfo = [NSMutableDictionary dictionaryWithCapacity:2];
                
        [deviceInfo setValue:[args objectAtIndex:0] forKey:DEVICE_ID_KEY];
        [deviceInfo setValue:[args objectAtIndex:1] forKey:DEVICE_TYPE_KEY];
        
        [deviceList addObject:deviceInfo];
        
    }
}

- (void) onDevicesConneceted: (NSArray*) devices {
    if (self.delegate != nil) {
        [self.delegate onDevicesConneceted:deviceList];
    }
}

- (void) requestDeviceModel: (NSString*) deviceId {
    NSThread* thread = [[NSThread alloc] initWithTarget:self selector:@selector(internalDeviceModel:) object:deviceId];
    [thread start];
}

- (void) internalDeviceModel:(NSString*) deviceId {
    // adb shell cat /system/build.prop
    //ro.product.model=SAMSUNG-SGH-I747

    NSArray *arguments = [NSArray arrayWithObjects: @"-s", deviceId, @"shell", @"cat", @"/system/build.prop", nil];
    
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
    NSArray* lines = [string componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
    for (NSString* line in lines) {
        if ([line hasPrefix:@"ro.product.model="]) {
            NSString* model = [line substringFromIndex:17];
            [self onDeviceModel:deviceId :model];
        }
    }
    
}

- (void) onDeviceModel: (NSString*) deviceId: (NSString*) model {
    if (delegate != nil) {
        [delegate  onDeviceModel: deviceId: model];
    } else {
        NSLog(@"DeviceListDatasource delegate was nil.");
    }
}

@end
