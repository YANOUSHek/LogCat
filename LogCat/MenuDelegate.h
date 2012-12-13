//
//  MenuDelegate.h
//  LogCat
//
//  Created by Chris Wilson on 12/12/12.
//

#import <Foundation/Foundation.h>
@class NSTableView;


@protocol MenuDelegate <NSObject>

- (NSMenu*) menuForTableView: (NSTableView*) tableView column:(NSInteger) column row:(NSInteger) row;

@end
