//
//  DevicePickerSheet.h
//  LogCat
//
//  Created by Chris Wilson on 12/17/12.
//  Copyright (c) 2012 SplashSoftware.pl. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DevicePickerSheet : NSWindow {
    NSArray* devices;
}
@property (weak) IBOutlet NSPopUpButton* deviceButton;
@property (strong) NSArray* devices;

@end
