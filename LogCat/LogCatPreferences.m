//
//  LogCatPreferences.m
//  LogCat
//
//  Created by Janusz Bossy on 21.11.2011.
//  Copyright (c) 2011 SplashSoftware.pl. All rights reserved.
//

#import "LogCatPreferences.h"
#import "LogCatAppDelegate.h"
#import "Constants.h"

@implementation LogCatPreferences

- (void)awakeFromNib
{
  self.tfAdbPath.stringValue = [[NSUserDefaults standardUserDefaults] objectForKey:PREFS_ADB_PATH];
}

- (void)setupToolbar
{
  [self addView:generalView label:@"General" image:[NSImage imageNamed:NSImageNamePreferencesGeneral]];
  [self addView:appearanceView label:@"Appearance" image:[NSImage imageNamed:NSImageNameColorPanel]];
  [self addView:aboutView label:@"About" image:[NSImage imageNamed:NSImageNameApplicationIcon]];
}

- (IBAction)browseForADB:(id)sender
{
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  [panel setDirectoryURL:[NSURL URLWithString:[@"~" stringByExpandingTildeInPath]]];
  [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
    if (result == NSFileHandlingPanelOKButton) {
      NSString* newPath = [panel.URL path];
      NSString* oldPath = self.tfAdbPath.stringValue;
      if ([newPath isEqualToString:oldPath]) {
        return;
      }
      
      self.tfAdbPath.stringValue = [panel.URL path];
      [[NSUserDefaults standardUserDefaults] setValue:[panel.URL path] forKey:PREFS_ADB_PATH];
      LogCatAppDelegate* appDelegate = [NSApp delegate];
      [appDelegate adbPathChanged];
    }
  }];
}

- (IBAction)fontChanged:(id)sender
{
  LogCatAppDelegate* appDelegate = [NSApp delegate];
  [appDelegate fontsChanged];
}

@end
