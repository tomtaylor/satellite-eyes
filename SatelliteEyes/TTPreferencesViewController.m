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
@synthesize helpWindowController;
@synthesize selectableMapTypes;
@synthesize stadiaTokenTextField;

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

- (IBAction)showPreferencesHelp:(id)sender {
    self.helpWindowController = [[TTPreferencesHelpWindowController alloc] init];
    [helpWindowController showWindow:self];
    [helpWindowController.window makeKeyAndOrderFront:self];
    [helpWindowController.window makeFirstResponder:nil];
}

@end
