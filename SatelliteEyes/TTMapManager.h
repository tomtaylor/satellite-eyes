//
//  TTMapManager.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 19/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "TTMapImage.h"

@class Reachability;

static NSString *const TTMapManagerStartedLoad = @"TTMapManagerStartedLoad";
static NSString *const TTMapManagerFailedLoad = @"TTMapManagerFailedLoad";
static NSString *const TTMapManagerFinishedLoad = @"TTMapManagerFinishedLoad";
static NSString *const TTMapManagerLocationUpdated = @"TTMapManagerLocationUpdated";
static NSString *const TTMapManagerLocationLost = @"TTMapManagerLocationLost";
static NSString *const TTMapManagerLocationPermissionDenied = @"TTMapManagerLocationPermissionDenied";

@interface TTMapManager : NSObject <CLLocationManagerDelegate> {
    CLLocationManager *locationManager;
    CLLocation *lastSeenLocation;
    dispatch_queue_t updateQueue;
    Reachability *reachability;
}

- (void)start;
- (void)updateMapToCoordinate:(CLLocationCoordinate2D)coordinate;
- (void)updateMap;
- (void)cleanCache;

@property (readonly) NSString *source;
@property (readonly) short unsigned int zoomLevel;
@property (readonly) NSDictionary *selectedMapType;
@property (readonly) NSImage *logoImage;
@property (readonly) TTMapImageEffect imageEffect;

@end
