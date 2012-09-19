//
//  TTMapWindowController.h
//  SatelliteEyes
//
//  Created by Sam Grover on 9/3/12.
//
//

#import <Cocoa/Cocoa.h>

@interface TTMapWindowController : NSWindowController

@property (nonatomic, strong) IBOutlet MKMapView *mapView;

- (IBAction)doneAction:(id)sender;
- (IBAction)cancelAction:(id)sender;

@end
