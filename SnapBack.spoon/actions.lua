--- === SnapBack.actions ===
---
--- Action Registry: every user-facing action exists exactly once, as data.
--- The menu, the hotkey bindings, and the cheat sheet all derive from
--- `actions.list` — so they cannot drift apart. (They had: the Up/Down
--- hotkeys used to maximize/minimize while the menu's Top/Bottom items
--- snapped to half-screens.)
---
--- Row shape:
---  * id      - unique key, also the hotkey slot name
---  * name    - plain-English name (cheat sheet)
---  * label   - menu title with glyph (rows without a label are hotkey-only)
---  * key     - key bound with the base modifiers
---  * section - menu section (see actions.menuSections); nil = no menu row
---  * snap    - direction passed to snapWindow, or
---  * command - named command dispatched by init ("save" | "restore")

local actions = {}

actions.list = {
    -- Halves
    { id = "snapLeft",       name = "Snap Left",             label = "◧  Left",             key = "Left",   section = "halves",    snap = "left" },
    { id = "snapRight",      name = "Snap Right",            label = "◨  Right",            key = "Right",  section = "halves",    snap = "right" },
    { id = "snapUp",         name = "Snap Top",              label = "⬒  Top",              key = "Up",     section = "halves",    snap = "top" },
    { id = "snapDown",       name = "Snap Bottom",           label = "⬓  Bottom",           key = "Down",   section = "halves",    snap = "bottom" },
    -- Quarters (corners)
    { id = "topLeft",        name = "Top Left Quarter",      label = "◤  Top Left",         key = "U",      section = "quarters",  snap = "topLeft" },
    { id = "topRight",       name = "Top Right Quarter",     label = "◥  Top Right",        key = "I",      section = "quarters",  snap = "topRight" },
    { id = "bottomLeft",     name = "Bottom Left Quarter",   label = "◣  Bottom Left",      key = "J",      section = "quarters",  snap = "bottomLeft" },
    { id = "bottomRight",    name = "Bottom Right Quarter",  label = "◢  Bottom Right",     key = "K",      section = "quarters",  snap = "bottomRight" },
    -- Thirds
    { id = "leftThird",      name = "Left Third",            label = "⅓  Left Third",       key = "D",      section = "thirds",    snap = "leftThird" },
    { id = "centerThird",    name = "Center Third",          label = "⅓  Center Third",     key = "F",      section = "thirds",    snap = "centerThird" },
    { id = "rightThird",     name = "Right Third",           label = "⅓  Right Third",      key = "G",      section = "thirds",    snap = "rightThird" },
    { id = "leftTwoThirds",  name = "Left Two Thirds",       label = "⅔  Left Two Thirds",  key = "E",      section = "twoThirds", snap = "leftTwoThirds" },
    { id = "rightTwoThirds", name = "Right Two Thirds",      label = "⅔  Right Two Thirds", key = "T",      section = "twoThirds", snap = "rightTwoThirds" },
    -- Window
    { id = "maximize",       name = "Maximize",              label = "⤢  Maximize",         key = "Return", section = "window",    snap = "maximize" },
    { id = "center",         name = "Center Window",         label = "✛  Center",           key = "C",      section = "window",    snap = "center" },
    { id = "restoreLayout",  name = "Restore Layout",        label = "↺  Restore Layout",   key = "delete", section = "window",    command = "restore" },
    -- Profiles (menu rows are placed by init in the profiles section)
    { id = "save",           name = "Save Current Layout",   label = "Save Current Layout", key = "S",                             command = "save" },
    { id = "restore",        name = "Restore Active Profile",                               key = "R",                             command = "restore" },
}

-- Menu section order; a separator follows each section
actions.menuSections = { "halves", "quarters", "thirds", "twoThirds", "window" }

function actions.byId(id)
    for _, row in ipairs(actions.list) do
        if row.id == id then return row end
    end
    return nil
end

local MOD_GLYPHS = { cmd = "⌘", alt = "⌥", ctrl = "⌃", shift = "⇧" }
local KEY_GLYPHS = {
    Left = "←", Right = "→", Up = "↑", Down = "↓",
    Return = "⏎", delete = "⌫",
}

--- Visual shortcut label for a menu row, e.g. "  ⌘⌥⌃←"
function actions.shortcutLabel(mods, key)
    local str = "  "
    for _, m in ipairs(mods) do
        str = str .. (MOD_GLYPHS[m] or "")
    end
    return str .. (KEY_GLYPHS[key] or key)
end

--- Cheat sheet listing every registered action with its shortcut
function actions.cheatSheet(mods)
    local lines = { "SnapBack Hotkeys:" }
    for _, row in ipairs(actions.list) do
        table.insert(lines, string.format("%s   %s",
            actions.shortcutLabel(mods, row.key), row.name))
    end
    return table.concat(lines, "\n")
end

return actions
