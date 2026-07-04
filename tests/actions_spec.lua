-- Action Registry spec. The consistency tests are the point: every menu
-- row, hotkey, and cheat-sheet line derives from one registry, and every
-- snap direction in the registry must exist in the geometry module — the
-- class of drift where a hotkey and a menu item disagree is unrepresentable.

return function(t, root)
    local actions = dofile(root .. "SnapBack.spoon/actions.lua")
    local geometry = dofile(root .. "SnapBack.spoon/geometry.lua")

    t.test("every row has id, name, key, and exactly one behaviour", function()
        for _, row in ipairs(actions.list) do
            t.ok(row.id, "row missing id")
            t.ok(row.name, "row missing name: " .. row.id)
            t.ok(row.key, "row missing key: " .. row.id)
            local behaviours = (row.snap and 1 or 0) + (row.command and 1 or 0)
            t.eq(behaviours, 1, row.id .. " must have exactly one of snap/command")
        end
    end)

    t.test("ids and keys are unique", function()
        local ids, keys = {}, {}
        for _, row in ipairs(actions.list) do
            t.ok(not ids[row.id], "duplicate id: " .. row.id)
            t.ok(not keys[row.key], "duplicate key: " .. tostring(row.key))
            ids[row.id] = true
            keys[row.key] = true
        end
    end)

    t.test("every snap direction exists in the geometry module", function()
        for _, row in ipairs(actions.list) do
            if row.snap then
                t.ok(geometry.directions[row.snap],
                    row.id .. " points at unknown direction: " .. row.snap)
            end
        end
    end)

    t.test("menu rows have labels and known sections", function()
        local known = {}
        for _, s in ipairs(actions.menuSections) do known[s] = true end
        for _, row in ipairs(actions.list) do
            if row.section then
                t.ok(known[row.section], row.id .. ": unknown section " .. row.section)
                t.ok(row.label, row.id .. ": menu row without a label")
            end
        end
    end)

    t.test("Up/Down snap to halves — the divergence stays fixed", function()
        t.eq(actions.byId("snapUp").snap, "top")
        t.eq(actions.byId("snapDown").snap, "bottom")
        t.eq(actions.byId("maximize").key, "Return")
    end)

    t.test("shortcutLabel renders modifier and key glyphs", function()
        t.eq(actions.shortcutLabel({"cmd", "alt", "ctrl"}, "Left"), "  ⌘⌥⌃←")
        t.eq(actions.shortcutLabel({"cmd", "shift"}, "S"), "  ⌘⇧S")
        t.eq(actions.shortcutLabel({}, "delete"), "  ⌫")
    end)

    t.test("cheat sheet lists every registered action", function()
        local sheet = actions.cheatSheet({"cmd", "alt", "ctrl"})
        for _, row in ipairs(actions.list) do
            t.ok(sheet:find(row.name, 1, true), "cheat sheet missing: " .. row.name)
        end
    end)
end
