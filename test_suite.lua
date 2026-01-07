-- Test Suite Agent
-- Run from CLI: hs -c "dofile('test_suite.lua')"
-- or from Console: dofile('test_suite.lua')

local wl = require("window-layout")
local tester = {}

function tester.log(msg)
    print("[TEST AGENT] " .. msg)
end

function tester.run()
    tester.log("Starting diagnostics...")
    
    -- 1. Verify Storage Path
    tester.log("Storage Path: " .. tostring(wl.storagePath))
    local attr = hs.fs.attributes(wl.storagePath)
    if not attr then
        tester.log("FAIL: Storage path does not exist!")
        -- Attempt fix
        hs.fs.mkdir(wl.storagePath)
        tester.log("Attempted mkdir. Check: " .. tostring(hs.fs.attributes(wl.storagePath)))
    else
        tester.log("PASS: Storage path exists (" .. attr.mode .. ")")
    end
    
    -- 2. Verify Write Permissions
    local testFile = wl.storagePath .. "/write_test.txt"
    local f = io.open(testFile, "w")
    if f then
        f:write("test")
        f:close()
        tester.log("PASS: Write permission verified")
        os.remove(testFile)
    else
        tester.log("FAIL: Cannot write to storage path!")
    end
    
    -- 3. Verify JSON Saving
    local mockData = { ["current"] = { windows = {}, timestamp = "test" } }
    wl.saveProfiles(mockData)
    
    local readData = wl.loadProfiles()
    if readData and readData["current"] and readData["current"].timestamp == "test" then
        tester.log("PASS: JSON Save/Load cycle verified")
        print("SUCCESS: Core storage logic is working.")
    else
        tester.log("FAIL: JSON Save/Load cycle failed. Read data: " .. hs.inspect(readData))
        print("ERROR: Storage logic failed.")
    end
    
    -- 4. Verify Display Config ID
    local configId = wl.getDisplayConfigId()
    if configId and type(configId) == "string" and #configId > 0 then
        tester.log("PASS: Generated Display Config ID: " .. configId)
    else
        tester.log("FAIL: Display Config ID generation failed")
    end
    
    -- 5. Test Profile Switching Logic
    local dummyConfig = "test_display_config"
    local profiles = {}
    
    -- Test Migration Logic (Simulated)
    profiles[dummyConfig] = { windows = { { app="TestApp" } }, timestamp = "old" }
    
    -- Manually trigger the migration logic by running 'captureLayout' with a mock? 
    -- Easier: just test the logic directly if possible, or trust the integration test.
    -- Let's test the 'captureLayout' function creates the right structure.
    
    -- We can't easily mock captureLayout without mocking getting windows, 
    -- but we can check if getActiveProfileName works
    local active = wl.getActiveProfileName(profiles, dummyConfig)
    if active == "Default" then
         tester.log("PASS: Default profile name returned for legacy data")
    else
         tester.log("FAIL: Incorrect active profile for legacy data: " .. tostring(active))
    end
    
    -- 6. Test Smart Matching Helpers
    tester.log("Testing Smart Matching Helpers...")
    local t1 = wl.normalizeTitle("My Profile - Google Chrome")
    local t2 = wl.normalizeTitle("my profile")
    if t1 == t2 then
         tester.log("PASS: Normalize Title logic")
    else
         tester.log("FAIL: Normalize Title logic: '"..t1.."' vs '"..t2.."'")
    end
    
    local score = wl.calculateSimilarity("short", "longer string with short inside")
    if score > 0.8 then
         tester.log("PASS: Similarity Calculation")
    else
         tester.log("FAIL: Similarity Calculation score: " .. score)
    end

    tester.log("Diagnostics complete.")
end

tester.run()
return tester
