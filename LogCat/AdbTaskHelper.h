//
//  AdbTaskHelper.h
//  LogCat
//
//  Created by Chris Wilson on 12/15/12.
//

#import <Foundation/Foundation.h>

@interface AdbTaskHelper : NSObject

+ (NSTask*) adbTask: (NSArray*) arguments;

@end
