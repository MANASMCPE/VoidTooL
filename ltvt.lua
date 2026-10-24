--[[
    Life Together RP — FIXED VOID TOOL
    GUI Fix: PlayerGui use kiya gaya hai (CoreGui block executors ke liye)
]]

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.2)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer

-- ================= CONFIG =================
local currentMode = "VOID"  -- VOID / EXTREME / BRING / GIVE
local isProcessing = false
local originalPos = nil
local allowTeleportBack = false
local selectedToolName = nil
local switchedToR6 = false

local OrgDestroyHeight = workspace.FallenPartsDestroyHeight or -500
local EXTREME_CFRAME = CFrame.new(9e9, 9999999, 9e9)

-- ================= SERVER REMOTE =================
-- Life Together RP mein remote ka naam alag ho sakta hai.
-- Neeche common names hain; agar RemoteSpy se actual naam mile toh yahan add karo.
local function getServerRemote()
    local candidates = {"01_server", "Server", "Remotes", "MainRemote", "GameRemote"}
    for _, name in ipairs(candidates) do
        local obj = ReplicatedStorage:FindFirstChild(name)
        if obj and obj:IsA("RemoteEvent") then return obj end
    end
    for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
        if obj:IsA("RemoteEvent") then return obj end
    end
    return nil
end
local ServerRemote = getServerRemote()

local function FireServerCmd(...)
    if ServerRemote then pcall(function() ServerRemote:FireServer(...) end) end
end
local function ForceServerReset() FireServerCmd("cmd", "-re") end
local function RemoveHats() FireServerCmd("cmd", "-ch") end
local function ChangeToR6() FireServerCmd("cmd", "-r6") end
local function ChangeToR15() FireServerCmd("cmd", "-r15") end

-- ================= HELPERS =================
local function GetPlr(name)
    if not name or name == "" then return end
    name = name:lower():gsub("([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")
    for _, a in ipairs(Players:GetPlayers()) do
        if a ~= lp and a.Character then
            local hrp = a.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local n, d = a.Name:lower(), a.DisplayName:lower()
                if n:find("^" .. name) or d:find("^" .. name) then return a end
            end
        end
    end
end

-- ================= CORE LOGIC =================
local function mainRun(targetName)
    local target = GetPlr(targetName)
    if not target then return false end
    local targetchar = target.Character
    local targethrp = targetchar and targetchar:WaitForChild("HumanoidRootPart", 5)
    if not targethrp then return false end

    local char = lp.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local backpack = lp:WaitForChild("Backpack")

    local Tool = selectedToolName
        and (char:FindFirstChild(selectedToolName) or backpack:FindFirstChild(selectedToolName))
        or (char:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool"))
    if not Tool then return "NO TOOL" end

    if char.Humanoid.RigType ~= Enum.HumanoidRigType.R6 then
        ChangeToR6(); switchedToR6 = true
    end
    task.wait(0.2)
    RemoveHats()

    local originalDestroyHeight = workspace.FallenPartsDestroyHeight

    -- GIVE MODE (no HRP clone)
    if currentMode == "GIVE" then
        if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0,0,0) end
        if char:FindFirstChildOfClass("Humanoid") then char:FindFirstChildOfClass("Humanoid"):Destroy() end
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

    -- VOID / EXTREME / BRING — clone HRP trick
    char.Archivable = true
    local Clone = char:Clone()
    task.wait(0.05)
    lp.Character = Clone
    task.wait(0.1)
    lp.Character = char
    task.wait(0.1)

    if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0,0,0) end
    if char:FindFirstChildOfClass("Humanoid") then char:FindFirstChildOfClass("Humanoid"):Destroy() end
    task.wait(0.05)
    Instance.new("Humanoid").Parent = char
    task.wait(0.05)

    Tool.Grip = CFrame.new(0,0,0)
    Tool.Parent = char
    local handle = Tool:FindFirstChild("Handle")

    local noclipConn = RunService.Stepped:Connect(function()
        if char then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
        end
    end)

    local hasInteracted, interactTime = false, 0
    local startTime = os.clock()

    repeat
        RunService.Stepped:Wait()
        if not Tool or not Tool:IsDescendantOf(game) then break end
        if Tool.Parent ~= char and Tool.Parent ~= targetchar and Tool.Parent ~= workspace then break end
        if not hasInteracted and (os.clock() - startTime > 5.0) then break end

        if targetchar and targethrp and hrp then
            if Tool.Parent == targetchar and not hasInteracted then
                hasInteracted = true
                interactTime = os.clock()
                if currentMode == "BRING" then task.wait(0.15); break else task.wait(0.02) end
            end

            if hasInteracted then
                if currentMode == "VOID" then
                    workspace.FallenPartsDestroyHeight = 0/1/0
                    local voidCF = CFrame.new(hrp.Position.X, (OrgDestroyHeight or originalDestroyHeight or -500) - 25, hrp.Position.Z)
                    hrp.CFrame = voidCF
                    pcall(function()
                        targethrp.CFrame = voidCF
                        targethrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    end)
                    if os.clock() - interactTime > 1.5 then break end
                elseif currentMode == "EXTREME" then
                    workspace.FallenPartsDestroyHeight = 0/1/0
                    hrp.CFrame = EXTREME_CFRAME
                    pcall(function()
                        targethrp.CFrame = EXTREME_CFRAME
                        targethrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    end)
                    if os.clock() - interactTime > 2.0 then break end
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
                if currentMode == "EXTREME" then
                    pcall(function() hrp.CFrame = targethrp.CFrame end)
                    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                elseif currentMode == "VOID" then
                    workspace.FallenPartsDestroyHeight = 0/1/0
                    local preVoid = CFrame.new(originalPos.Position.X, (OrgDestroyHeight or originalDestroyHeight or -500) - 25, originalPos.Position.Z)
                    hrp.CFrame = preVoid
                    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    pcall(function()
                        targethrp.CFrame = handle.CFrame
                        targethrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    end)
                else
                    pcall(function()
                        targethrp.CFrame = handle.CFrame
                        targethrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    end)
                    hrp.CFrame = originalPos
                    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                end
            end
        else break end
    until Tool.Parent == workspace

    workspace.FallenPartsDestroyHeight = originalDestroyHeight
    if noclipConn then noclipConn:Disconnect() end

    if currentMode == "BRING" and hrp and originalPos then
        hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
        hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
        hrp.CFrame = originalPos
        pcall(function()
            targethrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
            targethrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
            targethrp.CFrame = originalPos
        end)
        task.wait(0.4)
    elseif hrp and originalPos then
        hrp.CFrame = originalPos
        RunService.Heartbeat:Wait()
    end
    lp.Character = nil
    return true
