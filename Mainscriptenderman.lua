--[[
    W-AZURE V3  |  by jane doe sigma
    UI: Fluent
    Tabs: Main / Missions / Config
]]

repeat task.wait() until game:IsLoaded()

----------------------------------------------------------------
-- UI (Fluent)
----------------------------------------------------------------
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
	Title = "W-AZURE V3",
	SubTitle = "by jane doe sigma",
	TabWidth = 140,
	Size = UDim2.fromOffset(500, 400),
	Acrylic = false,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
	Main = Window:AddTab({ Title = "Main", Icon = "home" }),
	Missions = Window:AddTab({ Title = "Missions", Icon = "target" }),
	Config = Window:AddTab({ Title = "Config", Icon = "settings" }),
}

local Options = Fluent.Options

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

-- When there is a fruit on the ground and Auto Collect Fruit is on, the other farms pause
local FruitState = { Active = false }

----------------------------------------------------------------
-- Utilities
----------------------------------------------------------------
local function GetRoot()
	local char = LP.Character
	return char and char:FindFirstChild("HumanoidRootPart")
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
	if backpack and backpack:FindFirstChild(name) then return true end
	return false
end

local function EquipWeapon()
	local backpack = LP.Backpack
	local char = LP.Character
	if not (backpack and char) then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local held = char:FindFirstChildOfClass("Tool")
	local wanted = Options.WeaponType and Options.WeaponType.Value or "Melee"
	if held and held.ToolTip == wanted then return end
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool.ToolTip == wanted then
			hum:EquipTool(tool)
			return
		end
	end
end

----------------------------------------------------------------
-- Tween (anti-gravity holder fixed)
----------------------------------------------------------------
local ActiveTween, ActiveBV

local function StopTween()
	if ActiveTween then ActiveTween:Cancel() ActiveTween = nil end
	if ActiveBV then ActiveBV:Destroy() ActiveBV = nil end
end

local function TweenTo(cf)
	local root = GetRoot()
	if not root then return end
	local speed = tonumber(Options.TweenSpeed and Options.TweenSpeed.Value) or 210
	if speed <= 0 then speed = 210 end

	-- Keep the anti-gravity holder alive while farming so the player never falls
	if not ActiveBV or not ActiveBV.Parent then
		ActiveBV = Instance.new("BodyVelocity")
		ActiveBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		ActiveBV.Velocity = Vector3.zero
		ActiveBV.Parent = root
	end

	local dist = (root.Position - cf.Position).Magnitude
	if dist < 5 then
		-- Close enough: keep the player held in place instead of dropping
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

----------------------------------------------------------------
-- Noclip while any farm is active
----------------------------------------------------------------
local function AnyFarmActive()
	return (Options.AutoFarmLevel and Options.AutoFarmLevel.Value)
		or (Options.AutoFarmNearest and Options.AutoFarmNearest.Value)
		or (Options.AutoFarmChest and Options.AutoFarmChest.Value)
		or (Options.AutoCollectFruit and Options.AutoCollectFruit.Value)
		or (Options.AutoEliteBoss and Options.AutoEliteBoss.Value)
		or (Options.AutoYama and Options.AutoYama.Value)
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

----------------------------------------------------------------
-- FindEnemy (clean name, nearest)
----------------------------------------------------------------
local NameCache = {}

local function FindEnemy(names)
	local root = GetRoot()
	if not root then return nil end
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

----------------------------------------------------------------
-- Quest system (GetQuestInfo + IsQuestOn + spawns)
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

local SpawnIndex = 1
local function GoToSpawn(mobName)
	local folder = RS:FindFirstChild("FortBuilderReplicatedSpawnPositionsFolder")
	if not folder then return false end

	local function clean(s)
		return (s:gsub("Lv%.", ""):gsub("[%[%] %d]", ""):gsub("%s+", ""))
	end
	local wanted = clean(mobName)

	local spawns = {}
	for _, part in ipairs(folder:GetChildren()) do
		if part:IsA("Part") and part:GetAttribute("Active") and clean(part.Name) == wanted then
			table.insert(spawns, part:GetPivot())
		end
	end
	if #spawns == 0 then return false end
	if SpawnIndex > #spawns then SpawnIndex = 1 end

	local target = spawns[SpawnIndex]
	local dist = GetDistance(target.Position)
	if dist > 20 then
		TweenTo(target * CFrame.new(0, dist > 150 and 65 or 30, 5))
	end
	SpawnIndex = SpawnIndex % #spawns + 1
	return true
