-- SnapBack — window layout manager
require("hs.ipc") -- Enable CLI handling

-- (Ensure SnapBack.spoon is in ~/.hammerspoon/Spoons/)
hs.loadSpoon("SnapBack")
spoon.SnapBack:start()
