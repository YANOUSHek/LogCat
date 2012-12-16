//
//  AdbTaskHelper.m
//  LogCat
//
//  Created by Chris Wilson on 12/15/12.
//  Copyright (c) 2012 SplashSoftware.pl. All rights reserved.
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
