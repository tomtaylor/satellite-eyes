import Foundation

struct DistanceOfTimeInWordsOptions: OptionSet {
    let rawValue: UInt
    static let modifier  = DistanceOfTimeInWordsOptions(rawValue: 1)
    static let number    = DistanceOfTimeInWordsOptions(rawValue: 2)
    static let measure   = DistanceOfTimeInWordsOptions(rawValue: 4)
    static let direction = DistanceOfTimeInWordsOptions(rawValue: 8)
    static let justNow   = DistanceOfTimeInWordsOptions(rawValue: 16)
}

extension Date {
    func distanceOfTimeInWords() -> String {
        distanceOfTimeInWords(from: Date())
    }

    func distanceOfTimeInWords(from date: Date) -> String {
        let options: DistanceOfTimeInWordsOptions = [.modifier, .number, .measure, .direction]
        return distanceOfTimeInWords(from: date, options: options)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func distanceOfTimeInWords(from date: Date, options: DistanceOfTimeInWordsOptions) -> String {
        let secondsJustNowLimit = 5.0
        let secondsPerMinute    = 60.0
        let secondsPerHour      = 3600.0
        let secondsPerDay       = 86400.0
        let secondsPerMonth     = 2_592_000.0
        let secondsPerYear      = 31_536_000.0

        if options.contains(.justNow) {
            if abs(timeIntervalSince(date)) < secondsJustNowLimit {
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

        var since = timeIntervalSince(date)
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
        if options.contains(.modifier) {
            result += modifier
        }
        if options.contains(.number) {
            result += "\(number)"
        }
        if options.contains(.measure) {
            result += " \(measure)"
        }
        if options.contains(.direction) {
            result += " \(direction)"
        }
        return result
    }
}