end

-- ================= RESPAWN / TELEPORT BACK =================
local function WaitForCharacterAdded(timeout)
    local deadline = os.clock() + (timeout or 5)
    local fired = false
    local conn = lp.CharacterAdded:Connect(function() fired = true end)
    while os.clock() < deadline and not fired do task.wait(0.05) end
    conn:Disconnect()
    return fired
end

local function TeleportBackAfterRespawn()
    if not allowTeleportBack or not originalPos then return end
    local targetPos = originalPos
    local newChar = lp.Character
    local deadline = os.clock() + 3
    while not newChar and os.clock() < deadline do
        task.wait(0.05); newChar = lp.Character
    end
    if not newChar then return end
    task.wait(0.15)
    for _ = 1, 4 do
        local hrp = newChar:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = targetPos
            hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
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
        isProcessing = false; originalPos = nil; allowTeleportBack = false
        return (successStatus == "NO TOOL") and "NO TOOL" or "NOT FOUND"
    end
    local respawned = false
    for _ = 1, 3 do
        lp.Character = nil
        ForceServerReset()
        if WaitForCharacterAdded(1.2) then respawned = true; break end
    end
    TeleportBackAfterRespawn()
    if switchedToR6 then switchedToR6 = false; ChangeToR15() end
    originalPos = nil; allowTeleportBack = false; isProcessing = false
    task.wait(0.15)
    return "SUCCESS"
end

-- ================= GUI (FIXED: PlayerGui) =================
local MODE_COLORS = {
    VOID    = Color3.fromRGB(190, 210, 255),
    EXTREME = Color3.fromRGB(255, 150, 190),
    BRING   = Color3.fromRGB(150, 255, 190),
    GIVE    = Color3.fromRGB(255, 210, 130),
}

local function safeParent(gui)
    -- Pehle PlayerGui try karo (yehi main fix hai)
    local pg = lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 5)
    if pg then
        gui.Parent = pg
        print(">>> GUI parented to PlayerGui ✅")
        return true
    end
    -- Agar PlayerGui na mile toh CoreGui fallback
    local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    print(">>> CoreGui fallback:", ok)
    return ok
end

