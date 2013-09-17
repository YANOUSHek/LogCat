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
    [self addView:generalView label:@"General" image:[NSImage imageNamed:NSImageNamePreferencesGeneral]];
    [self addView:appearanceView label:@"Appearance" image:[NSImage imageNamed:NSImageNameQuickLookTemplate]];
    [self addView:aboutView label:@"About" image:[NSImage imageNamed:NSImageNameInfo]];
}

- (IBAction)fontChanged:(id)sender 
{
    LogCatAppDelegate* appDelegate = [NSApp delegate];
    [appDelegate fontsChanged];
}

- (IBAction)browseForADB:(id)sender
{
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setDirectoryURL:[NSURL URLWithString:[@"~" stringByExpandingTildeInPath]]];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSString* newPath = [panel.URL path];
            NSString* oldPath = [tfAdbPath stringValue];
            if ([newPath isEqualToString:oldPath]) {
                return;
            }
            
            [tfAdbPath setStringValue:[panel.URL path]];
            [[NSUserDefaults standardUserDefaults] setValue:[panel.URL path] forKey:@"adbPath"];
            LogCatAppDelegate* appDelegate = [NSApp delegate];
            [appDelegate adbPathChanged:newPath];
        }
    }];
}


@end
