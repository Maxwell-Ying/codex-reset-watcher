import SwiftUI

@main
struct CodexResetWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("menuBarMetric") private var menuBarMetricRawValue = MenuBarMetric.weekly.rawValue
    @StateObject private var store = ResetCreditsStore()
    @StateObject private var mainWindowController = MainWindowController()

    private var menuBarMetric: MenuBarMetric {
        MenuBarMetric(rawValue: menuBarMetricRawValue) ?? .weekly
    }

    var body: some Scene {
        WindowGroup("Codex 重置观察器", id: "main") {
            ContentView(store: store)
                .background {
                    MainWindowReader { window in
                        mainWindowController.register(window)
                    }
                }
                .frame(minWidth: 800, idealWidth: 860, minHeight: 560, idealHeight: 620)
                .task {
                    store.start()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Codex 重置观察器") {
                Button("刷新") {
                    Task {
                        await store.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra {
            MenuBarStatusView(
                store: store,
                mainWindowController: mainWindowController,
                menuBarMetricRawValue: $menuBarMetricRawValue
            )
                .task {
                    store.start()
                }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.statusSymbolName)
                Text(store.menuBarTitle(for: menuBarMetric))
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}
