/// Single source of truth for the displayed Space number.
public final class SpaceTracker {
    public private(set) var current: Int?
    public var onChange: ((Int) -> Void)?

    public init() {}

    /// Update the current number. Fires `onChange` only on an actual change.
    public func set(_ number: Int) {
        guard number != current else { return }
        current = number
        onChange?(number)
    }
}
