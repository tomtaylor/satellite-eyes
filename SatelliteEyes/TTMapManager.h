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
static NSString *const TTMapManagerFailedUnauthorized = @"TTMapManagerFailedUnauthorized";
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
- (void)updateMapToCoordinate:(CLLocationCoordinate2D)coordinate force:(BOOL)force;
- (void)updateMap;
- (void)forceUpdateMap;
- (void)cleanCache;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSURL *browserURL;

@end
