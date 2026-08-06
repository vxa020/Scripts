local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ws = game.Workspace
local lp = Players.LocalPlayer

local clamp = function(v, a, b) return math.max(a, math.min(b, v)) end

if _G.BBAP_stop then _G.BBAP_stop() end

local CONFIG = { enabled = true, ui = true, lead = 0.32, cd = 0.45, cap = 200, m2 = false }
_G.BBAP_installed = true

local attempts = 0
local hits = 0
local swingOK = false
local lastFire = 0
local hitFlash = 0
local lastParryCount = nil
local lastParryTime = nil
local balls = {}
local tracked = nil
local pingMs = 0

local D = {}
local function mkSquare()
  local s = Drawing.new("Square"); D[#D + 1] = s; return s
end
local function mkText(y, size)
  local t = Drawing.new("Text")
  t.Size = size or 13; t.Font = 4; t.Outline = true
  t.Position = Vector2.new(20, y); t.Visible = false
  D[#D + 1] = t; return t
end

local bg = mkSquare()
bg.Filled = true; bg.Color = Color3.fromRGB(10, 12, 18); bg.Transparency = 0.35
bg.Position = Vector2.new(10, 10); bg.Size = Vector2.new(246, 172); bg.Visible = false

local title = mkText(18, 14)
local lineStatus = mkText(40)
local lineLead = mkText(58)
local lineCD = mkText(76)
local lineCap = mkText(94)
local lineSwing = mkText(112)
local lineStats = mkText(130)
local lineTarget = mkText(148)

local barBg = mkSquare()
barBg.Filled = true; barBg.Color = Color3.fromRGB(40, 40, 50); barBg.Transparency = 0.4
barBg.Position = Vector2.new(20, 162); barBg.Size = Vector2.new(226, 8); barBg.Visible = false
local barFill = mkSquare()
barFill.Filled = true; barFill.Color = Color3.fromRGB(80, 220, 100)
barFill.Position = Vector2.new(20, 162); barFill.Size = Vector2.new(0, 8); barFill.Visible = false

local ret = mkSquare()
ret.Filled = false; ret.Color = Color3.fromRGB(80, 220, 255); ret.Thickness = 2; ret.Visible = false
local retText = mkText(0, 12)
retText.Center = true

local flash = mkText(20, 16)
flash.Position = Vector2.new(20, 186)

local hUIS
hUIS = UIS.InputBegan:Connect(function(inp)
  local kc = inp and inp.KeyCode
  local function is(k) return kc == k or kc == k.Value end
  if is(Enum.KeyCode.T) then
    CONFIG.enabled = not CONFIG.enabled
  elseif is(Enum.KeyCode.U) then
    CONFIG.ui = not CONFIG.ui
  elseif is(Enum.KeyCode.Z) then
    CONFIG.lead = math.max(0.05, CONFIG.lead - 0.05)
  elseif is(Enum.KeyCode.X) then
    CONFIG.lead = math.min(1.0, CONFIG.lead + 0.05)
  elseif is(Enum.KeyCode.LeftBracket) then
    CONFIG.cap = math.min(250, CONFIG.cap + 10)
  elseif is(Enum.KeyCode.RightBracket) then
    CONFIG.cap = math.max(20, CONFIG.cap - 10)
  elseif is(Enum.KeyCode.Comma) then
    CONFIG.cd = math.max(0.25, CONFIG.cd - 0.05)
  elseif is(Enum.KeyCode.Period) then
    CONFIG.cd = math.min(1.0, CONFIG.cd + 0.05)
  elseif is(Enum.KeyCode.N) then
    CONFIG.m2 = not CONFIG.m2
  end
end)

task.spawn(function()
  while _G.BBAP_installed do
    local bf = ws:FindFirstChild("Balls")
    balls = bf and bf:GetChildren() or {}
    local char = lp.Character
    local cnt = char and char:GetAttribute("ServerParryCount")
    if cnt then
      if lastParryCount and cnt > lastParryCount then
        hits = hits + (cnt - lastParryCount)
        hitFlash = os.clock()
      end
      lastParryCount = cnt
    end
    local pt = char and char:GetAttribute("ParryTime")
    if pt and pt ~= lastParryTime and lastParryTime ~= nil then
      swingOK = true
    end
    if pt then lastParryTime = pt end
    task.wait(0.25)
  end
end)

local hRender
hRender = RunService.RenderStepped:Connect(function()
  local now = os.clock()
  local png = pcall(function() return GetPingValue() end)
  pingMs = png and GetPingValue() or 0

  local char = lp.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  local alive = char and char.Parent == ws.Alive and not char:GetAttribute("Stunned")

  tracked = nil
  if CONFIG.enabled and root and alive then
    local rootPos = root.Position
    local bestDist = math.huge
    for _, b in ipairs(balls) do
      local vel = b.AssemblyLinearVelocity
      if vel.Magnitude > 20 then
        local toBall = b.Position - rootPos
        local d = toBall.Magnitude
        if toBall:Dot(vel) < 0 and d < bestDist then
          bestDist = d
          tracked = { pos = b.Position, vel = vel, dist = d, speed = vel.Magnitude }
        end
      end
    end
    if tracked then
      local tti = tracked.dist / tracked.speed
      local D = CONFIG.lead + pingMs * 2 / 1000
      local zone = 8
      local window = D + zone / tracked.speed
      if tti <= window and tti >= 0.04 and tracked.dist <= CONFIG.cap and (now - lastFire) >= CONFIG.cd then
        local fired = pcall(CONFIG.m2 and mouse2click or mouse1click)
        if fired then
          lastFire = now
          attempts = attempts + 1
          swingOK = false
        end
      end
    end
  end

  local show = CONFIG.ui
  bg.Visible = show; title.Visible = show
  lineStatus.Visible = show; lineLead.Visible = show; lineCD.Visible = show
  lineCap.Visible = show; lineSwing.Visible = show; lineStats.Visible = show
  lineTarget.Visible = show; barBg.Visible = show; barFill.Visible = show

  if show then
    title.Text = "BLADE BALL AUTO PARRY"
    title.Color = Color3.fromRGB(80, 220, 255)
    lineStatus.Text = (CONFIG.enabled and "STATUS: ON   [T]") or "STATUS: OFF  [T]"
    lineStatus.Color = CONFIG.enabled and Color3.fromRGB(120, 240, 140) or Color3.fromRGB(255, 110, 110)
    lineLead.Text = string.format("LEAD: %.2fs  [Z/X]  ping %dms", CONFIG.lead, pingMs)
    lineLead.Color = Color3.fromRGB(235, 235, 235)
    lineCD.Text = string.format("COOLDOWN: %.2f  [ , / . ]", CONFIG.cd)
    lineCD.Color = Color3.fromRGB(235, 235, 235)
    lineCap.Text = string.format("MAX RANGE: %.0f  [ [ / ] ]", CONFIG.cap)
    lineCap.Color = Color3.fromRGB(235, 235, 235)
    local mname = CONFIG.m2 and "RMB" or "LMB"
    if swingOK then
      lineSwing.Text = "SWING: OK"
      lineSwing.Color = Color3.fromRGB(120, 240, 140)
    else
      lineSwing.Text = "SWING: waiting  [" .. mname .. ", N]"
      lineSwing.Color = Color3.fromRGB(255, 200, 80)
    end
    lineStats.Text = string.format("SWINGS: %d   HITS: %d", attempts, hits)
    lineStats.Color = Color3.fromRGB(235, 235, 235)
    if tracked then
      local tti = tracked.dist / tracked.speed
      lineTarget.Text = string.format("BALL: %.0f stu  %d spd  TTI %.2fs", tracked.dist, tracked.speed, tti)
      lineTarget.Color = Color3.fromRGB(80, 220, 255)
      local frac = clamp(1 - tracked.dist / math.max(1, CONFIG.lead * tracked.speed), 0, 1)
      barFill.Size = Vector2.new(226 * frac, 8)
      local inFire = tti <= CONFIG.lead + pingMs * 2 / 1000 + 8 / tracked.speed
      barFill.Color = inFire and Color3.fromRGB(80, 240, 100) or Color3.fromRGB(255, 200, 80)
    else
      lineTarget.Text = "BALL: no target"
      lineTarget.Color = Color3.fromRGB(150, 150, 160)
      barFill.Size = Vector2.new(0, 8)
    end
  end

  local flashing = (now - hitFlash) < 0.35
  flash.Visible = show and flashing
  if show and flashing then
    flash.Text = "PARRY HIT!"
    flash.Color = Color3.fromRGB(120, 255, 140)
  end

  if CONFIG.ui and tracked and root then
    local sp, vis = WorldToScreen(tracked.pos + Vector3.new(0, 5, 0))
    if vis then
      ret.Position = Vector2.new(sp.X - 15, sp.Y - 15)
      ret.Size = Vector2.new(30, 30)
      ret.Visible = true
      retText.Position = Vector2.new(sp.X, sp.Y - 22)
      retText.Text = string.format("%.1f", tracked.dist / tracked.speed)
      retText.Visible = true
    else
      ret.Visible = false; retText.Visible = false
    end
  else
    ret.Visible = false; retText.Visible = false
  end
end)

_G.BBAP_stop = function()
  _G.BBAP_installed = false
  if hUIS then hUIS:Disconnect() end
  if hRender then hRender:Disconnect() end
  for _, d in ipairs(D) do d:Remove() end
  _G.BBAP_stop = nil
end
print("BB AUTO PARRY LOADED")
