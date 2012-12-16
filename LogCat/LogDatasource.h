//
//  LogDatasource
//  LogCat
//
//  Created by Chris Wilson on 12/15/12.
//  Copyright (c) 2012 SplashSoftware.pl. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol LogDatasourceDelegate <NSObject>

- (void) onLoggerStarted;
- (void) onLoggerStopped;

- (void) onLogUpdated;

@end


@interface LogDatasource : NSObject {
    id <LogDatasourceDelegate> delegate;
    
    NSDictionary* filter;
    NSString* searchString;
    
    NSString* deviceId;
    
    BOOL isLogging;
    
}

@property (weak) id <LogDatasourceDelegate> delegate;

@property (strong) NSDictionary* filter;
@property (strong) NSString* searchString;
@property (strong) NSString* deviceId;
@property BOOL isLogging;

- (void) startLogger;
- (void) stopLogger;
- (void) clearLog;

- (NSUInteger) getDisplayCount;
- (NSDictionary*) valueForIndex: (NSUInteger) index;

@end
