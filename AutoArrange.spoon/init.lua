--- === AutoArrange ===
---
--- A comprehensive window manager with auto-restore profiles.
---
--- Download: https://github.com/jamesagarside/hammerspoon-auto-arrange
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "AutoArrange"
obj.version = "1.0"
obj.author = "James Garside"
obj.homepage = "https://github.com/jamesagarside/hammerspoon-auto-arrange"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new('AutoArrange', 'info')

-- Configuration
-- Configuration is now dynamic (see below)


-- Use hs.configdir or resolve ~/.hammerspoon safely
local configDir = hs.fs.pathToAbsolute("~/.hammerspoon")
obj.storagePath = configDir .. "/window-layouts"
obj.profilesFile = obj.storagePath .. "/profiles.json"
obj.settingsFile = obj.storagePath .. "/settings.json"
obj.dirCreated = false

-- Ensure storage directory exists
function obj.ensureStorageExists()
    if obj.dirCreated then return end
    local attr = hs.fs.attributes(obj.storagePath)
    if not attr then
        hs.fs.mkdir(obj.storagePath)
    end
    obj.dirCreated = true
end

-- Load general settings
function obj.loadSettings()
    obj.ensureStorageExists()
    local settings = hs.json.read(obj.settingsFile)
    return settings or {}
end

-- Save general settings
function obj.saveSettings(settings)
    obj.ensureStorageExists()
    hs.json.write(settings, obj.settingsFile, true, true)
end

-- Get Base Modifiers (default: Cmd+Alt+Ctrl)
function obj.getBaseModifiers()
    local settings = obj.loadSettings()
    if settings.baseModifiers then
        return settings.baseModifiers
    end
    return {"cmd", "alt", "ctrl"}
end

-- UI: Prompt to set base modifiers
function obj.configureModifiers()
    local current = table.concat(obj.getBaseModifiers(), ", ")
    local button, input = hs.dialog.textPrompt("Window Layout Config", "Enter base modifiers (comma separated):", current, "Save & Reload", "Cancel")
    
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
            local settings = obj.loadSettings()
            settings.baseModifiers = parts
            obj.saveSettings(settings)
            hs.reload()
        else
            hs.alert.show("Invalid input")
        end
    end
end

-- Toggle Auto-Restore Mode
function obj.setAutoRestoreMode(mode)
    local settings = obj.loadSettings()
    settings.autoRestoreMode = mode
    obj.saveSettings(settings)
    hs.alert.show("Auto-Restore: " .. mode:upper())
    -- Force menu rebuild to show checkmark
    obj.menubar:setMenu(obj.buildMenu()) 
end

function obj.getAutoRestoreMode()
    local settings = obj.loadSettings()
    return settings.autoRestoreMode or "auto"
end

-- Generate Configuration based on settings
-- We define keys here, but modifiers come from settings
local base = obj.getBaseModifiers()
obj.config = {
    hotkeys = {
        save = {base, "S"},
        restore = {base, "R"},
        
        -- Halves
        snapLeft = {base, "Left"},
        snapRight = {base, "Right"},
        snapUp = {base, "Up"},
        snapDown = {base, "Down"},
        
        -- Quarters (Corners)
        topLeft = {base, "U"},
        topRight = {base, "I"},
        bottomLeft = {base, "J"},
        bottomRight = {base, "K"},
        
        -- Thirds
        leftThird = {base, "D"},
        centerThird = {base, "F"},
        rightThird = {base, "G"},
        
        -- Two Thirds
        leftTwoThirds = {base, "E"},
        rightTwoThirds = {base, "T"},
        
        -- Extras
        maximize = {base, "Return"},
        center = {base, "C"},
        restoreLayout = {base, "delete"}, -- Backspace
        
        -- Displays
        nextScreen = {{"ctrl", "alt", "cmd"}, "Right"},
        prevScreen = {{"ctrl", "alt", "cmd"}, "Left"}
    }
}

