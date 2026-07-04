--- === SnapBack.store ===
---
--- Profile Store: everything SnapBack persists — profiles, layouts, and
--- settings — behind one interface that speaks in Profiles and Layouts.
--- Callers never see the JSON shape; schema migration happens in here, once.
---
--- Pure Lua. Side effects (JSON read/write, directory creation) are injected
--- via `deps`, so tests can run against in-memory adapters without Hammerspoon.

local Store = {}
Store.__index = Store

local DEFAULT_PROFILE = "Default"
local DEFAULT_MODIFIERS = {"cmd", "alt", "ctrl"}
local DEFAULT_AUTO_RESTORE = "auto"

--- Store.new(deps) -> store
--- deps:
---  * profilesFile  - path passed to readJson/writeJson for profile data
---  * settingsFile  - path passed to readJson/writeJson for settings
---  * readJson(path) -> table|nil
---  * writeJson(data, path)
---  * ensureStorage() - optional; called before any read/write
function Store.new(deps)
    assert(deps and deps.readJson and deps.writeJson, "store: readJson/writeJson deps required")
    local self = setmetatable({}, Store)
    self.deps = deps
    self._settings = nil -- lazy snapshot; settings are read from disk once
    return self
end

function Store:_ensure()
    if self.deps.ensureStorage then self.deps.ensureStorage() end
end

-- ============ Settings ============
-- Loaded once into a snapshot; setters persist and refresh the snapshot.

function Store:settings()
    if not self._settings then
        self:_ensure()
        self._settings = self.deps.readJson(self.deps.settingsFile) or {}
    end
    return self._settings
end

function Store:saveSettings(settings)
    self:_ensure()
    self.deps.writeJson(settings, self.deps.settingsFile)
    self._settings = settings
end

function Store:setSetting(key, value)
    local settings = self:settings()
    settings[key] = value
    self:saveSettings(settings)
end

function Store:baseModifiers()
    return self:settings().baseModifiers or DEFAULT_MODIFIERS
end

function Store:autoRestoreMode()
    return self:settings().autoRestoreMode or DEFAULT_AUTO_RESTORE
end

-- ============ Profiles ============
-- On-disk shape (after migration):
--   { [configId] = { active = name, layouts = { [name] = { windows, timestamp, display_count } } } }
-- Legacy shape (pre-profiles): { [configId] = { windows = {...}, timestamp = ... } }
-- Migration is normalize-on-load: callers only ever see the current shape.

local function normalize(profiles)
    for _, entry in pairs(profiles) do
        if entry.windows then
            entry.layouts = {
                [DEFAULT_PROFILE] = {
                    windows = entry.windows,
                    timestamp = entry.timestamp
                }
            }
            entry.windows = nil
            entry.timestamp = nil
            entry.active = DEFAULT_PROFILE
        end
        entry.layouts = entry.layouts or {}
        entry.active = entry.active or DEFAULT_PROFILE
    end
    return profiles
end

function Store:_load()
    self:_ensure()
    return normalize(self.deps.readJson(self.deps.profilesFile) or {})
end

function Store:_save(profiles)
    self:_ensure()
    self.deps.writeJson(profiles, self.deps.profilesFile)
end

--- Is there anything saved for this display configuration?
function Store:hasConfig(configId)
    return self:_load()[configId] ~= nil
end

function Store:activeProfileName(configId)
    local entry = self:_load()[configId]
    if not entry then return DEFAULT_PROFILE end
    return entry.active
end

--- Layout of the active profile for this display configuration, or nil.
function Store:activeLayout(configId)
    local entry = self:_load()[configId]
    if not entry then return nil end
    return entry.layouts[entry.active]
end

--- Sorted profile names for this display configuration.
function Store:profileNames(configId)
    local names = {}
    local entry = self:_load()[configId]
    if entry then
        for name in pairs(entry.layouts) do
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

--- Save a layout under `name` (nil = the active profile) and make it active.
--- Returns the resolved profile name.
function Store:saveLayout(configId, name, windows, displayCount)
    local profiles = self:_load()
    local entry = profiles[configId]
    if not entry then
        entry = { active = DEFAULT_PROFILE, layouts = {} }
        profiles[configId] = entry
    end

    local targetName = name or entry.active
    entry.layouts[targetName] = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        windows = windows,
        display_count = displayCount
    }
    entry.active = targetName

    self:_save(profiles)
    return targetName
end

--- Make `name` the active profile. Returns false if this display
--- configuration has nothing saved yet.
function Store:setActive(configId, name)
    local profiles = self:_load()
    if not profiles[configId] then return false end
    profiles[configId].active = name
    self:_save(profiles)
    return true
end

return Store
