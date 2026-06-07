import Foundation

/// Minimal persistence backend for notes, so `NoteStore` can be tested with an
/// in-memory implementation instead of the real user defaults.
public protocol KeyValueStore: AnyObject {
    func notesDictionary(forKey key: String) -> [String: String]
    func setNotesDictionary(_ value: [String: String], forKey key: String)
}

extension UserDefaults: KeyValueStore {
    public func notesDictionary(forKey key: String) -> [String: String] {
        (dictionary(forKey: key) as? [String: String]) ?? [:]
    }

    public func setNotesDictionary(_ value: [String: String], forKey key: String) {
        set(value, forKey: key)
    }
}

/// A flat map of desktop number → note, persisted via a `KeyValueStore`.
public final class NoteStore {
    private let store: KeyValueStore
    private let key = "virtualdesktopbadgeNotes"

    public init(store: KeyValueStore) {
        self.store = store
    }

    public func note(for number: Int) -> String? {
        store.notesDictionary(forKey: key)[String(number)]
    }

    /// Save a note for a desktop number. Whitespace is trimmed; a blank or nil
    /// value removes the note entirely.
    public func setNote(_ note: String?, for number: Int) {
        var dict = store.notesDictionary(forKey: key)
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            dict[String(number)] = nil
        } else {
            dict[String(number)] = trimmed
        }
        store.setNotesDictionary(dict, forKey: key)
    }
}
