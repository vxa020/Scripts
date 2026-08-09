local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local singleKeybind = nil
local seqKeybind = nil
local clickKeybind = nil
local stalkKeybind = nil
local flashbackKeybind = nil
local pCombo = nil

local waypoints = {{x="-1095.28", y="60.4", z="-6.16"}}
local sequenceIndex = 1
local sequenceDirection = 1

local waypointDrawings = {}
local waypointLines = {}

local wpColor = Color3.fromRGB(0, 255, 0)
local hoverY = nil

local lastTeleportPos = nil
local lastRecordedPos = nil

local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function getCurrentPos()
    local root = getRoot(LocalPlayer.Character)
    if root then return root.Position end
    return Vector3.new(0, 0, 0)
end

local function getDistance(v1, v2)
    return (v1 - v2).Magnitude
end

local function stepTowards(current, target, step)
    local diff = target - current
    local dist = diff.Magnitude
    if dist <= step or dist == 0 then return target end
    return current + (diff.Unit * step)
end

local function executeTeleportLogic(primaryPart, targetPos, mode, stepDist, reqConditionFn)
    if mode == 0 then
        primaryPart.CFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z)
        pcall(function() primaryPart.Velocity = Vector3.new(0, 0, 0) end)
        if UI.GetValue("tp_notifications") then notify("Moved!", "App", 1) end
        return true
    else
        local currentPos = primaryPart.Position
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

local function teleportTo(targetPos, isStalk)
    local primaryPart = getRoot(LocalPlayer.Character)
    if not primaryPart then return false end
    if not isStalk then lastTeleportPos = primaryPart.Position end
    local mode = UI.GetValue("tp_mode") or 0
    local stepDist = UI.GetValue("tp_step_dist") or 20
    return executeTeleportLogic(primaryPart, targetPos, mode, stepDist, function()
        local isTpActive = UI.GetValue("tp_enabled") and (singleKeybind and singleKeybind:IsEnabled())
        local isSeqActive = UI.GetValue("seq_enabled") and (seqKeybind and seqKeybind:IsEnabled())
        local isStalkActive = UI.GetValue("stalk_enabled") and (stalkKeybind and stalkKeybind:IsEnabled())
        return isTpActive or isSeqActive or isStalkActive or (clickKeybind and clickKeybind:IsEnabled()) or (flashbackKeybind and flashbackKeybind:IsEnabled())
    end)
end

local function doFlashback()
    if lastTeleportPos then
        local primaryPart = getRoot(LocalPlayer.Character)
        if primaryPart then
            primaryPart.CFrame = CFrame.new(lastTeleportPos)
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
        notify("Loaded safe!", "App", 2)
    end
end

UI.AddTab("Move", function(tab)
    local tpSec = tab:Section("Basic Move", "Left")
    tpSec:Toggle("tp_enabled", "Loop Move", false)
    singleKeybind = tpSec:Keybind("tp_keybind", 0x54, "toggle")
    singleKeybind:AddToHotkey("Loop Move", "tp_enabled")

    tpSec:Spacing()
    tpSec:Button("Get My Spot", function()
        local pos = getCurrentPos()
        UI.SetValue("tp_x", string.format("%.2f", pos.X))
        UI.SetValue("tp_y", string.format("%.2f", pos.Y))
        UI.SetValue("tp_z", string.format("%.2f", pos.Z))
    end)

    tpSec:InputText("tp_x", "X Spot", "-1095.28")
    tpSec:InputText("tp_y", "Y Spot", "60.4")
    tpSec:InputText("tp_z", "Z Spot", "-6.16")

    tpSec:Spacing()
    tpSec:Toggle("click_tp", "Click to Move", false)
    clickKeybind = tpSec:Keybind("click_keybind", 0x04, "click")
    clickKeybind:AddToHotkey("Click Move", "click_tp")

    tpSec:Toggle("flashback_tp", "Undo Move", false)
    flashbackKeybind = tpSec:Keybind("flashback_keybind", 0x46, "click")
    flashbackKeybind:AddToHotkey("Undo", "flashback_tp")

    tpSec:Spacing()
    tpSec:SliderFloat("tp_delay", "Wait Time", 0.0, 10.0, 1.0, "%.2fs")
    tpSec:Combo("tp_mode", "Move Type", {"Fast", "Safe Mode"}, 0)
    tpSec:SliderInt("tp_step_dist", "Safe Mode Speed", 5, 100, 20)
    tpSec:Toggle("tp_notifications", "Show Move Text", false)

    local fallSec = tab:Section("Anti-Fall", "Right")
    fallSec:Toggle("plat_enabled", "Invisible Floor", false)
    fallSec:Tip("Matcha can't spawn parts, so this pins your height when you enable it.")
end)

