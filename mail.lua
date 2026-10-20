-- language: Lua, file: vantar_core.lua, target: Roblox MM2 via Delta
-- VantarDLC: Часть 1 - Ядро, меню, логирование (без телеметрии и проверок валидности)

if getgenv().readyVANTAR then
	print("VantarDLC already injected")
	return
end
getgenv().readyVANTAR = true

print("VantarDLC Loading WH...")

-- ====================================================================
-- LOCAL CONFIG & LOGS (Replaced SNPWARE & Network calls)
-- ====================================================================
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = workspace
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local Stats = game:GetService("Stats")
local ContentProvider = game:GetService("ContentProvider")
local VirtualInputManager = game:GetService("VirtualInputManager")
local AssetService = game:GetService("AssetService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")

local VANTAR_DIR = "VantarDLC"
local VANTAR_LOG_FILE = VANTAR_DIR .. "/Vantar_Debug.log"
local VANTAR_CONFIG_DIR = VANTAR_DIR .. "/config/"

local function ensureDir()
	if type(makefolder) == "function" then
		pcall(makefolder, VANTAR_DIR)
		pcall(makefolder, VANTAR_CONFIG_DIR)
	end
end
ensureDir()

local logBuffer = {}
local function logLine(...)
	local args = {...}
	local out = {}
	for i = 1, #args do out[i] = tostring(args[i]) end
	local line = "[" .. os.date("%X") .. "] " .. table.concat(out, " ")
	table.insert(logBuffer, line)
	if #logBuffer > 50 then
		table.remove(logBuffer, 1)
	end
	if type(writefile) == "function" then
		pcall(writefile, VANTAR_LOG_FILE, table.concat(logBuffer, "\n"))
	end
end

logLine("Vantar Core Init")

-- ====================================================================
-- REMOTES & SERVICES SHORTCUTS
-- ====================================================================
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Gameplay = Remotes:WaitForChild("Gameplay")
local Extras = Remotes:WaitForChild("Extras")
local Inventory = Remotes:WaitForChild("Inventory")
local Shop = Remotes:WaitForChild("Shop")

-- ====================================================================
-- GLOBAL STATE (Переменные, которые нужны модулям)
-- ====================================================================
getgenv().values = getgenv().values or {}
getgenv().valueslider = getgenv().valueslider or {}
getgenv().valuestrings = getgenv().valuestrings or {}
getgenv().valuekeys = getgenv().valuekeys or {}
getgenv().dropdownval = getgenv().dropdownval or {}
getgenv().conns = getgenv().conns or {}

local values = getgenv().values
local valueslider = getgenv().valueslider
local valuestrings = getgenv().valuestrings
local valuekeys = getgenv().valuekeys
local dropdownval = getgenv().dropdownval
local conns = getgenv().conns

-- Инициализация дефолтных значений (пример)
values.runnings = false
values.noclipEnabled = false
values.flyEnabled = false
values.aimbotEnabled = false
values.shoot = false
values.autoGrabGun = false
values.HighlightInnocent = false
values.HighlightSheriff = true
values.HighlightMurderer = true
values.HighlightHero = true
values.HighlightDead = false
values.silentAim = false
values.KnifeAimEnabled = false
values.farmLift = -4
values.showtimer = true
values.showpingfps = false

valueslider.walkSpeed = 16
valueslider.jumpPower = 50
valueslider.newflySpeed = 50
valueslider.farmSpeed = 20
valueslider.shootRadius = 14
valueslider.KnifeFOVSize = 90

dropdownval.theme = "Amber"
dropdownval.language = "ru" -- Переключил на русский по умолчанию
dropdownval.espModes = { "Highlight" }
dropdownval.farmType = "Floating"

-- Заглушки, чтобы код не падал
local function dummy() end
local lc = {} -- Таблица локализации (заполним позже)
local notify = { ru = {}, en = {} }
local Window = nil

-- ====================================================================
-- UI SETUP (WindUI Placeholder)
-- ====================================================================
-- В этом сурсе используется кастомный WindUI, подгружаемый из сети.
-- Для VantarDLC мы будем использовать стандартный или локальный UI.
-- Поскольку в твоем сурсе WindUI вызывается через runHubScript, 
-- здесь мы его имитируем или оставляем заглушку для следующей части,
-- где будет написан чистый UI на Instance.new.

local function CreateMenu()
	-- Место для кода создания меню (будет во 2-й части)
end

-- ====================================================================
-- LOCALIZATION (Русский язык по умолчанию)
-- ====================================================================
lc = {
	script_loaded = "VantarDLC - Murder Mystery 2, загружено за %s",
	keybind = "Клавиша для открытия: G",
	trollcombatlock = "Вкладки Троллинг и Комбат заблокированы",
	trollcombatunlock = "Вкладки Троллинг и Комбат разблокированы",
}

-- ====================================================================
-- UTILITY FUNCTIONS
-- ====================================================================
local function getCharacter(player)
	return player.Character or player.CharacterAdded:Wait()
end

local function getHRP(player)
	local char = getCharacter(player)
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	local char = getCharacter(player)
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function findMurder()
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local bp = p:FindFirstChild("Backpack")
		if (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) then
			local hum = getHumanoid(p)
			if hum and hum.Health > 0 then
				return p
			end
		end
	end
	return nil
end

local function findSheriff()
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local bp = p:FindFirstChild("Backpack")
		if (char and char:FindFirstChild("Gun")) or (bp and bp:FindFirstChild("Gun")) then
			return p
		end
	end
	return nil
end

