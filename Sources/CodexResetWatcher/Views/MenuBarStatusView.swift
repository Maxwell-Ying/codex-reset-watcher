import AppKit
import SwiftUI

struct MenuBarStatusView: View {
    @ObservedObject var store: ResetCreditsStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.availableCount) reset\(store.availableCount == 1 ? "" : "s")")
                        .font(.headline)
                    Text(DateFormatting.checked(store.lastChecked))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.availableCredits.prefix(4)) { credit in
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.secondary)
                        Text(DateFormatting.compact(credit.expiresAt))
                            .font(.callout.weight(.medium))
                        Spacer()
                    }
                }

                if store.availableCredits.isEmpty, store.errorMessage == nil {
                    Text("No available resets")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Button {
                    Task {
                        await store.refresh()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)

                Spacer()

                Button("Open") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 270)
    }
}
