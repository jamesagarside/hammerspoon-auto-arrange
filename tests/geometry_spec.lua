-- Snap Geometry spec: frame math verified against the numbers the old
-- 17-branch if/else produced, on a screen with a non-zero origin
-- (external display) to catch offset mistakes.

return function(t, root)
    local geometry = dofile(root .. "SnapBack.spoon/geometry.lua")

    -- External display: origin not at 0,0
    local screen = { x = 100, y = 50, w = 1440, h = 900 }

    local cases = {
        left           = { x = 100,        y = 50,  w = 720,      h = 900 },
        right          = { x = 820,        y = 50,  w = 720,      h = 900 },
        top            = { x = 100,        y = 50,  w = 1440,     h = 450 },
        bottom         = { x = 100,        y = 500, w = 1440,     h = 450 },
        topLeft        = { x = 100,        y = 50,  w = 720,      h = 450 },
        topRight       = { x = 820,        y = 50,  w = 720,      h = 450 },
        bottomLeft     = { x = 100,        y = 500, w = 720,      h = 450 },
        bottomRight    = { x = 820,        y = 500, w = 720,      h = 450 },
        leftThird      = { x = 100,        y = 50,  w = 480,      h = 900 },
        centerThird    = { x = 580,        y = 50,  w = 480,      h = 900 },
        rightThird     = { x = 1060,       y = 50,  w = 480,      h = 900 },
        leftTwoThirds  = { x = 100,        y = 50,  w = 960,      h = 900 },
        rightTwoThirds = { x = 580,        y = 50,  w = 960,      h = 900 },
        maximize       = { x = 100,        y = 50,  w = 1440,     h = 900 },
        center         = { x = 316,        y = 185, w = 1008,     h = 630 },
    }

    for direction, expected in pairs(cases) do
        t.test("frameFor: " .. direction, function()
            t.eq(geometry.frameFor(direction, screen), expected)
        end)
    end

    t.test("frameFor: unknown direction returns nil", function()
        t.eq(geometry.frameFor("diagonal", screen), nil)
        t.eq(geometry.frameFor("minimize", screen), nil)
    end)

    t.test("framesMatch: within default 5pt tolerance", function()
        local a = { x = 0, y = 0, w = 720, h = 900 }
        t.ok(geometry.framesMatch(a, { x = 4, y = -4, w = 724, h = 896 }))
        t.ok(not geometry.framesMatch(a, { x = 5, y = 0, w = 720, h = 900 }))
        t.ok(not geometry.framesMatch(a, { x = 0, y = 0, w = 726, h = 900 }))
    end)

    t.test("isCycle: same window + direction within 2 seconds", function()
        local last = { winId = 7, direction = "left", time = 100 }
        t.ok(geometry.isCycle(last, 7, "left", 101), "1s later")
        t.ok(not geometry.isCycle(last, 7, "left", 102), "2s later is too late")
        t.ok(not geometry.isCycle(last, 8, "left", 101), "different window")
        t.ok(not geometry.isCycle(last, 7, "right", 101), "different direction")
        t.ok(not geometry.isCycle({ time = 0 }, 7, "left", 101), "no previous snap")
    end)

    t.test("cycleMove: only horizontal halves cycle across screens", function()
        t.eq(geometry.cycleMove.left, "west")
        t.eq(geometry.cycleMove.right, "east")
        t.eq(geometry.cycleMove.top, nil)
        t.eq(geometry.cycleMove.maximize, nil)
    end)
end
