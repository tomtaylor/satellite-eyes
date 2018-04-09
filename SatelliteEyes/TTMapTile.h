//
//  TTMapTile.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 19/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface TTMapTile : NSObject <NSConnectionDelegate> {
    NSUInteger x;
    NSUInteger y;
    unsigned short z;
    NSData *imageData;
    NSString *source;
}

@property (readonly) NSString *source;
@property (readonly) NSUInteger x;
@property (readonly) NSUInteger y;
@property (readonly) unsigned short z;
@property (atomic, retain) NSData *imageData;

- (instancetype)initWithSource:(NSString *)source 
                   x:(NSUInteger)_x 
                   y:(NSUInteger)_y 
                   z:(unsigned short)_z NS_DESIGNATED_INITIALIZER;
@property (NS_NONATOMIC_IOSONLY, readonly) CLLocationCoordinate2D topLeftCoordinate;
@property (NS_NONATOMIC_IOSONLY, readonly) CGImageRef newImageRef CF_RETURNS_RETAINED;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSURL *url;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSURLRequest *urlRequest;

+ (CLLocationCoordinate2D)coordinateForX:(NSUInteger)x y:(NSUInteger)y z:(unsigned short)z;
+ (CGPoint)coordinateToPoint:(CLLocationCoordinate2D)coordinate zoomLevel:(unsigned short)zoomLevel;
+ (double)latitudeToY:(CLLocationDegrees)latitude zoomLevel:(unsigned short)zoomLevel;
+ (double)longitudeToX:(CLLocationDegrees)longitude zoomLevel:(unsigned short)zoomLevel;
+ (TTMapTile *)tileForCoordinate:(CLLocationCoordinate2D)coordinate 
                          source:(NSString *)source 
                       zoomLevel:(unsigned short)zoomLevel;

@end
