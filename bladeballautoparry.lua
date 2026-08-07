

-------------------------------------------------------------------------
-- Made By vxa_020 --
-------------------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ws = game.Workspace
local lp = Players.LocalPlayer
local ZONE = 8
local CLOSE_R = 18
local PARRY_R = 10
local HEIGHT = 7
local SWING_GUARD = 0.2

local clamp = function(v, a, b) return math.max(a, math.min(b, v)) end

if _G.BBAP_stop then _G.BBAP_stop() end

local CONFIG = {
  enabled = true, ui = true, esp = true, range = true,
  curve = true, clash = true, ping = true, focus = true,
  lead = 0.32, cd = 0.45, cap = 200, m2 = false, pingMul = 1.5,
}
_G.BBAP_installed = true

local attempts = 0
local hits = 0
local swingOK = false
local lastFire = 0
local firedAt = 0
local firedHits = 0
local hitFlash = 0
local lastParryCount = nil
local lastParryTime = nil
local balls = {}
local targets = {}
local tracked = nil
local curBall = nil
local ballHist = {}
local distHist = {}
local closingStreak = {}
local swingCount = {}
local accelSm = Vector3.new(0, 0, 0)
local pingSm = 0
local pingMs = 0
local lastCharAddr = nil
local clashRisk = 0
local clashName = nil
local predictedPoint = nil
local tti = nil
local curId = nil
local firedId = nil

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
local function mkLine()
  local l = Drawing.new("Line"); l.Thickness = 1; l.Visible = false
  D[#D + 1] = l; return l
end

local bg = mkSquare()
bg.Filled = true; bg.Color = Color3.fromRGB(9, 12, 20); bg.Transparency = 0.25
bg.Position = Vector2.new(12, 12); bg.Size = Vector2.new(268, 218); bg.Rounding = 10; bg.Visible = false
local bgB = mkSquare()
bgB.Filled = false; bgB.Color = Color3.fromRGB(80, 220, 255); bgB.Thickness = 1
bgB.Position = Vector2.new(12, 12); bgB.Size = Vector2.new(268, 218); bgB.Rounding = 10; bgB.Visible = false

local title = mkText(20, 15)
local lineStatus = mkText(44)
local lineLead = mkText(62)
local lineCD = mkText(80)
local lineRange = mkText(98)
local lineSwing = mkText(116)
local lineBall = mkText(134)
local lineClash = mkText(152)
local lineStats = mkText(170)
local lineHint = mkText(190, 11)

local barBg = mkSquare()
barBg.Filled = true; barBg.Color = Color3.fromRGB(40, 42, 52); barBg.Transparency = 0.4
barBg.Position = Vector2.new(22, 206); barBg.Size = Vector2.new(248, 8); barBg.Rounding = 4; barBg.Visible = false
local barFill = mkSquare()
barFill.Filled = true; barFill.Color = Color3.fromRGB(80, 240, 100)
barFill.Position = Vector2.new(22, 206); barFill.Size = Vector2.new(0, 8); barFill.Rounding = 4; barFill.Visible = false

local ret = mkSquare()
ret.Filled = false; ret.Color = Color3.fromRGB(80, 220, 255); ret.Thickness = 2; ret.Visible = false
ret.ZIndex = 2
local retText = mkText(0, 12)
retText.Center = true; retText.ZIndex = 2

local flash = mkText(24, 15)
flash.Position = Vector2.new(24, 232)

local circlePool = {}
for i = 1, 64 do circlePool[i] = mkLine() end
local pathPool = {}
for i = 1, 28 do pathPool[i] = mkLine() end
local espPool = {}
for i = 1, 32 do
  local t = Drawing.new("Text")
  t.Size = 12; t.Font = 4; t.Outline = true; t.Center = true; t.Visible = false; t.ZIndex = 2
  D[#D + 1] = t; espPool[i] = t
end

local hUIS
hUIS = UIS.InputBegan:Connect(function(inp)
  local kc = inp and inp.KeyCode
  local function is(k) return kc == k or kc == k.Value end
  if is(Enum.KeyCode.T) then
    CONFIG.enabled = not CONFIG.enabled
  elseif is(Enum.KeyCode.U) then
    CONFIG.ui = not CONFIG.ui
  elseif is(Enum.KeyCode.Y) then
    CONFIG.range = not CONFIG.range
  elseif is(Enum.KeyCode.H) then
    CONFIG.esp = not CONFIG.esp
  elseif is(Enum.KeyCode.G) then
    CONFIG.clash = not CONFIG.clash
  elseif is(Enum.KeyCode.B) then
    CONFIG.curve = not CONFIG.curve
  elseif is(Enum.KeyCode.M) then
    CONFIG.ping = not CONFIG.ping
  elseif is(Enum.KeyCode.C) then
    CONFIG.focus = not CONFIG.focus
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
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
      if p ~= lp then
        local char = p.Character
        local head = char and char:FindFirstChild("Head")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if head and root then
          out[#out + 1] = {
            name = p.Name,
            head = head,
            root = root,
            ability = p:GetAttribute("CurrentlyEquippedAbility") or "",
            parrying = char:GetAttribute("Parrying") or false,
            focused = char:GetAttribute("IsFocusedByBall") or false,
          }
        end
      end
    end
    targets = out
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
    if pt and pt ~= lastParryTime and lastParryTime ~= nil then swingOK = true end
    if pt then lastParryTime = pt end
    task.wait(0.25)
  end
end)

local function arriveAt(ball, rootPos)
  local v = ball.vel
  local a = accelSm
  if a.Magnitude > 3 then
    local p = ball.pos
    local vv = v
    local t = 0
    while t < 3 do
      p = p + vv * 0.02
      vv = vv + a * 0.02
      t = t + 0.02
      if (p - rootPos).Magnitude < 5 then return t end
      if vv.Magnitude < 1 then return nil end
    end
    return nil
  end
  local toBall = ball.pos - rootPos
  local v2 = v:Dot(v)
  if v2 <= 0.001 then return nil end
  local t = -(toBall:Dot(v)) / v2
  if t < 0 or t > 3 then return nil end
  return t
end

local function predictPoint(ball, t)
  local a = CONFIG.curve and accelSm or Vector3.new(0, 0, 0)
  if a.Magnitude <= 3 then a = Vector3.new(0, 0, 0) end
  return ball.pos + ball.vel * t + a * (0.5 * t * t)
end

local function drawCircle(cx, cy, cz, r, pool, count, color, thick, transp)
  for i = 0, count - 1 do
    local a0 = (i / count) * 2 * math.pi
    local a1 = ((i + 1) / count) * 2 * math.pi
    local p0 = Vector3.new(cx + math.cos(a0) * r, cy, cz + math.sin(a0) * r)
    local p1 = Vector3.new(cx + math.cos(a1) * r, cy, cz + math.sin(a1) * r)
    local s0, v0 = WorldToScreen(p0)
    local s1, v1 = WorldToScreen(p1)
    local ln = pool[i + 1]
    if v0 and v1 then
      ln.From = s0; ln.To = s1
      ln.Color = color; ln.Thickness = thick; ln.Transparency = transp or 0
      ln.Visible = true
    else
      ln.Visible = false
    end
  end
end

local hRender
hRender = RunService.RenderStepped:Connect(function()
  local now = os.clock()
  local okPing, rawPing = pcall(GetPingValue)
  local rp = okPing and (type(rawPing) == "number" and rawPing or 0) or pingSm
  pingSm = pingSm == 0 and rp or (pingSm * 0.7 + rp * 0.3)
  pingMs = pingSm

  local bf = ws:FindFirstChild("Balls")
  balls = bf and bf:GetChildren() or {}

  local char = lp.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  local alive = char and char.Parent == ws.Alive and not char:GetAttribute("Stunned")
  local focused = char and (char:GetAttribute("IsFocusedByBall") or false) or false
  local pv2 = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
  local moving = pv2.Magnitude > 5
  local effR = PARRY_R + (moving and 6 or 0)
  local effH = HEIGHT + (moving and 3 or 0)

  local charAddr = char and char.Address
  if charAddr ~= lastCharAddr then
    lastCharAddr = charAddr
    distHist = {}
    closingStreak = {}
    swingCount = {}
    firedId = nil
    curId = nil
    ballHist = {}
    accelSm = Vector3.new(0, 0, 0)
  end

  tracked = nil; curBall = nil; tti = nil; predictedPoint = nil
  clashRisk = 0; clashName = nil
  if root and alive then
    local rootPos = root.Position
    local bestPath = nil
    local bestPathBall = nil
    local bestPathTca = math.huge
    local nearest = nil
    local nearestBall = nil
    local nearestD = math.huge
    local newDistHist = {}
    for _, b in ipairs(balls) do
      local vel = b.AssemblyLinearVelocity
      local speed = vel.Magnitude
      if speed > 20 and speed < 350 then
        local toBall = b.Position - rootPos
        local d = toBall.Magnitude
        local v2 = vel:Dot(vel)
        local key = b.Address
        local prevD = distHist[key]
        local teleport = prevD ~= nil and d > prevD * 1.8 and d - prevD > 40
        local closing = prevD ~= nil and d < prevD and not teleport
        local streak = closing and ((closingStreak[key] or 0) + 1) or 0
        closingStreak[key] = streak
        newDistHist[key] = d
        if toBall:Dot(vel) < 0 and v2 > 1 then
          local tca = -(toBall:Dot(vel)) / v2
          local vhat = vel / math.sqrt(v2)
          local rv = toBall:Dot(vhat)
          local perp = math.sqrt(math.max(0, d * d - rv * rv))
          local impact = b.Position + vel * tca
          local dY = math.abs(impact.Y - rootPos.Y)
          local align = rv / math.max(0.01, d)
          local homing = align > -0.9 and align < -0.15
          local strongClosing = streak >= 2
          local entry = { pos = b.Position, vel = vel, speed = speed, dist = d, perp = perp, tca = tca, dY = dY, closing = closing, strongClosing = strongClosing, homing = homing }
          local onPath = perp <= effR and dY <= effH
          if (onPath or closing or strongClosing or homing) and tca < bestPathTca then
            bestPathTca = tca
            bestPath = entry
            bestPathBall = b
          end
          if d < nearestD then
            nearestD = d
            nearest = entry
            nearestBall = b
          end
        end
      end
    end
    distHist = newDistHist
    if bestPath then
      tracked = bestPath
      curBall = bestPathBall
    elseif nearest and nearestD <= CLOSE_R then
      tracked = nearest
      curBall = nearestBall
    end
  end

  if tracked and curBall then
    local id = curBall.Address
    if id ~= curId then
      curId = id
      firedId = nil
      ballHist = {}
    end
    local ht = os.clock()
    if #ballHist == 0 or (ht - ballHist[#ballHist].t) >= 0.05 then
      local prev = ballHist[#ballHist]
      if prev and prev.vel and tracked.vel:Dot(prev.vel) < -1 then
        ballHist = {}
        firedId = nil
      end
      ballHist[#ballHist + 1] = { t = ht, vel = tracked.vel, ball = curBall }
      if #ballHist > 15 then table.remove(ballHist, 1) end
    end
    if #ballHist >= 2 then
      local b0 = ballHist[#ballHist - 1]
      local b1 = ballHist[#ballHist]
      local dt = b1.t - b0.t
      if dt > 0.03 then
        local a = (b1.vel - b0.vel) / dt
        if a.Magnitude < 400 then accelSm = accelSm:Lerp(a, 0.35) end
      end
    end
    if root then
      local rootPos = root.Position
      local tCurve = (CONFIG.curve or moving or tracked.homing) and arriveAt(tracked, rootPos)
      tti = tCurve or (tracked.dist / math.max(1, tracked.speed))
      if tti then
        predictedPoint = predictPoint(tracked, tti)
        for i = 1, #targets do
          local tg = targets[i]
          if tg.root then
            local to = tg.root.Position - tracked.pos
            if to.Magnitude < CONFIG.cap * 1.25 then
              local t2 = CONFIG.curve and arriveAt(tracked, tg.root.Position) or (to.Magnitude / tracked.speed)
              if t2 and math.abs(t2 - tti) < 0.22 then
                local w = tg.parrying and 1.0 or (tg.focused and 0.85 or 0.55)
                if w > clashRisk then clashRisk = w; clashName = tg.name end
              end
            end
          end
        end
      end
    end
  else
    ballHist = {}
    accelSm = Vector3.new(0, 0, 0)
  end

  if CONFIG.enabled and tracked and tti and root and alive then
    local id = curBall.Address
    local lead = CONFIG.lead + (moving and 0.10 or 0) + (tracked.homing and 0.06 or 0) + (CONFIG.ping and (math.min(pingMs, 250) * CONFIG.pingMul / 1000) or 0)
    local window = lead + ZONE / tracked.speed
    local closeFire = tracked.dist <= CLOSE_R
    local focusOK = not CONFIG.focus or focused or closeFire or moving
    local focusThreat = CONFIG.focus and focused
    local onPath = tracked.perp <= effR and tracked.dY <= effH
    local threat = moving or onPath or tracked.closing or tracked.strongClosing or tracked.homing or focusThreat
    local freshD = (curBall.Position - root.Position).Magnitude
    local freshOk = freshD >= 0 and freshD < 10000
    local notFired = firedId ~= id
    local canRetry = not notFired and (swingCount[id] or 0) < 2 and hits == firedHits and (now - firedAt) > 0.45 and freshD <= 40
    local swingable = notFired or canRetry
    local ok = (closeFire or (threat and tti <= window + 0.02)) and swingable and freshOk
      and freshD <= CONFIG.cap and focusOK and (now - lastFire) >= SWING_GUARD
    if ok then
      local blocked = CONFIG.clash and clashRisk >= 0.8 and not closeFire
      if not blocked then
        local fired = pcall(CONFIG.m2 and mouse2click or mouse1click)
        if not fired and CONFIG.m2 then fired = pcall(mouse1click) end
        if fired then
          lastFire = now
          attempts = attempts + 1
          swingOK = false
          firedId = id
          firedAt = now
          firedHits = hits
          swingCount[id] = (swingCount[id] or 0) + 1
        end
      end
    end
  end

  local show = CONFIG.ui
  bg.Visible = show; bgB.Visible = show; title.Visible = show
  lineStatus.Visible = show; lineLead.Visible = show; lineCD.Visible = show
  lineRange.Visible = show; lineSwing.Visible = show; lineBall.Visible = show
  lineClash.Visible = show; lineStats.Visible = show; lineHint.Visible = show
  barBg.Visible = show; barFill.Visible = show

  if show then
    title.Text = "BLADE BALL AUTO PARRY"
    title.Color = Color3.fromRGB(80, 220, 255)
    lineStatus.Text = (CONFIG.enabled and "STATUS: ON [T]" or "STATUS: OFF [T]") .. "  FOCUS:" .. (CONFIG.focus and "ON[C]" or "OFF[C]")
    if CONFIG.enabled and CONFIG.focus and not focused and not moving then
      lineStatus.Color = Color3.fromRGB(255, 200, 80)
    else
      lineStatus.Color = CONFIG.enabled and Color3.fromRGB(120, 240, 140) or Color3.fromRGB(255, 110, 110)
    end
    lineLead.Text = string.format("LEAD: %.2fs [Z/X]  PING %dms %s%s", CONFIG.lead, math.floor(pingMs), CONFIG.ping and "[M]on" or "[M]off", moving and "  MOVING" or "")
    lineLead.Color = Color3.fromRGB(235, 235, 235)
    lineCD.Text = string.format("COOLDOWN: %.2f  [ , / . ]", CONFIG.cd)
    lineCD.Color = Color3.fromRGB(235, 235, 235)
    lineRange.Text = string.format("RANGE: %.0f [ [ / ] ]  %s", CONFIG.cap, CONFIG.range and "Y:on" or "Y:off")
    lineRange.Color = Color3.fromRGB(235, 235, 235)
    local mname = CONFIG.m2 and "RMB" or "LMB"
    if swingOK then
      lineSwing.Text = "SWING: OK"
      lineSwing.Color = Color3.fromRGB(120, 240, 140)
    else
      lineSwing.Text = "SWING: waiting  [" .. mname .. ", N]"
      lineSwing.Color = Color3.fromRGB(255, 200, 80)
    end
    if tracked and tti then
      local fstate = CONFIG.focus and (focused and "FOCUSED" or "WAIT") or "ANY"
      local close = tracked.dist <= CLOSE_R and " CLOSE" or ""
      local path
      if (tracked.perp or 0) <= effR and (tracked.dY or 99) <= effH then
        path = "PATH"
      elseif tracked.closing then
        path = "CLOSING"
      else
        path = "OFF"
      end
      if tracked.strongClosing then path = path .. "+S" end
      if tracked.homing then path = path .. "+H" end
      lineBall.Text = string.format("BALL: %.0f st  %d spd  TTI %.2fs  %s %.0f Y%.0f %s%s", tracked.dist, tracked.speed, tti, path, tracked.perp or 0, tracked.dY or 0, fstate, close)
      lineBall.Color = Color3.fromRGB(80, 220, 255)
      local frac = clamp(1 - tracked.dist / math.max(1, CONFIG.lead * tracked.speed), 0, 1)
      barFill.Size = Vector2.new(248 * frac, 8)
      local leadD = CONFIG.lead + (moving and 0.10 or 0) + (tracked.homing and 0.06 or 0) + (CONFIG.ping and (math.min(pingMs, 250) * CONFIG.pingMul / 1000) or 0)
      local inFire = ((threat and tti <= leadD + ZONE / tracked.speed + 0.02) or tracked.dist <= CLOSE_R)
      barFill.Color = inFire and Color3.fromRGB(80, 240, 100) or Color3.fromRGB(255, 200, 80)
    else
      lineBall.Text = "BALL: no target"
      lineBall.Color = Color3.fromRGB(150, 150, 160)
      barFill.Size = Vector2.new(0, 8)
    end
    if clashName then
      if clashRisk >= 0.8 then
        lineClash.Text = "CLASH: " .. clashName .. "  [G] SKIP"
        lineClash.Color = Color3.fromRGB(255, 90, 90)
      else
        lineClash.Text = "CLASH RISK: " .. clashName .. " [G]"
        lineClash.Color = Color3.fromRGB(255, 200, 80)
      end
    else
      lineClash.Text = "CLASH: none  [G] " .. (CONFIG.clash and "protect" or "off")
      lineClash.Color = Color3.fromRGB(150, 150, 160)
    end
    local acc = attempts > 0 and math.floor(100 * hits / attempts) or 0
    lineStats.Text = string.format("SWINGS: %d  HITS: %d  ACC %d%%", attempts, hits, acc)
    lineStats.Color = Color3.fromRGB(235, 235, 235)
    lineHint.Text = "ESP:H RNG:Y CLASH:G FOCUS:C CURVE:B PING:M UI:U"
    lineHint.Color = Color3.fromRGB(140, 150, 165)
  end

  if root and CONFIG.range then
    local cy = root.Position.Y - 3.0
    drawCircle(root.Position.X, cy, root.Position.Z, CONFIG.cap, circlePool, 36, Color3.fromRGB(255, 255, 255), 1, 0.45)
    if tracked then
      local leadR = tracked.speed * (CONFIG.lead + (moving and 0.10 or 0) + (tracked.homing and 0.06 or 0) + (CONFIG.ping and (math.min(pingMs, 250) * CONFIG.pingMul / 1000) or 0))
      drawCircle(root.Position.X, cy, root.Position.Z, math.min(CONFIG.cap, leadR), circlePool, 24, Color3.fromRGB(80, 240, 120), 1, 0.2)
      local p0, v0 = WorldToScreen(tracked.pos)
      if v0 then
        circlePool[61].From = p0
        local p1, v1 = WorldToScreen(predictPoint(tracked, tti or tracked.tca))
        if v1 then
          circlePool[61].To = p1
          circlePool[61].Color = Color3.fromRGB(80, 220, 255)
          circlePool[61].Thickness = 1
          circlePool[61].Transparency = 0
          circlePool[61].Visible = true
        else
          circlePool[61].Visible = false
        end
      else
        circlePool[61].Visible = false
      end
    else
      circlePool[61].Visible = false
    end
    for i = 62, 64 do circlePool[i].Visible = false end
  else
    for i = 1, 64 do circlePool[i].Visible = false end
  end

  for i = 1, 28 do pathPool[i].Visible = false end
  if CONFIG.range and tracked and tti then
    local n = 0
    local p = tracked.pos
    local v = tracked.vel
    local a = CONFIG.curve and (accelSm.Magnitude > 3 and accelSm or Vector3.new(0, 0, 0)) or Vector3.new(0, 0, 0)
    local t = 0
    local prevS, prevV = WorldToScreen(p)
    while t < tti and n < 28 do
      p = p + v * 0.02
      v = v + a * 0.02
      t = t + 0.02
      local s, vis = WorldToScreen(p)
      if vis and prevV then
        n = n + 1
        local ln = pathPool[n]
        ln.From = prevS; ln.To = s
        ln.Color = Color3.fromRGB(80, 220, 255)
        ln.Thickness = 1
        ln.Transparency = 0.15
        ln.Visible = true
      end
      prevS = s; prevV = vis
    end
  end

  local nEsp = 0
  if CONFIG.esp then
    for i = 1, #targets do
      if nEsp >= 32 then break end
      local tg = targets[i]
      local sp, vis = WorldToScreen(tg.head.Position + Vector3.new(0, 3.4, 0))
      if vis then
        nEsp = nEsp + 1
        local e = espPool[nEsp]
        e.Position = Vector2.new(sp.X, sp.Y)
        e.Text = tg.ability ~= "" and tg.ability or "none"
        e.Color = tg.parrying and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(140, 220, 255)
        e.Visible = true
      end
    end
  end
  for i = nEsp + 1, 32 do espPool[i].Visible = false end

  if CONFIG.ui and tracked and root then
    local tp = predictedPoint or (tracked.pos + Vector3.new(0, 5, 0))
    local sp, vis = WorldToScreen(tp)
    if vis then
      ret.Position = Vector2.new(sp.X - 15, sp.Y - 15)
      ret.Size = Vector2.new(30, 30)
      ret.Color = clashRisk >= 0.8 and Color3.fromRGB(255, 80, 80) or (CONFIG.focus and not focused and not moving and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(80, 220, 255))
      ret.Visible = true
      retText.Position = Vector2.new(sp.X, sp.Y - 22)
      retText.Text = string.format("%.2f", tti or 0)
      retText.Color = clashRisk >= 0.8 and Color3.fromRGB(255, 90, 90) or (CONFIG.focus and not focused and not moving and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(220, 235, 255))
      retText.Visible = true
    else
      ret.Visible = false; retText.Visible = false
    end
  else
    ret.Visible = false; retText.Visible = false
  end

  local flashing = (now - hitFlash) < 0.35
  flash.Visible = show and flashing
  if show and flashing then
    flash.Text = "PARRY HIT!"
    flash.Color = Color3.fromRGB(120, 255, 140)
  end
end)

_G.BBAP_stop = function()
  _G.BBAP_installed = false
  if hUIS then hUIS:Disconnect() end
  if hRender then hRender:Disconnect() end
  for _, d in ipairs(D) do d:Remove() end
  _G.BBAP_stop = nil
end
print("Blade Bval script initiated")
