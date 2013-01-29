//
//  DeviceScreenDatasource.h
//  LogCat
//
//  Created by Chris Wilson on 12/19/12.
//

#import <Foundation/Foundation.h>

@protocol DeviceScreenDatasourceDelegate <NSObject>

- (void) onScreenUpdate: (NSString*) deviceId screen:(NSImage*) screen;

@end

@interface DeviceScreenDatasource : NSObject {

    id <DeviceScreenDatasourceDelegate> delegate;
    
    NSString* deviceId;
}

@property (strong) id <DeviceScreenDatasourceDelegate> delegate;

@property (strong) NSString* deviceId;


- (void) startMonitoring;

- (void) stopMonitoring;

@end

