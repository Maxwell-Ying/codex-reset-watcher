import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ResetCreditsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let errorMessage = store.errorMessage {
                errorBanner(errorMessage)
            }

            if store.credits.isEmpty, store.isRefreshing {
                Spacer()
                ProgressView("Checking Codex resets...")
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if store.credits.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.credits) { credit in
                            CreditRowView(credit: credit)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            footer
        }
        .padding(22)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 36, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(store.errorMessage == nil ? .blue : .orange)

            VStack(alignment: .leading, spacing: 5) {
                Text("Codex Reset Watcher")
                    .font(.title2.weight(.semibold))
                Text(DateFormatting.checked(store.lastChecked))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text("\(store.availableCount)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(store.availableCount == 1 ? "reset available" : "resets available")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            Label("Updates every 5 min", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                Label(store.isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshing)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No reset credits returned.")
                .font(.headline)
            Text("Codex responded successfully, but there are no credits to display.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
