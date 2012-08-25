//
//  TTMapManager.m
//  SatelliteEyes
//
//  Created by Tom Taylor on 19/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TTMapManager.h"
#import "TTMapImage.h"
#import "TTMapTile.h"
#import "NSFileManager+StandardPaths.h"
#import "Reachability.h"

@interface TTMapManager (Private)

- (CGRect)tileRectForScreen:(NSScreen *)screen 
                 coordinate:(CLLocationCoordinate2D)coordinate 
                  zoomLevel:(unsigned short)zoomLevel;

@end

@implementation TTMapManager

@synthesize source;
@synthesize zoomLevel;

- (id)init
{
    self = [super init];
    if (self) {
        locationManager = [[CLLocationManager alloc] init];
        locationManager.distanceFilter = 300;
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        locationManager.delegate = self;
        //locationManager.purpose = @"Satellite Eyes needs permission to access your location so it can update your desktop wallpaper with the view overhead.";
        
        // serial dispatch queue to synchronize map updates
        updateQueue = dispatch_queue_create("uk.co.tomtaylor.satelliteeyes.mapupdate", DISPATCH_QUEUE_SERIAL);
        
        reachability = [Reachability reachabilityForInternetConnection];
        [reachability startNotifier];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:) 
                                                     name:kReachabilityChangedNotification 
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(screensChanged:) 
                                                     name:NSApplicationDidChangeScreenParametersNotification 
                                                   object:nil];
        
        [[NSUserDefaults standardUserDefaults] addObserver:self 
                                                forKeyPath:@"selectedMapTypeIndex" 
                                                   options:NSKeyValueObservingOptionNew
                                                   context:nil];
        
        [[NSUserDefaults standardUserDefaults] addObserver:self 
                                                forKeyPath:@"zoomLevel" 
                                                   options:NSKeyValueObservingOptionNew
                                                   context:nil];
        
        [[NSUserDefaults standardUserDefaults] addObserver:self 
                                                forKeyPath:@"imageEffect" 
                                                   options:NSKeyValueObservingOptionNew
                                                   context:nil];

        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self 
                                                               selector:@selector(spaceChanged:) 
                                                                   name:NSWorkspaceActiveSpaceDidChangeNotification 
                                                                 object:nil];
        
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self 
                                                               selector:@selector(receiveWakeNote:) 
                                                                   name:NSWorkspaceDidWakeNotification 
                                                                 object:nil];
    }
    return self;
}

- (void)start {
    if ([CLLocationManager locationServicesEnabled]) {
        [locationManager startUpdatingLocation];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerLocationPermissionDenied object:nil];
    }    
}

// If the screens have changed, force an update.
- (void)screensChanged:(NSNotification *)notification {
    [self updateMap];
}

- (void)spaceChanged:(NSNotification *)notification {
    [self updateMap];
}

- (void)receiveWakeNote:(NSNotification *)notification {
    [self restartMap];
}

- (void)reachabilityChanged:(NSNotification *)notification {
    Reachability *thisReachability = notification.object;
    
    if (thisReachability.isReachable) {
        [self updateMap];
    } else {
        [self restartMap];
    }
}

- (void)updateMap {
    if (lastSeenLocation) {
        [self updateMapToCoordinate:lastSeenLocation.coordinate];
    }
}

// Lose the location and force fetching a new one
- (void)restartMap {
    [locationManager stopUpdatingLocation];
    lastSeenLocation = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerLocationLost object:nil];
    [locationManager startUpdatingLocation];    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self updateMap];
}

