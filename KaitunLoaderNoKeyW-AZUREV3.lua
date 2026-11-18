-- ============================================================
-- W-AZURE V3 ONE CLICK - LOADER
-- ============================================================

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LogService = game:GetService("LogService")
local CoreGui = game:GetService("CoreGui")

-- Configuration
local SCRIPT_URL = "https://raw.githubusercontent.com/Janedoesigma/KeyMenu1-/main/kaitunLOLw-azurev3.lua"
local DISCORD_LINK = "https://discord.gg/f54yYhxJZx"

local FONT_ID = "rbxassetid://127896232205472"
local LOADING_IMAGE = "rbxassetid://6646175684"

local player = Players.LocalPlayer

-- ============================================================
-- FONT
-- ============================================================

local customFont

pcall(function()
    customFont = Font.new(FONT_ID)
end)

local function applyFont(object)
    if customFont then
        pcall(function()
            object.FontFace = customFont
        end)
    end
end

-- ============================================================
-- UI CREATOR
-- ============================================================

local function create(className, properties, parent)
    local object = Instance.new(className)

    for property, value in pairs(properties) do
        object[property] = value
    end

    object.Parent = parent
    return object
end

-- ============================================================
-- SCREEN GUI
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "WAzureV3Loader"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local guiParent = CoreGui

if type(gethui) == "function" then
    local success, result = pcall(gethui)

    if success and result then
        guiParent = result
    end
end

local parentSuccess = pcall(function()
    ScreenGui.Parent = guiParent
end)

if not parentSuccess then
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

-- ============================================================
-- MAIN FRAME
-- ============================================================

local MainFrame = create("Frame", {
    Name = "MainFrame",
    Size = UDim2.fromOffset(430, 390),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.fromRGB(5, 7, 12),
    BorderSizePixel = 0
}, ScreenGui)

create("UICorner", {
    CornerRadius = UDim.new(0, 10)
}, MainFrame)

create("UIStroke", {
    Color = Color3.fromRGB(20, 48, 95),
    Thickness = 2,
    Transparency = 0
}, MainFrame)

-- ============================================================
-- TITLE
-- ============================================================

local Title = create("TextLabel", {
    Name = "Title",
    Size = UDim2.new(1, -30, 0, 34),
    Position = UDim2.fromOffset(15, 13),
    BackgroundTransparency = 1,
    Text = "W-AZURE V3 ONE CLICK",
    TextColor3 = Color3.fromRGB(220, 230, 255),
    TextSize = 21,
    Font = Enum.Font.GothamBold
}, MainFrame)

applyFont(Title)

-- ============================================================
-- STATUS
-- ============================================================

local Status = create("TextLabel", {
    Name = "Status",
    Size = UDim2.new(1, -30, 0, 20),
    Position = UDim2.fromOffset(15, 50),
    BackgroundTransparency = 1,
    Text = "Initializing loader...",
    TextColor3 = Color3.fromRGB(115, 155, 215),
    TextSize = 12,
    Font = Enum.Font.Gotham
}, MainFrame)

applyFont(Status)

-- ============================================================
-- LOADING ANIMATION
-- ============================================================

local Spinner = create("ImageLabel", {
    Name = "LoadingSpinner",
    Size = UDim2.fromOffset(38, 38),
    Position = UDim2.new(0.5, -19, 0, 77),
    BackgroundTransparency = 1,
    Image = LOADING_IMAGE,
    ImageColor3 = Color3.fromRGB(100, 160, 255),
    ScaleType = Enum.ScaleType.Fit
}, MainFrame)

local SpinnerTween = TweenService:Create(
    Spinner,
    TweenInfo.new(
        0.85,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.InOut,
        -1,
        false
    ),
    {
        Rotation = 360
    }
)

SpinnerTween:Play()

-- ============================================================
-- ERROR LOG FRAME
-- ============================================================

local LogFrame = create("Frame", {
    Name = "LogFrame",
    Size = UDim2.new(1, -40, 0, 148),
    Position = UDim2.fromOffset(20, 120),
    BackgroundColor3 = Color3.fromRGB(9, 12, 20),
    BorderSizePixel = 0
}, MainFrame)

create("UICorner", {
    CornerRadius = UDim.new(0, 7)
}, LogFrame)

create("UIStroke", {
    Color = Color3.fromRGB(24, 48, 85),
    Thickness = 1
}, LogFrame)

local LogTitle = create("TextLabel", {
    Size = UDim2.new(1, -55, 0, 27),
    Position = UDim2.fromOffset(10, 5),
    BackgroundTransparency = 1,
    Text = "EXECUTION LOG",
    TextColor3 = Color3.fromRGB(120, 165, 235),
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold
}, LogFrame)

applyFont(LogTitle)

-- ============================================================
-- COPY ERROR BUTTON
-- ============================================================

local CopyErrors = create("TextButton", {
    Name = "CopyErrors",
    Size = UDim2.fromOffset(32, 27),
    Position = UDim2.new(1, -42, 0, 5),
    BackgroundColor3 = Color3.fromRGB(16, 32, 55),
    Text = "▤",
    TextColor3 = Color3.fromRGB(160, 195, 255),
    TextSize = 19,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = true
}, LogFrame)

create("UICorner", {
    CornerRadius = UDim.new(0, 5)
}, CopyErrors)

