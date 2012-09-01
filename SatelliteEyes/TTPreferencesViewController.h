//
//  PreferencesViewController.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 27/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface TTPreferencesViewController : NSViewController <NSTextFieldDelegate> {
    WebView *aboutView;
}

@property (nonatomic) BOOL startAtLogin;
@property (nonatomic, retain) IBOutlet WebView *aboutView;
@property (nonatomic, strong) IBOutlet NSTextField *urlTextField;

@end
