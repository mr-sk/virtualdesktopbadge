import AppKit
import ServiceManagement
import DeskBadgeCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let tracker = SpaceTracker()
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = BadgeRenderer.image(forNumber: 0)

        tracker.onChange = { [weak self] number in
            self?.statusItem.button?.image = BadgeRenderer.image(forNumber: number)
        }

        buildMenu()
        startKeyMonitor()
        observeSpaceChanges()
        refreshFromSystem()   // initial value
    }

    // MARK: - Inputs

    /// Instant path: react to ctrl+1...ctrl+9.
    private func startKeyMonitor() {
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.control) else { return }
            guard let chars = event.charactersIgnoringModifiers,
                  let number = Int(chars), (1...9).contains(number) else { return }
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

    /// Re-derive the true number via the private API for the active display.
    private func refreshFromSystem() {
        let displays = parseDisplaySpaces(rawManagedDisplaySpaces())
        let uuid = ScreenInfo.activeDisplayUUID() ?? ""
        if let index = resolveIndex(displays: displays, activeDisplayUUID: uuid) {
            tracker.set(index)
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
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
