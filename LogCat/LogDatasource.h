//
//  LogDatasource
//  LogCat
//
//  Created by Chris Wilson on 12/15/12.
//

#import <Foundation/Foundation.h>

@protocol LogDatasourceDelegate <NSObject>

- (void) onLoggerStarted;
- (void) onLoggerStopped;

- (void) onMultipleDevicesConnected;

- (void) onLogUpdated;

@end


@interface LogDatasource : NSObject {
    id <LogDatasourceDelegate> delegate;
    
    NSString* deviceId;
    
    BOOL isLogging;
    
}

@property (weak) id <LogDatasourceDelegate> delegate;

@property (strong) NSString* deviceId;
@property BOOL isLogging;

- (void) startLogger;
- (void) stopLogger;
- (void) clearLog;

- (void) setSearchString: (NSString*) search;
- (void) setFilter: (NSDictionary*) filter;

- (NSUInteger) getDisplayCount;
- (NSDictionary*) valueForIndex: (NSUInteger) index;

@end
