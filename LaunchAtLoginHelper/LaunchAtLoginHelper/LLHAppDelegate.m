//
//  LLHAppDelegate.m
//  LaunchAtLoginHelper
//
//  Created by David Keegan on 4/20/12.
//  Copyright (c) 2012 David Keegan. All rights reserved.
//

#import "LLHAppDelegate.h"
#import "LLStrings.h"

@implementation LLHAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification{
    // Call the scheme to launch the app
    NSString *scheme = [NSString stringWithFormat:@"%@://", LLURLScheme];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:scheme]];
    
    // Call the app again this time with `launchedAtLogin` so it knows how it was launched
    NSString *schemeLaunchedAtLogin = 
    [NSString stringWithFormat:@"%@://launchedAtLogin", LLURLScheme];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:schemeLaunchedAtLogin]];    
    [NSApp terminate:self];
}

@end
