import AppKit

enum DesktopApps {
    /// App names with a real on-screen window on the primary display's current
    /// desktop, frontmost first and de-duplicated. Excludes Virtual Desktop Badge itself.
    ///
    /// Uses the public window list, which only reveals windows on the desktop
    /// currently visible on each display — exactly the desktop the badge shows.
    static func current() -> [String] {
        let primary = CGDisplayBounds(CGMainDisplayID())
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else { return [] }

        var names: [String] = []
        for window in windows {
            // Normal application windows only (layer 0 skips the menu bar, Dock, etc.).
            guard (window[kCGWindowLayer as String] as? Int) == 0 else { continue }
            guard let owner = window[kCGWindowOwnerName as String] as? String,
                  !owner.isEmpty, owner != "Virtual Desktop Badge" else { continue }
            // Keep only windows on the primary display (on-screen spans all displays).
            guard let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  primary.contains(CGPoint(x: bounds.midX, y: bounds.midY)) else { continue }
            if !names.contains(owner) { names.append(owner) }
        }
        return names
    }
}
