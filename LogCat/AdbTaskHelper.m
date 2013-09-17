//
//  AdbTaskHelper.m
//  LogCat
//
//  Created by Chris Wilson on 12/15/12.
//

#import "AdbTaskHelper.h"

@implementation AdbTaskHelper

+ (NSTask*) adbTask: (NSArray*) arguments {
    NSTask *task;
    task = [[NSTask alloc] init];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString *adbPath = [defaults objectForKey:@"adbPath"];
    if (adbPath == nil && [adbPath length] == 0) {
        // Use built in adb
        //NSBundle *mainBundle = [NSBundle mainBundle];
        //adbPath = [mainBundle pathForResource:@"adb" ofType:nil];
    }
//    NSLog(@"Will use ADB [%@]", adbPath);
    
    [task setLaunchPath:adbPath];
    [task setArguments: arguments];
    
    return task;
}


@end
