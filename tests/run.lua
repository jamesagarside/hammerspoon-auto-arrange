#!/usr/bin/env lua
-- Plain-Lua test runner for SnapBack's pure modules. No Hammerspoon needed.
-- Usage: lua tests/run.lua

local here = arg[0]:match("(.*[/\\])") or "./"
local root = here .. "../"

local t = { pass = 0, fail = 0, failures = {}, current = "?" }

local function fmt(v)
    if type(v) == "table" then
        local parts = {}
        for k, val in pairs(v) do table.insert(parts, tostring(k) .. "=" .. tostring(val)) end
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function deepEq(a, b)
    if type(a) == "number" and type(b) == "number" then
        return math.abs(a - b) < 1e-9
    end
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not deepEq(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

function t.eq(actual, expected, label)
    if not deepEq(actual, expected) then
        error(string.format("%s: expected %s, got %s", label or "eq", fmt(expected), fmt(actual)), 2)
    end
end

function t.ok(cond, label)
    if not cond then error((label or "ok") .. ": condition was falsy", 2) end
end

function t.test(name, fn)
    t.current = name
    local ok, err = pcall(fn)
    if ok then
        t.pass = t.pass + 1
        print("  PASS  " .. name)
    else
        t.fail = t.fail + 1
        table.insert(t.failures, name .. "\n        " .. tostring(err))
        print("  FAIL  " .. name .. "\n        " .. tostring(err))
    end
end

local specs = { "store_spec" }

for _, name in ipairs(specs) do
    print(name .. ":")
    dofile(here .. name .. ".lua")(t, root)
end

print(string.format("\n%d passed, %d failed", t.pass, t.fail))
os.exit(t.fail == 0 and 0 or 1)
