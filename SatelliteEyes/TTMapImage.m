//
//  TTMapImage.m
//  SatelliteEyes
//
//  Created by Tom Taylor on 19/02/2012.
//  Copyright (c) 2012 Tom Taylor. All rights reserved.

#import "TTMapImage.h"
#import "TTMapTile.h"
#import "AFHTTPRequestOperation.h"
#import "MD5Digest.h"
#import "NSFileManager+StandardPaths.h"
#import <QuartzCore/QuartzCore.h>

@interface TTMapImage (Private)

- (NSURL *)writeImageData;
- (NSArray *)tilesArray;
- (NSString *)uniqueHash;

@end

@implementation TTMapImage

- (id)initWithTileRect:(CGRect)_tileRect 
             zoomLevel:(unsigned short)_zoomLevel
                source:(NSString *)_source
                effect:(TTMapImageEffect)_effect
                  logo:(NSImage *)_logoImage
{
    self = [super init];
    if (self) {
        tileRect = _tileRect;
        zoomLevel = _zoomLevel;
        imageEffect = _effect;
        source = _source;
        logoImage = _logoImage;

        // calculate the offset of the tiles on the final image
        float dummy; // throw away variable for catching the int component
        int shiftX = floor(modff(tileRect.origin.x, &dummy) * TILE_SIZE);
        int shiftY = TILE_SIZE - floor(modff(tileRect.origin.y, &dummy) * TILE_SIZE);
        pixelShift = CGPointMake(shiftX, shiftY);
        
        tiles = [self tilesArray];
        
        tileQueue = [[NSOperationQueue alloc] init];
        [tileQueue setMaxConcurrentOperationCount:4];
    }
    return self;
}

// Returns the array of tiles for the bounds of the image
- (NSArray *)tilesArray {
    NSMutableArray *array = [NSMutableArray array];
    
    int bottomY = floor(tileRect.origin.y);
    int topY = floor(tileRect.origin.y - tileRect.size.height);
    int leftX = floor(tileRect.origin.x);
    int rightX = floor(tileRect.origin.x + tileRect.size.width);
    
    int currentY = bottomY;
    
    while (currentY >= topY) {
        int currentX = leftX;
        NSMutableArray *rowArray = [NSMutableArray array];
        while (currentX <= rightX) {
            TTMapTile *mapTile = [[TTMapTile alloc] initWithSource:source x:currentX y:currentY z:zoomLevel];
            [rowArray addObject:mapTile];            
            currentX++;
        }
        [array addObject:rowArray];
        currentY--;
    }
    
    return array;
}

- (void)fetchTilesWithSuccess:(void (^)(NSURL *filePath))success
                      failure:(void (^)(NSError *error))failure
                    skipCache:(BOOL)skipCache
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^(void) {
        
        NSURL *fileURL = [self fileURL];

        if (!skipCache) {
            // callback instantly if the image already exists
            DDLogInfo(@"Looking up file at: %@", [fileURL path]);
            if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]]) {
                DDLogInfo(@"Map image already cached: %@", [fileURL path]);
                success(fileURL);
                return;
            }
        }
        
        DDLogInfo(@"Not found, or skipping cache, so fetching file at: %@", [fileURL path]);
        
        __block NSError *error;
        [tiles enumerateObjectsUsingBlock:^(NSArray *rowArray, NSUInteger idx, BOOL *stop) {
            [rowArray enumerateObjectsUsingBlock:^(TTMapTile *mapTile, NSUInteger rowIndex, BOOL *rowStop) {
                AFHTTPRequestOperation *httpOperation = [[AFHTTPRequestOperation alloc] initWithRequest:[mapTile urlRequest]];
                [httpOperation setAcceptableStatusCodes:[NSIndexSet indexSetWithIndex:200]];
                [httpOperation setAcceptableContentTypes:[NSSet setWithObjects:@"image/jpeg", @"image/png", @"image/jpg", nil]];
                
                [httpOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, NSData *responseData) {
                    mapTile.imageData = responseData;
                } failure:^(AFHTTPRequestOperation *operation, NSError *_error) {
                    error = _error;
                    DDLogError(@"Fetching tile error: %@", error);
                }];
                [tileQueue addOperation:httpOperation];
            }];
        }];
        [tileQueue waitUntilAllOperationsAreFinished];
        
        if (error) {
            failure(error);
        } else {
            NSURL *fileURL = [self writeImageData];
            success(fileURL);
        }
    });
}

