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

@interface TTAppDelegate : NSObject <NSApplicationDelegate> {
    TTMapManager *mapManager;
    TTStatusItemController *statusItemController;
    TTPreferencesWindowController *preferencesWindowController;
    TTAboutWindowController *aboutWindowController;
}

@property IBOutlet TTPreferencesWindowController *preferencesWindowController;
@property IBOutlet TTAboutWindowController *aboutWindowController;

- (void)menuActionExit:(id)sender;
- (void)setUserDefaults;
- (NSURL *)visibleMapBrowserURL;

@end
