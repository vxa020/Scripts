local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
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
local platColor = Color3.fromRGB(153, 51, 255)
local stalkOffset = Vector3.new(0, 5, 5)

local platformPart = nil
local platformWalls = {}
local currentPlatformY = nil

local lastTeleportPos = nil
local lastRecordedPos = nil

local function getCurrentPos()
local char = LocalPlayer.Character
if char and char.PrimaryPart then
return char.PrimaryPart.Position
end
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
if UI.GetValue("tp_notifications") then notify("Moved!", "App", 1) end
return true
end
end

local function teleportTo(targetPos, isStalk)
local char = LocalPlayer.Character
if not char then return false end
local primaryPart = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
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
local char = LocalPlayer.Character
local primaryPart = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
if primaryPart then
primaryPart.CFrame = CFrame.new(lastTeleportPos)
notify("Went back", "Undo", 1)
end
else
notify("No spot saved!", "Undo", 1)
end
end

local function doClickTeleport()
pcall(function()
local mouse = LocalPlayer:GetMouse()
if mouse and mouse.Hit then
teleportTo(mouse.Hit.Position + Vector3.new(0, 3, 0), false)
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

local platSec = tab:Section("Floor Magic", "Right")
platSec:Toggle("plat_enabled", "Make Floor Under Me", false)
platSec:Toggle("plat_box", "Make Walls", false)
platSec:ColorPicker("plat_cp", platColor.R, platColor.G, platColor.B, 1, function(c, a) platColor = c end)
platSec:SliderInt("plat_size", "Floor Size", 5, 100, 15)

platSec:Spacing()
platSec:SliderFloat("tp_delay", "Wait Time", 0.0, 10.0, 1.0, "%.2fs")
platSec:Combo("tp_mode", "Move Type", {"Fast", "Safe Mode"}, 0)
platSec:SliderInt("tp_step_dist", "Safe Mode Speed", 5, 100, 20)
platSec:Toggle("tp_notifications", "Show Move Text", false)


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
waypoints = rev; sequenceIndex = 1
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
if tP and tP.Character and tP.Character.PrimaryPart then
teleportTo(tP.Character.PrimaryPart.Position, false)
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
task.wait()
local timeNow = tick()
local dynamicRainbow = Color3.fromHSV((timeNow % 5) / 5, 1, 1)
local activeWpColor = wpColor
if UI.GetValue("rainbow_wp") then activeWpColor = dynamicRainbow end

    local showWp = UI.GetValue("show_visualizer")
    local showLines = UI.GetValue("show_lines")
    
    local requiredDrawings = math.max(#waypoints, #waypointDrawings)
    for i = 1, requiredDrawings do
        if not waypointDrawings[i] then
            waypointDrawings[i] = Drawing.new("Text")
            waypointDrawings[i].Center = true
            waypointDrawings[i].Size = 16
            waypointDrawings[i].Outline = true
        end
        local textDrawing = waypointDrawings[i]
        if showWp and waypoints[i] then
            local pos3D = Vector3.new(tonumber(waypoints[i].x) or 0, tonumber(waypoints[i].y) or 0, tonumber(waypoints[i].z) or 0)
            local pos2D, onScreen = WorldToScreen(pos3D)
            if onScreen then
                textDrawing.Position = pos2D
                textDrawing.Text = tostring(i)
                textDrawing.Color = activeWpColor 
                textDrawing.Visible = true
            else
                textDrawing.Visible = false
            end
        else
            textDrawing.Visible = false
        end
    end
    
    local requiredLines = math.max(0, #waypoints - 1, #waypointLines)
    for i = 1, requiredLines do
        if not waypointLines[i] then
            waypointLines[i] = Drawing.new("Line")
            waypointLines[i].Thickness = 1.5
        end
        local line = waypointLines[i]
        if showWp and showLines and waypoints[i] and waypoints[i+1] then
            local p1 = Vector3.new(tonumber(waypoints[i].x) or 0, tonumber(waypoints[i].y) or 0, tonumber(waypoints[i].z) or 0)
            local p2 = Vector3.new(tonumber(waypoints[i+1].x) or 0, tonumber(waypoints[i+1].y) or 0, tonumber(waypoints[i+1].z) or 0)
            local s1, o1 = WorldToScreen(p1)
            local s2, o2 = WorldToScreen(p2)
            if o1 and o2 then
                line.From = s1
                line.To = s2
                line.Color = activeWpColor
                line.Visible = true
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
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
local function createWall()
local part = Instance.new("Part")
part.Name = "MagicWall"
part.Anchored = true
part.CanCollide = true
part.Transparency = 0.7
pcall(function() part.Material = Enum.Material.Glass end)
part.Parent = Workspace
return part
end
while true do
task.wait()
local char = LocalPlayer.Character
local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
if UI.GetValue("plat_enabled") and root then
if not platformPart or not platformPart.Parent then
pcall(function()
platformPart = Instance.new("Part")
platformPart.Name = "MagicFloor"
platformPart.Anchored = true
platformPart.CanCollide = true
platformPart.Transparency = 0.5
pcall(function() platformPart.Material = Enum.Material.Neon end)
platformPart.Parent = Workspace
end)
end
if UI.GetValue("plat_box") and #platformWalls == 0 then
for i = 1, 4 do table.insert(platformWalls, createWall()) end
elseif not UI.GetValue("plat_box") and #platformWalls > 0 then
for _, w in ipairs(platformWalls) do pcall(function() w:Destroy() end) end
platformWalls = {}
end
if platformPart then
local size = UI.GetValue("plat_size") or 15
platformPart.Size = Vector3.new(size, 3, size)
platformPart.Color = platColor
local hum = char:FindFirstChildOfClass("Humanoid")
local offset = 3.0
if hum and hum.RigType == Enum.HumanoidRigType.R15 then
offset = hum.HipHeight + (root.Size.Y / 2)
end
local expectedY = root.Position.Y - offset - (platformPart.Size.Y / 2)
if currentPlatformY == nil or math.abs(currentPlatformY - expectedY) > 6 then
currentPlatformY = expectedY
end
local platCFrame = CFrame.new(root.Position.X, currentPlatformY, root.Position.Z)
platformPart.CFrame = platCFrame
if UI.GetValue("plat_box") and #platformWalls == 4 then
local wallHeight = 15
local ws = size / 2
local wt = 2
platformWalls[1].Size = Vector3.new(size, wallHeight, wt)
platformWalls[1].CFrame = platCFrame * CFrame.new(0, wallHeight/2, ws)
platformWalls[1].Color = platColor
platformWalls[2].Size = Vector3.new(size, wallHeight, wt)
platformWalls[2].CFrame = platCFrame * CFrame.new(0, wallHeight/2, -ws)
platformWalls[2].Color = platColor
platformWalls[3].Size = Vector3.new(wt, wallHeight, size)
platformWalls[3].CFrame = platCFrame * CFrame.new(ws, wallHeight/2, 0)
platformWalls[3].Color = platColor
platformWalls[4].Size = Vector3.new(wt, wallHeight, size)
platformWalls[4].CFrame = platCFrame * CFrame.new(-ws, wallHeight/2, 0)
platformWalls[4].Color = platColor
end
pcall(function()
root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
end)
end
else
if platformPart then pcall(function() platformPart:Destroy() end) platformPart = nil end
if #platformWalls > 0 then
for _, w in ipairs(platformWalls) do pcall(function() w:Destroy() end) end
platformWalls = {}
end
currentPlatformY = nil
end
end
end)

task.spawn(function()
while true do
task.wait()
local char = LocalPlayer.Character
if char then
local hum = char:FindFirstChildOfClass("Humanoid")
if hum then
if UI.GetValue("boost_speed") then
hum.WalkSpeed = UI.GetValue("speed_val") or 50
end
if UI.GetValue("boost_jump") then
hum.UseJumpPower = true
hum.JumpPower = UI.GetValue("jump_val") or 100
end
end

        if UI.GetValue("boost_noclip") then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end
        
        if UI.GetValue("mod_spin") then
            local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
            if root then
                local speed = UI.GetValue("spin_val") or 20
                root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(speed), 0)
            end
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
            if getDistance(getCurrentPos(), target) <= 5 then
                local pMode = UI.GetValue("seq_mode") or 1
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
                    local pMode = UI.GetValue("seq_mode") or 1
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
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local targetHRP = targetPlayer.Character.HumanoidRootPart
                local ox = UI.GetValue("off_x") or 0
                local oy = UI.GetValue("off_y") or 5
                local oz = UI.GetValue("off_z") or 5
                teleportTo((targetHRP.CFrame * CFrame.new(ox, oy, oz)).Position, true)
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
