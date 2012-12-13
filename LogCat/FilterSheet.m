//
//  FilterSheet.m
//  LogCat
//
//  Created by Chris Wilson on 12/12/12.
//

#import "FilterSheet.h"

#define KEY_TIME @"time"
#define KEY_APP @"app"
#define KEY_PID @"pid"
#define KEY_TID @"tid"
#define KEY_TYPE @"type"
#define KEY_NAME @"name"
#define KEY_TEXT @"text"

@implementation FilterSheet

@synthesize filterType;

- (void) selectItemWithTitie: (NSString*) title {
    /*
     Column names do not match the filter type list so we have
     to match them up.
     */
    if (filterType != nil) {
        
        if ([title isEqualToString:KEY_TIME]) {
            //[filterType selectItemWithTitle:@""];
            
        } else if ([title isEqualToString:KEY_APP]) {
            [filterType selectItemWithTitle:@"APP"];
            
        } else if ([title isEqualToString:KEY_PID]) {
            [filterType selectItemWithTitle:@"PID"];
            
        } else if ([title isEqualToString:KEY_TID]) {
            [filterType selectItemWithTitle:@"TID"];
            
        } else if ([title isEqualToString:KEY_TYPE]) {
            [filterType selectItemWithTitle:@"Type"];
            
        } else if ([title isEqualToString:KEY_NAME]) {
            [filterType selectItemWithTitle:@"Tag"];
            
        } else if ([title isEqualToString:KEY_TEXT]) {
            [filterType selectItemWithTitle:@"Text"];
            
        }
        
    }
}

@end
