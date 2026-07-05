-- Menu Minimap spec: scale-to-fit math and window placement, including the
-- awkward arrangements — negative origins (a display left of the primary),
-- stacked displays taller than the picture, and stale saved windows whose
-- screen is no longer attached.

return function(t, root)
    local minimap = dofile(root .. "SnapBack.spoon/minimap.lua")

    -- His real shape: laptop + two externals, one mounted left of origin
    local laptop = { x = 0,     y = 0, w = 1512, h = 982,  name = "Built-in Retina Display", uuid = "UUID-LAPTOP" }
    local dellA  = { x = 1512,  y = -400, w = 2560, h = 1440, name = "DELL U2723QE", uuid = "UUID-DELL-A" }
    local dellB  = { x = -2560, y = -400, w = 2560, h = 1440, name = "DELL U2720Q",  uuid = "UUID-DELL-B" }

    t.test("no screens -> nil", function()
        t.eq(minimap.layout({}, {}), nil)
        t.eq(minimap.layout(nil, {}), nil)
    end)

    t.test("wide arrangements fill the picture width, aspect preserved", function()
        local plan = minimap.layout({ laptop, dellA }, {}, { width = 260, padding = 10 })
        t.eq(plan.width, 260, "width")
        -- span: x 0..4072, y -400..1040
        local s = plan.screens[1]
        t.eq(s.x, 10, "leftmost at padding")
        t.ok(math.abs(s.w - 1512 * (240 / 4072)) < 1e-9, "scaled to span")
        -- aspect: h/w of the drawn rect matches the real display
        t.ok(math.abs(s.h / s.w - 982 / 1512) < 1e-9, "aspect ratio")
        t.ok(math.abs(plan.height - (1440 * (240 / 4072) + 20)) < 1e-9, "height hugs the content")
        t.eq(s.name, "Built-in Retina Display", "name carried through")
    end)

    t.test("a lone laptop screen is height-limited, not width-limited", function()
        -- 1512x982 at width 240 would be ~176 tall; the clamp kicks in
        local plan = minimap.layout({ laptop }, {}, { width = 260, padding = 10, maxHeight = 150 })
        t.eq(plan.height, 150, "clamped height")
        t.ok(plan.width < 260, "narrower picture")
        t.ok(math.abs(plan.scale - 130 / 982) < 1e-9, "scale from height")
    end)

    t.test("negative origins normalise: leftmost screen starts at the padding", function()
        local plan = minimap.layout({ laptop, dellA, dellB }, {}, { width = 260, padding = 10 })
        -- arrangement spans x -2560..4072, y -400..982
        local leftmost = plan.screens[3]
        t.eq(leftmost.x, 10, "leftmost at padding")
        local topEdge = math.min(plan.screens[1].y, plan.screens[2].y, plan.screens[3].y)
        t.eq(topEdge, 10, "topmost at padding")
        -- laptop sits between the two Dells, scaled consistently
        local scale = 240 / (4072 + 2560)
        t.ok(math.abs(plan.screens[1].x - (10 + 2560 * scale)) < 1e-9, "laptop offset")
    end)

    t.test("tall arrangements clamp to maxHeight and narrow the picture", function()
        local stacked = {
            { x = 0, y = 0,    w = 1000, h = 2000, uuid = "A" },
            { x = 0, y = 2000, w = 1000, h = 2000, uuid = "B" },
        }
        local plan = minimap.layout(stacked, {}, { width = 260, padding = 10, maxHeight = 150 })
        t.eq(plan.height, 150, "clamped height")
        t.ok(plan.width < 260, "width shrinks to keep aspect")
        local expectedScale = 130 / 4000
        t.ok(math.abs(plan.scale - expectedScale) < 1e-9, "scale from height")
    end)

    t.test("window lands inside its screen, matched by UUID", function()
        local win = { frame = { x = 1512 + 1280, y = -400, w = 1280, h = 1440 },
                      screen_uuid = "UUID-DELL-A", screen = "DELL U2723QE" }
        local plan = minimap.layout({ laptop, dellA }, { win }, { width = 260, padding = 10 })
        t.eq(#plan.windows, 1, "one window drawn")
        t.eq(plan.dropped, 0, "nothing dropped")
        local w, s = plan.windows[1], plan.screens[2]
        -- right half of the Dell: starts at its horizontal midpoint
        t.ok(math.abs(w.x - (s.x + s.w / 2)) < 1e-9, "x at screen midpoint")
        t.ok(math.abs(w.w - s.w / 2) < 1e-9, "half the screen wide")
        t.ok(math.abs(w.h - s.h) < 1e-9, "full screen tall")
    end)

    t.test("falls back to matching by display name when the UUID is gone", function()
        local win = { frame = { x = 0, y = 0, w = 756, h = 982 },
                      screen_uuid = "UUID-OLD", screen = "Built-in Retina Display" }
        local plan = minimap.layout({ laptop }, { win })
        t.eq(#plan.windows, 1, "matched by name")
        t.eq(plan.dropped, 0, "not dropped")
    end)

    t.test("windows from a detached screen are counted, not drawn", function()
        local win = { frame = { x = 1512, y = -400, w = 1280, h = 1440 },
                      screen_uuid = "UUID-DELL-A", screen = "DELL U2723QE" }
        local plan = minimap.layout({ laptop }, { win })
        t.eq(#plan.windows, 0, "not drawn")
        t.eq(plan.dropped, 1, "counted as dropped")
    end)

    t.test("overhanging saved frames are clamped to their screen", function()
        -- window extends 200pt past the laptop's right edge
        local win = { frame = { x = 1312, y = 0, w = 400, h = 982 },
                      screen_uuid = "UUID-LAPTOP" }
        local plan = minimap.layout({ laptop }, { win }, { width = 260, padding = 10 })
        local w, s = plan.windows[1], plan.screens[1]
        t.ok(math.abs((w.x + w.w) - (s.x + s.w)) < 1e-9, "clamped at right edge")
    end)

    t.test("degenerate clamped windows are dropped", function()
        -- entirely off the right side of its own recorded screen
        local win = { frame = { x = 1512, y = 0, w = 400, h = 982 },
                      screen_uuid = "UUID-LAPTOP" }
        local plan = minimap.layout({ laptop }, { win })
        t.eq(#plan.windows, 0, "not drawn")
        t.eq(plan.dropped, 1, "dropped")
    end)
end
