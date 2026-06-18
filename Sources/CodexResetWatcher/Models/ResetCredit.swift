import Foundation

struct ResetCreditsResponse: Decodable, Sendable {
    let credits: [ResetCredit]
    let availableCount: Int
}

struct ResetCredit: Decodable, Identifiable, Sendable {
    let id: String
    let resetType: String
    let status: String
    let grantedAt: String?
    let expiresAt: String?
    let redeemStartedAt: String?
    let redeemedAt: String?
    let title: String?
    let description: String?

    var isAvailable: Bool {
        status == "available"
    }
}
