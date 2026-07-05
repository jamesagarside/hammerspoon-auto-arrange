--- === SnapBack ===
---
--- Layout profiles for every display setup: your windows snap back into place
--- when you dock, undock, or your screens wake.
---
--- Download: https://github.com/jamesagarside/snapback
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "SnapBack"
obj.version = "0.6.0"
obj.author = "James Garside"
obj.homepage = "https://github.com/jamesagarside/snapback"
obj.license = "Apache-2.0 - https://www.apache.org/licenses/LICENSE-2.0"

obj.logger = hs.logger.new('SnapBack', 'info')

-- Configuration
-- Configuration is now dynamic (see below)


-- Use hs.configdir or resolve ~/.hammerspoon safely
local configDir = hs.fs.pathToAbsolute("~/.hammerspoon")
obj.storagePath = configDir .. "/snapback"
obj.legacyStoragePath = configDir .. "/window-layouts"
obj.profilesFile = obj.storagePath .. "/profiles.json"
obj.settingsFile = obj.storagePath .. "/settings.json"
obj.dirCreated = false

-- Ensure storage directory exists
function obj.ensureStorageExists()
    if obj.dirCreated then return end
    -- Migrate data saved under the pre-rename (AutoArrange) storage location
    if not hs.fs.attributes(obj.storagePath) and hs.fs.attributes(obj.legacyStoragePath) then
        os.rename(obj.legacyStoragePath, obj.storagePath)
    end
    if not hs.fs.attributes(obj.storagePath) then
        hs.fs.mkdir(obj.storagePath)
    end
    obj.dirCreated = true
end

-- Submodules live next to this file inside the Spoon
local spoonPath = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or ""
local Store = dofile(spoonPath .. "store.lua")
local geometry = dofile(spoonPath .. "geometry.lua")
local matcher = dofile(spoonPath .. "matcher.lua")
local actions = dofile(spoonPath .. "actions.lua")
local minimap = dofile(spoonPath .. "minimap.lua")

-- Profile Store: profiles, layouts, and settings behind one interface.
-- Hammerspoon supplies the storage adapters; tests supply in-memory ones.
obj.store = Store.new{
    profilesFile = obj.profilesFile,
    settingsFile = obj.settingsFile,
    readJson = function(path) return hs.json.read(path) end,
    writeJson = function(data, path) hs.json.write(data, path, true, true) end,
    ensureStorage = function() obj.ensureStorageExists() end,
}

-- UI: Prompt to set base modifiers
function obj.configureModifiers()
    local current = table.concat(obj.store:baseModifiers(), ", ")
    local button, input = hs.dialog.textPrompt("SnapBack Config", "Enter base modifiers (comma separated):", current, "Save & Reload", "Cancel")
    
    if button == "Save & Reload" and input then
        local parts = {}
        local map = {
            cntl = "ctrl", control = "ctrl",
            opt = "alt", option = "alt", atl = "alt", -- frequent typo 'atl'
            command = "cmd",
            shft = "shift"
        }

        for w in string.gmatch(input, "([^,]+)") do
            -- trim whitespace
            local mod = w:match("^%s*(.-)%s*$"):lower()
            if mod and mod ~= "" then
                -- Normalize
                mod = map[mod] or mod
                table.insert(parts, mod)
            end
        end
        
        if #parts > 0 then
            obj.store:setSetting("baseModifiers", parts)
            hs.reload()
        else
            hs.alert.show("Invalid input")
        end
    end
end

-- Toggle Auto-Restore Mode
function obj.setAutoRestoreMode(mode)
    obj.store:setSetting("autoRestoreMode", mode)
    hs.alert.show("Auto-Restore: " .. mode:upper())
end

-- Resolve a registry row to its callable. Snap rows dispatch to
-- snapWindow; command rows map to profile operations.
local commandFns = {
    save = function() obj.captureLayout(nil) end,
    restore = function() obj.restoreLayout() end,
}

local function actionFn(row)
    if row.snap then
        return function() obj.snapWindow(row.snap) end
    end
    return commandFns[row.command]
end

