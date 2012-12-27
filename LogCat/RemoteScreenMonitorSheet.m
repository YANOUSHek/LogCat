//
//  RemoteScreenMonitorSheet.m
//  LogCat
//
//  Created by Chris Wilson on 12/19/12.
//

#import "RemoteScreenMonitorSheet.h"
#import "DeviceScreenDatasource.h"

@interface RemoteScreenMonitorSheet () {
    DeviceScreenDatasource* screenSource;
}

@end

@implementation RemoteScreenMonitorSheet

@synthesize screenImage;

@synthesize deviceId;

- (id)init
{
    self=[super initWithWindowNibName:REMOTE_SCREEN_SHEET];
    if(self)
    {
        
    }
    return self;
}


- (IBAction)showWindow:(id)sender {
    if (screenSource != nil) {
        [screenSource setDeviceId:deviceId];
        [screenSource startMonitoring];
    }
    [super showWindow:sender];
}


- (void)windowDidLoad {
    NSLog(@"Remote Screen Window: windowDidLoad");
    [[self window] setTitle:@"Remote Screen Monitor"];
    [[self window] setBackgroundColor:[NSColor blackColor]];
    
    if (screenSource == nil) {
        screenSource = [[DeviceScreenDatasource alloc] init];
        [screenSource setDelegate:self];
    }
    
    [screenSource setDeviceId:deviceId];
    [screenSource startMonitoring];
}

- (void)windowWillBeginSheet:(NSNotification *)notification {
    NSLog(@"windowWillBeginSheet");
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

- (void) copy:(id)sender {
    NSLog(@"Copy Screen");
    NSImage *image = [screenImage image];
    if (image != nil) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        NSArray *copiedObjects = [NSArray arrayWithObject:image];
        [pasteboard writeObjects:copiedObjects];
    }
}

@end
