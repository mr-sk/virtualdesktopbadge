import AppKit
import ApplicationServices
import ServiceManagement
import DeskBadgeCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let tracker = SpaceTracker()
    private var keyMonitor: Any?
    private var spaceSnapshot: [String: Int] = [:]
    private static let digitKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = BadgeRenderer.image(forNumber: 0)

        tracker.onChange = { [weak self] number in
            self?.statusItem.button?.image = BadgeRenderer.image(forNumber: number)
        }

        buildMenu()
        promptForAccessibilityIfNeeded()
        startKeyMonitor()
        observeSpaceChanges()
        refreshFromSystem()   // initial value
    }

    // MARK: - Accessibility

    /// Trigger the system Accessibility prompt if not yet trusted.
    /// The global key monitor only works once access is granted.
    private func promptForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Inputs

    /// Instant path: react to ctrl+1...ctrl+9 by physical key (layout-independent).
    private func startKeyMonitor() {
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.control) else { return }
            guard let number = Self.digitKeyCodes[event.keyCode] else { return }
            self?.tracker.set(number)
        }
    }

    /// Correction path: any space change (incl. swipe / Mission Control).
    private func observeSpaceChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func spaceChanged() {
        refreshFromSystem()
    }

    /// Re-derive the number via the private API, reporting the display whose
    /// desktop actually changed (not the one under the mouse). On the first read,
    /// the focused display is used as the starting point.
    private func refreshFromSystem() {
        let displays = parseDisplaySpaces(rawManagedDisplaySpaces())
        let focusedUUID = NSScreen.main.flatMap(ScreenInfo.displayUUID(for:))
        if let index = activeDesktopNumber(previous: spaceSnapshot,
                                           displays: displays,
                                           focusedUUID: focusedUUID) {
            tracker.set(index)
        }
        spaceSnapshot = currentSpaceSnapshot(displays)
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        let accessibilityItem = NSMenuItem(
            title: "Grant Accessibility Access\u{2026}",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit DeskBadge",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                sender.state = .off
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on
            }
        } catch {
            NSLog("DeskBadge: launch-at-login toggle failed: \(error)")
        }
    }
}
