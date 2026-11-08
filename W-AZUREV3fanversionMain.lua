--[[
    W-AZURE V3  |  by jane doe sigma
    UI: Fluent
    Tabs: Main (Farming) / Missions / Sea Event / Volcano / Config (Setting Farm)
    Logica portada do Banana Cat Hub.
]]

repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

----------------------------------------------------------------
-- UI (Fluent)
----------------------------------------------------------------
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
	Title = "W-AZURE V3",
	SubTitle = "by jane doe sigma",
	TabWidth = 140,
	Size = UDim2.fromOffset(580, 460),
	Acrylic = false,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
	Main = Window:AddTab({ Title = "Main", Icon = "home" }),
	Missions = Window:AddTab({ Title = "Missions", Icon = "target" }),
	SeaEvent = Window:AddTab({ Title = "Sea Event", Icon = "waves" }),
	Volcano = Window:AddTab({ Title = "Volcano", Icon = "flame" }),
	Config = Window:AddTab({ Title = "Config", Icon = "settings" }),
}

local Options = Fluent.Options

-- Settings["Nome do toggle"] le direto o valor da opcao do Fluent (mesma API do Banana)
local Settings = setmetatable({}, {
	__index = function(_, k)
		local o = Options[k]
		return o and o.Value
	end,
})

----------------------------------------------------------------
-- Services / references
----------------------------------------------------------------
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local Enemies = workspace:WaitForChild("Enemies")
local Remotes = RS:WaitForChild("Remotes")
local CommF_ = Remotes:WaitForChild("CommF_")
local Net = RS:WaitForChild("Modules"):WaitForChild("Net")
local RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
local RegisterHit = Net:WaitForChild("RE/RegisterHit")

local HitKey = tostring(LP.UserId):sub(2, 4) .. "078da"

local Unloaded = false
local FruitState = { Active = false }

local function CurrentSea()
	local id = game.PlaceId
	if id == 2753915549 or id == 85211729168715 then return 1 end
	if id == 4442272183 or id == 79091703265657 then return 2 end
	return 3
end

local function Noti(msg)
	pcall(function()
		Fluent:Notify({ Title = "W-AZURE V3", Content = tostring(msg), Duration = 5 })
	end)
end

----------------------------------------------------------------
-- UI helpers (id == titulo, igual ao Banana)
----------------------------------------------------------------
local StopTween, CancelBoat -- forward

local function Tg(tab, id, desc, default)
	local t = tab:AddToggle(id, { Title = id, Description = desc, Default = default or false })
	t:OnChanged(function()
		if not t.Value then
			StopTween()
			CancelBoat()
		end
	end)
	return t
end

local function Dd(tab, id, values, default, multi)
	return tab:AddDropdown(id, { Title = id, Values = values, Multi = multi or false, Default = default })
end

local function Sl(tab, id, min, max, default)
	return tab:AddSlider(id, { Title = id, Default = default, Min = min, Max = max, Rounding = 0 })
end

local function Para(tab, title, content)
	tab:AddParagraph({ Title = title, Content = content or "" })
end

----------------------------------------------------------------
-- Utilities
----------------------------------------------------------------
local function GetRoot()
	local char = LP.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHum()
	local char = LP.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(model)
	local hum = model and model:FindFirstChild("Humanoid")
	return hum and hum.Health > 0
end

local function GetDistance(target)
	local root = GetRoot()
	if not root then return math.huge end
	local pos
	if typeof(target) == "CFrame" then
		pos = target.Position
	elseif typeof(target) == "Vector3" then
		pos = target
	else
		return math.huge
	end
	return (root.Position - pos).Magnitude
end

local function FireRemote(...)
	return CommF_:InvokeServer(...)
end

local function ActivateHaki()
	local char = LP.Character
	if char and not char:FindFirstChild("HasBuso") then
		FireRemote("Buso")
	end
end

local function HasTool(name)
	local char = LP.Character
	if char and char:FindFirstChild(name) then return true end
	local backpack = LP.Backpack
	return backpack and backpack:FindFirstChild(name) and true or false
end

local function GetTool(kind)
	local function scan(c)
		if not c then return nil end
		for _, t in ipairs(c:GetChildren()) do
			if t:IsA("Tool") and t.ToolTip == kind then return t end
		end
	end
	return scan(LP.Character) or scan(LP.Backpack)
end

local function EquipTool(tool)
	local hum = GetHum()
	if tool and hum and not hum.Sit and tool.Parent ~= LP.Character then
		hum:EquipTool(tool)
	end
end

local function EquipWeapon()
	local wanted = Settings["Select Weapon"] or "Melee"
	local held = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
	if held and held.ToolTip == wanted then return end
	EquipTool(GetTool(wanted))
end

-- Usa as skills prontas da tool (Z X C V F)
local function UseSkills(tool)
	local ok, skillsGui = pcall(function() return LP.PlayerGui.Main.Skills end)
	if not ok then return false end
	local gui = skillsGui:FindFirstChild(tool.Name)
	if not gui then return false end
	for _, f in ipairs(gui:GetChildren()) do
		if f:IsA("Frame") and f.Name ~= "Template" and f:FindFirstChild("Cooldown") and f:FindFirstChild("Title") then
			local ready = (f.Title.TextColor3 == Color3.new(1, 1, 1) and f.Cooldown.Size == UDim2.new(0, 0, 1, -1))
				or f.Cooldown.Size == UDim2.new(1, 0, 1, -1)
			if ready then
				VIM:SendKeyEvent(true, f.Name, false, game)
				task.wait(0.25)
				VIM:SendKeyEvent(false, f.Name, false, game)
				return true
			end
		end
	end
	return false
end

local function AutoUseSkillWeapons(sel)
	for kind, on in pairs(sel or {}) do
		if on and kind ~= "Only Farm Ship Brigade" then
			local tool = GetTool(kind)
			if tool then
				if tool.Parent ~= LP.Character then
					EquipTool(tool)
					task.wait(0.15)
				end
				if UseSkills(tool) then return end
			end
		end
	end
end

local FruitCounter = 0
local function FruitM1At(pos)
	local tool = GetTool("Blox Fruit")
	if not tool then return end
	if tool.Parent ~= LP.Character then
		EquipTool(tool)
		return
	end
	local remote, root = tool:FindFirstChild("LeftClickRemote"), GetRoot()
	if remote and root then
		FruitCounter = FruitCounter % 5 + 1
		remote:FireServer((pos - root.Position).Unit, FruitCounter)
	end
end

local function Mouse()
	local ok, m = pcall(function() return require(RS.Mouse) end)
	return ok and m or nil
end

