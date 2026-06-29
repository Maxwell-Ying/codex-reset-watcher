import XCTest
@testable import CodexResetWatcher

final class UsageNudgeTests: XCTestCase {
    @MainActor
    func testBurnTokensWhenWeeklyIsLowAndResetsAreBanked() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 10, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 2
        )

        XCTAssertEqual(nudge.tier, .spend)
        XCTAssertEqual(nudge.title, "可以推进任务")
    }

    @MainActor
    func testHoldResetWhenWeeklyRoomIsHealthyAndRefreshIsClose() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 40, resetAfterSeconds: 2 * 86_400)
            ],
            resetCount: 2
        )

        XCTAssertEqual(nudge.tier, .hold)
        XCTAssertEqual(nudge.title, "先保留重置")
    }

    @MainActor
    func testWaitForFiveHourWindowWhenWeeklyRoomIsFine() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 8, resetAfterSeconds: 45 * 60),
                window(kind: .weekly, remaining: 45, resetAfterSeconds: 3 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .waitFiveHour)
        XCTAssertEqual(nudge.title, "先等 5h 窗口恢复")
    }

    @MainActor
    func testLowFiveHourAndHealthyWeeklyWithLongWaitBecomesDeadlineCall() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 5, resetAfterSeconds: 4 * 3_600),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .deadline)
        XCTAssertEqual(nudge.title, "紧急任务可重置")
        XCTAssertTrue(nudge.message.contains("重要截止时间"))
    }

    @MainActor
    func testLowFiveHourAndHealthyWeeklyWithMediumWaitBecomesDeadlineCall() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 5, resetAfterSeconds: 2 * 3_600),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .deadline)
        XCTAssertEqual(nudge.title, "按截止时间判断")
        XCTAssertTrue(nudge.message.contains("紧急工作"))
    }

    @MainActor
    func testLowFiveHourAndHealthyWeeklyWithShortWaitSavesReset() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 5, resetAfterSeconds: 60 * 60),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .waitFiveHour)
        XCTAssertEqual(nudge.title, "先等 5h 窗口恢复")
    }

    @MainActor
    func testLowFiveHourDeadlineCallRequiresBankedReset() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 5, resetAfterSeconds: 4 * 3_600),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 0
        )

        XCTAssertEqual(nudge.tier, .noResets)
        XCTAssertEqual(nudge.title, "没有可用重置")
    }

    @MainActor
    func testModerateFiveHourRemainingDoesNotTriggerDeadlineWarning() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 15, resetAfterSeconds: 4 * 3_600),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .steady)
        XCTAssertEqual(nudge.title, "状态平稳")
    }

    @MainActor
    func testMissingFiveHourDataStillUsesWeeklyAdvice() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 10, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 2
        )

        XCTAssertEqual(nudge.tier, .spend)
        XCTAssertEqual(nudge.title, "可以推进任务")
    }

    @MainActor
    func testExpiringResetOverridesHoldAdvice() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 80, resetAfterSeconds: 4 * 3_600),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 24 * 60 * 60)
            ],
            resetCount: 1,
            resetUrgencies: [
                ResetExpiryUrgency(level: .urgent, badge: "今天到期", hint: "尽快使用，否则会失效")
            ]
        )

        XCTAssertEqual(nudge.tier, .expiringReset)
        XCTAssertEqual(nudge.title, "今天不用就会失效")
    }

    @MainActor
    func testUseIfBlockedWhenWeeklyIsLowButNotBurnMode() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 18, resetAfterSeconds: 3 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .useIfBlocked)
        XCTAssertEqual(nudge.title, "受阻时再重置")
    }

    @MainActor
    func testPocketResetHoldWhenWeeklyRefreshIsVeryClose() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 30, resetAfterSeconds: 36 * 3_600)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .hold)
        XCTAssertEqual(nudge.title, "把重置留到后面")
    }

    @MainActor
    func testUnavailableWhenWeeklyWindowIsMissing() {
        let nudge = UsageNudge.make(windows: [], resetCount: 1)

        XCTAssertEqual(nudge.tier, .unavailable)
        XCTAssertEqual(nudge.title, "正在等待限额数据")
    }

    @MainActor
    func testUnknownWeeklyResetTimingDoesNotPretendRefreshIsClose() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 40, resetAfterSeconds: nil)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .steady)
        XCTAssertEqual(nudge.title, "重置时间不明确")
    }

    @MainActor
    func testFiveHourLowBoundaryIsInclusive() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 12, resetAfterSeconds: 60 * 60),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .waitFiveHour)
    }

    @MainActor
    func testFiveHourBoundaryAboveLowStaysCalm() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 13, resetAfterSeconds: 60 * 60),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .steady)
    }

    @MainActor
    func testNoResetsShowsNoCushion() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 60, resetAfterSeconds: 3 * 86_400)
            ],
            resetCount: 0
        )

        XCTAssertEqual(nudge.tier, .noResets)
        XCTAssertEqual(nudge.title, "没有可用重置")
    }

    private func window(
        kind: UsageLimitDisplay.Kind,
        remaining: Int,
        resetAfterSeconds: Int?
    ) -> UsageLimitDisplay {
        let seconds: Int
        let id: String
        let title: String

        switch kind {
        case .fiveHour:
            seconds = 18_000
            id = "five-hour"
            title = "5h limit"
        case .weekly:
            seconds = 604_800
            id = "weekly"
            title = "Weekly limit"
        case .generic:
            seconds = resetAfterSeconds ?? 0
            id = "generic"
            title = "Limit"
        }

        return UsageLimitDisplay(
            id: id,
            kind: kind,
            title: title,
            window: UsageLimitWindow(
                usedPercent: 100 - remaining,
                limitWindowSeconds: seconds,
                resetAfterSeconds: resetAfterSeconds,
                resetAt: nil
            ),
            limitReached: false
        )
    }
}
