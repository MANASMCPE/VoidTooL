--[[
    Life Together RP — VOID TOOL (Remake)
    Based on the original ToolVoid by Theo / Tory
    Adapted for LifeTogether RP by Cinnamon Software
    Modes: VOID | EXTREME | BRING | GIVE
]]

--====================================================================
-- SERVICES & VARIABLES
--====================================================================
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.2)

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local lp = Players.LocalPlayer

--====================================================================
-- CONFIGURATION
--====================================================================
local currentMode      = "VOID"          -- VOID / EXTREME / BRING / GIVE
local isProcessing     = false
local originalPos      = nil
local allowTeleportBack = false
local selectedToolName = nil
local switchedToR6     = false

local OrgDestroyHeight = workspace.FallenPartsDestroyHeight or -500
local EXTREME_CFRAME   = CFrame.new(9e9, 9999999, 9e9)

--====================================================================
-- SERVER REMOTE (LifeTogether RP)
--====================================================================
-- LifeTogether RP uses a remote inside ReplicatedStorage.
-- We try several known names; if none is found, the script still
-- works in client‑only mode for VOID/BRING/GIVE (EXTREME needs server).
local function getServerRemote()
    local candidates = {
        "01_server",          -- original name used in many LT scripts
        "Server",
        "Remotes",
        "MainRemote",
        "GameRemote",
    }
    for _, name in ipairs(candidates) do
        local obj = ReplicatedStorage:FindFirstChild(name)
        if obj and obj:IsA("RemoteEvent") then
            return obj
        end
    end
    -- fallback: first RemoteEvent in ReplicatedStorage
    for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
        if obj:IsA("RemoteEvent") then
            return obj
        end
    end
    return nil
end

local ServerRemote = getServerRemote()

local function FireServerCmd(...)
    if ServerRemote then
        pcall(function()
            ServerRemote:FireServer(...)
        end)
    end
end

local function ForceServerReset()   FireServerCmd("cmd", "-re") end
local function RemoveHats()         FireServerCmd("cmd", "-ch") end
local function ChangeToR6()         FireServerCmd("cmd", "-r6") end
local function ChangeToR15()        FireServerCmd("cmd", "-r15") end

--====================================================================
-- HELPERS
--====================================================================
local function GetPlr(name)
    if not name or name == "" then return end
    name = name:lower():gsub("([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")
    for _, a in ipairs(Players:GetPlayers()) do
        if a ~= lp then
            local char = a.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local n, d = a.Name:lower(), a.DisplayName:lower()
                    if n:find("^" .. name) or d:find("^" .. name) then
                        return a
                    end
                end
            end
        end
    end
end

