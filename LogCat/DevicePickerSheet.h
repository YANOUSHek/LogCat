//
//  DevicePickerSheet.h
//  LogCat
//
//  Created by Chris Wilson on 12/17/12.
//

#import <Cocoa/Cocoa.h>

@interface DevicePickerSheet : NSWindow {
    NSArray* devices;
}
@property (weak) IBOutlet NSPopUpButton* deviceButton;
@property (strong) NSArray* devices;

@end
