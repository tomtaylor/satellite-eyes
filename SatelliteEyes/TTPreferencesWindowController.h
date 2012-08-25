//
//  TTPreferencesWindowController.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 05/04/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>

@class TTPreferencesViewController;

@interface TTPreferencesWindowController : NSWindowController {
    TTPreferencesViewController *viewController;
    SUUpdater *updater;
}

@property (nonatomic, retain) IBOutlet SUUpdater *updater;

@end