local function BuildGui()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LT_VoidTool_FIXED"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.DisplayOrder = 999

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.BorderSizePixel = 0
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    MainFrame.Size = UDim2.new(0, 350, 0, 420)
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = MainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 200, 255)
    stroke.Thickness = 2
    stroke.Parent = MainFrame

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -80, 0, 30)
    Title.Position = UDim2.new(0, 10, 0, 8)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextColor3 = Color3.fromRGB(100, 200, 255)
    Title.Text = "LT VOID TOOL (FIXED)"
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = MainFrame

    -- Close button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -40, 0, 8)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 61, 136)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 14
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    CloseBtn.Parent = MainFrame
    local ccorner = Instance.new("UICorner")
    ccorner.CornerRadius = UDim.new(0, 6)
    ccorner.Parent = CloseBtn
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    -- Minimize
    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    MinimizeBtn.Position = UDim2.new(1, -75, 0, 8)
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 210, 130)
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.TextSize = 14
    MinimizeBtn.Text = "-"
    MinimizeBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
    MinimizeBtn.Parent = MainFrame
    local mcorner = Instance.new("UICorner")
    mcorner.CornerRadius = UDim.new(0, 6)
    mcorner.Parent = MinimizeBtn

    -- Mode label
    local ModeLabel = Instance.new("TextLabel")
    ModeLabel.Name = "ModeLabel"
    ModeLabel.Size = UDim2.new(0.8, 0, 0, 30)
    ModeLabel.Position = UDim2.new(0.1, 0, 0, 50)
    ModeLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    ModeLabel.Font = Enum.Font.Gotham
    ModeLabel.TextSize = 14
    ModeLabel.TextColor3 = Color3.new(1, 1, 1)
    ModeLabel.Text = "Mode: VOID"
    ModeLabel.Parent = MainFrame
    local mlcorner = Instance.new("UICorner")
    mlcorner.CornerRadius = UDim.new(0, 6)
    mlcorner.Parent = ModeLabel

    -- Target input
    local TargetBox = Instance.new("TextBox")
    TargetBox.Name = "TargetBox"
    TargetBox.Size = UDim2.new(0.8, 0, 0, 36)
    TargetBox.Position = UDim2.new(0.1, 0, 0, 90)
    TargetBox.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    TargetBox.Font = Enum.Font.Gotham
    TargetBox.TextSize = 14
    TargetBox.TextColor3 = Color3.new(1, 1, 1)
    TargetBox.PlaceholderText = "Enter player name..."
    TargetBox.ClearTextOnFocus = false
    TargetBox.Parent = MainFrame
    local tbcorner = Instance.new("UICorner")
    tbcorner.CornerRadius = UDim.new(0, 6)
    tbcorner.Parent = TargetBox

    -- Tool selector
    local ToolBtn = Instance.new("TextButton")
    ToolBtn.Size = UDim2.new(0.8, 0, 0, 32)
    ToolBtn.Position = UDim2.new(0.1, 0, 0, 136)
    ToolBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    ToolBtn.Font = Enum.Font.GothamBold
    ToolBtn.TextSize = 14
    ToolBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
    ToolBtn.Text = "Select Tool"
    ToolBtn.Parent = MainFrame
    local tlbcorner = Instance.new("UICorner")
    tlbcorner.CornerRadius = UDim.new(0, 6)
    tlbcorner.Parent = ToolBtn

    -- Switch mode
    local SwitchBtn = Instance.new("TextButton")
    SwitchBtn.Size = UDim2.new(0.38, 0, 0, 32)
    SwitchBtn.Position = UDim2.new(0.1, 0, 0, 178)
    SwitchBtn.BackgroundColor3 = Color3.fromRGB(255, 210, 130)
    SwitchBtn.Font = Enum.Font.GothamBold
    SwitchBtn.TextSize = 14
    SwitchBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
    SwitchBtn.Text = "Switch Mode"
    SwitchBtn.Parent = MainFrame
    local swcorner = Instance.new("UICorner")
    swcorner.CornerRadius = UDim.new(0, 6)
    swcorner.Parent = SwitchBtn

    -- Start
    local StartBtn = Instance.new("TextButton")
    StartBtn.Size = UDim2.new(0.38, 0, 0, 32)
    StartBtn.Position = UDim2.new(0.52, 0, 0, 178)
    StartBtn.BackgroundColor3 = Color3.fromRGB(150, 255, 190)
    StartBtn.Font = Enum.Font.GothamBold
    StartBtn.TextSize = 14
    StartBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
    StartBtn.Text = "START"
    StartBtn.Parent = MainFrame
    local stcorner = Instance.new("UICorner")
    stcorner.CornerRadius = UDim.new(0, 6)
    stcorner.Parent = StartBtn

    -- Status
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(0.8, 0, 0, 24)
    StatusLabel.Position = UDim2.new(0.1, 0, 0, 218)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextSize = 12
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.Text = ""
    StatusLabel.Parent = MainFrame

    -- Tool list frame
    local ToolFrame = Instance.new("Frame")
    ToolFrame.Name = "ToolFrame"
    ToolFrame.Size = UDim2.new(0.8, 0, 0, 150)
    ToolFrame.Position = UDim2.new(0.1, 0, 0, 250)
    ToolFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    ToolFrame.Visible = false
    ToolFrame.Parent = MainFrame
    local tfcorner = Instance.new("UICorner")
    tfcorner.CornerRadius = UDim.new(0, 6)
    tfcorner.Parent = ToolFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = ToolFrame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.PaddingLeft = UDim.new(0, 6)
    padding.PaddingRight = UDim.new(0, 6)
    padding.Parent = ToolFrame

    -- Parent to PlayerGui (FIX)
    safeParent(ScreenGui)

    return ScreenGui, MainFrame, ModeLabel, TargetBox, ToolBtn, SwitchBtn, StartBtn,
           StatusLabel, ToolFrame, CloseBtn, MinimizeBtn
