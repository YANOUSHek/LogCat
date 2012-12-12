//
//  SelectableTableView.m
//  LogCat
//
//  Created by Chris Wilson on 12/12/12.
//  Copyright (c) 2012 SplashSoftware.pl. All rights reserved.
//

#import "SelectableTableView.h"

@implementation SelectableTableView

- (NSInteger)getRightClickedRow
{
    return rightClickedRow;
}

- (NSInteger)getRightClickedColumn
{
    return rightClickedColumn;
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    rightClickedRow = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
    rightClickedColumn = [self columnAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
    
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(test) keyEquivalent:@"C"]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Copy Message" action:@selector(test) keyEquivalent:@""]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Add Filter..." action:@selector(test) keyEquivalent:@""]];
    
    return menu;
}

- (void) test {
    NSLog(@"TEST %ld, %ld",rightClickedColumn, rightClickedRow);
    
    
}

@end
