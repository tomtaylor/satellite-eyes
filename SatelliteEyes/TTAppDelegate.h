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

@interface TTAppDelegate : NSObject <NSApplicationDelegate> {
    TTMapManager *mapManager;
    TTStatusItemController *statusItemController;
    TTPreferencesWindowController *preferencesWindowController;
}

@property (nonatomic, retain) TTPreferencesWindowController *preferencesWindowController;

- (void)menuActionExit:(id)sender;
- (void)setUserDefaults;

@end