-- Save data to JSON file
function obj.saveProfiles(profiles)
    obj.ensureStorageExists()
    hs.json.write(profiles, obj.profilesFile, true, true)
end

-- Load data from JSON file
function obj.loadProfiles()
    obj.ensureStorageExists()
    local profiles = hs.json.read(obj.profilesFile)
    return profiles or {}
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

-- HELPER: Get active profile name for current config
function obj.getActiveProfileName(profiles, configId)
    if not profiles[configId] then return "Default" end
    return profiles[configId].active or "Default"
end

-- Helper: Get Space Index map
-- Returns: { [spaceID] = index } and { [screenUUID] = {spaceID, ...} }
function obj.getSpaceMap()
    local map = {}
    local spaces = hs.spaces.allSpaces()
    for screenUUID, spaceIDs in pairs(spaces) do
        for i, spaceID in ipairs(spaceIDs) do
            map[spaceID] = i
        end
    end
    return map, spaces
end

-- Helper: Get Space ID from Screen UUID and Index
function obj.getSpaceID(screenUUID, index)
    local spaces = hs.spaces.allSpaces()
    if spaces[screenUUID] and spaces[screenUUID][index] then
        return spaces[screenUUID][index]
    end
    return nil
end

-- SMART MATCHING HELPERS

-- Normalize title for fuzzy matching (remove " - AppName", numbers, special chars)
function obj.normalizeTitle(title)
    if not title then return "" end
    -- Lowercase
    local s = string.lower(title)
    -- Remove common browser suffixes
    s = s:gsub(" %- google chrome$", "")
    s = s:gsub(" %- visual studio code$", "")
    -- Remove notification counters like "(1)"
    s = s:gsub("%s?%d+%s?", "")
    -- Remove special chars
    s = s:gsub("[%p%c]", "")
    return s
end

-- Calculate string similarity (0.0 to 1.0) - Jaro-Winkler-ish simplified
function obj.calculateSimilarity(s1, s2)
    local longer = #s1 > #s2 and s1 or s2
    local shorter = #s1 > #s2 and s2 or s1
    if #longer == 0 then return 1.0 end
    
    -- Exact substring check is usually good enough for windows
    if string.find(longer, shorter, 1, true) then
        return 0.9 -- High score for substring match
    end
    
    return 0.0
end

-- Find best match for a saved window from available windows
function obj.findBestMatch(savedWin, availableWins, usedWinIDs)
    -- 1. ID Match (Perfect)
    for _, win in ipairs(availableWins) do
        if not usedWinIDs[win:id()] and win:id() == savedWin.id then
            return win, "ID"
        end
    end

    -- 2. Exact Title Match (Good)
    for _, win in ipairs(availableWins) do
        if not usedWinIDs[win:id()] then
            local app = win:application()
            if app and app:name() == savedWin.app and win:title() == savedWin.title then
                return win, "Exact"
            end
        end
    end
    
    -- 3. Fuzzy Title Match (Okay)
    local bestWin = nil
    local bestScore = 0
    local savedNorm = obj.normalizeTitle(savedWin.title)
    
    for _, win in ipairs(availableWins) do
        if not usedWinIDs[win:id()] then
            local app = win:application()
            if app and app:name() == savedWin.app then
                local currentNorm = obj.normalizeTitle(win:title())
                local score = obj.calculateSimilarity(savedNorm, currentNorm)
                if score > 0.5 and score > bestScore then
                    bestScore = score
                    bestWin = win
                end
            end
        end
    end
    
    if bestWin then return bestWin, "Fuzzy" end
    
    -- 4. App Slotting (Last Resort) - Just find *any* window of same app
    for _, win in ipairs(availableWins) do
        if not usedWinIDs[win:id()] then
            local app = win:application()
            if app and app:name() == savedWin.app then
                return win, "Slot"
            end
        end
    end
    
    return nil, nil
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
            local winSpaces = hs.spaces.windowSpaces(win)
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
    
    local profiles = obj.loadProfiles()
    local configId = obj.getDisplayConfigId()
    
    -- Initialize structure if missing
    if not profiles[configId] then
        profiles[configId] = {
            active = "Default",
            layouts = {}
        }
    end
    
    -- Migration check: if old format (direct windows property), move to Default
    if profiles[configId].windows then
        profiles[configId].layouts = {}
        profiles[configId].layouts["Default"] = {
            windows = profiles[configId].windows,
            timestamp = profiles[configId].timestamp
        }
        profiles[configId].windows = nil
        profiles[configId].timestamp = nil
        profiles[configId].active = "Default"
    end
    
    -- Determine target name
    local targetName = profileName or profiles[configId].active or "Default"
    
    -- Save new layout
    if not profiles[configId].layouts then profiles[configId].layouts = {} end
    
    profiles[configId].layouts[targetName] = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        windows = layout,
        display_count = #hs.screen.allScreens()
    }
    profiles[configId].active = targetName
    
    obj.saveProfiles(profiles)
    
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

