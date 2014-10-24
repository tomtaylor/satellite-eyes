//
//  LLManager.h
//  LaunchAtLogin
//
//  Created by David Keegan on 4/20/12.
//  Copyright (c) 2012 David Keegan.
//  Copyright (c) 2014 Jan Weiß.
//  Some rights reserved: <http://opensource.org/licenses/mit-license.php>
//

#import <Foundation/Foundation.h>


extern NSString * const LLManagerSetLaunchAtLoginFailedNotification;


@interface LLManager : NSObject

+ (BOOL)launchAtLogin;
+ (void)setLaunchAtLogin:(BOOL)value;
+ (void)setLaunchAtLogin:(BOOL)value
         notifyOnFailure:(BOOL)wantFailureNotification;

@property (assign) BOOL launchAtLogin;
@property (assign) BOOL notifyIfSetLaunchAtLoginFailed;

@end