-- Get unique hash for current display configuration
function obj.getDisplayConfigId()
    local screens = hs.screen.allScreens()
    local identifiers = {}
    for _, screen in ipairs(screens) do
        table.insert(identifiers, screen:id())
    end
    table.sort(identifiers)
    return table.concat(identifiers, "_")
end

-- hs.spaces wraps private macOS APIs that can fail or throw on newer macOS
-- versions; guard every call so Spaces trouble degrades a capture/restore
-- (windows land on the current Space) instead of aborting it
local function spacesCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
    obj.logger.w("hs.spaces call failed: " .. tostring(result))
    return nil
end

-- Helper: Get Space Index map
-- Returns: { [spaceID] = index } and { [screenUUID] = {spaceID, ...} }
function obj.getSpaceMap()
    local map = {}
    local spaces = spacesCall(hs.spaces.allSpaces) or {}
    for screenUUID, spaceIDs in pairs(spaces) do
        for i, spaceID in ipairs(spaceIDs) do
            map[spaceID] = i
        end
    end
    return map, spaces
end

-- Helper: Get Space ID from Screen UUID and Index
function obj.getSpaceID(screenUUID, index)
    local spaces = spacesCall(hs.spaces.allSpaces) or {}
    if spaces[screenUUID] and spaces[screenUUID][index] then
        return spaces[screenUUID][index]
    end
    return nil
end

