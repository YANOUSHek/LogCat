//
//  SelectableTableView.m
//  LogCat
//
//  Created by Chris Wilson on 12/12/12.
//

#import "SelectableTableView.h"
#import "MenuDelegate.h"

@implementation SelectableTableView

@synthesize rightClickedRow;
@synthesize rightClickedColumn;
@synthesize menuDelegate;

- (NSInteger)getRightClickedRow {
    return rightClickedRow;
}

- (NSInteger)getRightClickedColumn {
    return rightClickedColumn;
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
    
    rightClickedRow = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
    rightClickedColumn = [self columnAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
    
    NSLog(@"Menu for: %ld, %ld",rightClickedColumn, rightClickedRow);
    if (menuDelegate != nil) {
        return [menuDelegate menuForTableView:self column:rightClickedColumn row:rightClickedRow];
    }

    return nil;
}

@end
