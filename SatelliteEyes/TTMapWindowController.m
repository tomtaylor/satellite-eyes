//
//  TTMapWindowController.m
//  SatelliteEyes
//
//  Created by Sam Grover on 9/3/12.
//
//

#import "TTMapWindowController.h"

@implementation TTMapWindowController

@synthesize mapView;

- (id)init
{
    self = [super initWithWindowNibName:@"TTMapWindow"];
    return self;
}

- (void)windowDidLoad
{
    [self resetToManualCoords];
}

#pragma mark - Helpers

- (void)saveManualCoords
{
    NSDictionary *manualCoords = @{
    @"latitude" : [NSNumber numberWithDouble:self.mapView.centerCoordinate.latitude],
    @"longitude" : [NSNumber numberWithDouble:self.mapView.centerCoordinate.longitude] };
    [[NSUserDefaults standardUserDefaults] setObject:manualCoords forKey:@"manualCoordinates"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)resetToManualCoords
{
    NSDictionary *manualCoords = [[NSUserDefaults standardUserDefaults] objectForKey:@"manualCoordinates"];
    [self.mapView setCenterCoordinate:CLLocationCoordinate2DMake([manualCoords[@"latitude"] doubleValue], [manualCoords[@"longitude"] doubleValue])];
}

#pragma mark - Actions

- (IBAction)doneAction:(id)sender
{
    [self saveManualCoords];
    [self close];
}

- (IBAction)cancelAction:(id)sender
{
    [self resetToManualCoords];
    [self close];
}

@end
