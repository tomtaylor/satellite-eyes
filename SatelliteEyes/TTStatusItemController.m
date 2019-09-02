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

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Menu"];
        menu.delegate = self;
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
        
        NSMenuItem *aboutMenuItem = [[NSMenuItem alloc] initWithTitle:@"About" action:@selector(showAbout:) keyEquivalent:@""];
        [menu addItem:aboutMenuItem];
        
        NSMenuItem *preferencesMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open preferences..." action:@selector(showPreferences:) keyEquivalent:@""];
        [menu addItem:preferencesMenuItem];
        
        NSMenuItem *updatesMenuItem = [[NSMenuItem alloc] initWithTitle:@"Check for updates..." action:@selector(checkForUpdates:) keyEquivalent:@""];
        [menu addItem:updatesMenuItem];
        
        NSMenuItem *itemExit = [[NSMenuItem alloc] initWithTitle:@"Exit" action:@selector(menuActionExit:) keyEquivalent:@""];
        [menu addItem:itemExit];
        
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:22];
        [statusItem setHighlightMode:YES];
        statusItem.menu = menu;
        
        [self updateStatus];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:TTMapManagerStartedLoad 
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note) {
                                                          self->mapManagerdidError = NO;
                                                          self->mapManagerisActive = YES;
                                                          [self performSelectorOnMainThread:@selector(updateStatus) withObject:nil waitUntilDone:YES];
                                                      }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:TTMapManagerFinishedLoad 
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note) {
                                                          self->mapManagerdidError = NO;
                                                          self->mapManagerisActive = NO;
                                                          self->mapLastUpdated = [NSDate date];
                                                          [self performSelectorOnMainThread:@selector(updateStatus) withObject:nil waitUntilDone:YES];

                                                      }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:TTMapManagerFailedLoad 
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note) {
                                                          self->mapManagerdidError = YES;
                                                          self->mapManagerisActive = NO;
                                                          [self performSelectorOnMainThread:@selector(updateStatus) withObject:nil waitUntilDone:YES];
                                                      }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:TTMapManagerLocationUpdated 
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note) {
                                                          self->mapManagerhasLocation = YES;
                                                          [self performSelectorOnMainThread:@selector(updateStatus) withObject:nil waitUntilDone:YES];
                                                      }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:TTMapManagerLocationLost
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note) {
                                                          self->mapManagerhasLocation = NO;
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
            [self startActivityAnimation];
            
        } else if (mapManagerdidError) {
            [self stopActivityAnimation];
            [self showError];
            
        } else { // is idle
            [self stopActivityAnimation];
            [self showNormal];
        }
        
    } else {
        [self stopActivityAnimation];
        [self showOffline];
        [forceMapUpdateMenuItem setEnabled:NO];
        [self disableOpenInBrowser];
    }
}
    
- (void)showOffline {
    NSImage *image = [NSImage imageNamed:@"status-icon-offline"];
    image.template = YES;
    statusItem.image = image;
    statusMenuItem.title = @"Waiting for location fix";
}

- (void)showNormal {
    NSImage *image = [NSImage imageNamed:@"status-icon-online"];
    image.template = YES;
    statusItem.image = image;

    [forceMapUpdateMenuItem setHidden:NO];
    
    if (mapLastUpdated) {
        statusMenuItem.title = [NSString stringWithFormat:@"Map updated %@", [mapLastUpdated distanceOfTimeInWords].lowercaseString];
        
    } else {
        statusMenuItem.title = @"Waiting for map update";
    }
}

- (void)startActivityAnimation {
    activityAnimationFrameIndex = 0;
    [self updateActivityImage];

    if (activityAnimationTimer) {
        [activityAnimationTimer invalidate];
    }

    activityAnimationTimer = [NSTimer timerWithTimeInterval:1.0/4.0
                                                     target:self
                                                   selector:@selector(updateActivityImage)
                                                   userInfo:nil
                                                    repeats:YES];
    activityAnimationTimer.tolerance = 0.01;
    [[NSRunLoop currentRunLoop] addTimer:activityAnimationTimer forMode:NSDefaultRunLoopMode];

    statusMenuItem.title = @"Updating the map";
}

- (void)updateActivityImage {
    NSString *imageName = [NSString stringWithFormat:@"status-icon-activity-%lu", (unsigned long)activityAnimationFrameIndex];
    NSImage *image = [NSImage imageNamed:imageName];
    image.template = YES;
    statusItem.image = image;
    if (activityAnimationFrameIndex >= 3) {
        activityAnimationFrameIndex = 0;
    } else {
        activityAnimationFrameIndex += 1;
    }
}

- (void)stopActivityAnimation {
    [activityAnimationTimer invalidate];
    activityAnimationTimer = nil;
}

- (void)showError {
    NSImage *image = [NSImage imageNamed:@"status-icon-error"];
    image.template = YES;
    statusItem.image = image;
    statusMenuItem.title = @"Problem updating the map";
}

- (void)enableOpenInBrowser {
    // It's a bit hacky to reach up into the App Delegate for this, but hey.
    TTAppDelegate *appDelegate = (TTAppDelegate *)[NSApplication sharedApplication].delegate;
    
    if ([appDelegate visibleMapBrowserURL]) {
        [openInBrowserMenuItem setEnabled:YES];
    } else {
        [openInBrowserMenuItem setEnabled:NO];
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
