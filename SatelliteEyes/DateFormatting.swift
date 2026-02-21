import Foundation

@objc enum DistanceOfTimeInWordsStringComponents: UInt {
    case modifier  = 1
    case number    = 2
    case measure   = 4
    case direction = 8
    case justNow   = 16
}

extension NSDate {
    @objc func distanceOfTimeInWords() -> String {
        distanceOfTimeInWords(NSDate())
    }

    @objc func distanceOfTimeInWords(_ date: NSDate) -> String {
        let options: UInt =
            DistanceOfTimeInWordsStringComponents.modifier.rawValue |
            DistanceOfTimeInWordsStringComponents.number.rawValue |
            DistanceOfTimeInWordsStringComponents.measure.rawValue |
            DistanceOfTimeInWordsStringComponents.direction.rawValue
        return distanceOfTimeInWords(date, withOptions: options)
    }

    @objc func distanceOfTimeInWordsWithOptions(_ options: UInt) -> String {
        distanceOfTimeInWords(NSDate(), withOptions: options)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    @objc func distanceOfTimeInWords(_ date: NSDate, withOptions options: UInt) -> String {
        let secondsJustNowLimit = 5.0
        let secondsPerMinute    = 60.0
        let secondsPerHour      = 3600.0
        let secondsPerDay       = 86400.0
        let secondsPerMonth     = 2_592_000.0
        let secondsPerYear      = 31_536_000.0

        if options & DistanceOfTimeInWordsStringComponents.justNow.rawValue != 0 {
            if abs(timeIntervalSince(date as Date)) < secondsJustNowLimit {
                return "Just now"
            }
        }

        let ago      = "ago"
        let fromNow  = "from now"
        let lessThan = "Less than"
        let about    = "About"
        let over     = "Over"
        let almost   = "Almost"
        let secondsWord = "seconds"
        let minuteWord  = "minute"
        let minutesWord = "minutes"
        let hourWord    = "hour"
        let hoursWord   = "hours"
        let dayWord     = "day"
        let daysWord    = "days"
        let monthWord   = "month"
        let monthsWord  = "months"
        let yearWord    = "year"
        let yearsWord   = "years"

        var since = timeIntervalSince(date as Date)
        let direction = since <= 0.0 ? ago : fromNow
        since = abs(since)

        let seconds = Int(since)
        let minutes = Int(round(since / secondsPerMinute))
        let hours   = Int(round(since / secondsPerHour))
        let days    = Int(round(since / secondsPerDay))
        let months  = Int(round(since / secondsPerMonth))
        var years   = Int(floor(since / secondsPerYear))
        let offset  = Int(round(floor(Double(years) / 4.0) * 1440.0))
        let remainder = (minutes - offset) % 525600

        var number: Int
        var measure: String
        var modifier = ""

        switch minutes {
        case 0...1:
            measure = secondsWord
            switch seconds {
            case 0...4:
                number = 5; modifier = lessThan
            case 5...9:
                number = 10; modifier = lessThan
            case 10...19:
                number = 20; modifier = lessThan
            case 20...39:
                number = 30; modifier = about
            case 40...59:
                number = 1; measure = minuteWord; modifier = lessThan
            default:
                number = 1; measure = minuteWord; modifier = about
            }
        case 2...44:
            number = minutes; measure = minutesWord
        case 45...89:
            number = 1; measure = hourWord; modifier = about
        case 90...1439:
            number = hours; measure = hoursWord; modifier = about
        case 1440...2529:
            number = 1; measure = dayWord
        case 2530...43199:
            number = days; measure = daysWord
        case 43200...86399:
            number = 1; measure = monthWord; modifier = about
        case 86400...525599:
            number = months; measure = monthsWord
        default:
            number = years
            measure = number == 1 ? yearWord : yearsWord
            if remainder < 131400 {
                modifier = about
            } else if remainder < 394200 {
                modifier = over
            } else {
                years += 1
                number = years
                measure = yearsWord
                modifier = almost
            }
        }

        if !modifier.isEmpty {
            modifier += " "
        }

        var result = ""
        if options & DistanceOfTimeInWordsStringComponents.modifier.rawValue != 0 {
            result += modifier
        }
        if options & DistanceOfTimeInWordsStringComponents.number.rawValue != 0 {
            result += "\(number)"
        }
        if options & DistanceOfTimeInWordsStringComponents.measure.rawValue != 0 {
            result += " \(measure)"
        }
        if options & DistanceOfTimeInWordsStringComponents.direction.rawValue != 0 {
            result += " \(direction)"
        }
        return result
    }
}
