//
//  TTMapTile.m
//  SatelliteEyes
//
//  Created by Tom Taylor on 19/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TTMapTile.h"

@implementation TTMapTile

@synthesize source;
@synthesize x;
@synthesize y;
@synthesize z;
@synthesize imageData;

- (id)initWithSource:(NSString *)_source x:(NSUInteger)_x y:(NSUInteger)_y z:(unsigned short)_z
{
    self = [super init];
    if (self) {
        source = _source;
        x = _x;
        y = _y;
        z = _z;
    }
    return self;
}

- (CLLocationCoordinate2D)topLeftCoordinate
{
    return [TTMapTile coordinateForX:x y:y z:z];
}

- (NSURLRequest *)urlRequest {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url]
                                 cachePolicy:NSURLRequestUseProtocolCachePolicy 
                             timeoutInterval:60.0];
    
    NSString *version = [[NSBundle mainBundle] infoDictionary][(NSString*)kCFBundleVersionKey];
    NSString *userAgent = [NSString stringWithFormat:@"Satellite Eyes/%@ (http://satelliteeyes.tomtaylor.co.uk)", version];
    
    [request addValue:userAgent forHTTPHeaderField:@"User-Agent"];
    return request;
}

- (CGImageRef)newImageRef {
    if (imageData) {
        CFDataRef imageDataRef = (__bridge CFDataRef)imageData;
        CGDataProviderRef provider = CGDataProviderCreateWithCFData(imageDataRef);
        
        // Try JPEG first, otherwise fall back to PNG
        CGImageRef image = CGImageCreateWithJPEGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
        if (image == NULL) {
            image = CGImageCreateWithPNGDataProvider(provider, NULL, NO, 0);
        }
        
        CGDataProviderRelease(provider);
        return image;
    } else {
        return nil;
    }
}

- (NSURL *)url {
    NSString *urlString = self.source;
    urlString = [urlString stringByReplacingOccurrencesOfString:@"{x}" 
                                                     withString:[NSString stringWithFormat:@"%li", x]];
    
    urlString = [urlString stringByReplacingOccurrencesOfString:@"{y}" 
                                                     withString:[NSString stringWithFormat:@"%li", y]];

    urlString = [urlString stringByReplacingOccurrencesOfString:@"{z}" 
                                                     withString:[NSString stringWithFormat:@"%i", z]];
    
    urlString = [urlString stringByReplacingOccurrencesOfString:@"{q}" 
                                                     withString:[self quadKey]];
    
    return [NSURL URLWithString:urlString];
}

- (NSString *)quadKey {
    NSMutableString *quadKey = [NSMutableString string];
	for (int i = z; i > 0; i--)
	{
		int mask = 1 << (i - 1);
		int cell = 0;
		if ((x & mask) != 0)
		{
			cell++;
		}
		if ((y & mask) != 0)
		{
			cell += 2;
		}
		[quadKey appendString:[NSString stringWithFormat:@"%d", cell]];
	}
    return quadKey;
}

#pragma mark Class methods

+ (CLLocationCoordinate2D)coordinateForX:(NSUInteger)x y:(NSUInteger)y z:(unsigned short)z
{
    CLLocationDegrees longitude = x / pow(2.0, z) * 360.0 - 180;
    
    double n = M_PI - 2.0 * M_PI * y / pow(2.0, z);
	CLLocationDegrees latitude = 180.0 / M_PI * atan(0.5 * (exp(n) - exp(-n)));
    
    return CLLocationCoordinate2DMake(latitude, longitude);
}

+ (TTMapTile *)tileForCoordinate:(CLLocationCoordinate2D)coordinate 
                          source:(NSString *)source 
                       zoomLevel:(unsigned short)zoomLevel
{
    CLLocationDegrees latitude = coordinate.latitude;
    CLLocationDegrees longitude = coordinate.longitude;
    
    NSInteger y = floor([TTMapTile latitudeToY:latitude zoomLevel:zoomLevel]);
    NSInteger x = floor([TTMapTile longitudeToX:longitude zoomLevel:zoomLevel]);
    
    TTMapTile *mapTile = [[TTMapTile alloc] initWithSource:source x:x y:y z:zoomLevel];
    return mapTile;
}

+ (CGPoint)coordinateToPoint:(CLLocationCoordinate2D)coordinate zoomLevel:(unsigned short)zoomLevel {
    double y = [TTMapTile latitudeToY:coordinate.latitude zoomLevel:zoomLevel];
    double x = [TTMapTile longitudeToX:coordinate.longitude zoomLevel:zoomLevel];
    return CGPointMake(x, y);
}

+ (double)latitudeToY:(CLLocationDegrees)latitude zoomLevel:(unsigned short)zoomLevel {
    double y = (1.0 - log(tan(latitude * M_PI/180.0) + 1.0 / cos(latitude * M_PI/180.0)) / M_PI) / 2.0 * pow(2.0, zoomLevel);
    return y;
}

+ (double)longitudeToX:(CLLocationDegrees)longitude zoomLevel:(unsigned short)zoomLevel {
    double x = (longitude + 180.0) / 360.0 * pow(2.0, zoomLevel);
    return x;
}

@end
