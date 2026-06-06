# DeskBadge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS menu-bar app (no Dock icon) that shows the current desktop/Space number in a small rounded box, kept accurate via `ctrl+N` keypresses plus the system space-change notification.

**Architecture:** A Swift Package Manager project with a testable pure-logic library (`DeskBadgeCore`) and a thin AppKit executable (`deskbadge`) that wires up an `NSStatusItem`, a global key monitor, the `NSWorkspace` space-change notification, and a private CoreGraphics (CGS) bridge for the always-correct fallback. The executable runs as an `.accessory` agent; a packaging task wraps it in a `.app` bundle for Launch-at-Login.

**Tech Stack:** Swift 5.9+, Swift Package Manager, AppKit, XCTest, ServiceManagement (`SMAppService`), private `CGSCopyManagedDisplaySpaces` API. macOS 13+.

---

## File Structure

```
~/Research/DeskBadge/
  Package.swift
  Sources/
    DeskBadgeCore/                 # pure, testable logic
      DisplaySpaces.swift          # model + parseDisplaySpaces()
      SpaceIndex.swift             # spaceIndex(), resolveIndex()
      SpaceTracker.swift           # state holder with onChange callback
      BadgeRenderer.swift          # number -> NSImage
    deskbadge/                     # AppKit executable (system glue)
      main.swift                   # NSApplication bootstrap (.accessory)
      AppDelegate.swift            # status item, monitor, notification, menu
      CGSBridge.swift              # private API fetch -> raw dictionaries
      ScreenInfo.swift             # active screen + display UUID
  Tests/
    DeskBadgeCoreTests/
      DisplaySpacesTests.swift
      SpaceIndexTests.swift
      SpaceTrackerTests.swift
      BadgeRendererTests.swift
  scripts/
    package_app.sh                 # assemble + sign the .app bundle
```

Each `DeskBadgeCore` file has one responsibility and is unit-tested. All
system-touching, untestable code lives in the `deskbadge` target.

---

### Task 1: Scaffold the Swift package

**Files:**
- Create: `Package.swift`
- Create: `Sources/DeskBadgeCore/Placeholder.swift`
- Create: `Sources/deskbadge/main.swift`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeskBadge",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "DeskBadgeCore"),
        .executableTarget(
            name: "deskbadge",
            dependencies: ["DeskBadgeCore"]
        ),
        .testTarget(
            name: "DeskBadgeCoreTests",
            dependencies: ["DeskBadgeCore"]
        ),
    ]
)
```

- [ ] **Step 2: Create a temporary placeholder so the library compiles**

`Sources/DeskBadgeCore/Placeholder.swift`:

```swift
public enum DeskBadgeCore {}
```

- [ ] **Step 3: Create a minimal executable entry point**

`Sources/deskbadge/main.swift`:

```swift
import DeskBadgeCore

print("DeskBadge starting")
```

- [ ] **Step 4: Build to verify the package is valid**

Run: `cd ~/Research/DeskBadge && swift build`
Expected: `Build complete!` with no errors.

- [ ] **Step 5: Commit**

```bash
cd ~/Research/DeskBadge
git add Package.swift Sources
git commit -m "chore: scaffold Swift package"
```

---

### Task 2: Display-spaces model and parser

Parses the raw dictionary array returned by the private CGS API into typed
structs. Pure function — fully unit-testable with fake input.

**Files:**
- Create: `Sources/DeskBadgeCore/DisplaySpaces.swift`
- Test: `Tests/DeskBadgeCoreTests/DisplaySpacesTests.swift`
- Delete: `Sources/DeskBadgeCore/Placeholder.swift`

- [ ] **Step 1: Write the failing test**

`Tests/DeskBadgeCoreTests/DisplaySpacesTests.swift`:

```swift
import XCTest
@testable import DeskBadgeCore

final class DisplaySpacesTests: XCTestCase {
    func test_parses_uuid_ordered_ids_and_current() {
        let raw: [[String: Any]] = [
            [
                "Display Identifier": "DISPLAY-A",
                "Current Space": ["ManagedSpaceID": 7],
                "Spaces": [
                    ["ManagedSpaceID": 5],
                    ["ManagedSpaceID": 7],
                    ["ManagedSpaceID": 9],
                ],
            ]
        ]
        let parsed = parseDisplaySpaces(raw)
        XCTAssertEqual(parsed, [
            DisplaySpaces(uuid: "DISPLAY-A",
                          orderedSpaceIDs: [5, 7, 9],
                          currentSpaceID: 7)
        ])
    }

