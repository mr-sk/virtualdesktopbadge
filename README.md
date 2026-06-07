# DeskBadge

A tiny macOS menu-bar app that shows **which desktop (Space) you're on** as a number in a small box. No Dock icon, no window — just the number.

macOS has keyboard shortcuts to jump between desktops (`ctrl+1`, `ctrl+2`, …) but gives no on-screen indication of which one you're currently on. DeskBadge fills that gap.

```
┌──┐
│ 2│   ← in your menu bar
└──┘
```

## Features

- **Boxed number** in the menu bar showing the current desktop.
- **Instant updates** when you switch with `ctrl+1` … `ctrl+9`.
- **Self-correcting** after trackpad swipes / Mission Control, via the system space-change notification.
- **Multi-monitor aware** — shows the Space of the screen currently under the mouse.
- **Launch at Login** toggle and **Quit** in a click menu.

## Requirements

- macOS 13 (Ventura) or later
- Xcode command-line tools / Swift 5.9+ (to build)

## Build & Install

```bash
# Build, bundle, and ad-hoc sign into build/DeskBadge.app
./scripts/package_app.sh

# Install it (optional but recommended — Launch at Login is more reliable from /Applications)
cp -R build/DeskBadge.app /Applications/

# Launch
open /Applications/DeskBadge.app
```

### First launch: grant Accessibility access

The `ctrl+N` instant path uses a global key monitor, which macOS gates behind **Accessibility** permission. On first launch DeskBadge prompts for it:

1. **System Settings → Privacy & Security → Accessibility** → enable **DeskBadge**.
2. **Quit and relaunch** the app (the permission only takes effect on a fresh launch).

You can reopen this pane any time from the menu: **Grant Accessibility Access…**

> Without the grant, the badge still updates on trackpad/Mission Control switches (that path needs no permission) — only the keyboard-shortcut path is affected.

## Usage

- Switch desktops however you like; the badge follows.
- Click the badge for the menu:
  - **Grant Accessibility Access…** — opens the relevant Settings pane.
  - **Launch at Login** — start DeskBadge automatically (toggles a checkmark).
  - **Quit DeskBadge**

## How it works

macOS exposes **no public API** for "what Space number am I on," so DeskBadge uses a hybrid of two signals:

1. **Keyboard (instant, no private API):** a global monitor watches for `ctrl`+digit by *physical key code* (layout-independent) and sets the number immediately.
2. **System notification + private API (always correct):** `NSWorkspace.activeSpaceDidChangeNotification` fires on any switch, including swipes. DeskBadge then re-derives the true number from the private `CGSCopyManagedDisplaySpaces` API for the screen under the mouse.

The private API is **isolated to a single file** (`Sources/deskbadge/CGSBridge.swift`). If a future macOS changes it, only that file needs attention — and the keyboard path keeps working regardless.

## Project layout

```
Sources/
  DeskBadgeCore/        # pure, unit-tested logic (no system calls)
    DisplaySpaces.swift   # parse raw CGS data → typed model
    SpaceIndex.swift      # map active space → 1-based desktop number
    SpaceTracker.swift    # current-number state + change callback
    BadgeRenderer.swift   # number → menu-bar image
  deskbadge/            # AppKit executable (the system glue)
    main.swift            # NSApplication bootstrap (.accessory agent)
    AppDelegate.swift     # status item, key monitor, notification, menu
    CGSBridge.swift       # the one file touching the private API
    ScreenInfo.swift      # active screen + its display UUID
Tests/
  DeskBadgeCoreTests/   # XCTest coverage of the pure core
scripts/
  package_app.sh        # build + assemble + sign the .app bundle
docs/
  superpowers/          # design spec and implementation plan
```

## Development

```bash
swift build      # compile
swift test       # run the unit tests (the DeskBadgeCore logic)
```

The pure logic lives in `DeskBadgeCore` precisely so it can be tested without a GUI; the executable target is thin wiring around it.

## Limitations

- The keyboard path covers `ctrl+1` … `ctrl+9` (desktops 1–9). Higher desktops still update via the notification/swipe path.
- The Space-number derivation relies on a private, undocumented macOS API; it may need updating on major macOS releases.

## License

Personal project — do as you like with it.
