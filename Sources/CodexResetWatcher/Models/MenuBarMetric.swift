import Foundation

enum MenuBarMetric: String, CaseIterable, Identifiable, Sendable {
    case weekly
    case fiveHour

    var id: String {
        rawValue
    }

    var pickerTitle: String {
        switch self {
        case .weekly:
            return "每周"
        case .fiveHour:
            return "5h"
        }
    }

    var fallbackCue: String {
        switch self {
        case .weekly:
            return "本周"
        case .fiveHour:
            return "5h"
        }
    }

    func matches(_ kind: UsageLimitDisplay.Kind) -> Bool {
        switch (self, kind) {
        case (.weekly, .weekly), (.fiveHour, .fiveHour):
            return true
        case (.weekly, _), (.fiveHour, _):
            return false
        }
    }
}