UI.AddTab("Path", function(tab)
    local seqSec = tab:Section("Follow Path", "Left")
    seqSec:Toggle("seq_enabled", "Start Path", false)
    seqKeybind = seqSec:Keybind("seq_keybind", 0x59, "toggle")
    seqKeybind:AddToHotkey("Path Move", "seq_enabled")
    seqSec:Combo("seq_mode", "End Rule", {"Stop", "Loop", "Go Back"}, 1)
    seqSec:Spacing()
    seqSec:Button("Start Over", function() sequenceIndex = 1; sequenceDirection = 1 end)
    seqSec:Button("Turn Around", function()
        local rev = {}
        for i = #waypoints, 1, -1 do table.insert(rev, waypoints[i]) end
        waypoints = rev
        sequenceIndex = 1
    end)

    local recSec = tab:Section("Make Path", "Right")
    recSec:Toggle("rec_enabled", "Save My Steps", false)
    recSec:SliderInt("rec_dist", "Step Size", 5, 100, 15)
    recSec:Spacing()
    recSec:Button("Add Spot Here", function()
        local p = getCurrentPos()
        table.insert(waypoints, {x=string.format("%.2f",p.X), y=string.format("%.2f",p.Y), z=string.format("%.2f",p.Z)})
    end)
    recSec:Button("Delete Last Spot", function() if #waypoints > 0 then table.remove(waypoints) end end)
    recSec:Button("Clear All Spots", function() waypoints = {}; sequenceIndex = 1 end)
    recSec:Spacing()
    recSec:Toggle("show_visualizer", "Show Spots on Screen", true)
    recSec:Toggle("show_lines", "Draw Lines", true)
    recSec:Toggle("rainbow_wp", "Rainbow Colors", false)
    recSec:ColorPicker("wp_cp", wpColor.R, wpColor.G, wpColor.B, 1, function(c, a) wpColor = c end)
end)

UI.AddTab("Follow", function(tab)
    local stalkSec = tab:Section("Follow Player", "Left")
    pCombo = stalkSec:Combo("player_list", "Pick Who", {"None"}, 0)
    stalkSec:Button("Load Players", function()
        pCombo:Clear()
        pCombo:Add("None")
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then pCombo:Add(p.Name) end
        end
    end)
    stalkSec:Toggle("stalk_enabled", "Keep Following", false)
    stalkKeybind = stalkSec:Keybind("stalk_keybind", 0x48, "toggle")
    stalkKeybind:AddToHotkey("Follow", "stalk_enabled")
    stalkSec:Button("Go to Them Now", function()
        local tName = pCombo:GetText()
        if tName and tName ~= "None" then
            local tP = Players:FindFirstChild(tName)
            local tRoot = tP and getRoot(tP.Character)
            if tRoot then
                teleportTo(tRoot.Position, false)
            end
        end
    end)

    local offSec = tab:Section("Distance", "Right")
    offSec:SliderInt("off_x", "Side Distance", -50, 50, 0)
    offSec:SliderInt("off_y", "Up Distance", -50, 50, 5)
    offSec:SliderInt("off_z", "Front Distance", -50, 50, 5)

    local cfgSec = tab:Section("Save Data", "Left")
    cfgSec:Button("Copy My Save", function() saveConfig() end)
    cfgSec:InputText("import_box", "Paste Save Here", "")
    cfgSec:Button("Load My Save", function() loadConfig(UI.GetValue("import_box")) end)
end)

UI.AddTab("Boost", function(tab)
    local bSec = tab:Section("Body Mods", "Left")
    bSec:Toggle("boost_speed", "Fast Walk", false)
    bSec:SliderInt("speed_val", "Walk Speed", 16, 300, 50)
    bSec:Toggle("boost_jump", "High Jump", false)
    bSec:SliderInt("jump_val", "Jump Power", 50, 500, 100)
    bSec:Toggle("boost_noclip", "Walk Through Walls", false)

    local camSec = tab:Section("Fun Mods", "Right")
    camSec:Toggle("mod_fov", "Change View Size", false)
    camSec:SliderInt("fov_val", "View Size", 10, 120, 70)
    camSec:Toggle("mod_spin", "Spin Body", false)
    camSec:SliderInt("spin_val", "Spin Speed", 1, 100, 20)
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if UI.GetValue("click_tp") and clickKeybind and clickKeybind:IsEnabled() then
            doClickTeleport()
        end
        if UI.GetValue("flashback_tp") and flashbackKeybind and flashbackKeybind:IsEnabled() then
            doFlashback()
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        if UI.GetValue("rec_enabled") then
            local pos = getCurrentPos()
            local threshold = UI.GetValue("rec_dist") or 15
            if not lastRecordedPos or getDistance(lastRecordedPos, pos) >= threshold then
                table.insert(waypoints, {x=string.format("%.2f",pos.X), y=string.format("%.2f",pos.Y), z=string.format("%.2f",pos.Z)})
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
            if cam then
                cam.FieldOfView = UI.GetValue("fov_val") or 70
            end
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
                d.Text = tostring(i)
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
end)

task.spawn(function()
    while true do
        task.wait()
        local isSeqActive = UI.GetValue("seq_enabled") and (seqKeybind and seqKeybind:IsEnabled())
        local isTpActive = UI.GetValue("tp_enabled") and (singleKeybind and singleKeybind:IsEnabled())
        local isStalkActive = UI.GetValue("stalk_enabled") and (stalkKeybind and stalkKeybind:IsEnabled())

        if isSeqActive and #waypoints > 0 then
            local sequencePoints = {}
            for i = 1, #waypoints do
                table.insert(sequencePoints, Vector3.new(tonumber(waypoints[i].x) or 0, tonumber(waypoints[i].y) or 0, tonumber(waypoints[i].z) or 0))
            end
            if sequenceIndex > #sequencePoints or sequenceIndex < 1 then sequenceIndex = 1; sequenceDirection = 1 end
            local target = sequencePoints[sequenceIndex]
            if target then
                local pMode = UI.GetValue("seq_mode") or 1
                if getDistance(getCurrentPos(), target) <= 5 then
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
                else
                    local completed = teleportTo(target, false)
                    if completed then
                        task.wait(UI.GetValue("tp_delay") or 1.0)
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
                end
            end
        elseif isStalkActive then
            local targetName = "None"
            pcall(function() if pCombo then targetName = pCombo:GetText() or "None" end end)
            if targetName ~= "None" then
                local targetPlayer = Players:FindFirstChild(targetName)
                local targetRoot = targetPlayer and getRoot(targetPlayer.Character)
                if targetRoot then
                    local ox = UI.GetValue("off_x") or 0
                    local oy = UI.GetValue("off_y") or 5
                    local oz = UI.GetValue("off_z") or 5
                    teleportTo((targetRoot.CFrame * CFrame.new(ox, oy, oz)).Position, true)
                    task.wait(UI.GetValue("tp_delay") or 0.1)
                end
            end
        elseif isTpActive then
            local x = tonumber(UI.GetValue("tp_x")) or -1095.28
            local y = tonumber(UI.GetValue("tp_y")) or 60.4
            local z = tonumber(UI.GetValue("tp_z")) or -6.16
            local completed = teleportTo(Vector3.new(x, y, z), false)
            if completed then task.wait(UI.GetValue("tp_delay") or 1.0) end
        end
    end
end)