    func test_skips_entries_without_display_identifier() {
        let raw: [[String: Any]] = [["Spaces": []]]
        XCTAssertEqual(parseDisplaySpaces(raw), [])
    }

    func test_falls_back_to_id64_when_managed_id_absent() {
        let raw: [[String: Any]] = [
            [
                "Display Identifier": "DISPLAY-B",
                "Current Space": ["id64": 42],
                "Spaces": [["id64": 42]],
            ]
        ]
        XCTAssertEqual(parseDisplaySpaces(raw), [
            DisplaySpaces(uuid: "DISPLAY-B", orderedSpaceIDs: [42], currentSpaceID: 42)
        ])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/Research/DeskBadge && swift test --filter DisplaySpacesTests`
Expected: FAIL — `cannot find 'parseDisplaySpaces' in scope` / `DisplaySpaces` not found.

- [ ] **Step 3: Write the implementation**

`Sources/DeskBadgeCore/DisplaySpaces.swift`:

```swift
import Foundation

/// One physical display and the ordered Spaces that belong to it.
public struct DisplaySpaces: Equatable {
    public let uuid: String
    public let orderedSpaceIDs: [Int]
    public let currentSpaceID: Int?

    public init(uuid: String, orderedSpaceIDs: [Int], currentSpaceID: Int?) {
        self.uuid = uuid
        self.orderedSpaceIDs = orderedSpaceIDs
        self.currentSpaceID = currentSpaceID
    }
}

private func spaceID(_ dict: [String: Any]) -> Int? {
    (dict["ManagedSpaceID"] as? Int) ?? (dict["id64"] as? Int)
}

/// Parse the raw array produced by `CGSCopyManagedDisplaySpaces` into typed models.
public func parseDisplaySpaces(_ raw: [[String: Any]]) -> [DisplaySpaces] {
    raw.compactMap { entry in
        guard let uuid = entry["Display Identifier"] as? String else { return nil }
        let spaces = (entry["Spaces"] as? [[String: Any]]) ?? []
        let ids = spaces.compactMap(spaceID)
        let current = (entry["Current Space"] as? [String: Any]).flatMap(spaceID)
        return DisplaySpaces(uuid: uuid, orderedSpaceIDs: ids, currentSpaceID: current)
    }
}
```

- [ ] **Step 4: Delete the placeholder**

```bash
rm ~/Research/DeskBadge/Sources/DeskBadgeCore/Placeholder.swift
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd ~/Research/DeskBadge && swift test --filter DisplaySpacesTests`
Expected: PASS — 3 tests pass.

- [ ] **Step 6: Commit**

```bash
cd ~/Research/DeskBadge
git add Sources/DeskBadgeCore Tests
git rm --cached Sources/DeskBadgeCore/Placeholder.swift 2>/dev/null; true
git commit -am "feat: display-spaces model and parser"
```

---

### Task 3: Space-index logic

Two pure functions: position of the active space within one display, and the
display-selection + index resolution across all displays.

**Files:**
- Create: `Sources/DeskBadgeCore/SpaceIndex.swift`
- Test: `Tests/DeskBadgeCoreTests/SpaceIndexTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/DeskBadgeCoreTests/SpaceIndexTests.swift`:

```swift
import XCTest
@testable import DeskBadgeCore

final class SpaceIndexTests: XCTestCase {
    func test_index_is_one_based_position() {
        XCTAssertEqual(spaceIndex(orderedSpaceIDs: [5, 7, 9], activeSpaceID: 7), 2)
        XCTAssertEqual(spaceIndex(orderedSpaceIDs: [5, 7, 9], activeSpaceID: 5), 1)
    }

    func test_index_nil_when_active_not_in_list() {
        XCTAssertNil(spaceIndex(orderedSpaceIDs: [5, 7], activeSpaceID: 99))
    }

    func test_resolve_uses_matching_display() {
        let displays = [
            DisplaySpaces(uuid: "A", orderedSpaceIDs: [1, 2], currentSpaceID: 2),
            DisplaySpaces(uuid: "B", orderedSpaceIDs: [3, 4, 5], currentSpaceID: 5),
        ]
        XCTAssertEqual(resolveIndex(displays: displays, activeDisplayUUID: "B"), 3)
    }

    func test_resolve_falls_back_to_first_display_when_uuid_unknown() {
        let displays = [
            DisplaySpaces(uuid: "A", orderedSpaceIDs: [1, 2], currentSpaceID: 2),
        ]
        XCTAssertEqual(resolveIndex(displays: displays, activeDisplayUUID: "ZZZ"), 2)
    }

    func test_resolve_nil_when_no_displays() {
        XCTAssertNil(resolveIndex(displays: [], activeDisplayUUID: "A"))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/Research/DeskBadge && swift test --filter SpaceIndexTests`
Expected: FAIL — `cannot find 'spaceIndex' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/DeskBadgeCore/SpaceIndex.swift`:

```swift
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/Research/DeskBadge && swift test --filter SpaceIndexTests`
Expected: PASS — 5 tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/Research/DeskBadge
git add Sources/DeskBadgeCore/SpaceIndex.swift Tests/DeskBadgeCoreTests/SpaceIndexTests.swift
git commit -m "feat: space-index resolution logic"
```

---

### Task 4: SpaceTracker state holder

Holds the current number and fires `onChange` only when the value actually
changes (prevents redundant redraws). Pure, testable.

**Files:**
- Create: `Sources/DeskBadgeCore/SpaceTracker.swift`
- Test: `Tests/DeskBadgeCoreTests/SpaceTrackerTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/DeskBadgeCoreTests/SpaceTrackerTests.swift`:

```swift
import XCTest
@testable import DeskBadgeCore

final class SpaceTrackerTests: XCTestCase {
    func test_set_updates_current_and_fires_callback() {
        let tracker = SpaceTracker()
        var fired: [Int] = []
        tracker.onChange = { fired.append($0) }

        tracker.set(3)
        XCTAssertEqual(tracker.current, 3)
        XCTAssertEqual(fired, [3])
    }

    func test_set_same_value_does_not_fire_again() {
        let tracker = SpaceTracker()
        var count = 0
        tracker.onChange = { _ in count += 1 }

        tracker.set(2)
        tracker.set(2)
        XCTAssertEqual(count, 1)
    }

    func test_set_different_values_fires_each_time() {
        let tracker = SpaceTracker()
        var fired: [Int] = []
        tracker.onChange = { fired.append($0) }

        tracker.set(1)
        tracker.set(2)
        tracker.set(1)
        XCTAssertEqual(fired, [1, 2, 1])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/Research/DeskBadge && swift test --filter SpaceTrackerTests`
Expected: FAIL — `cannot find 'SpaceTracker' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/DeskBadgeCore/SpaceTracker.swift`:

```swift
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/Research/DeskBadge && swift test --filter SpaceTrackerTests`
Expected: PASS — 3 tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/Research/DeskBadge
git add Sources/DeskBadgeCore/SpaceTracker.swift Tests/DeskBadgeCoreTests/SpaceTrackerTests.swift
git commit -m "feat: SpaceTracker state holder"
```

---

### Task 5: Badge renderer

Draws a rounded box with the number centered, as a template `NSImage` so it
adapts to light/dark menu bars.

**Files:**
- Create: `Sources/DeskBadgeCore/BadgeRenderer.swift`
- Test: `Tests/DeskBadgeCoreTests/BadgeRendererTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/DeskBadgeCoreTests/BadgeRendererTests.swift`:

```swift
import XCTest
import AppKit
@testable import DeskBadgeCore

final class BadgeRendererTests: XCTestCase {
    func test_produces_square_template_image_of_requested_size() {
        let image = BadgeRenderer.image(forNumber: 4, size: 18)
        XCTAssertEqual(image.size.width, 18, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 18, accuracy: 0.5)
        XCTAssertTrue(image.isTemplate)
    }

    func test_handles_multi_digit_numbers() {
        let image = BadgeRenderer.image(forNumber: 12, size: 18)
        XCTAssertEqual(image.size.width, 18, accuracy: 0.5)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/Research/DeskBadge && swift test --filter BadgeRendererTests`
Expected: FAIL — `cannot find 'BadgeRenderer' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/DeskBadgeCore/BadgeRenderer.swift`:

```swift
import AppKit

/// Renders a Space number into a small rounded-box template image.
public enum BadgeRenderer {
    public static func image(forNumber number: Int, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let inset: CGFloat = 1.5
        let boxRect = NSRect(x: inset, y: inset,
                             width: size - inset * 2, height: size - inset * 2)
        let box = NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4)
        box.lineWidth = 1.5
        NSColor.black.setStroke()
        box.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size * 0.55, weight: .bold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph,
        ]
        let text = "\(number)" as NSString
        let textSize = text.size(withAttributes: attributes)
        let origin = NSPoint(x: (size - textSize.width) / 2,
                             y: (size - textSize.height) / 2)
        text.draw(at: origin, withAttributes: attributes)

        image.unlockFocus()
        image.isTemplate = true   // tint follows the menu bar appearance
        return image
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/Research/DeskBadge && swift test --filter BadgeRendererTests`
Expected: PASS — 2 tests pass.

- [ ] **Step 5: Run the full suite**

Run: `cd ~/Research/DeskBadge && swift test`
Expected: PASS — all tests across all files pass.

- [ ] **Step 6: Commit**

```bash
cd ~/Research/DeskBadge
git add Sources/DeskBadgeCore/BadgeRenderer.swift Tests/DeskBadgeCoreTests/BadgeRendererTests.swift
git commit -m "feat: badge renderer"
```

---

### Task 6: CGS bridge (private API fetch)

The single file touching undocumented API. Fetches the raw managed-display-spaces
array; `parseDisplaySpaces` (Task 2) turns it into models. Not unit-tested
(system-dependent) — verified manually in Task 9.

**Files:**
- Create: `Sources/deskbadge/CGSBridge.swift`

- [ ] **Step 1: Write the implementation**

`Sources/deskbadge/CGSBridge.swift`:

```swift
import Foundation

typealias CGSConnectionID = UInt32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ connection: CGSConnectionID) -> CFArray

/// Fetch the raw per-display spaces description from the WindowServer.
/// Returns an empty array if the private call yields an unexpected shape.
func rawManagedDisplaySpaces() -> [[String: Any]] {
    let connection = CGSMainConnectionID()
    let result = CGSCopyManagedDisplaySpaces(connection)
    return (result as? [[String: Any]]) ?? []
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd ~/Research/DeskBadge && swift build`
Expected: `Build complete!` (warnings about private symbols are acceptable; errors are not).

- [ ] **Step 3: Commit**

```bash
cd ~/Research/DeskBadge
git add Sources/deskbadge/CGSBridge.swift
git commit -m "feat: private CGS bridge for managed display spaces"
```

---

### Task 7: Screen info (active display + UUID)

Determines which screen the mouse is on and that screen's display UUID string,
which matches the `Display Identifier` from the CGS bridge. System-dependent —
not unit-tested.

**Files:**
- Create: `Sources/deskbadge/ScreenInfo.swift`

- [ ] **Step 1: Write the implementation**

`Sources/deskbadge/ScreenInfo.swift`:

```swift
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
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd ~/Research/DeskBadge && swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
cd ~/Research/DeskBadge
git add Sources/deskbadge/ScreenInfo.swift
git commit -m "feat: active screen and display UUID lookup"
```

---

### Task 8: App delegate — status item, key monitor, notification, menu

Wires everything together. System glue — verified manually in Task 9.

**Files:**
- Create: `Sources/deskbadge/AppDelegate.swift`
- Modify: `Sources/deskbadge/main.swift`

- [ ] **Step 1: Replace `main.swift` with the NSApplication bootstrap**

`Sources/deskbadge/main.swift`:

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon, no main window
app.run()
```

- [ ] **Step 2: Write the app delegate**

`Sources/deskbadge/AppDelegate.swift`:

```swift
import AppKit
import ServiceManagement
import DeskBadgeCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let tracker = SpaceTracker()
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = BadgeRenderer.image(forNumber: 0)

        tracker.onChange = { [weak self] number in
            self?.statusItem.button?.image = BadgeRenderer.image(forNumber: number)
        }

        buildMenu()
        startKeyMonitor()
        observeSpaceChanges()
        refreshFromSystem()   // initial value
    }

    // MARK: - Inputs

    /// Instant path: react to ctrl+1...ctrl+9.
    private func startKeyMonitor() {
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.control) else { return }
            guard let chars = event.charactersIgnoringModifiers,
                  let number = Int(chars), (1...9).contains(number) else { return }
            self?.tracker.set(number)
        }
    }

    /// Correction path: any space change (incl. swipe / Mission Control).
    private func observeSpaceChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func spaceChanged() {
        refreshFromSystem()
    }

    /// Re-derive the true number via the private API for the active display.
    private func refreshFromSystem() {
        let displays = parseDisplaySpaces(rawManagedDisplaySpaces())
        let uuid = ScreenInfo.activeDisplayUUID() ?? ""
        if let index = resolveIndex(displays: displays, activeDisplayUUID: uuid) {
            tracker.set(index)
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit DeskBadge",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                sender.state = .off
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on
            }
        } catch {
            NSLog("DeskBadge: launch-at-login toggle failed: \(error)")
        }
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `cd ~/Research/DeskBadge && swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
cd ~/Research/DeskBadge
git add Sources/deskbadge/AppDelegate.swift Sources/deskbadge/main.swift
git commit -m "feat: app delegate wiring status item, key monitor, and notification"
```

---

### Task 9: Package into a `.app` bundle and verify manually

`SMAppService` and Accessibility permission need a real bundle with an
`Info.plist`. This script assembles one from the SPM binary and ad-hoc signs it.

**Files:**
- Create: `scripts/package_app.sh`

- [ ] **Step 1: Write the packaging script**

`scripts/package_app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release

APP="build/DeskBadge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp ".build/release/deskbadge" "$APP/Contents/MacOS/DeskBadge"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>DeskBadge</string>
  <key>CFBundleDisplayName</key><string>DeskBadge</string>
  <key>CFBundleIdentifier</key><string>com.local.deskbadge</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key><string>DeskBadge</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"
```

- [ ] **Step 2: Make it executable and run it**

```bash
cd ~/Research/DeskBadge
chmod +x scripts/package_app.sh
./scripts/package_app.sh
```

Expected: `Built build/DeskBadge.app` with no errors.

- [ ] **Step 3: Launch the app**

```bash
open ~/Research/DeskBadge/build/DeskBadge.app
```

Expected: a small boxed number appears in the menu bar. (It may read `0` until
the first space change or keypress.)

- [ ] **Step 4: Grant Accessibility permission**

Open **System Settings → Privacy & Security → Accessibility**, enable
**DeskBadge**, then quit and relaunch the app (via the menu's *Quit*, then
`open` again). This activates the `ctrl+N` instant path.

- [ ] **Step 5: Manual verification checklist**

Confirm each, by observing the menu-bar box:
- Press `ctrl+1`, `ctrl+2`, `ctrl+3` → number updates instantly to 1, 2, 3.
- Swipe between desktops with the trackpad (or Mission Control) → number
  self-corrects to the new desktop.
- On a second monitor, move the mouse to that screen and switch its space → the
  number reflects the screen under the mouse.
- Click the menu-bar item → menu shows **Launch at Login** and **Quit**.
- Toggle **Launch at Login** on → checkmark appears; verify it shows under
  System Settings → General → Login Items. Toggle off → checkmark clears.

- [ ] **Step 6: Commit**

```bash
cd ~/Research/DeskBadge
git add scripts/package_app.sh
git commit -m "build: package script for .app bundle and login-item support"
```

---

## Self-Review Notes

- **Spec coverage:** box-with-number badge (Task 5), instant `ctrl+N` path
  (Task 8), swipe correction via notification + private API (Tasks 6–8),
  multi-display active-screen resolution (Tasks 3, 7), Accessibility prompt
  (Task 9 manual grant), Launch at Login via `SMAppService` (Tasks 8–9), private
  API isolated to one file (Task 6), unit-tested pure core (Tasks 2–5),
  `LSUIElement`/`.accessory` agent (Tasks 8–9), location `~/Research/DeskBadge`. All
  spec sections map to a task.
- **Naming consistency:** `parseDisplaySpaces`, `DisplaySpaces`, `spaceIndex`,
  `resolveIndex`, `SpaceTracker.set/onChange/current`, `BadgeRenderer.image`,
  `rawManagedDisplaySpaces`, `ScreenInfo.activeDisplayUUID` are used identically
  across producing and consuming tasks.
- **Known deviation from spec:** the explicit programmatic Accessibility *prompt*
  (`AXIsProcessTrustedWithOptions`) is handled as a manual grant step in Task 9
  to keep the agent code minimal (YAGNI); the notification path works without it,
  so the app is useful before the grant. Revisit if an in-app prompt is wanted.
```
