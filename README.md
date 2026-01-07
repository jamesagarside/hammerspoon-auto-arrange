# AutoArrange Spoon

A powerful window management tool for macOS using Hammerspoon. It combines advanced window snapping with a robust Layout Manager that saves and restores window positions across multiple monitors and Spaces (Virtual Desktops).

## Key Features

*   **Advanced Snapping**: Snap windows to halves, thirds, quarters, and corners using familiar hotkeys.
*   **Multi-Monitor Layouts**: Automatically detects your display setup (e.g., "Home" vs "Work") and restores the correct windows.
*   **Space-Aware**: Remembers which Space (Virtual Desktop) a window belongs to and puts it back there.
*   **Smart Matching**: Logic to find windows even if their titles change (e.g., Chrome tabs) or just by App Name.
*   **Stream Deck API**: Control everything via `hammerspoon://` URLs.
*   **Performance**: Instant snapping (zero animation).

## Installation

1.  Download **AutoArrange.spoon** (or clone this repo).
2.  Double-click `AutoArrange.spoon` to install it (Hammerspoon will handle this).
3.  Or manually move it to `~/.hammerspoon/Spoons/`.
4.  Add this to your `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("AutoArrange")
spoon.AutoArrange:start()
```

5.  Reload Hammerspoon.

## Usage

### 1. Menubar & Configuration
Click the **"WL"** icon in the menubar to access all features.
*   **Visual Shortcuts**: See the hotkeys for every snapping action directly in the menu.
*   **Settings**: Go to `Configuration ▶ Set Base Modifiers...` to customize your hotkey combo (default: `Ctrl + Alt`).
*   **Profiles**: Save multiple layouts per screen setup (e.g., "Coding", "Meeting").

### 2. Hotkeys
Default Base: **Ctrl + Alt** (customizable).

| Action | Key | Description |
| :--- | :--- | :--- |
| **Left / Right** | `←` / `→` | Snap to Left/Right Half |
| **Top / Bottom** | `↑` / `↓` | Maximize / Minimize |
| **Corners** | `U` `I` `J` `K` | Top-Left / Top-Right / Bottom-Left / Bottom-Right |
| **Thirds** | `D` `F` `G` | Left / Center / Right Third |
| **Two-Thirds** | `E` `T` | Left / Right Two-Thirds |
| **Center** | `C` | Center Window |
| **Maximize** | `Enter` | Full Screen |
| **Restore Layout** | `Backspace` | Restore all windows to saved positions |
| **Save Layout** | `S` | Save current positions |

### 3. Automation / Stream Deck
Control the manager using system URLs:

| Action | URL | Description |
| :--- | :--- | :--- |
| **Restore Active** | `hammerspoon://windowlayout?action=restore` | Restores the currently active profile. |
| **Switch Profile** | `hammerspoon://windowlayout?action=restore&profile=Name` | Switches to "Name" and restores it. |
| **Save Active** | `hammerspoon://windowlayout?action=save` | Overwrites the current profile. |

## Customization
You can change the base modifiers (e.g., from `ctrl, alt` to `cmd, shift`) via the Menubar:
1.  Click **WL** > **Configuration** > **Set Base Modifiers...**.
2.  Type your combo (e.g., `cmd, shift`).
3.  Save & Reload.

## Compatibility
-   **macOS**: Tested on macOS Sonoma.
-   **Hammerspoon**: Latest version recommended.
