-- Window Layout Manager
require("hs.ipc") -- Enable CLI handling

-- Load the AutoArrange Spoon
-- (Ensure AutoArrange.spoon is in ~/.hammerspoon/Spoons/)
hs.loadSpoon("AutoArrange")
spoon.AutoArrange:start()

-- Legacy Load (Disabled)
-- local windowLayout = require("window-layout")
-- windowLayout.start()
