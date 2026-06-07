import XCTest
@testable import VirtualDesktopBadgeCore

private final class InMemoryStore: KeyValueStore {
    var data: [String: [String: String]] = [:]
    func notesDictionary(forKey key: String) -> [String: String] { data[key] ?? [:] }
    func setNotesDictionary(_ value: [String: String], forKey key: String) { data[key] = value }
}

final class NoteStoreTests: XCTestCase {
    func test_set_then_get_round_trip() {
        let store = NoteStore(store: InMemoryStore())
        store.setNote("virtualdesktopbadge", for: 7)
        XCTAssertEqual(store.note(for: 7), "virtualdesktopbadge")
    }

    func test_get_is_nil_when_unset() {
        let store = NoteStore(store: InMemoryStore())
        XCTAssertNil(store.note(for: 3))
    }

    func test_set_nil_clears_note() {
        let store = NoteStore(store: InMemoryStore())
        store.setNote("x", for: 2)
        store.setNote(nil, for: 2)
        XCTAssertNil(store.note(for: 2))
    }

    func test_blank_value_clears_note() {
        let store = NoteStore(store: InMemoryStore())
        store.setNote("x", for: 2)
        store.setNote("   ", for: 2)
        XCTAssertNil(store.note(for: 2))
    }

    func test_whitespace_is_trimmed() {
        let store = NoteStore(store: InMemoryStore())
        store.setNote("  hello  ", for: 5)
        XCTAssertEqual(store.note(for: 5), "hello")
    }

    func test_notes_persist_across_instances_sharing_backend() {
        let backend = InMemoryStore()
        NoteStore(store: backend).setNote("work", for: 1)
        XCTAssertEqual(NoteStore(store: backend).note(for: 1), "work")
    }
}
