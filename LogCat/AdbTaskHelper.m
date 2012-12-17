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
    NSBundle *mainBundle=[NSBundle mainBundle];
    NSString *path=[mainBundle pathForResource:@"adb" ofType:nil];
    
    [task setLaunchPath:path];
    [task setArguments: arguments];
    
    return task;
}


@end
