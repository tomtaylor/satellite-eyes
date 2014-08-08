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
    NSUInteger tileSize;
    unsigned short zoomLevel;
    NSString *source;
    NSDictionary *imageEffect;
    NSArray *tiles;
    CGPoint pixelShift;
    NSOperationQueue *tileQueue;
    NSImage *logoImage;
}

- (id)initWithTileRect:(CGRect)_tileRect
              tileSize:(NSUInteger)_tileSize
             zoomLevel:(unsigned short)_zoomLevel
                source:(NSString *)_provider
                effect:(NSDictionary *)_effect
                  logo:(NSImage *)logoImage;

- (void)fetchTilesWithSuccess:(void (^)(NSURL *filePath))success
                      failure:(void (^)(NSError *error))failure
                    skipCache:(BOOL)skipCache;

- (NSURL *)fileURL;

@end