--====================================================================
-- CORE LOGIC (same as original, with safety checks)
--====================================================================
local function mainRun(targetName)
    local target = GetPlr(targetName)
    if not target then return false end

    local targetchar = target.Character
    local targethrp  = targetchar and targetchar:WaitForChild("HumanoidRootPart", 5)
    if not targethrp then return false end

    local char = lp.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local backpack = lp:WaitForChild("Backpack")

    -- Select tool
    local Tool = selectedToolName
        and (char:FindFirstChild(selectedToolName) or backpack:FindFirstChild(selectedToolName))
        or (char:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool"))

    if not Tool then return "NO TOOL" end

    -- R6 conversion (some games need it for void tricks)
    if char.Humanoid.RigType ~= Enum.HumanoidRigType.R6 then
        ChangeToR6()
        switchedToR6 = true
    end
    task.wait(0.2)

    RemoveHats()

    local originalDestroyHeight = workspace.FallenPartsDestroyHeight

    --================================================================
    -- GIVE MODE (does not clone HRP)
    --================================================================
    if currentMode == "GIVE" then
        if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0,0,0) end
        if char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid"):Destroy()
        end
        task.wait(0.05)
        Instance.new("Humanoid").Parent = char
        Tool.Parent = char

        local handle = Tool:FindFirstChild("Handle")
        local giveStart = os.clock()
        while Tool.Parent == char and (os.clock() - giveStart) < 3 do
            task.wait()
            pcall(function()
                hrp.CFrame = targethrp.CFrame
                if handle then handle.CFrame = targethrp.CFrame end
            end)
        end

        workspace.FallenPartsDestroyHeight = originalDestroyHeight
        lp.Character = nil
        FireServerCmd("cmd", "-rs")
        ForceServerReset()
        return true
    end

    --================================================================
    -- VOID / EXTREME / BRING — clone HRP trick
    --================================================================
    char.Archivable = true
    local Clone = char:Clone()
    task.wait(0.05)
    lp.Character = Clone
    task.wait(0.1)
    lp.Character = char
    task.wait(0.1)

    if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0,0,0) end
    if char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid"):Destroy()
    end
    task.wait(0.05)

    local Humanoid = Instance.new("Humanoid")
    Humanoid.Parent = char
    task.wait(0.05)

    Tool.Grip = CFrame.new(0,0,0)
    Tool.Parent = char
    local handle = Tool:FindFirstChild("Handle")

    -- Noclip while holding the tool
    local noclipConn = RunService.Stepped:Connect(function()
        if char then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
        end
    end)

    local hasInteracted = false
    local interactTime = 0
    local startTime     = os.clock()

    repeat
        RunService.Stepped:Wait()

        if not Tool or not Tool:IsDescendantOf(game) then break end
        if Tool.Parent ~= char and Tool.Parent ~= targetchar and Tool.Parent ~= workspace then break end
        if not hasInteracted and (os.clock() - startTime > 5.0) then break end

        if targetchar and targethrp and hrp then
            -- Victim picked up the tool
            if Tool.Parent == targetchar and not hasInteracted then
                hasInteracted = true
                interactTime = os.clock()

                if currentMode == "BRING" then
                    task.wait(0.15)
                    break
                else
                    task.wait(0.02)
                end
            end

            if hasInteracted then
                --========== VOID ==========
                if currentMode == "VOID" then
                    workspace.FallenPartsDestroyHeight = 0/1/0   -- anti‑void bypass
                    local voidCF = CFrame.new(
                        hrp.Position.X,
                        (OrgDestroyHeight or originalDestroyHeight or -500) - 25,
                        hrp.Position.Z
                    )
                    hrp.CFrame = voidCF
                    pcall(function()
                        targethrp.CFrame = voidCF
                        targethrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    end)
                    if os.clock() - interactTime > 1.5 then break end

                --========== EXTREME ==========
                elseif currentMode == "EXTREME" then
                    workspace.FallenPartsDestroyHeight = 0/1/0
                    hrp.CFrame = EXTREME_CFRAME
                    pcall(function()
                        targethrp.CFrame = EXTREME_CFRAME
                        targethrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    end)
                    if os.clock() - interactTime > 2.0 then break end

                --========== BRING ==========
                elseif currentMode == "BRING" then
                    if originalPos then
                        hrp.CFrame = originalPos
                        pcall(function()
                            targethrp.CFrame = originalPos
                            targethrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                        end)
                    end
                    if os.clock() - interactTime > 1.8 then break end
                end
            else
                -- Victim has not yet picked up the tool; move victim's HRP to the tool handle
                if currentMode == "EXTREME" then
                    pcall(function() hrp.CFrame = targethrp.CFrame end)
                    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)

                elseif currentMode == "VOID" then
                    workspace.FallenPartsDestroyHeight = 0/1/0
                    local preVoid = CFrame.new(
                        originalPos.Position.X,
                        (OrgDestroyHeight or originalDestroyHeight or -500) - 25,
                        originalPos.Position.Z
                    )
                    hrp.CFrame = preVoid
                    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    pcall(function()
                        targethrp.CFrame = handle.CFrame
                        targethrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    end)

                else -- BRING
                    pcall(function()
                        targethrp.CFrame = handle.CFrame
                        targethrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    end)
                    hrp.CFrame = originalPos
                    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                end
            end
        else
            break
        end
    until Tool.Parent == workspace

    -- Clean‑up
    workspace.FallenPartsDestroyHeight = originalDestroyHeight
    if noclipConn then noclipConn:Disconnect() end

    if currentMode == "BRING" then
        if hrp and originalPos then
            hrp.AssemblyLinearVelocity   = Vector3.new(0,0,0)
            hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
            hrp.CFrame = originalPos
            pcall(function()
                targethrp.AssemblyLinearVelocity   = Vector3.new(0,0,0)
                targethrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
                targethrp.CFrame = originalPos
            end)
            task.wait(0.4)
        end
    else
        if hrp and originalPos then
            hrp.CFrame = originalPos
            RunService.Heartbeat:Wait()
        end
    end

    lp.Character = nil
    return true
end

--====================================================================
-- RESPAWN / TELEPORT BACK
--====================================================================
local function WaitForCharacterAdded(timeout)
    local deadline = os.clock() + (timeout or 5)
    local fired = false
    local conn = lp.CharacterAdded:Connect(function() fired = true end)
    while os.clock() < deadline and not fired do
        task.wait(0.05)
    end
    conn:Disconnect()
    return fired
