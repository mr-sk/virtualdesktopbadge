import AppKit
import ServiceManagement

// Headless mode: `DeskBadge --register-login` registers the app as a login item
// (same SMAppService mechanism as the menu toggle) and exits. Run it from the
// installed copy in /Applications so the registration points there.
if CommandLine.arguments.contains("--register-login") {
    do {
        try SMAppService.mainApp.register()
        print("Launch at login enabled (status: \(SMAppService.mainApp.status.rawValue)).")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("Failed to enable launch at login: \(error)\n".utf8))
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon, no main window
app.run()
