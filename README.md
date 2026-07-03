# SnapBack

**Your windows, back where they belong.**

You unplug your MacBook from your monitors and every window piles onto the laptop screen. You plug back in — or your displays simply wake from sleep — and macOS has shuffled everything. SnapBack fixes that: it remembers a window layout for **every display setup** you use (desk, office, laptop-only) and puts everything back automatically when your screens change.

Built on [Hammerspoon](https://www.hammerspoon.org/). Free and open source.

## Why SnapBack

* **Layout profiles per display setup**: Each monitor configuration gets its own saved layouts. Multiple named profiles per setup (e.g. "Coding", "Meeting").
* **Auto-restore on dock, undock, and wake**: When your display configuration changes, SnapBack restores the matching layout — automatically, after a prompt, or never (your choice, in the menubar).
* **Smart window matching**: Finds your windows even when titles change (Chrome tabs, editors), falling back from exact ID → title → fuzzy → same-app matching.
* **Snapping included**: Halves, thirds, two-thirds, quarters, center, maximize — with hotkeys and a menubar menu. Press Left/Right twice to throw a window to the previous/next screen. Zero animation delay.
* **Automation-friendly**: Trigger everything from a Stream Deck, Shortcuts, or scripts via `hammerspoon://` URLs.
* **Spaces support (best-effort)**: Attempts to remember which Space a window belongs to. macOS APIs for Spaces are private and can be unreliable on recent macOS versions.

## Installation

1. Install [Hammerspoon](https://www.hammerspoon.org/) and grant it Accessibility permission (System Settings → Privacy & Security → Accessibility).
2. Download **SnapBack.spoon.zip** from the [latest release](https://github.com/jamesagarside/snapback-macos/releases) and unzip it.
3. Double-click `SnapBack.spoon` (Hammerspoon installs it), or move it to `~/.hammerspoon/Spoons/` manually.
4. Add this to your `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("SnapBack")
spoon.SnapBack:start()
```

5. Reload Hammerspoon.

## Quick start (the travel workflow)

1. At your desk with everything plugged in, arrange your windows how you like them.
2. Press `⌃⌥⌘ S` (or menubar **SB** → *Save Current Layout*).
3. That's it. Unplug, work from the sofa, plug back in — SnapBack notices the displays returned and puts every window back. Do the same once for your laptop-only layout and it restores that when you undock, too.

Auto-restore behaviour is configurable under **SB → Auto-Restore Mode**: *Automatic*, *Prompt* (ask first), or *Disabled* (restore manually with `⌃⌥⌘ ⌫`).

## Hotkeys

Default base modifiers: **⌃⌥⌘** (Ctrl + Alt + Cmd) — customizable via **SB → Set Base Modifiers...**.

| Action | Key | Description |
| :--- | :--- | :--- |
| **Save Layout** | `S` | Save current window positions to the active profile |
| **Restore Layout** | `R` or `⌫` | Restore the active profile |
| **Left / Right Half** | `←` / `→` | Snap to half; press twice to move to prev/next screen |
| **Maximize / Minimize** | `↑` / `↓` | Maximize or minimize the focused window |
| **Corners** | `U` `I` `J` `K` | Top-left / top-right / bottom-left / bottom-right quarter |
| **Thirds** | `D` `F` `G` | Left / center / right third |
| **Two-Thirds** | `E` `T` | Left / right two-thirds |
| **Center** | `C` | Center window at 70% size |
| **Maximize** | `⏎` | Full screen frame |

## Automation / Stream Deck

| Action | URL |
| :--- | :--- |
| Restore active profile | `hammerspoon://snapback?action=restore` |
| Switch to profile and restore | `hammerspoon://snapback?action=restore&profile=Name` |
| Save active profile | `hammerspoon://snapback?action=save` |
| Save to a named profile | `hammerspoon://snapback?action=save&profile=Name` |
| List profiles | `hammerspoon://snapback?action=list` |

(The legacy `hammerspoon://windowlayout` scheme still works.)

## Data & privacy

Layouts and settings are stored as plain JSON in `~/.hammerspoon/snapback/` (menubar → *Open Data Folder...*). Nothing leaves your machine.

## Compatibility & known limitations

* **macOS**: Tested on macOS Sonoma. Accessibility permission required (it's how any window manager moves windows).
* **Spaces**: Moving windows between Spaces relies on private macOS APIs and may fail silently on some macOS versions; windows on non-visible Spaces may not be capturable.
* **Display identity**: Profiles are currently keyed by display IDs that can occasionally change across reboots; migration to stable UUIDs is planned.

## Alternatives

If you only need snapping, [Rectangle](https://rectangleapp.com/) is excellent and simpler to install. SnapBack is for people whose window arrangements get destroyed by docking/undocking/display sleep and who want them to come back on their own — plus Stream Deck/URL automation and the hackability of Hammerspoon underneath.

## License

Apache-2.0 — see [LICENSE](LICENSE).
