//
//  DeviceListDatasource.m
//  LogCat
//
//  Created by Chris Wilson on 12/16/12.
//

#import "DeviceListDatasource.h"
#import "AdbTaskHelper.h"

@interface DeviceListDatasource () {
    
}

@property (nonatomic, strong) NSMutableArray* deviceList;
@property (nonatomic, strong) NSThread* thread;

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

@synthesize deviceList = _deviceList;
@synthesize delegate = _delegate;
@synthesize thread = _thread;

- (void) loadDeviceList {
    self.deviceList = [NSMutableArray arrayWithCapacity:0];
    
    if (self.thread == nil) {
        self.thread = [[NSThread alloc] initWithTarget:self selector:@selector(internalLoadDeviceList) object:nil];
    }
    
    if ([self.thread isExecuting] == NO) {
        [self.thread start];
    }
    
}

- (void) internalLoadDeviceList {
    [self fetchDevices];
    
    [self performSelectorOnMainThread:@selector(onDevicesConneceted:) withObject:self.deviceList waitUntilDone:NO];
    
}

- (void) fetchDevices {
    NSArray *arguments = @[@"devices"];
    @try {
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
    } @catch(NSException* ex) {
        // NSTask::launch Raises an NSInvalidArgumentException if the
        // launch path has not been set or is invalid or if it fails
        // to create a process.
        NSLog(@"************\n* Failed to get screen capture from device because %@\n***********************", ex);
        NSBeep();
    }
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
                
        [deviceInfo setValue:args[0] forKey:DEVICE_ID_KEY];
        [deviceInfo setValue:args[1] forKey:DEVICE_TYPE_KEY];
        
        [self.deviceList addObject:deviceInfo];
        
    }
}

- (void) onDevicesConneceted: (NSArray*) devices {
    if (self.delegate != nil) {
        [self.delegate onDevicesConneceted:self.deviceList];
    }
}

- (void) requestDeviceModel: (NSString*) deviceId {
    NSThread* thread = [[NSThread alloc] initWithTarget:self selector:@selector(internalDeviceModel:) object:deviceId];
    [thread start];
}

- (void) internalDeviceModel:(NSString*) deviceId {
    // adb shell cat /system/build.prop
    //ro.product.model=SAMSUNG-SGH-I747

    NSArray *arguments = @[@"-s", deviceId, @"shell", @"cat", @"/system/build.prop"];
    
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
            [self onDeviceModel:deviceId model:model];
        }
    }
    
}

- (void) onDeviceModel: (NSString*) deviceId model:(NSString*) model {
    if (delegate != nil) {
        [delegate  onDeviceModel: deviceId model: model];
    } else {
        NSLog(@"DeviceListDatasource delegate was nil.");
    }
}

@end
