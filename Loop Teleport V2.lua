
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local moveKeybind, pathKeybind, followKeybind, flyKeybind, espKeybind = nil, nil, nil, nil, nil
local clickKeybind, undoKeybind, holdKeybind = nil, nil, nil
local pCombo = nil

local waypoints = {}
local sequenceIndex = 1
local sequenceDirection = 1

local waypointDrawings = {}
local waypointLines = {}

local wpColor = Color3.fromRGB(0, 255, 0)
local hoverY = nil
local lastTeleportPos = nil
local lastRecordedPos = nil
local activeHold = false
local clickTpPrev = false
local undoPrev = false
local holdPrev = false

local espPoolSize = 32
local espTargets = {}
local espColor = Color3.fromRGB(255, 80, 80)
local espDrawings = {}
for i = 1, espPoolSize do
    local e = {}
    e.box = Drawing.new("Square")
    e.box.Thickness = 1
    e.box.Filled = false
    e.box.Visible = false
    e.name = Drawing.new("Text")
    e.name.Size = 13
    e.name.Center = true
    e.name.Outline = true
    e.name.Visible = false
    e.hpBG = Drawing.new("Square")
    e.hpBG.Filled = true
    e.hpBG.Visible = false
    e.hpFill = Drawing.new("Square")
    e.hpFill.Filled = true
    e.hpFill.Visible = false
    e.line = Drawing.new("Line")
    e.line.Thickness = 1
    e.line.Visible = false
    espDrawings[i] = e
end

local xhDot = Drawing.new("Circle")
xhDot.Thickness = 1
xhDot.Color = Color3.fromRGB(0, 255, 0)
xhDot.Visible = false
local xhH = Drawing.new("Line")
xhH.Thickness = 1
xhH.Color = Color3.fromRGB(0, 255, 0)
xhH.Visible = false
local xhV = Drawing.new("Line")
xhV.Thickness = 1
xhV.Color = Color3.fromRGB(0, 255, 0)
xhV.Visible = false

local function keyDown(k)
    return UserInputService:IsKeyDown(k)
end

local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function getCurrentPos()
    local root = getRoot(LocalPlayer.Character)
    if root then
        local p = root.Position
        if typeof(p) == "Vector3" then return p end
    end
    return Vector3.new(0, 0, 0)
end

local function getDistance(v1, v2)
    if typeof(v1) ~= "Vector3" or typeof(v2) ~= "Vector3" then return math.huge end
    return (v1 - v2).Magnitude
end

local function stepTowards(current, target, step)
    local diff = target - current
    local dist = diff.Magnitude
    if dist <= step or dist == 0 then return target end
    return current + (diff.Unit * step)
end

local function executeTeleportLogic(primaryPart, targetPos, mode, stepDist, reqConditionFn)
    if typeof(targetPos) ~= "Vector3" then return false end
    if mode == 0 then
        primaryPart.CFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z)
        pcall(function() primaryPart.Velocity = Vector3.new(0, 0, 0) end)
        if UI.GetValue("tp_notifications") then notify("Moved!", "App", 1) end
        return true
    else
        local currentPos = primaryPart.Position
        if typeof(currentPos) ~= "Vector3" then return false end
        while getDistance(currentPos, targetPos) > stepDist do
            if reqConditionFn and not reqConditionFn() then return false end
            currentPos = stepTowards(currentPos, targetPos, stepDist)
            primaryPart.CFrame = CFrame.new(currentPos.X, currentPos.Y, currentPos.Z)
            task.wait()
        end
        if reqConditionFn and not reqConditionFn() then return false end
        primaryPart.CFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z)
        pcall(function() primaryPart.Velocity = Vector3.new(0, 0, 0) end)
        if UI.GetValue("tp_notifications") then notify("Moved!", "App", 1) end
        return true
    end
end

local function teleportTo(targetPos, isStalk, continuous)
    local primaryPart = getRoot(LocalPlayer.Character)
    if not primaryPart then return false end
    if typeof(targetPos) ~= "Vector3" then return false end
    if not isStalk then
        local p = primaryPart.Position
        if typeof(p) == "Vector3" then lastTeleportPos = p end
    end
    local mode = UI.GetValue("tp_mode") or 0
    local stepDist = UI.GetValue("tp_step_dist") or 20
    return executeTeleportLogic(primaryPart, targetPos, mode, stepDist, function()
        if not continuous then return true end
        return UI.GetValue("tp_enabled") or UI.GetValue("seq_enabled") or UI.GetValue("stalk_enabled")
    end)
