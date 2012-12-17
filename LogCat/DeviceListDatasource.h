//
//  DeviceListDatasource.h
//  LogCat
//
//  Created by Chris Wilson on 12/16/12.
//

#import <Foundation/Foundation.h>

#define DEVICE_ID_KEY @"id"
#define DEVICE_TYPE_KEY @"type"

@protocol DeviceListDatasourceDelegate <NSObject>

- (void) onDevicesConneceted: (NSArray*) devices;

@end

@interface DeviceListDatasource : NSObject {
    id <DeviceListDatasourceDelegate> delegate;
}

@property (weak) id <DeviceListDatasourceDelegate> delegate;

- (void) loadDeviceList;

@end
