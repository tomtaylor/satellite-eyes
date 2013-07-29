//
//  TTAboutViewController.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 28/07/2013.
//
//

#import <Cocoa/Cocoa.h>

@interface TTAboutViewController : NSViewController {
    NSTextView *aboutTextView;
    NSTextField *versionTextField;
}

@property IBOutlet NSTextView *aboutTextView;
@property IBOutlet NSTextField *versionTextField;

@end
