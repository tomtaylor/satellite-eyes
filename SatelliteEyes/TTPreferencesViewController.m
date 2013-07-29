//
//  PreferencesViewController.m
//  SatelliteEyes
//
//  Created by Tom Taylor on 27/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TTPreferencesViewController.h"
#import "LLManager.h"

@implementation TTPreferencesViewController

@synthesize startAtLogin;
@synthesize manageMapStylesWindowController;

- (void)awakeFromNib {
    self.startAtLogin = [LLManager launchAtLogin];
}

- (BOOL)startAtLogin {
    return [LLManager launchAtLogin];
}

- (void)setStartAtLogin:(BOOL)enabled {
    [self willChangeValueForKey:@"startAtLogin"];
    [LLManager setLaunchAtLogin:enabled];
    [self didChangeValueForKey:@"startAtLogin"];
}

- (IBAction)showManageMapStyles:(id)sender {
    self.manageMapStylesWindowController = [[TTManageMapStylesWindowController alloc] init];
    [manageMapStylesWindowController showWindow:self];
    [manageMapStylesWindowController.window makeKeyAndOrderFront:self];
    [manageMapStylesWindowController.window makeFirstResponder:nil];
}

@end