- (NSURL *)writeImageData {
    CGFloat width = floor(tileRect.size.width * TILE_SIZE);
    CGFloat height = floor(tileRect.size.height * TILE_SIZE);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    size_t bitsPerComponent = 8;
    size_t bytesPerPixel    = 4;
    size_t bytesPerRow      = (width * bitsPerComponent * bytesPerPixel + 7) / 8;
    size_t dataSize         = bytesPerRow * height;
    
    unsigned char *data = malloc(dataSize);
    memset(data, 0, dataSize);
    
    CGContextRef context = CGBitmapContextCreate(data, width, height, 
                                                 bitsPerComponent, 
                                                 bytesPerRow, colorSpace, 
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    [tiles enumerateObjectsUsingBlock:^(NSArray *rowArray, NSUInteger rowIndex, BOOL *rowStop) {
        [rowArray enumerateObjectsUsingBlock:^(TTMapTile *tile, NSUInteger tileIndex, BOOL *tileStop) {
            CGImageRef tileImageRef = [tile newImageRef];
            
            float drawX = (tileIndex * TILE_SIZE) - pixelShift.x;
            float drawY = ((rowIndex * TILE_SIZE)) - pixelShift.y;
            CGRect rect = CGRectMake(drawX, drawY, TILE_SIZE, TILE_SIZE);
            CGContextDrawImage(context, rect, tileImageRef);
            CGImageRelease(tileImageRef);
        }];
    }];
    
    CGColorSpaceRelease(colorSpace);
    
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    
    CIContext *coreImageContext = [CIContext contextWithCGContext:context options:nil];
    
    CIImage *coreImageInput = [CIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    CIImage *coreImageOutput;
    
    switch (imageEffect) {
        case TTPixellateImageEffect: {
            CIFilter *pixellateFilter = [CIFilter filterWithName:@"CIPixellate"];
            [pixellateFilter setDefaults];
            [pixellateFilter setValue:coreImageInput forKey:@"inputImage"];
            [pixellateFilter setValue:[NSNumber numberWithFloat:8]
                               forKey:@"inputScale"];
            coreImageOutput = [pixellateFilter valueForKey: @"outputImage"];
            break;
        }
        case TTDotScreenImageEffect: {
            CIFilter *dotScreenFilter = [CIFilter filterWithName:@"CIDotScreen"];
            [dotScreenFilter setDefaults];
            [dotScreenFilter setValue:coreImageInput forKey:@"inputImage"];
            [dotScreenFilter setValue:[NSNumber numberWithFloat:2]
                               forKey:@"inputWidth"];
            coreImageOutput = [dotScreenFilter valueForKey:@"outputImage"];
            break;
        }
        default:
            coreImageOutput = coreImageInput;
            break;
    }
    
    CGImageRef tiledImageRef = [coreImageContext createCGImage:coreImageOutput fromRect:coreImageOutput.extent];
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), tiledImageRef);
    CGImageRelease(tiledImageRef);
    
    if (logoImage) {
        CGImageSourceRef logoImageSourceRef = CGImageSourceCreateWithData((__bridge CFDataRef)[logoImage TIFFRepresentation], NULL);
        CGImageRef logoImageRef =  CGImageSourceCreateImageAtIndex(logoImageSourceRef, 0, NULL);
        CFRelease(logoImageSourceRef);
        
        float margin = 10;
        float drawX = width - CGImageGetWidth(logoImageRef) - margin;
        float drawY = margin;

        CGRect drawRect = CGRectMake(drawX, drawY, CGImageGetWidth(logoImageRef), CGImageGetHeight(logoImageRef));
        CGContextDrawImage(context, drawRect, logoImageRef);
        CGImageRelease(logoImageRef);
    }
    
    CGImageRef finalImageRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);

    // bake out to a file
    NSURL *fileURL = [self fileURL];
    CFURLRef url = (__bridge CFURLRef)fileURL;
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(destination, finalImageRef, nil);
    CGImageRelease(finalImageRef);
    
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
    
    free(data);
    
    return fileURL;
}

// Returns a hash that keys the map details
- (NSString *)uniqueHash {
    NSString *key = [NSString stringWithFormat:@"%@_%.1f_%.1f_%.2f_%.2f_%u_%u", 
                     source,
                     tileRect.origin.x,
                     tileRect.origin.y,
                     tileRect.size.width,
                     tileRect.size.height,
                     imageEffect,
                     zoomLevel];
    return [key md5Digest];
}

- (NSURL *)fileURL {
    NSString *fileName = [NSString stringWithFormat:@"map-%@.png", [self uniqueHash]];
    NSString *path = [[NSFileManager defaultManager] pathForPrivateFile:fileName];
    return [NSURL fileURLWithPath:path];
}

@end
