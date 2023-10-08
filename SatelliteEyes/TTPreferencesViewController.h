//
//  PreferencesViewController.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 27/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TTManageMapStylesWindowController.h"
#import "TTPreferencesHelpWindowController.h"

@interface TTPreferencesViewController : NSViewController <NSTextFieldDelegate>

@property (nonatomic) BOOL startAtLogin;
@property (strong) TTManageMapStylesWindowController *manageMapStylesWindowController;
@property (strong) TTPreferencesHelpWindowController *helpWindowController;

- (IBAction)showManageMapStyles:(id)sender;
@property (weak) IBOutlet NSPopUpButton *selectableMapTypes;
@property (weak) IBOutlet NSTextField *stadiaTokenTextField;

@end
