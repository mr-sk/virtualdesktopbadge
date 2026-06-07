/// Formats the list of apps on a desktop into a compact menu-bar label.
public enum AppLabel {
    /// Build a label from app names (frontmost first).
    ///
    /// Shows up to `maxApps` names joined by ", "; if more remain, appends " +N".
    /// The names portion is truncated to `maxChars` (with "…") so the menu bar
    /// stays narrow, while the " +N" suffix is always kept visible.
    public static func format(_ apps: [String], maxApps: Int = 3, maxChars: Int = 28) -> String {
        guard !apps.isEmpty else { return "" }

        let shown = apps.prefix(maxApps)
        var names = shown.joined(separator: ", ")
        if names.count > maxChars {
            names = names.prefix(max(0, maxChars - 1)) + "…"
        }

        let extra = apps.count - shown.count
        return extra > 0 ? "\(names) +\(extra)" : names
    }
}
