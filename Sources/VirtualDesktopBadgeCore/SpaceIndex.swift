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