end

local function doFlashback()
    if lastTeleportPos and typeof(lastTeleportPos) == "Vector3" then
        local primaryPart = getRoot(LocalPlayer.Character)
        if primaryPart then
            primaryPart.CFrame = CFrame.new(lastTeleportPos.X, lastTeleportPos.Y, lastTeleportPos.Z)
            notify("Went back", "Undo", 1)
        end
    else
        notify("No spot saved!", "Undo", 1)
    end
end

local function getLookTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local origin = cam.CFrame.Position
    local endPos = (cam.CFrame * CFrame.new(0, 0, -3000)).Position
    local params = RaycastParams.new()
    local myChar = LocalPlayer.Character
    if myChar then params:AddToFilter(myChar) end
    local result = Workspace:Raycast(origin, endPos - origin, params)
    if result then return result.Position end
    return endPos
end

local function doClickTeleport()
    pcall(function()
        local target = getLookTarget()
        if target then
            teleportTo(target + Vector3.new(0, 3, 0), false)
        end
    end)
end

local function getSelectedWpIndex()
    return tonumber(UI.GetValue("wp_select_num") or "") or 0
end

local function refreshWpCombo()
    local cur = getSelectedWpIndex()
    if cur > #waypoints and #waypoints > 0 then
        UI.SetValue("wp_select_num", tostring(#waypoints))
    end
end

local function getHoldPoint()
    local idx = getSelectedWpIndex()
    if idx and waypoints[idx] then
        local wp = waypoints[idx]
        return Vector3.new(tonumber(wp.x) or 0, tonumber(wp.y) or 0, tonumber(wp.z) or 0), true
    end
    return getCurrentPos(), false
end

local function holdAtPoint(point, seconds, stopFn)
    if activeHold then return end
    activeHold = true
    task.spawn(function()
        local start = tick()
        while not stopFn or not stopFn() do
            if seconds and tick() - start >= seconds then break end
            local root = getRoot(LocalPlayer.Character)
            if root then
                if getDistance(root.Position, point) > 1.5 then
                    pcall(function() root.CFrame = CFrame.new(point.X, point.Y, point.Z) end)
                end
                pcall(function() root.Velocity = Vector3.new(0, 0, 0) end)
            end
            task.wait(0.3)
        end
        activeHold = false
    end)
end

local function saveConfig()
    local data = {
        tp_x = UI.GetValue("tp_x") or "-1095.28",
        tp_y = UI.GetValue("tp_y") or "60.4",
        tp_z = UI.GetValue("tp_z") or "-6.16",
        waypoints = waypoints
    }
    local success, json = pcall(function() return HttpService:JSONEncode(data) end)
    if success then
        setclipboard(json)
        notify("Saved code copied!", "App", 2)
        UI.SetValue("import_box", json)
    end
end

local function loadConfig(jsonStr)
    if not jsonStr or jsonStr == "" then return end
    local success, decoded = pcall(function() return HttpService:JSONDecode(jsonStr) end)
    if success and decoded then
        UI.SetValue("tp_x", tostring(decoded.tp_x or "-1095.28"))
        UI.SetValue("tp_y", tostring(decoded.tp_y or "60.4"))
        UI.SetValue("tp_z", tostring(decoded.tp_z or "-6.16"))
        if decoded.waypoints and type(decoded.waypoints) == "table" then
            waypoints = decoded.waypoints
        end
        refreshWpCombo()
        notify("Loaded safe!", "App", 2)
    end
end

UI.AddTab("Universal", function(tab)
    local moveSec = tab:Section("Move", "Left")
    moveSec:Toggle("tp_enabled", "Loop Move", false)
    moveKeybind = moveSec:Keybind("tp_keybind", 0x54, "toggle")
    moveKeybind:AddToHotkey("Loop Move", "tp_enabled")
    moveSec:Spacing()
    moveSec:InputText("tp_x", "X Spot", "-1095.28")
    moveSec:InputText("tp_y", "Y Spot", "60.4")
    moveSec:InputText("tp_z", "Z Spot", "-6.16")
    moveSec:Button("Get My Spot", function()
        local pos = getCurrentPos()
        UI.SetValue("tp_x", string.format("%.2f", pos.X))
        UI.SetValue("tp_y", string.format("%.2f", pos.Y))
        UI.SetValue("tp_z", string.format("%.2f", pos.Z))
    end)
    moveSec:Button("Copy Coords", function()
        local pos = getCurrentPos()
        setclipboard(string.format("%.2f, %.2f, %.2f", pos.X, pos.Y, pos.Z))
        notify("Coords copied!", "App", 1)
    end)
    moveSec:Spacing()
    moveSec:SliderFloat("tp_delay", "Loop Wait", 0.0, 10.0, 1.0, "%.2fs")
    moveSec:Combo("tp_mode", "Move Type", {"Fast", "Safe Mode"}, 0)
    moveSec:SliderInt("tp_step_dist", "Safe Mode Speed", 5, 100, 20)
    moveSec:Spacing()
    moveSec:Toggle("click_tp", "Click to Move", false)
    clickKeybind = moveSec:Keybind("click_keybind", 0x04, "click")
    moveSec:Toggle("flashback_tp", "Undo Move", false)
    undoKeybind = moveSec:Keybind("flashback_keybind", 0x46, "click")
    moveSec:Spacing()
    moveSec:Toggle("plat_enabled", "Anti-Fall Floor", false)
    moveSec:Toggle("tp_notifications", "Show Move Text", false)

    local modSec = tab:Section("Flight & Body", "Left")
    modSec:Toggle("fly_enabled", "Fly", false)
    flyKeybind = modSec:Keybind("fly_keybind", 0x58, "toggle")
    flyKeybind:AddToHotkey("Fly", "fly_enabled")
    modSec:SliderInt("fly_speed", "Fly Speed", 10, 300, 50)
    modSec:Spacing()
    modSec:Toggle("boost_speed", "Fast Walk", false)
    modSec:SliderInt("speed_val", "Walk Speed", 16, 300, 50)
    modSec:Toggle("boost_jump", "High Jump", false)
    modSec:SliderInt("jump_val", "Jump Power", 50, 500, 100)
    modSec:Toggle("moon_jump", "Moon Jump (Hold Space)", false)
    modSec:Spacing()
    modSec:Toggle("boost_noclip", "Walk Through Walls", false)
    modSec:Toggle("vanish", "Invisible Body", false)

    local funSec = tab:Section("Extras", "Left")
    funSec:Toggle("xhair_enabled", "Crosshair", false)
    funSec:Combo("xhair_style", "Style", {"Dot", "Cross"}, 0)
    funSec:SliderInt("xhair_size", "Size", 2, 12, 5)
    funSec:Spacing()
    funSec:Toggle("clicker_enabled", "Auto Clicker", false)
    funSec:SliderInt("clicker_cps", "Clicks per Second", 1, 30, 10)
    funSec:Spacing()
    funSec:Toggle("afk_enabled", "Anti-AFK", false)
    funSec:SliderInt("afk_interval", "AFK Timeout (s)", 10, 300, 60)
    funSec:Spacing()
    funSec:Toggle("mod_fov", "View Size", false)
    funSec:SliderInt("fov_val", "FOV", 10, 120, 70)
    funSec:Toggle("mod_spin", "Spin Body", false)
    funSec:SliderInt("spin_val", "Spin Speed", 1, 100, 20)

    local pathSec = tab:Section("Path", "Right")
    pathSec:Toggle("seq_enabled", "Start Path", false)
    pathKeybind = pathSec:Keybind("seq_keybind", 0x59, "toggle")
    pathKeybind:AddToHotkey("Path Move", "seq_enabled")
    pathSec:Combo("seq_mode", "End Rule", {"Stop", "Loop", "Go Back"}, 1)
    pathSec:Spacing()
    pathSec:Button("Start Over", function() sequenceIndex = 1; sequenceDirection = 1 end)
    pathSec:Button("Turn Around", function()
        local rev = {}
        for i = #waypoints, 1, -1 do table.insert(rev, waypoints[i]) end
        waypoints = rev
        sequenceIndex = 1
        refreshWpCombo()
    end)
    pathSec:Button("Skip Waypoint", function()
        if #waypoints > 0 then
            sequenceIndex = sequenceIndex + 1
            if sequenceIndex > #waypoints then sequenceIndex = 1 end
        end
    end)
    pathSec:Spacing()
    pathSec:SliderInt("wp_wait", "New Spot Wait (s)", 0, 3600, 0)
    pathSec:Button("Add Spot Here", function()
        local p = getCurrentPos()
        table.insert(waypoints, {x=string.format("%.2f",p.X), y=string.format("%.2f",p.Y), z=string.format("%.2f",p.Z), w=UI.GetValue("wp_wait") or 0, h=0})
        refreshWpCombo()
    end)
    pathSec:Button("Delete Last Spot", function()
        if #waypoints > 0 then table.remove(waypoints) end
        if sequenceIndex > #waypoints then sequenceIndex = math.max(1, #waypoints) end
        refreshWpCombo()
    end)
    pathSec:Button("Clear All Spots", function() waypoints = {}; sequenceIndex = 1; refreshWpCombo() end)
    pathSec:Spacing()
    pathSec:Toggle("rec_enabled", "Record My Steps", false)
    pathSec:SliderInt("rec_dist", "Step Size", 5, 100, 15)
    pathSec:Spacing()
    pathSec:Toggle("show_visualizer", "Show Spots", true)
    pathSec:Toggle("show_lines", "Draw Lines", true)
    pathSec:Toggle("rainbow_wp", "Rainbow Colors", false)
    pathSec:ColorPicker("wp_cp", wpColor.R, wpColor.G, wpColor.B, 1, function(c, a) wpColor = c end)

    local wpSec = tab:Section("Waypoint Timing", "Right")
    wpSec:InputText("wp_select_num", "Waypoint Number", "1")
    wpSec:Button("Set Wait on Selected", function()
        local idx = getSelectedWpIndex()
        if idx and waypoints[idx] then
            waypoints[idx].w = UI.GetValue("wp_wait") or 0
            notify("Wait set on spot " .. idx, "Path", 1)
        else
            notify("Pick a waypoint first!", "Path", 1)
        end
    end)
    wpSec:Spacing()
    wpSec:Combo("hold_units", "Hold Units", {"Seconds", "Minutes"}, 0)
    wpSec:SliderInt("hold_dur", "Hold Duration", 1, 3600, 10)
    wpSec:Button("Set Hold on Selected", function()
        local idx = getSelectedWpIndex()
        if idx and waypoints[idx] then
            local dur = UI.GetValue("hold_dur") or 10
            if UI.GetValue("hold_units") == 1 then dur = dur * 60 end
            waypoints[idx].h = dur
            notify("Hold set on spot " .. idx, "Path", 1)
        else
            notify("Pick a waypoint first!", "Path", 1)
        end
    end)
    wpSec:Spacing()
    wpSec:Toggle("hold_enabled", "Hold Key Active", false)
    holdKeybind = wpSec:Keybind("hold_keybind", 0x4C, "click")
    wpSec:Combo("hold_mode", "Hold Mode", {"Timed", "While Held"}, 0)
    wpSec:Spacing()
    wpSec:Button("Go to Selected", function()
        local idx = getSelectedWpIndex()
        if idx and waypoints[idx] then
            local wp = waypoints[idx]
            teleportTo(Vector3.new(tonumber(wp.x) or 0, tonumber(wp.y) or 0, tonumber(wp.z) or 0), false)
        end
    end)
    wpSec:Button("Random Waypoint", function()
        if #waypoints > 0 then
            local wp = waypoints[math.random(#waypoints)]
            teleportTo(Vector3.new(tonumber(wp.x) or 0, tonumber(wp.y) or 0, tonumber(wp.z) or 0), false)
        end
    end)

    local plrSec = tab:Section("Players & ESP", "Right")
    plrSec:Toggle("esp_enabled", "ESP", false)
    espKeybind = plrSec:Keybind("esp_keybind", 0x50, "toggle")
    espKeybind:AddToHotkey("ESP", "esp_enabled")
    plrSec:Toggle("esp_boxes", "Boxes", true)
    plrSec:Toggle("esp_names", "Names", true)
    plrSec:Toggle("esp_health", "Health Bar", true)
    plrSec:Toggle("esp_tracers", "Tracers", false)
    plrSec:Toggle("esp_distance", "Distance", false)
    plrSec:ColorPicker("esp_cp", 255, 80, 80, 1, function(c, a) espColor = c end)
    plrSec:Spacing()
    plrSec:Toggle("stalk_enabled", "Follow Player", false)
    followKeybind = plrSec:Keybind("stalk_keybind", 0x48, "toggle")
    followKeybind:AddToHotkey("Follow", "stalk_enabled")
    pCombo = plrSec:Combo("player_list", "Pick Who", {"None"}, 0)
    plrSec:Button("Load Players", function()
        pCombo:Clear()
        pCombo:Add("None")
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then pCombo:Add(p.Name) end
        end
    end)
    plrSec:Button("Go to Them Now", function()
        local tName = pCombo:GetText()
        if tName and tName ~= "None" then
            local tP = Players:FindFirstChild(tName)
            local tRoot = tP and getRoot(tP.Character)
            if tRoot then teleportTo(tRoot.Position, false) end
        end
    end)
    plrSec:Button("Nearest Player", function()
        local best, bd = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local r = getRoot(p.Character)
                if r then
                    local d = getDistance(getCurrentPos(), r.Position)
                    if d < bd then bd = d; best = p end
                end
            end
        end
        if best then
            local tRoot = getRoot(best.Character)
            if tRoot then teleportTo(tRoot.Position, false) end
        end
    end)
    plrSec:Button("Random Player", function()
        local cands = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then cands[#cands + 1] = p end
        end
        if #cands > 0 then
            local p = cands[math.random(#cands)]
            local tRoot = getRoot(p.Character)
            if tRoot then teleportTo(tRoot.Position, false) end
        end
    end)
    plrSec:SliderInt("off_x", "Side Distance", -50, 50, 0)
    plrSec:SliderInt("off_y", "Up Distance", -50, 50, 5)
    plrSec:SliderInt("off_z", "Front Distance", -50, 50, 5)

    local dataSec = tab:Section("Save / Load", "Right")
    dataSec:Button("Copy My Save", function() saveConfig() end)
    dataSec:InputText("import_box", "Paste Save Here", "")
    dataSec:Button("Load My Save", function() loadConfig(UI.GetValue("import_box")) end)
    dataSec:Spacing()
    dataSec:Button("Save Path to File", function()
        local ok, json = pcall(function() return HttpService:JSONEncode(waypoints) end)
        if ok then
            local wok = pcall(function() writefile("matcha_waypoints.json", json) end)
            if wok then notify("Path saved to file!", "Save", 1) else notify("Write failed!", "Save", 1) end
        end
    end)
    dataSec:Button("Load Path from File", function()
        if not isfile("matcha_waypoints.json") then notify("No file found!", "Save", 1) return end
        local ok, data = pcall(function() return readfile("matcha_waypoints.json") end)
        if ok then
            local dok, decoded = pcall(function() return HttpService:JSONDecode(data) end)
            if dok and type(decoded) == "table" then
                waypoints = decoded
                sequenceIndex = 1
                refreshWpCombo()
                notify("Path loaded from file!", "Save", 1)
            end
        end
    end)
end)

task.spawn(function()
    while true do
        task.wait(0.05)
        local cd = clickKeybind and clickKeybind:IsEnabled()
        if UI.GetValue("click_tp") and cd and not clickTpPrev then
            doClickTeleport()
        end
        clickTpPrev = cd

        local ud = undoKeybind and undoKeybind:IsEnabled()
        if UI.GetValue("flashback_tp") and ud and not undoPrev then
            doFlashback()
        end
        undoPrev = ud

        local hd = holdKeybind and holdKeybind:IsEnabled()
        if UI.GetValue("hold_enabled") and hd and not holdPrev and not activeHold then
            local point, isWp = getHoldPoint()
            if point then
                if isWp and getDistance(getCurrentPos(), point) > 2 then
                    teleportTo(point, false)
                end
                if UI.GetValue("hold_mode") == 0 then
                    local dur = UI.GetValue("hold_dur") or 10
                    if UI.GetValue("hold_units") == 1 then dur = dur * 60 end
                    holdAtPoint(point, dur, nil)
                else
                    holdAtPoint(point, nil, function()
                        return not (UI.GetValue("hold_enabled") and holdKeybind and holdKeybind:IsEnabled())
                    end)
                end
            end
        end
        holdPrev = hd
    end
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        if UI.GetValue("rec_enabled") then
            local pos = getCurrentPos()
            local threshold = UI.GetValue("rec_dist") or 15
            if not lastRecordedPos or getDistance(lastRecordedPos, pos) >= threshold then
                table.insert(waypoints, {x=string.format("%.2f",pos.X), y=string.format("%.2f",pos.Y), z=string.format("%.2f",pos.Z), w=0, h=0})
                lastRecordedPos = pos
            end
        else
            lastRecordedPos = nil
        end
    end
end)

task.spawn(function()
    while true do
        task.wait()
        if UI.GetValue("plat_enabled") then
            local root = getRoot(LocalPlayer.Character)
            if root then
                local p = root.Position
                if hoverY == nil then hoverY = p.Y end
                if p.Y < hoverY then
                    root.CFrame = CFrame.new(p.X, hoverY, p.Z)
                end
                local v = root.Velocity
                if v and v.Y < 0 then
                    pcall(function() root.Velocity = Vector3.new(v.X, 0, v.Z) end)
                end
            end
        else
            hoverY = nil
        end
    end
end)

task.spawn(function()
    while true do
        task.wait()
        local root = getRoot(LocalPlayer.Character)
        if root then
            if UI.GetValue("boost_speed") then
                local v = root.Velocity
                if v and (v.X ~= 0 or v.Z ~= 0) then
                    local mult = (UI.GetValue("speed_val") or 50) / 16
                    pcall(function() root.Velocity = Vector3.new(v.X * mult, v.Y, v.Z * mult) end)
                end
            end
            if UI.GetValue("boost_jump") then
                local v = root.Velocity
                if v and v.Y > 0.1 then
                    local mult = (UI.GetValue("jump_val") or 100) / 50
                    pcall(function() root.Velocity = Vector3.new(v.X, v.Y * mult, v.Z) end)
                end
            end
            if UI.GetValue("mod_spin") then
                local speed = UI.GetValue("spin_val") or 20
                root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(speed), 0)
            end
        end
        if UI.GetValue("mod_fov") then
            local cam = Workspace.CurrentCamera
            if cam then cam.FieldOfView = UI.GetValue("fov_val") or 70 end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.25)
        if UI.GetValue("boost_noclip") then
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p.CanCollide then
                        pcall(function() p.CanCollide = false end)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.3)
        local char = LocalPlayer.Character
        if char then
            local set = UI.GetValue("vanish") and 1 or 0
            for _, p in ipairs(char:GetDescendants()) do
                pcall(function()
                    if p.ClassName == "MeshPart" or p.ClassName == "Part" then
                        if p.Transparency ~= set then p.Transparency = set end
                    end
                end)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait()
        if UI.GetValue("fly_enabled") then
            local root = getRoot(LocalPlayer.Character)
            local cam = Workspace.CurrentCamera
            if root and cam then
                local speed = UI.GetValue("fly_speed") or 50
                local cf = cam.CFrame
                local f = Vector3.new(0, 0, 0)
                if keyDown(87) then f = f + cf.LookVector end
                if keyDown(83) then f = f - cf.LookVector end
                if keyDown(65) then f = f - cf.RightVector end
                if keyDown(68) then f = f + cf.RightVector end
                local dir = Vector3.new(f.X, 0, f.Z).Unit
                local vy = 0
                if keyDown(32) then vy = vy + 1 end
                if keyDown(16) then vy = vy - 1 end
                pcall(function() root.Velocity = dir * speed + Vector3.new(0, vy * speed, 0) end)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1 / (UI.GetValue("clicker_cps") or 10))
        if UI.GetValue("clicker_enabled") then
            mouse1click()
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(UI.GetValue("afk_interval") or 60)
        if UI.GetValue("afk_enabled") then
            local root = getRoot(LocalPlayer.Character)
            if root then
                pcall(function() root.CFrame = root.CFrame * CFrame.new(0, 0, 1) end)
                task.wait(0.1)
                pcall(function() root.CFrame = root.CFrame * CFrame.new(0, 0, -1) end)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait()
        if UI.GetValue("moon_jump") then
            local root = getRoot(LocalPlayer.Character)
            if root and keyDown(32) then
                local v = root.Velocity
                if v and v.Y <= 1 then
                    pcall(function() root.Velocity = Vector3.new(v.X, (UI.GetValue("jump_val") or 100) * 1.5, v.Z) end)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.4)
        local out = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                local head = char and char:FindFirstChild("Head")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if head and root and hum then
                    out[#out + 1] = { name = plr.Name, head = head, root = root, hum = hum }
                end
            end
        end
        espTargets = out
    end
end)

RunService.RenderStepped:Connect(function()
    local showWp = UI.GetValue("show_visualizer")
    local showLines = UI.GetValue("show_lines")
    local activeWpColor = wpColor
    if UI.GetValue("rainbow_wp") then
        activeWpColor = Color3.fromHSV((tick() % 5) / 5, 1, 1)
    end

    local n = #waypoints
    for i = #waypointDrawings + 1, n do
        local d = Drawing.new("Text")
        d.Center = true
        d.Size = 16
        d.Outline = true
        waypointDrawings[i] = d
    end
    for i = #waypointLines + 1, math.max(0, n - 1) do
        local l = Drawing.new("Line")
        l.Thickness = 1.5
        waypointLines[i] = l
    end

    for i = 1, #waypointDrawings do
        local d = waypointDrawings[i]
        local wp = waypoints[i]
        if showWp and wp then
            local p3 = Vector3.new(tonumber(wp.x) or 0, tonumber(wp.y) or 0, tonumber(wp.z) or 0)
            local p2, vis = WorldToScreen(p3)
            if vis then
                d.Position = p2
                local ww = tonumber(wp.w) or 0
                if ww > 0 then
                    d.Text = tostring(i) .. " " .. string.format("%.1fs", ww)
                else
                    d.Text = tostring(i)
                end
                d.Color = activeWpColor
                d.Visible = true
            else
                d.Visible = false
            end
        else
            d.Visible = false
        end
    end

    for i = 1, #waypointLines do
        local l = waypointLines[i]
        local wp1 = waypoints[i]
        local wp2 = waypoints[i + 1]
        if showWp and showLines and wp1 and wp2 then
            local p1 = Vector3.new(tonumber(wp1.x) or 0, tonumber(wp1.y) or 0, tonumber(wp1.z) or 0)
            local p2 = Vector3.new(tonumber(wp2.x) or 0, tonumber(wp2.y) or 0, tonumber(wp2.z) or 0)
            local s1, v1 = WorldToScreen(p1)
            local s2, v2 = WorldToScreen(p2)
            if v1 and v2 then
                l.From = s1
                l.To = s2
                l.Color = activeWpColor
                l.Visible = true
            else
                l.Visible = false
            end
        else
            l.Visible = false
        end
    end

    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(960, 600)
    local camPos = cam and cam.Position or Vector3.new()
    local cx = vp.X / 2
    local cy = vp.Y / 2

    if UI.GetValue("xhair_enabled") then
        local style = UI.GetValue("xhair_style") or 0
        local s = UI.GetValue("xhair_size") or 5
        if style == 0 then
            xhDot.Position = Vector2.new(cx, cy)
            xhDot.Radius = s
            xhDot.Visible = true
        else
            local g = s * 2
            xhH.From = Vector2.new(cx - g, cy)
            xhH.To = Vector2.new(cx + g, cy)
            xhV.From = Vector2.new(cx, cy - g)
            xhV.To = Vector2.new(cx, cy + g)
            xhH.Visible = true
            xhV.Visible = true
        end
    else
        xhDot.Visible = false
        xhH.Visible = false
        xhV.Visible = false
    end

    local espOn = UI.GetValue("esp_enabled")
    local showBox = UI.GetValue("esp_boxes")
    local showName = UI.GetValue("esp_names")
    local showHP = UI.GetValue("esp_health")
    local showTrace = UI.GetValue("esp_tracers")
    local showDist = UI.GetValue("esp_distance")
    local list = espTargets
    local used = 0
    if espOn then
        for i = 1, #list do
            if used >= espPoolSize then break end
            local t = list[i]
            local top, v1 = WorldToScreen(t.head.Position + Vector3.new(0, 0.6, 0))
            local bot, v2 = WorldToScreen(t.root.Position - Vector3.new(0, 3, 0))
            if v1 and v2 then
                used = used + 1
                local e = espDrawings[used]
                local h = bot.Y - top.Y
                local w = h * 0.45
                if showBox then
                    e.box.Position = Vector2.new(top.X - w * 0.5, top.Y)
                    e.box.Size = Vector2.new(w, h)
                    e.box.Color = espColor
                    e.box.Visible = true
                else
                    e.box.Visible = false
                end
                if showName then
                    local txt = t.name
                    if showDist then
                        txt = txt .. " " .. string.format("%.0f", (t.root.Position - camPos).Magnitude) .. "m"
                    end
                    e.name.Text = txt
                    e.name.Position = Vector2.new(top.X, top.Y - 14)
                    e.name.Color = espColor
                    e.name.Visible = true
                else
                    e.name.Visible = false
                end
                if showHP then
                    local ratio = math.clamp(t.hum.Health / math.max(1, t.hum.MaxHealth), 0, 1)
                    local bx = top.X + w * 0.5 + 2
                    e.hpBG.Position = Vector2.new(bx, top.Y)
                    e.hpBG.Size = Vector2.new(3, h)
                    e.hpBG.Color = Color3.fromRGB(30, 30, 30)
                    e.hpBG.Visible = true
                    local fh = math.max(1, h * ratio)
                    e.hpFill.Position = Vector2.new(bx, top.Y + (h - fh))
                    e.hpFill.Size = Vector2.new(3, fh)
                    e.hpFill.Color = Color3.fromRGB(math.floor(255 * (1 - ratio)), math.floor(255 * ratio), 0)
                    e.hpFill.Visible = true
                else
                    e.hpBG.Visible = false
                    e.hpFill.Visible = false
                end
                if showTrace then
                    e.line.From = Vector2.new(cx, vp.Y)
                    e.line.To = bot
                    e.line.Color = espColor
                    e.line.Visible = true
                else
                    e.line.Visible = false
                end
            end
        end
    end
    for i = used + 1, espPoolSize do
        local e = espDrawings[i]
        e.box.Visible = false
        e.name.Visible = false
        e.hpBG.Visible = false
        e.hpFill.Visible = false
        e.line.Visible = false
    end
end)

task.spawn(function()
    while true do
        task.wait()
        local seqOn = UI.GetValue("seq_enabled")
        local stalkOn = UI.GetValue("stalk_enabled")
        local tpOn = UI.GetValue("tp_enabled")

        if seqOn and #waypoints > 0 then
            local sequencePoints = {}
            for i = 1, #waypoints do
                sequencePoints[i] = Vector3.new(tonumber(waypoints[i].x) or 0, tonumber(waypoints[i].y) or 0, tonumber(waypoints[i].z) or 0)
            end
            if sequenceIndex > #sequencePoints or sequenceIndex < 1 then sequenceIndex = 1; sequenceDirection = 1 end
            local target = sequencePoints[sequenceIndex]
            if target then
                local pMode = UI.GetValue("seq_mode") or 1
                local function advanceSeq()
                    if pMode == 0 then
                        if sequenceIndex < #sequencePoints then sequenceIndex = sequenceIndex + 1 else UI.SetValue("seq_enabled", false) end
                    elseif pMode == 1 then
                        sequenceIndex = sequenceIndex + 1
                        if sequenceIndex > #sequencePoints then sequenceIndex = 1 end
                    elseif pMode == 2 then
                        sequenceIndex = sequenceIndex + sequenceDirection
                        if sequenceIndex >= #sequencePoints then
                            sequenceIndex = #sequencePoints; sequenceDirection = -1
                        elseif sequenceIndex <= 1 then
                            sequenceIndex = 1; sequenceDirection = 1
                        end
                    end
                end
                local dwell = tonumber(waypoints[sequenceIndex].w) or 0
                if getDistance(getCurrentPos(), target) <= 5 then
                    if dwell > 0 then task.wait(dwell) end
                    advanceSeq()
                else
                    local completed = teleportTo(target, false, true)
                    if completed then
                        task.wait(UI.GetValue("tp_delay") or 1.0)
                        if dwell > 0 then task.wait(dwell) end
                        advanceSeq()
                    end
                end
            end
        elseif stalkOn then
            local targetName = "None"
            pcall(function() if pCombo then targetName = pCombo:GetText() or "None" end end)
            if targetName ~= "None" then
                local targetPlayer = Players:FindFirstChild(targetName)
                local targetRoot = targetPlayer and getRoot(targetPlayer.Character)
                if targetRoot then
                    local cf = targetRoot.CFrame
                    if typeof(cf) == "CFrame" then
                        local ox = UI.GetValue("off_x") or 0
                        local oy = UI.GetValue("off_y") or 5
                        local oz = UI.GetValue("off_z") or 5
                        teleportTo((cf * CFrame.new(ox, oy, oz)).Position, true, true)
                        task.wait(UI.GetValue("tp_delay") or 0.1)
                    end
                end
            end
        elseif tpOn then
            local x = tonumber(UI.GetValue("tp_x")) or -1095.28
            local y = tonumber(UI.GetValue("tp_y")) or 60.4
            local z = tonumber(UI.GetValue("tp_z")) or -6.16
            local completed = teleportTo(Vector3.new(x, y, z), false, true)
            if completed then task.wait(UI.GetValue("tp_delay") or 1.0) end
        end
    end
end)
