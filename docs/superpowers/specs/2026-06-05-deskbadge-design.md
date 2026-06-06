# DeskBadge — Design

**Date:** 2026-06-05
**Status:** Approved

## Summary

A tiny macOS menu-bar app (no Dock icon) that displays which desktop/Space the
user is currently on as a number drawn inside a small rounded box. The number is
kept accurate via a hybrid of two signals: the user's existing `ctrl+1`…`ctrl+9`
keypresses (instant, no private API) and the public system space-change
notification (catches trackpad swipes / Mission Control switches), with the true
index re-derived from a private API as a correction step.

## Goals

- Show the current Space number as a box-with-number in the menu bar.
- Update instantly when switching desktops via `ctrl+N`.
- Stay correct after trackpad-swipe / Mission Control switches.
- On multi-display setups, reflect the Space of the **active screen** (the screen
  under the mouse cursor).
- Dead simple: no configuration beyond a Quit and Launch-at-Login menu.

## Non-Goals

- Showing a number per display simultaneously (e.g. `2 | 4`). Active screen only.
- Renaming spaces, switching spaces, or any Mission Control management.
- App Store distribution / notarization (personal local build only).

## Architecture

A single lightweight agent app:

- `LSUIElement = true` — no Dock icon, no main window.
- Three focused units, each independently understandable and (where possible)
  testable.

### Units

**1. `SpaceTracker`** — owns the single source of truth: "what number are we on."
Two inputs feed it:

- A **global key monitor** for `ctrl+1`…`ctrl+9`. On a match it sets the number
  *instantly* — no private API, zero lag.
- The public **`NSWorkspace.activeSpaceDidChangeNotification`** — fires on *any*
  switch including trackpad swipe and Mission Control. On fire it asks
  `SpaceResolver` for the true number and corrects the displayed value.

When the value changes, `SpaceTracker` notifies `BadgeView` to redraw.

**2. `SpaceResolver`** — the "always correct" fallback, and the *only* unit that
touches undocumented API (isolated by design).

- Determines the **active display**: the `NSScreen` containing the current mouse
  location (`NSEvent.mouseLocation`).
- Maps that display's current space to a **1-based index** by reading the ordered
  space list for the display (via the private `CGS`/SkyLight layer and/or the
  `com.apple.spaces` defaults) and finding the position of the active space id.
- Exposes a pure function: `index(orderedSpaceIDs:, activeSpaceID:) -> Int`,
  separated from the system-data-fetching so it can be unit-tested.

**3. `BadgeView`** — rendering only.

- Draws a rounded box with the number centered, into an `NSImage`, and sets it as
  the `NSStatusItem` button image.
- Click opens a minimal menu: **Launch at Login** (toggle via `SMAppService`) and
  **Quit**.

## Data Flow

```
ctrl+N pressed
  -> global key monitor
  -> SpaceTracker.set(N)
  -> BadgeView.redraw

swipe / Mission Control switch
  -> NSWorkspace.activeSpaceDidChangeNotification
  -> SpaceResolver.currentIndex()   (active screen -> 1-based index)
  -> SpaceTracker.set(index)
  -> BadgeView.redraw
```

## Key Technical Decisions & Constraints

- **No public API for the current Space index.** macOS does not expose it. Hence
  the hybrid: keypresses give an instant, API-free signal; the notification +
  private resolver keep it honest after non-keyboard switches.
- **Accessibility permission required** for global key monitoring. The app detects
  whether permission is granted on launch and prompts the user to grant it in
  System Settings; until granted, the keypress path is inactive but the
  notification path still works.
- **Private API risk is contained.** If a future macOS breaks the private space
  enumeration, only `SpaceResolver` needs changing, and the badge still updates on
  `ctrl+N` (it just won't self-correct after a swipe until fixed).
- **Index meaning is consistent.** "Desktop N" is the Nth space in macOS's ordered
  list for the display — exactly what `ctrl+N` maps to — so the keypress path and
  the resolver path agree.

## Error Handling

- Accessibility not granted: show the badge anyway (driven by the notification
  path); surface a one-time prompt and a menu item linking to the Settings pane.
- Private API returns nothing / unexpected data: keep the last known number rather
  than showing a wrong/blank value; log for diagnosis.
- Unknown / out-of-range index: fall back to the last keypress value.

## Testing

- **Unit tests:** `SpaceResolver.index(orderedSpaceIDs:, activeSpaceID:)` — pure
  logic, tested by injecting a fake ordered list + active id and asserting the
  number, including edge cases (active id missing, single space, many spaces).
- **Manual verification:** key monitoring, the space-change notification, active-
  display selection across two monitors, and badge rendering — all inherently
  system-level.

## Packaging

- Xcode project producing a `.app`.
- `LSUIElement = true`.
- Locally signed with the user's own signing identity; no notarization (personal
  use).
- Launch at Login via `SMAppService`.
- Project location: `~/Research/DeskBadge`.
