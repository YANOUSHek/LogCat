//
//  FilterSheet.h
//  LogCat
//
//  Created by Chris Wilson on 12/12/12.
//

#import <Cocoa/Cocoa.h>

@interface FilterSheet : NSWindow {
    
}

@property (weak) IBOutlet NSTextField *filterName;
@property (weak) IBOutlet NSPopUpButton *filterType;
@property (weak) IBOutlet NSTextField *filterCriteria;


- (void) selectItemWithTitie: (NSString*) title;

@end


