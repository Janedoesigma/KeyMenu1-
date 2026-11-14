--[[
    HOP HUB (beta 0.1) - Blox Fruits - WindUI
    Logicas portadas dos scripts Banana Cat Hub e Speed Hub X.

    COMO USAR O AUTO-RELOAD APOS O HOP:
      Opcao A) salve este arquivo em  workspace/HopHub/main.lua  (padrao)
      Opcao B) hospede em um link e ponha em SCRIPT_URL abaixo
]]

if getgenv().HopHubLoaded then return end
getgenv().HopHubLoaded = true

local SCRIPT_URL = getgenv().HopHubURL or ""  -- definido pelo loadstring (link raw do proprio script)
local FOLDER     = "HopHub"
local HOP_DELAY  = 10.5               -- segundos ocioso antes de dar hop

repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------
local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local HttpService   = game:GetService("HttpService")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local TeleportSvc   = game:GetService("TeleportService")
local CollectionSvc = game:GetService("CollectionService")
local Lighting      = game:GetService("Lighting")
local VIM           = game:GetService("VirtualInputManager")
local VirtualUser   = game:GetService("VirtualUser")
local LP            = Players.LocalPlayer

repeat task.wait() until LP:FindFirstChild("DataLoaded")
local CommF = RS:WaitForChild("Remotes"):WaitForChild("CommF_")
local Net   = RS:WaitForChild("Modules"):WaitForChild("Net")

LP.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

----------------------------------------------------------------
-- CONFIG (salva em arquivo)
----------------------------------------------------------------
local DEFAULT = {
    AutoHop = true,
    -- config
    WeaponTool = "Melee", TweenSpeed = 300, FarmDistance = 20,
    FastAttack = true, AttackDelay = 0, BringMob = true, BringRadius = 300,
    AutoBuso = true, AutoKen = false, AutoTeam = true, Team = "Pirates",
    -- chest / boss
    AutoChest = false, ChestNumber = 20, AutoChestHop = false, StopIfItem = true,
    Hop4h = false, AutoDarkbeard = false, AutoRipIndra = false,
    AutoTushita = false, AutoDoughKing = false,
    -- fruit
    AutoCollectFruit = false, AutoStoreFruit = false, AutoHopFruit = false,
}
local CFG_FILE = FOLDER .. "/config_" .. LP.UserId .. ".json"
local Cfg = {}
for k, v in pairs(DEFAULT) do Cfg[k] = v end

pcall(function()
    if isfile and isfile(CFG_FILE) then
        local d = HttpService:JSONDecode(readfile(CFG_FILE))
        for k, v in pairs(d) do if DEFAULT[k] ~= nil then Cfg[k] = v end end
    end
end)
Cfg.AutoHop = true -- SEMPRE ligado ao executar

local lastSave = 0
local function Save()
    if not writefile then return end
    if os.clock() - lastSave < 0.5 then return end
    lastSave = os.clock()
    pcall(function()
        if not isfolder(FOLDER) then makefolder(FOLDER) end
        writefile(CFG_FILE, HttpService:JSONEncode(Cfg))
    end)
end

----------------------------------------------------------------
-- QUEUE ON TELEPORT (recarrega o script depois do hop)
----------------------------------------------------------------
pcall(function()
    local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if not q then return end
    local boot
    if SCRIPT_URL ~= "" then
        boot = 'loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()'
    else
        boot = 'loadstring(readfile("' .. FOLDER .. '/main.lua"))()'
    end
    q('repeat task.wait() until game:IsLoaded() task.wait(2) ' .. boot)
end)

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local function Sea()
    local p = game.PlaceId
    if p == 2753915549 or p == 85211729168715 then return 1 end
    if p == 4442272183 or p == 79091703265657 then return 2 end
    if p == 7449423635 or p == 100117331123089 then return 3 end
    return 0
end

local function HRP() local c = LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum() local c = LP.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function Alive() local h = Hum() return h and h.Health > 0 and HRP() ~= nil end

local function MobAlive(m)
    if not (m and m.Parent) then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0 and m:FindFirstChild("HumanoidRootPart") ~= nil
end

local function Has(name)
    return (LP.Character and LP.Character:FindFirstChild(name)) or (LP.Backpack and LP.Backpack:FindFirstChild(name)) or nil
end

local function StopItems()
    return Cfg.StopIfItem and (Has("Fist of Darkness") or Has("God's Chalice") or Has("Sweet Chalice")) and true or false
end