-- Switch to a different profile
function obj.switchProfile(name)
    local profiles = obj.loadProfiles()
    local configId = obj.getDisplayConfigId()
    
    if profiles[configId] then
        profiles[configId].active = name
        obj.saveProfiles(profiles)
        obj.updateMenubarTitle()
        obj.restoreLayout() -- Auto-restore on switch
    end
end

-- Restore window layout for current display config
function obj.restoreLayout()
    local profiles = obj.loadProfiles()
    local configId = obj.getDisplayConfigId()
    
    if not profiles[configId] then
        hs.alert.show("No profiles for this display setup")
        return
    end

    -- Migration check
    if profiles[configId].windows then
        -- Handle legacy format by treating it as Default
        local windows = profiles[configId].windows
        -- restore logic below...
    end

    local activeName = obj.getActiveProfileName(profiles, configId)
    local layoutData = nil
    
    if profiles[configId].layouts and profiles[configId].layouts[activeName] then
        layoutData = profiles[configId].layouts[activeName]
    elseif profiles[configId].windows then
        -- Legacy fallback
        layoutData = profiles[configId]
    end
    
    if not layoutData then
        hs.alert.show("Profile '" .. activeName .. "' is empty")
        return
    end
    
    local windows = layoutData.windows
    -- Get ALL windows
    local allWindows = hs.window.filter.new():setDefaultFilter({}):getWindows()
    local restoreCount = 0
    local usedWinIDs = {} -- Track assigned windows
    local matchStats = {ID=0, Exact=0, Fuzzy=0, Slot=0}
    
    -- Map Screens for Current Setup
    local currentScreens = {}
    for _, s in ipairs(hs.screen.allScreens()) do
        currentScreens[s:name()] = s -- fallback by name
        currentScreens[s:getUUID()] = s -- pref by UUID
    end
    
    local spaceMap, allSpaces = obj.getSpaceMap()

    for _, savedWin in ipairs(windows) do
        -- Find Best Match
        local match, matchType = obj.findBestMatch(savedWin, allWindows, usedWinIDs)
        
        if match then
            usedWinIDs[match:id()] = true
            matchStats[matchType] = matchStats[matchType] + 1
            
            -- 1. Identify Target Screen
            local targetScreen = currentScreens[savedWin.screen_uuid] or currentScreens[savedWin.screen]
            
            -- 2. Identify Target Space ID
            local targetSpaceID = nil
            if targetScreen and savedWin.space_index then
               targetSpaceID = obj.getSpaceID(targetScreen:getUUID(), savedWin.space_index)
            end
            
            -- 3. Move to Space (if needed and valid)
            if targetSpaceID then
                hs.spaces.moveWindowToSpace(match, targetSpaceID)
                -- Small delay might be needed for space move animation?
                -- hs.timer.usleep(100000) -- 0.1s
            end
            
            -- 4. Move Frame (Geometry)
            if targetScreen then
                match:move(savedWin.frame, targetScreen, true)
            else
                -- Fallback to current screen frame only
                match:setFrame(savedWin.frame)
            end
            
            restoreCount = restoreCount + 1
        else
            obj.logger.d("Could not find match for: " .. savedWin.app .. " - " .. savedWin.title)
        end
    end
    
    local msg = string.format("Restored '%s' (%d wins)", activeName, restoreCount)
    -- Add detail if matches were imprecise
    if matchStats.Fuzzy > 0 or matchStats.Slot > 0 then
        msg = msg .. string.format("\n(Fuzzy: %d, Slot: %d)", matchStats.Fuzzy, matchStats.Slot)
    end
    hs.alert.show(msg)
