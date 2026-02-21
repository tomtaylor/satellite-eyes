//
//  TTAppDelegate.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 19/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class TTMapManager;
@class TTStatusItemController;
@class TTPreferencesWindowController;
@class TTAboutWindowController;
@class SPUStandardUpdaterController;

@interface TTAppDelegate : NSObject <NSApplicationDelegate> {
    TTMapManager *mapManager;
    TTStatusItemController *statusItemController;
    TTPreferencesWindowController *preferencesWindowController;
    TTAboutWindowController *aboutWindowController;
    SPUStandardUpdaterController *updaterController;
}

@property IBOutlet TTPreferencesWindowController *preferencesWindowController;
@property IBOutlet TTAboutWindowController *aboutWindowController;

- (void)menuActionExit:(id)sender;
- (void)forceMapUpdate:(id)sender;
- (void)openMapInBrowser:(id)sender;
- (void)checkForUpdates:(id)sender;
- (void)showPreferences:(id)sender;
- (void)showAbout:(id)sender;
- (void)setUserDefaults;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSURL *visibleMapBrowserURL;

@end
