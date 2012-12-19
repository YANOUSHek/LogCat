//
//  RemoteScreenMonitorSheet.m
//  LogCat
//
//  Created by Chris Wilson on 12/19/12.
//  Copyright (c) 2012 SplashSoftware.pl. All rights reserved.
//

#import "RemoteScreenMonitorSheet.h"
#import "DeviceScreenDatasource.h"

@interface RemoteScreenMonitorSheet () {
    DeviceScreenDatasource* screenSource;
}

@end

@implementation RemoteScreenMonitorSheet

@synthesize screenImage;

- (id)init
{
    self=[super initWithWindowNibName:REMOTE_SCREEN_SHEET];
    if(self)
    {
        
    }
    return self;
}


- (void)windowDidLoad {
    NSLog(@"Remote Screen Window: windowDidLoad");
    [[self window] setTitle:@"Remote Screen Monitor"];
    screenSource = [[DeviceScreenDatasource alloc] init];
    [screenSource setDelegate:self];
    
    [screenSource startMonitoring];

}

- (void)windowWillClose:(NSNotification *)notification {
    NSLog(@"RemoteScreenMonitorSheet will close");
    [screenSource stopMonitoring];
}



- (void) onScreenUpdate: (NSString*) deviceId: (NSImage*) screen {
//    [[self imageCell] setImage:image];
    
    [[self screenImage] setImage:screen];
    
}

- (IBAction)segmentedControl:(id)sender {
    NSLog(@"Segmented Control Selected: %@", sender);
}
@end
