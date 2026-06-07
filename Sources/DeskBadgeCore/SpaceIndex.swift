/// 1-based position of `activeSpaceID` within the ordered list, or nil if absent.
public func spaceIndex(orderedSpaceIDs: [Int], activeSpaceID: Int) -> Int? {
    guard let idx = orderedSpaceIDs.firstIndex(of: activeSpaceID) else { return nil }
    return idx + 1
}

/// Resolve the 1-based Space number for the active display.
/// Falls back to the first display when the UUID isn't found.
public func resolveIndex(displays: [DisplaySpaces], activeDisplayUUID: String) -> Int? {
    let display = displays.first { $0.uuid == activeDisplayUUID } ?? displays.first
    guard let display, let current = display.currentSpaceID else { return nil }
    return spaceIndex(orderedSpaceIDs: display.orderedSpaceIDs, activeSpaceID: current)
}

/// The 1-based desktop number to display for "the desktop you last switched to".
///
/// With "Displays have separate Spaces", every display sits on its own desktop at
/// once, so we report the display whose current desktop *changed* since the
/// previous reading (`previous` maps display UUID → its last-seen current space id).
/// This deliberately ignores where the mouse is.
///
/// - A display is "changed" only if it was already known in `previous` and its
///   current space id differs — a newly connected display is not treated as a switch.
/// - On the first read (empty `previous`) or when nothing changed, fall back to the
///   focused display, then the first display; returns nil if that yields no value.
public func activeDesktopNumber(
    previous: [String: Int],
    displays: [DisplaySpaces],
    focusedUUID: String?
) -> Int? {
    if !previous.isEmpty {
        for display in displays {
            guard let current = display.currentSpaceID,
                  let prior = previous[display.uuid], prior != current else { continue }
            return spaceIndex(orderedSpaceIDs: display.orderedSpaceIDs, activeSpaceID: current)
        }
        return nil   // no known display changed — keep the current value
    }

    // First read: prefer the focused display, else the first display.
    let chosen = displays.first { $0.uuid == focusedUUID } ?? displays.first
    guard let chosen, let current = chosen.currentSpaceID else { return nil }
    return spaceIndex(orderedSpaceIDs: chosen.orderedSpaceIDs, activeSpaceID: current)
}

/// Snapshot of each display's current desktop, for change detection across reads.
public func currentSpaceSnapshot(_ displays: [DisplaySpaces]) -> [String: Int] {
    var snapshot: [String: Int] = [:]
    for display in displays where display.currentSpaceID != nil {
        snapshot[display.uuid] = display.currentSpaceID
    }
    return snapshot
}
