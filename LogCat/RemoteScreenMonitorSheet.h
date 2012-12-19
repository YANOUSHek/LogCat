//
//  RemoteScreenMonitorSheet.h
//  LogCat
//
//  Created by Chris Wilson on 12/19/12.
//  Copyright (c) 2012 SplashSoftware.pl. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DeviceScreenDatasource.h"

@interface RemoteScreenMonitorSheet : NSWindowController <NSWindowDelegate, DeviceScreenDatasourceDelegate> {
    __weak NSImageCell *screenImage;
}

@property (weak) IBOutlet NSImageCell *screenImage;

- (IBAction)segmentedControl:(id)sender;
- (IBAction)copy:(id)sender;
@end
