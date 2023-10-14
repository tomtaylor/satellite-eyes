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
- (IBAction)mapTypeSelected:(NSPopUpButton *)sender;
@property (weak) IBOutlet NSTextField *stadiaTokenTextField;
@property (weak) IBOutlet NSMenu *mapTypesMenu;

@end
