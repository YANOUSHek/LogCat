//
//  SelectableTableView.h
//  LogCat
//
//  Created by Chris Wilson on 12/12/12.
//

#import <Cocoa/Cocoa.h>
#import "MenuDelegate.h"

@interface SelectableTableView : NSTableView
{
    NSInteger rightClickedRow;
    NSInteger rightClickedColumn;
    
    id <MenuDelegate> menuDelegate;
}

@property (strong) id <MenuDelegate> menuDelegate;

@property NSInteger rightClickedRow;
@property NSInteger rightClickedColumn;

- (NSInteger)getRightClickedRow;
- (NSInteger)getRightClickedColumn;

@end