-- Capture current window layout
function obj.captureLayout(profileName)
    -- Use default filter but allow all spaces
    local wins = hs.window.filter.new():setDefaultFilter({}):getWindows()
    local layout = {}
    
    local spaceMap, allSpaces = obj.getSpaceMap()
    
    for _, win in ipairs(wins) do
        local app = win:application()
        if app then
            local f = win:frame()
            local winScreen = win:screen()
            local screenUUID = winScreen and winScreen:getUUID() or "Unknown"
            
            -- Determine Space Index
            local winSpaces = spacesCall(hs.spaces.windowSpaces, win)
            local spaceIndex = 1 -- default
            if winSpaces and #winSpaces > 0 then
                local sid = winSpaces[1] -- assume primary space
                if spaceMap[sid] then
                    spaceIndex = spaceMap[sid]
                end
            end
            
            local winData = {
                app = app:name(),
                title = win:title(),
                frame = {x=f.x, y=f.y, w=f.w, h=f.h},
                screen = winScreen and winScreen:name() or "Unknown",
                screen_uuid = screenUUID,
                space_index = spaceIndex, -- Valid Phase 3 property
                id = win:id(),
                isStandard = win:isStandard()
            }
            
            if winData.isStandard then
                table.insert(layout, winData)
            end
        end
    end
    
    obj.logger.i(string.format("Captured %d windows across spaces", #layout))

    local configId = obj.getDisplayConfigId()
    local targetName = obj.store:saveLayout(configId, profileName, layout, #hs.screen.allScreens())

    hs.alert.show(string.format("Saved Profile: %s", targetName))
    obj.updateMenubarTitle()
end

-- Prompt user for new profile name
function obj.saveAsNewProfile()
    local button, name = hs.dialog.textPrompt("New Profile", "Enter name for new layout profile:", "", "Save", "Cancel")
    if button == "Save" and name and name ~= "" then
        obj.captureLayout(name)
    end
end

-- Switch to a different profile. Only known names are accepted — a typo in
-- a Stream Deck URL would otherwise activate a brand-new empty profile
function obj.switchProfile(name)
    local configId = obj.getDisplayConfigId()
    local exists = false
    for _, n in ipairs(obj.store:profileNames(configId)) do
        if n == name then exists = true end
    end
    if not exists then
        hs.alert.show("No profile named '" .. tostring(name) .. "' for this display setup")
        return
    end
    if obj.store:setActive(configId, name) then
        obj.updateMenubarTitle()
        obj.restoreLayout() -- Auto-restore on switch
    end
end

-- Restore window layout for current display config
function obj.restoreLayout()
    local configId = obj.getDisplayConfigId()

    if not obj.store:hasConfig(configId) then
        hs.alert.show("No profiles for this display setup")
        return
    end

    local activeName = obj.store:activeProfileName(configId)
    local layoutData = obj.store:activeLayout(configId)

    if not layoutData then
        hs.alert.show("Profile '" .. activeName .. "' is empty")
        return
    end
    
    local windows = layoutData.windows

    -- Snapshot live windows into plain records for the matcher; the live
    -- window rides along on the record for the move step below
    local candidates = {}
    for _, win in ipairs(hs.window.filter.new():setDefaultFilter({}):getWindows()) do
        local app = win:application()
        table.insert(candidates, {
            id = win:id(),
            app = app and app:name() or nil,
            title = win:title(),
            win = win
        })
    end

    -- Map Screens for Current Setup
    local currentScreens = {}
    for _, s in ipairs(hs.screen.allScreens()) do
        currentScreens[s:name()] = s -- fallback by name
        currentScreens[s:getUUID()] = s -- pref by UUID
    end

    local matches, unmatched = matcher.assign(windows, candidates)
    local matchStats = {ID=0, Exact=0, Fuzzy=0, Slot=0}
    local spaceFailures = 0

    for _, m in ipairs(matches) do
        local savedWin = m.saved
        local match = m.candidate.win
        matchStats[m.matchType] = matchStats[m.matchType] + 1

        -- 1. Identify Target Screen
        local targetScreen = currentScreens[savedWin.screen_uuid] or currentScreens[savedWin.screen]

        -- 2. Identify Target Space ID
        local targetSpaceID = nil
        if targetScreen and savedWin.space_index then
           targetSpaceID = obj.getSpaceID(targetScreen:getUUID(), savedWin.space_index)
        end

        -- 3. Move to Space (if needed and valid)
        if targetSpaceID then
            if spacesCall(hs.spaces.moveWindowToSpace, match, targetSpaceID) == nil then
                spaceFailures = spaceFailures + 1
            end
        end

        -- 4. Move Frame (Geometry)
        if targetScreen then
            match:move(savedWin.frame, targetScreen, true)
        else
            -- Fallback to current screen frame only
            match:setFrame(savedWin.frame)
        end
    end

    for _, savedWin in ipairs(unmatched) do
        obj.logger.d("Could not find match for: " .. tostring(savedWin.app) .. " - " .. tostring(savedWin.title))
    end

    local msg = string.format("Restored '%s' (%d wins)", activeName, #matches)
    -- Add detail if matches were imprecise
    if matchStats.Fuzzy > 0 or matchStats.Slot > 0 then
        msg = msg .. string.format("\n(Fuzzy: %d, Slot: %d)", matchStats.Fuzzy, matchStats.Slot)
    end
    if spaceFailures > 0 then
        msg = msg .. string.format("\n(Spaces unavailable for %d window%s)",
            spaceFailures, spaceFailures == 1 and "" or "s")
    end
    hs.alert.show(msg)
end

-- Stream Deck / URL Handler
function obj.handleUrlEvent(eventName, params)
    obj.logger.i("URL Event Received: " .. tostring(eventName))
    obj.logger.i("Params: " .. hs.inspect(params))

    if eventName ~= "snapback" and eventName ~= "windowlayout" then return end
    
    local action = params.action
    local profile = params.profile
    
    if action == "save" then
        obj.captureLayout(profile) -- If profile is nil, saves to active
    elseif action == "restore" then
        if profile then
            obj.logger.i("Triggering Restore Specific Profile from URL: " .. profile)
            obj.switchProfile(profile)
        else
            obj.logger.i("Triggering Restore Active from URL...")
            obj.restoreLayout()
        end
    elseif action == "switch" and profile then
        obj.switchProfile(profile)
    elseif action == "list" then
        local names = obj.store:profileNames(obj.getDisplayConfigId())
        if #names > 0 then
            local doc = "Available Profiles:\n"
            for _, name in ipairs(names) do
                doc = doc .. "- " .. name .. "\n"
            end
            hs.alert.show(doc)
            obj.logger.i(doc)
        else
            hs.alert.show("No profiles found")
        end
    else
        hs.alert.show("SnapBack: Unknown URL action")
        obj.logger.e("Unknown URL Action: " .. tostring(action))
    end
end

function obj.updateMenubarTitle()
    if obj.menubar then
        local active = obj.store:activeProfileName(obj.getDisplayConfigId())
        obj.menubar:setTitle("SB: " .. active)
    end
end

-- Handle screen configuration changes (dock/undock, display sleep/wake).
-- macOS fires several watcher events while the displays settle, so debounce
-- and only act once the configuration has been stable for a few seconds.
function obj.handleScreenChanged()
    obj.logger.i("Display configuration changed")
    obj.updateMenubarTitle()

    if obj.restoreTimer then obj.restoreTimer:stop() end
    obj.restoreTimer = hs.timer.doAfter(3, function()
        local mode = obj.store:autoRestoreMode()
        if mode == "disabled" then return end

        local configId = obj.getDisplayConfigId()
        if not obj.store:hasConfig(configId) then
            obj.logger.i("No saved profile for display config: " .. configId)
            return
        end

        if mode == "auto" then
            obj.restoreLayout()
        elseif mode == "prompt" then
            local active = obj.store:activeProfileName(configId)
            local button = hs.dialog.blockAlert("SnapBack",
                string.format("Display setup changed. Restore layout '%s'?", active),
                "Restore", "Not Now")
            if button == "Restore" then obj.restoreLayout() end
        end
    end)
end

-- Reveal the profiles/settings folder in Finder
function obj.openStorageFolder()
    obj.ensureStorageExists()
    hs.execute(string.format("open %q", obj.storagePath))
end

-- Show Hotkeys Cheat Sheet — derives from the Action Registry
function obj.showHotkeys()
    hs.alert.show(actions.cheatSheet(obj.store:baseModifiers()), 5)
end

-- Minimap image: the current display arrangement with the active profile's
-- saved windows ghosted in — the dropdown's picture of what "snap back" means
function obj.minimapImage(configId)
    local screens = {}
    for _, s in ipairs(hs.screen.allScreens()) do
        local f = s:fullFrame()
        table.insert(screens, {
            x = f.x, y = f.y, w = f.w, h = f.h,
            name = s:name(), uuid = s:getUUID(),
        })
    end
    local layoutData = obj.store:activeLayout(configId)
    local windows = layoutData and layoutData.windows or {}
    return minimap.render(minimap.layout(screens, windows))
end

-- Helper to build the menu table (extracted for refreshing)
function obj.buildMenu()
    local configId = obj.getDisplayConfigId()
    local active = obj.store:activeProfileName(configId)
    local profileNames = obj.store:profileNames(configId)
    local restoreMode = obj.store:autoRestoreMode()
    local base = obj.store:baseModifiers()

    local menuTable = {}

    -- Minimap at the top; profiles are the product, so the first thing the
    -- dropdown shows is this setup and where windows will land. Guarded so a
    -- drawing failure can never take the whole menu down with it.
    local okMap, mapImage = pcall(obj.minimapImage, configId)
    if okMap and mapImage then
        table.insert(menuTable, {
            image = mapImage,
            title = "",
            tooltip = "Current displays with the active profile's saved windows — click to restore",
            fn = obj.restoreLayout,
        })
        table.insert(menuTable, { title = "-" })
    end

    -- Registry row -> menu item with its shortcut label
    local function add(row)
        table.insert(menuTable, {
            title = row.label .. actions.shortcutLabel(base, row.key),
            fn = actionFn(row)
        })
    end

    -- Snap sections derive from the Action Registry
    for _, section in ipairs(actions.menuSections) do
        for _, row in ipairs(actions.list) do
            if row.section == section then add(row) end
        end
        table.insert(menuTable, { title = "-" })
    end

    -- Profiles & Config
    table.insert(menuTable, { title = "Active: " .. active, disabled = true })

    if #profileNames > 0 then
        local profileMenu = {}
        for _, name in ipairs(profileNames) do
            table.insert(profileMenu, {
                title = name,
                checked = (name == active),
                fn = function() obj.switchProfile(name) end
            })
        end
        table.insert(menuTable, { title = "Switch Profile ▶", menu = profileMenu })
    end

    add(actions.byId("save"))
    table.insert(menuTable, { title = "Save as New Profile...", fn = obj.saveAsNewProfile })

    table.insert(menuTable, { title = "-" })
    
    -- Auto-Restore Submenu
    table.insert(menuTable, {
        title = "Auto-Restore Mode ▶",
        menu = {
            { title = "Automatic", checked = (restoreMode == "auto"), fn = function() obj.setAutoRestoreMode("auto") end },
            { title = "Prompt", checked = (restoreMode == "prompt"), fn = function() obj.setAutoRestoreMode("prompt") end },
            { title = "Disabled", checked = (restoreMode == "disabled"), fn = function() obj.setAutoRestoreMode("disabled") end }
        }
    })
    
    table.insert(menuTable, { title = "⌨  Hotkeys Cheat Sheet", fn = obj.showHotkeys })
    table.insert(menuTable, { title = "⚙  Set Base Modifiers...", fn = obj.configureModifiers })
    table.insert(menuTable, { title = "Open Data Folder...", fn = obj.openStorageFolder })
    table.insert(menuTable, { title = "Reload Config", fn = hs.reload })

    return menuTable
end

-- Setup Menubar (Standard Style)
function obj.setupMenubar()
    if obj.menubar then return end
    
    obj.menubar = hs.menubar.new()
    obj.menubar:setTooltip("SnapBack — window layout manager")
    obj.updateMenubarTitle()
    
    obj.menubar:setMenu(obj.buildMenu)
end

-- Bind Hotkeys — every registry row, one bind each. Note: this fixes an
-- old divergence where Up/Down maximized/minimized while the menu's
-- Top/Bottom snapped to halves; both now snap to halves.
function obj.bindHotkeys()
    local base = obj.store:baseModifiers()
    for _, row in ipairs(actions.list) do
        hs.hotkey.bind(base, row.key, actionFn(row))
    end
end

-- SNAP & GRID HELPERS
-- Track last snap for cycle detection
obj.lastSnap = {
    winId = nil,
    direction = nil,
    time = 0
}

function obj.snapWindow(direction)
    local win = hs.window.focusedWindow()
    if not win then return end

    if direction == "minimize" then
        win:minimize()
        return
    end

    -- Sub-second clock: os.time()'s 1s resolution made the 2s cycle window
    -- effectively 1-3s depending on where in a second the presses landed
    local now = hs.timer.secondsSinceEpoch()
    local winId = win:id()
    local target = geometry.frameFor(direction, win:screen():frame())
    if not target then return end

    -- Pressing the same direction twice on an already-snapped window walks
    -- it to the adjacent screen, landing on the near column so repeated
    -- presses traverse the whole display setup half-by-half
    local cycle = geometry.cycle[direction]
    if cycle and geometry.isCycle(obj.lastSnap, winId, direction, now)
       and geometry.framesMatch(win:frame(), target) then
        local nextScreen = cycle.toward == "west" and win:screen():toWest()
                                                   or win:screen():toEast()
        if nextScreen then
            win:setFrame(geometry.frameFor(cycle.landing, nextScreen:frame()))
            hs.alert.show(cycle.toward == "west" and "◨ Prev Screen" or "◧ Next Screen")
            -- Keep lastSnap armed so the walk continues press by press
            obj.lastSnap = { winId = winId, direction = direction, time = now }
        end
        return
    end

    win:setFrame(target)

    obj.lastSnap = {
        winId = winId,
        direction = direction,
        time = now
    }
end

-- Init
function obj.start()
    obj.ensureStorageExists()

    -- Performance: Disable window animations for instant snapping
    hs.window.animationDuration = 0

    obj.setupMenubar()
    obj.bindHotkeys()

    -- Watch for display changes
    obj.screenWatcher = hs.screen.watcher.new(obj.handleScreenChanged)
    obj.screenWatcher:start()
    
    -- Bind URL Events ("windowlayout" kept for pre-rename Stream Deck setups)
    hs.urlevent.bind("snapback", obj.handleUrlEvent)
    hs.urlevent.bind("windowlayout", obj.handleUrlEvent)

    obj.logger.i("SnapBack started (profiles, auto-restore & snapping)")
end

return obj
