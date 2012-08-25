//
//  LLAppDelegate.m
//  LaunchAtLoginSample
//
//  Created by David Keegan on 4/20/12.
//  Copyright (c) 2012 David Keegan. All rights reserved.
//

#import "LLAppDelegate.h"
#import "LLManager.h"

@implementation LLAppDelegate

@synthesize window = _window;
@synthesize checkBox = _checkBox;

- (void)applicationDidFinishLaunching:(NSNotification *)notification{
    [self.checkBox setState:[LLManager launchAtLogin]];
}

- (IBAction)checkBoxAction:(id)sender{
    [LLManager setLaunchAtLogin:[self.checkBox state]];
}

@end
