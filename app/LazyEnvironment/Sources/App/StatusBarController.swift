import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private static let settingsWindowIdentifier = "com_apple_SwiftUI_Settings_window"
    private static let reopenGraceInterval: TimeInterval = 1

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var lastOpenMainWindowRequest = Date.distantPast

    static func isMainWindowCandidate(_ window: NSWindow, includingSettings: Bool) -> Bool {
        if window is NSPanel || window.className == "NSStatusBarWindow" { return false }
        if !includingSettings, window.identifier?.rawValue == Self.settingsWindowIdentifier { return false }
        return window.isMiniaturized || (window.isVisible && window.canBecomeMain)
    }

    var reopenRequestIsRecent: Bool {
        Date().timeIntervalSince(lastOpenMainWindowRequest) < Self.reopenGraceInterval
    }

    func install(appState: AppState) {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: "Lazy Environment")
        item.button?.image?.isTemplate = true
        item.button?.target = self
        item.button?.action = #selector(handleClick)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        popover.behavior = .transient
        let hostingController = NSHostingController(
            rootView: MenuBarSummaryView()
                .environment(appState)
                .environment(\.locale, appState.resolvedLocale)
        )
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
    }

    func showPopover() {
        guard let button = statusItem?.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func remove() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    @objc private func handleClick() {
        guard statusItem?.button != nil else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showContextMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "Open Lazy Environment"), action: #selector(openMainWindowAction), keyEquivalent: "").target = self
        menu.addItem(withTitle: String(localized: "Settings…"), action: #selector(openSettingsAction), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Quit"), action: #selector(quitAction), keyEquivalent: "").target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openMainWindowAction() {
        openMainWindow()
    }

    @objc private func openSettingsAction() {
        openSettings()
    }

    func openSettings() {
        popover.performClose(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let appMenu = NSApp.mainMenu?.items.first?.submenu {
            let settingsIndex = appMenu.items.firstIndex { item in
                item.keyEquivalent == "," && item.keyEquivalentModifierMask == .command
            }
            if let settingsIndex {
                appMenu.performActionForItem(at: settingsIndex)
                return
            }
        }
        if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    func openMainWindow() {
        lastOpenMainWindowRequest = Date()
        popover.performClose(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let mainWindow = NSApp.windows.first { Self.isMainWindowCandidate($0, includingSettings: false) }
        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            openNewMainWindow()
        }
    }

    private func openNewMainWindow() {
        for menu in NSApp.mainMenu?.items.compactMap(\.submenu) ?? [] {
            let newWindowIndex = menu.items.firstIndex { item in
                item.keyEquivalent == "n" && item.keyEquivalentModifierMask == .command
            }
            if let newWindowIndex {
                menu.performActionForItem(at: newWindowIndex)
                return
            }
        }
        NSApp.setActivationPolicy(.accessory)
    }
}
