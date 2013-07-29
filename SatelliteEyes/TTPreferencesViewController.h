//
//  PreferencesViewController.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 27/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TTManageMapStylesWindowController.h"

@interface TTPreferencesViewController : NSViewController <NSTextFieldDelegate>

@property (nonatomic) BOOL startAtLogin;
@property (strong) TTManageMapStylesWindowController *manageMapStylesWindowController;

- (IBAction)showManageMapStyles:(id)sender;

@end
