--- === SnapBack.geometry ===
---
--- Snap Geometry: pure frame math for every snap direction, plus the
--- cycle-detection decision. No Hammerspoon types cross this interface —
--- frames are plain {x, y, w, h} tables — so it runs under plain Lua.

local geometry = {}

-- Each direction as screen fractions: {x, y, w, h} of the screen frame.
local FRACTIONS = {
    -- Halves
    left           = {0,     0,    0.5,  1},
    right          = {0.5,   0,    0.5,  1},
    top            = {0,     0,    1,    0.5},
    bottom         = {0,     0.5,  1,    0.5},
    -- Quarters (corners)
    topLeft        = {0,     0,    0.5,  0.5},
    topRight       = {0.5,   0,    0.5,  0.5},
    bottomLeft     = {0,     0.5,  0.5,  0.5},
    bottomRight    = {0.5,   0.5,  0.5,  0.5},
    -- Thirds
    leftThird      = {0,     0,    1/3,  1},
    centerThird    = {1/3,   0,    1/3,  1},
    rightThird     = {2/3,   0,    1/3,  1},
    leftTwoThirds  = {0,     0,    2/3,  1},
    rightTwoThirds = {1/3,   0,    2/3,  1},
    -- Standard
    maximize       = {0,     0,    1,    1},
    center         = {0.15,  0.15, 0.7,  0.7},
}

geometry.directions = FRACTIONS

-- Pressing the same direction twice walks the window across screens column
-- by column: a right-half window continues to the LEFT half of the screen
-- to the east (and mirrored for left), so repeated presses traverse the
-- whole display setup half-by-half.
geometry.cycle = {
    left  = { toward = "west", landing = "right" },
    right = { toward = "east", landing = "left" },
}

--- geometry.frameFor(direction, screen) -> frame | nil
--- Target frame for a snap direction within a screen frame {x, y, w, h}.
--- Returns nil for directions with no frame (unknown, or e.g. "minimize").
function geometry.frameFor(direction, screen)
    local fr = FRACTIONS[direction]
    if not fr then return nil end
    return {
        x = screen.x + fr[1] * screen.w,
        y = screen.y + fr[2] * screen.h,
        w = fr[3] * screen.w,
        h = fr[4] * screen.h,
    }
end

--- Are two frames the same position/size within a tolerance (default 5pt)?
function geometry.framesMatch(a, b, tolerance)
    tolerance = tolerance or 5
    return math.abs(a.x - b.x) < tolerance and
           math.abs(a.y - b.y) < tolerance and
           math.abs(a.w - b.w) < tolerance and
           math.abs(a.h - b.h) < tolerance
end

--- Same window snapped in the same direction within 2 seconds?
--- lastSnap: {winId, direction, time} — the previous snap decision.
function geometry.isCycle(lastSnap, winId, direction, now)
    return lastSnap.winId == winId and
           lastSnap.direction == direction and
           (now - (lastSnap.time or 0)) < 2
end

return geometry