end

-- Stream Deck / URL Handler
function obj.handleUrlEvent(eventName, params)
    obj.logger.i("URL Event Received: " .. tostring(eventName))
    obj.logger.i("Params: " .. hs.inspect(params))

    if eventName ~= "windowlayout" then return end
    
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
        local profiles = obj.loadProfiles()
        local configId = obj.getDisplayConfigId()
        if profiles[configId] and profiles[configId].layouts then
            local doc = "Available Profiles:\n"
            for name, _ in pairs(profiles[configId].layouts) do
                doc = doc .. "- " .. name .. "\n"
            end
            hs.alert.show(doc)
            obj.logger.i(doc)
        else
            hs.alert.show("No profiles found")
        end
    else
        hs.alert.show("WL: Unknown URL action")
        obj.logger.e("Unknown URL Action: " .. tostring(action))
    end
end

function obj.updateMenubarTitle()
    if obj.menubar then
        local configId = obj.getDisplayConfigId()
        local profiles = obj.loadProfiles()
        local active = obj.getActiveProfileName(profiles, configId)
        obj.menubar:setTitle("WL: " .. active)
    end
end

-- Handle screen configuration changes
function obj.handleScreenChanged()
    obj.logger.i("Display configuration changed")
    obj.updateMenubarTitle()
end

-- Open Config File
function obj.editConfig()
    hs.execute("open " .. os.getenv("HOME") .. "/.hammerspoon/window-layout.lua")
end

-- Show Hotkeys Cheat Sheet
function obj.showHotkeys()
    local keys = obj.config.hotkeys
    local msg = "Current Hotkeys:\n"
    
    local function modStr(mods) return table.concat(mods, "+") end
    
    if keys.save then msg = msg .. "- Save: " .. modStr(keys.save[1]) .. " + " .. keys.save[2] .. "\n" end
    if keys.restore then msg = msg .. "- Restore: " .. modStr(keys.restore[1]) .. " + " .. keys.restore[2] .. "\n" end
    if keys.snapLeft then msg = msg .. "- Snap Left: " .. modStr(keys.snapLeft[1]) .. " + " .. keys.snapLeft[2] .. "\n" end
    if keys.snapRight then msg = msg .. "- Snap Right: " .. modStr(keys.snapRight[1]) .. " + " .. keys.snapRight[2] .. "\n" end
    if keys.snapUp then msg = msg .. "- Maximize: " .. modStr(keys.snapUp[1]) .. " + " .. keys.snapUp[2] .. "\n" end
    
    hs.alert.show(msg, 5)
end

-- Helper: Get visual shortcut label
function obj.getShortcutLabel(keyName)
    local conf = obj.config.hotkeys[keyName]
    if not conf then return "" end
    
    local mods = conf[1]
    local key = conf[2]
    
    local modMap = {
        cmd = "⌘", alt = "⌥", ctrl = "⌃", shift = "⇧"
    }
    
    local str = "  "
    for _, m in ipairs(mods) do
        str = str .. (modMap[m] or "")
    end
    
    -- Fix key names for display
    if key == "Left" then key = "←"
    elseif key == "Right" then key = "→"
    elseif key == "Up" then key = "↑"
    elseif key == "Down" then key = "↓"
    elseif key == "Return" then key = "⏎"
    elseif key == "delete" then key = "⌫"
    end
    
    return str .. key