-- ============================================================
-- SCROLLING LOG
-- ============================================================

local LogScroll = create("ScrollingFrame", {
    Name = "LogScroll",
    Size = UDim2.new(1, -16, 1, -41),
    Position = UDim2.fromOffset(8, 36),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Color3.fromRGB(40, 90, 160),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, LogFrame)

local LogText = create("TextLabel", {
    Name = "LogText",
    Size = UDim2.new(1, -8, 0, 20),
    BackgroundTransparency = 1,
    Text = "No errors detected.",
    TextColor3 = Color3.fromRGB(125, 195, 145),
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    AutomaticSize = Enum.AutomaticSize.Y,
    Font = Enum.Font.Code
}, LogScroll)

-- ============================================================
-- ERROR MANAGEMENT
-- ============================================================

local Errors = {}

local function addError(message)
    message = tostring(message)

    local formatted = "[ERROR] " .. message

    -- Avoid duplicate consecutive entries
    if Errors[#Errors] == formatted then
        return
    end

    table.insert(Errors, formatted)

    -- Keep the most recent 25 errors
    while #Errors > 25 do
        table.remove(Errors, 1)
    end

    LogText.Text = table.concat(Errors, "\n\n")
    LogText.TextColor3 = Color3.fromRGB(255, 110, 110)

    task.defer(function()
        LogScroll.CanvasPosition = Vector2.new(
            0,
            LogScroll.AbsoluteCanvasSize.Y
        )
    end)
end

-- Listen for runtime errors
local ErrorConnection = LogService.MessageOut:Connect(
    function(message, messageType)

        if messageType == Enum.MessageType.MessageError then
            addError(message)
        end

    end
)

-- ============================================================
-- CLIPBOARD FUNCTION
-- ============================================================

local function copyToClipboard(text)
    if type(setclipboard) == "function" then
        local success = pcall(setclipboard, text)
        return success
    end

    return false
end

-- Copy execution errors
CopyErrors.MouseButton1Click:Connect(function()

    local textToCopy

    if #Errors > 0 then
        textToCopy = table.concat(Errors, "\n\n")
    else
        textToCopy = "No errors detected."
    end

    if copyToClipboard(textToCopy) then
        Status.Text = "Error log copied successfully."
    else
        Status.Text = "Clipboard API unavailable."
    end

end)

-- ============================================================
-- DISCORD REPORT SECTION
-- ============================================================

local ReportText = create("TextLabel", {
    Name = "ReportText",
    Size = UDim2.new(1, -30, 0, 22),
    Position = UDim2.fromOffset(15, 277),
    BackgroundTransparency = 1,
    Text = "BUGS? REPORT ON DISCORD",
    TextColor3 = Color3.fromRGB(150, 175, 215),
    TextSize = 13,
    Font = Enum.Font.GothamBold
}, MainFrame)

applyFont(ReportText)

-- ============================================================
-- DISCORD BUTTON
-- ============================================================

local DiscordButton = create("TextButton", {
    Name = "DiscordButton",
    Size = UDim2.new(1, -40, 0, 40),
    Position = UDim2.fromOffset(20, 307),
    BackgroundColor3 = Color3.fromRGB(17, 36, 65),
    Text = "COPY DISCORD LINK",
    TextColor3 = Color3.fromRGB(190, 215, 255),
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = true
}, MainFrame)

create("UICorner", {
    CornerRadius = UDim.new(0, 6)
}, DiscordButton)

create("UIStroke", {
    Color = Color3.fromRGB(35, 75, 135),
    Thickness = 1
}, DiscordButton)

DiscordButton.MouseButton1Click:Connect(function()

    if copyToClipboard(DISCORD_LINK) then
        Status.Text = "Discord link copied successfully."
    else
        Status.Text = "Clipboard API unavailable."
    end

end)

-- ============================================================
-- EXECUTE REMOTE SCRIPT
-- ============================================================

task.spawn(function()

    Status.Text = "Downloading remote script..."

    local success, executionError = pcall(function()

        -- Download script
        local source = game:HttpGet(SCRIPT_URL)

        if type(source) ~= "string" or source == "" then
            error("Failed to download the remote script.")
        end

        -- Compile script
        if type(loadstring) ~= "function" then
            error("Loadstring is unavailable in this environment.")
        end

        local compiledScript, compileError = loadstring(source)

        if not compiledScript then
            error(
                "Compilation failed: " .. tostring(compileError)
            )
        end

        -- Execute script
        Status.Text = "Executing remote script..."

        local runSuccess, runtimeError = xpcall(
            compiledScript,
            function(err)
                return debug.traceback(tostring(err), 2)
            end
        )

        if not runSuccess then
            error(runtimeError, 0)
        end

    end)

    -- ========================================================
    -- EXECUTION RESULT
    -- ========================================================

    SpinnerTween:Cancel()
    Spinner.Visible = false

    if success then

        Status.Text = "Script loaded successfully."
        Status.TextColor3 = Color3.fromRGB(100, 220, 145)

    else

        addError("LOADER: " .. tostring(executionError))

        Status.Text = "Script failed. Check the execution log."
        Status.TextColor3 = Color3.fromRGB(255, 100, 100)

    end

end)

-- ============================================================
-- END OF W-AZURE V3 ONE CLICK
-- ============================================================