- (void)updateMapToCoordinate:(CLLocationCoordinate2D)coordinate
{
    [[NSScreen screens] enumerateObjectsUsingBlock:^(NSScreen *screen, NSUInteger idx, BOOL *stop) {
        // put everything through the serial dispatch queue to ensure we're 
        // not requesting the same tile multiple times concurrently
        dispatch_async(updateQueue, ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerStartedLoad object:nil];
            
            CGRect tileRect = [self tileRectForScreen:screen 
                                           coordinate:coordinate 
                                            zoomLevel:self.zoomLevel];
            
            TTMapImage *mapImage = 
            [[TTMapImage alloc] initWithTileRect:tileRect
                                       zoomLevel:self.zoomLevel
                                          source:self.source
                                          effect:self.imageEffect
                                            logo:self.logoImage];
            
            [mapImage fetchTilesWithSuccess:^(NSURL *filePath) {
                [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerFinishedLoad object:nil];
                [[NSWorkspace sharedWorkspace] setDesktopImageURL:filePath 
                                                        forScreen:screen
                                                          options:nil
                                                            error:nil];
            } failure:^(NSError *error) {
                [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerFailedLoad object:nil];
                DDLogError(@"Error fetching image: %@", error);
            }];
        });
    }];
}

#pragma mark CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager 
    didUpdateToLocation:(CLLocation *)newLocation 
           fromLocation:(CLLocation *)oldLocation
{
    // throw away location updates older than two minutes
	if (newLocation && abs([newLocation.timestamp timeIntervalSinceNow]) < 120) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerLocationUpdated object:newLocation];
        lastSeenLocation = newLocation;
        [self updateMapToCoordinate:newLocation.coordinate];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if ([error code] == kCLErrorDenied) {
        [locationManager stopUpdatingLocation];
        [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerLocationPermissionDenied object:nil];
    }
}

// Returns a CGRect for the screen's tiles, given a centre coordinate and a zoom level
- (CGRect)tileRectForScreen:(NSScreen *)screen 
                 coordinate:(CLLocationCoordinate2D)coordinate 
                  zoomLevel:(unsigned short)z 
{
    // Find the centre tile
    CGPoint centerTile = [TTMapTile coordinateToPoint:coordinate zoomLevel:z];

    CGRect mainScreenFrame = [[NSScreen mainScreen] frame];
    CGRect targetScreenFrame = screen.frame;
    
    // Get the size and origin of the main screen in tiles
    float mainScreenTileHeight = NSHeight(mainScreenFrame)/TILE_SIZE;
    float mainScreenTileWidth = NSWidth(mainScreenFrame)/TILE_SIZE;
    float mainScreenTileOriginX = centerTile.x - mainScreenTileWidth/2;
    float mainScreenTileOriginY = centerTile.y + mainScreenTileHeight/2;
    
    // Calculate the size and origin of the target screen in tiles, offset from the main screen centre point
    float targetScreenTileHeight = NSHeight(targetScreenFrame)/TILE_SIZE;
    float targetScreenTileWidth = NSWidth(targetScreenFrame)/TILE_SIZE;
    float targetScreenTileOriginX = mainScreenTileOriginX + targetScreenFrame.origin.x/TILE_SIZE;
    float targetScreenTileOriginY = mainScreenTileOriginY - targetScreenFrame.origin.y/TILE_SIZE;
    
    return CGRectMake(targetScreenTileOriginX, targetScreenTileOriginY, targetScreenTileWidth, targetScreenTileHeight);
}

- (TTMapImageEffect)imageEffect {
    NSNumber *imageEffectNumber = [[NSUserDefaults standardUserDefaults] objectForKey:@"imageEffect"];
    return [imageEffectNumber intValue];
}

- (NSString *)source {
    return [self.selectedMapType objectForKey:@"source"];
}

- (NSImage *)logoImage {
    NSString *imageName = [self.selectedMapType objectForKey:@"logoImage"];
    if (imageName) {
        return [NSImage imageNamed:imageName];
    } else {
        return nil;
    }
}

- (short unsigned int)zoomLevel {
    NSNumber *maxZoom = [self.selectedMapType objectForKey:@"maxZoom"];
    NSNumber *minZoom = [self.selectedMapType objectForKey:@"minZoom"];
    NSNumber *desiredZoom = [[NSUserDefaults standardUserDefaults] objectForKey:@"zoomLevel"];
    int desiredZoomInt = [desiredZoom intValue];
    
    if (maxZoom && desiredZoomInt > [maxZoom intValue]) {
        desiredZoomInt = [maxZoom intValue];
    } else if (minZoom && desiredZoomInt < [minZoom intValue]) {
        desiredZoomInt = [minZoom intValue];
    }
    
    return desiredZoomInt;
}