----------------------------------------------------------------
-- Inventario (ItemReplicationService)
----------------------------------------------------------------
local InvCache, InvTick = {}, 0
local function GetInventory()
	if tick() - InvTick < 1 then return InvCache end
	local out = {}
	pcall(function()
		local Rep = require(RS:WaitForChild("ItemReplicationService"))
		local Cfg = require(RS:WaitForChild("ItemConfig"))
		for _, it in Rep:GetItems(Rep.KEYS.QUANTITY) do
			if it.Value and it.Value > 0 then
				local ok, c = pcall(function() return Cfg.match(it.ItemId):unwrap() end)
				if ok and c and c.Display then
					local cat, key = c.Display.Category, c.Index and c.Index.StorageKey
					local name = cat == "Blox Fruit" and (key or c.Display.Name) or (c.Display.Name or key)
					out[#out + 1] = { Name = name, Type = cat, Count = it.Value }
				end
			end
		end
	end)
	InvCache, InvTick = out, tick()
	return out
end

local function CheckCountItem(name, count)
	for _, it in ipairs(GetInventory()) do
		if it.Name == name and it.Count >= count then return true end
	end
	return false
end

local function CheckItemInventory(name)
	for _, it in ipairs(GetInventory()) do
		if it.Name == name then return true end
	end
	return false
end

----------------------------------------------------------------
-- Tween / toTarget (Teleport Y, dodge, speed)
----------------------------------------------------------------
local ActiveTween, ActiveBV
local ReadyToDodge, LowHP = false, false
local CurrentTarget

function StopTween()
	if ActiveTween then ActiveTween:Cancel() ActiveTween = nil end
	if ActiveBV then ActiveBV:Destroy() ActiveBV = nil end
end

local function EnsureBV(root)
	if not ActiveBV or not ActiveBV.Parent then
		ActiveBV = Instance.new("BodyVelocity")
		ActiveBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		ActiveBV.Velocity = Vector3.zero
		ActiveBV.Parent = root
	end
end

local function TweenTo(cf)
	local root = GetRoot()
	if not root then return end
	local speed = tonumber(Settings["Speed Tween "]) or 300
	if speed <= 0 then speed = 300 end
	EnsureBV(root)

	local dist = (root.Position - cf.Position).Magnitude
	if dist < 5 then
		if ActiveTween then ActiveTween:Cancel() ActiveTween = nil end
		return
	end
	if ActiveTween then ActiveTween:Cancel() end
	ActiveTween = TweenService:Create(
		root,
		TweenInfo.new(math.max(0.05, dist / speed), Enum.EasingStyle.Linear),
		{ CFrame = cf }
	)
	ActiveTween:Play()
end

local function toTarget(cf)
	if typeof(cf) ~= "CFrame" then return end
	local root, hum = GetRoot(), GetHum()
	if not root or not hum then return end

	if hum.Sit then
		StopTween()
		hum.Sit = false
		hum.Jump = true
		task.wait(0.1)
		root.CFrame = root.CFrame * CFrame.new(0, 10, 0)
		return
	end

	if Settings["Teleport Y"] then
		local ratio = hum.Health / hum.MaxHealth
		if ratio < (Settings["% Health Player"] or 40) / 100 then
			LowHP = true
		elseif ratio > 0.8 then
			LowHP = false
		end
	else
		LowHP = false
	end

	if ReadyToDodge then
		cf = cf + Vector3.new(0, 200, 0)
	elseif LowHP then
		cf = cf + Vector3.new(0, Settings["Distance Teleport Y"] or 800, 0)
	end

	if not ReadyToDodge and not LowHP and (cf.Position - root.Position).Magnitude < 150 then
		if ActiveTween then ActiveTween:Cancel() ActiveTween = nil end
		EnsureBV(root)
		root.CFrame = cf
		return
	end
	TweenTo(cf)
end

----------------------------------------------------------------
-- Noclip enquanto qualquer farm estiver ativo
----------------------------------------------------------------
local FarmFlags = {
	"Start Farm", "Auto Click", "AutoEliteBoss", "AutoYama", "Auto Sea Event", "Auto Find Mirage",
	"Auto Spawn Kitsune Island", "Auto Find Leviathan", "Auto Attack Leviathan", "Auto Start Leviathan",
	"Auto Crafting Volcanic Magnet", "Auto Find Prehistoric Island", "Auto Event Prehistoric Island",
	"Auto Collect Bone", "Auto Collect Egg", "Fully Event Prehistoric Island", "Tween Safe if have Items",
	"Auto Collect Soul Ember", "Auto Summon Soul Ember", "Teleport To Kitsune Island",
}

local function AnyFarmActive()
	for _, id in ipairs(FarmFlags) do
		local o = Options[id]
		if o and o.Value then return true end
	end
	return false
end

RunService.Stepped:Connect(function()
	if Unloaded or not AnyFarmActive() then return end
	local char = LP.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
		end
	end
end)

-- Aimbot das skills (AimPos) via namecall, igual ao Banana
pcall(function()
	local mt = getrawmetatable(game)
	local old = mt.__namecall
	setreadonly(mt, false)
	mt.__namecall = newcclosure(function(self, ...)
		local method = getnamecallmethod()
		local aim = getgenv().AimPos
		if method == "FireServer" and aim and self.Name == "RemoteEvent" and tostring(aim.X) ~= "nan" and AnyFarmActive() then
			local args = { ... }
			if #args == 1 and typeof(args[1]) == "Vector3" then
				args[1] = aim.Position
			elseif #args == 1 and typeof(args[1]) == "CFrame" then
				args[1] = aim
			end
			return old(self, unpack(args))
		end
		return old(self, ...)
	end)
	setreadonly(mt, true)
end)

----------------------------------------------------------------
-- Enemies / bosses / spawns
----------------------------------------------------------------
local NameCache = {}

local function FindEnemy(names)
	local root = GetRoot()
	if not root then return nil end
	if type(names) == "string" then names = { names } end
	local set = {}
	for _, n in ipairs(names) do set[n] = true end

	local best, bestDist = nil, math.huge
	for _, mob in ipairs(Enemies:GetChildren()) do
		local hum = mob:FindFirstChild("Humanoid")
		local hrp = mob:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 then
			local clean = NameCache[mob.Name] or mob.Name:match("^(.-)%s*%[") or mob.Name
			NameCache[mob.Name] = clean
			if set[clean] then
				local d = (hrp.Position - root.Position).Magnitude
				if d < bestDist then
					bestDist = d
					best = mob
				end
			end
		end
	end
	return best
end

local function CheckNameBoss(name)
	local set = type(name) == "table" and name or { name }
	for _, container in ipairs({ RS, Enemies }) do
		for _, m in ipairs(container:GetChildren()) do
			if table.find(set, m.Name) and m:FindFirstChild("HumanoidRootPart") and IsAlive(m) then
				return m
			end
		end
	end
end

local SpawnIndex = 1
local function GoToSpawn(mobName)
	local function clean(s)
		return (s:gsub("Lv%.", ""):gsub("[%[%] %d]", ""):gsub("%s+", ""))
	end
	local wanted = clean(mobName)
	local spawns = {}

	local folder = RS:FindFirstChild("FortBuilderReplicatedSpawnPositionsFolder")
	if folder then
		for _, part in ipairs(folder:GetChildren()) do
			if part:IsA("Part") and part:GetAttribute("Active") and clean(part.Name) == wanted then
				table.insert(spawns, part:GetPivot())
			end
		end
	end
	if #spawns == 0 then
		local es = workspace:FindFirstChild("_WorldOrigin") and workspace._WorldOrigin:FindFirstChild("EnemySpawns")
		if es then
			for _, part in ipairs(es:GetChildren()) do
				if part:IsA("Part") and clean(part.Name) == wanted then
					table.insert(spawns, part:GetPivot())
				end
			end
		end
	end
	if #spawns == 0 then return false end
	if SpawnIndex > #spawns then SpawnIndex = 1 end

	local target = spawns[SpawnIndex]
	local dist = GetDistance(target.Position)
	if dist > 20 then
		toTarget(target * CFrame.new(0, dist > 150 and 65 or 30, 5))
	end
	SpawnIndex = SpawnIndex % #spawns + 1
	return true
end

local SpawnListIdx = 1
local function GoToSpawnAny(list)
	for i = 0, #list - 1 do
		local idx = (SpawnListIdx + i - 1) % #list + 1
		if GoToSpawn(list[idx]) then
			SpawnListIdx = idx
			return true
		end
	end
	SpawnListIdx = SpawnListIdx % #list + 1
	return false
end

local function DetectNpc(name)
	local root = GetRoot()
	if not root then return nil end
	local best, bd
	for _, folder in ipairs({ workspace.NPCs, RS.NPCs }) do
		for _, n in ipairs(folder:GetChildren()) do
			if n.Name == name and n:FindFirstChild("HumanoidRootPart") then
				local d = (n.HumanoidRootPart.Position - root.Position).Magnitude
				if not bd or d < bd then best, bd = n, d end
			end
		end
	end
	return best
end

----------------------------------------------------------------
-- Quest system
----------------------------------------------------------------
local function IsQuestOn()
	local gui = LP.PlayerGui:FindFirstChild("TrackedQuestFrame")
	return gui and gui.Frame.Visible or false
end

local function GetQuestInfo()
	local level = LP.Data.Level.Value
	local team = tostring(LP.Team)
	local root = GetRoot()
	local num, cf, taskKey, questName, reqLevel, mobName

	local function pack()
		return { Num = num, CFrame = cf, Task = taskKey, Quest = questName, Level = reqLevel, Mob = mobName }
	end

	if level >= 1 and level <= 9 then
		if team == "Marines" then
			num, questName, taskKey, mobName = 1, "MarineQuest", "Trainee", "Trainee"
			cf = CFrame.new(-2709.67944, 24.5206585, 2104.24585)
		else
			num, questName, taskKey, mobName = 1, "BanditQuest1", "Bandit", "Bandit"
			cf = CFrame.new(1059.99731, 16.9222069, 1549.28162)
		end
		reqLevel = 1
		return pack()
	end

	if level >= 210 and level <= 249 then
		num, questName, taskKey, mobName = 2, "PrisonerQuest", "Dangerous Prisoner", "Dangerous Prisoner"
		reqLevel = 210
		cf = CFrame.new(5308.93115, 1.65517521, 475.120514)
		return pack()
	end

	reqLevel = 0
	for npc, data in pairs(require(RS.GuideModule).Data.NPCList) do
		local levels = data.Levels
		for i = 1, #levels do
			local lv = levels[i]
			if level >= lv and lv > reqLevel then
				reqLevel = lv
				num = (#levels == 3 and i == 3) and 2 or i
				cf = npc.CFrame
			end
		end
	end

	if root and cf then
		local mag = (cf.Position - root.Position).Magnitude
		if level >= 375 and level <= 449 and mag > 3000 then
			FireRemote("requestEntrance", Vector3.new(61163.85, 11.6797, 1819.7842))
		elseif level >= 450 and level <= 474 and mag > 3000 then
			FireRemote("requestEntrance", Vector3.new(-4607.8228, 872.5425, -1667.5569))
		elseif level >= 475 and level <= 624 and mag > 5000 then
			FireRemote("requestEntrance", Vector3.new(-7894.6177, 5547.1416, -380.2912))
		end
	end

	local Quests = require(RS.Quests)
	for qName, quest in pairs(Quests) do
		if qName ~= "CitizenQuest" then
			for qNum, qData in pairs(quest) do
				if qData.LevelReq == reqLevel then
					questName = qName
					num = qNum
					for taskName in pairs(qData.Task) do
						taskKey = taskName
						mobName = string.split(taskName, " [Lv. " .. qData.LevelReq .. "]")[1]
					end
				end
			end
		end
	end

	if questName == "ImpelQuest" then
		questName, num = "PrisonerQuest", 2
		taskKey, mobName = "Dangerous Prisoner", "Dangerous Prisoner"
		reqLevel = 210
		cf = CFrame.new(5310.60547, 0.350014925, 474.946594)
	elseif questName == "Area2Quest" and num == 2 then
		num = 1
		taskKey, mobName = "Swan Pirate", "Swan Pirate"
		reqLevel = 775
	end

	if level >= 2500 and level <= 2524 then
		taskKey, mobName = "Sun-kissed Warrior", "Sun-kissed Warriors"
	end

	return pack()
end

local function GetQuestNPC(questName, id)
	local q = require(RS.Quests)[questName]
	local req = q and q[id] and q[id].LevelReq
	if not req then return nil end
	for npc, data in pairs(require(RS.GuideModule).Data.NPCList) do
		if table.find(data.Levels, req) then return npc.CFrame end
	end
end

local function TakeQuest(questName, num, cf)
	if cf and GetDistance(cf) > 8 then
		toTarget(cf * CFrame.new(0, 4, 2))
	else
		StopTween()
		FireRemote("StartQuest", questName, num)
		task.wait(0.5)
	end
end

----------------------------------------------------------------
-- Bring Mob
----------------------------------------------------------------
local function BringMobs(target, cf)
	if not Settings["Bring Mob"] then return end
	if not target or not target.Parent then return end

	local maxCount = tonumber(Settings["Bring Mob Count"]) or 2
	local radius = maxCount > 2 and 350 or 200
	local radiusSq = radius * radius
	local pos = cf.Position
	local count = 0

	pcall(function()
		sethiddenproperty(LP, "SimulationRadius", math.huge)
		sethiddenproperty(LP, "MaxSimulationRadius", math.huge)
	end)

	for _, mob in ipairs(Enemies:GetChildren()) do
		if count >= maxCount then break end
		if mob.Name == target.Name then
			local hum = mob:FindFirstChildOfClass("Humanoid")
			local hrp = mob:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 and mob:FindFirstChild("CharacterReady") then
				local diff = hrp.Position - pos
				if diff:Dot(diff) <= radiusSq and not hrp:GetAttribute("BeingBrought") then
					count += 1
					hrp:SetAttribute("BeingBrought", true)

					for _, d in ipairs(mob:GetDescendants()) do
						if d:IsA("BasePart") then
							d.CanCollide = false
							d.CanTouch = false
							d.Massless = true
						end
					end

					local lock = Instance.new("BodyVelocity")
					lock.Name = "Lock"
					lock.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
					lock.P = 9000
					lock.Velocity = Vector3.zero
					lock.Parent = hrp

					hum.AutoRotate = false
					pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)

					local goal = pos + Vector3.new(math.random(-20, 20) / 100, 0, math.random(-20, 20) / 100)
					local vec = goal - hrp.Position
					if vec.Magnitude > 0.5 then
						lock.Velocity = vec.Unit * math.clamp(vec.Magnitude * 10, 20, 1200)
					else
						lock.Velocity = Vector3.zero
						pcall(function() hrp.CFrame = CFrame.new(goal) end)
					end

					task.delay(0.12, function()
						pcall(function()
							if lock.Parent then lock:Destroy() end
							if hrp.Parent then hrp:SetAttribute("BeingBrought", false) end
						end)
					end)
				end
			end
		end
	end
end

----------------------------------------------------------------
-- Fast Attack
----------------------------------------------------------------
local function GetHits(range)
	local hits = {}
	local root = GetRoot()
	if not root then return hits end
	for _, folder in ipairs({ workspace.Enemies, workspace.Characters }) do
		for _, child in ipairs(folder:GetChildren()) do
			local hum = child:FindFirstChildOfClass("Humanoid")
			local hrp = child:FindFirstChild("HumanoidRootPart")
			if child ~= LP.Character and hum and hrp and hum.Health > 0
				and (hrp.Position - root.Position).Magnitude <= range then
				table.insert(hits, { child, child:FindFirstChild("Head") or hrp })
			end
		end
	end
	return hits
end

local FruitM1 = { last = 0, delay = 0 }

local function AttackOnce()
	local char = LP.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not tool then return end
	local tip = tool.ToolTip

	if tip == "Blox Fruit" and tool:FindFirstChild("LeftClickRemote") then
		local root = GetRoot()
		if not root then return end
		local now = tick()
		FruitM1.delay = (now - FruitM1.last <= 0.4) and math.min(FruitM1.delay + 1, 4) or 1
		FruitM1.last = now
		for _, mob in ipairs(Enemies:GetChildren()) do
			local hrp = mob:FindFirstChild("HumanoidRootPart")
			if hrp and IsAlive(mob) and (hrp.Position - root.Position).Magnitude <= 50 then
				tool.LeftClickRemote:FireServer((hrp.Position - root.Position).Unit, FruitM1.delay)
			end
		end
	elseif tip == "Melee" or tip == "Sword" then
		local hits = GetHits(60)
		if #hits > 0 then
			RegisterAttack:FireServer(0)
			local first = table.remove(hits, 1)
			RegisterHit:FireServer(first[2], hits, nil, HitKey)
		end
	end
end

task.spawn(function()
	while task.wait() do
		if Unloaded then break end
		if AnyFarmActive() or Settings["Auto Click"] then
			pcall(AttackOnce)
		end
	end
end)

----------------------------------------------------------------
-- Engage
----------------------------------------------------------------
local function FarmCF(hrp)
	if Settings["Select Weapon"] == "Blox Fruit" then
		return hrp.CFrame * CFrame.new(-7, 20, 0)
	end
	return hrp.CFrame * CFrame.new(7, 20, 0)
end

-- extraFn(mob) retorna true quando ela mesma cuida da arma (ex: mastery)
local function EngageEnemy(mob, flagName, extraFn)
	local hrp = mob and mob:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local bringCF = hrp.CFrame
	CurrentTarget = mob

	while not Unloaded and Options[flagName] and Options[flagName].Value and mob.Parent and IsAlive(mob) do
		RunService.Heartbeat:Wait()
		local mhrp = mob:FindFirstChild("HumanoidRootPart")
		if not mhrp then break end
		-- sizepart
		if GetDistance(mhrp.Position) <= 50 then
			for _, d in ipairs(mob:GetDescendants()) do
				if d:IsA("BasePart") and d.CanCollide then d.CanCollide = false end
			end
		end
		local handled = extraFn and extraFn(mob)
		if not handled then EquipWeapon() end
		ActivateHaki()
		BringMobs(mob, bringCF)
		toTarget(FarmCF(mhrp))
	end
	CurrentTarget = nil
end

----------------------------------------------------------------
-- Generic loop
----------------------------------------------------------------
local function CreateLoop(flagName, fn, delay)
	task.spawn(function()
		while not Unloaded do
			if Options[flagName] and Options[flagName].Value then
				local ok, err = pcall(fn)
				if not ok then warn("[W-AZURE] " .. flagName .. ": " .. tostring(err)) end
			end
			task.wait(delay or 0)
		end
	end)
end

----------------------------------------------------------------
-- HopServer (um hop por chamada)
----------------------------------------------------------------
local LastHop = 0
local function HopServer()
	local cooldown = tonumber(Settings["Time Hop Server"]) or 10
	if tick() - LastHop < math.max(cooldown, 5) then return end
	LastHop = tick()
	for page = 1, 100 do
		local ok, list = pcall(function() return RS.__ServerBrowser:InvokeServer(page) end)
		if ok and type(list) == "table" then
			for id in pairs(list) do
				if id ~= game.JobId then
					RS.__ServerBrowser:InvokeServer("teleport", id)
					return
				end
			end
		end
	end
end

----------------------------------------------------------------
-- Mastery
----------------------------------------------------------------
local function FarmMastery(mob)
	getgenv().AimPos = mob.HumanoidRootPart.CFrame
	if not Settings["Farm Mastery"] then return false end
	local hum = mob:FindFirstChild("Humanoid")
	if not hum then return false end
	if hum.Health / hum.MaxHealth > (Settings["Health %"] or 40) / 100 then return false end
	local tool = GetTool(Settings["Select Method Farm Mastery"] or "Blox Fruit")
	if not tool then return false end
	if tool.Parent ~= LP.Character then
		EquipTool(tool)
		return true
	end
	UseSkills(tool)
	return true
end

----------------------------------------------------------------
-- TAB MAIN  (Farming do Banana)
----------------------------------------------------------------
local BONES = { "Reborn Skeleton", "Demonic Soul", "Living Zombie", "Posessed Mummy" }
local KATAKURI = { "Baking Staff", "Head Baker", "Cake Guard", "Cookie Crafter" }
local TYRANT = { "Isle Champion", "Serpent Hunter", "Skull Slayer", "Sun-kissed Warrior" }

local NameMaterials = {
	Ectoplasm = { "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer", "Cursed Captain" },
	["Magma Ore"] = { "Lava Pirate", "Magma Ninja" },
	Leather = { "Jungle Pirate", "Musketeer Pirate" },
	["Scrap Metal"] = { "Jungle Pirate" },
	["Angel Wings"] = { "God's Guard", "Shanda", "Royal Squad", "Royal Soldier" },
	["Fish Tail"] = { "Fishman Raider", "Fishman Captain" },
	["Radioactive Material"] = { "Factory Staff" },
	["Vampire Fang"] = { "Vampire" },
	["Mystic Droplet"] = { "Sea Soldier", "Water Fighter" },
	["Mini Tusk"] = { "Mythological Pirate" },
	Gunpowder = { "Pistol Billionaire" },
	["Demonic Wisp"] = { "Demonic Soul" },
	["Dragon Scale"] = { "Dragon Crew Archer", "Dragon Crew Warrior" },
	["Conjured Cocoa"] = { "Cocoa Warrior", "Chocolate Bar Battler" },
	Bones = { "Reborn Skeleton", "Demonic Soul", "Living Zombie", "Posessed Mummy" },
}
local MaterialSea = {
	Ectoplasm = 2, ["Magma Ore"] = 2, Leather = 3, ["Scrap Metal"] = 3, ["Angel Wings"] = 1,
	["Fish Tail"] = 3, ["Radioactive Material"] = 2, ["Vampire Fang"] = 2, ["Mystic Droplet"] = 2,
	["Mini Tusk"] = 3, Gunpowder = 3, ["Demonic Wisp"] = 3, ["Dragon Scale"] = 3, ["Conjured Cocoa"] = 3, Bones = 3,
}
local TravelByName = { [1] = "TravelMain", [2] = "TravelDressrosa", [3] = "TravelZou" }
local TableMaterials = {}
for k in pairs(NameMaterials) do table.insert(TableMaterials, k) end
table.sort(TableMaterials)

local function DetectMobAura()
	local range = tonumber(Settings["Distance Farm Aura"]) or 300
	local root = GetRoot()
	if not root then return nil end
	local best, bd = nil, range
	for _, m in ipairs(Enemies:GetChildren()) do
		if IsAlive(m) and m:FindFirstChild("HumanoidRootPart") then
			local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
			if d < bd then
				bd, best = d, m.Name:match("^(.-)%s*%[") or m.Name
			end
		end
	end
	return best
end

local function FarmMethod()
	if FruitState.Active or not IsAlive(LP.Character) then return end

	local method = Settings["Select Method Farm"] or "Level Farm"
	local mobs, minLv, qName, qId, isLevel

	if Settings["Farm Material"] then
		local mat = Settings["Select Material"]
		if not mat or not NameMaterials[mat] then return end
		local sea = MaterialSea[mat]
		if sea ~= CurrentSea() then
			FireRemote(TravelByName[sea])
			task.wait(3)
			return
		end
		mobs = NameMaterials[mat]
	elseif method == "Farm Bones" then
		mobs, minLv, qName, qId = BONES, 2050, "HauntedQuest2", 2
	elseif method == "Farm Katakuri" then
		mobs, minLv, qName, qId = KATAKURI, 2275, "CakeQuest2", 2
	elseif method == "Farm Tyrant of the Skies" then
		mobs, minLv, qName, qId = TYRANT, 2575, "TikiQuest3", 3
	elseif method == "Aura Farm" then
		local n = DetectMobAura()
		mobs = n and { n } or nil
	else
		isLevel = true
	end

	-- Level Farm: pega a quest do nivel
	if isLevel then
		local info = GetQuestInfo()
		if not info or not info.Mob then return end
		if not IsQuestOn() then
			TakeQuest(info.Quest, info.Num, info.CFrame)
			return
		end
		mobs = { info.Mob }
	else
		if qName and Settings["Auto Quest [Katakuri/Bone/Tyrant]"] and LP.Data.Level.Value >= minLv and not IsQuestOn() then
			TakeQuest(qName, qId, GetQuestNPC(qName, qId))
			return
		end
	end

	-- Bosses das rotas
	if not Settings["Farm Material"] then
		if method == "Farm Katakuri" and not Settings["Ignore Attack Katakuri"] then
			local boss = CheckNameBoss("Cake Prince")
			if boss then
				EngageEnemy(boss, "Start Farm")
				return
			elseif Settings["Hop Find Katakuri"] then
				task.spawn(HopServer)
			end
		elseif method == "Farm Tyrant of the Skies" then
			local boss = CheckNameBoss("Tyrant of the Skies")
			if boss then
				EngageEnemy(boss, "Start Farm")
				return
			end
		end
	end

	if not mobs then return end
	local mob = FindEnemy(mobs)
	if mob then
		EngageEnemy(mob, "Start Farm", FarmMastery)
		if getgenv().QuestTrainer and getgenv().QuestTrainer.CountKillMob then
			getgenv().QuestTrainer.CountKillMob += 1
		end
	else
		GoToSpawnAny(mobs)
		task.wait(0.5)
	end
end

Para(Tabs.Main, "Setting Farm", "Metodo de farm, aura, quests e hop.")
Dd(Tabs.Main, "Select Method Farm", { "Level Farm", "Farm Bones", "Farm Katakuri", "Farm Tyrant of the Skies", "Aura Farm" }, "Level Farm")
Sl(Tabs.Main, "Distance Farm Aura", 0, 1000, 300)
Tg(Tabs.Main, "Ignore Attack Katakuri")
Tg(Tabs.Main, "Hop Find Katakuri")
Tg(Tabs.Main, "Auto Quest [Katakuri/Bone/Tyrant]")
Tg(Tabs.Main, "Start Farm", "Inicia o farm do metodo escolhido")
CreateLoop("Start Farm", FarmMethod, 0)

Para(Tabs.Main, "Mastery Farm", "Usa fruta/arma com a vida do mob abaixo de Health %.")
Dd(Tabs.Main, "Select Method Farm Mastery", { "Blox Fruit", "Gun" }, "Blox Fruit")
Sl(Tabs.Main, "Health %", 0, 100, 40)
local tgMastery = Tg(Tabs.Main, "Farm Mastery")
tgMastery:OnChanged(function()
	if tgMastery.Value and not Options["Start Farm"].Value then Noti("Turn On Start Farm Plz") end
end)

Para(Tabs.Main, "Farming Material", "Farma o material escolhido (troca de mar automatico).")
Dd(Tabs.Main, "Select Material", TableMaterials, nil)
local tgMat = Tg(Tabs.Main, "Farm Material")
tgMat:OnChanged(function()
	if tgMat.Value and not Options["Start Farm"].Value then Noti("Turn On Start Farm Plz") end
end)

----------------------------------------------------------------
-- TAB MISSIONS (mantida)
----------------------------------------------------------------
Para(Tabs.Missions, "Auto Elite Boss", "Farma os bosses elite (Diablo, Deandre, Urban) e pega a quest do Elite Hunter.")
Tg(Tabs.Missions, "AutoEliteBoss", "Farms elite bosses automatically")
CreateLoop("AutoEliteBoss", function()
	if not IsAlive(LP.Character) then return end
	local boss = FindEnemy({ "Diablo", "Deandre", "Urban" })
	if boss and IsQuestOn() then
		EngageEnemy(boss, "AutoEliteBoss")
	else
		if HasTool("God's Chalice") then
			FireRemote("requestEntrance", Vector3.new(-12471.17, 374.94025, -7551.6777))
			return
		end
		if not IsQuestOn() then
			FireRemote("EliteHunter")
		end
	end
end, 0.5)

Para(Tabs.Missions, "Auto Yama", "Farma elite ate o progresso 30 e pega a Yama na Waterfall.")
Tg(Tabs.Missions, "AutoYama", "Fetches Yama once Elite Hunter progress is 30")

local function FindYamaKatana()
	local map = workspace:FindFirstChild("Map")
	local waterfall = map and map:FindFirstChild("Waterfall")
	return waterfall and waterfall:FindFirstChild("SealedKatana")
end

CreateLoop("AutoYama", function()
	if not IsAlive(LP.Character) then return end
	if HasTool("Yama") then return end
	local progress = tonumber(FireRemote("EliteHunter", "Progress")) or 0
	if progress >= 30 then
		local katana = FindYamaKatana()
		if katana and katana:FindFirstChild("Handle") then
			local handle = katana.Handle
			if GetDistance(handle.CFrame) > 8 then
				toTarget(handle.CFrame)
			else
				local cd = handle:FindFirstChild("ClickDetecter") or handle:FindFirstChild("ClickDetector")
				if cd then fireclickdetector(cd) end
			end
		end
		return
	end
	if Options.AutoEliteBoss and Options.AutoEliteBoss.Value then return end
	local boss = FindEnemy({ "Diablo", "Deandre", "Urban" })
	if boss and IsQuestOn() then
		EngageEnemy(boss, "AutoYama")
	elseif not IsQuestOn() then
		FireRemote("EliteHunter")
	end
end, 0.5)

----------------------------------------------------------------
-- BOATS / SEA EVENT helpers
----------------------------------------------------------------
local BoatTweens = {}
local RoughV = 0

function CancelBoat(key)
	if key then
		local t = BoatTweens[key]
		if t then t.cancel = true BoatTweens[key] = nil end
	else
		for _, t in pairs(BoatTweens) do t.cancel = true end
		table.clear(BoatTweens)
	end
end

local function manageTween(part, cf, speed, key)
	if not part or typeof(cf) ~= "CFrame" then return end
	key = key or "TweenBoat"
	speed = tonumber(Settings["Value Speed Tween Boat"]) or speed or 350
	local cur = BoatTweens[key]
	if cur and cur.part == part then
		cur.target, cur.speed = cf, speed
		return cur
	end
	CancelBoat(key)
	local h = { part = part, target = cf, speed = speed }
	BoatTweens[key] = h
	task.spawn(function()
		while not h.cancel and part.Parent do
			local dt = RunService.Heartbeat:Wait()
			local hum = GetHum()
			if not hum or hum.SeatPart ~= part then break end
			local pos, goal = part.Position, h.target.Position
			local d = (goal - pos).Magnitude
			local step = h.speed * dt
			if d <= step or d < 5 then
				part.CFrame = h.target
				part.AssemblyLinearVelocity = Vector3.zero
				break
			end
			part.CFrame = CFrame.new(pos + (goal - pos).Unit * step) * part.CFrame.Rotation
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
		if BoatTweens[key] == h then BoatTweens[key] = nil end
	end)
	return h
end

local function checkboat()
	for _, b in ipairs(workspace.Boats:GetChildren()) do
		if b:IsA("Model") and b:FindFirstChild("Owner") and tostring(b.Owner.Value) == LP.Name
			and b:FindFirstChild("Humanoid") and b.Humanoid.Value > 0 and b:FindFirstChild("VehicleSeat") then
			return b
		end
	end
	return false
end

local function NoclipBoat(boat)
	for _, p in ipairs(boat:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
	end
end

local function BuyPoint()
	if CurrentSea() == 3 then
		return CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375)
	end
	return CFrame.new(-13.488054275512695, 10.311711311340332, 2927.692)
end

local Zones = {
	["Zone 1"] = CFrame.new(-21767.4765625, 0, 5815.41259765625),
	["Zone 2"] = CFrame.new(-26017.931640625, 0, 5657.8837890625),
	["Zone 3"] = CFrame.new(-29545.703125, 0, 6377.98974609375),
	["Zone 4"] = CFrame.new(-33609.7578125, 0, 7422.890625),
	["Zone 5"] = CFrame.new(-38480.42578125, 0, 10350.943359375),
	["Zone 6"] = CFrame.new(-32975.9921875, 0, 25963.7109375),
}
local function SelectedZoneCFrame()
	return Zones[Settings["Select Zone"] or "Zone 1"] or Zones["Zone 1"]
end

local function DecectPartRoughSea()
	local ok, res = pcall(function()
		for _, p in ipairs(workspace._WorldOrigin.Locations:GetChildren()) do
			if p.Name == "Rough Sea" and GetDistance(p.Position) <= 3000
				and Vector3.new(0.001, 0.001, 0.001) ~= workspace._WorldOrigin.RainEmitterPart.Size
				and not p:FindFirstChild("Ignored") then
				return p
			end
		end
	end)
	return ok and res or nil
end

local function BuyBoatNamed(name)
	FireRemote("BuyBoat", (name == "Brigade" or name == "GrandBrigade") and ("Pirate" .. name) or name)
	task.wait(3)
end

-- Compra barco, senta e navega para longe ate doneFn() ser verdadeiro
local function SailSearch(boatBuy, flag, doneFn, canBuy)
	local boat = checkboat()
	local buyCF = BuyPoint()
	local hum = GetHum()
	if not hum then return end
	if not boat or GetDistance(boat.VehicleSeat.Position) >= 4000 then
		if canBuy == false then return end
		if GetDistance(buyCF) > 8 then
			toTarget(buyCF)
		else
			FireRemote("BuyBoat", boatBuy)
			task.wait(3)
		end
		return
	end
	if hum.Sit then
		local far = CFrame.new(-118834.515625, 160, -78.9505844116211) * CFrame.new(0, 0, 99999999)
		repeat
			task.wait(0.5)
			NoclipBoat(boat)
			manageTween(boat.VehicleSeat, far, 350, "TweenBoat")
		until not Settings[flag] or not hum.Sit or doneFn()
		CancelBoat()
	else
		CancelBoat()
		toTarget(boat.VehicleSeat.CFrame)
	end
end

-- Eventos do mar
local function BeastMax(b)
	local t = b.HealthBBG.Frame.TextLabel.Text
	return tonumber(((t:match("/([%d,]+)") or "0"):gsub(",", ""))) or 0
end

local function DetectSeaEvents(all)
	local sel = Settings["Select Sea Events"] or {}
	if all or sel.SeaBeast then
		for _, c in ipairs(workspace.SeaBeasts:GetChildren()) do
			if c.Name == "SeaBeast1" and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChild("HealthBBG")
				and BeastMax(c) >= 90000 and GetDistance(c.HumanoidRootPart.Position) < 2000 then
				return c
			end
		end
	end
	if all or sel.Terrorshark then
		local b = CheckNameBoss("Terrorshark")
		if b and GetDistance(b.HumanoidRootPart.Position) < 2000 then return b end
	end
	if all or sel.Ship then
		for _, c in ipairs(Enemies:GetChildren()) do
			if c:FindFirstChild("Engine") and c:FindFirstChild("Health") and c.Health.Value > 0
				and GetDistance(c.Engine.Position) < 2000 then
				if sel["Only Farm Ship Brigade"] then
					if c.Name == "PirateBrigade" or c.Name == "PirateGrandBrigade" then return c end
				else
					return c
				end
			end
		end
	end
	if all or sel.Shark then
		local s = FindEnemy({ "Fish Crew Member", "Shark" })
		if s and GetDistance(s.HumanoidRootPart.Position) < 2000 then return s end
	end
	if all or sel.Piranha then
		local p = FindEnemy("Piranha")
		if p and GetDistance(p.HumanoidRootPart.Position) < 2000 then return p end
	end
	return false
end

local function TeleportSeaEvents(t)
	if not t then return end
	if t:FindFirstChild("Engine") and t:FindFirstChild("Health") and t.Health.Value > 0 then
		local y = Settings["Use Click M1 Fruit For Sea Event"] and -25 or -15
		toTarget(t.Engine.CFrame * CFrame.new(0, y, 0))
		return
	end
	if t.Name == "SeaBeast1" and t:FindFirstChild("HumanoidRootPart") then
		local hrp = t.HumanoidRootPart
		if Vector3.new(0, hrp.Position.Y, 0) - Vector3.new(0, -60, 0) == Vector3.zero or
			(Vector3.new(0, hrp.Position.Y, 0) - Vector3.new(0, -60, 0)).Magnitude <= 175 then
			toTarget(hrp.CFrame * CFrame.new(0, 200, Settings["Use Click M1 Fruit For Sea Event"] and 0 or 50))
		else
			toTarget(CFrame.new(hrp.Position.X, 140, hrp.Position.Z))
		end
	else
		local up = (not Settings["Use Click M1 Fruit For Sea Event"] and t.Name == "Terrorshark") and 60 or 20
		if t:FindFirstChildWhichIsA("Humanoid") and t.Humanoid.Health > 0 then
			toTarget(t.HumanoidRootPart.CFrame * CFrame.new(0, up, 0))
		end
	end
end

local function BoatRoutine()
	local boat = checkboat()
	local buyCF = BuyPoint()
	local hum = GetHum()
	if not hum then return end

	if not boat or GetDistance(boat.VehicleSeat.Position) >= 4000 then
		if GetDistance(buyCF) > 8 then
			toTarget(buyCF)
		else
			local name = Settings["Select Boat"]
			if not name then Noti("Escolha o barco em Select Boat") task.wait(3) return end
			BuyBoatNamed(name)
		end
		return
	end

	task.spawn(NoclipBoat, boat)
	local seat = boat.VehicleSeat

	if Settings["Tween Until Have Sea Event"] then
		local far = CFrame.new(-118834.515625, boat.WorldPivot.Y, 999920.0494155884)
		if not hum.Sit then toTarget(seat.CFrame) else manageTween(seat, far, 350, "TweenBoat") end
		return
	end

	local rs = DecectPartRoughSea()
	if rs then
		task.wait(1)
		RoughV = RoughV == 0 and 7000 or 0
		Instance.new("IntValue", rs).Name = "Ignored"
		task.wait(0.5)
	end
	local rough = Settings["Teleport Boat Other CFrame if Rough Sea"] and RoughV or 0
	local zone = CurrentSea() == 3 and (SelectedZoneCFrame() * CFrame.new(0, boat.WorldPivot.Y, rough))
		or CFrame.new(654.3875732421875, boat.WorldPivot.Y, 6321.95947265625)

	if (seat.Position - zone.Position).Magnitude > 200 then
		local c = CFrame.new(zone.Position.X, boat.WorldPivot.Y, zone.Position.Z)
		if not hum.Sit then toTarget(seat.CFrame) else manageTween(seat, c, 350, "TweenBoat") end
		return
	end

	-- reparo
	if Settings["Auto Repair Ur Ship"] then
		local ok, bar = pcall(function() return LP.PlayerGui.Main.BottomHUDList.ShipHealthBar end)
		if ok and bar.Visible then
			local txt = string.split(string.gsub(bar.TextLabel.Text, "Ship ", ""), "/")
			if tonumber(txt[1]) and tonumber(txt[2]) and tonumber(txt[1]) < tonumber(txt[2]) then
				if GetDistance(boat.PrimaryPart.Position) < 20 and not hum.Sit then
					local hammer = LP.Character:FindFirstChild("_RepairHammer")
					if hammer then
						if hammer:FindFirstChild("M1UP") then
							hammer.M1UP:Destroy()
						elseif not hammer:GetAttribute("Repairing") then
							hammer.M1Down:FireServer("Default")
							task.wait(0.5)
						end
					else
						RS.Remotes.SubclassNetwork.UseSubclass:InvokeServer({ Action = "RequestHammer" })
						task.wait(3)
					end
				else
					toTarget(boat.PrimaryPart.CFrame * CFrame.new(0, 15, 0))
				end
				return
			end
		end
	end

	if not hum.Sit then toTarget(seat.CFrame) end
	if DetectSeaEvents(true) then
		local t0 = tick()
		repeat
			task.wait()
			toTarget(CFrame.new(zone.Position.X, boat.WorldPivot.Y, zone.Position.Z) * CFrame.new(0, 2500, 0))
		until tick() - t0 >= 12
	elseif hum.Sit then
		manageTween(seat, CFrame.new(zone.Position.X, boat.WorldPivot.Y, zone.Position.Z), 350, "TweenBoat")
	end
end

local function AutoSeabeast()
	local sel = Settings["Select Sea Events"] or {}
	local any = false
	for k, v in pairs(sel) do
		if v and k ~= "Only Farm Ship Brigade" then any = true break end
	end
	if not any then Noti("Selecione um evento em Select Sea Events") task.wait(3) return end

	local target = DetectSeaEvents()
	if not target then
		BoatRoutine()
		return
	end
	CancelBoat()
	repeat
		task.wait()
		TeleportSeaEvents(target)
		local part = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Engine")
		if part then
			if target.Name == "SeaBeast1" then
				getgenv().AimPos = CFrame.new(part.Position.X, 40, part.Position.Z)
			else
				local r = GetRoot()
				if r then getgenv().AimPos = CFrame.new(r.Position.X, -58, r.Position.Z) end
			end
			if Settings["Use Click M1 Fruit For Sea Event"] then
				FruitM1At(part.Position)
			elseif target:FindFirstChildWhichIsA("Humanoid") then
				EquipWeapon()
			elseif GetDistance(part.Position) < 400 then
				AutoUseSkillWeapons(Settings["Select Weapons Use Skill"])
			end
		end
	until not target or not target.Parent or not Settings["Auto Sea Event"]
		or (target:FindFirstChild("Health") and target.Health.Value == 0)
		or (target:FindFirstChildWhichIsA("Humanoid") and target.Humanoid.Health == 0)
end

----------------------------------------------------------------
-- TAB SEA EVENT
----------------------------------------------------------------
Para(Tabs.SeaEvent, "Setting", "Configuracao do Sea Event.")
Dd(Tabs.SeaEvent, "Select Zone", { "Zone 1", "Zone 2", "Zone 3", "Zone 4", "Zone 5", "Zone 6" }, "Zone 1")
Dd(Tabs.SeaEvent, "Select Sea Events", { "SeaBeast", "Ship", "Shark", "Terrorshark", "Piranha", "Only Farm Ship Brigade" }, {}, true)
Dd(Tabs.SeaEvent, "Select Boat", { "Beast Hunter", "Guardian", "Lantern", "Seleigh", "Brigade", "GrandBrigade" }, "Brigade")
Dd(Tabs.SeaEvent, "Select Weapons Use Skill", { "Melee", "Sword", "Gun", "Blox Fruit" }, {}, true)
Tg(Tabs.SeaEvent, "Use Click M1 Fruit For Sea Event")
Tg(Tabs.SeaEvent, "Teleport Boat Other CFrame if Rough Sea")
Tg(Tabs.SeaEvent, "Tween Until Have Sea Event", "Para para lutar quando aparece evento e depois continua")
Sl(Tabs.SeaEvent, "Value Speed Tween Boat", 50, 2000, 350)

Para(Tabs.SeaEvent, "Farming", "Auto Sea Event")
Tg(Tabs.SeaEvent, "Auto Repair Ur Ship")
Tg(Tabs.SeaEvent, "Auto Sea Event")
CreateLoop("Auto Sea Event", AutoSeabeast, 0)

Tg(Tabs.SeaEvent, "Auto Find Mirage")
CreateLoop("Auto Find Mirage", function()
	if workspace.Map:FindFirstChild("MysticIsland") then
		CancelBoat()
		Noti("Mirage Island Spawned")
		Options["Auto Find Mirage"]:SetValue(false)
		task.wait(5)
		return
	end
	SailSearch("PirateBrigade", "Auto Find Mirage", function() return workspace.Map:FindFirstChild("MysticIsland") end)
end, 0.1)

----- Kitsune
Para(Tabs.SeaEvent, "Kitsune Event", "Ilha da Kitsune e Azure Ember.")
Tg(Tabs.SeaEvent, "Teleport To Kitsune Island")
Tg(Tabs.SeaEvent, "Hop Server Kitsune Island", "Hop se nao for Next Night / perto da Full Moon")
Tg(Tabs.SeaEvent, "Auto Spawn Kitsune Island", "Ligue depois que o status for Full Moon")
Tg(Tabs.SeaEvent, "Auto Summon Soul Ember")
Tg(Tabs.SeaEvent, "Auto Collect Soul Ember")
Sl(Tabs.SeaEvent, "Values Azure Ember", 0, 25, 10)
Tg(Tabs.SeaEvent, "Auto Trade Azure Ember")

local function CheckMoon()
	local ok, id = pcall(function()
		return game.Lighting:FindFirstChild("Sky") and game.Lighting.Sky.MoonTextureId or game.Lighting.FantasySky.MoonTextureId
	end)
	if not ok then return "Bad Moon" end
	if id == "http://www.roblox.com/asset/?id=9709149431" then return "Full Moon" end
	if id == "http://www.roblox.com/asset/?id=9709149052" then return "Next Night" end
	return "Bad Moon"
end

local function KitsuneReady()
	local k = workspace.Map:FindFirstChild("KitsuneIsland")
	return k and k.ShrineDialogPart.ProximityPrompt.Enabled
end

local function AutoSpawnKitsune()
	local clock = game.Lighting.ClockTime
	local boat = checkboat()
	local hum = GetHum()
	if Settings["Hop Server Kitsune Island"] then
		local moon = CheckMoon()
		local okTime = (moon == "Full Moon" and math.floor(18 - clock) <= 5 and math.floor(18 - clock) >= 0)
			or moon == "Next Night" or (moon == "Full Moon" and clock <= 5)
		if not okTime then HopServer() return end
	end
	if not boat then
		local buyCF = BuyPoint()
		if GetDistance(buyCF) > 8 then
			toTarget(buyCF)
		else
			local name = Settings["Select Boat"]
			if not name then Noti("Escolha o barco em Select Boat") return end
			BuyBoatNamed(name)
		end
		return
	end
	NoclipBoat(boat)
	local seat = boat.VehicleSeat
	local goal = CFrame.new(-32975.9921875, boat.WorldPivot.Y, 25963.7109375) * CFrame.new(0, 0, 1000)
	if CheckMoon() == "Full Moon" and math.floor(18 - clock) <= 0 then
		if (seat.Position - goal.Position).Magnitude > 200 then
			if not hum.Sit then toTarget(seat.CFrame) else manageTween(seat, goal, 350, "TweenBoat") end
		elseif not hum.Sit then
			toTarget(seat.CFrame)
		end
	else
		if (seat.Position - goal.Position).Magnitude > 200 then
			manageTween(seat, goal, 350, "TweenBoat")
		end
		toTarget(goal * CFrame.new(0, 2000, 0))
	end
end

task.spawn(function()
	while not Unloaded do
		task.wait(0.1)
		pcall(function()
			local hud = LP.PlayerGui.Main.TopHUDList
			if Settings["Teleport To Kitsune Island"] then
				local loc = workspace._WorldOrigin.Locations:FindFirstChild("Kitsune Island")
				if loc then toTarget(loc.CFrame) end
			end
			if Settings["Auto Spawn Kitsune Island"] and not KitsuneReady() then
				AutoSpawnKitsune()
			end
			if Settings["Auto Collect Soul Ember"] and hud.RaidTimer.Visible then
				local ember
				for _, c in ipairs(workspace:GetChildren()) do
					if c.Name == "EmberTemplate" and c:FindFirstChild("Part") then ember = c break end
				end
				if ember then
					if GetDistance(ember.Part.Position) > 100 then toTarget(ember.Part.CFrame)
					else GetRoot().CFrame = ember.Part.CFrame end
				else
					local loc = workspace._WorldOrigin.Locations:FindFirstChild("Kitsune Island")
					if loc then toTarget(loc.CFrame) end
				end
			end
			if Settings["Auto Summon Soul Ember"] and not hud.RaidTimer.Visible and KitsuneReady() then
				local shrine = workspace.Map.KitsuneIsland.ShrineInactive
				if GetDistance(shrine.WorldPivot.Position) >= 10 then
					toTarget(shrine.WorldPivot)
				else
					Net:FindFirstChild("RE/TouchKitsuneStatue"):FireServer()
					task.wait(5)
				end
			end
			if Settings["Auto Trade Azure Ember"] and hud.RaidTimer.Visible
				and CheckCountItem("Azure Ember", tonumber(Settings["Values Azure Ember"]) or 10) then
				Net:FindFirstChild("RF/KitsuneStatuePray"):InvokeServer()
				task.wait(5)
			end
		end)
	end
end)

----- Leviathan
Para(Tabs.SeaEvent, "Leviathan Event", "Spy, achar, iniciar e atacar o Leviathan.")

local function StatusCheckLeviathan()
	if CurrentSea() ~= 3 then return "..." end
	local r = FireRemote("InfoLeviathan", "1")
	if r == -1 then return "I DONT KNOW" end
	return r == 5 and "You can find leviathan now" or "Buy Find leviathan"
end

Tabs.SeaEvent:AddButton({
	Title = "Buy Spy",
	Callback = function()
		pcall(function()
			local d = require(RS.DialoguesList).Spy
			require(RS.DialogueController):Start(d)
		end)
	end,
})
Tg(Tabs.SeaEvent, "Auto Buy Spy")
CreateLoop("Auto Buy Spy", function()
	if StatusCheckLeviathan() == "Buy Find leviathan" then
		FireRemote("InfoLeviathan", "1")
		FireRemote("InfoLeviathan", "2")
	end
end, 5)

Tg(Tabs.SeaEvent, "Auto Buy Boat Beast Hunter")
Tg(Tabs.SeaEvent, "Auto Find Leviathan")
CreateLoop("Auto Find Leviathan", function()
	if workspace._WorldOrigin.Locations:FindFirstChild("Frozen Dimension") then
		CancelBoat()
		Noti("Frozen Dimension Spawned")
		task.wait(5)
		return
	end
	SailSearch("Beast Hunter", "Auto Find Leviathan", function()
		return workspace._WorldOrigin.Locations:FindFirstChild("Frozen Dimension")
	end, Settings["Auto Buy Boat Beast Hunter"])
end, 0.1)

Tg(Tabs.SeaEvent, "Auto Start Leviathan")
CreateLoop("Auto Start Leviathan", function()
	if workspace._WorldOrigin.Locations:FindFirstChild("Frozen Dimension") then
		local watcher = DetectNpc("Frozen Watcher")
		if watcher then
			if GetDistance(watcher.HumanoidRootPart.Position) < 8 then
				FireRemote("OpenLeviathanGate")
			else
				toTarget(watcher.HumanoidRootPart.CFrame)
			end
		end
	end
end, 2.5)

Tg(Tabs.SeaEvent, "Use Click M1 Fruit Leviathan")
Tg(Tabs.SeaEvent, "Auto Attack Leviathan")

local function DetectLeviathan()
	local sb = workspace.SeaBeasts
	for _, p in ipairs(sb:GetChildren()) do
		if p.Name == "Leviathan Tail" and p:GetAttribute("HealthEnabled") and p:FindFirstChild("Health") and p.Health.Value > 0 then return p end
	end
	for _, p in ipairs(sb:GetChildren()) do
		if p.Name == "Leviathan" and not p:GetAttribute("Armored") and p:FindFirstChild("Health") and p.Health.Value > 0 then return p end
	end
	for _, p in ipairs(sb:GetChildren()) do
		if p.Name == "Leviathan Segment" and p:FindFirstChild("Health") and p.Health.Value > 0 then return p end
	end
end

CreateLoop("Auto Attack Leviathan", function()
	local b = DetectLeviathan()
	if not b then return end
	repeat
		task.wait()
		local hb = b:FindFirstChild("Hitbox11")
		local hrp = b:FindFirstChild("HumanoidRootPart")
		if not hb or not hrp then break end
		getgenv().AimPos = hb.CFrame
		toTarget(CFrame.new(hrp.Position.X, b.Name == "Leviathan" and 140 or 142, hrp.Position.Z))
		if Settings["Use Click M1 Fruit Leviathan"] then
			FruitM1At(hb.Position)
		elseif GetDistance(hb.Position) < 400 then
			AutoUseSkillWeapons(Settings["Select Weapons Use Skill"])
		end
	until not b.Parent or b.Health.Value == 0 or not Settings["Auto Attack Leviathan"]
end, 0.1)

----------------------------------------------------------------
-- TAB VOLCANO
----------------------------------------------------------------
Para(Tabs.Volcano, "Settings Volcano", "Armas e metodo para golem e lava.")
Dd(Tabs.Volcano, "Select Weapon Kill Golem", { "Melee", "Sword", "Blox Fruit" }, "Melee")
Dd(Tabs.Volcano, "Select Weapons Fix Lava", { "Melee", "Sword", "Gun", "Blox Fruit" }, {}, true)
Dd(Tabs.Volcano, "Select Method Kill Golem", { "Click M1", "Instant Kill [ Risk and can bug no die mob ]" }, "Click M1")

local ROCK_OFF = {
	[273] = CFrame.new(40, 0, 0), [286] = CFrame.new(40, 0, 0), [246] = CFrame.new(0, -40, 0),
	[486] = CFrame.new(40, 0, 0), [364] = CFrame.new(40, 0, 0), [682] = CFrame.new(0, 0, -40),
	[490] = CFrame.new(0, 40, 0), [691] = CFrame.new(40, 0, 0), [502] = CFrame.new(-40, 0, 0),
	[256] = CFrame.new(-40, 0, 0), [290] = CFrame.new(0, 40, 0), [427] = CFrame.new(0, 40, 0),
	[692] = CFrame.new(0, 0, 40), [316] = CFrame.new(0, 40, 0), [481] = CFrame.new(0, 40, 0),
	[594] = CFrame.new(0, 40, 0), [649] = CFrame.new(40, 0, 0), [285] = CFrame.new(0, -40, 0),
	[250] = CFrame.new(0, 40, 0), [454] = CFrame.new(-40, 0, 0),
}

local function KillRaidEnemy()
	for _, e in ipairs(Enemies:GetChildren()) do
		if IsAlive(e) and e:FindFirstChild("HumanoidRootPart") and GetDistance(e.HumanoidRootPart.Position) < 50 then
			e.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		end
	end
end

local KillAuraBusy = false
local function KillAuraOnce(mob)
	if KillAuraBusy or not Settings["Kill Aura Only Raid And Volcano"] then return end
	KillAuraBusy = true
	pcall(function() mob.Humanoid:ChangeState(Enum.HumanoidStateType.Dead) end)
	task.delay(Settings["Time Delay Kill"] or 5, function() KillAuraBusy = false end)
end

local function DetectGolem()
	for _, b in ipairs(Enemies:GetChildren()) do
		if b.Name == "Lava Golem" and IsAlive(b) and GetDistance(b.HumanoidRootPart.Position) <= 1500 then return b end
	end
end

local function DetectRockVolcano()
	local ok, rocks = pcall(function() return workspace.Map.PrehistoricIsland.Core.VolcanoRocks:GetChildren() end)
	if not ok then return nil end
	local best, bd = nil, math.huge
	for _, r in ipairs(rocks) do
		if r.Name == "Rock" and r:FindFirstChild("VFXLayer") and r.VFXLayer:FindFirstChild("Specs") and r.VFXLayer.Specs.Enabled then
			local d = GetDistance(r.WorldPivot.Position)
			if d < bd then bd, best = d, r end
		end
	end
	return best
end

local function AutoUseSkillFixLava()
	AutoUseSkillWeapons(Settings["Select Weapons Fix Lava"])
end

local SkullPending = false
local LastLavaClean = 0

local function VolcanoCore(flag)
	local PI = workspace.Map:FindFirstChild("PrehistoricIsland")
	if not PI then return end
	local hud = LP.PlayerGui.Main.TopHUDList
	local raidOn = hud.PrehistoricRaidTimer.Visible or hud.RaidTimer.Visible

	if LP:GetAttribute("CurrentLocation") ~= "Prehistoric Island" then
		local npc = DetectNpc("Fossil Expert")
		if npc then toTarget(npc.HumanoidRootPart.CFrame) return end
	end

	if tick() - LastLavaClean > 3 then
		LastLavaClean = tick()
		for _, d in ipairs(PI:GetDescendants()) do
			if d.Name == "TouchInterest" and d.Parent.Name ~= "TrialTeleport" then d:Destroy() end
		end
		local lava = PI.Core:FindFirstChild("InteriorLava")
		if lava then for _, c in ipairs(lava:GetChildren()) do c:Destroy() end end
	end

	if not raidOn then
		local prompt = PI.Core:FindFirstChild("ActivationPrompt")
		if prompt and prompt:FindFirstChild("ProximityPrompt") then
			toTarget(prompt.CFrame)
			if GetDistance(prompt.Position) < 8 then
				fireproximityprompt(prompt.ProximityPrompt, 1)
				task.wait(3)
			end
		elseif not PI.Core:FindFirstChild("FossilExpertSpawn") then
			local npc = DetectNpc("Fossil Expert")
			if npc then toTarget(npc.HumanoidRootPart.CFrame) end
		end
		return
	end

	if SkullPending then
		local skull = PI.Core.PrehistoricRelic.Skull
		repeat
			task.wait()
			toTarget(skull.CFrame)
		until GetDistance(skull.Position) <= 200 or DetectGolem() or DetectRockVolcano() or not Settings[flag]
		SkullPending = false
		return
	end

	local golem = DetectGolem()
	if golem then
		repeat
			task.wait()
			toTarget(golem.HumanoidRootPart.CFrame * CFrame.new(0, 20, 7))
			if Settings["Select Method Kill Golem"] == "Instant Kill [ Risk and can bug no die mob ]" then
				if GetDistance(golem.HumanoidRootPart.Position) < 50 then KillRaidEnemy() end
			else
				EquipTool(GetTool(Settings["Select Weapon Kill Golem"] or "Melee"))
			end
			KillAuraOnce(golem)
		until not IsAlive(golem) or not Settings[flag]
	end

	local rock = DetectRockVolcano()
	if rock then
		local off = ROCK_OFF[math.floor(rock.WorldPivot.Position.Y)] or CFrame.new(0, 40, 0)
		local M = Mouse()
		repeat
			task.wait()
			if GetDistance((rock.WorldPivot * off).Position) > 8 then
				toTarget(rock.WorldPivot * off)
			end
			if GetDistance(rock.WorldPivot.Position) < 100 then
				AutoUseSkillFixLava()
			end
			getgenv().AimPos = rock.WorldPivot
			if M then M.Hit = rock.WorldPivot M.Target = rock end
		until not rock.Parent or not Settings[flag] or not rock.VFXLayer.Specs.Enabled or DetectGolem()
			or not workspace.Map:FindFirstChild("PrehistoricIsland")
		if not DetectGolem() then SkullPending = true end
		task.wait(1)
	end
end

----- Dragon Hunter (Blaze Ember) + Magnet
local QuestHunter
pcall(function()
	RS:WaitForChild("Remotes"):WaitForChild("CommE").OnClientEvent:Connect(function(kind, text)
		if kind ~= "Notify" or type(text) ~= "string" then return end
		local clean = text:gsub("<[^>]+>", ""):gsub("{[^}]*}", "")
		if string.find(clean, "Task completed", 1, true) or string.find(clean, "Head back to the Dojo", 1, true) then
			QuestHunter = nil
		end
	end)
end)

local function DetectTree()
	local ok, res = pcall(function()
		local island = workspace.Map:FindFirstChild("Waterfall") and workspace.Map.Waterfall:FindFirstChild("IslandModel")
		if not island then toTarget(CFrame.new(5251.900390625, 17.18115234375, 453.6025390625)) return nil end
		local function rec(p)
			for _, c in ipairs(p:GetChildren()) do
				if c:IsA("Model") and not c:FindFirstChild("Ignored") and c.Name == "Tree"
					and not c:GetAttribute("AlreadyDestroyedClient") and c:FindFirstChild("Group")
					and (c.Group:FindFirstChild("Meshes/bambootree") or c.Group:FindFirstChild("Meshes/plant1_Icosphere"))
					and not workspace:FindFirstChild("EmberTemplate") then
					return c
				end
				local r = rec(c)
				if r then return r end
			end
		end
		return rec(island)
	end)
	return ok and res or nil
end

local function KillMobName(name, flag)
	local m = FindEnemy(name)
	if m then
		EngageEnemy(m, flag)
	else
		GoToSpawn(name)
		task.wait(0.5)
	end
end

local function DragonHunterStep(flag)
	for _, c in ipairs(workspace:GetChildren()) do
		if c.Name == "EmberTemplate" and not c:FindFirstChild("Ignored") and c:FindFirstChild("Part") and c.Part.Position.Y > -100 then
			Instance.new("IntValue", c).Name = "Ignored"
			local t0 = tick()
			repeat
				task.wait()
				toTarget(c.Part.CFrame)
			until not c.Parent or tick() - t0 > 10 or not Settings[flag]
			return
		end
	end

	local npc = DetectNpc("Dragon Hunter")
	if not npc then return end
	local remote = Net:FindFirstChild("RF/DragonHunter")
	if not QuestHunter then
		if GetDistance(npc.HumanoidRootPart.Position) > 8 then
			toTarget(npc.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
		else
			local r = remote:InvokeServer({ Context = "Check" })
			if not r or not r.Text then r = remote:InvokeServer({ Context = "RequestQuest" }) end
			QuestHunter = r and r.Text
		end
		return
	end

	if string.find(QuestHunter, "Hydra Enforcers") then
		KillMobName("Hydra Enforcer", flag)
	elseif string.find(QuestHunter, "Venomous Assailants") then
		KillMobName("Venomous Assailant", flag)
	elseif string.find(QuestHunter, "trees") then
		local tree = DetectTree()
		if tree then
			Instance.new("IntValue", tree).Name = "Ignored"
			local t0 = tick()
			local M = Mouse()
			repeat
				task.wait()
				local pos = tree.WorldPivot.Position
				if GetDistance(pos) < 50 then AutoUseSkillWeapons({ ["Blox Fruit"] = true, Melee = true, Sword = true, Gun = true }) end
				if tree:FindFirstChild("Meshes/plant1_Icosphere", true) then
					toTarget(tree.WorldPivot)
					getgenv().AimPos = tree.WorldPivot
					if M then M.Hit = CFrame.new(workspace.CurrentCamera.CFrame.Position, pos) M.Target = tree end
				else
					local a = (tree.WorldPivot * CFrame.new(5, -20, 0)).Position
					local b = (tree.WorldPivot * CFrame.new(0, -20, 0)).Position
					toTarget(CFrame.new(a))
					getgenv().AimPos = CFrame.new(b)
					if M then M.Hit = CFrame.new(workspace.CurrentCamera.CFrame.Position, b) M.Target = tree end
				end
			until not tree.Parent or not Settings[flag] or not QuestHunter or tree:GetAttribute("AlreadyDestroyedClient") or tick() - t0 >= 15
		end
	end
end

-- retorna true quando o magnet ja existe
local function CraftMagnet(flag)
	if CheckItemInventory("Volcanic Magnet") then return true end
	if not CheckCountItem("Scrap Metal", 10) then
		local list = { "Jungle Pirate", "Musketeer Pirate" }
		local m = FindEnemy(list)
		if m then EngageEnemy(m, flag, nil) else GoToSpawnAny(list) task.wait(0.5) end
	elseif not CheckCountItem("Blaze Ember", 15) then
		DragonHunterStep(flag)
	else
		Net:FindFirstChild("RF/Craft"):InvokeServer("Craft", "Volcanic Magnet", 1, {})
		task.wait(2)
	end
	return false
end

Para(Tabs.Volcano, "Farming Volcano", "Craft, achar a ilha e evento.")
Tg(Tabs.Volcano, "Auto Crafting Volcanic Magnet")
CreateLoop("Auto Crafting Volcanic Magnet", function()
	if CraftMagnet("Auto Crafting Volcanic Magnet") then
		Noti("Done Craft Volcanic Magnet")
		Options["Auto Crafting Volcanic Magnet"]:SetValue(false)
	end
end, 0.1)

Tg(Tabs.Volcano, "Auto Find Prehistoric Island")
CreateLoop("Auto Find Prehistoric Island", function()
	if workspace.Map:FindFirstChild("PrehistoricIsland") then
		CancelBoat()
		Noti("Prehistoric Island Spawned")
		Options["Auto Find Prehistoric Island"]:SetValue(false)
		task.wait(5)
		return
	end
	SailSearch("PirateBrigade", "Auto Find Prehistoric Island", function()
		return workspace.Map:FindFirstChild("PrehistoricIsland")
	end)
end, 0.1)

Tg(Tabs.Volcano, "Auto Event Prehistoric Island", "Auto start event, kill golem, fix volcano")
CreateLoop("Auto Event Prehistoric Island", function()
	VolcanoCore("Auto Event Prehistoric Island")
end, 0.1)

local function DetectBone()
	for _, c in ipairs(workspace:GetChildren()) do
		if c.Name == "DinoBone" then return c end
	end
end

local function DetectDragonEggs()
	local ok, res = pcall(function()
		for _, e in ipairs(workspace.Map.PrehistoricIsland.Core.SpawnedDragonEggs:GetChildren()) do
			if e.Name == "DragonEgg" and e:FindFirstChild("Molten") and e.Molten:FindFirstChild("ProximityPrompt") then
				return e
			end
		end
	end)
	return ok and res or nil
end

local function InVolcanoRaid()
	local hud = LP.PlayerGui.Main.TopHUDList
	return hud.PrehistoricRaidTimer.Visible or hud.RaidTimer.Visible
end

Tg(Tabs.Volcano, "Auto Collect Bone")
CreateLoop("Auto Collect Bone", function()
	local bone = DetectBone()
	if bone and not InVolcanoRaid() then toTarget(bone.CFrame) end
end, 0)

Tg(Tabs.Volcano, "Auto Collect Egg")
CreateLoop("Auto Collect Egg", function()
	local egg = DetectDragonEggs()
	if egg then
		if DetectBone() and Settings["Auto Collect Bone"] then return end
		toTarget(egg.Molten.CFrame)
		if GetDistance(egg.Molten.Position) < 8 then fireproximityprompt(egg.Molten.ProximityPrompt) end
	end
end, 0)

Para(Tabs.Volcano, "Fully Volcano", "Faz tudo: craft, achar, evento, bones e ovos.")
Tg(Tabs.Volcano, "Ignore Craft Volcanic Magnet")
Tg(Tabs.Volcano, "Ignore Collect Bone")

local CanReset = false
Tg(Tabs.Volcano, "Fully Event Prehistoric Island")
CreateLoop("Fully Event Prehistoric Island", function()
	local flag = "Fully Event Prehistoric Island"
	local PI = workspace.Map:FindFirstChild("PrehistoricIsland")
	if not PI then
		if not Settings["Ignore Craft Volcanic Magnet"] and not CraftMagnet(flag) then return end
		SailSearch("PirateBrigade", flag, function() return workspace.Map:FindFirstChild("PrehistoricIsland") end)
		return
	end
	CancelBoat()

	local egg = DetectDragonEggs()
	if egg then
		toTarget(egg.Molten.CFrame)
		if GetDistance(egg.Molten.Position) < 8 then fireproximityprompt(egg.Molten.ProximityPrompt) end
		return
	end
	if not Settings["Ignore Collect Bone"] then
		local bone = DetectBone()
		if bone and not InVolcanoRaid() then toTarget(bone.CFrame) return end
	end

	if LP:GetAttribute("CurrentLocation") == "Prehistoric Island" and not InVolcanoRaid() and CanReset then
		local t0 = tick()
		repeat task.wait()
		until tick() - t0 >= 10 or not Settings[flag] or DetectDragonEggs()
			or (DetectBone() and not Settings["Ignore Collect Bone"])
		if Settings[flag] and not DetectDragonEggs() and (Settings["Ignore Collect Bone"] or not DetectBone()) then
			local h = GetHum()
			if h then h.Health = 0 end
			CanReset = false
		end
		return
	end
	if InVolcanoRaid() then CanReset = true end
	VolcanoCore(flag)
end, 0.1)

----------------------------------------------------------------
-- TAB CONFIG  (Setting Farm do Banana)
----------------------------------------------------------------
Para(Tabs.Config, "Setting Farm", "Arma, ataque, hakis e movimento.")
Dd(Tabs.Config, "Select Weapon", { "Melee", "Sword", "Blox Fruit" }, "Melee")
Tg(Tabs.Config, "Attack No Animation ", "O ataque rapido ja ignora a animacao", true)
Tg(Tabs.Config, "Kill Aura Only Raid And Volcano")
Sl(Tabs.Config, "Time Delay Kill", 0, 5, 5)
Tg(Tabs.Config, "Auto Click")

-- Kill Aura With DragonStorm
local function SpamGunDragonStorm(part)
	local CombatUtil = require(RS.Modules.CombatUtil)
	local char = LP.Character
	local gun = char and char:FindFirstChild("Dragonstorm")
	if not gun or CombatUtil:IsGunReloading(gun) then return end
	local l = getupvalues(require(RS.Controllers.CombatController).Attack)[9]
	local I, _, o, V, N, y, P =
		debug.getupvalue(l, 15), debug.getupvalue(l, 13), debug.getupvalue(l, 16), debug.getupvalue(l, 17),
		debug.getupvalue(l, 14), debug.getupvalue(l, 12), debug.getupvalue(l, 18)
	local Q = y * _
	local d = ((N * _ + y * I) % o * o + Q) % V
	N = math.floor(d / o)
	y = d - N * o
	P += 1
	debug.setupvalue(l, 15, I) debug.setupvalue(l, 13, _) debug.setupvalue(l, 16, o)
	debug.setupvalue(l, 17, V) debug.setupvalue(l, 14, N) debug.setupvalue(l, 12, y) debug.setupvalue(l, 18, P)
	RS.Remotes.Validator2:FireServer(math.floor(d / V * 16777215), P)
	Net:FindFirstChild("RE/ShootGunEvent"):FireServer(part.Position, { part })
end
Tg(Tabs.Config, "Kill Aura With DragonStorm")
CreateLoop("Kill Aura With DragonStorm", function()
	if not (LP.Character and LP.Character:FindFirstChild("Dragonstorm")) then return end
	local root = GetRoot()
	if not root then return end
	local best, bd = nil, 150
	for _, folder in ipairs({ workspace.Enemies, workspace.Characters }) do
		for _, c in ipairs(folder:GetChildren()) do
			local hrp = c:FindFirstChild("HumanoidRootPart")
			if c ~= LP.Character and hrp and IsAlive(c) then
				local d = (hrp.Position - root.Position).Magnitude
				if d < bd then bd, best = d, hrp end
			end
		end
	end
	if best then SpamGunDragonStorm(best) end
end, 0)

Tg(Tabs.Config, "Auto Turn On Buso", nil, true)
CreateLoop("Auto Turn On Buso", function()
	local c = LP.Character
	if c and not c:FindFirstChild("HasBuso") then
		local has = false
		for _, ch in ipairs(c:GetChildren()) do
			if ch.Name:match("_BusoLayer1") then has = true break end
		end
		if not has then FireRemote("Buso") task.wait(2) end
	end
end, 1)

Tg(Tabs.Config, "Auto Turn On Observation")
CreateLoop("Auto Turn On Observation", function()
	if not game.Lighting.Blur.Enabled then
		VIM:SendKeyEvent(true, "E", false, game)
		task.wait()
		VIM:SendKeyEvent(false, "E", false, game)
		task.wait(3)
	end
end, 1)

Tg(Tabs.Config, "Auto Turn On V4")
CreateLoop("Auto Turn On V4", function()
	local c = LP.Character
	local energy, transformed = c and c:FindFirstChild("RaceEnergy"), c and c:FindFirstChild("RaceTransformed")
	if not energy or energy.Value < 1 or not transformed or transformed.Value then return end
	local aw = LP.Backpack:FindFirstChild("Awakening") or c:FindFirstChild("Awakening")
	if aw then aw.RemoteFunction:InvokeServer(true) end
end, 1)

Tg(Tabs.Config, "Auto Turn On V3")
CreateLoop("Auto Turn On V3", function()
	Remotes.CommE:FireServer("ActivateAbility")
	task.wait(2)
end, 1)

Tg(Tabs.Config, "Auto Dodge Skill Mobs")
Enemies.DescendantAdded:Connect(function(d)
	if Settings["Auto Dodge Skill Mobs"] and CurrentTarget and CurrentTarget.Parent and not ReadyToDodge
		and (d.Name == "BodyGyro" or d.Name == "BodyPosition" or d.Name == "KiBlastFireShort")
		and d.Parent and d.Parent.Parent and d.Parent.Parent.Name == CurrentTarget.Name then
		ReadyToDodge = true
		local t0 = tick()
		repeat task.wait() until not d or not d.Parent or tick() - t0 > 14
		if tick() - t0 < 2 then task.wait(0.5) end
		ReadyToDodge = false
	end
end)

Tg(Tabs.Config, "Teleport Y", "Teleport Y if low health")
Sl(Tabs.Config, "% Health Player", 0, 100, 40)
Sl(Tabs.Config, "Distance Teleport Y", 0, 10000, 800)

Tg(Tabs.Config, "Tween Safe if have Items")
CreateLoop("Tween Safe if have Items", function()
	if CheckNameBoss("Darkbeard") then return end
	if HasTool("Fist of Darkness") or HasTool("God's Chalice") then
		if CurrentSea() == 2 then
			toTarget(CFrame.new(-385.250916, 73.0458984, 297.388397))
		else
			toTarget(CFrame.new(-12463, 374, -7523))
		end
	end
end, 0.25)

Sl(Tabs.Config, "Time Hop Server", 0, 60, 10)
Sl(Tabs.Config, "Bring Mob Count", 2, 6, 2)
Tg(Tabs.Config, "Bring Mob", nil, true)
Sl(Tabs.Config, "Speed Tween ", 0, 1000, 300)
Para(Tabs.Config, "Dica", "Recomendado: 350. Se estiver farmando spots proximos, use velocidade maior.")

----------------------------------------------------------------
-- Final
----------------------------------------------------------------
Window:SelectTab(1)

Fluent:Notify({
	Title = "W-AZURE V3",
	Content = "Loaded successfully! by jane doe sigma",
	Duration = 5,
})
