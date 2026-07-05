--- === SnapBack.minimap ===
---
--- Menu Minimap: a to-scale picture of the current display arrangement with
--- the active profile's saved windows ghosted in, shown at the top of the
--- menubar dropdown. The layout math is pure Lua over plain {x, y, w, h}
--- tables so it runs under the test suite; only `render` touches
--- Hammerspoon (hs.canvas).

local minimap = {}

local DEFAULTS = { width = 260, padding = 10, maxHeight = 150 }

--- minimap.layout(screens, windows, opts) -> plan | nil
--- Scale a display arrangement (global coordinates) to fit a menu-sized
--- picture, and place each saved window inside its screen.
---
--- screens: { {x, y, w, h, name = ?, uuid = ?}, ... } current display frames
--- windows: { {frame = {x,y,w,h}, screen_uuid = ?, screen = ?}, ... } saved
---          windows from a profile layout; a window's screen is resolved by
---          UUID first, display name second (mirroring restoreLayout)
--- opts:    { width = 260, padding = 10, maxHeight = 150 } in points
---
--- Returns nil when there are no screens, otherwise:
---   { width, height, scale, screens = {rects with .name}, windows = {rects},
---     dropped = count of saved windows with no screen in this arrangement }
function minimap.layout(screens, windows, opts)
    if not screens or #screens == 0 then return nil end
    opts = opts or {}
    local width = opts.width or DEFAULTS.width
    local padding = opts.padding or DEFAULTS.padding
    local maxHeight = opts.maxHeight or DEFAULTS.maxHeight

    -- Bounding box of the whole arrangement
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for _, s in ipairs(screens) do
        minX = math.min(minX, s.x); minY = math.min(minY, s.y)
        maxX = math.max(maxX, s.x + s.w); maxY = math.max(maxY, s.y + s.h)
    end

    -- Fit to width; if a tall arrangement (stacked displays) would exceed
    -- maxHeight, fit to height instead and let the picture be narrower
    local scale = (width - 2 * padding) / (maxX - minX)
    local height = (maxY - minY) * scale + 2 * padding
    if height > maxHeight then
        scale = (maxHeight - 2 * padding) / (maxY - minY)
        height = maxHeight
        width = (maxX - minX) * scale + 2 * padding
    end

    local function place(r)
        return {
            x = padding + (r.x - minX) * scale,
            y = padding + (r.y - minY) * scale,
            w = r.w * scale,
            h = r.h * scale,
        }
    end

    local plan = {
        width = width, height = height, scale = scale,
        screens = {}, windows = {}, dropped = 0,
    }

    local byKey = {}
    for _, s in ipairs(screens) do
        local rect = place(s)
        rect.name = s.name
        table.insert(plan.screens, rect)
        if s.uuid then byKey[s.uuid] = rect end
        if s.name and not byKey[s.name] then byKey[s.name] = rect end
    end

    for _, w in ipairs(windows or {}) do
        local home = (w.screen_uuid and byKey[w.screen_uuid])
                  or (w.screen and byKey[w.screen])
        if home and w.frame then
            local rect = place(w.frame)
            -- Saved frames can overhang their screen (menubar inset, drags
            -- mid-flight); clamp so the picture never draws off-display
            local x2 = math.min(rect.x + rect.w, home.x + home.w)
            local y2 = math.min(rect.y + rect.h, home.y + home.h)
            rect.x = math.max(rect.x, home.x)
            rect.y = math.max(rect.y, home.y)
            rect.w = x2 - rect.x
            rect.h = y2 - rect.y
            if rect.w > 1 and rect.h > 1 then
                table.insert(plan.windows, rect)
            else
                plan.dropped = plan.dropped + 1
            end
        else
            plan.dropped = plan.dropped + 1
        end
    end

    return plan
end

-- Drawing palette: SnapBack indigo windows over neutral screen glass —
-- mid-tones chosen to stay legible on both light and dark menu themes.
-- Window fills stay faint so stacked/maximized windows read as outlines
-- instead of washing the screen solid.
local COLORS = {
    screenFill   = { red = 0.50, green = 0.50, blue = 0.55, alpha = 0.12 },
    screenStroke = { red = 0.50, green = 0.50, blue = 0.55, alpha = 0.90 },
    windowFill   = { red = 0.39, green = 0.40, blue = 0.95, alpha = 0.18 },
    windowStroke = { red = 0.39, green = 0.40, blue = 0.95, alpha = 1.00 },
    labelPill    = { red = 0.10, green = 0.10, blue = 0.12, alpha = 0.60 },
    labelText    = { red = 1.00, green = 1.00, blue = 1.00, alpha = 0.95 },
}

--- minimap.render(plan) -> hs.image | nil
--- Draw a layout plan onto an hs.canvas and return it as an image suitable
--- for a menu item. Hammerspoon-only.
function minimap.render(plan)
    if not plan then return nil end
    local c = hs.canvas.new{ x = 0, y = 0, w = plan.width, h = plan.height }

    for _, s in ipairs(plan.screens) do
        local frame = { x = s.x, y = s.y, w = s.w, h = s.h }
        c[#c + 1] = { type = "rectangle", action = "fill",
            fillColor = COLORS.screenFill,
            roundedRectRadii = { xRadius = 3, yRadius = 3 },
            frame = frame }
        c[#c + 1] = { type = "rectangle", action = "stroke",
            strokeColor = COLORS.screenStroke, strokeWidth = 1,
            roundedRectRadii = { xRadius = 3, yRadius = 3 },
            frame = frame }
    end

    for _, w in ipairs(plan.windows) do
        local frame = { x = w.x, y = w.y, w = w.w, h = w.h }
        c[#c + 1] = { type = "rectangle", action = "fill",
            fillColor = COLORS.windowFill,
            roundedRectRadii = { xRadius = 1.5, yRadius = 1.5 },
            frame = frame }
        c[#c + 1] = { type = "rectangle", action = "stroke",
            strokeColor = COLORS.windowStroke, strokeWidth = 1,
            roundedRectRadii = { xRadius = 1.5, yRadius = 1.5 },
            frame = frame }
    end

    -- Screen names on a pill along each display's bottom edge, drawn last
    -- so they stay readable over maximized windows; skipped on displays
    -- drawn too small to label
    for _, s in ipairs(plan.screens) do
        if s.name and s.h > 34 and s.w > 56 then
            -- ~4.6pt/char approximates 8pt system-font width
            local pillW = math.min(#s.name * 4.6 + 12, s.w - 8)
            c[#c + 1] = { type = "rectangle", action = "fill",
                fillColor = COLORS.labelPill,
                roundedRectRadii = { xRadius = 6, yRadius = 6 },
                frame = { x = s.x + (s.w - pillW) / 2,
                          y = s.y + s.h - 17, w = pillW, h = 12 } }
            c[#c + 1] = { type = "text", text = s.name,
                textSize = 8, textColor = COLORS.labelText,
                textAlignment = "center",
                frame = { x = s.x + (s.w - pillW) / 2,
                          y = s.y + s.h - 16, w = pillW, h = 11 } }
        end
    end

    local img = c:imageFromCanvas()
    c:delete()
    return img
end

return minimap
