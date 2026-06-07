import AppKit
import ApplicationServices
import ServiceManagement
import DeskBadgeCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let tracker = SpaceTracker()
    private var keyMonitor: Any?
    private let noteStore = NoteStore(store: UserDefaults.standard)
    private static let digitKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
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

    /// Draw the number box and show the desktop's note as the button title.
    private func render(number: Int) {
        statusItem.button?.image = BadgeRenderer.image(forNumber: number)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.title = noteStore.note(for: number).map { " \($0)" } ?? ""
    }

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
        let noteItem = NSMenuItem(
            title: "Set Note for This Desktop\u{2026}",
            action: #selector(setNoteForCurrentDesktop),
            keyEquivalent: ""
        )
        noteItem.target = self
        menu.addItem(noteItem)
        menu.addItem(.separator())
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
            NSLog("DeskBadge: launch-at-login toggle failed: \(error)")
        }
    }
}