end

-- Helper to build the menu table (extracted for refreshing)
function obj.buildMenu()
    local configId = obj.getDisplayConfigId()
    local profiles = obj.loadProfiles()
    local active = obj.getActiveProfileName(profiles, configId)
    local restoreMode = obj.getAutoRestoreMode()
    
    local menuTable = {}
    
    -- Helper to make adding items cleaner
    local function add(title, keyName, fn)
        local label = title .. obj.getShortcutLabel(keyName)
        table.insert(menuTable, { title = label, fn = fn })
    end

    -- Section 1: Halves
    add("◧  Left", "snapLeft", function() obj.snapWindow("left") end)
    add("◨  Right", "snapRight", function() obj.snapWindow("right") end)
    add("⬒  Top", "snapUp", function() obj.snapWindow("top") end) 
    add("⬓  Bottom", "snapDown", function() obj.snapWindow("bottom") end)
    table.insert(menuTable, { title = "-" })

    -- Section 2: Quarters
    add("◤  Top Left", "topLeft", function() obj.snapWindow("topLeft") end)
    add("◥  Top Right", "topRight", function() obj.snapWindow("topRight") end)
    add("◣  Bottom Left", "bottomLeft", function() obj.snapWindow("bottomLeft") end)
    add("◢  Bottom Right", "bottomRight", function() obj.snapWindow("bottomRight") end)
    table.insert(menuTable, { title = "-" })

    -- Section 3: Thirds
    add("⅓  Left Third", "leftThird", function() obj.snapWindow("leftThird") end)
    add("⅓  Center Third", "centerThird", function() obj.snapWindow("centerThird") end)
    add("⅓  Right Third", "rightThird", function() obj.snapWindow("rightThird") end)
    table.insert(menuTable, { title = "-" })
    add("⅔  Left Two Thirds", "leftTwoThirds", function() obj.snapWindow("leftTwoThirds") end)
    add("⅔  Right Two Thirds", "rightTwoThirds", function() obj.snapWindow("rightTwoThirds") end)
    table.insert(menuTable, { title = "-" })

    -- Section 4: Maximize / Restore / Center
    add("⤢  Maximize", "maximize", function() obj.snapWindow("maximize") end)
    add("✛  Center", "center", function() obj.snapWindow("center") end)
    add("↺  Restore Layout", "restoreLayout", obj.restoreLayout)
    table.insert(menuTable, { title = "-" })

    -- Section 5: Displays
    add("⇥  Next Screen", "nextScreen", obj.moveWindowToNextScreen)
    add("⇤  Prev Screen", "prevScreen", obj.moveWindowToPrevScreen)
    table.insert(menuTable, { title = "-" })

    -- Section 6: Profiles & Config
    table.insert(menuTable, { title = "Active: " .. active, disabled = true })
    
    if profiles[configId] and profiles[configId].layouts then
        local profileMenu = {}
        for name, _ in pairs(profiles[configId].layouts) do
            table.insert(profileMenu, {
                title = name,
                checked = (name == active),
                fn = function() obj.switchProfile(name) end
            })
        end
        table.insert(menuTable, { title = "Switch Profile ▶", menu = profileMenu })
    end
    
    add("Save Current Layout", "save", function() obj.captureLayout(nil) end)
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
    
    table.insert(menuTable, { title = "⚙  Set Base Modifiers...", fn = obj.configureModifiers })
    table.insert(menuTable, { title = "Edit Config File...", fn = obj.editConfig })
    table.insert(menuTable, { title = "Reload Config", fn = hs.reload })
    
    return menuTable
