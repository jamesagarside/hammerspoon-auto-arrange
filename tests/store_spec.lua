-- Profile Store spec: exercises the store through its interface only,
-- with in-memory adapters standing in for hs.json/hs.fs.

return function(t, root)
    local Store = dofile(root .. "SnapBack.spoon/store.lua")

    local function deepcopy(v)
        if type(v) ~= "table" then return v end
        local out = {}
        for k, val in pairs(v) do out[k] = deepcopy(val) end
        return out
    end

    -- In-memory adapter: returns fresh copies on read (like hs.json.read)
    local function fakeStore(initialProfiles, initialSettings)
        local files = { profiles = initialProfiles, settings = initialSettings }
        local reads = { profiles = 0, settings = 0 }
        local store = Store.new{
            profilesFile = "profiles",
            settingsFile = "settings",
            readJson = function(path)
                reads[path] = reads[path] + 1
                return deepcopy(files[path])
            end,
            writeJson = function(data, path) files[path] = deepcopy(data) end,
        }
        return store, files, reads
    end

    t.test("settings load from disk exactly once", function()
        local store, _, reads = fakeStore(nil, { autoRestoreMode = "prompt" })
        t.eq(store:autoRestoreMode(), "prompt")
        t.eq(store:baseModifiers(), {"cmd", "alt", "ctrl"}, "default modifiers")
        store:autoRestoreMode()
        t.eq(reads.settings, 1, "settings disk reads")
    end)

    t.test("setSetting persists and refreshes the snapshot", function()
        local store, files = fakeStore(nil, nil)
        store:setSetting("autoRestoreMode", "disabled")
        t.eq(store:autoRestoreMode(), "disabled")
        t.eq(files.settings.autoRestoreMode, "disabled", "persisted value")
        store:setSetting("baseModifiers", {"cmd", "shift"})
        t.eq(store:baseModifiers(), {"cmd", "shift"})
    end)

    t.test("empty store: sane defaults through the interface", function()
        local store = fakeStore(nil, nil)
        t.eq(store:hasConfig("cfg"), false)
        t.eq(store:activeProfileName("cfg"), "Default")
        t.eq(store:activeLayout("cfg"), nil)
        t.eq(store:profileNames("cfg"), {})
    end)

    t.test("legacy flat-windows format is migrated on load", function()
        local store = fakeStore({
            cfg = { windows = { { app = "Safari" } }, timestamp = "old" }
        }, nil)
        t.eq(store:hasConfig("cfg"), true)
        t.eq(store:activeProfileName("cfg"), "Default")
        t.eq(store:profileNames("cfg"), {"Default"})
        local layout = store:activeLayout("cfg")
        t.eq(layout.timestamp, "old", "legacy timestamp carried over")
        t.eq(layout.windows[1].app, "Safari")
    end)

    t.test("saveLayout on a fresh config resolves to Default", function()
        local store, files = fakeStore(nil, nil)
        local name = store:saveLayout("cfg", nil, { { app = "Mail" } }, 2)
        t.eq(name, "Default")
        t.eq(files.profiles.cfg.active, "Default")
        t.eq(files.profiles.cfg.layouts.Default.display_count, 2)
        t.ok(files.profiles.cfg.layouts.Default.timestamp:match("^%d+-%d+-%d+T"),
            "ISO timestamp")
    end)

    t.test("saveLayout with a name creates the profile and makes it active", function()
        local store = fakeStore(nil, nil)
        store:saveLayout("cfg", "Coding", {}, 1)
        t.eq(store:activeProfileName("cfg"), "Coding")
        -- nil name now saves to the active profile, not Default
        local name = store:saveLayout("cfg", nil, { { app = "Terminal" } }, 1)
        t.eq(name, "Coding")
        t.eq(store:activeLayout("cfg").windows[1].app, "Terminal")
    end)

    t.test("profileNames is sorted", function()
        local store = fakeStore(nil, nil)
        store:saveLayout("cfg", "Meeting", {}, 1)
        store:saveLayout("cfg", "Coding", {}, 1)
        t.eq(store:profileNames("cfg"), {"Coding", "Meeting"})
    end)

    t.test("setActive only succeeds for known configs", function()
        local store = fakeStore(nil, nil)
        t.eq(store:setActive("cfg", "Coding"), false)
        store:saveLayout("cfg", "Coding", {}, 1)
        store:saveLayout("cfg", "Meeting", {}, 1)
        t.eq(store:setActive("cfg", "Coding"), true)
        t.eq(store:activeProfileName("cfg"), "Coding")
    end)

    t.test("migration is written back in the new shape on next save", function()
        local store, files = fakeStore({
            cfg = { windows = { { app = "Safari" } }, timestamp = "old" }
        }, nil)
        store:saveLayout("cfg", "Coding", {}, 1)
        t.eq(files.profiles.cfg.windows, nil, "legacy key gone from disk")
        t.ok(files.profiles.cfg.layouts.Default, "legacy windows preserved as Default")
        t.ok(files.profiles.cfg.layouts.Coding, "new profile saved")
    end)
end