-- Экспорт утилит
getgenv().Vantar = {
	Log = logLine,
	FindMurder = findMurder,
	FindSheriff = findSheriff,
	GetHRP = getHRP,
	GetHumanoid = getHumanoid,
}
-- language: Lua, file: vantar_ui.lua, target: Roblox MM2 via Delta
-- VantarDLC: Часть 2 - Кастомное меню, вкладки и элементы управления

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local values = getgenv().values
local valueslider = getgenv().valueslider
local dropdownval = getgenv().dropdownval
local Vantar = getgenv().Vantar

-- ====================================================================
-- UI BUILDER
-- ====================================================================
local UI = {}
UI.Elements = {}
UI.ActiveTab = nil
UI.TabsButtons = {}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VantarDLC_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = CoreGui

-- Главный фрейм
local MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.Size = UDim2.new(0, 480, 0, 320)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- Топбар (заголовок)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "VantarDLC • MM2"
Title.TextColor3 = Color3.fromRGB(255, 100, 100)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = TopBar

-- Боковая панель (Вкладки)
local SideBar = Instance.new("Frame")
SideBar.Name = "SideBar"
SideBar.Size = UDim2.new(0, 110, 1, -50)
SideBar.Position = UDim2.new(0, 10, 0, 45)
SideBar.BackgroundTransparency = 1
SideBar.Parent = MainFrame
Instance.new("UIListLayout", SideBar).Padding = UDim.new(0, 5)

-- Контент (Скролл)
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Name = "Content"
ContentFrame.Size = UDim2.new(1, -135, 1, -50)
ContentFrame.Position = UDim2.new(0, 125, 0, 45)
ContentFrame.BackgroundTransparency = 1
ContentFrame.BorderSizePixel = 0
ContentFrame.ScrollBarThickness = 4
ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentFrame.Parent = MainFrame
Instance.new("UIListLayout", ContentFrame).Padding = UDim.new(0, 6)

-- ====================================================================
-- HELPERS
-- ====================================================================
local function CreateTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	btn.BorderSizePixel = 0
	btn.Text = name
	btn.TextColor3 = Color3.fromRGB(200, 200, 200)
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 13
	btn.Parent = SideBar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	btn.MouseButton1Click:Connect(function()
		UI.ActiveTab = name
		for _, child in ipairs(ContentFrame:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end
		for _, b in pairs(UI.TabsButtons) do
			b.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
			b.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
		btn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	end)
	UI.TabsButtons[name] = btn
	return btn
end

local function CreateSection(title)
	local sec = Instance.new("Frame")
	sec.Size = UDim2.new(1, 0, 0, 20)
	sec.BackgroundTransparency = 1
	sec.Parent = ContentFrame

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = title
	lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = sec
	return sec
end

local function CreateToggle(title, flag, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.Parent = ContentFrame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -40, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = title
	lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 13
	lbl.Parent = btn

	local ind = Instance.new("Frame")
	ind.Size = UDim2.new(0, 36, 0, 18)
	ind.Position = UDim2.new(1, -46, 0.5, -9)
	ind.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	ind.BorderSizePixel = 0
	ind.Parent = btn
	Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)

	local circle = Instance.new("Frame")
	circle.Size = UDim2.new(0, 14, 0, 14)
	circle.Position = UDim2.new(0, 2, 0.5, -7)
	circle.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
	circle.BorderSizePixel = 0
	circle.Parent = ind
	Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

	local state = values[flag] or false
	local function update()
		if state then
			TweenService:Create(ind, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 180, 100)}):Play()
			TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(1, -16, 0.5, -7), BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
		else
			TweenService:Create(ind, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 45)}):Play()
			TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = Color3.fromRGB(150,150,150)}):Play()
		end
	end
	update()

	btn.MouseButton1Click:Connect(function()
		state = not state
		values[flag] = state
		update()
		if callback then callback(state) end
	end)
	ContentFrame.CanvasSize = UDim2.new(0, 0, 0, ContentFrame.UIListLayout.AbsoluteContentSize.Y + 10)
	return btn
end

