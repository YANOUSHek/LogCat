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

- (NSImage*) resize:(NSImage*)aImage width:(CGFloat)width height:(CGFloat)height scalingType:(NSImageScaling) type;

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

- (IBAction)refreshScreen:(id)sender {
    NSLog(@"TODO: refresh screen");
}


- (void) onScreenUpdate: (NSString*) deviceId: (NSImage*) screen {
//    [[self imageCell] setImage:image];
    
    [[self screenImage] setImage:screen];
    
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSLog(@"TODO: menuForEvent: %@", theEvent);
    return nil;
}

- (void)mouseDown:(NSEvent *)theEvent {
    
    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
    [theMenu insertItemWithTitle:@"Copy Scaled Image" action:@selector(copyScaledImage:) keyEquivalent:@"" atIndex:0];
    [theMenu insertItemWithTitle:@"Copy Full Image" action:@selector(copy:) keyEquivalent:@"" atIndex:1];
    
    [NSMenu popUpContextMenu:theMenu withEvent:theEvent forView:[self containingImageView]];
}

- (IBAction)segmentedControl:(id)sender {
    NSLog(@"Segmented Control Selected: %@", sender);
}

- (IBAction)copyScaledImage:(id)sender {
    NSLog(@"copyScaledImage");

    NSImage *image = [screenImage image];
    if (image == nil) {
        return;
    }
    
    image = [self resize:image
                   width:[self containingImageView].frame.size.width
                  height:[self containingImageView].frame.size.height
             scalingType:[[self screenImage] imageScaling]];
    
    [self copyImage:image];

}

- (IBAction)copyFullImage:(id)sender {
    NSLog(@"copyFullImage");
    NSImage *image = [screenImage image];
    [self copyImage:image];
}

- (void) copyImage:(NSImage*) image {
    if (image != nil) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        NSArray *copiedObjects = [NSArray arrayWithObject:image];
        [pasteboard writeObjects:copiedObjects];
    }
}

- (IBAction)copy:(id)sender {
    [self copyScaledImage:self];
}

- (NSImage*) resize:(NSImage*)aImage width:(CGFloat)width height:(CGFloat)height scalingType:(NSImageScaling) type {
    NSImageView* kView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
    [kView setImageScaling:type];
    [kView setImage:aImage];
    
    NSRect kRect = kView.frame;
    NSBitmapImageRep* kRep = [kView bitmapImageRepForCachingDisplayInRect:kRect];
    [kView cacheDisplayInRect:kRect toBitmapImageRep:kRep];
    
    NSData* kData = [kRep representationUsingType:NSJPEGFileType properties:nil];
    return [[NSImage alloc] initWithData:kData];
}

@end
