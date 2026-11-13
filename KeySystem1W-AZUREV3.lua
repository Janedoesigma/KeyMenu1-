-- Substitua a lógica antiga do botão "Verificar Chave" por esta:

ui.SubmitButton.MouseButton1Click:Connect(function()
    local key = ui.KeyInput.Text

    if key == "" then
        ui.StatusLabel.Text = "❌ Digite uma chave!"
        ui.StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        return
    end

    ui.StatusLabel.Text = "⏳ Verificando chave..."
    ui.StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)

    -- Define a chave global que o loader do VAMP Auth espera
    script_key = key

    -- Executa o loader do VAMP Auth
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://vampauth.com/v1/loaders/87628613a60d3ef091eaf9beb5f593d2.lua"))()
    end)

    if success then
        -- O loader cuidou de tudo: se a chave for válida, o script principal já foi executado.
        -- Podemos simplesmente fechar a interface.
        ui.StatusLabel.Text = "✅ Chave válida! Carregando script..."
        ui.StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)

        task.delay(1, function()
            ui.ScreenGui:Destroy()
        end)
    else
        -- Se o loader lançar um erro, provavelmente a chave é inválida.
        ui.StatusLabel.Text = "❌ Chave inválida ou expirada."
        ui.StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        warn("Erro no loader: " .. tostring(err))
    end
end)