local function CreateButton(title, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	btn.BorderSizePixel = 0
	btn.Text = title
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 13
	btn.Parent = ContentFrame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	btn.MouseButton1Click:Connect(function()
		if callback then callback() end
	end)
	ContentFrame.CanvasSize = UDim2.new(0, 0, 0, ContentFrame.UIListLayout.AbsoluteContentSize.Y + 10)
	return btn
end

-- Экспорт в Vantar
Vantar.UI = {
	CreateTab = CreateTab,
	CreateSection = CreateSection,
	CreateToggle = CreateToggle,
	CreateButton = CreateButton,
	ContentFrame = ContentFrame,
	MainFrame = MainFrame
}

-- ====================================================================
-- BUILD TABS
-- ====================================================================
CreateTab("Main")
CreateTab("Visuals")
CreateTab("Combat")
CreateTab("Farm")

-- Переключение на главную по умолчанию
UI.TabsButtons["Main"]:Fire("MouseButton1Click")

return UI
-- language: Lua, file: vantar_logic.lua, target: Roblox MM2 via Delta
-- VantarDLC: Часть 3 - Логика функций (ESP, Aim, Farm, Roles)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Vantar = getgenv().Vantar
local values = getgenv().values
local valueslider = getgenv().valueslider
local dropdownval = getgenv().dropdownval
local UI = Vantar.UI

-- ====================================================================
-- HELPERS & STATE
-- ====================================================================
local sessionData = {}
local espObjects = {}
local aimConnection = nil
local farmConnection = nil
local fovCircle = nil

-- FOV Circle (Создаем один раз, скрываем/показываем)
if not fovCircle then
	fovCircle = Instance.new("Frame")
	fovCircle.Name = "VantarFOV"
	fovCircle.Size = UDim2.new(0, valueslider.KnifeFOVSize * 2, 0, valueslider.KnifeFOVSize * 2)
	fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
	fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
	fovCircle.BackgroundTransparency = 1
	fovCircle.BorderSizePixel = 1
	fovCircle.BorderColor3 = Color3.fromRGB(255, 50, 50)
	fovCircle.Visible = values.KnifeAimEnabled
	fovCircle.Parent = UI.MainFrame.Parent
	Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(0.5, 0)
end

-- ====================================================================
-- ROLE SCANNER
-- ====================================================================
local function updateSessionData(data)
	if type(data) == "table" then
		for k, v in pairs(data) do
			sessionData[k] = v
		end
	end
end

-- Слушаем изменения данных игроков от сервера
task.spawn(function()
	local GetCurrentPlayerData = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Gameplay"):WaitForChild("GetCurrentPlayerData")
	while true do
		local ok, result = pcall(function()
			return GetCurrentPlayerData:InvokeServer()
		end)
		if ok and type(result) == "table" then
			updateSessionData(result)
		end
		task.wait(2)
	end
end)

local function getRole(player)
	local data = sessionData[player.Name]
	if not data then return "Innocent" end
	if data.Dead or data.Killed then return "Dead" end
	return data.Role or "Innocent"
end

-- ====================================================================
-- ESP (HIGHLIGHTS)
-- ====================================================================
local function getRoleColor(role)
	if role == "Murderer" then return Color3.fromRGB(255, 50, 50) end
	if role == "Sheriff" then return Color3.fromRGB(50, 150, 255) end
	if role == "Hero" then return Color3.fromRGB(255, 255, 0) end
	if role == "Dead" then return Color3.fromRGB(128, 128, 128) end
	return Color3.fromRGB(255, 255, 255) -- Innocent
end

local function updateESP()
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		
		local char = player.Character
		if not char then
			if espObjects[player.UserId] then
				espObjects[player.UserId]:Destroy()
				espObjects[player.UserId] = nil
			end
			continue
		end

		local role = getRole(player)
		local isVisible = false
		
		if role == "Murderer" and values.HighlightMurderer then isVisible = true end
		if role == "Sheriff" and values.HighlightSheriff then isVisible = true end
		if role == "Hero" and values.HighlightHero then isVisible = true end
		if role == "Innocent" and values.HighlightInnocent then isVisible = true end
		if role == "Dead" and values.HighlightDead then isVisible = true end

		if isVisible then
			if not espObjects[player.UserId] then
				local hl = Instance.new("Highlight")
				hl.Name = "VantarESP"
				hl.Adornee = char
				hl.FillTransparency = 0.6
				hl.OutlineTransparency = 0
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = char
				espObjects[player.UserId] = hl
			end
			local hl = espObjects[player.UserId]
			hl.Adornee = char
			hl.FillColor = getRoleColor(role)
			hl.OutlineColor = getRoleColor(role)
			hl.Enabled = true
		else
			if espObjects[player.UserId] then
				espObjects[player.UserId].Enabled = false
			end
		end
	end
end

RunService.RenderStepped:Connect(updateESP)

-- ====================================================================
-- AIMBOT
-- ====================================================================
local function getClosestPlayer()
	local closest = nil
	local shortestDist = valueslider.KnifeFOVSize
	local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

	for _, p in ipairs(Players:GetPlayers()) do
		if p == LocalPlayer then continue end
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		
		if char and hum and hum.Health > 0 and hrp then
			local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
			if onScreen and screenPos.Z > 0 then
				local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
				if dist < shortestDist then
					shortestDist = dist
					closest = hrp
				end
			end
		end
	end
	return closest
end

local function updateAim()
	if not values.aimbotEnabled then return end
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch) then
		local target = getClosestPlayer()
		if target then
			local targetCF = CFrame.lookAt(Camera.CFrame.Position, target.Position)
			Camera.CFrame = Camera.CFrame:Lerp(targetCF, 0.3)
		end
	end
end
RunService.RenderStepped:Connect(updateAim)

-- ====================================================================
-- AUTO FARM (Телепорт к монетам)
-- ====================================================================
local function startFarm()
	if farmConnection then farmConnection:Disconnect() end
	farmConnection = RunService.Heartbeat:Connect(function()
		if not values.runnings then
			if farmConnection then farmConnection:Disconnect() end
			return
		end
		
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		-- Ищем монеты
		local map = nil
		for _, child in ipairs(Workspace:GetChildren()) do
			if child:IsA("Model") and child:FindFirstChild("CoinContainer") then
				map = child
				break
			end
		end

		if not map then return end
		local coinContainer = map:FindFirstChild("CoinContainer")
		if not coinContainer then return end

		local closestCoin = nil
		local minDist = math.huge
		for _, coin in ipairs(coinContainer:GetChildren()) do
			if coin.Name == "Coin_Server" and coin:IsA("BasePart") then
				local dist = (coin.Position - hrp.Position).Magnitude
				if dist < minDist then
					minDist = dist
					closestCoin = coin
				end
			end
		end

		if closestCoin then
			-- Телепорт к монете
			hrp.CFrame = CFrame.new(closestCoin.Position + Vector3.new(0, values.farmLift, 0))
			if firetouchinterest then
				firetouchinterest(hrp, closestCoin, 0)
				task.wait()
				firetouchinterest(hrp, closestCoin, 1)
			end
		end
	end)
end

