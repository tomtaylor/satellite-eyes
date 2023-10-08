//
//  TTStatusItemController.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 20/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
@class Reachability;

@interface TTStatusItemController : NSObject <NSMenuDelegate> {
    NSStatusItem *statusItem;
    NSMenuItem *statusMenuItem;
    NSMenuItem *forceMapUpdateMenuItem;
    NSMenuItem *openInBrowserMenuItem;
    Reachability *reachability;
    BOOL mapManagerhasLocation;
    BOOL mapManagerisActive;
    BOOL mapManagerdidError;
    BOOL mapManagerUnauthorized;
    NSDate *mapLastUpdated;
    NSUInteger activityAnimationFrameIndex;
    NSTimer *activityAnimationTimer;
}

@end
