import Foundation

@MainActor
final class ResetCreditsStore: ObservableObject {
    @Published private(set) var credits: [ResetCredit] = []
    @Published private(set) var availableCount = 0
    @Published private(set) var lastChecked: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?

    private let client: CodexResetCreditsClient
    private var refreshTask: Task<Void, Never>?

    init(client: CodexResetCreditsClient = CodexResetCreditsClient()) {
        self.client = client
    }

    var availableCredits: [ResetCredit] {
        credits.filter(\.isAvailable)
    }

    var menuBarTitle: String {
        if errorMessage != nil, credits.isEmpty {
            return "Resets ?"
        }
        return "\(availableCount) reset\(availableCount == 1 ? "" : "s")"
    }

    var statusSymbolName: String {
        errorMessage == nil ? "arrow.clockwise.circle" : "exclamationmark.triangle"
    }

    func start() {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            guard let self else {
                return
            }
            await self.refresh()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 300 * 1_000_000_000)
                } catch {
                    return
                }
                await self.refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        defer {
            isRefreshing = false
        }

        do {
            let response = try await client.fetch()
            credits = response.credits.sorted(by: sortByExpiry)
            availableCount = response.availableCount
            errorMessage = nil
            lastChecked = Date()
        } catch {
            errorMessage = error.localizedDescription
            lastChecked = Date()
        }
    }

    private func sortByExpiry(_ lhs: ResetCredit, _ rhs: ResetCredit) -> Bool {
        let leftDate = DateFormatting.parse(lhs.expiresAt)
        let rightDate = DateFormatting.parse(rhs.expiresAt)

        switch (leftDate, rightDate) {
        case let (left?, right?):
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return lhs.id < rhs.id
        }
    }
}