end

local function TeleportBackAfterRespawn()
    if not allowTeleportBack or not originalPos then return end
    local targetPos = originalPos

    local newChar = lp.Character
    local deadline = os.clock() + 3
    while not newChar and os.clock() < deadline do
        task.wait(0.05)
        newChar = lp.Character
    end
    if not newChar then return end

    task.wait(0.15)
    for _ = 1, 4 do
        local hrp = newChar:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = targetPos
            hrp.AssemblyLinearVelocity   = Vector3.new(0,0,0)
            hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
        end
        task.wait(0.15)
    end
end

local function ExecuteSequence(targetName)
    if isProcessing then return end
    local char = lp.Character
    if not char or not char:FindFirstChildOfClass("Humanoid") then return "NO CHAR" end

    isProcessing = true
    local hrp = char:FindFirstChild("HumanoidRootPart")
    originalPos = hrp and hrp.CFrame or nil
    allowTeleportBack = true

    local successStatus = mainRun(targetName)

    if not successStatus or successStatus == "NO TOOL" then
        isProcessing = false
        originalPos = nil
        allowTeleportBack = false
        return (successStatus == "NO TOOL") and "NO TOOL" or "NOT FOUND"
    end

    local respawned = false
    for _ = 1, 3 do
        lp.Character = nil
        ForceServerReset()
        if WaitForCharacterAdded(1.2) then
            respawned = true
            break
        end
    end

    TeleportBackAfterRespawn()

    if switchedToR6 then
        switchedToR6 = false
        ChangeToR15()
    end

    originalPos = nil
    allowTeleportBack = false
    isProcessing = false
    task.wait(0.15)
    return "SUCCESS"
end

--====================================================================
-- GUI
--====================================================================
local MODE_COLORS = {
    VOID    = Color3.fromRGB(190, 210, 255),
    EXTREME = Color3.fromRGB(255, 150, 190),
    BRING   = Color3.fromRGB(150, 255, 190),
    GIVE    = Color3.fromRGB(255, 210, 130),
}