-- ====================================================================
-- UTILITY FUNCTIONS
-- ====================================================================
local function noclip()
	if values.noclipEnabled then
		local char = LocalPlayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end
end
RunService.Stepped:Connect(noclip)

local function fly()
	if not values.flyEnabled then return end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	local dir = Vector3.new()
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end

	hum.PlatformStand = true
	hrp.Velocity = dir * valueslider.newflySpeed
end
RunService.RenderStepped:Connect(fly)

-- ====================================================================
-- BUILD UI (Привязка к вкладкам)
-- ====================================================================
Vantar.UI.CreateTab("Combat")

Vantar.UI.CreateSection("ESP")
Vantar.UI.CreateToggle("Убийца (Murderer)", "HighlightMurderer")
Vantar.UI.CreateToggle("Шериф (Sheriff)", "HighlightSheriff")
Vantar.UI.CreateToggle("Мирный (Innocent)", "HighlightInnocent")
Vantar.UI.CreateToggle("Герой (Hero)", "HighlightHero")
Vantar.UI.CreateToggle("Мертвые (Dead)", "HighlightDead")

Vantar.UI.CreateSection("AIMBOT")
Vantar.UI.CreateToggle("Аимбот (ПКМ/Тап)", "aimbotEnabled", function(state)
	if state then
		fovCircle.Visible = true
	else
		fovCircle.Visible = false
	end
end)

Vantar.UI.CreateSection("MOVEMENT")
Vantar.UI.CreateToggle("Noclip (Сквозь стены)", "noclipEnabled")
Vantar.UI.CreateToggle("Fly (Полет)", "flyEnabled")

Vantar.UI.CreateTab("Farm")
Vantar.UI.CreateSection("Автофарм")
Vantar.UI.CreateToggle("Включить автофарм", "runnings", function(state)
	if state then startFarm() end
end)
-- language: Lua, file: vantar_logic.lua, target: Roblox MM2 via Delta
-- VantarDLC: Часть 4 - Логика функций (ESP, Combat, Farm)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local values = getgenv().values
local valueslider = getgenv().valueslider
local Vantar = getgenv().Vantar
local UI = Vantar.UI

-- ====================================================================
-- ПЕРЕМЕННЫЕ
-- ====================================================================
local espFolder = Instance.new("Folder", workspace)
espFolder.Name = "Vantar_ESP"

local espCache = {}
local fovCircle = nil
local aimbotEnabled = false
local shootEnabled = false
local autoFarmEnabled = false
local farmConnection = nil

-- ====================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ====================================================================
local function getRole(player)
    local char = player.Character
    if not char then return "UNKNOWN" end
    
    -- Murderer
    if (char:FindFirstChild("Knife")) or (player.Backpack and player.Backpack:FindFirstChild("Knife")) then
        return "MURDERER"
    end
    
    -- Sheriff
    if (char:FindFirstChild("Gun")) or (player.Backpack and player.Backpack:FindFirstChild("Gun")) then
        return "SHERIFF"
    end
    
    return "INNOCENT"
end

local function getESPColor(role)
    if role == "MURDERER" then return Color3.fromRGB(255, 50, 50) end
    if role == "SHERIFF" then return Color3.fromRGB(50, 150, 255) end
    return Color3.fromRGB(255, 255, 255)
end

local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

-- ====================================================================
-- 1. VISUALS (ESP + FOV)
-- ====================================================================
local function buildESP(player)
    if player == LocalPlayer then return end
    
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not head then return end

    -- Highlight (Сквозь стены)
    local hl = Instance.new("Highlight")
    hl.Adornee = char
    hl.Name = "Vantar_HL"
    hl.FillTransparency = 0.7
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char

    -- Billboard (Ник и роль)
    local bb = Instance.new("BillboardGui")
    bb.Name = "Vantar_Tag"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = char

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.2
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.Parent = bb

    espCache[player] = { hl = hl, bb = bb, label = lbl }
end

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        if not espCache[player] and isAlive(player) then
            buildESP(player)
        end
        
        local data = espCache[player]
        if data and isAlive(player) then
            local role = getRole(player)
            local color = getESPColor(role)
            
            -- Проверка тумблеров
            local show = false
            if role == "MURDERER" and values.HighlightMurderer then show = true end
            if role == "SHERIFF" and values.HighlightSheriff then show = true end
            if role == "INNOCENT" and values.HighlightInnocent then show = true end
            
            if show then
                data.hl.FillColor = color
                data.hl.OutlineColor = color
                data.label.Text = player.Name .. "\n[" .. role .. "]"
                data.label.TextColor3 = color
            else
                data.hl.FillTransparency = 1
                data.hl.OutlineTransparency = 1
                data.label.Text = ""
            end
        elseif data then
            data.hl:Destroy()
            data.bb:Destroy()
            espCache[player] = nil
        end
    end
end

-- FOV Круг
local function createFOV()
    fovCircle = Instance.new("Frame")
    fovCircle.Name = "FOV"
    fovCircle.Size = UDim2.new(0, valueslider.KnifeFOVSize * 2, 0, valueslider.KnifeFOVSize * 2)
    fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
    fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    fovCircle.BackgroundTransparency = 1
    fovCircle.BorderSizePixel = 2
    fovCircle.BorderColor3 = Color3.fromRGB(255, 255, 255)
    fovCircle.Visible = false
    fovCircle.Parent = UI.MainFrame
    
    local corner = Instance.new("UICorner", fovCircle)
    corner.CornerRadius = UDim.new(0.5, 0)
end
createFOV()