local function Uptime() return workspace.DistributedGameTime end
local function Fmt(s)
    s = math.floor(s)
    return ("%dh %02dm %02ds"):format(math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60)
end

local unlockCache, unlockT = {}, 0
local function IsUnlocked(flag)
    if unlockCache[flag] then return true end
    if os.clock() - unlockT < 15 then return false end
    unlockT = os.clock()
    local ok, r = pcall(function() return CommF:InvokeServer("GetUnlockables") end)
    if ok and type(r) == "table" and r[flag] then unlockCache[flag] = true end
    return unlockCache[flag] == true
end

local State = { status = "Iniciando...", task = "-", idleLeft = nil, chests = 0, hopReason = "" }

----------------------------------------------------------------
-- TEAM
----------------------------------------------------------------
task.spawn(function()
    if Cfg.AutoTeam then
        task.wait(2)
        if not LP.Team then
            pcall(function() CommF:InvokeServer("SetTeam", Cfg.Team) end)
        end
    end
end)

----------------------------------------------------------------
-- TWEEN + NOCLIP + ENTRANCES
----------------------------------------------------------------
local Tw = { t = nil, goal = nil, bv = nil, noclipUntil = 0 }

local function TwStop()
    if Tw.t then pcall(function() Tw.t:Cancel() end) Tw.t = nil end
    Tw.goal = nil
    if Tw.bv then pcall(function() Tw.bv:Destroy() end) Tw.bv = nil end
end

