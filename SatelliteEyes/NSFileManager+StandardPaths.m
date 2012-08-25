//
//  NSFileManager+StandardPaths.h
//
//  Version 1.1.1
//
//  Created by Nick Lockwood on 10/11/2011.
//  Copyright (C) 2012 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from either of these locations:
//
//  http://charcoaldesign.co.uk/source/cocoa#standardpaths
//  https://github.com/nicklockwood/StandardPaths
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//


#import "NSFileManager+StandardPaths.h"
#include <sys/xattr.h>


@implementation NSFileManager (StandardPaths)

- (NSString *)publicDataPath
{
    @synchronized ([NSFileManager class])
    {
        static NSString *path = nil;
        if (!path)
        {
            //user documents folder
            path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
            
            //retain path
            path = [[NSString alloc] initWithString:path];
        }
        return path;
    }
}

- (NSString *)privateDataPath
{
    @synchronized ([NSFileManager class])
    {
        static NSString *path = nil;
        if (!path)
        {
            //application support folder
            path = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
            
    #ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
            
            //append application name on Mac OS
            NSString *identifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
            path = [path stringByAppendingPathComponent:identifier];
            
    #endif
            
            //create the folder if it doesn't exist
            if (![self fileExistsAtPath:path])
            {
                [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            
            //retain path
            path = [[NSString alloc] initWithString:path];
        }
        return path;
    }
}

- (NSString *)cacheDataPath
{
    @synchronized ([NSFileManager class])
    {
        static NSString *path = nil;
        if (!path)
        {
            //cache folder
            path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
            
    #ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
            
            //append application bundle ID on Mac OS
            NSString *identifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleIdentifierKey];
            path = [path stringByAppendingPathComponent:identifier];
            
    #endif
            
            //create the folder if it doesn't exist
            if (![self fileExistsAtPath:path])
            {
                [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            
            //retain path
            path = [[NSString alloc] initWithString:path];
        }
        return path;
    }
}

- (NSString *)offlineDataPath
{
    static NSString *path = nil;
    if (!path)
    {
        //offline data folder
        path = [[self privateDataPath] stringByAppendingPathComponent:@"Offline Data"];
        
        //create the folder if it doesn't exist
        if (![self fileExistsAtPath:path])
        {
            [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
        }
        
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
#ifdef __IPHONE_5_1
        
        if (&NSURLIsExcludedFromBackupKey && [NSURL instancesRespondToSelector:@selector(setResourceValue:forKey:error:)])
        {
            //use iOS 5.1 method to exclude file from backp
            NSURL *URL = [NSURL fileURLWithPath:path isDirectory:YES];
            [URL setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:NULL];
        }
        else
            
#endif
            
        {
            //use the iOS 5.0.1 mobile backup flag to exclude file from backp
            u_int8_t b = 1;
            setxattr([path fileSystemRepresentation], "com.apple.MobileBackup", &b, 1, 0, 0);
        }
        
#endif
        //retain path
        path = [[NSString alloc] initWithString:path];
    }
    return path;
}

- (NSString *)temporaryDataPath
{
    static NSString *path = nil;
    if (!path)
    {
        //temporary directory (shouldn't change during app lifetime)
        path = NSTemporaryDirectory();
        
        //apparently NSTemporaryDirectory() can return nil in some cases
        if (!path)
        {
            path = [[self cacheDataPath] stringByAppendingPathComponent:@"Temporary Files"];
        }
        
        //retain path
        path = [[NSString alloc] initWithString:path];
    }
    return path;
}

- (NSString *)resourcePath
{
    static NSString *path = nil;
    if (!path)
    {
        //bundle path
        path = [[NSString alloc] initWithString:[[NSBundle mainBundle] resourcePath]];
    }
    return path;
}

- (NSString *)pathForPublicFile:(NSString *)file
{
	return [[self publicDataPath] stringByAppendingPathComponent:file];
}

- (NSString *)pathForPrivateFile:(NSString *)file
{
    return [[self privateDataPath] stringByAppendingPathComponent:file];
}

- (NSString *)pathForCacheFile:(NSString *)file
{
    return [[self cacheDataPath] stringByAppendingPathComponent:file];
}

- (NSString *)pathForOfflineFile:(NSString *)file
{
    return [[self offlineDataPath] stringByAppendingPathComponent:file];
}

- (NSString *)pathForTemporaryFile:(NSString *)file
{
    return [[self temporaryDataPath] stringByAppendingPathComponent:file];
}

- (NSString *)pathForResource:(NSString *)file
{
    return [[self resourcePath] stringByAppendingPathComponent:file];
}

@end
