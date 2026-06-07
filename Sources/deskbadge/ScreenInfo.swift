import AppKit

enum ScreenInfo {
    /// The display UUID string for a screen, matching CGS "Display Identifier".
    static func displayUUID(for screen: NSScreen) -> String? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return uuidString(for: CGDirectDisplayID(number.uint32Value))
    }

    /// The UUID string of the primary display — the one with the menu bar.
    static func primaryDisplayUUID() -> String? {
        uuidString(for: CGMainDisplayID())
    }

    private static func uuidString(for displayID: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
