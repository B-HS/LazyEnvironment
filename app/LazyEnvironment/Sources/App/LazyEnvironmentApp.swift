import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let appState = AppState.shared
        if appState.settings.menuBarEnabled {
            StatusBarController.shared.install(appState: appState)
        }
        if appState.settings.startInMenuBar, appState.settings.menuBarEnabled {
            NSApp.setActivationPolicy(.accessory)
        }
        observeWindowClosing()
        observeWake()
        if ProcessInfo.processInfo.arguments.contains("-debug-show-popover") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                StatusBarController.shared.showPopover()
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-debug-open-settings") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                StatusBarController.shared.openSettings()
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-debug-open-main") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                StatusBarController.shared.openMainWindow()
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-debug-close-windows") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                for window in NSApp.windows where window.canBecomeMain && !(window is NSPanel) {
                    window.close()
                }
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-debug-github-signin-cancel") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                SyncEngine.shared.signInWithGitHub()
                try? await Task.sleep(for: .seconds(3))
                SyncEngine.shared.cancelSignIn()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        StatusBarController.shared.openMainWindow()
        return false
    }

    private func observeWindowClosing() {
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                guard AppState.shared.settings.menuBarEnabled else { return }
                guard !StatusBarController.shared.reopenRequestIsRecent else { return }
                let hasVisibleMainWindow = NSApp.windows.contains { window in
                    StatusBarController.isMainWindowCandidate(window, includingSettings: true)
                }
                if !hasVisibleMainWindow {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }

    private func observeWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await AppState.shared.refreshAllStatuses()
            }
        }
    }
}

@main
struct LazyEnvironmentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private var appState = AppState.shared

    private let forcedColorScheme: ColorScheme? = ProcessInfo.processInfo.arguments.contains("-force-dark") ? .dark : nil

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
                .environment(\.locale, appState.resolvedLocale)
                .preferredColorScheme(forcedColorScheme)
                .frame(minWidth: 960, minHeight: 600)
        }
        .defaultLaunchBehavior(appState.settings.startInMenuBar && appState.settings.menuBarEnabled ? .suppressed : .automatic)
        Settings {
            SettingsView()
                .environment(appState)
                .environment(\.locale, appState.resolvedLocale)
        }
    }
}