-- ====================================================================
-- 2. COMBAT (Aimbot)
-- ====================================================================
local function getClosestTarget()
    local closest = nil
    local shortest = valueslider.KnifeFOVSize
    local center = Camera.ViewportSize / 2

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not isAlive(player) then continue end
        if getRole(player) ~= "MURDERER" then continue end -- Аим только на убийцу
        
        local char = player.Character
        local head = char and char:FindFirstChild("Head")
        if head then
            local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if dist < shortest then
                    shortest = dist
                    closest = head
                end
            end
        end
    end
    return closest
end

local function processAimbot()
    if not values.aimbotEnabled then return end
    
    local target = getClosestTarget()
    if target then
        local current = Camera.CFrame
        local goal = CFrame.lookAt(Camera.CFrame.Position, target.Position)
        Camera.CFrame = current:Lerp(goal, 0.3) -- Плавность
    end
end

-- ====================================================================
-- 3. AUTO FARM (Костыль на монеты)
-- ====================================================================
local function getNearestCoin()
    local closest = nil
    local shortest = 150 -- Радиус поиска
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Coin_Server" and obj:IsA("BasePart") then
            local dist = (obj.Position - hrp.Position).Magnitude
            if dist < shortest then
                shortest = dist
                closest = obj
            end
        end
    end
    return closest
end

local function processFarm()
    if not autoFarmEnabled then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local coin = getNearestCoin()
    if coin then
        hrp.CFrame = coin.CFrame -- Телепорт к монете
        task.wait(0.1)
        -- Симуляция сбора (если нужно)
    else
        task.wait(0.5)
    end
end

-- ====================================================================
-- ЦИКЛЫ (RenderStepped / Heartbeat)
-- ====================================================================
RunService.RenderStepped:Connect(function()
    updateESP()
    processAimbot()
end)

-- ====================================================================
-- НАВЕШИВАЕМ ЛОГИКУ НА UI
-- ====================================================================
-- Вкладка Visuals
local VisualTab = UI.TabsButtons["Visuals"]
VisualTab.MouseButton1Click:Connect(function()
    -- Очистка (в реальности делаем через UI.CreateSection)
    task.wait(0.05) 
    UI.CreateToggle("Показывать Убийц", "HighlightMurderer", function(state) end)
    UI.CreateToggle("Показывать Шерифов", "HighlightSheriff", function(state) end)
    UI.CreateToggle("Показывать Мирных", "HighlightInnocent", function(state) end)
end)

-- Вкладка Combat
local CombatTab = UI.TabsButtons["Combat"]
CombatTab.MouseButton1Click:Connect(function()
    task.wait(0.05)
    UI.CreateToggle("Аимбот (Убийца)", "aimbotEnabled", function(state)
        fovCircle.Visible = state
    end)
    
    -- Слайдер FOV (упрощенно)
    UI.CreateButton("Увеличить FOV (+10)", function()
        valueslider.KnifeFOVSize = valueslider.KnifeFOVSize + 10
        fovCircle.Size = UDim2.new(0, valueslider.KnifeFOVSize * 2, 0, valueslider.KnifeFOVSize * 2)
    end)
    UI.CreateButton("Уменьшить FOV (-10)", function()
        valueslider.KnifeFOVSize = math.max(20, valueslider.KnifeFOVSize - 10)
        fovCircle.Size = UDim2.new(0, valueslider.KnifeFOVSize * 2, 0, valueslider.KnifeFOVSize * 2)
    end)
end)

-- Вкладка Farm
local FarmTab = UI.TabsButtons["Farm"]
FarmTab.MouseButton1Click:Connect(function()
    task.wait(0.05)
    UI.CreateToggle("Автофарм Монет", "autoFarmEnabled", function(state)
        autoFarmEnabled = state
        if state then
            task.spawn(function()
                while autoFarmEnabled do
                    processFarm()
                end
            end)
        end
    end)
end)
-- language: Lua, file: vantar_logic_v5.lua, target: Roblox MM2 via Delta
-- VantarDLC: Часть 5 - Полный функционал (Kill All, Auto-Shoot, TP, ESP v2)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local values = getgenv().values
local valueslider = getgenv().valueslider
local Vantar = getgenv().Vantar
local UI = Vantar.UI

-- ====================================================================
-- ПЕРЕМЕННЫЕ
-- ====================================================================
local espCache = {}
local fovCircle = nil
local aimbotEnabled = false
local shootEnabled = false
local autoFarmEnabled = false

-- ====================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ====================================================================
local function getRole(player)
    local char = player.Character
    if not char then return "UNKNOWN" end
    if (char:FindFirstChild("Knife")) or (player.Backpack and player.Backpack:FindFirstChild("Knife")) then return "MURDERER" end
    if (char:FindFirstChild("Gun")) or (player.Backpack and player.Backpack:FindFirstChild("Gun")) then return "SHERIFF" end
    return "INNOCENT"
end

local function getESPColor(role)
    if role == "MURDERER" then return Color3.fromRGB(255, 50, 50) end
    if role == "SHERIFF" then return Color3.fromRGB(50, 150, 255) end
    return Color3.fromRGB(255, 255, 255)
end

