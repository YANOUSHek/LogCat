//
//  RemoteScreenMonitorSheet.h
//  LogCat
//
//  Created by Chris Wilson on 12/19/12.
//

#import <Cocoa/Cocoa.h>
#import "DeviceScreenDatasource.h"

@interface RemoteScreenMonitorSheet : NSWindowController <NSWindowDelegate, DeviceScreenDatasourceDelegate> {
    __weak NSImageCell *screenImage;
    NSString* deviceId;
    __weak NSView *_containingImageView;
}

@property (weak) IBOutlet NSImageCell *screenImage;
@property (strong) NSString* deviceId;

- (IBAction)segmentedControl:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)copyScaledImage:(id)sender;

@property (weak) IBOutlet NSView *containingImageView;

@end
