//
//  TTStatusItemController.m
//  SatelliteEyes
//
//  Created by Tom Taylor on 20/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TTAppDelegate.h"
#import "TTStatusItemController.h"
#import "TTMapManager.h"
#import "Reachability.h"
#import "NSDate+Formatting.h"

@implementation TTStatusItemController

- (id)init
{
    self = [super init];
    if (self) {
        offlineImage = [NSImage imageNamed:@"menu-outline"];
        activeImage = [NSImage imageNamed:@"menu-blue"];
        inactiveImage = [NSImage imageNamed:@"menu-black"];
        errorImage = [NSImage imageNamed:@"menu-red"];

        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Menu"];
        [menu setDelegate:self];
        [menu setAutoenablesItems:NO];
        
        statusMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
        [statusMenuItem setEnabled:NO];
        [menu addItem:statusMenuItem];
        
        forceMapUpdateMenuItem = [[NSMenuItem alloc] initWithTitle:@"Refresh the map now" action:@selector(forceMapUpdate:) keyEquivalent:@""];
        [forceMapUpdateMenuItem setEnabled:NO];
        [menu addItem:forceMapUpdateMenuItem];
        
        openInBrowserMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open in browser" action:@selector(openMapInBrowser:) keyEquivalent:@""];
        [openInBrowserMenuItem setEnabled:NO];
        [menu addItem:openInBrowserMenuItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *preferencesMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open Preferences..." action:@selector(showPreferences:) keyEquivalent:@""];
        [menu addItem:preferencesMenuItem];
        
        NSMenuItem *updatesMenuItem = [[NSMenuItem alloc] initWithTitle:@"Check for updates..." action:@selector(checkForUpdates:) keyEquivalent:@""];
        [menu addItem:updatesMenuItem];
        
        NSMenuItem *itemExit = [[NSMenuItem alloc] initWithTitle:@"Exit" action:@selector(menuActionExit:) keyEquivalent:@""];
        [menu addItem:itemExit];
        
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:22];
        [statusItem setHighlightMode:YES];
        [statusItem setMenu:menu];
        
        [self updateStatus];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:TTMapManagerStartedLoad 
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note) {
                                                          mapManagerdidError = NO;
                                                          mapManagerisActive = YES;
                                                          [self performSelectorOnMainThread:@selector(updateStatus) withObject:nil waitUntilDone:YES];
                                                      }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:TTMapManagerFinishedLoad 
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note) {
                                                          mapManagerdidError = NO;
                                                          mapManagerisActive = NO;
                                                          mapLastUpdated = [NSDate date];
                                                          [self performSelectorOnMainThread:@selector(updateStatus) withObject:nil waitUntilDone:YES];

                                                      }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:TTMapManagerFailedLoad 
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note) {
                                                          mapManagerdidError = YES;
                                                          mapManagerisActive = NO;
                                                          [self performSelectorOnMainThread:@selector(updateStatus) withObject:nil waitUntilDone:YES];
                                                      }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:TTMapManagerLocationUpdated 
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note) {
                                                          mapManagerhasLocation = YES;
                                                          [self performSelectorOnMainThread:@selector(updateStatus) withObject:nil waitUntilDone:YES];
                                                      }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:TTMapManagerLocationLost
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note) {
                                                          mapManagerhasLocation = NO;
                                                          [self performSelectorOnMainThread:@selector(updateStatus) withObject:nil waitUntilDone:YES];
                                                      }];
    }
    return self;
}

- (void)updateStatus {
    if (mapManagerhasLocation) {
        [forceMapUpdateMenuItem setEnabled:YES];
        [self enableOpenInBrowser];
        
        if (mapManagerisActive) {
            [self showActivity];
            
        } else if (mapManagerdidError) {
            [self showError];
            
        } else { // is idle
            [self showNormal];
        }
        
    } else {
        [self showOffline];
        [forceMapUpdateMenuItem setEnabled:NO];
        [self disableOpenInBrowser];
    }
}
    
- (void)showOffline {
    statusItem.image = offlineImage;
    statusMenuItem.title = @"Waiting for location fix";
}

- (void)showNormal {
    statusItem.image = inactiveImage;
    [forceMapUpdateMenuItem setHidden:NO];
    
    if (mapLastUpdated) {
        statusMenuItem.title = [NSString stringWithFormat:@"Map updated %@", [[mapLastUpdated distanceOfTimeInWords] lowercaseString]];
        
    } else {
        statusMenuItem.title = @"Waiting for map update";
    }
}

- (void)showActivity {
    statusItem.image = activeImage;
    statusMenuItem.title = @"Updating the map";
}

- (void)showError {
    statusItem.image = errorImage;
    statusMenuItem.title = @"Problem updating the map";
}

- (void)enableOpenInBrowser {
    // It's a bit hacky to reach up into the App Delegate for this, but hey.
    TTAppDelegate *appDelegate = (TTAppDelegate *)[[NSApplication sharedApplication] delegate];
    
    if ([appDelegate visibleMapBrowserURL]) {
        [openInBrowserMenuItem setEnabled:YES];
    }
}

- (void)disableOpenInBrowser {
    [openInBrowserMenuItem setEnabled:NO];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark NSMenuDelegate methods

- (void)menuWillOpen:(NSMenu *)menu {
    [self updateStatus];
}

@end