local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ====================================================================
-- 1. VISUALS (ESP v2)
-- ====================================================================
local function buildESP(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local hl = Instance.new("Highlight")
    hl.Adornee = char
    hl.Name = "Vantar_HL"
    hl.FillTransparency = 0.7
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char

    local bb = Instance.new("BillboardGui")
    bb.Name = "Vantar_Tag"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = char

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.2
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.Parent = bb

    espCache[player] = { hl = hl, bb = bb, label = lbl }
end

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        if not espCache[player] and isAlive(player) then
            buildESP(player)
        end
        
        local data = espCache[player]
        if data and isAlive(player) then
            local role = getRole(player)
            local color = getESPColor(role)
            
            local show = false
            if role == "MURDERER" and values.HighlightMurderer then show = true end
            if role == "SHERIFF" and values.HighlightSheriff then show = true end
            if role == "INNOCENT" and values.HighlightInnocent then show = true end
            
            if show then
                local hrp = getHRP()
                local dist = 0
                if hrp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    dist = (hrp.Position - player.Character.HumanoidRootPart.Position).Magnitude
                end
                
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                local hp = hum and math.floor(hum.Health) or 0

                data.hl.FillColor = color
                data.hl.OutlineColor = color
                data.label.Text = string.format("%s [%dm] %d HP\n[%s]", player.Name, dist, hp, role)
                data.label.TextColor3 = color
            else
                data.hl.FillTransparency = 1
                data.hl.OutlineTransparency = 1
                data.label.Text = ""
            end
        elseif data then
            data.hl:Destroy()
            data.bb:Destroy()
            espCache[player] = nil
        end
    end
end

-- FOV Круг
local function createFOV()
    fovCircle = Instance.new("Frame")
    fovCircle.Name = "FOV"
    fovCircle.Size = UDim2.new(0, valueslider.KnifeFOVSize * 2, 0, valueslider.KnifeFOVSize * 2)
    fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
    fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    fovCircle.BackgroundTransparency = 1
    fovCircle.BorderSizePixel = 1
    fovCircle.BorderColor3 = Color3.fromRGB(255, 255, 255)
    fovCircle.Visible = false
    fovCircle.Parent = UI.MainFrame
    
    local corner = Instance.new("UICorner", fovCircle)
    corner.CornerRadius = UDim.new(0.5, 0)
end
createFOV()

-- ====================================================================
-- 2. COMBAT (Aimbot & Auto-Shoot)
-- ====================================================================
local function getClosestTarget()
    local closest = nil
    local shortest = valueslider.KnifeFOVSize
    local center = Camera.ViewportSize / 2

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not isAlive(player) then continue end
        if getRole(player) ~= "MURDERER" then continue end
        
        local char = player.Character
        local head = char and char:FindFirstChild("Head")
        if head then
            local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if dist < shortest then
                    shortest = dist
                    closest = head
                end
            end
        end
    end
    return closest
end

local function processAimbot()
    if not values.aimbotEnabled then return end
    local target = getClosestTarget()
    if target then
        local current = Camera.CFrame
        local goal = CFrame.lookAt(Camera.CFrame.Position, target.Position)
        Camera.CFrame = current:Lerp(goal, 0.3)
    end
end

-- Авто-стрельба (для Шерифа)
local function processAutoShoot()
    if not shootEnabled then return end
    if getRole(LocalPlayer) ~= "SHERIFF" then return end
    
    local target = getClosestTarget()
    if target then
        local char = LocalPlayer.Character
        local gun = char and char:FindFirstChild("Gun")
        if gun then
            local shootRemote = gun:FindFirstChild("Shoot")
            if shootRemote then
                -- Симуляция выстрела (нужно проверять аргументы, тут упрощенно)
                local args = {Camera.CFrame}
                pcall(function() shootRemote:FireServer(unpack(args)) end)
            end
        end
    end
end

-- ====================================================================
-- 3. TROLL (Kill All, Noclip)
-- ====================================================================
local function processKillAll()
    if not values.killAllEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local knife = char:FindFirstChild("Knife")
    if not knife then return end
    local events = knife:FindFirstChild("Events")
    if not events then return end
    local stab = events:FindFirstChild("KnifeStabbed")

    if stab then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and isAlive(p) then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    -- Удар (логика зависит от ремоутов игры, тут пример)
                    stab:FireServer()
                    -- Или через touch (как в некоторых версиях)
                    pcall(function()
                        firetouchinterest(char.HumanoidRootPart, hrp, 0)
                        firetouchinterest(char.HumanoidRootPart, hrp, 1)
                    end)
                end
            end
        end
    end
end

local noclipConnection = nil
local function toggleNoclip(state)
    if noclipConnection then noclipConnection:Disconnect() end
    if state then
        noclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

-- ====================================================================
-- 4. AUTO FARM
-- ====================================================================
local function getNearestCoin()
    local closest = nil
    local shortest = 200
    local hrp = getHRP()
    if not hrp then return nil end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Coin_Server" and obj:IsA("BasePart") then
            local dist = (obj.Position - hrp.Position).Magnitude
            if dist < shortest then
                shortest = dist
                closest = obj
            end
        end
    end
    return closest
end

local function processFarm()
    if not autoFarmEnabled then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local coin = getNearestCoin()
    if coin then
        hrp.CFrame = coin.CFrame
        task.wait(0.1)
    else
        task.wait(0.5)
    end
end

-- ====================================================================
-- ЦИКЛЫ
-- ====================================================================
RunService.RenderStepped:Connect(function()
    updateESP()
    processAimbot()
    processAutoShoot()
    processKillAll()
end)

-- ====================================================================
-- НАВЕШИВАЕМ ЛОГИКУ НА UI
-- ====================================================================
local VisualTab = UI.TabsButtons["Visuals"]
VisualTab.MouseButton1Click:Connect(function()
    task.wait(0.05) 
    UI.CreateToggle("Показывать Убийц", "HighlightMurderer", function(state) end)
    UI.CreateToggle("Показывать Шерифов", "HighlightSheriff", function(state) end)
    UI.CreateToggle("Показывать Мирных", "HighlightInnocent", function(state) end)
end)

local CombatTab = UI.TabsButtons["Combat"]
CombatTab.MouseButton1Click:Connect(function()
    task.wait(0.05)
    UI.CreateToggle("Аимбот (Убийца)", "aimbotEnabled", function(state)
        fovCircle.Visible = state
    end)
    
    UI.CreateButton("Увеличить FOV (+10)", function()
        valueslider.KnifeFOVSize = valueslider.KnifeFOVSize + 10
        fovCircle.Size = UDim2.new(0, valueslider.KnifeFOVSize * 2, 0, valueslider.KnifeFOVSize * 2)
    end)
    UI.CreateButton("Уменьшить FOV (-10)", function()
        valueslider.KnifeFOVSize = math.max(20, valueslider.KnifeFOVSize - 10)
        fovCircle.Size = UDim2.new(0, valueslider.KnifeFOVSize * 2, 0, valueslider.KnifeFOVSize * 2)
    end)
    UI.CreateToggle("Авто-стрельба (Шериф)", "shootEnabled", function(state)
        shootEnabled = state
    end)
end)

local TrollTab = UI.CreateTab("Troll")
TrollTab.MouseButton1Click:Connect(function()
    task.wait(0.05)
    UI.CreateToggle("Убить всех (Knife)", "killAllEnabled", function(state) end)
    UI.CreateToggle("Проход сквозь стены", "noclipEnabled", function(state)
        toggleNoclip(state)
    end)
end)

local FarmTab = UI.TabsButtons["Farm"]
FarmTab.MouseButton1Click:Connect(function()
    task.wait(0.05)
    UI.CreateToggle("Автофарм Монет", "autoFarmEnabled", function(state)
        autoFarmEnabled = state
        if state then
            task.spawn(function()
                while autoFarmEnabled do
                    processFarm()
                end
            end)
        end
    end)
end)
-- language: Lua, file: vantar_final.lua, target: Roblox MM2 via Delta
-- VantarDLC: Часть 6 - Конфиги, Телепорт, Мобильный тумблер меню

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local values = getgenv().values
local valueslider = getgenv().valueslider
local Vantar = getgenv().Vantar
local UI = Vantar.UI

local CONFIG_DIR = "VantarDLC/config/"
local CONFIG_FILE = CONFIG_DIR .. "default.json"

local function saveConfig()
    local data = {
        values = values,
        valueslider = valueslider,
        dropdownval = getgenv().dropdownval
    }
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if ok and type(writefile) == "function" then
        pcall(function()
            if type(makefolder) == "function" then pcall(makefolder, "VantarDLC"); pcall(makefolder, CONFIG_DIR) end
            writefile(CONFIG_FILE, encoded)
        end)
        Vantar.Log("Config saved")
    end
end

local function loadConfig()
    if type(isfile) ~= "function" or not isfile(CONFIG_FILE) then return end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if ok and type(decoded) == "table" then
        if decoded.values then for k, v in pairs(decoded.values) do values[k] = v end end
        if decoded.valueslider then for k, v in pairs(decoded.valueslider) do valueslider[k] = v end end
        if decoded.dropdownval then for k, v in pairs(decoded.dropdownval) do getgenv().dropdownval[k] = v end end
        Vantar.Log("Config loaded")
    end
end

-- ====================================================================
-- ТЕЛЕПОРТ К ИГРОКУ
-- ====================================================================
local function teleportToPlayer(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target or not target.Character then return false end
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local tgtHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if myHRP and tgtHRP then
        myHRP.CFrame = tgtHRP.CFrame * CFrame.new(0, 0, 3)
        return true
    end
    return false
end

-- ====================================================================
-- МОБИЛЬНАЯ КНОПКА МЕНЮ (Скрыть/Показать)
-- ====================================================================
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "VantarToggle"
toggleBtn.Size = UDim2.new(0, 50, 0, 50)
toggleBtn.Position = UDim2.new(0, 10, 0.5, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
toggleBtn.Text = "V"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 20
toggleBtn.Visible = true
toggleBtn.Parent = UI.MainFrame.Parent
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

local isMenuOpen = true
local function toggleMenu()
    isMenuOpen = not isMenuOpen
    UI.MainFrame.Visible = isMenuOpen
end

toggleBtn.MouseButton1Click:Connect(toggleMenu)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        toggleMenu()
    end
end)

-- ====================================================================
-- НАВЕШИВАЕМ ЛОГИКУ НА UI (ДОП. ВКЛАДКИ)
-- ====================================================================
local PlayerTab = UI.CreateTab("Player")
PlayerTab.MouseButton1Click:Connect(function()
    task.wait(0.05)
    
    -- ТП к случайному
    UI.CreateButton("Телепорт к случайному", function()
        local players = Players:GetPlayers()
        local rnd = players[math.random(1, #players)]
        if rnd and rnd ~= LocalPlayer then teleportToPlayer(rnd.Name) end
    end)
    
    -- ТП к убийце
    UI.CreateButton("Телепорт к убийце", function()
        local murder = Vantar.FindMurder()
        if murder then teleportToPlayer(murder.Name) end
    end)
    
    -- ТП к шерифу
    UI.CreateButton("Телепорт к шерифу", function()
        local sheriff = Vantar.FindSheriff()
        if sheriff then teleportToPlayer(sheriff.Name) end
    end)

    -- Респавн
    UI.CreateButton("Респавн (Умереть)", function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end)
end)

-- Кнопки сохранения/загрузки в главном меню (Main)
local MainTab = UI.TabsButtons["Main"]
MainTab.MouseButton1Click:Connect(function()
    task.wait(0.05)
    UI.CreateButton("Сохранить настройки", function() saveConfig() end)
    UI.CreateButton("Загрузить настройки", function() loadConfig() end)
    UI.CreateSection("Информация")
    UI.CreateButton("VantarDLC (by dj)", function() end)
end)

-- Загружаем конфиг при старте
task.spawn(function()
    task.wait(1)
    loadConfig()
end)
-- language: Lua, file: vantar_advanced.lua, target: Roblox MM2 via Delta
-- VantarDLC: Часть 7 - Продвинутый комбат (Silent Aim, Fake Knife, Auto-Grab)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local CollectionService = game:GetService("CollectionService")

local values = getgenv().values
local valueslider = getgenv().valueslider
local Vantar = getgenv().Vantar
local UI = Vantar.UI

-- ====================================================================
-- SILENT AIM (Hookmetamethod / Namecall)
-- ====================================================================
local silentAimEnabled = false
local originalNamecall
local hookmetamethodFunc = hookmetamethod or hookfunction

local function setupSilentAim()
    if not hookmetamethodFunc then return end
    
    originalNamecall = hookmetamethodFunc(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        
        -- Если включен Silent Aim и это выстрел (Shot / FireGun)
        if silentAimEnabled and (method == "FireServer" or method == "InvokeServer") then
            local target = Vantar.FindMurder()
            if target and target.Character and target.Character:FindFirstChild("Head") then
                -- Перехватываем аргументы (зависит от игры, тут хардкод под MM2)
                local args = { ... }
                -- В MM2 выстрел обычно передает CFrame / позицию
                -- Заменяем на позицию цели
                if self.Name == "Shoot" or self.Name == "FireGun" then
                    local headPos = target.Character.Head.Position
                    -- Меняем аргумент (например, args[1])
                    if #args > 0 then
                        args[1] = CFrame.lookAt(Camera.CFrame.Position, headPos)
                        return originalNamecall(self, unpack(args))
                    end
                end
            end
        end
        return originalNamecall(self, ...)
    end)
end

-- ====================================================================
-- FAKE KNIFE (Визуальный нож)
-- ====================================================================
local fakeKnife = nil
local function toggleFakeKnife(state)
    if state then
        local char = LocalPlayer.Character
        if not char then return end
        
        fakeKnife = Instance.new("Tool")
        fakeKnife.Name = "Fake Knife"
        fakeKnife.CanBeDropped = false
        fakeKnife.RequiresHandle = true
        
        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(0.4, 3, 0.7)
        handle.Color = Color3.fromRGB(150, 150, 150)
        handle.Material = Enum.Material.Metal
        handle.CanCollide = false
        handle.Parent = fakeKnife
        
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshId = "http://www.roblox.com/asset/?id=121944778" -- Стандартный меш ножа
        mesh.TextureId = "http://www.roblox.com/asset/?id=121944805"
        mesh.Parent = handle
        
        fakeKnife.Parent = char
        -- Экипируем (симуляция для визуала)
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:EquipTool(fakeKnife) end
    else
        if fakeKnife then
            fakeKnife:Destroy()
            fakeKnife = nil
        end
    end
end

-- ====================================================================
-- AUTO-GRAB GUN (Авто-подбор пистолета)
-- ====================================================================
local function processAutoGrab()
    if not values.autoGrabGun then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Ищем упавший пистолет на карте
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Gun" and obj:IsA("Tool") and obj.Parent == workspace then
            hrp.CFrame = obj.Handle.CFrame
            task.wait(0.1)
            break
        end
    end
end

-- ====================================================================
-- AUTO-KILL (Авто-убийство для убийцы)
-- ====================================================================
local function processAutoKill()
    if not values.autoKillEnabled then return end
    
    local char = LocalPlayer.Character
    local knife = char and char:FindFirstChild("Knife")
    if not knife then return end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and Vantar.GetHumanoid(p) and Vantar.GetHumanoid(p).Health > 0 then
            local tgt = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if tgt and (Vantar.GetHRP().Position - tgt.Position).Magnitude < 5 then
                local events = knife:FindFirstChild("Events")
                if events and events:FindFirstChild("KnifeStabbed") then
                    events.KnifeStabbed:FireServer()
                end
            end
        end
    end
end

-- ====================================================================
-- UI ДОПОЛНЕНИЯ (Combat и Player)
-- ====================================================================
local CombatTab = UI.TabsButtons["Combat"]
if CombatTab then
    CombatTab.MouseButton1Click:Connect(function()
        task.wait(0.05)
        UI.CreateToggle("Silent Aim (Авто-наводка)", "silentAim", function(state)
            silentAimEnabled = state
            if state and not originalNamecall then
                setupSilentAim()
            end
        end)
        UI.CreateToggle("Fake Knife (Визуал)", "fakeKnife", function(state)
            toggleFakeKnife(state)
        end)
        UI.CreateToggle("Auto-Grab Gun", "autoGrabGun", function(state) end)
        UI.CreateToggle("Auto-Kill (Убийца)", "autoKillEnabled", function(state) end)
    end)
end

local PlayerTab = UI.TabsButtons["Player"]
if PlayerTab then
    PlayerTab.MouseButton1Click:Connect(function()
        task.wait(0.05)
        UI.CreateButton("Снять фейк-нож", function()
            toggleFakeKnife(false)
            values.fakeKnife = false
        end)
    end)
end

-- ====================================================================
-- ЦИКЛЫ
-- ====================================================================
RunService.Heartbeat:Connect(function()
    processAutoGrab()
    processAutoKill()
end)