end

-- Purane GUI remove karo
local playerGui = lp:WaitForChild("PlayerGui")
for _, name in ipairs({"LT_VoidTool_FIXED", "LT_VoidTool", "ToolVoid"}) do
    local a = playerGui:FindFirstChild(name); if a then a:Destroy() end
    local b = game:GetService("CoreGui"):FindFirstChild(name); if b then b:Destroy() end
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

local function RefreshToolList()
    for _, child in ipairs(ToolFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local found = {}
    local function scan(parent)
        if not parent then return end
        for _, obj in ipairs(parent:GetChildren()) do
            if obj:IsA("Tool") and not found[obj.Name] then found[obj.Name] = true end
        end
    end
    scan(lp:FindFirstChild("Backpack")); scan(lp.Character)
    for tName, _ in pairs(found) do
        local tBtn = Instance.new("TextButton")
        tBtn.Size = UDim2.new(1, 0, 0, 26)
        tBtn.TextSize = 14
        tBtn.TextScaled = true
        tBtn.Text = tName
        tBtn.BackgroundColor3 = (selectedToolName == tName) and Color3.fromRGB(84, 168, 120) or Color3.fromRGB(60, 60, 80)
        tBtn.TextColor3 = Color3.new(1, 1, 1)
        tBtn.Parent = ToolFrame
        local tcorner = Instance.new("UICorner")
        tcorner.CornerRadius = UDim.new(0, 4)
        tcorner.Parent = tBtn
        tBtn.MouseButton1Click:Connect(function()
            selectedToolName = (selectedToolName == tName) and nil or tName
            RefreshToolList()
        end)
    end
end

ToolBtn.MouseButton1Click:Connect(function()
    toolListOpen = not toolListOpen
    if toolListOpen then RefreshToolList(); ToolFrame.Visible = true else ToolFrame.Visible = false end
end)

SwitchBtn.MouseButton1Click:Connect(function()
    if currentMode == "VOID" then currentMode = "EXTREME"
    elseif currentMode == "EXTREME" then currentMode = "BRING"
    elseif currentMode == "BRING" then currentMode = "GIVE"
    else currentMode = "VOID" end
    UpdateModeUI()
end)

local minimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    for _, child in ipairs(MainFrame:GetChildren()) do
        if child ~= MinimizeBtn and child ~= CloseBtn and child ~= MainFrame:FindFirstChild("Title") then
            child.Visible = not minimized
        end
    end
    if minimized and toolListOpen then toolListOpen = false; ToolFrame.Visible = false end
end)

CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local function Run(targetName)
    if isProcessing then return end
    SetStatus("Checking...", Color3.fromRGB(255, 210, 130))
    local res = ExecuteSequence(targetName)
    if res == "NOT FOUND" then SetStatus("Player not found!", Color3.fromRGB(255, 150, 190))
    elseif res == "NO TOOL" then SetStatus("No tool selected!", Color3.fromRGB(255, 150, 190))
    elseif res == "NO CHAR" then SetStatus("Character not ready!", Color3.fromRGB(255, 150, 190))
    else SetStatus("Done!", Color3.fromRGB(150, 255, 190)) end
    RefreshToolList()
end

StartBtn.MouseButton1Click:Connect(function()
    if isProcessing then return end
    if TargetBox.Text == "" then SetStatus("Enter a player name!", Color3.fromRGB(255, 210, 130)); return end
    Run(TargetBox.Text)
end)

TargetBox.FocusLost:Connect(function(enterPressed)
    if enterPressed and TargetBox.Text ~= "" and not isProcessing then Run(TargetBox.Text) end
end)

print("[LT VOID TOOL FIXED] Loaded successfully.")
print("[LT VOID TOOL FIXED] ServerRemote:", ServerRemote and ServerRemote:GetFullName() or "NOT FOUND ⚠️")