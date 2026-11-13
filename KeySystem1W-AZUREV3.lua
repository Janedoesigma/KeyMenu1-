-- Serviços
local CoreGui = game:GetService("CoreGui")

-- ============================================================
-- 1. FUNÇÃO QUE CRIA A INTERFACE (RETORNA A TABELA UI)
-- ============================================================
local function createKeyUI()
    local ScreenGui = Instance.new("ScreenGui")
    local MainFrame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local KeyInput = Instance.new("TextBox")
    local SubmitButton = Instance.new("TextButton")
    local GetKeyButton = Instance.new("TextButton")
    local StatusLabel = Instance.new("TextLabel")

    -- ScreenGui
    ScreenGui.Name = "VampKeySystemUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false

    -- MainFrame
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, -150, 0.5, -110)
    MainFrame.Size = UDim2.new(0, 300, 0, 220)
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

    -- Title
    Title.Name = "Title"
    Title.Parent = MainFrame
    Title.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
    Title.BorderSizePixel = 0
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.Font = Enum.Font.GothamSemibold
    Title.Text = "🔑 VAMP Auth – Key System"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 16
    Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)

    -- KeyInput
    KeyInput.Name = "KeyInput"
    KeyInput.Parent = MainFrame
    KeyInput.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    KeyInput.BorderSizePixel = 0
    KeyInput.Position = UDim2.new(0.5, -125, 0.25, 0)
    KeyInput.Size = UDim2.new(0, 250, 0, 35)
    KeyInput.Font = Enum.Font.Gotham
    KeyInput.PlaceholderText = "Cole sua chave aqui..."
    KeyInput.Text = ""
    KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyInput.TextSize = 14
    Instance.new("UICorner", KeyInput).CornerRadius = UDim.new(0, 6)

    -- SubmitButton
    SubmitButton.Name = "SubmitButton"
    SubmitButton.Parent = MainFrame
    SubmitButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    SubmitButton.BorderSizePixel = 0
    SubmitButton.Position = UDim2.new(0.5, -125, 0.45, 0)
    SubmitButton.Size = UDim2.new(0, 120, 0, 32)
    SubmitButton.Font = Enum.Font.GothamSemibold
    SubmitButton.Text = "✅ Verificar Chave"
    SubmitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SubmitButton.TextSize = 13
    Instance.new("UICorner", SubmitButton).CornerRadius = UDim.new(0, 6)

    -- GetKeyButton
    GetKeyButton.Name = "GetKeyButton"
    GetKeyButton.Parent = MainFrame
    GetKeyButton.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    GetKeyButton.BorderSizePixel = 0
    GetKeyButton.Position = UDim2.new(0.5, 5, 0.45, 0)
    GetKeyButton.Size = UDim2.new(0, 120, 0, 32)
    GetKeyButton.Font = Enum.Font.GothamSemibold
    GetKeyButton.Text = "🔗 Obter Chave"
    GetKeyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    GetKeyButton.TextSize = 13
    Instance.new("UICorner", GetKeyButton).CornerRadius = UDim.new(0, 6)

    -- StatusLabel
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Parent = MainFrame
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 0, 0.68, 0)
    StatusLabel.Size = UDim2.new(1, 0, 0, 25)
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.Text = "Aguardando chave..."
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 12

    -- ✅ ESSENCIAL: Retorna a tabela com todos os elementos criados
    return {
        ScreenGui = ScreenGui,
        KeyInput = KeyInput,
        SubmitButton = SubmitButton,
        GetKeyButton = GetKeyButton,
        StatusLabel = StatusLabel
    }
end

-- ============================================================
-- 2. INICIALIZAÇÃO E LIGAÇÃO DOS BOTÕES
-- ============================================================
local function initKeySystem()
    -- ✅ Atribui o retorno da função à variável 'ui'
    local ui = createKeyUI()

    -- Botão "Obter Chave"
    ui.GetKeyButton.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard("https://discord.gg/SEU_CONVITE")
            ui.StatusLabel.Text = "Link copiado! Cole no navegador."
            ui.StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            ui.StatusLabel.Text = "Acesse o Discord para obter a chave."
            ui.StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        end
    end)

    -- Botão "Verificar Chave" (Integração VAMP Auth)
    ui.SubmitButton.MouseButton1Click:Connect(function()
        local key = ui.KeyInput.Text

        if key == "" then
            ui.StatusLabel.Text = "❌ Digite uma chave!"
            ui.StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            return
        end

        ui.StatusLabel.Text = "⏳ Verificando chave..."
        ui.StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)

        -- Define a variável global esperada pelo loader do VAMP Auth
        script_key = key

        -- Executa o loader oficial (substitua pelo link do seu projeto se necessário)
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://vampauth.com/v1/loaders/87628613a60d3ef091eaf9beb5f593d2.lua"))()
        end)

        if success then
            ui.StatusLabel.Text = "✅ Chave válida! Carregando script..."
            ui.StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            task.delay(1, function()
                ui.ScreenGui:Destroy()
            end)
        else
            ui.StatusLabel.Text = "❌ Chave inválida ou expirada."
            ui.StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            warn("Erro no loader VAMP Auth: " .. tostring(err))
        end
    end)
end

-- Executa a inicialização
initKeySystem()
