//
//  LLHAppDelegate.m
//  LaunchAtLoginHelper
//
//  Created by David Keegan on 4/20/12.
//  Copyright (c) 2012 David Keegan.
//  Some rights reserved: <http://opensource.org/licenses/mit-license.php>
//

#import "LLHAppDelegate.h"
#import "LLStrings.h"

@implementation LLHAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
    // The scheme to launch the app
    NSString *scheme = [NSString stringWithFormat:@"%@://", LLURLScheme];
    NSURL *schemeURL = [NSURL URLWithString:scheme];
    
    // Get URL for app that responds to scheme
    NSURL *appURL = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:schemeURL];

    // Check if app exists
    if(appURL) {
        
        // App exists, run it
        [[NSWorkspace sharedWorkspace] openURL:schemeURL];
        
        // Call the app again this time with `launchedAtLogin` so it knows how it was launched
        NSString *schemeLaunchedAtLogin = [NSString stringWithFormat:@"%@://launchedAtLogin", LLURLScheme];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:schemeLaunchedAtLogin]];
        
    } else {
        
        // Log that the app couldn't be found
        NSLog(@"No app responds to %@, helper should be removed from launchd", scheme);
        
    }
    [NSApp terminate:self];
}

@end
