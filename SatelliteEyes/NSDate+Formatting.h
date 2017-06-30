//
//  Copyright 2011 Rob Warner
//  @hoop33
//  rwarner@grailbox.com
//  http://grailbox.com


//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>

//
// Distance of time in words to string components.
typedef enum DistanceOfTimeInWordsStringComponents {
    kDOTIWStringComponentModifier       = 1,            // 00001 in binary.
    kDOTIWStringComponentNumber         = 2,            // 00010 in binary.
    kDOTIWStringComponentMeasure        = 4,            // 00100 in binary.
    kDOTIWStringComponentDirection      = 8,            // 01000 in binary.
    kDOTIWStringComponentJustNow        = 16,           // 10000 in binary (Disabled by default.)
} DistanceOfTimeInWordsStringComponents;

@interface NSDate (formatting)

- (NSString *)formatWithString:(NSString *)format;
- (NSString *)formatWithStyle:(NSDateFormatterStyle)style;
- (NSString *)distanceOfTimeInWords;
- (NSString *)distanceOfTimeInWords:(NSDate *)date;

- (NSString *)distanceOfTimeInWordsWithOptions:(NSUInteger)options;
- (NSString *)distanceOfTimeInWords:(NSDate *)date withOptions:(NSUInteger)options;
    
@end
