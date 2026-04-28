import Foundation

/// Visual schedule specification (user-friendly)
public enum ScheduleSpec: Codable, Sendable {
    case oneTime(date: Date)
    case daily(time: ScheduleTime, timezone: String)
    case weekly(time: ScheduleTime, days: [Weekday], timezone: String)
    case monthly(time: ScheduleTime, days: [Int], timezone: String)

    public struct ScheduleTime: Codable, Sendable {
        public let hour: Int  // 0-23
        public let minute: Int  // 0-59

        public init(hour: Int, minute: Int) {
            self.hour = hour
            self.minute = minute
        }

        public var description: String {
            String(format: "%02d:%02d", hour, minute)
        }
    }

    public enum Weekday: Int, Codable, CaseIterable, Sendable {
        case sunday = 0, monday = 1, tuesday = 2, wednesday = 3,
             thursday = 4, friday = 5, saturday = 6

        public var name: String {
            switch self {
            case .sunday: return "Sunday"
            case .monday: return "Monday"
            case .tuesday: return "Tuesday"
            case .wednesday: return "Wednesday"
            case .thursday: return "Thursday"
            case .friday: return "Friday"
            case .saturday: return "Saturday"
            }
        }

        public var shortName: String {
            String(name.prefix(3))
        }
    }
}

