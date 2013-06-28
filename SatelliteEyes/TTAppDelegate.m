//
//  TTAppDelegate.m
//  SatelliteEyes
//
//  Created by Tom Taylor on 19/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TTAppDelegate.h"
#import "TTMapManager.h"
#import "TTStatusItemController.h"
#import "TTPreferencesWindowController.h"
#import "LLManager.h"
#import "DDASLLogger.h"
#import "DDTTYLogger.h"

@implementation TTAppDelegate

@synthesize preferencesWindowController;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    preferencesWindowController = [[TTPreferencesWindowController alloc] init];
    
    [self setUserDefaults];
    
    // 100MB disk cache for tile images
    [[NSURLCache sharedURLCache] setDiskCapacity:100*1024^2];
    
    statusItemController = [[TTStatusItemController alloc] init];
    mapManager = [[TTMapManager alloc] init];
    
    BOOL shouldCleanCache = [[NSUserDefaults standardUserDefaults] boolForKey:@"cleanCache"];
    if (shouldCleanCache) {
        [mapManager cleanCache];
    }
    
    [[NSNotificationCenter defaultCenter] addObserverForName:TTMapManagerLocationPermissionDenied object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self shutdownWithLocationError];
    }];
    
    [self doFirstRun];
    [mapManager start];
    
}

- (void)menuActionExit:(id)sender {
    [[NSApplication sharedApplication] terminate:self];
}

- (void)showPreferences:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [preferencesWindowController showWindow:self];
    [preferencesWindowController.window makeKeyAndOrderFront:self];
    [preferencesWindowController.window makeFirstResponder:nil];
}

- (void)forceMapUpdate:(id)sender {
    [mapManager forceUpdateMap];
}

- (void)checkForUpdates:(id)sender {
    [[SUUpdater sharedUpdater] checkForUpdates:sender];
}

- (void)setUserDefaults {
    NSDictionary *appDefaults = [NSDictionary dictionaryWithContentsOfFile:
                                [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:appDefaults];
}

- (void)doFirstRun {
    NSString *firstRunKey = @"doneFirstRun";
    BOOL doneFirstRun = [[NSUserDefaults standardUserDefaults] boolForKey:firstRunKey];
    if (!doneFirstRun) {
        [self doHelloAlert];
        [self doStartupAlert];
    }
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:firstRunKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)doHelloAlert {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Welcome to Satellite Eyes"];
    [alert setInformativeText:@"Satellite Eyes is now running in the status bar at the top right of your screen.\n\nIt will automatically change your desktop wallpaper to your current location.\n\nYou can adjust the preferences by clicking on the icon."];
    [alert runModal];
}

- (void)doStartupAlert {
    NSAlert *startupAlert = [[NSAlert alloc] init];
    [startupAlert addButtonWithTitle:@"Yes"];
    [startupAlert addButtonWithTitle:@"No"];
    [startupAlert setMessageText:@"Run Satellite Eyes at Startup?"];
    [startupAlert setInformativeText:@"Satellite Eyes works best when it's run in the background all the time. Do you want it to run automatically at startup?"];
    
    NSInteger result = [startupAlert runModal];
    if (result == NSAlertFirstButtonReturn) {
        [LLManager setLaunchAtLogin:YES];
        
    } else if (result == NSAlertSecondButtonReturn) {
        // do nothing
    }
}

- (void)shutdownWithLocationError {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Satellite Eyes Will Quit"];
    [alert setInformativeText:@"Satellite Eyes needs permission to access your location, or it can't load the correct map.\n\nYou can enable Location Services from the Security & Privacy pane in System Preferences, and then restart the application."];
    [alert runModal];
    [NSApp terminate:nil];
}

- (NSURL *)visibleMapBrowserURL {
    return [mapManager browserURL];
}

- (void)openMapInBrowser:(id)sender {
    NSURL *browserURL = [mapManager browserURL];
    if (browserURL) {
        [[NSWorkspace sharedWorkspace] openURL:browserURL];
    }
}

@end