end

----------------------------------------------------------------
-- Bring Mob
----------------------------------------------------------------
local function BringMobs(target, cf)
	if not (Options.BringMob and Options.BringMob.Value) then return end
	if not target or not target.Parent then return end

	local radius = tonumber(Options.BringRadius and Options.BringRadius.Value) or 300
	local radiusSq = radius * radius
	local pos = cf.Position

	pcall(function()
		sethiddenproperty(LP, "SimulationRadius", math.huge)
		sethiddenproperty(LP, "MaxSimulationRadius", math.huge)
	end)

	for _, mob in ipairs(Enemies:GetChildren()) do
		if mob.Name == target.Name then
			local hum = mob:FindFirstChildOfClass("Humanoid")
			local hrp = mob:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 and mob:FindFirstChild("CharacterReady") then
				local diff = hrp.Position - pos
				if diff:Dot(diff) <= radiusSq and not hrp:GetAttribute("BeingBrought") then
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
		if Options.FastAttack and Options.FastAttack.Value then
			pcall(AttackOnce)
		end
	end
end)

----------------------------------------------------------------
-- Engage
----------------------------------------------------------------
local function EngageEnemy(mob, flagName)
	local hrp = mob and mob:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local cf = hrp.CFrame

	while not Unloaded and Options[flagName] and Options[flagName].Value and mob.Parent and IsAlive(mob) do
		RunService.Heartbeat:Wait()
		EquipWeapon()
		ActivateHaki()
		BringMobs(mob, cf)
		local height = tonumber(Options.FarmDistance and Options.FarmDistance.Value) or 20
		TweenTo(cf + Vector3.new(0, height, 0))
	end
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
-- TAB MAIN
----------------------------------------------------------------
Tabs.Main:AddParagraph({
	Title = "Auto Farm Level",
	Content = "Automatically takes the quest, goes to the NPC, and farms the quest mobs.",
})

local tgLevel = Tabs.Main:AddToggle("AutoFarmLevel", {
	Title = "Auto Farm Level",
	Description = "Auto Quest + Farm",
	Default = false,
})
tgLevel:OnChanged(function()
	if not tgLevel.Value then StopTween() end
end)

CreateLoop("AutoFarmLevel", function()
	if FruitState.Active then return end
	if not IsAlive(LP.Character) then return end

	local info = GetQuestInfo()
	if not info or not info.Mob then return end

	if IsQuestOn() then
		local mob = FindEnemy({ info.Mob })
		if mob then
			EngageEnemy(mob, "AutoFarmLevel")
		else
			GoToSpawn(info.Mob)
			task.wait(1)
		end
	else
		if info.CFrame and GetDistance(info.CFrame) > 5 then
			TweenTo(info.CFrame)
		else
			StopTween()
			FireRemote("StartQuest", info.Quest, info.Num)
			task.wait(0.5)
		end
	end
end)

Tabs.Main:AddParagraph({
	Title = "Farm Nearest",
	Content = "Farms the nearest living enemy without a quest. Auto Farm Level has priority.",
})

Tabs.Main:AddDropdown("NearestRange", {
	Title = "Search range",
	Values = { "1000", "2000", "3000", "Infinite" },
	Multi = false,
	Default = "Infinite",
})

local tgNearest = Tabs.Main:AddToggle("AutoFarmNearest", {
	Title = "Auto Farm Nearest",
	Description = "Farms the nearest mob",
	Default = false,
})
tgNearest:OnChanged(function()
	if not tgNearest.Value then StopTween() end
end)

CreateLoop("AutoFarmNearest", function()
	if FruitState.Active then return end
	if Options.AutoFarmLevel.Value then return end
	local root = GetRoot()
	if not root or not IsAlive(LP.Character) then return end

	local rangeOpt = Options.NearestRange.Value
	local maxRange = rangeOpt == "Infinite" and math.huge or tonumber(rangeOpt)

	local nearest, best = nil, math.huge
	for _, mob in ipairs(Enemies:GetChildren()) do
		local hrp = mob:FindFirstChild("HumanoidRootPart")
		if hrp and IsAlive(mob) then
			local d = (hrp.Position - root.Position).Magnitude
			if d < best and d <= maxRange then
				best = d
				nearest = mob
			end
		end
	end

	if nearest then
		EngageEnemy(nearest, "AutoFarmNearest")
	end
end)

