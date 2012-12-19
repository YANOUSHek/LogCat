//
//  DeviceScreenDatasource.h
//  LogCat
//
//  Created by Chris Wilson on 12/19/12.
//  Copyright (c) 2012 SplashSoftware.pl. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DeviceScreenDatasourceDelegate <NSObject>

- (void) onScreenUpdate: (NSString*) deviceId: (NSImage*) screen;

@end

@interface DeviceScreenDatasource : NSObject {

    id <DeviceScreenDatasourceDelegate> delegate;
}

@property (strong) id <DeviceScreenDatasourceDelegate> delegate;



- (void) startMonitoring;

- (void) stopMonitoring;

@end

