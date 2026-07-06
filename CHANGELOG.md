# Changelog

All notable changes to SnapBack are documented here. Every release must have
an entry — the release workflow refuses to ship a tag that has no section in
this file or whose version doesn't match `obj.version` in the Spoon.

## v0.6.0 — 2026-07-06

### Added
- **Auto-restore on dock, undock, and wake**: display changes are debounced
  and the matching profile is restored per the Auto-Restore Mode setting
  (Automatic / Prompt / Disabled) — the setting previously had no effect.
- **Menubar minimap**: the dropdown opens with a to-scale map of the current
  display arrangement with the active profile's saved windows drawn in;
  clicking it restores the profile.
- **Cyclic snapping walks screens column by column**: pressing Left/Right on
  an already-snapped window carries it to the *near* half of the adjacent
  screen, so repeated presses traverse the whole setup half-by-half.
- **Hotkeys cheat sheet** in the menubar, derived from the action registry.
- **One-line installer** (`scripts/install.sh`).
- CI: syntax check + 59-test plain-Lua suite on every push and PR.

### Changed
- **Rebranded AutoArrange → SnapBack**: new URL scheme `hammerspoon://snapback`
  (legacy `windowlayout` still works), storage moved to `~/.hammerspoon/snapback/`
  with automatic one-time migration, menubar `SB:`.
- Internals split into focused modules (profile store, snap geometry, smart
  matching, action registry, minimap) with the pure logic under test.

### Fixed
- Menubar menu no longer freezes into a static snapshot after changing
  Auto-Restore mode.
- Up/Down hotkeys now snap to top/bottom halves, matching the menu (they
  previously maximized/minimized while the menu items snapped).
- Fuzzy window matching no longer lets titles that normalize to nothing
  (clocks, counters) match any window at high confidence.
- All `hs.spaces` calls are guarded — Spaces trouble on newer macOS degrades
  a restore instead of aborting it, and failures are reported in the alert.
- Switching profiles validates the name, so a Stream Deck URL typo can't
  activate a brand-new empty profile.
- Snap-cycle detection uses a sub-second clock; the 2-second window is real.
- Removed the disabled drag-to-edge watcher (unsafe as written) and the
  broken "Edit Config File..." menu item (now "Open Data Folder...").

## v0.5.0 — 2026-04-21

Initial public release (as AutoArrange).

- Window snapping: halves, quarters, thirds, two-thirds, center, maximize.
- Layout profiles per display configuration with save/restore and
  best-effort Spaces support.
- Stream Deck / automation via `hammerspoon://windowlayout` URLs.
- GitHub Actions release workflow packaging the Spoon.
