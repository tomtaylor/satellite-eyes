//
//  TTMapImage.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 19/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface TTMapImage : NSObject {
    CGRect tileRect;
    float tileScale;
    unsigned short zoomLevel;
    NSString *source;
    NSDictionary *imageEffect;
    NSArray *tiles;
    CGPoint pixelShift;
    NSOperationQueue *tileQueue;
    NSImage *logoImage;
    NSUInteger tileSize;
}

- (instancetype)initWithTileRect:(CGRect)_tileRect
             tileScale:(float)_tileScale
             zoomLevel:(unsigned short)_zoomLevel
                source:(NSString *)_provider
                effect:(NSDictionary *)_effect
                  logo:(NSImage *)_logoImage NS_DESIGNATED_INITIALIZER;

- (void)fetchTilesWithSuccess:(void (^)(NSURL *filePath))success
                      failure:(void (^)(NSError *error, NSInteger statusCode))failure
                    skipCache:(BOOL)skipCache;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSURL *fileURL;

@end
