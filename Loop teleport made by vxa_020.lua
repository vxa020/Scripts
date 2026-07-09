
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local singleKeybind = nil
local seqKeybind = nil

local waypoints = {
{ x = "-1095.28", y = "60.4", z = "-6.16" }
}
local sequenceIndex = 1

local waypointDrawings = {}

local wpColor = Color3.fromRGB(0, 255, 0)
local platColor = Color3.fromRGB(153, 51, 255)

local platformPart = nil
local currentPlatformY = nil

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
if dist <= step or dist == 0 then
return target
end
return current + (diff.Unit * step)
end

local function teleportTo(targetPos)
local char = LocalPlayer.Character
if not char then return false end

local primaryPart = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
if not primaryPart then return false end

local mode = UI.GetValue("tp_mode") or 0

if mode == 0 then
    primaryPart.CFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z)
    if UI.GetValue("tp_notifications") then
        notify("Teleport finished!", "Matcha Teleporter", 1)
    end
    return true
    
else
    local stepDist = UI.GetValue("tp_step_dist") or 20
    local currentPos = primaryPart.Position
    
    while getDistance(currentPos, targetPos) > stepDist do
        local isTpActive = UI.GetValue("tp_enabled") and (singleKeybind and singleKeybind:IsEnabled())
        local isSeqActive = UI.GetValue("seq_enabled") and (seqKeybind and seqKeybind:IsEnabled())
        
        if not isTpActive and not isSeqActive then 
            return false 
        end
        
        currentPos = stepTowards(currentPos, targetPos, stepDist)
        primaryPart.CFrame = CFrame.new(currentPos.X, currentPos.Y, currentPos.Z)
        task.wait() 
    end
    
    local isTpActive = UI.GetValue("tp_enabled") and (singleKeybind and singleKeybind:IsEnabled())
    local isSeqActive = UI.GetValue("seq_enabled") and (seqKeybind and seqKeybind:IsEnabled())
    
    if isTpActive or isSeqActive then
        primaryPart.CFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z)
        if UI.GetValue("tp_notifications") then
            notify("Teleport finished!", "Matcha Teleporter", 1)
        end
        return true
    end
    return false
end


end


local function saveConfig()
local HttpService = game:GetService("HttpService")
local data = {
tp_x = UI.GetValue("tp_x") or "-1095.28",
tp_y = UI.GetValue("tp_y") or "60.4",
tp_z = UI.GetValue("tp_z") or "-6.16",
tp_delay = UI.GetValue("tp_delay") or 1.0,
tp_mode = UI.GetValue("tp_mode") or 0,
tp_step_dist = UI.GetValue("tp_step_dist") or 20,
tp_notifications = UI.GetValue("tp_notifications") or false,
wp_r = wpColor.R, wp_g = wpColor.G, wp_b = wpColor.B,
plat_r = platColor.R, plat_g = platColor.G, plat_b = platColor.B,
waypoints = waypoints
}

local success, json = pcall(function()
    return HttpService:JSONEncode(data)
end)

if success then
    setclipboard(json)
    notify("Config copied to clipboard!", "Matcha Teleporter", 2)
    UI.SetValue("import_box", json)
else
    notify("Failed to save config!", "Matcha Teleporter", 2)
end


end

local function loadConfig(jsonStr)
local HttpService = game:GetService("HttpService")
if not jsonStr or jsonStr == "" then
notify("Paste config text into the box first.", "Matcha Teleporter", 2)
return
end

local success, decoded = pcall(function()
    return HttpService:JSONDecode(jsonStr)
end)

if success and decoded then
    UI.SetValue("tp_x", tostring(decoded.tp_x or "-1095.28"))
    UI.SetValue("tp_y", tostring(decoded.tp_y or "60.4"))
    UI.SetValue("tp_z", tostring(decoded.tp_z or "-6.16"))
    UI.SetValue("tp_delay", tonumber(decoded.tp_delay) or 1.0)
    UI.SetValue("tp_mode", tonumber(decoded.tp_mode) or 0)
    UI.SetValue("tp_step_dist", tonumber(decoded.tp_step_dist) or 20)
    UI.SetValue("tp_notifications", not not decoded.tp_notifications)
    
    if decoded.wp_r then wpColor = Color3.new(decoded.wp_r, decoded.wp_g, decoded.wp_b) end
    if decoded.plat_r then platColor = Color3.new(decoded.plat_r, decoded.plat_g, decoded.plat_b) end
    
    if decoded.waypoints and type(decoded.waypoints) == "table" then
     
        for i = #decoded.waypoints + 1, #waypointDrawings do
            if waypointDrawings[i] then
                pcall(function() waypointDrawings[i]:Remove() end)
                waypointDrawings[i] = nil
            end
        end

        waypoints = decoded.waypoints
        for i, wp in ipairs(waypoints) do
            UI.SetValue("s" .. i .. "_x", tostring(wp.x))
            UI.SetValue("s" .. i .. "_y", tostring(wp.y))
            UI.SetValue("s" .. i .. "_z", tostring(wp.z))
        end
    end
    notify("Settings loaded!", "Matcha Teleporter", 2)