Tabs.Main:AddParagraph({
	Title = "Chests",
	Content = "Collects the nearest chest. Auto Farm Level has priority when both are on.",
})

local tgChest = Tabs.Main:AddToggle("AutoFarmChest", {
	Title = "Auto Farm Chests",
	Description = "Collects chests automatically",
	Default = false,
})
tgChest:OnChanged(function()
	if not tgChest.Value then StopTween() end
end)

CreateLoop("AutoFarmChest", function()
	if FruitState.Active then return end
	if Options.AutoFarmLevel.Value or Options.AutoFarmNearest.Value then return end
	local root = GetRoot()
	if not root or not IsAlive(LP.Character) then return end

	local nearest, best = nil, math.huge
	for _, chest in ipairs(CollectionService:GetTagged("_ChestTagged")) do
		if not chest:GetAttribute("IsDisabled") then
			local d = (chest:GetPivot().Position - root.Position).Magnitude
			if d < best then
				best = d
				nearest = chest
			end
		end
	end

	if nearest then
		TweenTo(nearest:GetPivot())
	end
end, 0.1)

----------------------------------------------------------------
-- Fruits (collect + store)
----------------------------------------------------------------
Tabs.Main:AddParagraph({
	Title = "Fruits",
	Content = "Collects fruits on the ground and stores them. When a fruit is on the ground, other farms pause.",
})

local function FindGroundFruit()
	local root = GetRoot()
	if not root then return nil end
	local bestDist = math.huge
	local bestHandle = nil
	for _, child in ipairs(workspace:GetChildren()) do
		local handle = child:FindFirstChild("Handle")
		if handle and child:IsA("Tool") then
			local d = (root.Position - handle.Position).Magnitude
			if d < bestDist then
				bestDist = d
				bestHandle = handle
			end
		elseif handle and child.Name:find("Fruit") then
			local d = (root.Position - handle.Position).Magnitude
			if d < bestDist then
				bestDist = d
				bestHandle = handle
			end
		end
	end
	return bestHandle
end

local tgCollectFruit = Tabs.Main:AddToggle("AutoCollectFruit", {
	Title = "Auto Collect Fruit",
	Description = "Collects fruits on the ground automatically",
	Default = false,
})
tgCollectFruit:OnChanged(function()
	if not tgCollectFruit.Value then
		FruitState.Active = false
		StopTween()
	end
end)

CreateLoop("AutoCollectFruit", function()
	if not IsAlive(LP.Character) then
		FruitState.Active = false
		return
	end
	local handle = FindGroundFruit()
	if handle then
		FruitState.Active = true
		TweenTo(handle.CFrame)
	else
		FruitState.Active = false
	end
end, 0.1)

local function GetCurrentFruit()
	local function normalize(name)
		local parts = name:split(":")
		return (parts[1] .. "-" .. parts[1] .. (parts[2] and ":" .. parts[2] or "")):gsub(" Fruit", "")
	end

	local char = LP.Character
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item.Name:find("Fruit") then
				return item.Name, normalize(item.Name), item
			end
		end
	end

	local backpack = LP.Backpack
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item.Name:find("Fruit") then
				return item.Name, normalize(item.Name), item
			end
		end
	end

	return nil, nil, nil
end

Tabs.Main:AddToggle("AutoStoreFruit", {
	Title = "Auto Store Fruit",
	Description = "Stores fruits in the inventory automatically",
	Default = false,
})

CreateLoop("AutoStoreFruit", function()
	local _, fruitKey, tool = GetCurrentFruit()
	if fruitKey and tool then
		FireRemote("StoreFruit", fruitKey, tool)
	end
end, 0.5)

----------------------------------------------------------------
-- TAB MISSIONS
----------------------------------------------------------------
Tabs.Missions:AddParagraph({
	Title = "Auto Elite Boss",
	Content = "Farms the elite bosses (Diablo, Deandre, Urban) and picks up the Elite Hunter quest when needed.",
})

local tgElite = Tabs.Missions:AddToggle("AutoEliteBoss", {
	Title = "Auto Elite Boss",
	Description = "Farms elite bosses automatically",
	Default = false,
})
tgElite:OnChanged(function()
	if not tgElite.Value then StopTween() end
end)