end

-- Setup Menubar (Standard Style)
function obj.setupMenubar()
    if obj.menubar then return end
    
    obj.menubar = hs.menubar.new()
    obj.menubar:setTooltip("Window Layout Manager")
    obj.updateMenubarTitle()
    
    obj.menubar:setMenu(obj.buildMenu)
end

-- Bind Hotkeys
-- Bind Hotkeys
function obj.bindHotkeys()
    local keys = obj.config.hotkeys
    
    local function bind(keyId, fn)
        if keys[keyId] then
            hs.hotkey.bind(keys[keyId][1], keys[keyId][2], fn)
        end
    end
    
    -- Save & Restore
    bind("save", function() obj.captureLayout(nil) end)
    bind("restore", obj.restoreLayout)
    bind("restoreLayout", obj.restoreLayout) -- Alias for Backspace
    
    -- Halves
    bind("snapLeft", function() obj.snapWindow("left") end)
    bind("snapRight", function() obj.snapWindow("right") end)
    bind("snapUp", function() obj.snapWindow("maximize") end)
    bind("snapDown", function() obj.snapWindow("minimize") end)
    
    -- Corners
    bind("topLeft", function() obj.snapWindow("topLeft") end)
    bind("topRight", function() obj.snapWindow("topRight") end)
    bind("bottomLeft", function() obj.snapWindow("bottomLeft") end)
    bind("bottomRight", function() obj.snapWindow("bottomRight") end)
    
    -- Thirds
    bind("leftThird", function() obj.snapWindow("leftThird") end)
    bind("centerThird", function() obj.snapWindow("centerThird") end)
    bind("rightThird", function() obj.snapWindow("rightThird") end)
    
    -- Two Thirds
    bind("leftTwoThirds", function() obj.snapWindow("leftTwoThirds") end)
    bind("rightTwoThirds", function() obj.snapWindow("rightTwoThirds") end)
    
    -- Extras
    bind("maximize", function() obj.snapWindow("maximize") end)
    bind("center", function() obj.snapWindow("center") end)
    
    -- Displays
    bind("nextScreen", obj.moveWindowToNextScreen)
    bind("prevScreen", obj.moveWindowToPrevScreen)
end

-- SNAP & GRID HELPERS
function obj.snapWindow(direction)
    local win = hs.window.focusedWindow()
    if not win then return end
    
    local f = win:frame()
    local screen = win:screen()
    local max = screen:frame()
    
    -- Halves
    if direction == "left" then
        f.x = max.x
        f.y = max.y
        f.w = max.w / 2
        f.h = max.h
    elseif direction == "right" then
        f.x = max.x + (max.w / 2)
        f.y = max.y
        f.w = max.w / 2
        f.h = max.h
    elseif direction == "top" then
        f.x = max.x
        f.y = max.y
        f.w = max.w
        f.h = max.h / 2
    elseif direction == "bottom" then
        f.x = max.x
        f.y = max.y + (max.h / 2)
        f.w = max.w
        f.h = max.h / 2
        
    -- Quarters (Corners)
    elseif direction == "topLeft" then
        f.x = max.x
        f.y = max.y
        f.w = max.w / 2
        f.h = max.h / 2
    elseif direction == "topRight" then
        f.x = max.x + (max.w / 2)
        f.y = max.y
        f.w = max.w / 2
        f.h = max.h / 2
    elseif direction == "bottomLeft" then
        f.x = max.x
        f.y = max.y + (max.h / 2)
        f.w = max.w / 2
        f.h = max.h / 2
    elseif direction == "bottomRight" then
        f.x = max.x + (max.w / 2)
        f.y = max.y + (max.h / 2)
        f.w = max.w / 2
        f.h = max.h / 2
        
    -- Thirds
    elseif direction == "leftThird" then
        f.x = max.x
        f.y = max.y
        f.w = max.w / 3
        f.h = max.h
    elseif direction == "centerThird" then
        f.x = max.x + (max.w / 3)
        f.y = max.y
        f.w = max.w / 3
        f.h = max.h
    elseif direction == "rightThird" then
        f.x = max.x + (max.w / 3) * 2
        f.y = max.y
        f.w = max.w / 3
        f.h = max.h
    elseif direction == "leftTwoThirds" then
        f.x = max.x
        f.y = max.y
        f.w = (max.w / 3) * 2
        f.h = max.h
    elseif direction == "rightTwoThirds" then
        f.x = max.x + (max.w / 3)
        f.y = max.y
        f.w = (max.w / 3) * 2
        f.h = max.h
        
    -- Standard
    elseif direction == "center" then
        f.w = max.w * 0.7
        f.h = max.h * 0.7
        f.x = max.x + (max.w - f.w) / 2
        f.y = max.y + (max.h - f.h) / 2
    elseif direction == "maximize" then
        f = max
    elseif direction == "minimize" then
        win:minimize()
        return
    end
    
    win:setFrame(f)
