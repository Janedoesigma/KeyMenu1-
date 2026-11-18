--==============================================================
-- W-AZURE V3 | ONE-CLICK KAITUN (Fluent)  -- PARTE 1
--==============================================================
local SCRIPT_URL  = ""              -- raw deste script (reload apos teleporte entre seas). Ou use autoexec.
local SECRET_URL  = ""              -- raw do script Secret Quest (opcional)
local SECRET_FILE = "SecretQuest.lua" -- ou salve o script na pasta workspace com esse nome

repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer
local cloneref = cloneref or function(x) return x end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local VIM = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer
local CommF = RS:WaitForChild("Remotes"):WaitForChild("CommF_")
local CommE = RS.Remotes:WaitForChild("CommE")
local StartTick = os.time()

if SCRIPT_URL ~= "" then
    local q = queue_on_teleport or (syn and syn.queue_on_teleport)
    if q then pcall(q, ('loadstring(game:HttpGet("%s"))()'):format(SCRIPT_URL)) end
end

--==============================================================
-- UI (Fluent)
--==============================================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "W-AZURE V3", SubTitle = "ONE-CLICK Kaitun",
    TabWidth = 160, Size = UDim2.fromOffset(600, 470),
    Acrylic = false, Theme = "Dark", MinimizeKey = Enum.KeyCode.RightControl
})
local Tabs = {
    Main = Window:AddTab({ Title = "ONE-CLICK", Icon = "play" }),
    Webhook = Window:AddTab({ Title = "Webhook", Icon = "send" }),
    Config = Window:AddTab({ Title = "Config", Icon = "sliders-horizontal" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}
local Options = Fluent.Options

local StatusP = Tabs.Main:AddParagraph({ Title = "Status", Content = "Farm Principal: -\nSub Farm: -" })
local ItemsP  = Tabs.Main:AddParagraph({ Title = "Itens da conta", Content = "carregando..." })
Tabs.Main:AddToggle("StartOneClick", { Title = "Start One-Click", Description = "Liga/desliga o kaitun completo", Default = false })
Tabs.Main:AddToggle("AutoSecret", { Title = "Auto Secret Quest", Description = "Ativa sozinho quando os itens obrigatorios estiverem prontos", Default = true })
local SecretP = Tabs.Main:AddParagraph({ Title = "Secret Quest", Content = "Aguardando kaitun principal terminar..." })

-- Webhook
Tabs.Webhook:AddToggle("WebhookOn", { Title = "Send Webhook Status", Default = false })
Tabs.Webhook:AddInput("WebhookUrl", { Title = "Link do Webhook", Default = "", Placeholder = "https://discord.com/api/webhooks/...", Finished = true })
Tabs.Webhook:AddInput("WebhookMin", { Title = "Tempo (minutos)", Description = "1, 2, 10, 60 (=1 hora)...", Default = "10", Numeric = true, Finished = true })
Tabs.Webhook:AddButton({ Title = "Testar webhook agora", Callback = function() if _G.__WA_SendStatus then _G.__WA_SendStatus(true) end end })

-- Config
Tabs.Config:AddDropdown("Team", { Title = "Team", Values = { "Pirates", "Marines" }, Default = "Pirates" })
Tabs.Config:AddDropdown("Weapon", { Title = "Arma de farm", Values = { "Melee", "Sword" }, Default = "Melee" })
Tabs.Config:AddDropdown("Goals", {
    Title = "Itens do kaitun", Description = "O que o kaitun vai buscar",
    Values = { "Saber", "Godhuman", "Skull Guitar", "Race V2", "Race V3", "Bartilo" }, Multi = true,
    Default = { "Saber", "Godhuman", "Skull Guitar", "Race V2", "Race V3", "Bartilo" } })
Tabs.Config:AddDropdown("Required", {
    Title = "Obrigatorios p/ iniciar Secret Quest",
    Description = "Tire o que voce nao quer esperar (CDK entra na Parte 2)",
    Values = { "Saber", "Godhuman", "Skull Guitar", "Race V3", "Cursed Dual Katana", "Level Max" }, Multi = true,
    Default = { "Saber", "Godhuman", "Skull Guitar", "Race V3" } })
Tabs.Config:AddToggle("HopMoon", { Title = "Hop procurando lua cheia (Skull Guitar)", Default = true })
Tabs.Config:AddToggle("LowGfx", { Title = "Low Graphics", Default = true })
Tabs.Config:AddToggle("WhiteScreen", { Title = "White Screen (desliga render 3D)", Default = false })
Tabs.Config:AddSlider("FPS", { Title = "FPS cap", Default = 60, Min = 15, Max = 240, Rounding = 0 })

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("WAzureV3")
SaveManager:SetFolder("WAzureV3/OneClick")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)

local function SetP(p, t, d) pcall(function() p:SetTitle(t) end) pcall(function() p:SetDesc(d) end) end

--==============================================================
-- Estado / utilitarios
--==============================================================
local State = { Main = "Idle", Sub = "Idle" }
local function SetFarm(m, s) State.Main = m; if s then State.Sub = s end end
local function SetSub(s) State.Sub = s end
local function Running() return Options.StartOneClick and Options.StartOneClick.Value end
local function Goal(n) return Options.Goals and Options.Goals.Value[n] == true end

local _c = {}
local function Cache(k, s, f)
    local e = _c[k]
    if e and tick() - e.t < s then return e.v end
    local ok, v = pcall(f)
    _c[k] = { t = tick(), v = ok and v or nil }
    return ok and v or nil
end

local function SeaIdx()
    local p = game.PlaceId
    if p == 2753915549 or p == 85211729168715 then return 1 end
    if p == 4442272183 or p == 79091703265657 then return 2 end
    if p == 7449423635 or p == 100117331123089 then return 3 end
    return 0
end
local function Level() return LP.Data.Level.Value end
local function Beli() return LP.Data.Beli.Value end
local function Frags() return LP.Data.Fragments.Value end
local MaxLevel = (workspace:GetAttribute("LEVEL_CAP") or 2800)

local function Char()
    local c = LP.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if c and h and r and h.Health > 0 then return c, h, r end
end

local IRS, KEYS, MATCH
pcall(function()
    KEYS = require(RS.ItemReplicationService.KEYS)
    IRS = require(RS.ItemReplicationService)
    MATCH = require(RS.ItemConfig.Storage).match
end)

local function HasTool(n)
    local c = LP.Character
    return (c and c:FindFirstChild(n)) or LP.Backpack:FindFirstChild(n)
end
local function EquipTool(n)
    local _, h = Char()
    local t = HasTool(n)
    if h and t and t.Parent ~= LP.Character then pcall(function() h:EquipTool(t) end) end
end
local function CheckItem(name)
    if not IRS then return false end
    local ok, res = pcall(function()
        for _, v in IRS:GetItems(KEYS.QUANTITY) do
            local item = MATCH(v.ItemId)._ok
            local c = item.Display.Category
            if (c == "Sword" or c == "Gun" or c == "Accessory") and item.Index.StorageKey == name then return true end
        end
        return false
    end)
    return ok and res or false
end
local function InvNames()
    return Cache("inv", 5, function()
        local l = CommF:InvokeServer("getInventory")
        local n = {}
        if type(l) == "table" then for _, v in pairs(l) do if type(v) == "table" and v.Name then n[v.Name] = true end end end
        return n
    end) or {}
end
local function Has(name)
    if HasTool(name) then return true end
    if CheckItem(name) then return true end
    return InvNames()[name] == true
end
local function GetMaterial(name)
    if not IRS then return 0 end
    local ok, res = pcall(function()
        for _, v in IRS:GetItems(KEYS.QUANTITY) do
            local item = MATCH(v.ItemId)._ok
            if item.Display.Category == "Material" and item.Index.StorageKey == name then return v.Value end
        end
        return 0
    end)
    return ok and res or 0
end
local function GetFruitValue(minPrice)
    if not IRS then return nil end
    local ok, res = pcall(function()
        for _, v in IRS:GetItems(KEYS.QUANTITY) do
            local item = MATCH(v.ItemId)._ok
            if item.Display.Category == "Blox Fruit" and item.Quality.MoneyPrice >= minPrice then return item.Index.StorageKey end
        end
    end)
    return ok and res or nil
end
local function GetUseableFruit()
    if not IRS then return nil end
    local ok, res = pcall(function()
        for _, v in IRS:GetItems(KEYS.QUANTITY) do
            local item = MATCH(v.ItemId)._ok
            if item.Display.Category == "Blox Fruit" and item.Quality.MoneyPrice < 1000000 then return item.Index.StorageKey end
        end
    end)
    return ok and res or nil
end

-- Melee data (mastery)
local MeleeData = { BlackLeg = 0, Electro = 0, FishmanKarate = 0, SharkmanKarate = 0, DeathStep = 0, DragonClaw = 0,
    Superhuman = 0, ElectricClaw = 0, DragonTalon = 0, Godhuman = 0, SanguineArt = 0 }
local Name2Name = { ["Water Kung Fu"] = "FishmanKarate", ["Electric"] = "Electro", ["Dark Step"] = "BlackLeg", ["Dragon Breath"] = "DragonClaw" }
local function CheckMeleeMastery()
    Cache("mastery", 10, function()
        for _, v in IRS:GetItems(KEYS.MASTERY) do
            local m = MATCH(v.ItemId)
            local item = m and m._ok
            if item and item.Index and item.Display and item.Display.Category == "Fighting Style" then
                local n = item.Index.StorageKey
                local key = Name2Name[n] or n:gsub(" ", "")
                if MeleeData[key] ~= nil then MeleeData[key] = tonumber(v.Value) or MeleeData[key] end
            end
        end
        return true
    end)
end
local function MeleeHas(key) CheckMeleeMastery(); return (MeleeData[key] or 0) > 0 or HasTool(key == "Godhuman" and "Godhuman" or key) ~= nil end

local function GetRaceGrade()
    local race = LP.Data.Race
    if HasTool("Awakening") then return "V4" end
    for _, n in ipairs({ "Last Resort", "Agility", "Water Body", "Heavenly Blood", "Heightened Senses", "Energy Core", "Primordial Reign" }) do
        if HasTool(n) then return "V3" end
    end
    if race:FindFirstChild("Evolved") then return "V2" end
    return "V1"
end

--==============================================================
-- Movimento
--==============================================================
local PORTALS = {
    [1] = { Vector3.new(-7894.6, 5545.5, -380.2), Vector3.new(-4607.8, 872.5, -1667.6), Vector3.new(61163.85, 11.76, 1819.78), Vector3.new(3876.28, 35.1, -1939.3) },
    [2] = { Vector3.new(-288.5, 306.1, 598), Vector3.new(2284.9, 15.15, 905.5), Vector3.new(923.2, 127, 32852.8), Vector3.new(-6508.6, 89, -132.8) },
    [3] = { Vector3.new(-5058.8, 314.5, -3155.9), Vector3.new(-12463.9, 374.9, -7523.8), Vector3.new(5661.5, 1013, -335), Vector3.new(5319, 23, -93) },
}
local Move = { tw = nil, goal = nil, lastPortal = 0, lastTravel = 0 }
local function StopTween()
    if Move.tw then pcall(function() Move.tw:Cancel() end) end
    Move.tw = nil; Move.goal = nil
end
local function Goto(t, hover, snap)
    local c, h, r = Char()
    if not c then return false end
    local pos = typeof(t) == "CFrame" and t.Position or t
    pos = pos + Vector3.new(0, hover or 0, 0)
    h.Sit = false
    local d = (r.Position - pos).Magnitude
    if d <= 6 or (snap and d <= snap) then StopTween(); r.CFrame = CFrame.new(pos); return d <= 6 or true end
    if d > 600 and tick() - Move.lastPortal > 3 then
        local best, bd
        for _, p in ipairs(PORTALS[SeaIdx()] or {}) do
            local pd = (p - pos).Magnitude
            if pd < d - 300 and (not bd or pd < bd) then best, bd = p, pd end
        end
        if best then
            Move.lastPortal = tick(); StopTween()
            pcall(function() CommF:InvokeServer("requestEntrance", best) end)
            return false
        end
    end
    if Move.tw and Move.goal and (Move.goal - pos).Magnitude < 8 then return false end
    StopTween()
    Move.goal = pos
    local speed = d < 250 and 280 or d < 500 and 255 or d < 1000 and 235 or 200
    Move.tw = TweenService:Create(r, TweenInfo.new(d / speed, Enum.EasingStyle.Linear), { CFrame = CFrame.new(pos) })
    Move.tw:Play()
    return false
end
local function Near(pos, r) local _, _, root = Char(); return root and (root.Position - pos).Magnitude <= (r or 10) end
local function Travel(n)
    if SeaIdx() == n then return true end
    if tick() - Move.lastTravel > 6 then
        Move.lastTravel = tick()
        pcall(function() CommF:InvokeServer(n == 1 and "TravelMain" or n == 2 and "TravelDressrosa" or "TravelZou") end)
    end
    SetSub("Viajando para Sea " .. n)
    return false
end

RunService.Stepped:Connect(function()
    local c = LP.Character
    if not c then return end
    local r = c:FindFirstChild("HumanoidRootPart")
    if Running() then
        for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end
        if r and not r:FindFirstChild("KaitunFloat") then
            local bv = Instance.new("BodyVelocity")
            bv.Name = "KaitunFloat"; bv.MaxForce = Vector3.new(1e9, 1e9, 1e9); bv.Velocity = Vector3.zero; bv.Parent = r
        end
    elseif r and r:FindFirstChild("KaitunFloat") then
        r.KaitunFloat:Destroy()
    end
end)

--==============================================================
-- Combate
--==============================================================
local RE_Attack = RS.Modules.Net["RE/RegisterAttack"]
local RE_Hit = RS.Modules.Net["RE/RegisterHit"]
local capR, capId
for _, f in ipairs({ RS.Util, RS.Common, RS.Remotes, RS.Assets, RS.FX }) do
    for _, n in ipairs(f:GetChildren()) do
        if n:IsA("RemoteEvent") and n:GetAttribute("Id") then capR, capId = n, n:GetAttribute("Id") end
    end
    f.ChildAdded:Connect(function(n)
        if n:IsA("RemoteEvent") and n:GetAttribute("Id") then capR, capId = n, n:GetAttribute("Id") end
    end)
end

local WeaponOverride = nil
local function EquipWeapon()
    if WeaponOverride and HasTool(WeaponOverride) then EquipTool(WeaponOverride); return end
    local want = Options.Weapon and Options.Weapon.Value or "Melee"
    local c = LP.Character
    if not c then return end
    if not c:FindFirstChild("HasBuso") then pcall(function() CommF:InvokeServer("Buso") end) end
    local cur = c:FindFirstChildOfClass("Tool")
    if cur and cur.ToolTip == want then return end
    for _, v in ipairs(LP.Backpack:GetChildren()) do
        if v:IsA("Tool") and v.ToolTip == want then
            local _, h = Char()
            if h then h:EquipTool(v) end
            return
        end
    end
end
local function EquipMelee(name)
    if name and HasTool(name) then EquipTool(name) else EquipWeapon() end
end

local function Attack()
    local c = LP.Character
    if not c then return end
    local parts = {}
    for _, v in ipairs(workspace.Enemies:GetChildren()) do
        local hrp, hum = v:FindFirstChild("HumanoidRootPart"), v:FindFirstChild("Humanoid")
        if hrp and hum and hum.Health > 0 and LP:DistanceFromCharacter(hrp.Position) <= 35 then
            for _, p in ipairs(v:GetChildren()) do
                if p:IsA("BasePart") then parts[#parts + 1] = { v, p } end
            end
        end
    end
    if #parts == 0 then return end
    local tool = c:FindFirstChildOfClass("Tool")
    if not tool or (tool.ToolTip ~= "Melee" and tool.ToolTip ~= "Sword") then return end
    pcall(function()
        RE_Attack:FireServer()
        local head = parts[1][1]:FindFirstChild("Head") or parts[1][1].PrimaryPart
        RE_Hit:FireServer(head, parts, {}, tostring(LP.UserId):sub(2, 4) .. tostring(coroutine.running()):sub(11, 15))
        if capR and capId then
            cloneref(capR):FireServer(
                string.gsub("RE/RegisterHit", ".", function(ch)
                    return string.char(bit32.bxor(string.byte(ch), math.floor(workspace:GetServerTimeNow() / 10 % 10) + 1))
                end),
                bit32.bxor(capId + 909090, RS.Modules.Net.seed:InvokeServer() * 2), head, parts)
        end
    end)
end

local function BringMob(name)
    local _, _, r = Char()
    if not r then return end
    local list = {}
    for _, x in ipairs(workspace.Enemies:GetChildren()) do
        local h = x:FindFirstChildOfClass("Humanoid")
        if x.PrimaryPart and h and h.Health > 0 and (not name or x.Name == name) and (x.PrimaryPart.Position - r.Position).Magnitude <= 180 then
            list[#list + 1] = x
            if #list == 3 then break end
        end
    end
    if #list == 0 then return end
    local t = list[1].PrimaryPart.CFrame
    for _, x in ipairs(list) do
        if not isnetworkowner or isnetworkowner(x.PrimaryPart) then x.PrimaryPart.CFrame = t end
    end
end

local function FindMob(names)
    local _, _, r = Char()
    if not r then return end
    local best, bd
    for _, folder in ipairs({ workspace.Enemies, RS }) do
        for _, v in ipairs(folder:GetChildren()) do
            if v:IsA("Model") and table.find(names, v.Name) then
                local hum, hrp = v:FindFirstChildOfClass("Humanoid"), v:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    local d = (hrp.Position - r.Position).Magnitude
                    if not bd or d < bd then best, bd = v, d end
                end
            end
        end
    end
    return best
end
local function SpawnPos(names)
    local _, _, r = Char()
    if not r then return end
    local best, bd
    local folders = { RS:FindFirstChild("FortBuilderReplicatedSpawnPositionsFolder") }
    local wo = workspace:FindFirstChild("_WorldOrigin")
    if wo and wo:FindFirstChild("EnemySpawns") then table.insert(folders, wo.EnemySpawns) end
    for _, f in ipairs(folders) do
        for _, n in ipairs(f:GetChildren()) do
            if table.find(names, n.Name) then
                local p = n:GetPivot().Position
                local d = (p - r.Position).Magnitude
                if not bd or d < bd then best, bd = p, d end
            end
        end
    end
    return best
end
-- 1 tick de farm. retorna true se encontrou o mob.
local function Farm(names, hover, fallback)
    hover = hover or 22
    local mob = FindMob(names)
    local _, _, r = Char()
    if not r then return false end
    if mob then
        local hrp = mob:FindFirstChild("HumanoidRootPart")
        SetSub("Atacando " .. mob.Name)
        Goto(hrp.Position, hover, 200)
        if (r.Position - hrp.Position).Magnitude < 60 then
            EquipWeapon(); BringMob(mob.Name); Attack()
        end
        return true
    end
    local sp = SpawnPos(names) or fallback
    SetSub("Procurando " .. names[1])
    if sp then Goto(sp, 25) end
    return false
end

--==============================================================
-- Quests / Level farm
--==============================================================
local QuestData = require(RS.Quests)
local Q = { cur = "", name = "" }
RS.Remotes.QuestUpdate.OnClientEvent:Connect(function(a)
    if typeof(a) == "table" then
        for i in pairs(a.Progress or {}) do Q.cur = i; break end
        Q.name = a.InternalQuestName or ""
    else
        Q.cur = ""; Q.name = ""
    end
end)

local function PickQuest()
    local lv = Level()
    if lv >= 1450 and SeaIdx() == 2 then return "ForgottenQuest", 2 end
    if lv >= 700 and SeaIdx() == 1 then return "FountainQuest", 2 end
    local bestReq, bq, bid = -1, nil, nil
    for rnq, v in pairs(QuestData) do
        if not table.find({ "BartiloQuest", "Trainees", "MarineQuest", "CitizenQuest", "ImpelQuest" }, tostring(rnq)) then
            for ridq, ct in pairs(v) do
                if ct.LevelReq >= 0 and lv >= ct.LevelReq then
                    for _, taskValue in pairs(ct.Task) do
                        if taskValue > 1 and ct.LevelReq > bestReq then bestReq, bq, bid = ct.LevelReq, rnq, ridq end
                    end
                end
            end
        end
    end
    return bq, bid
end
local function QuestNpcPos(qn)
    local best, bd
    local ok, list = pcall(function() return require(RS.GuideModule).Data.NPCList end)
    if not ok then return end
    for _, v in pairs(list) do
        if typeof(v) == "table" and v.Position then
            for _, x in pairs(v) do
                if x == qn then
                    local d = LP:DistanceFromCharacter(v.Position)
                    if not bd or d < bd then best, bd = v.Position, d end
                end
            end
        end
    end
    return best
end

local lastQuestTry = 0
local function LevelFarm()
    local lv = Level()
    SetFarm("Level Farm", "Lv " .. lv)
    if lv >= MaxLevel then SetFarm("Level Max", "Concluido"); return end
    if lv >= 10 and lv < 70 and SeaIdx() == 1 then
        if not Farm({ "Shanda" }, 20) and not SpawnPos({ "Shanda" }) then Goto(Vector3.new(-7783, 5576, -519)) end
        return
    elseif lv >= 70 and lv < 120 and SeaIdx() == 1 then
        if not Farm({ "God's Guard" }, 25) and not SpawnPos({ "God's Guard" }) then Goto(Vector3.new(-4650, 872, -1775)) end
        return
    end
    local qn, qid = PickQuest()
    if not qn then return end
    if Q.name ~= "" and Q.name ~= qn then
        pcall(function() CommF:InvokeServer("AbandonQuest") end); return
    end
    if Q.cur == "" then
        local pos = QuestNpcPos(qn)
        SetSub("Pegando quest " .. qn)
        if pos then
            Goto(pos, 3)
            if LP:DistanceFromCharacter(pos) <= 15 and tick() - lastQuestTry > 0.8 then
                lastQuestTry = tick()
                pcall(function() CommF:InvokeServer("StartQuest", qn, qid) end)
            end
        end
        return
    end
    Farm({ Q.cur }, 20)
end

-- Pontos de status
task.spawn(function()
    while task.wait(2) do
        if Running() and LP.Data.Points.Value > 0 then
            pcall(function()
                local S = LP.Data.Stats
                local lv = Level()
                CommF:InvokeServer("AddPoint", "Melee", lv * 2 - S.Melee.Level.Value)
                CommF:InvokeServer("AddPoint", "Defense", lv - S.Defense.Level.Value)
                if S.Melee.Level.Value >= MaxLevel and S.Defense.Level.Value >= MaxLevel then
                    CommF:InvokeServer("AddPoint", "Sword", lv * 3 - MaxLevel * 2)
                end
            end)
        end
    end
end)

--==============================================================
-- Servidor / Hop
--==============================================================
local lastHop = 0
local function Hop()
    if tick() - lastHop < 20 then return end
    lastHop = tick()
    pcall(function()
        local servers
        for i = 1, 100 do
            local w = RS:WaitForChild("__ServerBrowser"):InvokeServer(i)
            if type(w) == "table" and next(w) then servers = w; break end
        end
        if not servers then return end
        local list = {}
        for id, d in pairs(servers) do if id ~= game.JobId then table.insert(list, { id, d.Count or 99 }) end end
        table.sort(list, function(a, b) return a[2] < b[2] end)
        local pick = list[math.random(1, math.min(10, #list))]
        if pick then RS.__ServerBrowser:InvokeServer("teleport", pick[1]) end
    end)
end

--==============================================================
-- Materiais
--==============================================================
local MAT = {
    [2] = {
        ["Magma Ore"] = { { "Magma Ninja", "Lava Pirate" }, Vector3.new(-5428, 78, -5959) },
        ["Ectoplasm"] = { { "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer" }, Vector3.new(911, 126, 33159) },
        ["Mystic Droplet"] = { { "Water Fighter" }, Vector3.new(-3385, 239, -10542) },
    },
    [3] = {
        ["Fish Tail"] = { { "Fishman Raider", "Fishman Captain" }, Vector3.new(-10993, 332, -8940) },
        ["Dragon Scale"] = { { "Dragon Crew Warrior", "Dragon Crew Archer" }, Vector3.new(6594, 383, 139) },
    },
}
local MAT_SEA = { ["Magma Ore"] = 2, ["Ectoplasm"] = 2, ["Mystic Droplet"] = 2, ["Fish Tail"] = 3, ["Dragon Scale"] = 3 }
local function FarmMaterial(name)
    local sea = MAT_SEA[name]
    if not Travel(sea) then return end
    local d = MAT[sea][name]
    SetSub("Farmando " .. name .. " (" .. GetMaterial(name) .. ")")
    Farm(d[1], 20, d[2])
end

local boneMobs = { "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" }
local function FarmBones()
    if not Travel(3) then return end
    SetSub("Farmando Bones (" .. GetMaterial("Bones") .. ")")
    Farm(boneMobs, 15, Vector3.new(-9515, 164, 5786))
end

--==============================================================
-- Raid (fragmentos)
--==============================================================
local Raid = { on = false, chipAt = 0, pause = false }
pcall(function()
    local rr = RS.Remotes:FindFirstChild("Raids")
    if rr then rr.OnClientEvent:Connect(function(a) Raid.on = (a == "StartTimer") end) end
end)
local function CanDungeon()
    if SeaIdx() == 1 or Level() < 1250 then return false end
    if HasTool("Special Microchip") or GetUseableFruit() then return true end
    local res = Cache("raidsel", 5, function() return CommF:InvokeServer("RaidsNpc", "Select", "Dark") end)
    return Beli() >= 100000 and ((type(res) == "number" and res == 1) or (type(res) == "string" and not res:find("wait")))
end
local function DungeonTick()
    SetFarm("Raid (Fragmentos)", "Fragments " .. Frags())
    local c, h, r = Char()
    if not c then return end
    if not Raid.on then
        if not HasTool("Special Microchip") then
            SetSub("Pegando chip")
            if Beli() >= 100000 and tick() - Raid.chipAt > 3 then
                Raid.chipAt = tick()
                CommF:InvokeServer("RaidsNpc", "Select", "Dark")
            elseif tick() - Raid.chipAt > 3 then
                Raid.chipAt = tick()
                local f = GetUseableFruit()
                if f then
                    Raid.pause = true
                    CommF:InvokeServer("LoadFruit", f)
                    task.wait(0.5)
                    CommF:InvokeServer("RaidsNpc", "Select", "Dark")
                    Raid.pause = false
                end
            end
            return
        end
        EquipTool("Special Microchip")
        SetSub("Iniciando raid")
        local sea = SeaIdx()
        local btn
        if sea == 2 then
            local ci = workspace.Map:FindFirstChild("CircleIsland")
            btn = ci and ci:FindFirstChild("RaidSummon2")
            if btn and not Near(btn:GetPivot().Position, 40) then Goto(btn:GetPivot().Position, 5); return end
        else
            if not Near(Vector3.new(-5018, 315, -2828), 40) then Goto(Vector3.new(-5018, 315, -2828)); return end
            local bc = workspace.Map:FindFirstChild("Boat Castle")
            btn = bc and bc:FindFirstChild("RaidSummon2")
        end
        local cd = btn and btn:FindFirstChildWhichIsA("ClickDetector", true)
        if cd then pcall(fireclickdetector, cd) end
        local t0 = tick()
        repeat task.wait(0.25) until Raid.on or tick() - t0 > 20
        return
    end
    -- raid ativa
    SetSub("Limpando ilha")
    for _, v in ipairs(workspace.Enemies:GetChildren()) do
        local hum = v:FindFirstChildOfClass("Humanoid")
        if v.PrimaryPart and hum and hum.Health > 0 and LP:DistanceFromCharacter(v.PrimaryPart.Position) <= 2000 then
            Goto(v.PrimaryPart.Position, 28, 200)
            if LP:DistanceFromCharacter(v.PrimaryPart.Position) < 60 then EquipWeapon(); Attack() end
            return
        end
    end
    for i = 5, 1, -1 do
        local loc = workspace._WorldOrigin.Locations:FindFirstChild("Island " .. i)
        if loc and LP:DistanceFromCharacter(loc:GetPivot().Position) <= 6000 then
            Goto(loc:GetPivot().Position + Vector3.new(100, 70, 100)); return
        end
    end
end

--==============================================================
-- Melees / Godhuman
--==============================================================
local PRICE = {
    BlackLeg = { beli = 150000 }, Electro = { beli = 500000 }, FishmanKarate = { beli = 750000 },
    DragonClaw = { frag = 1500 }, Superhuman = { beli = 3000000 },
    DeathStep = { beli = 2500000, frag = 5000 }, SharkmanKarate = { beli = 2500000, frag = 5000 },
    ElectricClaw = { beli = 2500000, frag = 5000 }, DragonTalon = { beli = 2500000, frag = 5000 },
    Godhuman = { beli = 5000000, frag = 5000 },
}
local BUYER = {
    BlackLeg = { Vector3.new(-985, 14, 3988), Vector3.new(-4754, 35, -4849), Vector3.new(-5045, 372, -3178) },
    Electro = { Vector3.new(-5384, 14, -2149), Vector3.new(-4864, 35, -4765), Vector3.new(-4994, 315, -3201) },
    FishmanKarate = { Vector3.new(61585, 19, 987), Vector3.new(-4957, 35, -4668), Vector3.new(-5022, 372, -3187) },
    SharkmanKarate = { false, Vector3.new(-2602, 239, -10317), Vector3.new(-4974, 315, -3221) },
    DeathStep = { false, Vector3.new(6356, 296, -6763), Vector3.new(-4997, 315, -3220) },
    Superhuman = { false, Vector3.new(1379, 247, -5190), Vector3.new(-5004, 372, -3194) },
    DragonClaw = { false, Vector3.new(702, 187, 653), Vector3.new(-4980, 372, -3205) },
    ElectricClaw = { false, false, Vector3.new(-10371, 331, -10131) },
    DragonTalon = { false, false, Vector3.new(5661, 1210, 863) },
    Godhuman = { false, false, Vector3.new(-13774, 333, -9879) },
}
local function RealName(k) return (k:gsub("(%l)(%u)", "%1 %2")) end
local function GoBuyer(k)
    local p = BUYER[k] and BUYER[k][SeaIdx()]
    if not p then return false end
    SetSub("Indo ao NPC de " .. RealName(k))
    if Near(p, 12) then return true end
    Goto(p, 2)
    return false
end

local function GodhumanStep()
    SetFarm("Godhuman", "Verificando requisitos")
    local check = Cache("bg", 2, function() return CommF:InvokeServer("BuyGodhuman", true) end)
    if check ~= 0 and check ~= 1 then
        for i, v in ipairs({ "Dragon Scale", "Fish Tail", "Mystic Droplet", "Magma Ore" }) do
            local need = (i % 2 > 0) and 10 or 20
            if GetMaterial(v) < need then FarmMaterial(v); return end
        end
    end
    if not Travel(3) then return end
    if GoBuyer("Godhuman") then
        CommF:InvokeServer("BuyGodhuman", true)
        CommF:InvokeServer("BuyGodhuman")
    end
end

local UNLOCK = {}
UNLOCK.SharkmanKarate = function()
    if not Travel(2) then return end
    local check = Cache("bsk", 2, function() return CommF:InvokeServer("BuySharkmanKarate", true) end)
    if not HasTool("Water Key") and check ~= 0 and check ~= 1 and type(check) == "string" then
        if not Farm({ "Tide Keeper" }, 25) and not FindMob({ "Tide Keeper" }) then Hop() end
    elseif GoBuyer("SharkmanKarate") then
        CommF:InvokeServer("BuySharkmanKarate", true); CommF:InvokeServer("BuySharkmanKarate")
    end
end
UNLOCK.DeathStep = function()
    if not Travel(2) then return end
    local check = Cache("ol", 2, function() return CommF:InvokeServer("OpenLibrary") end)
    if not HasTool("Library Key") and not check then
        if not Farm({ "Awakened Ice Admiral" }, 25) and not FindMob({ "Awakened Ice Admiral" }) then Hop() end
    elseif HasTool("Library Key") then
        CommF:InvokeServer("OpenLibrary")
    elseif check == true and GoBuyer("DeathStep") then
        CommF:InvokeServer("BuyDeathStep")
    end
end
UNLOCK.ElectricClaw = function()
    if not Travel(3) then return end
    if GoBuyer("ElectricClaw") then
        CommF:InvokeServer("BuyElectricClaw", "Start")
        local t0 = tick()
        repeat Goto(Vector3.new(-12550, 336, -7510)); task.wait(0.3) until Near(Vector3.new(-12550, 336, -7510), 15) or tick() - t0 > 25
        GoBuyer("ElectricClaw")
        CommF:InvokeServer("BuyElectricClaw")
    end
end
UNLOCK.DragonTalon = function()
    if not Travel(3) then return end
    if not HasTool("Fire Essence") then
        if GetMaterial("Bones") >= 50 then CommF:InvokeServer("Bones", "Buy", 1, 1) end
        FarmBones(); return
    end
    if GoBuyer("DragonTalon") then
        CommF:InvokeServer("BuyDragonTalon", true); CommF:InvokeServer("BuyDragonTalon")
    end
end

local function UnlockMelee(v)
    local P = PRICE[v]
    local m = MeleeData[v] or 0
    local eco = (not P.beli or Beli() >= P.beli) and (not P.frag or Frags() >= P.frag)
    local real = RealName(v)
    if m == 0 and eco then
        SetFarm("Melee", "Liberando " .. real)
        if v == "Godhuman" then GodhumanStep()
        elseif UNLOCK[v] then UNLOCK[v]()
        elseif GoBuyer(v) then
            if v == "Superhuman" then CommF:InvokeServer("BuySuperhuman")
            else CommF:InvokeServer("BlackbeardReward", "DragonClaw", "2") end
        end
        return true
    elseif m == 0 and P.frag and Frags() < P.frag and CanDungeon() then
        DungeonTick(); return true
    elseif m == 0 then
        SetSub("Aguardando recursos para " .. real)
        return false
    elseif not HasTool(real) then
        if GoBuyer(v) then
            if v == "DragonClaw" then CommF:InvokeServer("BlackbeardReward", "DragonClaw", "2") else CommF:InvokeServer("Buy" .. v) end
        end
        return true
    end
    return false
end

local lastHaki = 0
local function MeleeStage()
    if not IRS then return false end
    CheckMeleeMastery()
    if tick() - lastHaki > 20 then
        lastHaki = tick()
        local c = LP.Character
        if c then
            local b = Beli()
            if not c:HasTag("Buso") and b >= 25000 then CommF:InvokeServer("BuyHaki", "Buso") end
            if not c:HasTag("Geppo") and b >= 10000 then CommF:InvokeServer("BuyHaki", "Geppo") end
            if not c:HasTag("Soru") and b >= 100000 then CommF:InvokeServer("BuyHaki", "Soru") end
        end
    end
    for _, v in ipairs({ "BlackLeg", "Electro", "FishmanKarate" }) do
        if (MeleeData[v] or 0) < 400 then
            if (MeleeData[v] or 0) == 0 and Beli() < PRICE[v].beli then return false end
            if not HasTool(RealName(v)) then
                if GoBuyer(v) then CommF:InvokeServer("Buy" .. v) end
                SetFarm("Melee", "Comprando " .. RealName(v))
                return true
            end
            return false
        end
    end
    if SeaIdx() ~= 1 then
        for _, v in ipairs({ "DragonClaw", "Superhuman", "DeathStep", "SharkmanKarate" }) do
            if (MeleeData[v] or 0) < 400 then return UnlockMelee(v) end
        end
        for _, v in ipairs({ "ElectricClaw", "DragonTalon", "Godhuman" }) do
            if (MeleeData[v] or 0) < 400 then return UnlockMelee(v) end
        end
    end
    return false
end

--==============================================================
-- Saber / Bartilo / Race / Sea unlocks / Skull Guitar
--==============================================================
local flag = { abandoned = false, swanSeen = false, swanKilled = false, ripBegun = false, humanStage = 0, minkChests = 0 }

local function SaberStage()
    SetFarm("Saber", "Quest da Saber")
    if not Travel(1) then return end
    if not flag.abandoned then flag.abandoned = true; pcall(function() CommF:InvokeServer("AbandonQuest") end) end
    local d = Cache("pq", 0.8, function() return CommF:InvokeServer("ProQuestProgress") end)
    local c, h, r = Char()
    if type(d) ~= "table" or not c then return end
    if d.UsedRelic == false then
        local J = workspace.Map:FindFirstChild("Jungle")
        local plates = J and J:FindFirstChild("QuestPlates")
        if not (plates and plates:FindFirstChild("Door")) then SetSub("Indo a selva"); Goto(Vector3.new(-1254, 18, 342)); return end
        if plates.Door.Transparency == 0 then
            SetSub("Ativando placas")
            for _, v in ipairs(plates:GetChildren()) do
                if v:IsA("Model") and v.Name:find("Plate") and v:FindFirstChild("Button") then
                    firetouchinterest(v.Button, r, 1); firetouchinterest(v.Button, r, 0)
                end
            end
        elseif d.UsedTorch == false then
            SetSub("Tocha")
            if HasTool("Torch") then CommF:InvokeServer("ProQuestProgress", "DestroyTorch") else CommF:InvokeServer("ProQuestProgress", "GetTorch") end
        elseif d.UsedCup then
            if d.TalkedSon and d.KilledMob then
                SetSub("Colocando relic")
                CommF:InvokeServer("ProQuestProgress", "RichSon")
                EquipTool("Relic")
                CommF:InvokeServer("ProQuestProgress", "PlaceRelic")
            elseif d.TalkedSon == false then
                SetSub("Falando com Rich Son")
                CommF:InvokeServer("ProQuestProgress", "RichSon")
            elseif d.KilledMob == false then
                SetSub("Mob Leader")
                Farm({ "Mob Leader" }, 25)
            end
        else
            SetSub("Enchendo o copo")
            CommF:InvokeServer("ProQuestProgress", "GetCup")
            EquipTool("Cup")
            if LP.Character:FindFirstChild("Cup") then CommF:InvokeServer("ProQuestProgress", "FillCup", LP.Character.Cup) end
            CommF:InvokeServer("ProQuestProgress", "SickMan")
        end
    else
        SetSub("Saber Expert")
        Farm({ "Saber Expert" }, 25)
    end
end

local function Sea2Stage()
    SetFarm("Desbloquear Sea 2", "")
    local travel = CommF:InvokeServer("TravelDressrosa")
    if type(travel) == "string" and travel:find("Cannot") then
        local d = Cache("dq", 1, function() return CommF:InvokeServer("DressrosaQuestProgress") end)
        if type(d) ~= "table" then return end
        if not d.UsedKey then
            if not d.TalkedDetective then SetSub("Falando com detetive"); CommF:InvokeServer("DressrosaQuestProgress", "Detective")
            elseif HasTool("Key") then EquipTool("Key") end
            CommF:InvokeServer("DressrosaQuestProgress", "UseKey")
        elseif not d.KilledIceBoss then
            SetSub("Ice Admiral")
            Farm({ "Ice Admiral" }, 25, Vector3.new(1328, 43, -1346))
        else
            CommF:InvokeServer("TravelDressrosa")
        end
    end
end

local function BartiloStage()
    SetFarm("Bartilo Quest", "")
    if not Travel(2) then return end
    local killed = Cache("bk", 1, function() return CommF:InvokeServer("BartiloQuestProgress").KilledBandits end)
    local data = Cache("bd", 1, function() return CommF:InvokeServer("BartiloQuestProgress", "Bartilo") end)
    if killed == false then
        SetSub("50x Swan Pirate")
        if Q.name ~= "BartiloQuest" then pcall(function() CommF:InvokeServer("StartQuest", "BartiloQuest", 1) end) end
        Farm({ "Swan Pirate" }, 20, Vector3.new(932, 156, 1180))
    elseif data == 1 then
        SetSub("Jeremy")
        Farm({ "Jeremy" }, 25, Vector3.new(2129, 469, 779))
    elseif data == 2 then
        SetSub("Placas")
        local c, h, r = Char()
        for i = 1, 8 do
            local p = workspace.Map.Dressrosa.BartiloPlates["Plate" .. i]
            firetouchinterest(p, r, 0); task.wait(0.1); firetouchinterest(p, r, 1)
        end
    end
end

local function RaceV2Stage()
    SetFarm("Race V2", "")
    if not Travel(2) then return end
    local check = Cache("alc", 1, function() return CommF:InvokeServer("Alchemist", "1") end)
    local c, h, r = Char()
    if not c then return end
    if check == 0 then SetSub("Falando com alquimista"); CommF:InvokeServer("Alchemist", "2")
    elseif check == 1 then
        if not HasTool("Flower 1") then
            SetSub("Flor 1"); local f = workspace:FindFirstChild("Flower1")
            if f then Goto(f.Position, 2); firetouchinterest(f, r, 1); firetouchinterest(f, r, 0) end
        elseif not HasTool("Flower 2") then
            SetSub("Flor 2"); local f = workspace:FindFirstChild("Flower2")
            if f then Goto(f.Position, 2); firetouchinterest(f, r, 1); firetouchinterest(f, r, 0) end
        elseif not HasTool("Flower 3") then
            SetSub("Flor 3 (Zombie)")
            Farm({ "Zombie" }, 15, Vector3.new(-5685, 48, -853))
        end
    elseif check == 2 then
        SetSub("Entregando flores"); CommF:InvokeServer("Alchemist", "3")
    end
end

local HUMAN_WAIT = {
    [0] = Vector3.new(2333, 449, 699), [1] = Vector3.new(-1713, 199, -104), [2] = Vector3.new(-2148, 73, -4304),
}
local HUMAN_BOSS = { [0] = "Jeremy", [1] = "Diamond", [2] = "Orbitus" }
local function RaceV3Stage()
    SetFarm("Race V3", "")
    if not Travel(2) then return end
    local race = LP.Data.Race.Value
    local check = CommF:InvokeServer("Wenlocktoad", "1")
    if check == 0 then SetSub("Iniciando quest"); CommF:InvokeServer("Wenlocktoad", "2"); return end
    if check == 2 then SetSub("Concluindo"); CommF:InvokeServer("Wenlocktoad", "3"); return end
    if check ~= 1 then return end
    if race == "Human" then
        if flag.humanStage >= 3 then CommF:InvokeServer("Wenlocktoad", "3"); flag.humanStage = 0; return end
        local boss = HUMAN_BOSS[flag.humanStage]
        SetSub("Boss " .. (flag.humanStage + 1) .. "/3: " .. boss)
        local live = FindMob({ boss })
        if live then
            Farm({ boss }, 30)
        else
            if flag.humanSeen == boss then flag.humanStage += 1; flag.humanSeen = nil
            else Goto(HUMAN_WAIT[flag.humanStage], 0) end
        end
        if live then flag.humanSeen = boss end
    elseif race == "Rabbit" then
        local folder = workspace:FindFirstChild("ChestModels")
        if flag.minkChests >= 30 then CommF:InvokeServer("Wenlocktoad", "3"); return end
        local chest = folder and folder:GetChildren()[flag.minkChests + 1]
        if chest then
            SetSub("Bau " .. (flag.minkChests + 1) .. "/30")
            Goto(chest.WorldPivot.Position, 0)
            if Near(chest.WorldPivot.Position, 10) then flag.minkChests += 1 end
        end
    else
        SetSub("Fishman V3 entra na Parte 2")
    end
end

local function GetTitle(t)
    local a = CommF:InvokeServer("getTitles") or {}
    for _, v in pairs(a) do if v.InternalName == t and v.Name ~= "(LOCKED)" then return true end end
    return false
end
local function SwanKilled()
    if flag.swanKilled then return true end
    if Cache("swan", 30, function() return GetTitle("Heavenly Devil") end) then flag.swanKilled = true end
    return flag.swanKilled
end

local function Sea3Stage()
    SetFarm("Desbloquear Sea 3", "")
    local unl = Cache("unl", 3, function() return CommF:InvokeServer("GetUnlockables") end)
    if type(unl) == "table" and unl.FlamingoAccess then
        local z = CommF:InvokeServer("ZQuestProgress", "Check")
        if z == 0 then
            if FindMob({ "rip_indra" }) then
                SetSub("rip_indra"); Farm({ "rip_indra" }, 30)
            else
                if not flag.ripBegun then CommF:InvokeServer("ZQuestProgress", "Begin"); flag.ripBegun = true end
                Goto(Vector3.new(2288, 15, 863))
            end
        elseif z == 1 then
            CommF:InvokeServer("TravelZou")
        else
            if FindMob({ "Don Swan" }) then
                flag.swanSeen = true; SetSub("Don Swan"); Farm({ "Don Swan" }, 30)
            else
                if flag.swanSeen then flag.swanKilled = true end
                Goto(Vector3.new(2288, 15, 863))
            end
        end
    else
        SetSub("Liberando Flamingo (Trevor)")
        local talk = CommF:InvokeServer("TalkTrevor", "1")
        local df = GetFruitValue(1000000)
        if df then
            if talk == 1 then CommF:InvokeServer("TalkTrevor", "2"); task.wait(0.75) end
            Raid.pause = true
            CommF:InvokeServer("LoadFruit", df)
            local tool = LP.Backpack:FindFirstChildWhichIsA("Tool")
            for _, t in ipairs(LP.Backpack:GetChildren()) do if t.Name:find("Fruit") then EquipTool(t.Name) end end
            CommF:InvokeServer("TalkTrevor", "1"); CommF:InvokeServer("TalkTrevor", "2"); CommF:InvokeServer("TalkTrevor", "3")
            Raid.pause = false
        else
            SetSub("Sem fruta >= 1M, trocando de server")
            Hop()
        end
    end
end

local function FullMoon()
    local ok, r = pcall(function()
        return Lighting.Sky.MoonTextureId == "http://www.roblox.com/asset/?id=9709149431" and (Lighting.ClockTime > 16 or Lighting.ClockTime < 5)
    end)
    return ok and r
end
local lastMoonHop = 0
local function GuitarStage()
    SetFarm("Skull Guitar", "")
    if not Travel(3) then return end
    local check = Cache("gp", 1, function() return CommF:InvokeServer("GuitarPuzzleProgress", "Check") end)
    if not check then
        if FullMoon() then
            SetSub("Ritual do tumulo")
            if not Near(Vector3.new(-8654, 140, 6167), 40) then Goto(Vector3.new(-8654, 140, 6167)); return end
            CommF:InvokeServer("gravestoneEvent", 2); CommF:InvokeServer("gravestoneEvent", 2, true)
        else
            SetSub("Esperando lua cheia")
            if Options.HopMoon.Value and tick() - lastMoonHop > 60 then lastMoonHop = tick(); Hop() end
        end
    elseif check.Swamp == false then
        SetSub("Pantano (Living Zombie)")
        Farm({ "Living Zombie" }, 15, Vector3.new(-10144, 138, 5838))
    elseif check.Gravestones == false then CommF:InvokeServer("GuitarPuzzleProgress", "Gravestones")
    elseif check.Ghost == false then CommF:InvokeServer("GuitarPuzzleProgress", "Ghost")
    elseif check.Trophies == false then CommF:InvokeServer("GuitarPuzzleProgress", "Trophies")
    elseif check.Pipes == false then CommF:InvokeServer("GuitarPuzzleProgress", "Pipes")
    elseif check.CraftedOnce == false then
        if Frags() >= 5000 and GetMaterial("Bones") >= 500 and GetMaterial("Ectoplasm") >= 250 then
            SetSub("Craftando"); CommF:InvokeServer("soulGuitarBuy")
        elseif GetMaterial("Ectoplasm") < 250 then FarmMaterial("Ectoplasm")
        elseif GetMaterial("Bones") < 500 then FarmBones()
        elseif CanDungeon() then DungeonTick()
        else SetSub("Faltam Fragments (" .. Frags() .. "/5000)") end
    end
end

--==============================================================
-- Itens / progresso
--==============================================================
local ITEM_CHECKS = {
    { "Godhuman", function() return MeleeHas("Godhuman") end },
    { "Saber", function() return Has("Saber") end },
    { "Cursed Dual Katana", function() return Has("Cursed Dual Katana") end },
    { "Skull Guitar", function() return Has("Skull Guitar") end },
    { "Yama", function() return Has("Yama") end },
    { "Tushita", function() return Has("Tushita") end },
    { "Rengoku", function() return Has("Rengoku") end },
    { "Warrior Helmet", function() return Has("Warrior Helmet") end },
    { "Valkyrie Helm", function() return Has("Valkyrie Helm") end },
    { "Mirror Fractal", function() return Has("Mirror Fractal") end },
    { "Race V2+", function() local g = GetRaceGrade(); return g ~= "V1" end },
    { "Race V3+", function() local g = GetRaceGrade(); return g == "V3" or g == "V4" end },
}
local ItemState = {}
local function RefreshItems()
    local lines = {}
    for _, it in ipairs(ITEM_CHECKS) do
        local ok, v = pcall(it[2])
        v = ok and v or false
        ItemState[it[1]] = v
        table.insert(lines, (v and "✅ " or "❌ ") .. it[1])
    end
    return table.concat(lines, "\n")
end

local function RequiredDone()
    local req = Options.Required.Value
    local map = { ["Saber"] = "Saber", ["Godhuman"] = "Godhuman", ["Skull Guitar"] = "Skull Guitar", ["Race V3"] = "Race V3+", ["Cursed Dual Katana"] = "Cursed Dual Katana" }
    for name, on in pairs(req) do
        if on then
            if name == "Level Max" then
                if Level() < MaxLevel then return false end
            elseif not ItemState[map[name] or name] then
                return false
            end
        end
    end
    return true
end

--==============================================================
-- Secret Quest (modulo externo)
--==============================================================
local Secret = { loaded = false, loading = false, started = false }
local function LoadSecret()
    if Secret.loaded or Secret.loading then return end
    Secret.loading = true
    task.spawn(function()
        local src
        if isfile and readfile and isfile(SECRET_FILE) then src = readfile(SECRET_FILE)
        elseif SECRET_URL ~= "" then pcall(function() src = game:HttpGet(SECRET_URL) end) end
        if not src then Secret.loading = false; Secret.err = "Salve SecretQuest.lua no workspace ou preencha SECRET_URL"; return end
        local fn, err = loadstring(src)
        if not fn then Secret.loading = false; Secret.err = tostring(err); return end
        local ok, e = pcall(fn)
        if not ok then Secret.err = tostring(e) end
        local t0 = tick()
        repeat task.wait(0.5) until getgenv().SaveSettings or tick() - t0 > 30
        pcall(function()
            local g = LP.PlayerGui:FindFirstChild("SecretQuestInterface") or (gethui and gethui():FindFirstChild("SecretQuestInterface"))
            if g then g.Enabled = false end
        end)
        Secret.loaded = getgenv().SaveSettings ~= nil
        Secret.loading = false
    end)
end
local function SecretSet(on)
    local save = getgenv().SaveSettings
    if not save then return end
    pcall(function()
        save("Select Team", Options.Team.Value)
        save("Select Weapon", Options.Weapon.Value)
        save("Auto Secret Quest", on)
    end)
    Secret.started = on
end
local function SecretInfo()
    local HE = getgenv().HiddenEvent or _G.HiddenEvent
    local HQ = getgenv().HiddenQuests or _G.HiddenQuests
    if not HE or not HQ then return nil end
    local prog = HE.progress or {}
    local done, missing = 0, {}
    for _, q in ipairs(HQ) do
        local v = prog["Sea1/" .. tostring(q.Island) .. "/" .. tostring(q.Name)]
        if v == true or (type(v) == "table" and v.Completed) then done += 1 else table.insert(missing, q.Name) end
    end
    return done, #HQ, missing, HE
end
local function SecretStage()
    SetFarm("Secret Quest", "")
    if not Travel(1) then return end
    LoadSecret()
    if not Secret.loaded then SetSub(Secret.err or "Carregando modulo Secret Quest..."); return end
    if not Secret.started then SecretSet(true) end
    local done, total, _, HE = SecretInfo()
    SetSub("Missao: " .. tostring(HE and HE.current or "-") .. " | " .. tostring(done or 0) .. "/" .. tostring(total or 39))
end

--==============================================================
-- Loop principal
--==============================================================
local Stages = {
    { "Melee", function() return Goal("Godhuman") and Level() >= 200 end, function() return MeleeStage() end, true },
    { "Saber", function() return Goal("Saber") and Level() >= 200 and not Has("Saber") end, SaberStage },
    { "Sea2", function() return Level() >= 700 and SeaIdx() == 1 end, Sea2Stage },
    { "Bartilo", function() return Goal("Bartilo") and Level() >= 850 and SeaIdx() ~= 3 and not Has("Warrior Helmet") end, BartiloStage },
    { "RaceV2", function() return Goal("Race V2") and Level() >= 850 and Beli() >= 500000 and GetRaceGrade() == "V1" and Has("Warrior Helmet") end, RaceV2Stage },
    { "RaceV3", function() return Goal("Race V3") and Level() >= 1000 and Beli() >= 2000000 and GetRaceGrade() == "V2" and SwanKilled() end, RaceV3Stage },
    { "Sea3", function() return Level() >= 1500 and SeaIdx() == 2 end, Sea3Stage },
    { "Guitar", function() return Goal("Skull Guitar") and Level() >= 2300 and SeaIdx() ~= 1 and not Has("Skull Guitar") end, GuitarStage },
}

local function Tick()
    if not Char() then SetSub("Aguardando respawn"); return end
    if not LP.Team then pcall(function() CommF:InvokeServer("SetTeam", Options.Team.Value) end); return end
    RefreshItems()
    if Options.AutoSecret.Value and RequiredDone() then
        SecretStage(); return
    elseif Secret.started then
        SecretSet(false)
    end
    for _, st in ipairs(Stages) do
        local okc, c = pcall(st[2])
        if okc and c then
            if st[4] then
                local ok, acted = pcall(st[3])
                if ok and acted then return end
            else
                local ok, e = pcall(st[3])
                if not ok then SetSub("Erro: " .. tostring(e):sub(1, 60)) end
                return
            end
        end
    end
    -- fallback: level farm (Godhuman faltando fragmentos tambem passa aqui)
    if Level() < MaxLevel then LevelFarm()
    else
        if Goal("Godhuman") and CanDungeon() and Frags() < 5000 then DungeonTick() else SetFarm("Kaitun completo", "Aguardando") end
    end
end

task.spawn(function()
    while true do
        task.wait()
        if Running() then
            local ok, e = pcall(Tick)
            if not ok then SetSub("Erro: " .. tostring(e):sub(1, 60)); task.wait(1) end
        else
            if Secret.started then SecretSet(false) end
            StopTween()
        end
    end
end)

Options.StartOneClick:OnChanged(function()
    if not Options.StartOneClick.Value then StopTween(); SetFarm("Parado", "-") end
end)

-- auto store de frutas
task.spawn(function()
    while task.wait(2) do
        if Running() and not Raid.pause then
            pcall(function()
                for _, cont in ipairs({ LP.Backpack, LP.Character }) do
                    if cont then
                        for _, v in ipairs(cont:GetChildren()) do
                            if v:IsA("Tool") and v.Name:find("Fruit") then
                                local ori = v:GetAttribute("OriginalName") or v.Name
                                CommF:InvokeServer("StoreFruit", ori, v)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- anti afk + ken
LP.Idled:Connect(function() pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end) end)
task.spawn(function()
    while task.wait(1.5) do
        if Running() then pcall(function() if LP.Character and not LP.Character:FindFirstChild("HasKen") then CommE:FireServer("Ken", true) end end) end
    end
end)

-- graficos
local function ApplyGfx()
    pcall(function() setfpscap(Options.FPS.Value) end)
    pcall(function() RunService:Set3dRenderingEnabled(not Options.WhiteScreen.Value) end)
    if Options.LowGfx.Value then
        pcall(function()
            Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            for _, v in ipairs(Lighting:GetChildren()) do if v:IsA("PostEffect") then v.Enabled = false end end
        end)
    end
end
Options.FPS:OnChanged(ApplyGfx); Options.WhiteScreen:OnChanged(ApplyGfx); Options.LowGfx:OnChanged(ApplyGfx)
ApplyGfx()

--==============================================================
-- Webhook
--==============================================================
local function Req(t) local f = (syn and syn.request) or http_request or request; return f(t) end
function SendMessage(url, message)
    local body = HttpService:JSONEncode({ content = message })
    Req({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
end
function SendMessageEMBED(url, embed)
    local body = HttpService:JSONEncode({ embeds = { { title = embed.title, description = embed.description, color = embed.color,
        fields = embed.fields, footer = { text = embed.footer.text } } } })
    Req({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
end
local function Uptime()
    local s = os.time() - StartTick
    return string.format("%dh %dm", math.floor(s / 3600), math.floor(s % 3600 / 60))
end
local function SendStatus(force)
    local url = Options.WebhookUrl.Value
    if not url or url == "" then return end
    RefreshItems()
    local items = {}
    for _, it in ipairs(ITEM_CHECKS) do table.insert(items, (ItemState[it[1]] and "✅ " or "❌ ") .. it[1]) end
    local done, total = SecretInfo()
    local embed = {
        title = "W-AZURE V3 - ONE CLICK",
        description = "**" .. LP.DisplayName .. "** | Sea " .. SeaIdx(),
        color = 3066993,
        fields = {
            { name = "📊 Conta", value = ("Level: **%d**\nBeli: **%s**\nFragments: **%s**\nRace: **%s %s**"):format(Level(), tostring(Beli()), tostring(Frags()), LP.Data.Race.Value, GetRaceGrade()), inline = true },
            { name = "⚙️ Farm", value = ("Principal: **%s**\nSub: %s\nUptime: %s"):format(State.Main, State.Sub, Uptime()), inline = true },
            { name = "🎒 Itens", value = table.concat(items, "\n") },
            { name = "🕵️ Secret Quest", value = done and (done .. "/" .. total .. " concluidas") or "nao iniciada" },
        },
        footer = { text = "W-AZURE V3 • " .. os.date("%H:%M:%S") },
    }
    task.spawn(function() pcall(SendMessageEMBED, url, embed) end)
end
_G.__WA_SendStatus = SendStatus

task.spawn(function()
    local last = 0
    while task.wait(5) do
        if Options.WebhookOn.Value and Options.WebhookUrl.Value ~= "" then
            local mins = math.max(1, tonumber(Options.WebhookMin.Value) or 10)
            if tick() - last >= mins * 60 then last = tick(); SendStatus() end
        end
        -- aviso imediato de item novo
        if Options.WebhookOn.Value and Options.WebhookUrl.Value ~= "" then
            for _, it in ipairs(ITEM_CHECKS) do
                local now = ItemState[it[1]]
                if now and Fluent.__prev and Fluent.__prev[it[1]] == false then
                    pcall(SendMessage, Options.WebhookUrl.Value, "🎉 **" .. LP.DisplayName .. "** desbloqueou **" .. it[1] .. "**")
                end
            end
            Fluent.__prev = table.clone(ItemState)
        end
    end
end)

--==============================================================
-- Atualizacao da UI
--==============================================================
task.spawn(function()
    while task.wait(1) do
        SetP(StatusP, "Status", "Farm Principal: " .. State.Main .. "\nSub Farm: " .. State.Sub)
        pcall(function() SetP(ItemsP, "Itens da conta", RefreshItems()) end)
        local done, total, missing, HE = SecretInfo()
        if done then
            local nxt = {}
            for i = 1, math.min(3, #missing) do nxt[i] = missing[i] end
            local txt = ("Missao atual: %s\nEtapa: %s\nConcluidas: %d/%d | Faltam: %d\nProximas: %s"):format(
                tostring(HE.current or "-"), tostring(HE.step or "-"), done, total, #missing, #nxt > 0 and table.concat(nxt, ", ") or "-")
            SetP(SecretP, "Secret Quest", txt)
        else
            SetP(SecretP, "Secret Quest", Secret.err or (RequiredDone() and "Preparando..." or "Aguardando kaitun principal terminar..."))
        end
    end
end)

--==============================================================
-- Salvar automaticamente
--==============================================================
pcall(function()
    local path = "WAzureV3/OneClick/settings/autoload.txt"
    if writefile then writefile(path, "auto") end
end)
SaveManager:LoadAutoloadConfig()
task.spawn(function()
    while task.wait(5) do pcall(function() SaveManager:Save("auto") end) end
end)

Fluent:Notify({ Title = "W-AZURE V3", Content = "ONE-CLICK carregado (Parte 1)", Duration = 6 })
