//
//  LLManager.m
//  LaunchAtLogin
//
//  Created by David Keegan on 4/20/12.
//  Copyright (c) 2012 David Keegan.
//  Copyright (c) 2014 Jan Weiß.
//  Some rights reserved: <http://opensource.org/licenses/mit-license.php>
//

#import "LLManager.h"
#import "LLStrings.h"
#import <ServiceManagement/ServiceManagement.h>


NSString * const    LLManagerSetLaunchAtLoginFailedNotification        = @"LLManagerSetLaunchAtLoginFailedNotification";


@implementation LLManager

+ (BOOL)launchAtLogin{
    BOOL launch = NO;
    CFArrayRef cfJobs = SMCopyAllJobDictionaries(kSMDomainUserLaunchd);
    if(cfJobs == NULL)  return NO;
#if __has_feature(objc_arc)
    NSArray *jobs = CFBridgingRelease(cfJobs);
#else    
    NSArray *jobs = [NSArray arrayWithArray:(NSArray *)cfJobs];
    CFRelease(cfJobs);
#endif
    if([jobs count]){
        for(NSDictionary *job in jobs){
            if([job[@"Label"] isEqualToString:LLHelperBundleIdentifier]){
                launch = [job[@"OnDemand"] boolValue];
                break;
            }
        }
    }   
    return launch;  
}

+ (void)setLaunchAtLogin:(BOOL)value {
    [self setLaunchAtLogin:value
           notifyOnFailure:NO];
}

+ (void)setLaunchAtLogin:(BOOL)value
         notifyOnFailure:(BOOL)wantFailureNotification {
#if __has_feature(objc_arc)
    CFStringRef LLHelperBundleIdentifierCF = (__bridge CFStringRef)LLHelperBundleIdentifier;
#else
    CFStringRef LLHelperBundleIdentifierCF = (CFStringRef)LLHelperBundleIdentifier;
#endif
    
    if(!SMLoginItemSetEnabled(LLHelperBundleIdentifierCF, value)){
        if(wantFailureNotification){
            [[NSNotificationCenter defaultCenter] postNotificationName:LLManagerSetLaunchAtLoginFailedNotification object:self];
        }
        else {
            NSLog(@"SMLoginItemSetEnabled failed!");
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
