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


#import "NSDate+Formatting.h"

#define SECONDS_JUST_NOW_LIMIT 5.0
#define SECONDS_PER_MINUTE     60.0
#define SECONDS_PER_HOUR       3600.0
#define SECONDS_PER_DAY        86400.0
#define SECONDS_PER_MONTH      2592000.0
#define SECONDS_PER_YEAR       31536000.0

#define LOCALIZED_STRING_TABLE_NAME @"DistanceOfTimeInWordsLocalizable"

@implementation NSDate (formatting)

- (NSString *)formatWithString:(NSString *)format {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];
    NSString *string = [formatter stringFromDate:self];
    return string;
}

- (NSString *)formatWithStyle:(NSDateFormatterStyle)style {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:style];
    NSString *string = [formatter stringFromDate:self];
    return string;
}

- (NSString *)distanceOfTimeInWords {
    return [self distanceOfTimeInWords:[NSDate date]];
}

- (NSString *)distanceOfTimeInWords:(NSDate *)date {

    NSUInteger allOptionsEnabledByDefault =
    kDOTIWStringComponentModifier |
    kDOTIWStringComponentNumber   |
    kDOTIWStringComponentMeasure  |
    kDOTIWStringComponentDirection;

    return [self distanceOfTimeInWords:date withOptions:allOptionsEnabledByDefault];
}

- (NSString *)distanceOfTimeInWordsWithOptions:(NSUInteger)options {
    return [self distanceOfTimeInWords:[NSDate date] withOptions:options];
}

- (NSString *)distanceOfTimeInWords:(NSDate *)date withOptions:(NSUInteger)options {

    if (options & kDOTIWStringComponentJustNow)
    if (fabs([self timeIntervalSinceDate:date]) < SECONDS_JUST_NOW_LIMIT)
    return NSLocalizedStringFromTable(@"Just now", LOCALIZED_STRING_TABLE_NAME, @"Indicates a recent action");

    NSString *Ago      = NSLocalizedStringFromTable(@"ago",       LOCALIZED_STRING_TABLE_NAME, @"Denotes past dates");
    NSString *FromNow  = NSLocalizedStringFromTable(@"from now",  LOCALIZED_STRING_TABLE_NAME, @"Denotes future dates");
    NSString *LessThan = NSLocalizedStringFromTable(@"Less than", LOCALIZED_STRING_TABLE_NAME, @"Indicates a less-than number");
    NSString *About    = NSLocalizedStringFromTable(@"About",     LOCALIZED_STRING_TABLE_NAME, @"Indicates an approximate number");
    NSString *Over     = NSLocalizedStringFromTable(@"Over",      LOCALIZED_STRING_TABLE_NAME, @"Indicates an exceeding number");
    NSString *Almost   = NSLocalizedStringFromTable(@"Almost",    LOCALIZED_STRING_TABLE_NAME, @"Indicates an approaching number");
    //NSString *Second   = NSLocalizedStringFromTable(@"second",  LOCALIZED_STRING_TABLE_NAME, @"One second in time");
    NSString *Seconds  = NSLocalizedStringFromTable(@"seconds",   LOCALIZED_STRING_TABLE_NAME, @"More than one second in time");
    NSString *Minute   = NSLocalizedStringFromTable(@"minute",    LOCALIZED_STRING_TABLE_NAME, @"One minute in time");
    NSString *Minutes  = NSLocalizedStringFromTable(@"minutes",   LOCALIZED_STRING_TABLE_NAME, @"More than one minute in time");
    NSString *Hour     = NSLocalizedStringFromTable(@"hour",      LOCALIZED_STRING_TABLE_NAME, @"One hour in time");
    NSString *Hours    = NSLocalizedStringFromTable(@"hours",     LOCALIZED_STRING_TABLE_NAME, @"More than one hour in time");
    NSString *Day      = NSLocalizedStringFromTable(@"day",       LOCALIZED_STRING_TABLE_NAME, @"One day in time");
    NSString *Days     = NSLocalizedStringFromTable(@"days",      LOCALIZED_STRING_TABLE_NAME, @"More than one day in time");
    NSString *Month    = NSLocalizedStringFromTable(@"month",     LOCALIZED_STRING_TABLE_NAME, @"One month in time");
    NSString *Months   = NSLocalizedStringFromTable(@"months",    LOCALIZED_STRING_TABLE_NAME, @"More than one month in time");
    NSString *Year     = NSLocalizedStringFromTable(@"year",      LOCALIZED_STRING_TABLE_NAME, @"One year in time");
    NSString *Years    = NSLocalizedStringFromTable(@"years",     LOCALIZED_STRING_TABLE_NAME, @"More than one year in time");

    NSTimeInterval since = [self timeIntervalSinceDate:date];
    NSString *direction = since <= 0.0 ? Ago : FromNow;
    since = fabs(since);

    int seconds   = (int)since;
    int minutes   = (int)round(since / SECONDS_PER_MINUTE);
    int hours     = (int)round(since / SECONDS_PER_HOUR);
    int days      = (int)round(since / SECONDS_PER_DAY);
    int months    = (int)round(since / SECONDS_PER_MONTH);
    int years     = (int)floor(since / SECONDS_PER_YEAR);
    int offset    = (int)round(floor((float)years / 4.0) * 1440.0);
    int remainder = (minutes - offset) % 525600;

    int number;
    NSString *measure;
    NSString *modifier = @"";

    switch (minutes) {
        case 0 ... 1:
        measure = Seconds;
        switch (seconds) {
            case 0 ... 4:
            number = 5;
            modifier = LessThan;
            break;
            case 5 ... 9:
            number = 10;
            modifier = LessThan;
            break;
            case 10 ... 19:
            number = 20;
            modifier = LessThan;
            break;
            case 20 ... 39:
            number = 30;
            modifier = About;
            break;
            case 40 ... 59:
            number = 1;
            measure = Minute;
            modifier = LessThan;
            break;
            default:
            number = 1;
            measure = Minute;
            modifier = About;
            break;
        }
        break;
        case 2 ... 44:
        number = minutes;
        measure = Minutes;
        break;
        case 45 ... 89:
        number = 1;
        measure = Hour;
        modifier = About;
        break;
        case 90 ... 1439:
        number = hours;
        measure = Hours;
        modifier = About;
        break;
        case 1440 ... 2529:
        number = 1;
        measure = Day;
        break;
        case 2530 ... 43199:
        number = days;
        measure = Days;
        break;
        case 43200 ... 86399:
        number = 1;
        measure = Month;
        modifier = About;
        break;
        case 86400 ... 525599:
        number = months;
        measure = Months;
        break;
        default:
        number = years;
        measure = number == 1 ? Year : Years;
        if (remainder < 131400) {
            modifier = About;
        } else if (remainder < 394200) {
            modifier = Over;
        } else {
            ++number;
            measure = Years;
            modifier = Almost;
        }
        break;
    }
    if ([modifier length] > 0) {
        modifier = [modifier stringByAppendingString:@" "];
    }

    NSMutableString *resultString = [NSMutableString string];

    if (options & kDOTIWStringComponentModifier)
    [resultString appendString:[NSString stringWithFormat:@"%@", modifier]];
    if (options & kDOTIWStringComponentNumber)
    [resultString appendString:[NSString stringWithFormat:@"%d", number]];
    if (options & kDOTIWStringComponentMeasure)
    [resultString appendString:[NSString stringWithFormat:@" %@", measure]];
    if (options & kDOTIWStringComponentDirection)
    [resultString appendString:[NSString stringWithFormat:@" %@", direction]];
    
    return resultString;
}
    
    @end
