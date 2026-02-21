//
//  LLManager.m
//  LaunchAtLogin
//
//  Created by David Keegan on 4/20/12.
//  Copyright (c) 2012 David Keegan.
//  Some rights reserved: <http://opensource.org/licenses/mit-license.php>
//

#import "LLManager.h"
#import <ServiceManagement/ServiceManagement.h>


NSString * const LLManagerSetLaunchAtLoginFailedNotification = @"LLManagerSetLaunchAtLoginFailedNotification";


@implementation LLManager

+ (BOOL)launchAtLogin {
    if (@available(macOS 13.0, *)) {
        return SMAppService.mainAppService.status == SMAppServiceStatusEnabled;
    }
    return NO;
}

+ (void)setLaunchAtLogin:(BOOL)value {
    [self setLaunchAtLogin:value notifyOnFailure:NO];
}

+ (void)setLaunchAtLogin:(BOOL)value
         notifyOnFailure:(BOOL)wantFailureNotification {
    if (@available(macOS 13.0, *)) {
        NSError *error = nil;
        if (value) {
            [SMAppService.mainAppService registerAndReturnError:&error];
        } else {
            [SMAppService.mainAppService unregisterAndReturnError:&error];
        }
        if (error) {
            if (wantFailureNotification) {
                [[NSNotificationCenter defaultCenter] postNotificationName:LLManagerSetLaunchAtLoginFailedNotification object:self];
            } else {
                NSLog(@"SMAppService register/unregister failed: %@", error);
            }
        }
    }
}

#pragma mark - Bindings support

- (BOOL)launchAtLogin {
    return [[self class] launchAtLogin];
}

- (void)setLaunchAtLogin:(BOOL)launchAtLogin {
    [self willChangeValueForKey:@"launchAtLogin"];
    [[self class] setLaunchAtLogin:launchAtLogin
                   notifyOnFailure:self.notifyIfSetLaunchAtLoginFailed];
    [self didChangeValueForKey:@"launchAtLogin"];
}

@end