local function BuildGui()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LT_VoidTool"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false

    -- Main frame
    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name = "MainFrame"
    MainFrame.BorderSizePixel = 0
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    MainFrame.Size = UDim2.new(0.25, 0, 0.35, 0)
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.Active = true
    MainFrame.Draggable = true
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", MainFrame)
    stroke.Color = Color3.fromRGB(100, 200, 255)
    stroke.Thickness = 2

    -- Title
    local Title = Instance.new("TextLabel", MainFrame)
    Title.Name = "Title"
    Title.BorderSizePixel = 0
    Title.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    Title.Size = UDim2.new(0.7, 0, 0.12, 0)
    Title.Position = UDim2.new(0.15, 0, 0.02, 0)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextColor3 = Color3.fromRGB(100, 200, 255)
    Title.Text = "LT VOID TOOL"

    -- Close button
    local CloseBtn = Instance.new("TextButton", MainFrame)
    CloseBtn.Name = "Close"
    CloseBtn.BorderSizePixel = 0
    CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 61, 136)
    CloseBtn.Size = UDim2.new(0.12, 0, 0.12, 0)
    CloseBtn.Position = UDim2.new(0.86, 0, 0.02, 0)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 14
    CloseBtn.Text = "X"
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

    -- Minimize button
    local MinimizeBtn = Instance.new("TextButton", MainFrame)
    MinimizeBtn.Name = "Minimize"
    MinimizeBtn.BorderSizePixel = 0
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 210, 130)
    MinimizeBtn.Size = UDim2.new(0.12, 0, 0.12, 0)
    MinimizeBtn.Position = UDim2.new(0.73, 0, 0.02, 0)
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.TextSize = 14
    MinimizeBtn.Text = "-"
    Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

    -- Mode display
    local ModeLabel = Instance.new("TextLabel", MainFrame)
    ModeLabel.Name = "ModeLabel"
    ModeLabel.BorderSizePixel = 0
    ModeLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    ModeLabel.Size = UDim2.new(0.8, 0, 0.1, 0)
    ModeLabel.Position = UDim2.new(0.1, 0, 0.18, 0)
    ModeLabel.Font = Enum.Font.Gotham
    ModeLabel.TextSize = 14
    ModeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ModeLabel.Text = "Mode: VOID"
    Instance.new("UICorner", ModeLabel).CornerRadius = UDim.new(0, 6)

    -- Target input
    local TargetBox = Instance.new("TextBox", MainFrame)
    TargetBox.Name = "TargetBox"
    TargetBox.BorderSizePixel = 0
    TargetBox.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    TargetBox.Size = UDim2.new(0.8, 0, 0.12, 0)
    TargetBox.Position = UDim2.new(0.1, 0, 0.32, 0)
    TargetBox.Font = Enum.Font.Gotham
    TargetBox.TextSize = 14
    TargetBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    TargetBox.PlaceholderText = "Enter player name..."
    TargetBox.Text = ""
    TargetBox.ClearTextOnFocus = false
    Instance.new("UICorner", TargetBox).CornerRadius = UDim.new(0, 6)
    local inputStroke = Instance.new("UIStroke", TargetBox)
    inputStroke.Color = Color3.fromRGB(100, 200, 255)
    inputStroke.Thickness = 1

    -- Tool selector button
    local ToolBtn = Instance.new("TextButton", MainFrame)
    ToolBtn.Name = "ToolBtn"
    ToolBtn.BorderSizePixel = 0
    ToolBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    ToolBtn.Size = UDim2.new(0.8, 0, 0.1, 0)
    ToolBtn.Position = UDim2.new(0.1, 0, 0.47, 0)
    ToolBtn.Font = Enum.Font.GothamBold
    ToolBtn.TextSize = 14
    ToolBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
    ToolBtn.Text = "Select Tool"
    Instance.new("UICorner", ToolBtn).CornerRadius = UDim.new(0, 6)

    -- Switch mode button
    local SwitchBtn = Instance.new("TextButton", MainFrame)
    SwitchBtn.Name = "SwitchBtn"
    SwitchBtn.BorderSizePixel = 0
    SwitchBtn.BackgroundColor3 = Color3.fromRGB(255, 210, 130)
    SwitchBtn.Size = UDim2.new(0.38, 0, 0.1, 0)
    SwitchBtn.Position = UDim2.new(0.1, 0, 0.62, 0)
    SwitchBtn.Font = Enum.Font.GothamBold
    SwitchBtn.TextSize = 14
    SwitchBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
    SwitchBtn.Text = "Switch Mode"
    Instance.new("UICorner", SwitchBtn).CornerRadius = UDim.new(0, 6)

    -- Start button
    local StartBtn = Instance.new("TextButton", MainFrame)
    StartBtn.Name = "StartBtn"
    StartBtn.BorderSizePixel = 0
    StartBtn.BackgroundColor3 = Color3.fromRGB(150, 255, 190)
    StartBtn.Size = UDim2.new(0.38, 0, 0.1, 0)
    StartBtn.Position = UDim2.new(0.52, 0, 0.62, 0)
    StartBtn.Font = Enum.Font.GothamBold
    StartBtn.TextSize = 14
    StartBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
    StartBtn.Text = "START"
    Instance.new("UICorner", StartBtn).CornerRadius = UDim.new(0, 6)

    -- Status label
    local StatusLabel = Instance.new("TextLabel", MainFrame)
    StatusLabel.Name = "StatusLabel"
    StatusLabel.BorderSizePixel = 0
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Size = UDim2.new(0.8, 0, 0.08, 0)
    StatusLabel.Position = UDim2.new(0.1, 0, 0.78, 0)
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextSize = 12
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.Text = ""

    -- Tool list (hidden by default)
    local ToolFrame = Instance.new("Frame", MainFrame)
    ToolFrame.Name = "ToolFrame"
    ToolFrame.BorderSizePixel = 0
    ToolFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    ToolFrame.Size = UDim2.new(0.8, 0, 0.4, 0)
    ToolFrame.Position = UDim2.new(0.1, 0, 0.5, 0)
    ToolFrame.Visible = false
    Instance.new("UICorner", ToolFrame).CornerRadius = UDim.new(0, 6)
    local listLayout = Instance.new("UIListLayout", ToolFrame)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    local padding = Instance.new("UIPadding", ToolFrame)
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.PaddingLeft = UDim.new(0, 6)
    padding.PaddingRight = UDim.new(0, 6)

    ScreenGui.Parent = CoreGui

    return ScreenGui, MainFrame, ModeLabel, TargetBox, ToolBtn, SwitchBtn, StartBtn,
           StatusLabel, ToolFrame, CloseBtn, MinimizeBtn
end

--====================================================================
-- GUI LOGIC
--====================================================================
-- Remove old GUI
local playerGui = lp:WaitForChild("PlayerGui")
for _, name in ipairs({"LT_VoidTool", "ToolVoidByTory", "ToolVoid"}) do
    local a = CoreGui:FindFirstChild(name)
    if a then a:Destroy() end
    local b = playerGui:FindFirstChild(name)
    if b then b:Destroy() end
