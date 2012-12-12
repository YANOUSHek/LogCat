//
//  SelectableTableView.h
//  LogCat
//
//  Created by Chris Wilson on 12/12/12.
//  Copyright (c) 2012 SplashSoftware.pl. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SelectableTableView : NSTableView
{
    NSInteger rightClickedRow;
    NSInteger rightClickedColumn;
}

- (NSInteger)getRightClickedRow;
- (NSInteger)getRightClickedColumn;

@end
