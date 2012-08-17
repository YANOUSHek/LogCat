//
//  LogCatPreferences.m
//  LogCat
//
//  Created by Janusz Bossy on 21.11.2011.
//  Copyright (c) 2011 SplashSoftware.pl. All rights reserved.
//

#import "LogCatPreferences.h"
#import "LogCatAppDelegate.h"

@implementation LogCatPreferences

- (void)setupToolbar
{
    [self addView:appearanceView label:@"Appearance" image:[NSImage imageNamed:NSImageNameQuickLookTemplate]];
    [self addView:aboutView label:@"About" image:[NSImage imageNamed:NSImageNameInfo]];
}

- (IBAction)fontChanged:(id)sender 
{
    LogCatAppDelegate* appDelegate = [NSApp delegate];
    [appDelegate fontsChanged];
}

@end
