//
//  LLAppDelegate.h
//  LaunchAtLoginSample
//
//  Created by David Keegan on 4/20/12.
//  Copyright (c) 2012 David Keegan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LLAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSButton *checkBox;

- (IBAction)checkBoxAction:(id)sender;

@end
