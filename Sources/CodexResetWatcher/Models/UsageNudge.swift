import Foundation

struct UsageNudge: Sendable {
    enum Tier: Sendable {
        case spend
        case expiringReset
        case deadline
        case useIfBlocked
        case waitFiveHour
        case hold
        case steady
        case noResets
        case unavailable
    }

    let tier: Tier
    let title: String
    let message: String
    let detail: String

    @MainActor
    static func make(
        windows: [UsageLimitDisplay],
        resetCount: Int,
        resetUrgencies: [ResetExpiryUrgency] = []
    ) -> UsageNudge {
        if resetCount > 0, resetUrgencies.contains(where: { $0.level == .urgent }) {
            return UsageNudge(
                tier: .expiringReset,
                title: "今天不用就会失效",
                message: "有一个已保存的重置额度今天到期。如果有重要工作排队，优先用掉它。",
                detail: "今天到期"
            )
        }

        guard let weekly = windows.first(where: { $0.kind == .weekly }),
              let weeklyRemaining = weekly.remainingPercent
        else {
            return UsageNudge(
                tier: .unavailable,
                title: "正在等待限额数据",
                message: "重置额度已载入，Codex 使用窗口还在刷新中。",
                detail: "稍后再试"
            )
        }

        let fiveHour = windows.first(where: { $0.kind == .fiveHour })
        let fiveHourRemaining = fiveHour?.remainingPercent
        let weeklyResetSeconds = weekly.window.resetAfterSeconds

        if resetCount == 0 {
            return UsageNudge(
                tier: .noResets,
                title: "没有可用重置",
                message: "请留意限额。当前没有可保存的重置额度可供大任务使用。",
                detail: "每周剩余 \(weeklyRemaining)%"
            )
        }

        if let fiveHourRemaining,
           let fiveHourReset = fiveHour?.window.resetAfterSeconds,
           fiveHourRemaining <= 12,
           weeklyRemaining >= 25,
           fiveHourReset <= 90 * 60 {
            return UsageNudge(
                tier: .waitFiveHour,
                title: "先等 5h 窗口恢复",
                message: "每周额度还算充足。先等短窗口恢复，再决定是否使用重置。",
                detail: "5h 后 \(DateFormatting.duration(seconds: fiveHourReset)) 重置"
            )
        }

        if let fiveHourRemaining,
           let fiveHourReset = fiveHour?.window.resetAfterSeconds,
           fiveHourRemaining <= 12,
           weeklyRemaining >= 50,
           fiveHourReset > 90 * 60,
           fiveHourReset <= 3 * 3_600 {
            return UsageNudge(
                tier: .deadline,
                title: "按截止时间判断",
                message: "每周额度很充足。如果是紧急工作，可以使用重置；否则等待 5h 窗口恢复。",
                detail: "5h 后 \(DateFormatting.duration(seconds: fiveHourReset)) 重置"
            )
        }

        if let fiveHourRemaining,
           let fiveHourReset = fiveHour?.window.resetAfterSeconds,
           fiveHourRemaining <= 12,
           weeklyRemaining >= 50,
           fiveHourReset > 3 * 3_600 {
            return UsageNudge(
                tier: .deadline,
                title: "紧急任务可重置",
                message: "短窗口还要几个小时才恢复。有重要截止时间就使用重置，否则继续等待。",
                detail: "5h 后 \(DateFormatting.duration(seconds: fiveHourReset)) 重置"
            )
        }

        guard let weeklyResetSeconds else {
            return UsageNudge(
                tier: .steady,
                title: "重置时间不明确",
                message: "使用限额已载入，但 Codex 没有返回每周重置计时。只有工作受阻时再使用重置。",
                detail: "每周剩余 \(weeklyRemaining)%"
            )
        }

        let weeklyDays = Double(weeklyResetSeconds) / 86_400

        if resetCount >= 2, weeklyRemaining <= 15, weeklyDays >= 4 {
            return UsageNudge(
                tier: .spend,
                title: "可以推进任务",
                message: "你有 \(resetCount) 个可用重置，每周额度偏低且离刷新还有几天。先推进任务，如果 Codex 阻塞实际工作再使用重置。",
                detail: "每周剩余 \(weeklyRemaining)%"
            )
        }

        if resetCount >= 1, weeklyRemaining <= 20, weeklyDays >= 2 {
            return UsageNudge(
                tier: .useIfBlocked,
                title: "受阻时再重置",
                message: "如果实际工作卡住，使用重置是合理的。不要只为了让数字好看而消耗它。",
                detail: "距每周重置 \(DateFormatting.duration(seconds: weeklyResetSeconds))"
            )
        }

        if weeklyRemaining >= 35, weeklyDays <= 3 {
            return UsageNudge(
                tier: .hold,
                title: "先保留重置",
                message: "每周额度充足，而且下次刷新不远。把重置额度先留着。",
                detail: "每周剩余 \(weeklyRemaining)%"
            )
        }

        if weeklyRemaining >= 25, weeklyDays <= 2 {
            return UsageNudge(
                tier: .hold,
                title: "把重置留到后面",
                message: "距离每周刷新已经很近，当前容量还不算紧张。先保留这个重置额度。",
                detail: "还有 \(DateFormatting.duration(seconds: weeklyResetSeconds))"
            )
        }

        return UsageNudge(
            tier: .steady,
            title: "状态平稳",
            message: "继续工作即可。开始大任务前再检查一次。",
            detail: "每周剩余 \(weeklyRemaining)%"
        )
    }
}
