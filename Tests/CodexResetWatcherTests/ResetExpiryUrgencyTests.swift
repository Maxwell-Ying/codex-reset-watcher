import XCTest
@testable import CodexResetWatcher

final class ResetExpiryUrgencyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFarAwayResetStaysNormallyAvailable() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(8 * 86_400),
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .normal)
        XCTAssertEqual(urgency.badge, "可用")
        XCTAssertNil(urgency.hint)
    }

    func testResetWithinWeekGetsAttentionState() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(6 * 86_400),
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .approaching)
        XCTAssertEqual(urgency.badge, "本周到期")
    }

    func testResetWithinThreeDaysGetsSoonWarning() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(2 * 86_400),
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .soon)
        XCTAssertEqual(urgency.badge, "即将到期")
    }

    func testResetWithinOneDayGetsUrgentWarning() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(23 * 3_600),
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .urgent)
        XCTAssertEqual(urgency.badge, "今天到期")
    }

    func testExpiredResetIsRedFlagged() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(-60),
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .expired)
        XCTAssertEqual(urgency.badge, "已到期")
    }

    func testUnavailableResetDoesNotShowExpiryWarning() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(30 * 60),
            now: now,
            isAvailable: false
        )

        XCTAssertEqual(urgency.level, .inactive)
        XCTAssertEqual(urgency.badge, "已使用")
    }

    func testMissingExpiryStaysAvailableButUnknown() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: nil,
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .unknown)
        XCTAssertEqual(urgency.badge, "可用")
        XCTAssertEqual(urgency.hint, "到期时间未知")
    }

    func testExactUrgencyBoundaries() {
        XCTAssertEqual(urgency(after: 7 * 86_400 + 1).level, .normal)
        XCTAssertEqual(urgency(after: 7 * 86_400).level, .approaching)
        XCTAssertEqual(urgency(after: 3 * 86_400 + 1).level, .approaching)
        XCTAssertEqual(urgency(after: 3 * 86_400).level, .soon)
        XCTAssertEqual(urgency(after: 86_400 + 1).level, .soon)
        XCTAssertEqual(urgency(after: 86_400).level, .urgent)
        XCTAssertEqual(urgency(after: 1).level, .urgent)
        XCTAssertEqual(urgency(after: 0).level, .expired)
        XCTAssertEqual(urgency(after: -1).level, .expired)
    }

    private func urgency(after seconds: TimeInterval) -> ResetExpiryUrgency {
        ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(seconds),
            now: now,
            isAvailable: true
        )
    }
}
