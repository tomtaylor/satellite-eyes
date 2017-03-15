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

#define BASE_TILE_SIZE 256

@interface TTMapImage (Private)

- (NSURL *)writeImageData;
- (NSArray *)tilesArray;
- (NSString *)uniqueHash;

@end

@implementation TTMapImage

+ (void)load {
    [AFHTTPRequestOperation addAcceptableContentTypes:[NSSet setWithObjects:@"image/jpeg", @"image/png", @"image/jpg", nil]];
}

- (id)initWithTileRect:(CGRect)_tileRect
             tileScale:(float)_tileScale
             zoomLevel:(unsigned short)_zoomLevel
                source:(NSString *)_source
                effect:(NSDictionary *)_effect
                  logo:(NSImage *)_logoImage
{
    self = [super init];
    if (self) {
        tileRect = _tileRect;
        tileScale = _tileScale;
        zoomLevel = _zoomLevel;
        imageEffect = _effect;
        source = _source;
        logoImage = _logoImage;

        tileSize = BASE_TILE_SIZE * tileScale;

        // calculate the offset of the tiles on the final image
        float dummy; // throw away variable for catching the int component
        int shiftX = floor(modff(tileRect.origin.x, &dummy) * tileSize);
        int shiftY = tileSize - floor(modff(tileRect.origin.y, &dummy) * tileSize);
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
    CGFloat width = floor(tileRect.size.width * tileSize);
    CGFloat height = floor(tileRect.size.height * tileSize);
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
            
            float drawX = (tileIndex * tileSize) - pixelShift.x;
            float drawY = (rowIndex * tileSize) - pixelShift.y;
            CGRect rect = CGRectMake(drawX, drawY, tileSize, tileSize);
            CGContextDrawImage(context, rect, tileImageRef);
            CGImageRelease(tileImageRef);
        }];
    }];
    
    CGColorSpaceRelease(colorSpace);
    
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    
    CIContext *coreImageContext = [CIContext contextWithCGContext:context options:nil];
    
    CIImage *coreImageInput = [CIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    __block CIImage *coreImageOutput = coreImageInput;
    
    // use an affine clamp so "gloom" and "gaussian blur" type filters work
    if (! [[imageEffect objectForKey:@"disableAffineClamp"] boolValue]) {
        CGAffineTransform transform = CGAffineTransformIdentity;
        CIFilter *clampFilter = [CIFilter filterWithName:@"CIAffineClamp"];
        [clampFilter setDefaults];
        [clampFilter setValue:coreImageInput forKey:@"inputImage"];
        [clampFilter setValue:[NSValue valueWithBytes:&transform
                                             objCType:@encode(CGAffineTransform)]
                       forKey:@"inputTransform"];
        coreImageOutput = [clampFilter valueForKey:@"outputImage"];
    }
    
    // iterate through filters, applying each...
    NSArray *filters = [imageEffect valueForKey:@"filters"];
    [filters enumerateObjectsUsingBlock:^(NSDictionary *filter, NSUInteger filterIndex, BOOL *stop) {
        CIFilter *imageFilter = [CIFilter filterWithName:[filter valueForKey:@"name"]];
        [imageFilter setDefaults];
        [imageFilter setValue:coreImageOutput forKey:@"inputImage"];
        
        NSArray *parameters = [filter valueForKey:@"parameters"];
        [parameters enumerateObjectsUsingBlock:^(NSDictionary *parameter, NSUInteger filterIndex, BOOL *stop) {
            id value = parameter[@"value"];
            id name = parameter[@"name"];
            value = [self scaledFilterValue:value key:name];

            [imageFilter setValue:value
                           forKey:[parameter valueForKey:@"name"]];
        }];
        
        coreImageOutput = [imageFilter valueForKey:@"outputImage"];
    }];
    
    CGImageRef tiledImageRef = [coreImageContext createCGImage:coreImageOutput fromRect:coreImageInput.extent];
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
    NSString *key = [NSString stringWithFormat:@"%@_%.1f_%.1f_%.2f_%.2f_%.2f_%@_%u",
                     source,
                     tileRect.origin.x,
                     tileRect.origin.y,
                     tileRect.size.width,
                     tileRect.size.height,
                     tileScale,
                     imageEffect,
                     zoomLevel];
    return [key md5Digest];
}

- (NSURL *)fileURL {
    NSString *fileName = [NSString stringWithFormat:@"map-%@.png", [self uniqueHash]];
    NSString *path = [[NSFileManager defaultManager] pathForPrivateFile:fileName];
    return [NSURL fileURLWithPath:path];
}

// Some filter values (widths, radiuses, etc.) should be scaled up for retina devices
- (id)scaledFilterValue:(id)value key:(id)key {
    if ([@[kCIInputRadiusKey, kCIInputScaleKey, kCIInputWidthKey] containsObject:key]) {
        NSNumber *number = value;
        return @(number.floatValue * tileScale);
    } else if ([value isKindOfClass:[NSDictionary class]] && [@[kCIInputColorKey, @"inputColor0", @"inputColor1"] containsObject:key]) {
        NSDictionary *dictionary = value;
        CGFloat alpha = (nil != dictionary[@"alpha"]) ? [dictionary[@"alpha"] doubleValue] : 1.0;
        return [CIColor colorWithRed:[dictionary[@"red"] doubleValue]
                               green:[dictionary[@"green"] doubleValue]
                                blue:[dictionary[@"blue"] doubleValue]
                               alpha:alpha];
    } else {
        return value;
    }
}

@end
