//
//  TTMapTypesArrayController.m
//  SatelliteEyes
//
//  Created by Ezra Spier on 6/22/13.
//
//

#import "TTMapTypesArrayController.h"

@implementation TTMapTypesArrayController

- (id)newObject {
    return @{@"id": [[NSUUID UUID] UUIDString], @"mapZoom": @17, @"name": @"New Map Style"};
}

@end
