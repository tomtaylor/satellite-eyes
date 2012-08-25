//
//  LLManager.h
//  LaunchAtLogin
//
//  Created by David Keegan on 4/20/12.
//  Copyright (c) 2012 David Keegan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LLManager : NSObject

+ (BOOL)launchAtLogin;
+ (void)setLaunchAtLogin:(BOOL)value;

@end
