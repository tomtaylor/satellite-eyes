//
//  PreferencesViewController.m
//  SatelliteEyes
//
//  Created by Tom Taylor on 27/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TTPreferencesViewController.h"
#import "TTMapWindowController.h"
#import "LLManager.h"

@implementation TTPreferencesViewController

@synthesize startAtLogin;
@synthesize aboutView;
@synthesize mapWindowController;

- (void)awakeFromNib {
    self.startAtLogin = [LLManager launchAtLogin];
    self.mapWindowController = [[TTMapWindowController alloc] init];
    
    if (aboutView) {
        aboutView.policyDelegate = self;
        aboutView.drawsBackground = NO;
        NSString *aboutHTMLPath = [[NSBundle mainBundle] pathForResource:@"About" ofType:@"html"];
        NSURL *aboutHTMLURL = [NSURL fileURLWithPath:aboutHTMLPath];
        NSURLRequest* request = [NSURLRequest requestWithURL:aboutHTMLURL];
        [[aboutView mainFrame] loadRequest:request];
        [aboutView setNeedsDisplay:YES];
    }
}

- (BOOL)startAtLogin {
    return [LLManager launchAtLogin];
}

- (void)setStartAtLogin:(BOOL)enabled {
    [self willChangeValueForKey:@"startAtLogin"];
    [LLManager setLaunchAtLogin:enabled];
    [self didChangeValueForKey:@"startAtLogin"];
}

- (void)webView:(WebView *)webView 
decidePolicyForNavigationAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request 
          frame:(WebFrame *)frame 
decisionListener:(id <WebPolicyDecisionListener>)listener
{
    if ([actionInformation objectForKey:WebActionElementKey]) {
        [listener ignore];
        [[NSWorkspace sharedWorkspace] openURL:[request URL]];
    }
    else {
        [listener use];
    }
}

- (IBAction)showMapAction:(id)sender
{
    [self.mapWindowController.window makeKeyAndOrderFront:self];
}

@end
