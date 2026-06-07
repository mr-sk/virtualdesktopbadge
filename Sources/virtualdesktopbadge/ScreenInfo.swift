import AppKit

enum ScreenInfo {
    /// The UUID string of the primary display — the one with the menu bar.
    /// Matches the "Display Identifier" returned by `CGSCopyManagedDisplaySpaces`.
    static func primaryDisplayUUID() -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(CGMainDisplayID())?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