RunService.Stepped:Connect(function()
    if os.clock() < Tw.noclipUntil and LP.Character then
        for _, p in ipairs(LP.Character:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
end)

local V3 = Vector3.new
local ENTR = {
    [1] = { { p = V3(-7894.62, 5545.49, -380.25) }, { p = V3(-4607.82, 872.54, -1667.56) },
            { p = V3(61163.85, 11.76, 1819.78) },  { p = V3(3876.28, 35.11, -1939.32) } },
    [2] = { { p = V3(-288.46, 306.13, 597.99), need = "FlamingoAccess" },
            { p = V3(2284.91, 15.15, 905.48), need = "FlamingoAccess" },
            { p = V3(923.21, 126.98, 32852.83) }, { p = V3(-6508.56, 89.03, -132.84) } },
    [3] = { { p = V3(-4967.68, 314.88, -3157.10), need = "DefeatedIndraTrueForm" },
            { p = V3(5661.53, 1013.41, -334.96),  need = "DefeatedIndraTrueForm" },
            { p = V3(-12463.87, 374.91, -7523.77), need = "DefeatedIndraTrueForm" } },
}
local lastEntr = 0
local function TryEntrance(pos, dist)
    if dist < 3000 or os.clock() - lastEntr < 2 then return false end
    local best, bd
    for _, e in ipairs(ENTR[Sea()] or {}) do
        local d = (e.p - pos).Magnitude
        if d <= 3000 and (not bd or d < bd) and (not e.need or IsUnlocked(e.need)) then best, bd = e, d end
    end
    if not best then return false end
    lastEntr = os.clock()
    TwStop()
    pcall(function() CommF:InvokeServer("requestEntrance", best.p) end)
    return true
end

local function GoTo(cf, speed)
    local hrp, hum = HRP(), Hum()
    if not hrp or not hum then return end
    if hum.Sit then hum.Jump = true return end
    Tw.noclipUntil = os.clock() + 0.6
    local dist = (hrp.Position - cf.Position).Magnitude
    if dist < 5 then TwStop() hrp.CFrame = cf return end
    if TryEntrance(cf.Position, dist) then return end
    if Tw.t and Tw.goal and (Tw.goal.Position - cf.Position).Magnitude < 12 then return end
    TwStop()
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = V3(1e5, 1e5, 1e5) bv.Velocity = V3() bv.Parent = hrp
    Tw.bv = bv
    local t = TweenService:Create(hrp,
        TweenInfo.new(dist / math.max(speed or Cfg.TweenSpeed, 20), Enum.EasingStyle.Linear), { CFrame = cf })
    Tw.t, Tw.goal = t, cf
    t.Completed:Connect(function() if Tw.t == t then Tw.t, Tw.goal = nil, nil end end)
    t:Play()
end

----------------------------------------------------------------
-- COMBATE
----------------------------------------------------------------
local Combat = { untilT = 0 }
local atkKey = tostring(LP.UserId):sub(2, 4) .. "078da"
local RegAtk, RegHit
pcall(function()
    RegAtk = Net:WaitForChild("RE/RegisterAttack", 5)
    RegHit = Net:WaitForChild("RE/RegisterHit", 5)
end)

local function EquipTip(tip)
    local c = LP.Character
    if not c then return end
    local cur = c:FindFirstChildOfClass("Tool")
    if cur and cur.ToolTip == tip then return end
    for _, t in ipairs(LP.Backpack:GetChildren()) do
        if t:IsA("Tool") and t.ToolTip == tip then Hum():EquipTool(t) return end
    end
end
local function EquipName(name)
    local t = LP.Backpack:FindFirstChild(name)
    if t and Hum() then Hum():EquipTool(t) end
end

local lastBuso = 0
local function Buso()
    if Cfg.AutoBuso and LP.Character and not LP.Character:FindFirstChild("HasBuso") and os.clock() - lastBuso > 3 then
        lastBuso = os.clock()
        task.spawn(function() pcall(function() CommF:InvokeServer("Buso") end) end)
    end
end

local fruitIdx = 0
local function FastAttackOnce()
    local c, hrp = LP.Character, HRP()
    if not c or not hrp then return end
    local tool = c:FindFirstChildOfClass("Tool")
    if not tool then return end
    local tip = tool.ToolTip
    if tip == "Gun" then return end
    if tip == "Blox Fruit" and tool:FindFirstChild("LeftClickRemote") then
        for _, m in ipairs(workspace.Enemies:GetChildren()) do
            if MobAlive(m) then
                local r = m.HumanoidRootPart
                if (r.Position - hrp.Position).Magnitude <= 50 then
                    fruitIdx = fruitIdx % 4 + 1
                    tool.LeftClickRemote:FireServer((r.Position - hrp.Position).Unit, fruitIdx)
                end
            end
        end
        return
    end
    if not (RegAtk and RegHit) then tool:Activate() return end
    local hits = {}
    for _, m in ipairs(workspace.Enemies:GetChildren()) do
        if MobAlive(m) and (m.HumanoidRootPart.Position - hrp.Position).Magnitude <= 60 then
            hits[#hits + 1] = { m, m:FindFirstChild("Head") or m.HumanoidRootPart }
        end
    end
    if #hits > 0 then
        RegAtk:FireServer(0)
        local first = table.remove(hits, 1)[2]
        RegHit:FireServer(first, hits, nil, atkKey)
    end
end

task.spawn(function()
    while true do
        task.wait(math.max(Cfg.AttackDelay or 0, 0))
        if os.clock() < Combat.untilT and Alive() then
            if Cfg.FastAttack then pcall(FastAttackOnce)
            else
                local t = LP.Character:FindFirstChildOfClass("Tool")
                if t then pcall(function() t:Activate() end) end
            end
        end
    end
end)

-- Auto Ken
task.spawn(function()
    while true do
        task.wait(2)
        if Cfg.AutoKen and Alive() then
            pcall(function()
                if Lighting:FindFirstChild("Blur") and not Lighting.Blur.Enabled then
                    VIM:SendKeyEvent(true, "E", false, game)
                    task.wait()
                    VIM:SendKeyEvent(false, "E", false, game)
                end
            end)
        end
    end
end)

local function Bring(m)
    if not Cfg.BringMob then return end
    local r = m:FindFirstChild("HumanoidRootPart")
    if not r then return end
    pcall(function() sethiddenproperty(LP, "SimulationRadius", 1e9) end)
    for _, e in ipairs(workspace.Enemies:GetChildren()) do
        if e ~= m and e.Name == m.Name and MobAlive(e) then
            local er = e.HumanoidRootPart
            if (er.Position - r.Position).Magnitude <= Cfg.BringRadius then
                er.CFrame = r.CFrame
                er.CanCollide = false
            end
        end
    end
end

local function Engage(m, isMob)
    if not MobAlive(m) then return end
    EquipTip(Cfg.WeaponTool)
    Buso()
    Combat.untilT = os.clock() + 0.4
    if isMob then Bring(m) end
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
    end
    GoTo(m.HumanoidRootPart.CFrame * CFrame.new(0, Cfg.FarmDistance, 0))
end

local function FindBoss(names)
    if type(names) == "string" then names = { names } end
    for _, parent in ipairs({ RS, workspace.Enemies }) do
        for _, c in ipairs(parent:GetChildren()) do
            if table.find(names, c.Name) and MobAlive(c) then return c end
        end
    end
end

local function NearestMob(names)
    local hrp, best, bd = HRP(), nil, math.huge
    for _, m in ipairs(workspace.Enemies:GetChildren()) do
        if table.find(names, m.Name) and MobAlive(m) then
            local d = (m.HumanoidRootPart.Position - hrp.Position).Magnitude
            if d < bd then best, bd = m, d end
        end
    end
    return best
end

local function FarmMobs(names, fallback)
    local m = NearestMob(names)
    if m then Engage(m, true) else GoTo(fallback) end
end

----------------------------------------------------------------
-- STEP: FRUTAS
----------------------------------------------------------------
local fruitIgnored = setmetatable({}, { __mode = "k" })
local function FindFruit()
    for _, c in ipairs(workspace:GetChildren()) do
        if (c:IsA("Tool") or c:IsA("Model")) and c.Name:find("Fruit") and c:FindFirstChild("Handle") and not fruitIgnored[c] then
            return c
        end
    end
end
local curFruit, fruitStart = nil, 0

local function FruitStep()
    if not Cfg.AutoCollectFruit then return false end
    local f = curFruit and curFruit.Parent and curFruit or FindFruit()
    if not f or fruitIgnored[f] then curFruit = nil return false end
    if f ~= curFruit then curFruit, fruitStart = f, os.clock() end
    if os.clock() - fruitStart > 15 then fruitIgnored[f] = true curFruit = nil return true end
    State.status = "Coletando fruta: " .. f.Name
    local h = f.Handle
    if (HRP().Position - h.Position).Magnitude < 6 then
        pcall(function() firetouchinterest(HRP(), h, 0) firetouchinterest(HRP(), h, 1) end)
        Hum().Jump = true
    end
    GoTo(h.CFrame)
    return true
end

local stored = setmetatable({}, { __mode = "k" })
task.spawn(function()
    while true do
        task.wait(1.5)
        if Cfg.AutoStoreFruit then
            for _, cont in ipairs({ LP.Backpack, LP.Character }) do
                if cont then
                    for _, t in ipairs(cont:GetChildren()) do
                        if t:IsA("Tool") and t.Name:find("Fruit") and not stored[t] then
                            stored[t] = true
                            local base = (t.Name:gsub(" Fruit", ""))
                            local nm = t:GetAttribute("OriginalName") or (base .. "-" .. base)
                            pcall(function() CommF:InvokeServer("StoreFruit", nm, t) end)
                            task.wait(0.5)
                        end
                    end
                end
            end
        end
    end
end)

----------------------------------------------------------------
-- STEP: BOSSES / ITENS
----------------------------------------------------------------
local function BossOrNil(names, label)
    local b = FindBoss(names)
    if b then State.status = "Matando " .. label end
    return b
end

-- Dark Beard (Sea 2)
local function DarkbeardStep()
    if not Cfg.AutoDarkbeard or Sea() ~= 2 then return false end
    local b = BossOrNil("Darkbeard", "Darkbeard")
    if b then Engage(b, false) return true end
    if Has("Fist of Darkness") then
        local ok, det = pcall(function() return workspace.Map.DarkbeardArena.Summoner.Detection end)
        if ok and det then
            State.status = "Invocando Darkbeard"
            if (HRP().Position - det.Position).Magnitude <= 5 then
                EquipName("Fist of Darkness")
                local tool = LP.Character:FindFirstChild("Fist of Darkness")
                for _, other in ipairs({ tool and tool:FindFirstChild("Handle"), HRP() }) do
                    if other then
                        pcall(function() firetouchinterest(other, det, 0) firetouchinterest(other, det, 1) end)
                    end
                end
            else
                GoTo(det.CFrame)
            end
            return true
        end
    end
    return false
end

-- Rip Indra (Sea 3)
local function DetectButtons()
    local ok, r = pcall(function()
        for _, h in ipairs(workspace.Map["Boat Castle"].Summoner.Circle:GetChildren()) do
            if h:IsA("Part") and h:FindFirstChild("Part") and h.Part.BrickColor.Name ~= "Lime green" then return h end
        end
    end)
    return ok and r or nil
end
local function TouchPadHaki(btn)
    local map = { ["Hot pink"] = "Winter Sky", ["Really red"] = "Pure Red", ["Oyster"] = "Snow White" }
    local color = map[btn.BrickColor.Name]
    if color then
        pcall(function()
            Net:FindFirstChild("RF/FruitCustomizerRF"):InvokeServer({ StorageName = color, Type = "AuraSkin", Context = "Equip" })
            if color ~= "Winter Sky" then CommF:InvokeServer("activateColor", color) end
        end)
    end
    GoTo(btn.CFrame)
    task.wait(0.5)
end
local function IndraStep()
    if not Cfg.AutoRipIndra or Sea() ~= 3 then return false end
    local b = BossOrNil("rip_indra True Form", "Rip Indra")
    if b then Engage(b, false) return true end
    if Has("God's Chalice") then
        State.status = "Rip Indra: preparando altar"
        local castle = workspace.Map:FindFirstChild("Boat Castle")
        local circle = castle and castle:FindFirstChild("Summoner") and castle.Summoner:FindFirstChild("Circle")
        if not circle or not circle:FindFirstChildOfClass("Part") then
            GoTo(CFrame.new(-5500, 314, -2855))
            return true
        end
        local btn = DetectButtons()
        if btn then TouchPadHaki(btn) return true end
        EquipName("God's Chalice")
        GoTo(castle.Summoner.Detection.CFrame)
        return true
    end
    return false
end

-- Tushita (Sea 3)
local lastTorch = 0
local function TushitaStep()
    if not Cfg.AutoTushita or Sea() ~= 3 then return false end
    local ok, prog = pcall(function() return CommF:InvokeServer("TushitaProgress") end)
    if not ok or type(prog) ~= "table" then return false end
    if prog.OpenedDoor then
        local b = BossOrNil("Longma", "Longma (Tushita)")
        if b then Engage(b, false) return true end
        return false
    end
    local hit
    pcall(function()
        hit = workspace.Map.Waterfall.IslandModel:FindFirstChild("Hitbox", true)
    end)
    State.status = "Tushita: tochas"
    if not hit then GoTo(CFrame.new(5677.54, 28.53, 357.95)) return true end
    if hit:FindFirstChild("TouchInterest") then
        if not Has("Holy Torch") then
            GoTo(hit.CFrame)
        else
            EquipName("Holy Torch")
            if os.clock() - lastTorch > 5 then
                lastTorch = os.clock()
                for i = 1, 5 do pcall(function() CommF:InvokeServer("TushitaProgress", "Torch", i) end) end
            end
        end
        return true
    end
    return false -- Rip Indra ainda nao foi derrotado/spawnado
end

-- Dough King (Sea 3)
local CAKE_MOBS = { "Baking Staff", "Head Baker", "Cake Guard", "Cookie Crafter" }
local COCOA_MOBS = { "Chocolate Bar Battler", "Cocoa Warrior" }
local lastChalice = 0
local function DoughStep()
    if not Cfg.AutoDoughKing or Sea() ~= 3 then return false end
    local b = FindBoss({ "Dough King", "Cake Prince" })
    if b then
        State.status = "Matando " .. b.Name
        local mirror = Vector3.new(-1990.67, 4532.97, -14973.67)
        local hrp = HRP()
        if (mirror - b.HumanoidRootPart.Position).Magnitude <= 1000 and (mirror - hrp.Position).Magnitude > 1000 then
            local ok, main = pcall(function() return workspace.Map.CakeLoaf.BigMirror.Main end)
            if ok and main then GoTo(main.CFrame) return true end
        end
        Engage(b, false)
        return true
    end
    if Has("God's Chalice") and not Cfg.AutoRipIndra and os.clock() - lastChalice > 3 then
        lastChalice = os.clock()
        local ok, r = pcall(function() return CommF:InvokeServer("SweetChaliceNpc") end)
        if ok and type(r) == "string" and r:find("Where") then
            State.status = "Dough King: farmando Cocoa"
            FarmMobs(COCOA_MOBS, CFrame.new(400, 81, -12257))
            return true
        end
    end
    if Has("Sweet Chalice") then
        local ok, r = pcall(function() return CommF:InvokeServer("CakePrinceSpawner", true) end)
        if ok and type(r) == "string" and r:find("open the portal now") then
            pcall(function() CommF:InvokeServer("CakePrinceSpawner") end)
            task.wait(1)
        end
        State.status = "Dough King: farmando mobs do bolo"
        FarmMobs(CAKE_MOBS, CFrame.new(-2072.15, 70.13, -12097.08))
        return true
    end
    return false
end

----------------------------------------------------------------
-- STEP: CHESTS
----------------------------------------------------------------
local chestIgnored = setmetatable({}, { __mode = "k" })
local curChest, chestStart, chestReached = nil, 0, false
local spawnVisited = {}

local function ChestDone(c)
    return not c.Parent or c:GetAttribute("IsDisabled") or not c:FindFirstChild("TouchInterest")
end
local function NearestChest()
    local hrp, best, bd = HRP(), nil, math.huge
    for _, c in ipairs(CollectionSvc:GetTagged("_ChestTagged")) do
        if not chestIgnored[c] and not ChestDone(c) then
            local d = (c:GetPivot().Position - hrp.Position).Magnitude
            if d < bd then best, bd = c, d end
        end
    end
    return best
end
local function NextSpawn()
    local hrp, best, bd = HRP(), nil, math.huge
    local ok, folder = pcall(function() return workspace._WorldOrigin.PlayerSpawns.Pirates end)
    if not ok or not folder then return nil end
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and not spawnVisited[m] then
            local p = m:FindFirstChild("Part")
            if p then
                local d = (p.Position - hrp.Position).Magnitude
                if d < bd then best, bd = p, d end
            end
        end
    end
    return best
end

local function ChestStep()
    if not Cfg.AutoChest or StopItems() then return false end
    if State.chests >= Cfg.ChestNumber then return false end
    -- servidor novo demais para o modo 4h: nao perde tempo com bau
    if Cfg.Hop4h and Cfg.AutoHop and Uptime() < 14400 and (Cfg.AutoChestHop or Cfg.AutoHopFruit) then return false end

    if curChest and ChestDone(curChest) then
        if chestReached then State.chests += 1 end
        chestIgnored[curChest] = true
        curChest, chestReached = nil, false
    end
    local c = curChest or NearestChest()
    if c then
        if c ~= curChest then curChest, chestStart, chestReached = c, os.clock(), false end
        if os.clock() - chestStart > 8 then chestIgnored[c] = true curChest = nil return true end
        State.status = ("Coletando bau (%d/%d)"):format(State.chests, Cfg.ChestNumber)
        local hrp = HRP()
        if (hrp.Position - c:GetPivot().Position).Magnitude < 8 then
            chestReached = true
            pcall(function() firetouchinterest(hrp, c, 0) firetouchinterest(hrp, c, 1) end)
        end
        GoTo(c:GetPivot())
        return true
    end
    -- sem bau carregado: percorre spawns para dar stream
    local sp = NextSpawn()
    if sp then
        State.status = "Procurando baus..."
        GoTo(sp.CFrame * CFrame.new(0, 40, 0))
        if (HRP().Position - sp.Position).Magnitude < 100 then spawnVisited[sp.Parent] = true end
        return true
    end
    return false -- esgotou: ocioso -> hop
end

----------------------------------------------------------------
-- HOP
----------------------------------------------------------------
local VISITED_FILE = FOLDER .. "/visited.json"
local visited = {}
pcall(function()
    if isfile and isfile(VISITED_FILE) then
        local d = HttpService:JSONDecode(readfile(VISITED_FILE))
        for id, t in pairs(d) do if os.time() - t < 7200 then visited[id] = t end end
    end
end)
visited[game.JobId] = os.time()
local function SaveVisited()
    pcall(function()
        if not isfolder(FOLDER) then makefolder(FOLDER) end
        writefile(VISITED_FILE, HttpService:JSONEncode(visited))
    end)
end

local function AgeOf(info)
    for _, k in ipairs({ "Age", "Uptime", "ServerAge", "Time", "Created" }) do
        local v = info[k]
        if type(v) == "number" then return v end
    end
end

local function PickServer()
    local cands, maxP = {}, Players.MaxPlayers
    pcall(function()
        for page = 1, 4 do
            local r = RS:FindFirstChild("__ServerBrowser"):InvokeServer(page)
            if type(r) ~= "table" then break end
            for id, info in pairs(r) do
                if type(id) == "string" and id ~= game.JobId and not visited[id] and type(info) == "table" then
                    local cnt = info.Count or info.playing or 0
                    if cnt < maxP - 1 then cands[#cands + 1] = { id = id, age = AgeOf(info) } end
                end
            end
        end
    end)
    if #cands == 0 then
        pcall(function()
            local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
            local r = HttpService:JSONDecode(game:HttpGet(url))
            for _, s in ipairs(r.data or {}) do
                if s.id ~= game.JobId and not visited[s.id] and s.playing < s.maxPlayers - 1 then
                    cands[#cands + 1] = { id = s.id }
                end
            end
        end)
    end
    if #cands == 0 then return nil end
    if Cfg.Hop4h then
        local old = {}
        for _, c in ipairs(cands) do if c.age and c.age >= 14400 then old[#old + 1] = c end end
        if #old > 0 then cands = old end
    end
    return cands[math.random(1, #cands)].id
end

local Hopping = false
TeleportSvc.TeleportInitFailed:Connect(function() Hopping = false end)

local function DoHop()
    if Hopping then return end
    Hopping = true
    task.spawn(function()
        State.status = "Procurando servidor..."
        local id = PickServer()
        if not id then
            State.status = "Nenhum servidor encontrado, tentando de novo"
            task.wait(5) Hopping = false return
        end
        visited[id] = os.time()
        SaveVisited()
        State.status = "Teleportando para " .. id:sub(1, 8) .. "..."
        pcall(function() getgenv().HopHubNotify("Hop", "Indo para JobId:\n" .. id, 5) end)
        local ok = pcall(function() TeleportSvc:TeleportToPlaceInstance(game.PlaceId, id, LP) end)
        if not ok then Hopping = false end
        task.wait(25)
        Hopping = false
    end)
end

local function HopEligible()
    if not Cfg.AutoHop then return false, "Auto Hop desligado" end
    if StopItems() then return false, "Item obtido (parado)" end
    local fruitNow = FindFruit()
    local chestHop = Cfg.AutoChestHop
    local fruitHop = Cfg.AutoHopFruit and not fruitNow
    if chestHop or fruitHop then return true end
    return false, "Nenhum toggle de hop ligado (ChestHop / HopFruit)"
end

----------------------------------------------------------------
-- ORQUESTRADOR (ordem: frutas > bosses/itens > baus > hop)
----------------------------------------------------------------
local STEPS = {
    { "Fruta", FruitStep }, { "Darkbeard", DarkbeardStep }, { "Rip Indra", IndraStep },
    { "Tushita", TushitaStep }, { "Dough King", DoughStep }, { "Chest", ChestStep },
}
local idleSince

task.spawn(function()
    while true do
        task.wait()
        if not Alive() then
            TwStop() State.status = "Aguardando respawn" idleSince = nil
        else
            local busy = false
            for _, s in ipairs(STEPS) do
                local ok, res = pcall(s[2])
                if not ok then warn("[HopHub] " .. s[1] .. ": " .. tostring(res)) end
                if ok and res then busy = true State.task = s[1] break end
            end
            if busy then
                idleSince, State.idleLeft = nil, nil
            else
                TwStop()
                State.task = "Ocioso"
                idleSince = idleSince or os.clock()
                local left = HOP_DELAY - (os.clock() - idleSince)
                local ok, why = HopEligible()
                if ok then
                    State.idleLeft = math.max(left, 0)
                    State.status = ("Hop em %.1fs"):format(math.max(left, 0))
                    if left <= 0 then DoHop() end
                else
                    State.idleLeft = nil
                    State.status = "Parado: " .. why
                end
            end
        end
    end
end)

----------------------------------------------------------------
-- UI (WindUI)
----------------------------------------------------------------
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local function Notify(title, content, dur)
    pcall(function() WindUI:Notify({ Title = title, Content = content, Duration = dur or 8, Icon = "server" }) end)
end
getgenv().HopHubNotify = Notify

local function ServerInfoText()
    return ("JobId: %s\nPlayers: %d/%d\nTempo ativo: %s"):format(
        game.JobId, #Players:GetPlayers(), Players.MaxPlayers, Fmt(Uptime()))
end

local Window = WindUI:CreateWindow({
    Title = "Hop Hub", Icon = "zap", Author = "Blox Fruits", Folder = FOLDER,
    Size = UDim2.fromOffset(580, 460), Theme = "Dark",
})

local TabHop    = Window:Tab({ Title = "HOP", Icon = "repeat" })
local TabCfg    = Window:Tab({ Title = "Config", Icon = "settings" })
local TabChest  = Window:Tab({ Title = "ChestHop/ChestBoss", Icon = "package" })
local TabFruit  = Window:Tab({ Title = "Auto Collect Fruit Hop", Icon = "apple" })

local Reg = {}
local function Tog(tab, key, title, desc)
    local el = tab:Toggle({
        Title = title, Desc = desc, Default = Cfg[key], Value = Cfg[key],
        Callback = function(v) Cfg[key] = v Save() end,
    })
    Reg[key] = el
    return el
end
local function Sld(tab, key, title, desc, min, max, step)
    tab:Slider({
        Title = title, Desc = desc, Step = step or 1,
        Value = { Min = min, Max = max, Default = Cfg[key] },
        Callback = function(v) Cfg[key] = tonumber(v) or Cfg[key] Save() end,
    })
end
local function Drop(tab, key, title, values)
    tab:Dropdown({
        Title = title, Values = values, Value = Cfg[key],
        Callback = function(v) Cfg[key] = v Save() end,
    })
end

-- TAB HOP
Tog(TabHop, "AutoHop", "Auto Hop (recomendo)", "Controla a ordem de tudo e da o hop. Sempre ligado ao executar.")
local StatusP = TabHop:Paragraph({ Title = "Status", Desc = "Iniciando..." })
TabHop:Button({
    Title = "Stop Hop (tudo)", Desc = "Desliga todos os toggles, menos o Auto Hop",
    Callback = function()
        for k, el in pairs(Reg) do
            if k ~= "AutoHop" then
                Cfg[k] = false
                pcall(function() el:Set(false) end)
            end
        end
        Save()
        Notify("Hop Hub", "Todos os toggles desligados (Auto Hop mantido).", 4)
    end,
})

-- TAB CONFIG
Drop(TabCfg, "WeaponTool", "Weapon Tool", { "Melee", "Sword", "Blox Fruit", "Gun" })
Sld(TabCfg, "TweenSpeed", "Tween Speed", "Velocidade de movimento", 50, 1000)
Sld(TabCfg, "FarmDistance", "Farm Distance", "Altura acima do inimigo", 5, 60)
Tog(TabCfg, "FastAttack", "Fast Attack", "Ataque rapido")
Sld(TabCfg, "AttackDelay", "Attack Delay", "Segundos entre ataques (0 = mais rapido)", 0, 0.5, 0.01)
Tog(TabCfg, "BringMob", "Bring Mob", "Puxa inimigos iguais")
Sld(TabCfg, "BringRadius", "Bring Radius", "Raio do bring", 100, 500)
Tog(TabCfg, "AutoBuso", "Auto Buso Haki", "Ativa Buso sozinho")
Tog(TabCfg, "AutoKen", "Auto Ken", "Ativa Observation sozinho")
Tog(TabCfg, "AutoTeam", "Auto Join Team", "Entra no time ao carregar")
Drop(TabCfg, "Team", "Team", { "Pirates", "Marines" })

-- TAB CHEST
Tog(TabChest, "AutoChest", "Auto Chest", "Coleta baus automaticamente")
Sld(TabChest, "ChestNumber", "Chests number", "Baus antes de dar hop (1-355)", 1, 355)
Tog(TabChest, "AutoChestHop", "Auto Chest Hop Server", "Troca para servidor aleatorio (mesmo PlaceId) apos coletar")
Tog(TabChest, "StopIfItem", "Stop if have Fist of Darkness / God's Chalice / Sweet Chalice",
    "Para o chest e o hop quando pegar um desses itens")
Tog(TabChest, "Hop4h", "Hop 4 Hours Servers", "Prefere servidores com 4h+ abertos")
Tog(TabChest, "AutoDarkbeard", "Auto Kill Dark Beard", "Sea 2: invoca (Fist of Darkness) e mata")
Tog(TabChest, "AutoRipIndra", "Auto Rip Indra", "Sea 3: cores de Haki + God's Chalice + mata")
Tog(TabChest, "AutoTushita", "Auto Tushita", "Sea 3: tochas e Longma")
Tog(TabChest, "AutoDoughKing", "Auto Farm Dough King", "Sea 3: Sweet Chalice, mobs do bolo e boss")

-- TAB FRUIT
Tog(TabFruit, "AutoCollectFruit", "Auto Coletar Fruta", "Vai ate frutas no chao")
Tog(TabFruit, "AutoStoreFruit", "Auto Guardar Fruta", "Guarda no inventario")
Tog(TabFruit, "AutoHopFruit", "Auto Hop Fruit", "Troca de servidor se nao houver fruta no mapa")

pcall(function() Window:SelectTab(1) end)

-- Status ao vivo
task.spawn(function()
    while true do
        task.wait(0.5)
        local lines = {
            "Acao: " .. State.status,
            "Tarefa: " .. State.task,
            ("Baus: %d/%d"):format(State.chests, Cfg.ChestNumber),
            "Servidor ativo ha: " .. Fmt(Uptime()),
            ("Players: %d/%d"):format(#Players:GetPlayers(), Players.MaxPlayers),
            "JobId: " .. game.JobId,
        }
        if State.idleLeft then lines[#lines + 1] = ("Hop em: %.1fs"):format(State.idleLeft) end
        local txt = table.concat(lines, "\n")
        pcall(function() StatusP:SetDesc(txt) end)
    end
end)

Notify("Servidor atual", ServerInfoText(), 10)