else
    notify("Bad config data!", "Matcha Teleporter", 2)
end


end

UI.AddTab("Teleporter", function(tab)
local tpSec = tab:Section("Config", "Left", {"Single", "Sequence", "Settings", "Players & Visuals", "Platform"})

if tpSec.page == 0 then
    tpSec:Toggle("tp_enabled", "Arm Loop Teleport", false)
    singleKeybind = tpSec:Keybind("tp_keybind", 0x54, "toggle") 
    singleKeybind:AddToHotkey("Loop Teleport", "tp_enabled")
    
    tpSec:Spacing()
    tpSec:Button("Grab Current Position", function()
        local pos = getCurrentPos()
        UI.SetValue("tp_x", string.format("%.2f", pos.X))
        UI.SetValue("tp_y", string.format("%.2f", pos.Y))
        UI.SetValue("tp_z", string.format("%.2f", pos.Z))
    end)
    
    tpSec:InputText("tp_x", "X Coordinate", "-1095.28")
    tpSec:InputText("tp_y", "Y Coordinate", "60.4")
    tpSec:InputText("tp_z", "Z Coordinate", "-6.16")
    
elseif tpSec.page == 1 then
    tpSec:Toggle("seq_enabled", "Arm Sequence Teleport", false)
    seqKeybind = tpSec:Keybind("seq_keybind", 0x54, "toggle")
    seqKeybind:AddToHotkey("Sequence TP", "seq_enabled")
    
    tpSec:Spacing()
    tpSec:Button("Reset Sequence Progression", function()
        sequenceIndex = 1
        notify("Path reset back to Waypoint 1", "Matcha Teleporter", 1)
    end)
    
    tpSec:Spacing()
    tpSec:Button("Add Waypoint", function()
        table.insert(waypoints, { x = "0.00", y = "0.00", z = "0.00" })
    end)
    tpSec:Button("Remove Last Waypoint", function()
        if #waypoints > 1 then
       
            if waypointDrawings[#waypoints] then
                pcall(function() waypointDrawings[#waypoints]:Remove() end)
                waypointDrawings[#waypoints] = nil
            end
            table.remove(waypoints)
        end
    end)
    
    for i, wp in ipairs(waypoints) do
        tpSec:Spacing()
      
        tpSec:Button("Grab Waypoint " .. i, function()
            local pos = getCurrentPos()
            local px = string.format("%.2f", pos.X)
            local py = string.format("%.2f", pos.Y)
            local pz = string.format("%.2f", pos.Z)
            
            waypoints[i].x = px
            waypoints[i].y = py
            waypoints[i].z = pz
            
            UI.SetValue("s" .. i .. "_x", px)
            UI.SetValue("s" .. i .. "_y", py)
            UI.SetValue("s" .. i .. "_z", pz)
        end)
        tpSec:InputText("s" .. i .. "_x", "X" .. i, wp.x, function(val) waypoints[i].x = val end)
        tpSec:InputText("s" .. i .. "_y", "Y" .. i, wp.y, function(val) waypoints[i].y = val end)
        tpSec:InputText("s" .. i .. "_z", "Z" .. i, wp.z, function(val) waypoints[i].z = val end)
    end
    
elseif tpSec.page == 2 then
    tpSec:SliderFloat("tp_delay", "Wait Between Teleports", 0.0, 10.0, 1.0, "%.2fs")
    tpSec:Combo("tp_mode", "Teleport Method", {"Instant", "Anti-Cheat Bypass (Step)"}, 0)
    tpSec:SliderInt("tp_step_dist", "Bypass Step Studs", 5, 100, 20)
    tpSec:Toggle("tp_notifications", "Notify on Jumps", false)
    
    tpSec:Spacing()
    tpSec:Text("Configuration Management")
    tpSec:Button("Copy Config", function()
        saveConfig()
    end)
    
    tpSec:Spacing()
    tpSec:InputText("import_box", "Paste Config Here", "")
    tpSec:Button("Import Config", function()
        loadConfig(UI.GetValue("import_box"))
    end)
    
elseif tpSec.page == 3 then
    tpSec:Text("Waypoint Visualizer")
    tpSec:Toggle("show_visualizer", "Show Waypoints On Screen", true)
    tpSec:Toggle("rainbow_wp", "Rainbow Waypoints", false)
    
    
    tpSec:ColorPicker("wp_cp", wpColor.R, wpColor.G, wpColor.B, 1, function(c, a) 
        wpColor = c 
    end)
    
    tpSec:Spacing()
    tpSec:Text("Player Teleporter")
    
    local pCombo = tpSec:Combo("player_list", "Select Player", {"None"}, 0)
    
    tpSec:Button("Refresh Players", function()
        pCombo:Clear()
        pCombo:Add("None")
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                pCombo:Add(p.Name)
            end
        end
        notify("Player list updated!", "Matcha", 1)
    end)
    
    tpSec:Button("Teleport to Player", function()
        local targetName = pCombo:GetText()
        if targetName and targetName ~= "None" then
            local targetPlayer = Players:FindFirstChild(targetName)
            
            if targetPlayer and targetPlayer.Character and targetPlayer.Character.PrimaryPart then
                local pPos = targetPlayer.Character.PrimaryPart.Position
                teleportTo(pPos)
            else
                notify("Player is dead or not found!", "Error", 2)
            end
        else
            notify("Please select a player first.", "Error", 2)
        end
    end)
    
elseif tpSec.page == 4 then
    tpSec:Text("AirWalk Platform")
    tpSec:Tip("Creates a solid floor underneath you so you don't fall into the void.")
    tpSec:Toggle("plat_enabled", "Enable Platform", false)
    
    tpSec:ColorPicker("plat_cp", platColor.R, platColor.G, platColor.B, 1, function(c, a) 
        platColor = c 
    end)
    
    tpSec:SliderInt("plat_size", "Platform Size", 5, 50, 15)
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
    for i = 1, math.max(#waypoints, #waypointDrawings) do
        if not waypointDrawings[i] then
            waypointDrawings[i] = Drawing.new("Text")
            waypointDrawings[i].Center = true
            waypointDrawings[i].Size = 18
            waypointDrawings[i].Outline = true
        end

        local textDrawing = waypointDrawings[i]
        
        if showWp and waypoints[i] then
            local sx = tonumber(UI.GetValue("s" .. i .. "_x")) or tonumber(waypoints[i].x) or 0
            local sy = tonumber(UI.GetValue("s" .. i .. "_y")) or tonumber(waypoints[i].y) or 0
            local sz = tonumber(UI.GetValue("s" .. i .. "_z")) or tonumber(waypoints[i].z) or 0
            local pos3D = Vector3.new(sx, sy, sz)
            
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
    
    local char = LocalPlayer.Character
    local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
    
    if UI.GetValue("plat_enabled") and root then
    
        if not platformPart or not platformPart.Parent then
            pcall(function()
                platformPart = Instance.new("Part")
                platformPart.Name = "MatchaPlatform"
                platformPart.Anchored = true
                platformPart.CanCollide = true
                platformPart.Transparency = 0.5
                pcall(function() platformPart.Material = Enum.Material.Neon end)
                platformPart.Parent = game:GetService("Workspace")
            end)
        end
        
        if platformPart then
            local size = UI.GetValue("plat_size") or 15
            
            platformPart.Size = Vector3.new(size, 3, size)
            platformPart.Color = platColor
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            local offset = 3.0 
            if hum then
                if hum.RigType == Enum.HumanoidRigType.R15 then
                    offset = hum.HipHeight + (root.Size.Y / 2)
                end
            end
            
            local expectedY = root.Position.Y - offset - (platformPart.Size.Y / 2)
            
            if currentPlatformY == nil or math.abs(currentPlatformY - expectedY) > 6 then
                currentPlatformY = expectedY
            end
            
            platformPart.CFrame = CFrame.new(root.Position.X, currentPlatformY, root.Position.Z)
            
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
                root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
            end)
        end
    else
   
        if platformPart then
            pcall(function() platformPart:Destroy() end)
            platformPart = nil
        end
        currentPlatformY = nil 
    end
end


end)

task.spawn(function()
while true do
task.wait()

    local isSeqActive = UI.GetValue("seq_enabled") and (seqKeybind and seqKeybind:IsEnabled())
    local isTpActive = UI.GetValue("tp_enabled") and (singleKeybind and singleKeybind:IsEnabled())
    
    if isSeqActive then
        local sequencePoints = {}
        for i = 1, #waypoints do
            local sx = tonumber(UI.GetValue("s" .. i .. "_x")) or tonumber(waypoints[i].x) or 0
            local sy = tonumber(UI.GetValue("s" .. i .. "_y")) or tonumber(waypoints[i].y) or 0
            local sz = tonumber(UI.GetValue("s" .. i .. "_z")) or tonumber(waypoints[i].z) or 0
            table.insert(sequencePoints, Vector3.new(sx, sy, sz))
        end
        
        if sequenceIndex > #sequencePoints or sequenceIndex < 1 then
            sequenceIndex = 1
        end
        
        local target = sequencePoints[sequenceIndex]
        if target then
        
            if getDistance(getCurrentPos(), target) <= 5 then
                sequenceIndex = sequenceIndex + 1
                if sequenceIndex > #sequencePoints then sequenceIndex = 1 end
            else
                local completed = teleportTo(target)
                if completed then
                    local delayTime = UI.GetValue("tp_delay") or 1.0
                    task.wait(delayTime)
                    
                    sequenceIndex = sequenceIndex + 1
                    if sequenceIndex > #sequencePoints then
                        sequenceIndex = 1
                    end
                end
            end
        end
        
    elseif isTpActive then
        local x = tonumber(UI.GetValue("tp_x")) or -1095.28
        local y = tonumber(UI.GetValue("tp_y")) or 60.4
        local z = tonumber(UI.GetValue("tp_z")) or -6.16
        
        local completed = teleportTo(Vector3.new(x, y, z))
        if completed then
            local delayTime = UI.GetValue("tp_delay") or 1.0
            task.wait(delayTime)
        end
    end
end


end)
