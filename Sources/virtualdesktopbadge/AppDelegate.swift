import AppKit
import ApplicationServices
import ServiceManagement
import VirtualDesktopBadgeCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let tracker = SpaceTracker()
    private var keyMonitor: Any?
    private var pendingKeyConfirm: DispatchWorkItem?
    private let noteStore = NoteStore(store: UserDefaults.standard)
    // Maps the number-row key codes to desktops for the instant ctrl+digit path.
    // This is the keyboard shortcut set only (ten digit keys: 1-9, 0), NOT a cap
    // on desktops — higher desktops still display correctly via the system read.
    private static let digitKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9, 29: 10,
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = BadgeRenderer.image(forNumber: 0)

        tracker.onChange = { [weak self] number in
            self?.render(number: number)
        }

        buildMenu()
        promptForAccessibilityIfNeeded()
        startKeyMonitor()
        observeSpaceChanges()
        observeApps()
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

    /// Draw the number box and the desktop's label (note or live app list).
    private func render(number: Int) {
        statusItem.button?.image = BadgeRenderer.image(forNumber: number)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.title = titleText(for: number)
    }

    /// Refresh only the label for the current desktop (e.g. when apps change).
    private func refreshLabel() {
        guard let number = tracker.current else { return }
        statusItem.button?.title = titleText(for: number)
    }

    /// The menu-bar label: a manual note if one is set, otherwise the apps
    /// currently on this desktop. Prefixed with a space to sit beside the box.
    private func titleText(for number: Int) -> String {
        let label = noteStore.note(for: number) ?? AppLabel.format(DesktopApps.current())
        return label.isEmpty ? "" : " \(label)"
    }

    /// Instant path: react to ctrl+1…ctrl+0 (desktops 1–10) by physical key code,
    /// which is layout-independent.
    private func startKeyMonitor() {
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            guard event.modifierFlags.contains(.control) else { return }
            guard let number = Self.digitKeyCodes[event.keyCode] else { return }
            self.tracker.set(number)        // optimistic, zero-lag guess
            self.scheduleKeyConfirm()
        }
    }

    /// After an instant ctrl+digit guess, confirm it against the real desktop a
    /// moment later — unless a genuine space change arrives first (which already
    /// corrects it and cancels this). This keeps the guess safe even when
    /// ctrl+digit isn't actually mapped to switching desktops.
    private func scheduleKeyConfirm() {
        pendingKeyConfirm?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refreshFromSystem() }
        pendingKeyConfirm = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Correction path: re-read on any space change (swipe / Mission Control)
    /// and on any display reconfiguration (docking / undocking a monitor).
    private func observeSpaceChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func systemChanged() {
        // A real switch happened, so the pending ctrl+digit confirm is moot.
        pendingKeyConfirm?.cancel()
        pendingKeyConfirm = nil
        refreshFromSystem()
    }

    /// Keep the live app list fresh as apps are launched, activated, or quit.
    private func observeApps() {
        let center = NSWorkspace.shared.notificationCenter
        for name: NSNotification.Name in [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ] {
            center.addObserver(self, selector: #selector(appsChanged), name: name, object: nil)
        }
    }

    @objc private func appsChanged() {
        refreshLabel()
    }

    /// Show the current desktop of the primary display (the menu-bar screen).
    /// Anchoring to the primary display keeps the number correct at rest,
    /// regardless of where the mouse or keyboard focus happens to be.
    private func refreshFromSystem() {
        let displays = parseDisplaySpaces(rawManagedDisplaySpaces())
        let primaryUUID = ScreenInfo.primaryDisplayUUID() ?? ""
        if let index = resolveIndex(displays: displays, activeDisplayUUID: primaryUUID) {
            tracker.set(index)
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(item("Set Note for This Desktop", #selector(setNoteForCurrentDesktop)))
        menu.addItem(.separator())
        menu.addItem(item("Grant Accessibility Access", #selector(openAccessibilitySettings)))
        let loginItem = item("Launch at Login", #selector(toggleLaunchAtLogin))
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        // Quit targets the responder chain (NSApp), so it isn't built with `item`.
        menu.addItem(NSMenuItem(title: "Quit Virtual Desktop Badge",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    /// A menu item that targets this delegate.
    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func setNoteForCurrentDesktop() {
        guard let number = tracker.current else { return }
        let alert = NSAlert()
        alert.messageText = "Note for Desktop \(number)"
        alert.informativeText = "Shown next to the number in the menu bar. Leave blank to clear."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = noteStore.note(for: number) ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            noteStore.setNote(field.stringValue, for: number)
            render(number: number)
        }
    }

    /// Disable "Set Note…" until we know which desktop we're on.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(setNoteForCurrentDesktop) {
            return tracker.current != nil
        }
        return true
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
            NSLog("Virtual Desktop Badge: launch-at-login toggle failed: \(error)")
        }
    }
}
