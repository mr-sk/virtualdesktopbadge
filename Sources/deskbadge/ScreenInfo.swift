import AppKit

enum ScreenInfo {
    /// The screen currently under the mouse cursor (the "active" screen),
    /// falling back to the main screen.
    static func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
    }

    /// The display UUID string for a screen, matching CGS "Display Identifier".
    static func displayUUID(for screen: NSScreen) -> String? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        let displayID = CGDirectDisplayID(number.uint32Value)
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    /// Convenience: UUID of the active screen.
    static func activeDisplayUUID() -> String? {
        guard let screen = activeScreen() else { return nil }
        return displayUUID(for: screen)
    }
}
