//
//  LogCatPreferences.h
//  LogCat
//
//  Created by Janusz Bossy on 21.11.2011.
//  Copyright (c) 2011 SplashSoftware.pl. All rights reserved.
//

#import "DBPrefsWindowController.h"

@interface LogCatPreferences : DBPrefsWindowController {
    IBOutlet NSView *appearanceView;
    IBOutlet NSView *aboutView;
}
- (IBAction)fontChanged:(id)sender;

@end
