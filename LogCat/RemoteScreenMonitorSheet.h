//
//  RemoteScreenMonitorSheet.h
//  LogCat
//
//  Created by Chris Wilson on 12/19/12.
//

#import <Cocoa/Cocoa.h>
#import "DeviceScreenDatasource.h"

@interface RemoteScreenMonitorSheet : NSWindowController <NSWindowDelegate, DeviceScreenDatasourceDelegate> {
    NSString* deviceId;
    __weak NSImageCell *screenImage;
    __weak NSView *_containingImageView;
    __weak NSImageView *_imageView;
}


- (IBAction)copy:(id)sender;
- (IBAction)copyScaledImage:(id)sender;
- (IBAction)rotateImage:(id)sender;

@property (strong) NSString* deviceId;
@property (weak) IBOutlet NSView *containingImageView;
@property (weak) IBOutlet NSImageCell *screenImage;
@property (weak) IBOutlet NSImageView *imageView;

@end