CreateLoop("AutoEliteBoss", function()
	if not IsAlive(LP.Character) then return end

	local bosses = { "Diablo", "Deandre", "Urban" }
	local boss = FindEnemy(bosses)

	if boss and IsQuestOn() then
		EngageEnemy(boss, "AutoEliteBoss")
	else
		-- If we already own the chalice we can teleport straight into the elite area
		if HasTool("God's Chalice") then
			FireRemote("requestEntrance", Vector3.new(-12471.17, 374.94025, -7551.6777))
			return
		end
		-- Otherwise take the Elite Hunter quest
		if not IsQuestOn() then
			FireRemote("EliteHunter")
		end
	end
end, 0.5)

Tabs.Missions:AddParagraph({
	Title = "Auto Yama",
	Content = "Farms elite bosses until Elite Hunter progress reaches 30, then fetches Yama at the Waterfall.",
})

local function FindYamaKatana()
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end
	local waterfall = map:FindFirstChild("Waterfall")
	if not waterfall then return nil end
	return waterfall:FindFirstChild("SealedKatana")
end

local tgYama = Tabs.Missions:AddToggle("AutoYama", {
	Title = "Auto Yama",
	Description = "Fetches Yama once Elite Hunter progress is 30",
	Default = false,
})
tgYama:OnChanged(function()
	if not tgYama.Value then StopTween() end
end)

CreateLoop("AutoYama", function()
	if not IsAlive(LP.Character) then return end

	-- Already have Yama? Nothing to do
	if HasTool("Yama") then return end

	local progress = tonumber(FireRemote("EliteHunter", "Progress")) or 0

	if progress >= 30 then
		-- Go to the sealed katana and pick Yama up
		local katana = FindYamaKatana()
		if katana and katana:FindFirstChild("Handle") then
			local handle = katana.Handle
			if GetDistance(handle.CFrame) > 8 then
				TweenTo(handle.CFrame)
			else
				local cd = handle:FindFirstChild("ClickDetecter") or handle:FindFirstChild("ClickDetector")
				if cd then
					fireclickdetector(cd)
				end
			end
		end
		return
	end

	-- Below 30: let Auto Elite Boss handle the farming when it's also on
	if Options.AutoEliteBoss and Options.AutoEliteBoss.Value then return end

	local bosses = { "Diablo", "Deandre", "Urban" }
	local boss = FindEnemy(bosses)

	if boss and IsQuestOn() then
		EngageEnemy(boss, "AutoYama")
	else
		if not IsQuestOn() then
			FireRemote("EliteHunter")
		end
	end
end, 0.5)

----------------------------------------------------------------
-- TAB CONFIG
----------------------------------------------------------------
Tabs.Config:AddParagraph({ Title = "Combat", Content = "Fast Attack and Bring Mob" })

Tabs.Config:AddToggle("FastAttack", {
	Title = "Fast Attack",
	Description = "Faster attack speed",
	Default = true,
})

Tabs.Config:AddToggle("BringMob", {
	Title = "Bring Mob",
	Description = "Pulls enemies closer",
	Default = true,
})

Tabs.Config:AddDropdown("BringRadius", {
	Title = "Bring Mob radius",
	Values = { "100", "150", "200", "250", "300" },
	Multi = false,
	Default = "300",
})

Tabs.Config:AddParagraph({ Title = "Farm", Content = "Weapon and movement" })

Tabs.Config:AddDropdown("WeaponType", {
	Title = "Weapon",
	Values = { "Melee", "Sword", "Blox Fruit", "Gun" },
	Multi = false,
	Default = "Melee",
})

Tabs.Config:AddDropdown("FarmDistance", {
	Title = "Distance from enemy",
	Values = { "10", "20", "30", "40", "50", "60" },
	Multi = false,
	Default = "20",
})

Tabs.Config:AddSlider("TweenSpeed", {
	Title = "Tween Speed",
	Default = 210,
	Min = 100,
	Max = 210,
	Rounding = 0,
})

----------------------------------------------------------------
-- Final
----------------------------------------------------------------
Window:SelectTab(1)

Fluent:Notify({
	Title = "W-AZURE V3",
	Content = "Loaded successfully! by jane doe sigma",
	Duration = 5,
})
