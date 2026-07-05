-- Smart Matching spec: the full cascade (ID → exact → fuzzy → slot) over
-- plain records — the part test_suite.lua could never reach when the
-- matcher demanded live hs.window objects.

return function(t, root)
    local matcher = dofile(root .. "SnapBack.spoon/matcher.lua")

    local function saved(id, app, title)
        return { id = id, app = app, title = title }
    end

    t.test("normalizeTitle strips suffixes, counters, punctuation", function()
        t.eq(matcher.normalizeTitle("My Doc - Google Chrome"), matcher.normalizeTitle("my doc"))
        t.eq(matcher.normalizeTitle("init.lua - Visual Studio Code"), matcher.normalizeTitle("initlua"))
        -- Counter is stripped; the space before "(2)" survives (quirk kept
        -- from the original — substring similarity still matches "inbox")
        t.eq(matcher.normalizeTitle("Inbox (2)"), "inbox ")
        t.ok(matcher.similarity(matcher.normalizeTitle("Inbox (2)"),
                                matcher.normalizeTitle("Inbox")) > 0.5)
        t.eq(matcher.normalizeTitle(nil), "")
    end)

    t.test("similarity: substring containment scores 0.9", function()
        t.ok(matcher.similarity("short", "longer with short inside") > 0.8)
        t.eq(matcher.similarity("abc", "xyz"), 0.0)
        t.eq(matcher.similarity("", ""), 1.0)
    end)

    t.test("cascade: ID match wins even when titles changed", function()
        local cand, matchType = matcher.findBestMatch(
            saved(42, "Chrome", "Old Title"),
            { saved(41, "Chrome", "Old Title"), saved(42, "Chrome", "Totally New") },
            {})
        t.eq(cand.id, 42)
        t.eq(matchType, "ID")
    end)

    t.test("cascade: exact app+title match when the ID is gone", function()
        local cand, matchType = matcher.findBestMatch(
            saved(42, "Chrome", "Docs"),
            { saved(7, "Chrome", "Docs"), saved(8, "Chrome", "Other") },
            {})
        t.eq(cand.id, 7)
        t.eq(matchType, "Exact")
    end)

    t.test("cascade: fuzzy title match within the same app", function()
        local cand, matchType = matcher.findBestMatch(
            saved(42, "Chrome", "Project Plan - Google Chrome"),
            { saved(7, "Chrome", "Project Plan v2"), saved(8, "Safari", "Project Plan") },
            {})
        t.eq(cand.id, 7, "same-app fuzzy candidate")
        t.eq(matchType, "Fuzzy")
    end)

    t.test("cascade: app slot as last resort", function()
        local cand, matchType = matcher.findBestMatch(
            saved(42, "Terminal", "zsh — 80x24"),
            { saved(7, "Terminal", "completely unrelated telemetry 9000") },
            {})
        t.eq(cand.id, 7)
        t.eq(matchType, "Slot")
    end)

    t.test("cascade: no candidate from another app", function()
        local cand = matcher.findBestMatch(
            saved(42, "Terminal", "zsh"),
            { saved(7, "Safari", "zsh") },
            {})
        t.eq(cand, nil)
    end)

    t.test("used candidates are skipped at every tier", function()
        local cands = { saved(42, "Chrome", "Docs") }
        local cand = matcher.findBestMatch(saved(42, "Chrome", "Docs"), cands, { [42] = true })
        t.eq(cand, nil)
    end)

    t.test("assign: each candidate used at most once, in saved order", function()
        local savedWins = {
            saved(1, "Chrome", "Docs"),
            saved(2, "Chrome", "Docs"), -- same title: must take the other window
        }
        local cands = { saved(10, "Chrome", "Docs"), saved(11, "Chrome", "Docs") }
        local matches, unmatched = matcher.assign(savedWins, cands)
        t.eq(#matches, 2)
        t.eq(#unmatched, 0)
        t.ok(matches[1].candidate.id ~= matches[2].candidate.id, "distinct candidates")
    end)

    t.test("assign: reports unmatched saved windows", function()
        local matches, unmatched = matcher.assign(
            { saved(1, "Chrome", "Docs"), saved(2, "Figma", "Board") },
            { saved(10, "Chrome", "Docs") })
        t.eq(#matches, 1)
        t.eq(#unmatched, 1)
        t.eq(unmatched[1].app, "Figma")
    end)

    t.test("assign: extra record fields pass through untouched", function()
        local liveWin = { marker = "live" }
        local matches = matcher.assign(
            { saved(1, "Chrome", "Docs") },
            { { id = 1, app = "Chrome", title = "Docs", win = liveWin } })
        t.eq(matches[1].candidate.win.marker, "live")
    end)
end