end

-- Screen Movement Helpers
function obj.moveWindowToNextScreen()
    local win = hs.window.focusedWindow()
    if win then 
        win:moveOneScreenEast()
        hs.alert.show("Moved to Next Screen")
    end
end

function obj.moveWindowToPrevScreen()
    local win = hs.window.focusedWindow()
    if win then 
        win:moveOneScreenWest() 
        hs.alert.show("Moved to Prev Screen")
    end
end

-- Init
function obj.start()
    obj.ensureStorageExists()
    
    -- Performance: Disable window animations for instant snapping
    hs.window.animationDuration = 0
    
    obj.setupMenubar()
    obj.bindHotkeys()
    
    -- Drag-to-Edge Snapping (Mouse Up Listener)
    obj.dragWatcher = hs.eventtap.new({hs.eventtap.event.types.leftMouseUp}, function(e)
        -- Only check if we are dragging a window (this is hard to detect perfectly without accessibility, 
        -- but checking cursor position at edge is a good proxy for "User dropped something at the edge")
        
        local pt = hs.mouse.getAbsolutePosition()
        local screen = hs.mouse.getCurrentScreen()
        local frame = screen:frame()
        local edgeThreshold = 20
        
        local action = nil
        
        -- Check Edges
        if pt.x < frame.x + edgeThreshold then action = "left"
        elseif pt.x > frame.x + frame.w - edgeThreshold then action = "right"
        elseif pt.y < frame.y + edgeThreshold then action = "maximize"
        end
        
        -- If at an edge, find the top window at that point and snap it
        if action then
            -- Small delay to let the OS process the "drop" event first, 
            -- otherwise the window might not report its new position or focus correctly yet.
            hs.timer.doAfter(0.1, function()
                local win = hs.window.focusedWindow()
                if win and win:isStandard() then
                   -- Double check constraints: snap only if the user actually dropped it AT the edge
                   -- Since we handle this on MouseUp, we assume they just released it.
                   
                   -- We use an alert to confirm action to be unobtrusive
                   if action == "maximize" then
                       obj.snapWindow("maximize")
                       hs.alert.show("Snapped: Maximize")
                   else
                       obj.snapWindow(action)
                       hs.alert.show("Snapped: " .. action)
                   end
                end
            end)
        end
        
        return false -- Propagate event
    end)
    -- obj.dragWatcher:start() -- DISABLED temporarily to debug responsiveness

    -- Watch for display changes
    obj.screenWatcher = hs.screen.watcher.new(obj.handleScreenChanged)
    obj.screenWatcher:start()
    
    -- Bind URL Events
    hs.urlevent.bind("windowlayout", obj.handleUrlEvent)
    
    obj.logger.i("Window Layout Manager started (Smart Match, Auto-Restore & Snapping)")
end

return obj