/// Compiler that converts ScheduleSpec to cron expression and computes next run times
public final actor ScheduleCompiler {
    private let calendar: Calendar
    private let logger = AppLogger.scheduler

    public init() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        self.calendar = calendar
    }

    /// Compile ScheduleSpec to cron expression string
    public func compileToCron(_ spec: ScheduleSpec) -> String {
        switch spec {
        case .oneTime:
            // One-time schedules don't use cron - they use absolute date
            return ""

        case .daily(let time, _):
            // Format: minute hour * * *
            return "\(time.minute) \(time.hour) * * *"

        case .weekly(let time, let days, _):
            // Format: minute hour * * dayOfWeek
            let dayList = days.sorted { $0.rawValue < $1.rawValue }
                .map { String($0.rawValue) }
                .joined(separator: ",")
            return "\(time.minute) \(time.hour) * * \(dayList)"

        case .monthly(let time, let days, _):
            // Format: minute hour dayOfMonth * *
            let dayList = days.sorted().map { String($0) }.joined(separator: ",")
            return "\(time.minute) \(time.hour) \(dayList) * *"
        }
    }

    /// Calculate the next run time after a given date
    public func nextRunTime(from spec: ScheduleSpec, after date: Date = Date()) -> Date? {
        switch spec {
        case .oneTime(let targetDate):
            // One-time: return the target date if it's in the future
            return targetDate > date ? targetDate : nil

        case .daily(let time, let timezoneId):
            return nextDailyRunTime(time: time, timezoneId: timezoneId, after: date)

        case .weekly(let time, let days, let timezoneId):
            return nextWeeklyRunTime(time: time, days: days, timezoneId: timezoneId, after: date)

        case .monthly(let time, let days, let timezoneId):
            return nextMonthlyRunTime(time: time, days: days, timezoneId: timezoneId, after: date)
        }
    }

    /// Calculate the next N run times for preview purposes
    public func nextRunTimes(from spec: ScheduleSpec, count: Int, after date: Date = Date()) -> [Date] {
        var dates: [Date] = []
        var currentDate = date

        for _ in 0..<count {
            guard let nextDate = nextRunTime(from: spec, after: currentDate) else {
                break
            }
            dates.append(nextDate)
            currentDate = nextDate.addingTimeInterval(1) // Move past this date
        }

        return dates
    }

    /// Create a human-readable description of the schedule
    public func description(for spec: ScheduleSpec) -> String {
        switch spec {
        case .oneTime(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Once on \(formatter.string(from: date))"

        case .daily(let time, let timezone):
            return "Daily at \(time.description) \(timezoneDisplay(timezone))"

        case .weekly(let time, let days, let timezone):
            let dayNames = days.sorted { $0.rawValue < $1.rawValue }.map { $0.shortName }.joined(separator: ", ")
            return "Weekly on \(dayNames) at \(time.description) \(timezoneDisplay(timezone))"

        case .monthly(let time, let days, let timezone):
            let dayList = days.sorted().map { ordinal($0) }.joined(separator: ", ")
            return "Monthly on the \(dayList) at \(time.description) \(timezoneDisplay(timezone))"
        }
    }

    // MARK: - Private Calculation Methods

    private func nextDailyRunTime(time: ScheduleSpec.ScheduleTime, timezoneId: String, after date: Date) -> Date? {
        guard let timezone = TimeZone(identifier: timezoneId) else {
            logger.error("Invalid timezone: \(timezoneId)")
            return nil
        }

        var calendar = self.calendar
        calendar.timeZone = timezone

        // Get the date components for today in the target timezone
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0

        // Try today first
        if let todayRun = calendar.date(from: components), todayRun > date {
            return todayRun
        }

        // If today has passed, move to tomorrow
        components.day = (components.day ?? 1) + 1
        return calendar.date(from: components)
    }

    private func nextWeeklyRunTime(
        time: ScheduleSpec.ScheduleTime,
        days: [ScheduleSpec.Weekday],
        timezoneId: String,
        after date: Date
    ) -> Date? {
        guard let timezone = TimeZone(identifier: timezoneId),
              !days.isEmpty else {
            return nil
        }

        var calendar = self.calendar
        calendar.timeZone = timezone

        let sortedDays = days.sorted { $0.rawValue < $1.rawValue }
        let currentWeekday = calendar.component(.weekday, from: date) - 1 // 0 = Sunday

        // Check remaining days this week
        for day in sortedDays where day.rawValue > currentWeekday {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.weekday = day.rawValue + 1 // Calendar uses 1-7
            components.hour = time.hour
            components.minute = time.minute
            components.second = 0

            if let runDate = calendar.nextDate(
                after: date,
                matching: components,
                matchingPolicy: .nextTime,
                direction: .forward
            ) {
                return runDate
            }
        }

        // Move to next week starting from the first scheduled day
        guard let firstDay = sortedDays.first else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.weekday = firstDay.rawValue + 1
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0

        // Add 7 days to get to next week
        if let nextWeek = calendar.date(byAdding: .day, value: 7, to: date) {
            return calendar.nextDate(
                after: nextWeek,
                matching: components,
                matchingPolicy: .nextTime,
                direction: .forward
            )
        }

        return nil
    }

    private func nextMonthlyRunTime(
        time: ScheduleSpec.ScheduleTime,
        days: [Int],
        timezoneId: String,
        after date: Date
    ) -> Date? {
        guard let timezone = TimeZone(identifier: timezoneId),
              !days.isEmpty else {
            return nil
        }

        var calendar = self.calendar
        calendar.timeZone = timezone

        let sortedDays = days.sorted()
        let currentDay = calendar.component(.day, from: date)
        let currentMonth = calendar.component(.month, from: date)
        let currentYear = calendar.component(.year, from: date)

        // Check remaining days this month
        for day in sortedDays where day > currentDay {
            var components = DateComponents()
            components.year = currentYear
            components.month = currentMonth
            components.day = day
            components.hour = time.hour
            components.minute = time.minute
            components.second = 0

            if let runDate = calendar.date(from: components), runDate > date {
                return runDate
            }
        }

        // Move to next month starting from the first scheduled day
        guard let firstDay = sortedDays.first else { return nil }
        var components = DateComponents()
        components.year = currentYear
        components.month = currentMonth + 1
        components.day = firstDay
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0

        return calendar.date(from: components)
    }

    private func timezoneDisplay(_ identifier: String) -> String {
        if let timezone = TimeZone(identifier: identifier) {
            let abbreviation = timezone.abbreviation() ?? identifier
            return "(\(abbreviation))"
        }
        return "(\(identifier))"
    }

    private func ordinal(_ number: Int) -> String {
        let suffix: String
        switch number % 100 {
        case 11, 12, 13:
            suffix = "th"

        default:
            switch number % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(number)\(suffix)"
    }
}

/// Encoder/Decoder for ScheduleSpec to JSON payload storage
public final class ScheduleSpecCoder: Sendable {
    public init() {}

    public func encode(_ spec: ScheduleSpec) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(spec),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    public func decode(_ json: String) -> ScheduleSpec? {
        guard let data = json.data(using: .utf8) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let spec = try? decoder.decode(ScheduleSpec.self, from: data) {
            return spec
        }
        return nil
    }
}

// MARK: - ScheduleSpec Codable Implementation

extension ScheduleSpec {
    private enum CodingKeys: String, CodingKey {
        case kind, date, time, days, timezone
    }

    private enum Kind: String, Codable {
        case oneTime, daily, weekly, monthly
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .oneTime(let date):
            try container.encode(Kind.oneTime, forKey: .kind)
            try container.encode(date, forKey: .date)

        case .daily(let time, let timezone):
            try container.encode(Kind.daily, forKey: .kind)
            try container.encode(time, forKey: .time)
            try container.encode(timezone, forKey: .timezone)

        case .weekly(let time, let days, let timezone):
            try container.encode(Kind.weekly, forKey: .kind)
            try container.encode(time, forKey: .time)
            try container.encode(days, forKey: .days)
            try container.encode(timezone, forKey: .timezone)

        case .monthly(let time, let days, let timezone):
            try container.encode(Kind.monthly, forKey: .kind)
            try container.encode(time, forKey: .time)
            try container.encode(days, forKey: .days)
            try container.encode(timezone, forKey: .timezone)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .oneTime:
            let date = try container.decode(Date.self, forKey: .date)
            self = .oneTime(date: date)

        case .daily:
            let time = try container.decode(ScheduleTime.self, forKey: .time)
            let timezone = try container.decode(String.self, forKey: .timezone)
            self = .daily(time: time, timezone: timezone)

        case .weekly:
            let time = try container.decode(ScheduleTime.self, forKey: .time)
            let days = try container.decode([Weekday].self, forKey: .days)
            let timezone = try container.decode(String.self, forKey: .timezone)
            self = .weekly(time: time, days: days, timezone: timezone)

        case .monthly:
            let time = try container.decode(ScheduleTime.self, forKey: .time)
            let days = try container.decode([Int].self, forKey: .days)
            let timezone = try container.decode(String.self, forKey: .timezone)
            self = .monthly(time: time, days: days, timezone: timezone)
        }
    }
}
