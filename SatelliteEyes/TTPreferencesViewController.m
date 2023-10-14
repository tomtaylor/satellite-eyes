//
//  PreferencesViewController.m
//  SatelliteEyes
//
//  Created by Tom Taylor on 27/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TTPreferencesViewController.h"
#import "LLManager.h"
#import "TTMapManager.h"

@implementation TTPreferencesViewController

@synthesize startAtLogin;
@synthesize manageMapStylesWindowController;
@synthesize helpWindowController;
@synthesize stadiaTokenTextField;
@synthesize mapTypesMenu;

- (void)awakeFromNib {
    self.startAtLogin = [LLManager launchAtLogin];
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"stadiaToken"
                                               options:NSKeyValueObservingOptionNew
                                               context:nil];
    [self refreshAvailableMapTypes];
}

- (BOOL)startAtLogin {
    return [LLManager launchAtLogin];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self refreshAvailableMapTypes];
}

- (void) refreshAvailableMapTypes {
    [mapTypesMenu removeAllItems];
    NSDictionary *mapTypes = [[NSUserDefaults standardUserDefaults] objectForKey:@"mapTypes"];
    NSEnumerator *objectEnumerator = [mapTypes objectEnumerator];
    NSDictionary *mapType;

    while ((mapType = [objectEnumerator nextObject])) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:mapType[@"name"] action:nil keyEquivalent:@""];
        [item setRepresentedObject:mapType[@"id"]];
        NSString *apiKeyDefaultsKey = mapType[@"apiKeyDefaultsKey"];

        if (apiKeyDefaultsKey == nil) {
            [mapTypesMenu addItem:item];
            continue;
        }

        NSString *apiKey = [[NSUserDefaults standardUserDefaults] stringForKey:apiKeyDefaultsKey];
        if ([apiKey length] > 0) {
            [mapTypesMenu addItem:item];
        }
    }

    NSString *selectedMapType = [[NSUserDefaults standardUserDefaults ] stringForKey:@"selectedMapTypeId"];
    [mapTypesMenu performActionForItemAtIndex:[mapTypesMenu indexOfItemWithRepresentedObject:selectedMapType]];

}

- (void)setStartAtLogin:(BOOL)enabled {
    [self willChangeValueForKey:@"startAtLogin"];
    [LLManager setLaunchAtLogin:enabled];
    [self didChangeValueForKey:@"startAtLogin"];
}

- (IBAction)mapTypeSelected:(NSPopUpButton *)sender {
    NSString *_Nullable newSelectedMapTypeId = [[sender selectedItem] representedObject];
    DDLogInfo(@"Selected %@", newSelectedMapTypeId);
    [[NSUserDefaults standardUserDefaults] setObject:newSelectedMapTypeId forKey:@"selectedMapTypeId"];
}

- (IBAction)showManageMapStyles:(id)sender {
    self.manageMapStylesWindowController = [[TTManageMapStylesWindowController alloc] init];
    [manageMapStylesWindowController showWindow:self];
    [manageMapStylesWindowController.window makeKeyAndOrderFront:self];
    [manageMapStylesWindowController.window makeFirstResponder:nil];
}

- (IBAction)showPreferencesHelp:(id)sender {
    self.helpWindowController = [[TTPreferencesHelpWindowController alloc] init];
    [helpWindowController showWindow:self];
    [helpWindowController.window makeKeyAndOrderFront:self];
    [helpWindowController.window makeFirstResponder:nil];
}

@end