- (NSDictionary *)selectedMapType {
    NSArray *mapTypes = [[NSUserDefaults standardUserDefaults] objectForKey:@"mapTypes"];
    NSNumber *selectedMapTypeIndex = [[NSUserDefaults standardUserDefaults] objectForKey:@"selectedMapTypeIndex"];
    
    int selectedMapTypeInt = [selectedMapTypeIndex intValue];
    if (selectedMapTypeInt < 0) {
        selectedMapTypeInt = 0;
    } else if (selectedMapTypeInt > [mapTypes count]-1) {
        selectedMapTypeInt = (int)[mapTypes count] - 1;
    }
    
    return [mapTypes objectAtIndex:selectedMapTypeInt];
}

// Flushes out old map images, leaving the currently displayed ones, and the last 20 modified.
- (void)cleanCache {
    NSString *cacheDirectoryPath = [[NSFileManager defaultManager] privateDataPath];
    
    NSError *error;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cacheDirectoryPath error:&error];
    if (error) {
        return;
    }

    // For each of the currently active screens, find the current wallpaper filename
    NSMutableArray *safeFiles = [NSMutableArray array];
    [[NSScreen screens] enumerateObjectsUsingBlock:^(NSScreen *screen, NSUInteger idx, BOOL *stop) {
        NSURL *desktopImageURL = [[NSWorkspace sharedWorkspace] desktopImageURLForScreen:screen];
        [safeFiles addObject:[desktopImageURL lastPathComponent]];
    }];
    
    // Find all the files which begin with map and aren't currently on the desktop
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(SELF BEGINSWITH[cd] %@) && NOT (SELF IN %@)", @"map", safeFiles];
    NSArray *filesToRemove = [files filteredArrayUsingPredicate:predicate];
    
    // Make an array of dictionaries with the modification date for each file
    NSMutableArray *filesAndProperties = [NSMutableArray arrayWithCapacity:[filesToRemove count]];
    [filesToRemove enumerateObjectsUsingBlock:^(NSString *file, NSUInteger idx, BOOL *stop) {
        NSString *filePath = [NSString pathWithComponents:[NSArray arrayWithObjects:cacheDirectoryPath, file, nil]];
        NSError *error;
        NSDictionary* properties = [[NSFileManager defaultManager]
                                    attributesOfItemAtPath:filePath
                                    error:&error];
        if (error)
            return;
        
        NSDate* modificationDate = [properties objectForKey:NSFileModificationDate];
        
        [filesAndProperties addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       filePath, @"filePath", 
                                       modificationDate, @"modificationDate",
                                       nil]];
    }];
    
    // Sort by most recent first
    NSArray *sortedFiles = [filesAndProperties sortedArrayUsingComparator:
                             ^(id path1, id path2) {
                                 NSComparisonResult comp = [[path1 objectForKey:@"modificationDate"] compare:
                                                            [path2 objectForKey:@"modificationDate"]];
                                 if (comp == NSOrderedDescending) {
                                     comp = NSOrderedAscending;
                                 }
                                 else if (comp == NSOrderedAscending) {
                                     comp = NSOrderedDescending;
                                 }
                                 return comp;                                
                             }];
    
    // Leave the 20 most recent, and delete the rest
    [sortedFiles enumerateObjectsUsingBlock:^(NSDictionary *fileDict, NSUInteger idx, BOOL *stop) {
        if (idx >= 20) {
            NSString *path = [fileDict objectForKey:@"filePath"];
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
            if (error) {
                return;
            }
        }
    }];
}

- (void)dealloc
{
    [reachability stopNotifier];
  
#if NEEDS_DISPATCH_RETAIN_RELEASE
    dispatch_release(updateQueue);
#endif
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"selectedMapTypeIndex"];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"zoomLevel"];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"imageEffect"];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

@end
