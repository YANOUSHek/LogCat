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

- (void) onDeviceNotFound;

- (void) onLogUpdated;

@end


@interface LogDatasource : NSObject {
    id <LogDatasourceDelegate> delegate;
    
    NSString* deviceId;
    
    BOOL isLogging;
    
}

@property (weak) id <LogDatasourceDelegate> delegate;

@property (strong) NSString* deviceId;
@property (atomic) BOOL isLogging;
@property (atomic) BOOL skipPidLookup;

- (void) startLogger;
- (void) stopLogger;
- (void) clearLog;
- (NSUInteger) logEventCount;
- (void) logMessage: (NSString*) message;
- (NSArray*) eventsForPredicate: (NSPredicate*) predicate;

- (void)readLog:(id)param;

@end
