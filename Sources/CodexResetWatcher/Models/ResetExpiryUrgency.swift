import Foundation

struct ResetExpiryUrgency: Equatable, Sendable {
    enum Level: Equatable, Sendable {
        case normal
        case approaching
        case soon
        case urgent
        case expired
        case inactive
        case unknown
    }

    let level: Level
    let badge: String
    let hint: String?

    static func make(expiresAt: Date?, now: Date = Date(), isAvailable: Bool) -> ResetExpiryUrgency {
        guard isAvailable else {
            return ResetExpiryUrgency(level: .inactive, badge: "已使用", hint: nil)
        }

        guard let expiresAt else {
            return ResetExpiryUrgency(level: .unknown, badge: "可用", hint: "到期时间未知")
        }

        let seconds = expiresAt.timeIntervalSince(now)

        if seconds <= 0 {
            return ResetExpiryUrgency(level: .expired, badge: "已到期", hint: "这个重置额度已过期")
        }

        if seconds <= 86_400 {
            return ResetExpiryUrgency(level: .urgent, badge: "今天到期", hint: "尽快使用，否则会失效")
        }

        if seconds <= 3 * 86_400 {
            return ResetExpiryUrgency(level: .soon, badge: "即将到期", hint: "建议留意这个额度")
        }

        if seconds <= 7 * 86_400 {
            return ResetExpiryUrgency(level: .approaching, badge: "本周到期", hint: "到期时间越来越近")
        }

        return ResetExpiryUrgency(level: .normal, badge: "可用", hint: nil)
    }
}
