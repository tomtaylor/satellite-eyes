//
//  LLManager.m
//  LaunchAtLogin
//
//  Created by David Keegan on 4/20/12.
//  Copyright (c) 2012 David Keegan. All rights reserved.
//

#import "LLManager.h"
#import "LLStrings.h"
#import <ServiceManagement/ServiceManagement.h>

@implementation LLManager

+ (BOOL)launchAtLogin{
    BOOL launch = NO;
    CFArrayRef cfJobs = SMCopyAllJobDictionaries(kSMDomainUserLaunchd);
#if __has_feature(objc_arc)
    NSArray *jobs = [NSArray arrayWithArray:(__bridge NSArray *)cfJobs];
#else    
    NSArray *jobs = [NSArray arrayWithArray:(NSArray *)cfJobs];
#endif
    CFRelease(cfJobs);
    if([jobs count]){
        for(NSDictionary *job in jobs){
            if([[job objectForKey:@"Label"] isEqualToString:LLHelperBundleIdentifier]){
                launch = [[job objectForKey:@"OnDemand"] boolValue];
                break;
            }
        }
    }   
    return launch;  
}

+ (void)setLaunchAtLogin:(BOOL)value{
    if(!SMLoginItemSetEnabled((CFStringRef)LLHelperBundleIdentifier, value)){
        NSLog(@"SMLoginItemSetEnabled failed!");
    }
}

@end