end

local ScreenGui, MainFrame, ModeLabel, TargetBox, ToolBtn, SwitchBtn, StartBtn,
      StatusLabel, ToolFrame, CloseBtn, MinimizeBtn = BuildGui()

local toolListOpen = false

local function UpdateModeUI()
    ModeLabel.Text = "Mode: " .. currentMode
    ModeLabel.TextColor3 = MODE_COLORS[currentMode] or Color3.new(1, 1, 1)
end
UpdateModeUI()

local function SetStatus(text, color)
    StatusLabel.Text = text
    StatusLabel.TextColor3 = color or Color3.fromRGB(200, 200, 200)
end

-- Refresh tool list
local function RefreshToolList()
    for _, child in ipairs(ToolFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local found = {}
    local function scan(parent)
        if not parent then return end
        for _, obj in ipairs(parent:GetChildren()) do
            if obj:IsA("Tool") and not found[obj.Name] then
                found[obj.Name] = true
            end
        end
    end
    scan(lp:FindFirstChild("Backpack"))
    scan(lp.Character)

    for tName, _ in pairs(found) do
        local tBtn = Instance.new("TextButton", ToolFrame)
        tBtn.Size = UDim2.new(1, 0, 0, 26)
        tBtn.BorderSizePixel = 0
        tBtn.TextSize = 14
        tBtn.TextScaled = true
        tBtn.Text = tName
        tBtn.BackgroundColor3 = (selectedToolName == tName)
            and Color3.fromRGB(84, 168, 120)
            or Color3.fromRGB(60, 60, 80)
        tBtn.TextColor3 = Color3.new(1, 1, 1)
        Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0, 4)
        tBtn.MouseButton1Click:Connect(function()
            selectedToolName = (selectedToolName == tName) and nil or tName
            RefreshToolList()
        end)
    end
end

-- Toggle tool list
ToolBtn.MouseButton1Click:Connect(function()
    toolListOpen = not toolListOpen
    if toolListOpen then
        RefreshToolList()
        ToolFrame.Visible = true
    else
        ToolFrame.Visible = false
    end
end)

-- Switch mode
SwitchBtn.MouseButton1Click:Connect(function()
    if currentMode == "VOID" then currentMode = "EXTREME"
    elseif currentMode == "EXTREME" then currentMode = "BRING"
    elseif currentMode == "BRING" then currentMode = "GIVE"
    else currentMode = "VOID" end
    UpdateModeUI()
end)

-- Minimize
local minimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    for _, child in ipairs(MainFrame:GetChildren()) do
        if child ~= MinimizeBtn and child ~= CloseBtn and child ~= MainFrame:FindFirstChild("Title") then
            child.Visible = not minimized
        end
    end
    if minimized and toolListOpen then
        toolListOpen = false
        ToolFrame.Visible = false
    end
end)

-- Close
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Start
local function Run(targetName)
    if isProcessing then return end
    SetStatus("Checking...", Color3.fromRGB(255, 210, 130))
    local res = ExecuteSequence(targetName)
    if res == "NOT FOUND" then
        SetStatus("Player not found!", Color3.fromRGB(255, 150, 190))
    elseif res == "NO TOOL" then
        SetStatus("No tool selected!", Color3.fromRGB(255, 150, 190))
    elseif res == "NO CHAR" then
        SetStatus("Character not ready!", Color3.fromRGB(255, 150, 190))
    else
        SetStatus("Done!", Color3.fromRGB(150, 255, 190))
    end
    RefreshToolList()
end

StartBtn.MouseButton1Click:Connect(function()
    if isProcessing then return end
    local name = TargetBox.Text
    if name == "" then
        SetStatus("Enter a player name!", Color3.fromRGB(255, 210, 130))
        return
    end
    Run(name)
end)

TargetBox.FocusLost:Connect(function(enterPressed)
    if enterPressed and TargetBox.Text ~= "" and not isProcessing then
        Run(TargetBox.Text)
    end
end)

--====================================================================
-- ANTI‑VOID (optional, protects YOU from other void scripts)
--====================================================================
-- This section keeps your FallenPartsDestroyHeight safe.
-- You can uncomment the lines below if you want extra protection.
--[[
RunService.Heartbeat:Connect(function()
    if workspace.FallenPartsDestroyHeight > -100 then
        workspace.FallenPartsDestroyHeight = -500
    end
end)
]]

print("[LT VOID TOOL] Loaded successfully.")