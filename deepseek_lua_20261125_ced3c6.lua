-- ==========================================
-- SERVICES
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

if getgenv().HTrungCleanup then pcall(getgenv().HTrungCleanup) end
local joinTime = tick()

-- ==========================================
-- TRẠNG THÁI
-- ==========================================
local States = {
    Fly=false, FlyUp=false, FlyDown=false, Noclip=false, InfJump=false, AutoJump=false, AutoRun=false,
    FreeCam=false, FreeCamSpeed=50, Aimbot=false, Hitbox=false, ESP=false, KillAura=false, Dodge=false,
    GodMode=false, Wallbang=false, AutoItemTp=false, AutoTpSelected=false, ItemTpSpeed=0, AntiAFK=false,
    Fullbright=false, AutoClick=false, RemoveParticles=false, AntiFling=false, Glide=false, ItemESP=false,
    XRay=false, AntiVoid=false, UnlockFPS=false, ResetTime=false, AutoClaim=false, SpamRemote=false,
    AutoReward=false, BypassGamepass=false,
    Speed=16, JumpPower=50, FlySpeed=60, HitboxSize=10, AuraRange=2000, GameSpeed=1
}
local freeCamCFrame = CFrame.new()
local freeCamRotX, freeCamRotY = 0, 0
local freeCamInput = {F=false,B=false,L=false,R=false,U=false,D=false}
local lastAuraAttack = 0
local lastDodgeTime = 0
local godModeThread = nil
local oldRaycast = nil
local autoClickThread = nil
local autoItemTpThread = nil
local autoTpSelectedThread = nil
local autoRewardThread = nil
local autoRewardConn = nil
local bypassThread = nil
local bypassLoop = nil
local oldNamecallHook = nil
local oldIndexHook = nil
local scannedItems = {}
local selectedItemForLoop = nil
local savedPos1, savedPos2 = nil, nil
local autoTp1Active, autoTp2Active = false, false
local autoTp1Thread, autoTp2Thread = nil, nil
local autoLoopActive = false
local autoLoopThread = nil
local Connections = {}
local ESPObjects = {}
local menuScale = 1
local ColorableElements = { Toggles = {}, ActiveTabBtn = nil, MenuStroke = nil }
local currentFps = 0
local currentPing = 0
local currentRobux = "Đang tải..."

-- ==========================================
-- THEME
-- ==========================================
local blur = Instance.new("BlurEffect") blur.Size = 0 blur.Parent = Lighting
local Theme = {
    MainBG = Color3.fromRGB(15, 8, 20), TopBar = Color3.fromRGB(30, 15, 40),
    SidebarBtn = Color3.fromRGB(45, 25, 60), SidebarBtnActive = Color3.fromRGB(255, 105, 180),
    Text = Color3.fromRGB(255, 255, 255), TextDim = Color3.fromRGB(200, 180, 210),
    AccentPink = Color3.fromRGB(255, 105, 180), AccentPurple = Color3.fromRGB(180, 100, 255),
    AccentCyan = Color3.fromRGB(0, 255, 255), AccentGold = Color3.fromRGB(255, 215, 0)
}

-- ==========================================
-- HÀM HỖ TRỢ
-- ==========================================
local function httpGet(url)
    local success, result = pcall(function()
        if syn and syn.request then return syn.request({Url = url, Method = "GET"}).Body
        elseif http_request then return http_request({Url = url, Method = "GET"}).Body
        elseif request then return request({Url = url, Method = "GET"}).Body
        else return game:HttpGet(url) end
    end)
    return success and result or nil
end

local function bindClick(button, callback)
    local lastFire = 0
    local function fire()
        local now = tick()
        if now - lastFire < 0.2 then return end
        lastFire = now
        callback()
    end
    button.Activated:Connect(fire)
    local pressed = false
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then pressed = true end
    end)
    button.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and pressed then
            pressed = false fire()
        end
    end)
end

local function makeDraggable(frame, dragArea)
    local dragging, dragInput, dragStart, startPos
    local dragThreshold = 5
    local hasMoved = false
    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true hasMoved = false dragStart = input.Position startPos = frame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    dragArea.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            if delta.Magnitude > dragThreshold then hasMoved = true end
            if hasMoved then frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end
        end
    end)
end

local function bindHold(button, callbackDown, callbackUp)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then callbackDown() end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then callbackUp() end
    end)
end

if hookfunction and workspace.Raycast then
    pcall(function()
        oldRaycast = hookfunction(workspace.Raycast, function(self, origin, direction, params)
            if States.Wallbang and params then
                local newParams = RaycastParams.new()
                newParams.FilterType = Enum.RaycastFilterType.Include
                local chars = {}
                for _, plr in pairs(Players:GetPlayers()) do if plr.Character then table.insert(chars, plr.Character) end end
                newParams.FilterDescendantsInstances = chars
                return oldRaycast(self, origin, direction, newParams)
            end
            return oldRaycast(self, origin, direction, params)
        end)
    end)
end

-- ==========================================
-- SERVER FUNCTIONS
-- ==========================================
local function RejoinServer()
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end

local function ServerHop()
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local result = httpGet(url)
        if result then
            local servers = HttpService:JSONDecode(result)
            for _, server in pairs(servers.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer) break
                end
            end
        end
    end)
end

local function ServerVIP()
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local result = httpGet(url)
        if result then
            local servers = HttpService:JSONDecode(result)
            local bestServer = nil local minPlayers = 999
            for _, server in pairs(servers.data) do
                if server.playing < minPlayers and server.id ~= game.JobId then minPlayers = server.playing bestServer = server.id end
            end
            if bestServer then TeleportService:TeleportToPlaceInstance(game.PlaceId, bestServer, LocalPlayer) end
        end
    end)
end

task.spawn(function()
    local success, result = pcall(httpGet, "https://economy.roblox.com/v1/users/" .. LocalPlayer.UserId .. "/currency")
    if success and result then
        local ok, data = pcall(function() return HttpService:JSONDecode(result) end)
        if ok and data and data.robux then currentRobux = tostring(data.robux) else currentRobux = "Không thể lấy" end
    else currentRobux = "Không thể lấy" end
end)

-- ==========================================
-- GUI BASE
-- ==========================================
local gui = Instance.new("ScreenGui")
gui.Name = "HTrungVip" gui.ResetOnSpawn = false gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global gui.DisplayOrder = 999999

local openButton = Instance.new("ImageButton")
openButton.Size = UDim2.new(0, 50, 0, 50) openButton.Position = UDim2.new(0, 10, 0, 100)
openButton.BackgroundColor3 = Theme.MainBG openButton.BorderSizePixel = 0 openButton.ZIndex = 100
openButton.ScaleType = Enum.ScaleType.Crop
openButton.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
openButton.Parent = gui
local oc = Instance.new("UICorner") oc.CornerRadius = UDim.new(1, 0) oc.Parent = openButton
local openBtnStroke = Instance.new("UIStroke") openBtnStroke.Color = Theme.AccentPink openBtnStroke.Thickness = 2 openBtnStroke.Parent = openButton
makeDraggable(openButton, openButton)

-- ==========================================
-- OVERLAYS
-- ==========================================
local teleOverlay = Instance.new("Frame")
teleOverlay.Size = UDim2.new(0, 210, 0, 170) teleOverlay.Position = UDim2.new(1, -230, 1, -300)
teleOverlay.BackgroundColor3 = Theme.MainBG teleOverlay.BackgroundTransparency = 0.2
teleOverlay.BorderSizePixel = 0 teleOverlay.Visible = false teleOverlay.ZIndex = 90 teleOverlay.Parent = gui
local toc = Instance.new("UICorner") toc.CornerRadius = UDim.new(0, 8) toc.Parent = teleOverlay
local tos = Instance.new("UIStroke") tos.Color = Theme.AccentPurple tos.Thickness = 1 tos.Parent = teleOverlay
local teleTitle = Instance.new("TextLabel")
teleTitle.Size = UDim2.new(1, 0, 0, 25) teleTitle.BackgroundColor3 = Theme.TopBar teleTitle.TextColor3 = Theme.Text
teleTitle.Font = Enum.Font.GothamBold teleTitle.TextSize = 13 teleTitle.Text = "BẢNG TELE NHANH" teleTitle.ZIndex = 91 teleTitle.Parent = teleOverlay
local ttc = Instance.new("UICorner") ttc.CornerRadius = UDim.new(0, 8) ttc.Parent = teleTitle
makeDraggable(teleOverlay, teleTitle)

local function createOverlayBtn(text, x, y, bg, parent)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 60, 0, 28) b.Position = UDim2.new(0, x, 0, y) b.BackgroundColor3 = bg
    b.TextColor3 = Theme.Text b.Font = Enum.Font.GothamBold b.TextSize = 12 b.Text = text b.BorderSizePixel = 0 b.ZIndex = 91 b.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = b
    return b
end

local save1Btn = createOverlayBtn("Lưu 1", 5, 30, Theme.SidebarBtn, teleOverlay)
local tp1Btn = createOverlayBtn("Đến 1", 70, 30, Theme.AccentPurple, teleOverlay)
local auto1Btn = createOverlayBtn("Auto 1", 135, 30, Theme.SidebarBtn, teleOverlay)
local save2Btn = createOverlayBtn("Lưu 2", 5, 65, Theme.SidebarBtn, teleOverlay)
local tp2Btn = createOverlayBtn("Đến 2", 70, 65, Theme.AccentPurple, teleOverlay)
local auto2Btn = createOverlayBtn("Auto 2", 135, 65, Theme.SidebarBtn, teleOverlay)

-- NÚT AUTO LẶP 1 & 2
local autoLoopBtn = createOverlayBtn("Auto Lặp 1 & 2", 5, 100, Theme.SidebarBtn, teleOverlay)
autoLoopBtn.Size = UDim2.new(0, 190, 0, 30)

bindClick(save1Btn, function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then savedPos1 = hrp.CFrame save1Btn.Text = "Đã lưu!" task.wait(1) save1Btn.Text = "Lưu 1" end
end)
bindClick(tp1Btn, function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and savedPos1 then hrp.CFrame = savedPos1 end
end)
bindClick(auto1Btn, function()
    if not savedPos1 then auto1Btn.Text = "Chưa lưu!" task.wait(1) auto1Btn.Text = autoTp1Active and "Auto 1 ON" or "Auto 1" return end
    if autoTp2Active then autoTp2Active = false if autoTp2Thread then task.cancel(autoTp2Thread) end auto2Btn.Text = "Auto 2" auto2Btn.BackgroundColor3 = Theme.SidebarBtn end
    if autoLoopActive then autoLoopActive = false if autoLoopThread then task.cancel(autoLoopThread) end autoLoopBtn.Text = "Auto Lặp 1 & 2" autoLoopBtn.BackgroundColor3 = Theme.SidebarBtn end
    autoTp1Active = not autoTp1Active
    if autoTp1Active then
        auto1Btn.Text = "Auto 1 ON" auto1Btn.BackgroundColor3 = Theme.AccentPink
        autoTp1Thread = task.spawn(function() while autoTp1Active do local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") if hrp then hrp.CFrame = savedPos1 end task.wait(0.1) end end)
    else
        auto1Btn.Text = "Auto 1" auto1Btn.BackgroundColor3 = Theme.SidebarBtn
        if autoTp1Thread then task.cancel(autoTp1Thread) end
    end
end)
bindClick(save2Btn, function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then savedPos2 = hrp.CFrame save2Btn.Text = "Đã lưu!" task.wait(1) save2Btn.Text = "Lưu 2" end
end)
bindClick(tp2Btn, function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and savedPos2 then hrp.CFrame = savedPos2 end
end)
bindClick(auto2Btn, function()
    if not savedPos2 then auto2Btn.Text = "Chưa lưu!" task.wait(1) auto2Btn.Text = autoTp2Active and "Auto 2 ON" or "Auto 2" return end
    if autoTp1Active then autoTp1Active = false if autoTp1Thread then task.cancel(autoTp1Thread) end auto1Btn.Text = "Auto 1" auto1Btn.BackgroundColor3 = Theme.SidebarBtn end
    if autoLoopActive then autoLoopActive = false if autoLoopThread then task.cancel(autoLoopThread) end autoLoopBtn.Text = "Auto Lặp 1 & 2" autoLoopBtn.BackgroundColor3 = Theme.SidebarBtn end
    autoTp2Active = not autoTp2Active
    if autoTp2Active then
        auto2Btn.Text = "Auto 2 ON" auto2Btn.BackgroundColor3 = Theme.AccentPink
        autoTp2Thread = task.spawn(function() while autoTp2Active do local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") if hrp then hrp.CFrame = savedPos2 end task.wait(0.1) end end)
    else
        auto2Btn.Text = "Auto 2" auto2Btn.BackgroundColor3 = Theme.SidebarBtn
        if autoTp2Thread then task.cancel(autoTp2Thread) end
    end
end)

-- LOGIC CHO NÚT AUTO LẶP (DELAY 0S)
bindClick(autoLoopBtn, function()
    if not savedPos1 or not savedPos2 then
        autoLoopBtn.Text = "Chưa lưu đủ 2 vị trí!"
        task.wait(1.5)
        autoLoopBtn.Text = autoLoopActive and "Auto Lặp ON" or "Auto Lặp 1 & 2"
        return
    end
    
    -- Tắt các Auto đơn lẻ để tránh xung đột
    if autoTp1Active then
        autoTp1Active = false
        if autoTp1Thread then task.cancel(autoTp1Thread) end
        auto1Btn.Text = "Auto 1"
        auto1Btn.BackgroundColor3 = Theme.SidebarBtn
    end
    if autoTp2Active then
        autoTp2Active = false
        if autoTp2Thread then task.cancel(autoTp2Thread) end
        auto2Btn.Text = "Auto 2"
        auto2Btn.BackgroundColor3 = Theme.SidebarBtn
    end

    autoLoopActive = not autoLoopActive
    if autoLoopActive then
        autoLoopBtn.Text = "Auto Lặp 1 & 2 ON"
        autoLoopBtn.BackgroundColor3 = Theme.AccentCyan
        autoLoopThread = task.spawn(function()
            while autoLoopActive do
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = savedPos1 end
                RunService.Heartbeat:Wait() -- Delay 0s (chạy theo FPS)
                if not autoLoopActive then break end
                hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = savedPos2 end
                RunService.Heartbeat:Wait()
            end
        end)
    else
        autoLoopBtn.Text = "Auto Lặp 1 & 2"
        autoLoopBtn.BackgroundColor3 = Theme.SidebarBtn
        if autoLoopThread then task.cancel(autoLoopThread) end
    end
end)


local flyOverlay = Instance.new("Frame")
flyOverlay.Size = UDim2.new(0, 180, 0, 50) flyOverlay.Position = UDim2.new(1, -200, 1, -150)
flyOverlay.BackgroundColor3 = Theme.MainBG flyOverlay.BackgroundTransparency = 0.3
flyOverlay.Visible = false flyOverlay.ZIndex = 90 flyOverlay.Parent = gui
local foc = Instance.new("UICorner") foc.CornerRadius = UDim.new(0, 8) foc.Parent = flyOverlay
local fos = Instance.new("UIStroke") fos.Color = Theme.AccentPurple fos.Thickness = 1 fos.Parent = flyOverlay
local btnFlyUp = Instance.new("TextButton") btnFlyUp.Size = UDim2.new(0.45, 0, 1, -10) btnFlyUp.Position = UDim2.new(0.03, 0, 0, 5) btnFlyUp.BackgroundColor3 = Theme.AccentPurple btnFlyUp.TextColor3 = Theme.Text btnFlyUp.Font = Enum.Font.GothamBold btnFlyUp.Text = "LÊN" btnFlyUp.TextSize = 13 btnFlyUp.ZIndex = 91 btnFlyUp.Parent = flyOverlay
local uc1 = Instance.new("UICorner") uc1.CornerRadius = UDim.new(0, 6) uc1.Parent = btnFlyUp
local btnFlyDown = Instance.new("TextButton") btnFlyDown.Size = UDim2.new(0.45, 0, 1, -10) btnFlyDown.Position = UDim2.new(0.52, 0, 0, 5) btnFlyDown.BackgroundColor3 = Theme.AccentPink btnFlyDown.TextColor3 = Theme.Text btnFlyDown.Font = Enum.Font.GothamBold btnFlyDown.Text = "XUỐNG" btnFlyDown.TextSize = 13 btnFlyDown.ZIndex = 91 btnFlyDown.Parent = flyOverlay
local dc1 = Instance.new("UICorner") dc1.CornerRadius = UDim.new(0, 6) dc1.Parent = btnFlyDown
bindHold(btnFlyUp, function() States.FlyUp = true end, function() States.FlyUp = false end)
bindHold(btnFlyDown, function() States.FlyDown = true end, function() States.FlyDown = false end)
makeDraggable(flyOverlay, flyOverlay)

local fcOverlay = Instance.new("Frame")
fcOverlay.Size = UDim2.new(0, 180, 0, 200) fcOverlay.Position = UDim2.new(1, -200, 1, -380)
fcOverlay.BackgroundColor3 = Theme.MainBG fcOverlay.BackgroundTransparency = 0.3
fcOverlay.Visible = false fcOverlay.ZIndex = 90 fcOverlay.Parent = gui
local fcoc = Instance.new("UICorner") fcoc.CornerRadius = UDim.new(0, 8) fcoc.Parent = fcOverlay
local fcos = Instance.new("UIStroke") fcos.Color = Theme.AccentPurple fcos.Thickness = 1 fcos.Parent = fcOverlay

local function createFcBtn(text, x, y, w, h, key)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(w, 0, h, 0) b.Position = UDim2.new(x, 0, y, 0) b.BackgroundColor3 = Theme.SidebarBtn
    b.TextColor3 = Theme.Text b.Font = Enum.Font.GothamBold b.TextSize = 12 b.Text = text b.ZIndex = 91 b.Parent = fcOverlay
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = b
    bindHold(b, function() freeCamInput[key] = true end, function() freeCamInput[key] = false end)
    return b
end
createFcBtn("▲", 0.35, 0.05, 0.3, 0.15, "U")
createFcBtn("◀", 0.05, 0.22, 0.25, 0.15, "L")
createFcBtn("▼", 0.35, 0.4, 0.3, 0.15, "D")
createFcBtn("▶", 0.70, 0.22, 0.25, 0.15, "R")
createFcBtn("TIẾN", 0.35, 0.22, 0.3, 0.15, "F")
createFcBtn("LÙI", 0.35, 0.58, 0.3, 0.15, "B")

local teleBtn = Instance.new("TextButton")
teleBtn.Size = UDim2.new(0.9, 0, 0.15, 0) teleBtn.Position = UDim2.new(0.05, 0, 0.78, 0)
teleBtn.BackgroundColor3 = Theme.AccentPink teleBtn.TextColor3 = Theme.Text
teleBtn.Font = Enum.Font.GothamBold teleBtn.TextSize = 13 teleBtn.Text = "TELE ĐẾN ĐÂY" teleBtn.ZIndex = 91 teleBtn.Parent = fcOverlay
local teCorner = Instance.new("UICorner") teCorner.CornerRadius = UDim.new(0, 6) teCorner.Parent = teleBtn
bindClick(teleBtn, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = Camera.CFrame + Vector3.new(0, 3, 0) end
end)
makeDraggable(fcOverlay, fcOverlay)

-- ==========================================
-- MAIN MENU
-- ==========================================
local menu = Instance.new("Frame")
menu.Size = UDim2.fromOffset(650, 450) menu.Position = UDim2.new(0.5, 0, 0.5, 0)
menu.AnchorPoint = Vector2.new(0.5, 0.5) menu.BackgroundColor3 = Theme.MainBG
menu.BackgroundTransparency = 0.15 menu.BorderSizePixel = 0 menu.Visible = false menu.ZIndex = 50 menu.Parent = gui

local mc = Instance.new("UICorner") mc.CornerRadius = UDim.new(0, 16) mc.Parent = menu
local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(255, 255, 255) ms.Thickness = 2 ms.Transparency = 0.1 ms.Parent = menu
ColorableElements.MenuStroke = ms

local menuStrokeGradient = Instance.new("UIGradient")
menuStrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.AccentPink),
    ColorSequenceKeypoint.new(0.5, Theme.AccentCyan),
    ColorSequenceKeypoint.new(1, Theme.AccentPurple)
})
menuStrokeGradient.Parent = ms

local uiScale = Instance.new("UIScale") uiScale.Scale = 0.8 uiScale.Parent = menu

local bgImage = Instance.new("ImageLabel")
bgImage.Size = UDim2.new(1, 0, 1, 0) bgImage.BackgroundTransparency = 1
bgImage.Image = "rbxassetid://13476434849" bgImage.ScaleType = Enum.ScaleType.Crop
bgImage.ImageTransparency = 0.6 bgImage.ZIndex = 50 bgImage.Parent = menu
local bgCorner = Instance.new("UICorner") bgCorner.CornerRadius = UDim.new(0, 16) bgCorner.Parent = bgImage

local bgOverlay = Instance.new("Frame")
bgOverlay.Size = UDim2.new(1, 0, 1, 0) bgOverlay.BackgroundColor3 = Theme.MainBG
bgOverlay.BackgroundTransparency = 0.3 bgOverlay.ZIndex = 51 bgOverlay.Parent = menu
local boCorner = Instance.new("UICorner") boCorner.CornerRadius = UDim.new(0, 16) boCorner.Parent = bgOverlay

local titleFrame = Instance.new("Frame")
titleFrame.Size = UDim2.new(1, 0, 0, 45) titleFrame.BackgroundColor3 = Theme.TopBar
titleFrame.BackgroundTransparency = 0.3 titleFrame.BorderSizePixel = 0 titleFrame.ZIndex = 52 titleFrame.Parent = menu
local tfc = Instance.new("UICorner") tfc.CornerRadius = UDim.new(0, 16) tfc.Parent = titleFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -250, 1, 0) title.BackgroundTransparency = 1 title.TextColor3 = Theme.Text
title.Font = Enum.Font.GothamBlack title.TextSize = 20 title.Text = "👑 HTrung Hub V6.3" title.ZIndex = 53 title.Parent = titleFrame
local titleStroke = Instance.new("UIStroke") titleStroke.Color = Theme.AccentPink titleStroke.Thickness = 1.5 titleStroke.Transparency = 0.4 titleStroke.Parent = title

local scaleFrame = Instance.new("Frame")
scaleFrame.Size = UDim2.new(0, 60, 0, 30) scaleFrame.Position = UDim2.new(1, -180, 0.5, -15)
scaleFrame.BackgroundTransparency = 1 scaleFrame.ZIndex = 53 scaleFrame.Parent = titleFrame

local function createScaleBtn(text, posX, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 25, 0, 25) btn.Position = UDim2.new(0, posX, 0, 0) btn.BackgroundColor3 = color
    btn.TextColor3 = Theme.Text btn.Font = Enum.Font.GothamBold btn.TextSize = 14 btn.Text = text
    btn.BorderSizePixel = 0 btn.ZIndex = 54 btn.Parent = scaleFrame
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = btn
    local bs = Instance.new("UIStroke") bs.Color = Theme.Text bs.Thickness = 1 bs.Transparency = 0.5 bs.Parent = btn
    return btn
end
local scaleOutBtn = createScaleBtn("-", 0, Theme.AccentPink)
local scaleInBtn = createScaleBtn("+", 30, Theme.AccentPurple)
bindClick(scaleOutBtn, function() menuScale = math.max(menuScale - 0.1, 0.5) TweenService:Create(uiScale, TweenInfo.new(0.2), {Scale = menuScale}):Play() end)
bindClick(scaleInBtn, function() menuScale = math.min(menuScale + 0.1, 1.5) TweenService:Create(uiScale, TweenInfo.new(0.2), {Scale = menuScale}):Play() end)

local controlFrame = Instance.new("Frame")
controlFrame.Size = UDim2.new(0, 90, 0, 30) controlFrame.Position = UDim2.new(1, -110, 0.5, -15)
controlFrame.BackgroundTransparency = 1 controlFrame.ZIndex = 53 controlFrame.Parent = titleFrame

local function createControlBtn(text, posX, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 25, 0, 25) btn.Position = UDim2.new(0, posX, 0, 0) btn.BackgroundColor3 = color
    btn.TextColor3 = Theme.Text btn.Font = Enum.Font.GothamBold btn.TextSize = 14 btn.Text = text
    btn.BorderSizePixel = 0 btn.ZIndex = 54 btn.Parent = controlFrame
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = btn
    local bs = Instance.new("UIStroke") bs.Color = Theme.Text bs.Thickness = 1 bs.Transparency = 0.5 bs.Parent = btn
    return btn
end
local minBtn = createControlBtn("-", 0, Theme.SidebarBtn)
local maxBtn = createControlBtn("+", 30, Theme.AccentPurple)
local closeBtn = createControlBtn("X", 60, Theme.AccentPink)

local isAnimating = false
local function openMenu()
    if isAnimating or menu.Visible then return end
    isAnimating = true menu.Visible = true uiScale.Scale = 0.5 menu.BackgroundTransparency = 1 bgOverlay.BackgroundTransparency = 1 blur.Size = 0
    TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = menuScale}):Play()
    TweenService:Create(menu, TweenInfo.new(0.4), {BackgroundTransparency = 0.15}):Play()
    TweenService:Create(bgOverlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.3}):Play()
    TweenService:Create(blur, TweenInfo.new(0.4), {Size = 15}):Play()
    task.wait(0.4) isAnimating = false
end
local function closeMenu()
    if isAnimating or not menu.Visible then return end
    isAnimating = true
    TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.5}):Play()
    TweenService:Create(menu, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    TweenService:Create(bgOverlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    TweenService:Create(blur, TweenInfo.new(0.3), {Size = 0}):Play()
    task.wait(0.3) menu.Visible = false isAnimating = false
end
bindClick(minBtn, function() closeMenu() end)
bindClick(closeBtn, function() closeMenu() end)
bindClick(maxBtn, function() if menuScale == 1 then menuScale = 1.2 else menuScale = 1 end TweenService:Create(uiScale, TweenInfo.new(0.3), {Scale = menuScale}):Play() end)
bindClick(openButton, function() if menu.Visible then closeMenu() else openMenu() end end)
makeDraggable(menu, titleFrame)

task.spawn(function()
    while menu.Parent do
        TweenService:Create(title, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextTransparency = 0.5, TextColor3 = Theme.AccentCyan}):Play()
        task.wait(1)
        TweenService:Create(title, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextTransparency = 0, TextColor3 = Theme.Text}):Play()
        task.wait(1)
    end
end)

task.spawn(function()
    local rotation = 0
    while menu.Parent do rotation = (rotation + 1) % 360 if menuStrokeGradient then menuStrokeGradient.Rotation = rotation end task.wait(0.03) end
end)

local sidebar = Instance.new("ScrollingFrame")
sidebar.Size = UDim2.new(0, 130, 1, -55) sidebar.Position = UDim2.new(0, 10, 0, 50)
sidebar.BackgroundTransparency = 1 sidebar.BorderSizePixel = 0 sidebar.ScrollBarThickness = 0
sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y sidebar.ScrollingEnabled = true
sidebar.ScrollingDirection = Enum.ScrollingDirection.Y sidebar.ClipsDescendants = true sidebar.ZIndex = 52 sidebar.Parent = menu
local tabLayout = Instance.new("UIListLayout") tabLayout.Padding = UDim.new(0, 8) tabLayout.Parent = sidebar

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -160, 1, -60) contentFrame.Position = UDim2.new(0, 150, 0, 50)
contentFrame.BackgroundTransparency = 1 contentFrame.ZIndex = 52 contentFrame.ClipsDescendants = true contentFrame.Parent = menu

local function createTab(name, icon)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, 0, 0, 40) tabBtn.BackgroundColor3 = Theme.SidebarBtn
    tabBtn.BackgroundTransparency = 0.5 tabBtn.TextColor3 = Theme.TextDim tabBtn.Font = Enum.Font.GothamBold
    tabBtn.TextSize = 14 tabBtn.Text = icon .. " " .. name tabBtn.TextXAlignment = Enum.TextXAlignment.Left
    tabBtn.BorderSizePixel = 0 tabBtn.ZIndex = 53 tabBtn.Parent = sidebar
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = tabBtn
    local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0, 10) pad.Parent = tabBtn
    local stroke = Instance.new("UIStroke") stroke.Color = Theme.AccentPurple stroke.Thickness = 0 stroke.Parent = tabBtn

    local frame = Instance.new("ScrollingFrame")
    frame.Size = UDim2.new(1, 0, 1, 0) frame.BackgroundTransparency = 1 frame.BorderSizePixel = 0
    frame.ScrollBarThickness = 4 frame.ScrollBarImageColor3 = Theme.AccentPink frame.Visible = false
    frame.ZIndex = 53 frame.ClipsDescendants = true frame.ScrollingEnabled = true
    frame.ScrollingDirection = Enum.ScrollingDirection.Y frame.AutomaticCanvasSize = Enum.AutomaticSize.Y frame.Parent = contentFrame
    local layout = Instance.new("UIListLayout") layout.Padding = UDim.new(0, 8) layout.Parent = frame
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    bindClick(tabBtn, function()
        for _, child in pairs(contentFrame:GetChildren()) do if child:IsA("ScrollingFrame") then child.Visible = false end end
        for _, child in pairs(sidebar:GetChildren()) do
            if child:IsA("TextButton") then
                TweenService:Create(child, TweenInfo.new(0.2), {BackgroundTransparency = 0.5, TextColor3 = Theme.TextDim}):Play()
                child:FindFirstChild("UIStroke").Thickness = 0
            end
        end
        frame.Visible = true
        TweenService:Create(tabBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1, TextColor3 = Theme.Text}):Play()
        tabBtn:FindFirstChild("UIStroke").Thickness = 1
        tabBtn:FindFirstChild("UIStroke").Color = Theme.AccentCyan
        ColorableElements.ActiveTabBtn = tabBtn
    end)
    return frame
end

local function createToggle(parent, text, initialState, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 38) container.BackgroundColor3 = Theme.SidebarBtn
    container.BackgroundTransparency = 0.5 container.BorderSizePixel = 0 container.ZIndex = 53 container.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = container
    local s = Instance.new("UIStroke") s.Color = Theme.AccentPurple s.Thickness = 1 s.Transparency = 0.7 s.Parent = container
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0) label.Position = UDim2.new(0, 10, 0, 0) label.BackgroundTransparency = 1
    label.TextColor3 = Theme.Text label.Font = Enum.Font.GothamBold label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left label.Text = text label.ZIndex = 54 label.Parent = container
    local switchBtn = Instance.new("TextButton")
    switchBtn.Size = UDim2.new(0, 40, 0, 20) switchBtn.Position = UDim2.new(1, -50, 0.5, -10)
    switchBtn.BackgroundColor3 = initialState and Theme.AccentPink or Color3.fromRGB(50, 50, 60)
    switchBtn.Text = "" switchBtn.BorderSizePixel = 0 switchBtn.ZIndex = 54 switchBtn.Parent = container
    local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(1, 0) sc.Parent = switchBtn
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = initialState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255) knob.BorderSizePixel = 0 knob.ZIndex = 55 knob.Parent = switchBtn
    local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1, 0) kc.Parent = knob
    local state = initialState
    local data = { Button = switchBtn, State = state }
    table.insert(ColorableElements.Toggles, data)
    bindClick(switchBtn, function()
        state = not state data.State = state
        local targetColor = state and Theme.AccentPink or Color3.fromRGB(50, 50, 60)
        local targetPos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        TweenService:Create(switchBtn, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = targetPos}):Play()
        callback(state)
    end)
end

local function createSlider(parent, text, min, max, initial, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 38) frame.BackgroundColor3 = Theme.SidebarBtn
    frame.BackgroundTransparency = 0.5 frame.BorderSizePixel = 0 frame.ZIndex = 53 frame.Parent = parent
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 8) fc.Parent = frame
    local fs = Instance.new("UIStroke") fs.Color = Theme.AccentPurple fs.Thickness = 1 fs.Transparency = 0.7 fs.Parent = frame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0) label.Position = UDim2.new(0, 10, 0, 0) label.BackgroundTransparency = 1
    label.TextColor3 = Theme.Text label.Font = Enum.Font.GothamBold label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left label.Text = text .. ": " .. initial label.ZIndex = 54 label.Parent = frame
    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0, 30, 0, 25) minus.Position = UDim2.new(1, -70, 0.5, -12.5) minus.BackgroundColor3 = Theme.AccentPink
    minus.TextColor3 = Theme.Text minus.Font = Enum.Font.GothamBold minus.TextSize = 14 minus.Text = "-" minus.ZIndex = 54 minus.Parent = frame
    local minc = Instance.new("UICorner") minc.CornerRadius = UDim.new(0, 6) minc.Parent = minus
    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0, 30, 0, 25) plus.Position = UDim2.new(1, -35, 0.5, -12.5) plus.BackgroundColor3 = Theme.AccentPurple
    plus.TextColor3 = Theme.Text plus.Font = Enum.Font.GothamBold plus.TextSize = 14 plus.Text = "+" plus.ZIndex = 54 plus.Parent = frame
    local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0, 6) pc.Parent = plus
    local val = initial
    local step = (max > 100 and 50 or 0.1)
    if max == 2.0 and min == 0 then step = 0.1 end
    if max == 5 and min == 1 then step = 1 end
    bindClick(minus, function()
        val = math.max(min, val - step)
        if max <= 100 then label.Text = text .. ": " .. string.format("%.1f", val) else label.Text = text .. ": " .. val end
        callback(val)
    end)
    bindClick(plus, function()
        val = math.min(max, val + step)
        if max <= 100 then label.Text = text .. ": " .. string.format("%.1f", val) else label.Text = text .. ": " .. val end
        callback(val)
    end)
end

-- ==========================================
-- TAB 1: INFO
-- ==========================================
local infoTab = createTab("Thông Tin", "🏠")
infoTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
infoTab.CanvasSize = UDim2.new(0, 0, 0, 0)
infoTab.UIListLayout.Padding = UDim.new(0, 10)

local profileShowcase = Instance.new("Frame")
profileShowcase.Size = UDim2.new(1, -10, 0, 260) profileShowcase.BackgroundTransparency = 1
profileShowcase.ZIndex = 54 profileShowcase.LayoutOrder = 1 profileShowcase.Parent = infoTab

local ringContainer = Instance.new("Frame")
ringContainer.Size = UDim2.new(0, 140, 0, 140) ringContainer.Position = UDim2.new(0.5, 0, 0, 10)
ringContainer.AnchorPoint = Vector2.new(0.5, 0) ringContainer.BackgroundTransparency = 1
ringContainer.ZIndex = 55 ringContainer.Parent = profileShowcase

local ring1 = Instance.new("Frame")
ring1.Size = UDim2.new(1, 0, 1, 0) ring1.BackgroundTransparency = 1 ring1.ZIndex = 55 ring1.Parent = ringContainer
local r1c = Instance.new("UICorner") r1c.CornerRadius = UDim.new(1, 0) r1c.Parent = ring1
local r1s = Instance.new("UIStroke") r1s.Color = Theme.AccentPink r1s.Thickness = 4 r1s.Parent = ring1
local r1Gradient = Instance.new("UIGradient")
r1Gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.AccentPink), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Theme.AccentCyan)})
r1Gradient.Parent = r1s

local ring2 = Instance.new("Frame")
ring2.Size = UDim2.new(0.85, 0, 0.85, 0) ring2.Position = UDim2.new(0.5, 0, 0.5, 0)
ring2.AnchorPoint = Vector2.new(0.5, 0.5) ring2.BackgroundTransparency = 1 ring2.ZIndex = 55 ring2.Parent = ringContainer
local r2c = Instance.new("UICorner") r2c.CornerRadius = UDim.new(1, 0) r2c.Parent = ring2
local r2s = Instance.new("UIStroke") r2s.Color = Theme.AccentPurple r2s.Thickness = 2 r2s.Transparency = 0.5 r2s.Parent = ring2
local r2Gradient = Instance.new("UIGradient")
r2Gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.5, Theme.AccentPurple), ColorSequenceKeypoint.new(1, Theme.AccentPink)})
r2Gradient.Parent = r2s

local avatarImage = Instance.new("ImageLabel")
avatarImage.Size = UDim2.new(0, 110, 0, 110) avatarImage.Position = UDim2.new(0.5, 0, 0.5, 0)
avatarImage.AnchorPoint = Vector2.new(0.5, 0.5) avatarImage.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
avatarImage.Image = "rbxthumb://type=Avatar&id=" .. LocalPlayer.UserId .. "&w=420&h=420"
avatarImage.ScaleType = Enum.ScaleType.Crop avatarImage.ZIndex = 56 avatarImage.Parent = ringContainer
local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(1, 0) ac.Parent = avatarImage

task.spawn(function()
    local rot = 0
    while profileShowcase.Parent do
        rot = (rot + 2) % 360 r1Gradient.Rotation = rot r2Gradient.Rotation = -rot
        TweenService:Create(ring1, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.new(1.08, 0, 1.08, 0)}):Play()
        TweenService:Create(avatarImage, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, -15), Size = UDim2.new(0, 115, 0, 115)}):Play()
        task.wait(0.5)
        TweenService:Create(avatarImage, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 110, 0, 110)}):Play()
        task.wait(0.5)
        TweenService:Create(ring1, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.new(1, 0, 1, 0)}):Play()
        task.wait(1)
    end
end)

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, 0, 0, 50) nameLabel.Position = UDim2.new(0.5, 0, 0, 150)
nameLabel.AnchorPoint = Vector2.new(0.5, 0) nameLabel.BackgroundTransparency = 1
nameLabel.Text = LocalPlayer.DisplayName nameLabel.TextColor3 = Theme.Text
nameLabel.Font = Enum.Font.GothamBlack nameLabel.TextSize = 42 nameLabel.ZIndex = 55 nameLabel.Parent = profileShowcase
local textGradient = Instance.new("UIGradient")
textGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.AccentPink), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Theme.AccentPurple)})
textGradient.Parent = nameLabel
local textStroke = Instance.new("UIStroke") textStroke.Color = Theme.AccentPurple textStroke.Thickness = 2 textStroke.Transparency = 0.3 textStroke.Parent = nameLabel

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, 0, 0, 20) subLabel.Position = UDim2.new(0.5, 0, 0, 195)
subLabel.AnchorPoint = Vector2.new(0.5, 0) subLabel.BackgroundTransparency = 1
subLabel.Text = "Script Premium Roblox | ID: " .. LocalPlayer.UserId
subLabel.TextColor3 = Theme.TextDim subLabel.Font = Enum.Font.GothamBold subLabel.TextSize = 14 subLabel.ZIndex = 55 subLabel.Parent = profileShowcase

local gridFrame = Instance.new("Frame")
gridFrame.Size = UDim2.new(1, -10, 0, 320) gridFrame.BackgroundTransparency = 1
gridFrame.ZIndex = 54 gridFrame.LayoutOrder = 2 gridFrame.Parent = infoTab
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.5, -5, 0.5, -5) gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder gridLayout.Parent = gridFrame

local function createInfoBox(titleText, icon, color1, color2, layoutOrder)
    local box = Instance.new("Frame")
    box.BackgroundColor3 = Theme.SidebarBtn box.BackgroundTransparency = 0.4 box.BorderSizePixel = 0
    box.ZIndex = 54 box.LayoutOrder = layoutOrder box.Parent = gridFrame
    local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 12) corner.Parent = box
    local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(255, 255, 255) stroke.Thickness = 1.5 stroke.Transparency = 0.5 stroke.Parent = box
    local strokeGradient = Instance.new("UIGradient")
    strokeGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}) strokeGradient.Parent = stroke
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -10, 0, 25) titleLbl.Position = UDim2.new(0, 10, 0, 5)
    titleLbl.BackgroundTransparency = 1 titleLbl.TextColor3 = color1 titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 14 titleLbl.TextXAlignment = Enum.TextXAlignment.Left titleLbl.Text = icon .. " " .. titleText
    titleLbl.ZIndex = 55 titleLbl.Parent = box
    local listLayout = Instance.new("UIListLayout") listLayout.Padding = UDim.new(0, 5) listLayout.SortOrder = Enum.SortOrder.LayoutOrder listLayout.Parent = box
    local pad = Instance.new("UIPadding") pad.PaddingTop = UDim.new(0, 30) pad.PaddingLeft = UDim.new(0, 10) pad.PaddingRight = UDim.new(0, 10) pad.Parent = box
    return box
end

local function createStatRow(parent, text, layoutOrder)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18) lbl.BackgroundTransparency = 1 lbl.TextColor3 = Theme.Text
    lbl.Font = Enum.Font.GothamBold lbl.TextSize = 12 lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text lbl.ZIndex = 55 lbl.LayoutOrder = layoutOrder lbl.Parent = parent
    return lbl
end

local box1 = createInfoBox("Hiệu năng", "⚡", Theme.AccentCyan, Theme.AccentPurple, 1)
local fpsLabel = createStatRow(box1, "FPS: ...", 2)
local pingLabel = createStatRow(box1, "Ping: ... ms", 3)
local posLabel = createStatRow(box1, "Pos: ..., ..., ...", 4)
local box2 = createInfoBox("Phiên chơi", "⏱️", Theme.AccentPink, Theme.AccentPurple, 2)
local timeLbl = createStatRow(box2, "Giờ: " .. os.date("%H:%M:%S"), 2)
local dateLbl = createStatRow(box2, "Ngày: " .. os.date("%d/%m/%Y"), 3)
local playtimeLbl = createStatRow(box2, "Đã chơi: 00:00:00", 4)
local box3 = createInfoBox("Thông tin", "👤", Theme.AccentPurple, Theme.AccentPink, 3)
local gameNameLbl = createStatRow(box3, "🎮 Game: " .. game.Name, 2)
local userLbl = createStatRow(box3, "👑 Tên: " .. LocalPlayer.DisplayName, 3)
local robuxLbl = createStatRow(box3, "💰 Robux: " .. currentRobux, 4)
local box4 = createInfoBox("Update", "🔄", Theme.AccentCyan, Theme.AccentPurple, 4)
local updateLbl = Instance.new("TextLabel")
updateLbl.Size = UDim2.new(1, 0, 0, 40) updateLbl.BackgroundTransparency = 1
updateLbl.TextColor3 = Theme.Text updateLbl.Font = Enum.Font.GothamBold updateLbl.TextSize = 12
updateLbl.TextXAlignment = Enum.TextXAlignment.Left updateLbl.TextWrapped = true
updateLbl.Text = "V6.3: Auto Lặp TP 1 & 2 chỉnh về delay 0s (Heartbeat)."
updateLbl.ZIndex = 55 updateLbl.LayoutOrder = 2 updateLbl.Parent = box4

local serverFrame = Instance.new("Frame")
serverFrame.Size = UDim2.new(1, -10, 0, 45) serverFrame.BackgroundColor3 = Theme.SidebarBtn
serverFrame.BackgroundTransparency = 0.3 serverFrame.ZIndex = 54 serverFrame.LayoutOrder = 3 serverFrame.Parent = infoTab
local sfc = Instance.new("UICorner") sfc.CornerRadius = UDim.new(0, 10) sfc.Parent = serverFrame
local sfs = Instance.new("UIStroke") sfs.Color = Theme.AccentCyan sfs.Thickness = 1.5 sfs.Transparency = 0.3 sfs.Parent = serverFrame
local sLayout = Instance.new("UIListLayout")
sLayout.FillDirection = Enum.FillDirection.Horizontal sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sLayout.VerticalAlignment = Enum.VerticalAlignment.Center sLayout.Padding = UDim.new(0, 10) sLayout.Parent = serverFrame

local function createServerBtn(text, icon, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.31, 0, 1, -10) btn.BackgroundColor3 = color btn.BackgroundTransparency = 0
    btn.TextColor3 = Theme.Text btn.Font = Enum.Font.GothamBold btn.TextSize = 12
    btn.Text = icon .. " " .. text btn.ZIndex = 55 btn.Parent = serverFrame
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = btn
    local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(255,255,255) s.Thickness = 1 s.Transparency = 0.3 s.Parent = btn
    bindClick(btn, callback)
end
createServerBtn("Server Hop", "🔄", Theme.SidebarBtn, ServerHop)
createServerBtn("Rejoin", "🔁", Theme.AccentPurple, RejoinServer)
createServerBtn("Server VIP", "👑", Theme.AccentPink, ServerVIP)

-- ==========================================
-- TAB 2: PLAYER
-- ==========================================
local playerTab = createTab("Player", "🎮")
createToggle(playerTab, "God Mode (Bất tử)", false, function(s)
    States.GodMode = s
    if s and not godModeThread then
        godModeThread = task.spawn(function()
            while States.GodMode do
                task.wait(0.1)
                local c = LocalPlayer.Character
                if c then
                    local h = c:FindFirstChildOfClass("Humanoid")
                    if h then
                        if not c:FindFirstChild("GodModeForceField") then
                            local ff = Instance.new("ForceField") ff.Name = "GodModeForceField" ff.Visible = false ff.Parent = c
                        end
                        h.Health = h.MaxHealth
                    end
                end
            end
        end)
    elseif not s then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("GodModeForceField") then LocalPlayer.Character.GodModeForceField:Destroy() end
    end
end)
createSlider(playerTab, "WalkSpeed", 16, 500, 16, function(v) States.Speed = v end)
createSlider(playerTab, "JumpPower", 50, 500, 50, function(v) States.JumpPower = v end)
createToggle(playerTab, "Infinite Jump", false, function(s) States.InfJump = s end)
createToggle(playerTab, "Auto Run (Tự chạy)", false, function(s) States.AutoRun = s end)
createToggle(playerTab, "Auto Jump (Tự nhảy)", false, function(s) States.AutoJump = s end)
createToggle(playerTab, "Chống Văng (Anti-Fling)", false, function(s) States.AntiFling = s end)
createToggle(playerTab, "Lướt Trên Không (Glide)", false, function(s) States.Glide = s end)
createToggle(playerTab, "Noclip (Xuyên tường)", false, function(s)
    States.Noclip = s
    if not s and LocalPlayer.Character then
        for _, p in pairs(LocalPlayer.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end
    end
end)
createToggle(playerTab, "Fly (Bay)", false, function(s) States.Fly = s flyOverlay.Visible = s end)
createSlider(playerTab, "Fly Speed", 10, 500, 60, function(v) States.FlySpeed = v end)

-- ==========================================
-- TAB 3: VISUALS
-- ==========================================
local visualTab = createTab("Visuals", "👁️")
createToggle(visualTab, "Player ESP (Highlight)", false, function(s)
    States.ESP = s
    if not s then for _, obj in pairs(ESPObjects) do if obj then obj:Destroy() end end table.clear(ESPObjects) end
end)
createToggle(visualTab, "Hiện Vật Phẩm (Item ESP)", false, function(s) States.ItemESP = s end)
createToggle(visualTab, "Nhìn Xuyên Tường (X-Ray)", false, function(s)
    States.XRay = s
    if not s then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character) then obj.LocalTransparencyModifier = 0 end
        end
    end
end)
createSlider(visualTab, "FreeCam Speed", 10, 300, 50, function(v) States.FreeCamSpeed = v end)
createToggle(visualTab, "Free Camera (Tự do)", false, function(s)
    States.FreeCam = s
    local char = LocalPlayer.Character
    if s then
        freeCamCFrame = Camera.CFrame Camera.CameraType = Enum.CameraType.Scriptable
        if char and char:FindFirstChildOfClass("Humanoid") then
            Camera.CameraSubject = nil char.Humanoid.WalkSpeed = 0 char.Humanoid.JumpPower = 0
        end
        fcOverlay.Visible = true
        for k in pairs(freeCamInput) do freeCamInput[k] = false end
        local rx, ry, rz = freeCamCFrame:ToEulerAnglesYXZ() freeCamRotX = rx freeCamRotY = ry
    else
        Camera.CameraType = Enum.CameraType.Custom
        if char and char:FindFirstChildOfClass("Humanoid") then
            Camera.CameraSubject = char.Humanoid char.Humanoid.WalkSpeed = States.Speed char.Humanoid.JumpPower = States.JumpPower
        end
        fcOverlay.Visible = false
    end
end)

-- ==========================================
-- TAB 4: COMBAT
-- ==========================================
local combatTab = createTab("Combat", "⚔️")
createToggle(combatTab, "Hitbox Expander", false, function(s) States.Hitbox = s end)
createSlider(combatTab, "Hitbox Size", 5, 50, 10, function(v) States.HitboxSize = v end)
createToggle(combatTab, "Aimbot (Camera Lock)", false, function(s) States.Aimbot = s end)
createToggle(combatTab, "Wallbang (Bắn xuyên tường)", false, function(s) States.Wallbang = s end)
createToggle(combatTab, "Silent Kill Aura (Không cần nhìn)", false, function(s) States.KillAura = s end)
createSlider(combatTab, "Aura Range", 10, 2000, 2000, function(v) States.AuraRange = v end)
createToggle(combatTab, "Auto Dodge (VIP Teleport)", false, function(s) States.Dodge = s end)

-- ==========================================
-- TAB 5: FARM REWARD
-- ==========================================
pcall(function()
do
    local rewardTab = createTab("Farm Reward", "🌾")
    createToggle(rewardTab, "Ép Thời Gian Về 0 (liên tục)", false, function(s) States.ResetTime = s end)
    createToggle(rewardTab, "Auto Bấm Nhận (UI)", false, function(s) States.AutoClaim = s end)
    createToggle(rewardTab, "Spam Remote (Nhận Ngầm)", false, function(s) States.SpamRemote = s end)
    
    createToggle(rewardTab, "⚡ Auto Nhận Thưởng & Mở Rương", false, function(s)
        States.AutoReward = s
        if s then
            if autoRewardThread then pcall(task.cancel, autoRewardThread) end
            if autoRewardConn then pcall(task.cancel, autoRewardConn) end
            
            local cachedPrompts = {}
            local cachedDetectors = {}
            local cachedButtons = {}
            
            autoRewardConn = task.spawn(function()
                while States.AutoReward do
                    local newPrompts = {}
                    local newDetectors = {}
                    
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            table.insert(newPrompts, obj)
                        elseif obj:IsA("ClickDetector") then
                            table.insert(newDetectors, obj)
                        end
                    end
                    
                    local newButtons = {}
                    local pg = LocalPlayer:FindFirstChild("PlayerGui")
                    if pg then
                        for _, gui in ipairs(pg:GetChildren()) do
                            for _, obj in ipairs(gui:GetDescendants()) do
                                if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                                    local t = "" pcall(function() t = string.lower(obj.Text) end)
                                    if string.find(t, "nhận") or string.find(t, "claim") or string.find(t, "thắng") or string.find(t, "mở") or string.find(t, "open") then
                                        table.insert(newButtons, obj)
                                    end
                                end
                            end
                        end
                    end
                    
                    cachedPrompts = newPrompts
                    cachedDetectors = newDetectors
                    cachedButtons = newButtons
                    
                    task.wait(0.5)
                end
            end)
            
            autoRewardThread = task.spawn(function()
                while States.AutoReward do
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local hrpPos = hrp.Position
                        
                        for _, obj in ipairs(cachedPrompts) do
                            if obj and obj.Parent then
                                local part = obj.Parent
                                if part and part:IsA("BasePart") and (hrpPos - part.Position).Magnitude <= 100 then
                                    pcall(function()
                                        obj.Enabled = true
                                        obj.HoldDuration = 0
                                        obj.MaxActivationDistance = math.huge
                                        if fireproximityprompt then fireproximityprompt(obj) 
                                        else obj:InputHoldBegin() task.wait() obj:InputHoldEnd() end
                                    end)
                                end
                            end
                        end
                        
                        for _, obj in ipairs(cachedDetectors) do
                            if obj and obj.Parent then
                                local part = obj.Parent
                                if part and part:IsA("BasePart") and (hrpPos - part.Position).Magnitude <= 100 then
                                    pcall(function()
                                        obj.MaxActivationDistance = math.huge
                                        if fireclickdetector then fireclickdetector(obj) end
                                    end)
                                end
                            end
                        end
                        
                        for _, btn in ipairs(cachedButtons) do
                            if btn and btn.Parent then
                                pcall(function()
                                    btn.Visible = true
                                    btn.Active = true
                                    if firesignal then firesignal(btn.MouseButton1Click) end
                                    btn:Activate()
                                end)
                            end
                        end
                    end
                    RunService.Heartbeat:Wait()
                end
            end)
        else
            if autoRewardThread then pcall(task.cancel, autoRewardThread) autoRewardThread = nil end
            if autoRewardConn then pcall(task.cancel, autoRewardConn) autoRewardConn = nil end
        end
    end)

    createSlider(rewardTab, "SpeedHack (Tốc độ Game)", 1, 1000, 1, function(v)
        States.GameSpeed = v
        local char = LocalPlayer.Character
        if char then
            for _, obj in pairs(char:GetDescendants()) do
                if obj:IsA("Animator") then
                    for _, track in pairs(obj:GetPlayingAnimationTracks()) do pcall(function() track:AdjustSpeed(v) end) end
                end
            end
        end
    end)

    local function scanAllGuiButtons()
        local list = {}
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return list end
        for _, gui in ipairs(pg:GetChildren()) do
            for _, obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                    local t = "" pcall(function() t = string.lower(obj.Text) end)
                    local n = string.lower(obj.Name)
                    table.insert(list, {obj = obj, text = t, name = n})
                end
            end
        end
        return list
    end

    local function forceTimeValuesZero()
        local keys = {"time","timer","countdown","cooldown","playtime","wait","duration","remain","left","reset"}
        local function chk(name)
            local n = string.lower(name)
            for _, k in ipairs(keys) do if string.find(n, k, 1, true) then return true end end
            return false
        end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("IntValue") or obj:IsA("NumberValue") then
                if chk(obj.Name) then pcall(function() obj.Value = 0 end) end
            elseif obj:IsA("StringValue") then
                if chk(obj.Name) then pcall(function() obj.Value = "00:00" end) end
            end
        end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, obj in ipairs(pg:GetDescendants()) do
                if obj:IsA("IntValue") or obj:IsA("NumberValue") then
                    if chk(obj.Name) then pcall(function() obj.Value = 0 end) end
                elseif obj:IsA("StringValue") then
                    if chk(obj.Name) then pcall(function() obj.Value = "00:00" end) end
                end
            end
        end
        for _, obj in ipairs(LocalPlayer:GetDescendants()) do
            if obj:IsA("IntValue") or obj:IsA("NumberValue") then
                if chk(obj.Name) then pcall(function() obj.Value = 0 end) end
            elseif obj:IsA("StringValue") then
                if chk(obj.Name) then pcall(function() obj.Value = "00:00" end) end
            end
        end
    end

    local function fireRewardRemotes(keywords)
        local function tryFire(remote)
            if not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then return end
            local n = string.lower(remote.Name)
            local match = false
            for _, k in ipairs(keywords) do if string.find(n, k, 1, true) then match = true break end end
            if not match then return end
            for _, args in ipairs({{}, {0}, {1}, {"claim"}, {true}}) do
                pcall(function()
                    if remote:IsA("RemoteEvent") then remote:FireServer(table.unpack(args))
                    else remote:InvokeServer(table.unpack(args)) end
                end)
            end
        end
        for _, remote in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do tryFire(remote) end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then for _, remote in ipairs(pg:GetDescendants()) do tryFire(remote) end end
        for _, remote in ipairs(LocalPlayer:GetDescendants()) do tryFire(remote) end
    end

    local function clickClaimButtons(keywords)
        for _, b in ipairs(scanAllGuiButtons()) do
            local match = false
            for _, k in ipairs(keywords) do
                if string.find(b.text, k, 1, true) or string.find(b.name, k, 1, true) then match = true break end
            end
            if match then
                pcall(function() if firesignal then firesignal(b.obj.MouseButton1Click) end end)
                pcall(function() b.obj:Activate() end)
            end
        end
    end

    local bypassPlaytimeBtn = Instance.new("TextButton")
    bypassPlaytimeBtn.Size = UDim2.new(1, -10, 0, 45)
    bypassPlaytimeBtn.BackgroundColor3 = Theme.AccentCyan
    bypassPlaytimeBtn.TextColor3 = Theme.Text
    bypassPlaytimeBtn.Font = Enum.Font.GothamBlack
    bypassPlaytimeBtn.TextSize = 14
    bypassPlaytimeBtn.Text = "⏱️ NHẬN THƯỞNG THỜI GIAN CHƠI (BYPASS)"
    bypassPlaytimeBtn.BorderSizePixel = 0
    bypassPlaytimeBtn.ZIndex = 54
    bypassPlaytimeBtn.Parent = rewardTab
    local bpc = Instance.new("UICorner") bpc.CornerRadius = UDim.new(0, 8) bpc.Parent = bypassPlaytimeBtn
    local bps = Instance.new("UIStroke") bps.Color = Theme.AccentPurple bps.Thickness = 2 bps.Parent = bypassPlaytimeBtn

    bindClick(bypassPlaytimeBtn, function()
        bypassPlaytimeBtn.Text = "⏱️ ĐANG BYPASS..."
        local pkws = {"playtime","play","timeplay","time","minute","hour","session","online","active","min","gio","phut"}
        local ckws = {"nhận","claim","reward","playtime","time","min","hour","nhant","thuong"}
        for i = 1, 20 do
            forceTimeValuesZero()
            fireRewardRemotes(pkws)
            clickClaimButtons(ckws)
            if i % 5 == 0 then bypassPlaytimeBtn.Text = "⏱️ ĐANG BYPASS... (" .. i .. "/20)" end
            task.wait(0.1)
        end
        bypassPlaytimeBtn.Text = "✅ ĐÃ NHẬN THƯỞNG THỜI GIAN CHƠI"
        task.wait(2)
        bypassPlaytimeBtn.Text = "⏱️ NHẬN THƯỞNG THỜI GIAN CHƠI (BYPASS)"
    end)

    local bypassDailyBtn2 = Instance.new("TextButton")
    bypassDailyBtn2.Size = UDim2.new(1, -10, 0, 45)
    bypassDailyBtn2.BackgroundColor3 = Theme.AccentPink
    bypassDailyBtn2.TextColor3 = Theme.Text
    bypassDailyBtn2.Font = Enum.Font.GothamBlack
    bypassDailyBtn2.TextSize = 14
    bypassDailyBtn2.Text = "📅 NHẬN THƯỞNG HẰNG NGÀY (BYPASS)"
    bypassDailyBtn2.BorderSizePixel = 0
    bypassDailyBtn2.ZIndex = 54
    bypassDailyBtn2.Parent = rewardTab
    local bdc2 = Instance.new("UICorner") bdc2.CornerRadius = UDim.new(0, 8) bdc2.Parent = bypassDailyBtn2
    local bds2 = Instance.new("UIStroke") bds2.Color = Theme.AccentGold bds2.Thickness = 2 bds2.Parent = bypassDailyBtn2

    bindClick(bypassDailyBtn2, function()
        bypassDailyBtn2.Text = "📅 ĐANG BYPASS..."
        local dkws = {"daily","login","day","streak","calendar","checkin","signin","gift","reward","bonus","consecutive","ngay","diemdanh"}
        local ckws = {"nhận","claim","daily","login","day","gift","bonus","checkin","signin","nhan","thuong","diemdanh"}
        for i = 1, 20 do
            forceTimeValuesZero()
            fireRewardRemotes(dkws)
            clickClaimButtons(ckws)
            if i % 5 == 0 then bypassDailyBtn2.Text = "📅 ĐANG BYPASS... (" .. i .. "/20)" end
            task.wait(0.1)
        end
        bypassDailyBtn2.Text = "✅ ĐÃ NHẬN THƯỞNG HẰNG NGÀY"
        task.wait(2)
        bypassDailyBtn2.Text = "📅 NHẬN THƯỞNG HẰNG NGÀY (BYPASS)"
    end)

    local bypassAllBtn = Instance.new("TextButton")
    bypassAllBtn.Size = UDim2.new(1, -10, 0, 50)
    bypassAllBtn.BackgroundColor3 = Theme.AccentGold
    bypassAllBtn.TextColor3 = Theme.MainBG
    bypassAllBtn.Font = Enum.Font.GothamBlack
    bypassAllBtn.TextSize = 15
    bypassAllBtn.Text = "⚡ NHẬN TẤT CẢ THƯỞNG (PLAYTIME + DAILY + EVENT)"
    bypassAllBtn.BorderSizePixel = 0
    bypassAllBtn.ZIndex = 54
    bypassAllBtn.Parent = rewardTab
    local bac = Instance.new("UICorner") bac.CornerRadius = UDim.new(0, 8) bac.Parent = bypassAllBtn
    local bas = Instance.new("UIStroke") bas.Color = Theme.AccentCyan bas.Thickness = 2 bas.Parent = bypassAllBtn

    bindClick(bypassAllBtn, function()
        bypassAllBtn.Text = "⚡ ĐANG BYPASS TẤT CẢ..."
        local allkws = {"playtime","play","time","minute","hour","session","online","active","min","gio","phut",
                        "daily","login","day","streak","calendar","checkin","signin","gift","reward","bonus",
                        "consecutive","ngay","diemdanh","event","claim","nhant","thuong","cash","coin","gem","code","redeem"}
        for i = 1, 30 do
            forceTimeValuesZero()
            fireRewardRemotes(allkws)
            clickClaimButtons(allkws)
            if i % 5 == 0 then bypassAllBtn.Text = "⚡ ĐANG BYPASS... (" .. i .. "/30)" end
            task.wait(0.08)
        end
        bypassAllBtn.Text = "✅ XONG! KIỂM TRA TÚI ĐỒ / INVENTORY"
        task.wait(3)
        bypassAllBtn.Text = "⚡ NHẬN TẤT CẢ THƯỞNG (PLAYTIME + DAILY + EVENT)"
    end)

    task.spawn(function()
        while true do
            task.wait(0.15)
            if States.ResetTime then forceTimeValuesZero() end
            if States.AutoClaim then
                clickClaimButtons({"nhận","claim","free","thuong","reward","gift","daily","login","playtime","bonus"})
            end
        end
    end)

    task.spawn(function()
        while true do
            task.wait(0.4)
            if States.SpamRemote then
                fireRewardRemotes({"claim","reward","daily","nhan","playtime","login","gift","bonus","checkin","code","redeem"})
            end
        end
    end)
end
end)

-- ==========================================
-- TAB 6: TELEPORT
-- ==========================================
local tpTab = createTab("Teleport", "📍")
local tpMouseBtn = Instance.new("TextButton")
tpMouseBtn.Size = UDim2.new(1, -10, 0, 35) tpMouseBtn.BackgroundColor3 = Theme.SidebarBtn
tpMouseBtn.TextColor3 = Theme.Text tpMouseBtn.Font = Enum.Font.GothamBold tpMouseBtn.TextSize = 13
tpMouseBtn.Text = "Dịch Đến Chuột (TP to Mouse)" tpMouseBtn.BorderSizePixel = 0 tpMouseBtn.ZIndex = 54 tpMouseBtn.Parent = tpTab
local tmc = Instance.new("UICorner") tmc.CornerRadius = UDim.new(0, 8) tmc.Parent = tpMouseBtn
bindClick(tpMouseBtn, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") and Mouse.Hit then char.HumanoidRootPart.CFrame = Mouse.Hit + Vector3.new(0, 3, 0) end
end)

local toggleTeleOverlayBtn = Instance.new("TextButton")
toggleTeleOverlayBtn.Size = UDim2.new(1, -10, 0, 35) toggleTeleOverlayBtn.BackgroundColor3 = Theme.SidebarBtn
toggleTeleOverlayBtn.TextColor3 = Theme.Text toggleTeleOverlayBtn.Font = Enum.Font.GothamBold
toggleTeleOverlayBtn.TextSize = 13 toggleTeleOverlayBtn.Text = "HIỆN BẢNG TELE (NGOÀI)"
toggleTeleOverlayBtn.BorderSizePixel = 0 toggleTeleOverlayBtn.ZIndex = 54 toggleTeleOverlayBtn.Parent = tpTab
local tto = Instance.new("UICorner") tto.CornerRadius = UDim.new(0, 8) tto.Parent = toggleTeleOverlayBtn
bindClick(toggleTeleOverlayBtn, function()
    teleOverlay.Visible = not teleOverlay.Visible
    if teleOverlay.Visible then
        toggleTeleOverlayBtn.Text = "ẨN BẢNG TELE (NGOÀI)" toggleTeleOverlayBtn.BackgroundColor3 = Theme.AccentPink
    else
        toggleTeleOverlayBtn.Text = "HIỆN BẢNG TELE (NGOÀI)" toggleTeleOverlayBtn.BackgroundColor3 = Theme.SidebarBtn
    end
end)

local plrScroll = Instance.new("ScrollingFrame")
plrScroll.Size = UDim2.new(1, -10, 0, 200) plrScroll.BackgroundTransparency = 1
plrScroll.BorderSizePixel = 0 plrScroll.ScrollBarThickness = 4 plrScroll.ZIndex = 54
plrScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y plrScroll.Parent = tpTab
local plrLayout = Instance.new("UIListLayout") plrLayout.Padding = UDim.new(0, 3) plrLayout.Parent = plrScroll

local function updatePlayerList()
    for _, child in pairs(plrScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 30) btn.BackgroundColor3 = Theme.SidebarBtn
            btn.TextColor3 = Theme.Text btn.Font = Enum.Font.GothamBold btn.TextSize = 12
            btn.Text = "Tele đến: " .. plr.Name btn.BorderSizePixel = 0 btn.ZIndex = 55 btn.Parent = plrScroll
            local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = btn
            bindClick(btn, function()
                local targetChar = plr.Character
                local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetHrp and myHrp then myHrp.CFrame = targetHrp.CFrame + Vector3.new(0, 3, 0) end
            end)
        end
    end
end
updatePlayerList()
table.insert(Connections, Players.PlayerAdded:Connect(updatePlayerList))
table.insert(Connections, Players.PlayerRemoving:Connect(function() task.wait(1) updatePlayerList() end))

-- ==========================================
-- TAB 7: MISC
-- ==========================================
local miscTab = createTab("Misc", "⚙️")
createToggle(miscTab, "Anti-AFK (Chống treo)", false, function(s) States.AntiAFK = s end)
createToggle(miscTab, "Fullbright (Sáng bản đồ)", false, function(s)
    States.Fullbright = s
    if s then
        Lighting.Brightness = 2 Lighting.ClockTime = 12 Lighting.GlobalShadows = false Lighting.FogEnd = 9e9
    else
        Lighting.Brightness = 1 Lighting.ClockTime = 14 Lighting.GlobalShadows = true Lighting.FogEnd = 100000
    end
end)
createToggle(miscTab, "Chống Rơi Vực (Anti-Void)", false, function(s) States.AntiVoid = s end)
createToggle(miscTab, "Mở Khóa FPS (Unlock FPS)", false, function(s)
    States.UnlockFPS = s
    if setfpscap then pcall(function() if s then setfpscap(240) else setfpscap(60) end end) end
end)
createToggle(miscTab, "Auto Clicker", false, function(s)
    States.AutoClick = s
    if s then
        if autoClickThread then task.cancel(autoClickThread) end
        autoClickThread = task.spawn(function() while States.AutoClick do task.wait(0.1) VirtualUser:CaptureController() VirtualUser:ClickButton1(Vector2.new(500, 500)) end end)
    else
        if autoClickThread then task.cancel(autoClickThread) autoClickThread = nil end
    end
end)
createToggle(miscTab, "Remove Particles", false, function(s)
    States.RemoveParticles = s
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") then obj.Enabled = not s end
    end
end)

-- ==========================================
-- TAB 8: SCAN ITEM
-- ==========================================
local scanItemTab = createTab("Scan Item", "🔍")
local itemInputBox = Instance.new("TextBox")
itemInputBox.Size = UDim2.new(1, -10, 0, 35) itemInputBox.BackgroundColor3 = Theme.SidebarBtn
itemInputBox.TextColor3 = Theme.Text itemInputBox.PlaceholderText = "Nhập tên vật phẩm (VD: win, coin)..."
itemInputBox.PlaceholderColor3 = Theme.TextDim itemInputBox.Text = "" itemInputBox.TextSize = 13
itemInputBox.Font = Enum.Font.GothamBold itemInputBox.BorderSizePixel = 0 itemInputBox.ClearTextOnFocus = false
itemInputBox.ZIndex = 54 itemInputBox.Parent = scanItemTab
local iic = Instance.new("UICorner") iic.CornerRadius = UDim.new(0, 8) iic.Parent = itemInputBox

local scanWinBtn = Instance.new("TextButton")
scanWinBtn.Size = UDim2.new(1, -10, 0, 35) scanWinBtn.BackgroundColor3 = Theme.AccentPink
scanWinBtn.TextColor3 = Theme.Text scanWinBtn.Font = Enum.Font.GothamBold scanWinBtn.TextSize = 13
scanWinBtn.Text = "QUÉT WINPART" scanWinBtn.BorderSizePixel = 0 scanWinBtn.ZIndex = 54 scanWinBtn.Parent = scanItemTab
local swb = Instance.new("UICorner") swb.CornerRadius = UDim.new(0, 8) swb.Parent = scanWinBtn

local scanItemBtn = Instance.new("TextButton")
scanItemBtn.Size = UDim2.new(1, -10, 0, 35) scanItemBtn.BackgroundColor3 = Theme.AccentPurple
scanItemBtn.TextColor3 = Theme.Text scanItemBtn.Font = Enum.Font.GothamBold scanItemBtn.TextSize = 13
scanItemBtn.Text = "QUÉT VẬT PHẨM (THEO TÊN)" scanItemBtn.BorderSizePixel = 0 scanItemBtn.ZIndex = 54 scanItemBtn.Parent = scanItemTab
local sib = Instance.new("UICorner") sib.CornerRadius = UDim.new(0, 8) sib.Parent = scanItemBtn

createSlider(scanItemTab, "Auto TP Delay", 0, 2.0, 0, function(v) States.ItemTpSpeed = v end)

local itemListFrame = Instance.new("ScrollingFrame")
itemListFrame.Size = UDim2.new(1, -10, 0, 250) itemListFrame.BackgroundColor3 = Theme.SidebarBtn
itemListFrame.BackgroundTransparency = 0.5 itemListFrame.BorderSizePixel = 0 itemListFrame.ScrollBarThickness = 6
itemListFrame.ScrollBarImageColor3 = Theme.AccentPink itemListFrame.ZIndex = 54
itemListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y itemListFrame.Parent = scanItemTab
local ilf = Instance.new("UICorner") ilf.CornerRadius = UDim.new(0, 8) ilf.Parent = itemListFrame
local ilLayout = Instance.new("UIListLayout") ilLayout.Padding = UDim.new(0, 4) ilLayout.Parent = itemListFrame

local function getObjDistance(target)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not target or not target.Parent then return "..." end
    local targetPos = nil
    if target:IsA("BasePart") then targetPos = target.Position
    elseif target:IsA("Model") then
        local ok, pivot = pcall(function() return target:GetPivot() end)
        if ok then targetPos = pivot.Position elseif target.PrimaryPart then targetPos = target.PrimaryPart.Position end
    end
    if targetPos then return math.floor((hrp.Position - targetPos).Magnitude) .. "m" end
    return "..."
end

local function parseNumberString(str)
    if not str then return nil end
    str = string.lower(str)
    str = string.gsub(str, ",", "")
    local numStr, suffix = string.match(str, "(%d+%.?%d*)[%s]*([kmbt]?)")
    if numStr then
        local n = tonumber(numStr)
        if n then
            if suffix == "k" then n = n * 1000
            elseif suffix == "m" then n = n * 1000000
            elseif suffix == "b" then n = n * 1000000000
            elseif suffix == "t" then n = n * 1000000000000 end
            return n
        end
    end
    return nil
end

local function formatNumber(num)
    if not num then return "" end
    if num >= 1e12 then return string.format("%.1fT", num/1e12)
    elseif num >= 1e9 then return string.format("%.1fB", num/1e9)
    elseif num >= 1e6 then return string.format("%.1fM", num/1e6)
    elseif num >= 1e3 then return string.format("%.1fK", num/1e3)
    else return tostring(math.floor(num)) end
end

local function getWinAmount(obj)
    if not obj or not obj.Parent then return nil end
    local attrs = {"Value", "Amount", "Win", "Wins", "Reward", "Cash", "Coin", "Points"}
    for _, attr in ipairs(attrs) do
        local ok, val = pcall(function() return obj:GetAttribute(attr) end)
        if ok and val and type(val) == "number" then return val end
    end
    if string.find(string.lower(obj.Name), "win") then
        local n = parseNumberString(obj.Name)
        if n then return n end
    end
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") then
            local n = string.lower(child.Name)
            if string.find(n, "win") or string.find(n, "value") or string.find(n, "amount") then
                local num = tonumber(child.Value) or parseNumberString(tostring(child.Value))
                if num then return num end
            end
        end
    end
    local function searchBillboard(part)
        local bg = part:FindFirstChildWhichIsA("BillboardGui")
        if bg then
            for _, txt in ipairs(bg:GetDescendants()) do
                if txt:IsA("TextLabel") and txt.Text then
                    local lowerTxt = string.lower(txt.Text)
                    if string.find(lowerTxt, "thắng") or string.find(lowerTxt, "win") or string.find(txt.Text, "+") then
                        local n = parseNumberString(txt.Text)
                        if n then return n end
                    end
                end
            end
        end
        return nil
    end
    if obj:IsA("BasePart") then
        local v = searchBillboard(obj) if v then return v end
    elseif obj:IsA("Model") then
        for _, part in ipairs(obj:GetDescendants()) do
            if part:IsA("BasePart") then
                local v = searchBillboard(part) if v then return v end
            end
        end
    end
    return nil
end

local function addItemToUI(obj, nameOverride)
    table.insert(scannedItems, obj)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 30) btn.BackgroundColor3 = Theme.SidebarBtn btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.GothamBold btn.TextSize = 12 btn.BorderSizePixel = 0 btn.ZIndex = 55 btn.Parent = itemListFrame
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = btn
    local baseText = "📦 " .. (nameOverride or obj.Name)
    local winAmount = getWinAmount(obj)
    local amountText = winAmount and (" | +" .. formatNumber(winAmount)) or ""
    btn.Text = baseText .. amountText .. " | Cách: " .. getObjDistance(obj)
    task.spawn(function()
        while btn and btn.Parent do
            task.wait(0.5)
            if obj and obj.Parent then
                local newAmount = getWinAmount(obj)
                local newAmountText = newAmount and (" | +" .. formatNumber(newAmount)) or amountText
                btn.Text = baseText .. newAmountText .. " | Cách: " .. getObjDistance(obj)
            else
                btn.Text = baseText .. amountText .. " | Cách: N/A"
            end
        end
    end)
    bindClick(btn, function()
        selectedItemForLoop = obj
        for _, child in pairs(itemListFrame:GetChildren()) do if child:IsA("TextButton") then child.BackgroundColor3 = Theme.SidebarBtn end end
        btn.BackgroundColor3 = Theme.AccentPink
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local targetPos = nil
            if obj:IsA("BasePart") then targetPos = obj.Position
            elseif obj:IsA("Model") then
                local ok, pivot = pcall(function() return obj:GetPivot() end)
                if ok then targetPos = pivot.Position elseif obj.PrimaryPart then targetPos = obj.PrimaryPart.Position end
            end
            if targetPos then hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0)) end
        end
    end)
end

local function performScan(isWinScan)
    local query = string.lower(itemInputBox.Text)
    if not isWinScan and query == "" then
        scanItemBtn.Text = "VUI LÒNG NHẬP TÊN!" task.wait(1.5) scanItemBtn.Text = "QUÉT VẬT PHẨM (THEO TÊN)" return
    end
    for _, child in pairs(itemListFrame:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    table.clear(scannedItems) selectedItemForLoop = nil
    local all = Workspace:GetDescendants() local total = #all local processed = 0 local count = 0
    for _, obj in ipairs(all) do
        processed = processed + 1
        if processed % 100 == 0 then
            if isWinScan then scanWinBtn.Text = "ĐANG QUÉT: " .. processed .. " / " .. total
            else scanItemBtn.Text = "ĐANG QUÉT: " .. processed .. " / " .. total end
            task.wait()
        end
        if (obj:IsA("BasePart") or obj:IsA("Model")) and not obj:IsDescendantOf(LocalPlayer.Character) then
            local nameLower = string.lower(obj.Name)
            local m = false
            if isWinScan then if string.find(nameLower, "win") then m = true end
            else if string.find(nameLower, query) then m = true end end
            if m then addItemToUI(obj) count = count + 1 end
        end
    end
    if isWinScan then scanWinBtn.Text = "TÌM THẤY: " .. count .. " WINPART"
    else scanItemBtn.Text = "TÌM THẤY: " .. count .. " VẬT PHẨM" end
end
bindClick(scanWinBtn, function() performScan(true) end)
bindClick(scanItemBtn, function() performScan(false) end)

createToggle(scanItemTab, "Auto Teleport Item (All)", false, function(s)
    States.AutoItemTp = s
    if s then
        if #scannedItems == 0 then performScan(true) task.wait(0.5) end
        if autoItemTpThread then task.cancel(autoItemTpThread) end
        autoItemTpThread = task.spawn(function()
            while States.AutoItemTp do
                if #scannedItems == 0 then performScan(true) task.wait(1)
                else
                    for _, item in ipairs(scannedItems) do
                        if not States.AutoItemTp then break end
                        if item and item.Parent then
                            local char = LocalPlayer.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local targetPos = nil
                                if item:IsA("BasePart") then targetPos = item.Position
                                elseif item:IsA("Model") then
                                    local ok, pivot = pcall(function() return item:GetPivot() end)
                                    if ok then targetPos = pivot.Position elseif item.PrimaryPart then targetPos = item.PrimaryPart.Position end
                                end
                                if targetPos then hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0)) end
                            end
                            if States.ItemTpSpeed > 0 then task.wait(States.ItemTpSpeed) else RunService.Heartbeat:Wait() end
                        end
                    end
                    if States.AutoItemTp then table.clear(scannedItems) performScan(true) task.wait(0.5) end
                end
            end
        end)
    else
        if autoItemTpThread then task.cancel(autoItemTpThread) autoItemTpThread = nil end
    end
end)

createToggle(scanItemTab, "AUTO TP SELECTED (Vật phẩm đã chọn)", false, function(s)
    States.AutoTpSelected = s
    if s then
        if not selectedItemForLoop then States.AutoTpSelected = false return end
        if autoTpSelectedThread then task.cancel(autoTpSelectedThread) end
        autoTpSelectedThread = task.spawn(function()
            while States.AutoTpSelected do
                if selectedItemForLoop and selectedItemForLoop.Parent then
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local targetPos = nil
                        if selectedItemForLoop:IsA("BasePart") then targetPos = selectedItemForLoop.Position
                        elseif selectedItemForLoop:IsA("Model") then
                            local ok, pivot = pcall(function() return selectedItemForLoop:GetPivot() end)
                            if ok then targetPos = pivot.Position elseif selectedItemForLoop.PrimaryPart then targetPos = selectedItemForLoop.PrimaryPart.Position end
                        end
                        if targetPos then hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0)) end
                    end
                else States.AutoTpSelected = false end
                if States.ItemTpSpeed > 0 then task.wait(States.ItemTpSpeed) else RunService.Heartbeat:Wait() end
            end
        end)
    else
        if autoTpSelectedThread then task.cancel(autoTpSelectedThread) autoTpSelectedThread = nil end
    end
end)

-- ==========================================
-- TAB 9: GAME (AUTO REBIRTH)
-- ==========================================
getgenv().HTrungRebirth = { enabled = false, thread = nil, counter = 0, delay = 0, learned = {} }

pcall(function()
    local gameTab = createTab("Game", "🎯")
    local RB = getgenv().HTrungRebirth

    local function getRebirthCount()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            for _, v in ipairs(ls:GetChildren()) do
                if v:IsA("IntValue") or v:IsA("NumberValue") then
                    local n = string.lower(v.Name)
                    if string.find(n, "rebirth") or string.find(n, "reborn") or string.find(n, "prestige") or
                       string.find(n, "ascend") or string.find(n, "reset") or string.find(n, "taisinh") then
                        return v.Value
                    end
                end
            end
        end
        for _, attr in ipairs({"Rebirths","Rebirth","RebirthCount","Prestige","Prestiges","Reset","RebirthsCount"}) do
            local ok, v = pcall(function() return LocalPlayer:GetAttribute(attr) end)
            if ok and v and type(v) == "number" then return v end
        end
        for _, obj in ipairs(LocalPlayer:GetChildren()) do
            if obj:IsA("IntValue") or obj:IsA("NumberValue") then
                local n = string.lower(obj.Name)
                if string.find(n, "rebirth") or string.find(n, "reborn") or string.find(n, "prestige") then
                    return obj.Value
                end
            end
        end
        return nil
    end

    local rebirthStatus = Instance.new("TextLabel")
    rebirthStatus.Size = UDim2.new(1, -10, 0, 34) rebirthStatus.BackgroundColor3 = Theme.SidebarBtn
    rebirthStatus.BackgroundTransparency = 0.5 rebirthStatus.TextColor3 = Theme.Text
    rebirthStatus.Font = Enum.Font.GothamBold rebirthStatus.TextSize = 12
    rebirthStatus.Text = "Trạng thái: Chưa có lệnh. Bấm QUÉT."
    rebirthStatus.BorderSizePixel = 0 rebirthStatus.ZIndex = 54 rebirthStatus.Parent = gameTab
    local rsc = Instance.new("UICorner") rsc.CornerRadius = UDim.new(0, 8) rsc.Parent = rebirthStatus

    local logBox = Instance.new("ScrollingFrame")
    logBox.Size = UDim2.new(1, -10, 0, 150) logBox.BackgroundColor3 = Theme.MainBG
    logBox.BackgroundTransparency = 0.3 logBox.BorderSizePixel = 0 logBox.ScrollBarThickness = 4
    logBox.ScrollBarImageColor3 = Theme.AccentPink logBox.ZIndex = 54
    logBox.AutomaticCanvasSize = Enum.AutomaticSize.Y logBox.CanvasSize = UDim2.new(0, 0, 0, 0)
    logBox.Parent = gameTab
    local lbc = Instance.new("UICorner") lbc.CornerRadius = UDim.new(0, 8) lbc.Parent = logBox
    local ll = Instance.new("UIListLayout") ll.Padding = UDim.new(0, 2) ll.Parent = logBox

    local function logUI(text, color)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 16) lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color or Theme.TextDim lbl.Font = Enum.Font.Code lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.Text = "> " .. text lbl.ZIndex = 55 lbl.Parent = logBox
        task.defer(function() logBox.CanvasPosition = Vector2.new(0, ll.AbsoluteContentSize.Y) end)
    end

    local scanning = false

    local function scanAndLearn()
        if scanning then return end
        scanning = true
        local before = getRebirthCount()
        if before == nil then
            logUI("⚠ Không tìm thấy stat rebirth (leaderstats/attribute)", Theme.AccentPink)
        else
            logUI("Stat rebirth hiện tại: " .. tostring(before), Theme.AccentCyan)
        end

        local candidates = {}
        local kws = {
            {"rebirth", 1}, {"reborn", 1}, {"taisinh", 1},
            {"prestige", 2}, {"ascend", 2},
            {"reset", 3}, {"evolve", 3}
        }

        local ok1, rs = pcall(function() return game:GetService("ReplicatedStorage"):GetDescendants() end)
        if ok1 and rs then
            for _, remote in ipairs(rs) do
                if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                    local n = string.lower(remote.Name)
                    for _, kw in ipairs(kws) do
                        if string.find(n, kw[1], 1, true) then
                            table.insert(candidates, {remote = remote, priority = kw[2], isButton = false}) break
                        end
                    end
                end
            end
        end

        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in ipairs(playerGui:GetChildren()) do
                for _, obj in ipairs(gui:GetDescendants()) do
                    if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                        local n = string.lower(obj.Name)
                        local t = "" pcall(function() t = string.lower(obj.Text) end)
                        for _, kw in ipairs(kws) do
                            if string.find(n, kw[1], 1, true) or string.find(t, kw[1], 1, true) then
                                table.insert(candidates, {button = obj, priority = kw[2], isButton = true}) break
                            end
                        end
                    end
                end
            end
        end

        table.sort(candidates, function(a, b) return a.priority < b.priority end)
        logUI("Tìm thấy " .. #candidates .. " ứng viên. Bắt đầu thử...", Theme.AccentCyan)

        RB.learned = {}
        local currentStat = before
        for i, c in ipairs(candidates) do
            if before ~= nil and currentStat ~= nil and currentStat > before then break end
            local name = c.isButton and c.button:GetFullName() or c.remote:GetFullName()
            logUI("Thử #" .. i .. ": " .. name, Theme.TextDim)

            pcall(function()
                if c.isButton then
                    if firesignal then firesignal(c.button.MouseButton1Click) end
                    pcall(function() c.button:Activate() end)
                else
                    if c.remote:IsA("RemoteEvent") then c.remote:FireServer()
                    else c.remote:InvokeServer() end
                end
            end)

            task.wait(1.2)
            local after = getRebirthCount()
            if before ~= nil and after ~= nil and after > currentStat then
                logUI("✅ ĐÚNG: " .. name, Theme.AccentCyan)
                if c.isButton then
                    table.insert(RB.learned, {button = c.button})
                else
                    table.insert(RB.learned, {remote = c.remote, method = c.remote:IsA("RemoteEvent") and "FireServer" or "InvokeServer"})
                end
                currentStat = after
            else
                logUI("  -> không đổi", Theme.TextDim)
            end
        end

        if #RB.learned > 0 then
            rebirthStatus.Text = "Đã học " .. #RB.learned .. " lệnh. Sẵn sàng."
            rebirthStatus.TextColor3 = Theme.AccentCyan
        elseif #candidates == 0 then
            rebirthStatus.Text = "Không có ứng viên nào"
            rebirthStatus.TextColor3 = Theme.AccentPink
        else
            rebirthStatus.Text = "Không lệnh nào tăng stat"
            rebirthStatus.TextColor3 = Theme.AccentPink
        end
        scanning = false
    end

    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(1, -10, 0, 42) scanBtn.BackgroundColor3 = Theme.AccentCyan
    scanBtn.TextColor3 = Theme.Text scanBtn.Font = Enum.Font.GothamBlack scanBtn.TextSize = 12
    scanBtn.Text = "🔍 QUÉT VÀ HỌC LỆNH (tự tìm lệnh tái sinh)"
    scanBtn.BorderSizePixel = 0 scanBtn.ZIndex = 54 scanBtn.Parent = gameTab
    local sbc = Instance.new("UICorner") sbc.CornerRadius = UDim.new(0, 8) sbc.Parent = scanBtn
    bindClick(scanBtn, function() task.spawn(scanAndLearn) end)

    local manualBtn = Instance.new("TextButton")
    manualBtn.Size = UDim2.new(1, -10, 0, 38) manualBtn.BackgroundColor3 = Theme.AccentPurple
    manualBtn.TextColor3 = Theme.Text manualBtn.Font = Enum.Font.GothamBlack manualBtn.TextSize = 13
    manualBtn.Text = "⚡ TÁI SINH NGAY (replay lệnh đã học)"
    manualBtn.BorderSizePixel = 0 manualBtn.ZIndex = 54 manualBtn.Parent = gameTab
    local mbc = Instance.new("UICorner") mbc.CornerRadius = UDim.new(0, 8) mbc.Parent = manualBtn
    bindClick(manualBtn, function()
        if #RB.learned == 0 then
            rebirthStatus.Text = "Chưa có lệnh! Bấm QUÉT trước."
            rebirthStatus.TextColor3 = Theme.AccentPink
            return
        end
        local before = getRebirthCount()
        for _, e in ipairs(RB.learned) do
            pcall(function()
                if e.button then
                    if firesignal then firesignal(e.button.MouseButton1Click) end
                    pcall(function() e.button:Activate() end)
                elseif e.remote then
                    if e.method == "FireServer" then e.remote:FireServer()
                    else e.remote:InvokeServer() end
                end
            end)
        end
        task.wait(1.5)
        local after = getRebirthCount()
        if before ~= nil and after ~= nil then
            if after > before then
                rebirthStatus.Text = "✅ OK! Stat " .. before .. " → " .. after
                rebirthStatus.TextColor3 = Theme.AccentCyan
            else
                rebirthStatus.Text = "⚠ Stat không đổi (" .. before .. " → " .. after .. ")"
                rebirthStatus.TextColor3 = Theme.AccentGold
            end
        else
            rebirthStatus.Text = "Đã gửi (không có stat verify)"
            rebirthStatus.TextColor3 = Theme.AccentGold
        end
    end)

    createSlider(gameTab, "Delay auto (giây)", 0, 30.0, 0, function(v) RB.delay = v end)

    createToggle(gameTab, "Auto Rebirth (tự động tái sinh)", false, function(s)
        RB.enabled = s
        if s then
            if #RB.learned == 0 then
                logUI("Chưa có lệnh → tự quét trước...", Theme.AccentGold)
                scanAndLearn()
                if #RB.learned == 0 then
                    RB.enabled = false
                    rebirthStatus.Text = "Không quét được lệnh"
                    rebirthStatus.TextColor3 = Theme.AccentPink
                    return
                end
            end
            if RB.thread then pcall(task.cancel, RB.thread) end
            RB.thread = task.spawn(function()
                while RB.enabled do
                    local before = getRebirthCount()
                    for _, e in ipairs(RB.learned) do
                        if not RB.enabled then break end
                        pcall(function()
                            if e.button then
                                if firesignal then firesignal(e.button.MouseButton1Click) end
                                pcall(function() e.button:Activate() end)
                            elseif e.remote then
                                if e.method == "FireServer" then e.remote:FireServer()
                                else e.remote:InvokeServer() end
                            end
                        end)
                    end
                    local verifyWait = (RB.delay <= 0) and 0.3 or 1.0
                    task.wait(verifyWait)
                    local after = getRebirthCount()
                    if before ~= nil and after ~= nil and after > before then
                        RB.counter = RB.counter + 1
                        rebirthStatus.Text = "✅ Tái sinh #" .. RB.counter .. " (" .. before .. "→" .. after .. ")"
                        rebirthStatus.TextColor3 = Theme.AccentCyan
                        logUI("OK #" .. RB.counter, Theme.AccentCyan)
                    else
                        rebirthStatus.Text = "Đã gửi (chưa thấy đổi stat)"
                        rebirthStatus.TextColor3 = Theme.AccentGold
                    end
                    if not RB.enabled then break end
                    if RB.delay <= 0 then
                        RunService.Heartbeat:Wait()
                    else
                        task.wait(RB.delay)
                    end
                end
                rebirthStatus.Text = "Trạng thái: Đã tắt"
                rebirthStatus.TextColor3 = Theme.Text
            end)
        else
            if RB.thread then pcall(task.cancel, RB.thread) RB.thread = nil end
            rebirthStatus.Text = "Trạng thái: Đã tắt"
            rebirthStatus.TextColor3 = Theme.Text
        end
    end)

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(1, -10, 0, 30) clearBtn.BackgroundColor3 = Theme.SidebarBtn
    clearBtn.TextColor3 = Theme.AccentPink clearBtn.Font = Enum.Font.GothamBold clearBtn.TextSize = 12
    clearBtn.Text = "🗑️ XÓA LỆNH ĐÃ HỌC" clearBtn.BorderSizePixel = 0 clearBtn.ZIndex = 54 clearBtn.Parent = gameTab
    local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim.new(0, 8) cbc.Parent = clearBtn
    bindClick(clearBtn, function()
        RB.learned = {} RB.counter = 0
        rebirthStatus.Text = "Đã xóa." rebirthStatus.TextColor3 = Theme.Text
        logUI("Cleared.", Theme.AccentPink)
    end)
end)

-- ==========================================
-- TAB 10: ANTI-BAN
-- ==========================================
getgenv().HTrungAntiBan = {
    kick = false, report = false, tp = false, detect = false,
    screenshot = false, spoof = false,
    kickThread = nil, tpThread = nil, detectThread = nil, screenThread = nil,
    lastPos = nil, oldReportAbuse = nil, hookApplied = false, mtOldNamecall = nil
}

pcall(function()
do
    local antiTab = createTab("Anti-Ban", "🛡️")
    local AB = getgenv().HTrungAntiBan

    local logBox = Instance.new("ScrollingFrame")
    logBox.Size = UDim2.new(1, -10, 0, 130)
    logBox.BackgroundColor3 = Theme.MainBG
    logBox.BackgroundTransparency = 0.3
    logBox.BorderSizePixel = 0
    logBox.ScrollBarThickness = 4
    logBox.ScrollBarImageColor3 = Theme.AccentPink
    logBox.ZIndex = 54
    logBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
    logBox.CanvasSize = UDim2.new(0, 0, 0, 0)
    logBox.Parent = antiTab
    local lbc = Instance.new("UICorner") lbc.CornerRadius = UDim.new(0, 8) lbc.Parent = logBox
    local ll = Instance.new("UIListLayout") ll.Padding = UDim.new(0, 2) ll.Parent = logBox

    local function logUI(text, color)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color or Theme.TextDim
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = "> " .. text
        lbl.ZIndex = 55
        lbl.Parent = logBox
        task.defer(function() logBox.CanvasPosition = Vector2.new(0, ll.AbsoluteContentSize.Y) end)
    end

    createToggle(antiTab, "Anti-Kick (Chặn Kick)", false, function(s)
        AB.kick = s
        if s then
            pcall(function()
                if getrawmetatable and setreadonly and newcclosure and getnamecallmethod and not AB.hookApplied then
                    local mt = getrawmetatable(game)
                    if mt and mt.__namecall then
                        AB.mtOldNamecall = mt.__namecall
                        setreadonly(mt, false)
                        mt.__namecall = newcclosure(function(self, ...)
                            local m = getnamecallmethod()
                            if m == "Kick" and getgenv().HTrungAntiBan.kick then
                                logUI("🚫 Kick blocked!", Theme.AccentCyan)
                                return
                            end
                            return AB.mtOldNamecall(self, ...)
                        end)
                        setreadonly(mt, true)
                        AB.hookApplied = true
                        logUI("Hook Kick ON", Theme.AccentCyan)
                    end
                else
                    logUI("Hook không khả dụng — fallback AC kill", Theme.AccentGold)
                end
            end)
            if not AB.kickThread then
                AB.kickThread = task.spawn(function()
                    local keywords = {"anticheat","antihack","detect","ban","kick","exploit","cheat","protection","shield","monitor","sentry","guard","watch"}
                    while AB.kick do
                        task.wait(1)
                        local pg = LocalPlayer:FindFirstChild("PlayerGui")
                        if pg then
                            for _, gui in pairs(pg:GetChildren()) do
                                for _, ls in pairs(gui:GetDescendants()) do
                                    if ls:IsA("LocalScript") and not ls.Disabled then
                                        local n = string.lower(ls.Name)
                                        for _, kw in ipairs(keywords) do
                                            if string.find(n, kw, 1, true) then
                                                pcall(function() ls.Disabled = true end)
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        else
            pcall(function()
                if AB.hookApplied and AB.mtOldNamecall and getrawmetatable and setreadonly then
                    local mt = getrawmetatable(game)
                    setreadonly(mt, false)
                    mt.__namecall = AB.mtOldNamecall
                    setreadonly(mt, true)
                    AB.hookApplied = false
                end
            end)
        end
    end)

    createToggle(antiTab, "Anti-Report (Chặn ReportAbuse)", false, function(s)
        AB.report = s
        pcall(function()
            if s then
                if AB.oldReportAbuse == nil then AB.oldReportAbuse = LocalPlayer.ReportAbuse end
                LocalPlayer.ReportAbuse = function() return end
                logUI("ReportAbuse blocked", Theme.AccentCyan)
            else
                if AB.oldReportAbuse then
                    LocalPlayer.ReportAbuse = AB.oldReportAbuse
                    logUI("ReportAbuse restored", Theme.TextDim)
                end
            end
        end)
    end)

    createToggle(antiTab, "Anti-Teleport-Ban (Revert vị trí lạ)", false, function(s)
        AB.tp = s
        if s then
            AB.lastPos = nil
            if AB.tpThread then pcall(task.cancel, AB.tpThread) end
            AB.tpThread = task.spawn(function()
                while AB.tp do
                    task.wait(0.1)
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        if AB.lastPos then
                            local dist = (hrp.Position - AB.lastPos).Magnitude
                            if dist > 300 and dist < 5000 then
                                pcall(function() hrp.CFrame = CFrame.new(AB.lastPos) end)
                                logUI("Reverted abnormal TP", Theme.AccentGold)
                            end
                        end
                        AB.lastPos = hrp.Position
                    end
                end
            end)
            logUI("Teleport protection ON", Theme.AccentCyan)
        else
            if AB.tpThread then pcall(task.cancel, AB.tpThread) AB.tpThread = nil end
        end
    end)

    createToggle(antiTab, "Anti-Detect (Tắt anti-cheat scripts)", false, function(s)
        AB.detect = s
        if s then
            if AB.detectThread then pcall(task.cancel, AB.detectThread) end
            AB.detectThread = task.spawn(function()
                local keywords = {"anticheat","antihack","detector","detect","ban","exploit","cheat","protection","shield","monitor","sentry","guard","watch","secure","verify"}
                while AB.detect do
                    task.wait(1.5)
                    local pg = LocalPlayer:FindFirstChild("PlayerGui")
                    if pg then
                        for _, gui in pairs(pg:GetChildren()) do
                            for _, ls in pairs(gui:GetDescendants()) do
                                if ls:IsA("LocalScript") and not ls.Disabled then
                                    local n = string.lower(ls.Name)
                                    for _, kw in ipairs(keywords) do
                                        if string.find(n, kw, 1, true) then
                                            pcall(function() ls.Disabled = true end)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            logUI("Auto kill anti-cheat ON", Theme.AccentCyan)
        else
            if AB.detectThread then pcall(task.cancel, AB.detectThread) AB.detectThread = nil end
        end
    end)

    createToggle(antiTab, "Anti-Screenshot (Tắt CoreGui)", false, function(s)
        AB.screenshot = s
        if s then
            if AB.screenThread then pcall(task.cancel, AB.screenThread) end
            AB.screenThread = task.spawn(function()
                while AB.screenshot do
                    task.wait(1)
                    pcall(function()
                        game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.ScreenshotMode, false)
                    end)
                end
            end)
            logUI("Screenshot protection ON", Theme.AccentCyan)
        else
            if AB.screenThread then pcall(task.cancel, AB.screenThread) AB.screenThread = nil end
            pcall(function()
                game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.ScreenshotMode, true)
            end)
        end
    end)

    local killACBtn = Instance.new("TextButton")
    killACBtn.Size = UDim2.new(1, -10, 0, 45)
    killACBtn.BackgroundColor3 = Theme.AccentPink
    killACBtn.TextColor3 = Theme.Text
    killACBtn.Font = Enum.Font.GothamBlack
    killACBtn.TextSize = 14
    killACBtn.Text = "💀 KILL TẤT CẢ ANTI-CHEAT SCRIPTS"
    killACBtn.BorderSizePixel = 0
    killACBtn.ZIndex = 54
    killACBtn.Parent = antiTab
    local kac = Instance.new("UICorner") kac.CornerRadius = UDim.new(0, 8) kac.Parent = killACBtn
    local kas = Instance.new("UIStroke") kas.Color = Theme.AccentCyan kas.Thickness = 2 kas.Parent = killACBtn

    bindClick(killACBtn, function()
        killACBtn.Text = "💀 ĐANG QUÉT..."
        local count = 0
        local keywords = {"anticheat","antihack","detector","detect","ban","exploit","cheat","protection","shield","monitor","sentry","guard","watch","secure","verify","hack"}
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, gui in pairs(pg:GetChildren()) do
                for _, ls in pairs(gui:GetDescendants()) do
                    if ls:IsA("LocalScript") then
                        local n = string.lower(ls.Name)
                        for _, kw in ipairs(keywords) do
                            if string.find(n, kw, 1, true) then
                                pcall(function() ls.Disabled = true count = count + 1 end)
                                break
                            end
                        end
                    end
                end
            end
        end
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("LocalScript") then
                local n = string.lower(obj.Name)
                for _, kw in ipairs(keywords) do
                    if string.find(n, kw, 1, true) then
                        pcall(function() obj.Disabled = true count = count + 1 end)
                        break
                    end
                end
            end
        end
        killACBtn.Text = "✅ ĐÃ KILL " .. count .. " SCRIPTS"
        logUI("Killed " .. count .. " anti-cheat scripts", Theme.AccentCyan)
        task.wait(3)
        killACBtn.Text = "💀 KILL TẤT CẢ ANTI-CHEAT SCRIPTS"
    end)
end
end)

-- ==========================================
-- TAB 11: FIX LAG
-- ==========================================
getgenv().HTrungFixLag = { level = 3, applied = false, orig = nil, autoClean = false, autoThread = nil }

pcall(function()
do
    local fixTab = createTab("Fix Lag", "🚀")
    local FL = getgenv().HTrungFixLag

    local function saveOrig()
        if FL.orig then return end
        local o = {}
        o.Brightness = Lighting.Brightness
        o.ClockTime = Lighting.ClockTime
        o.GlobalShadows = Lighting.GlobalShadows
        o.FogEnd = Lighting.FogEnd
        o.FogStart = Lighting.FogStart
        o.ShadowSoftness = Lighting.ShadowSoftness
        o.EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale
        o.EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
        o.OutdoorAmbient = Lighting.OutdoorAmbient
        o.Ambient = Lighting.Ambient
        o.ExposureCompensation = Lighting.ExposureCompensation
        o.postFX = {}
        for _, obj in ipairs(Lighting:GetChildren()) do
            if obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") or obj:IsA("ColorCorrectionEffect") then
                table.insert(o.postFX, {obj=obj, en=obj.Enabled})
            end
        end
        o.particles = {}
        o.decals = {}
        o.sounds = {}
        o.accessories = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Beam") or obj:IsA("Trail") then
                table.insert(o.particles, {obj=obj, en=obj.Enabled})
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                table.insert(o.decals, {obj=obj, tr=obj.Transparency})
            elseif obj:IsA("Sound") then
                table.insert(o.sounds, {obj=obj, vol=obj.Volume})
            elseif obj:IsA("Accessory") and obj:FindFirstChild("Handle") then
                table.insert(o.accessories, {obj=obj, tr=obj.Handle.Transparency})
            end
        end
        for _, obj in ipairs(game:GetService("SoundService"):GetDescendants()) do
            if obj:IsA("Sound") then
                table.insert(o.sounds, {obj=obj, vol=obj.Volume})
            end
        end
        pcall(function()
            o.terrain = {ws=Workspace.Terrain.WaterWaveSize, wst=Workspace.Terrain.WaterWaveStrength}
        end)
        o.animTracks = {}
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                for _, obj in ipairs(char:GetDescendants()) do
                    if obj:IsA("Animator") then
                        for _, t in ipairs(obj:GetPlayingAnimationTracks()) do
                            table.insert(o.animTracks, {track=t})
                        end
                    end
                end
            end
        end)
        FL.orig = o
    end

    local function restoreAll()
        local o = FL.orig
        if not o then return end
        pcall(function()
            Lighting.Brightness = o.Brightness
            Lighting.ClockTime = o.ClockTime
            Lighting.GlobalShadows = o.GlobalShadows
            Lighting.FogEnd = o.FogEnd
            Lighting.FogStart = o.FogStart
            Lighting.ShadowSoftness = o.ShadowSoftness
            Lighting.EnvironmentDiffuseScale = o.EnvironmentDiffuseScale
            Lighting.EnvironmentSpecularScale = o.EnvironmentSpecularScale
            Lighting.OutdoorAmbient = o.OutdoorAmbient
            Lighting.Ambient = o.Ambient
            Lighting.ExposureCompensation = o.ExposureCompensation
        end)
        for _, t in ipairs(o.postFX or {}) do pcall(function() if t.obj and t.obj.Parent then t.obj.Enabled = t.en end end) end
        for _, t in ipairs(o.particles or {}) do pcall(function() if t.obj and t.obj.Parent then t.obj.Enabled = t.en end end) end
        for _, t in ipairs(o.decals or {}) do pcall(function() if t.obj and t.obj.Parent then t.obj.Transparency = t.tr end end) end
        for _, t in ipairs(o.sounds or {}) do pcall(function() if t.obj and t.obj.Parent then t.obj.Volume = t.vol end end) end
        for _, t in ipairs(o.accessories or {}) do pcall(function() if t.obj and t.obj.Parent and t.obj.Handle then t.obj.Handle.Transparency = t.tr end end) end
        pcall(function() if o.terrain then Workspace.Terrain.WaterWaveSize = o.terrain.ws Workspace.Terrain.WaterWaveStrength = o.terrain.wst end end)
        for _, t in ipairs(o.animTracks or {}) do pcall(function() t.track:AdjustSpeed(1) end) end
        FL.orig = nil
        FL.applied = false
    end

    FL.restore = restoreAll

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -10, 0, 34)
    statusLbl.BackgroundColor3 = Theme.SidebarBtn
    statusLbl.BackgroundTransparency = 0.5
    statusLbl.TextColor3 = Theme.Text
    statusLbl.Font = Enum.Font.GothamBold
    statusLbl.TextSize = 12
    statusLbl.Text = "Trạng thái: Chưa áp dụng"
    statusLbl.BorderSizePixel = 0
    statusLbl.ZIndex = 54
    statusLbl.Parent = fixTab
    local slc = Instance.new("UICorner") slc.CornerRadius = UDim.new(0, 8) slc.Parent = statusLbl

    createSlider(fixTab, "Cấp độ fix lag (1-5)", 1, 5, 3, function(v) FL.level = v end)

    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(1, -10, 0, 45)
    applyBtn.BackgroundColor3 = Theme.AccentCyan
    applyBtn.TextColor3 = Theme.Text
    applyBtn.Font = Enum.Font.GothamBlack
    applyBtn.TextSize = 14
    applyBtn.Text = "🚀 ÁP DỤNG THEO CẤP ĐỘ"
    applyBtn.BorderSizePixel = 0
    applyBtn.ZIndex = 54
    applyBtn.Parent = fixTab
    local abc2 = Instance.new("UICorner") abc2.CornerRadius = UDim.new(0, 8) abc2.Parent = applyBtn
    local abs2 = Instance.new("UIStroke") abs2.Color = Theme.AccentPurple abs2.Thickness = 2 abs2.Parent = applyBtn

    local turboBtn = Instance.new("TextButton")
    turboBtn.Size = UDim2.new(1, -10, 0, 45)
    turboBtn.BackgroundColor3 = Theme.AccentPink
    turboBtn.TextColor3 = Theme.Text
    turboBtn.Font = Enum.Font.GothamBlack
    turboBtn.TextSize = 14
    turboBtn.Text = "💀 TURBO MAX (HỦY DIỆT)"
    turboBtn.BorderSizePixel = 0
    turboBtn.ZIndex = 54
    turboBtn.Parent = fixTab
    local tbc = Instance.new("UICorner") tbc.CornerRadius = UDim.new(0, 8) tbc.Parent = turboBtn
    local tbs = Instance.new("UIStroke") tbs.Color = Theme.AccentGold tbs.Thickness = 2 tbs.Parent = turboBtn

    local restoreBtn = Instance.new("TextButton")
    restoreBtn.Size = UDim2.new(1, -10, 0, 40)
    restoreBtn.BackgroundColor3 = Theme.SidebarBtn
    restoreBtn.TextColor3 = Theme.Text
    restoreBtn.Font = Enum.Font.GothamBold
    restoreBtn.TextSize = 13
    restoreBtn.Text = "↩️ HOÀN TÁC TẤT CẢ"
    restoreBtn.BorderSizePixel = 0
    restoreBtn.ZIndex = 54
    restoreBtn.Parent = fixTab
    local rbc = Instance.new("UICorner") rbc.CornerRadius = UDim.new(0, 8) rbc.Parent = restoreBtn

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, -10, 0, 130)
    infoLbl.BackgroundColor3 = Theme.MainBG
    infoLbl.BackgroundTransparency = 0.3
    infoLbl.TextColor3 = Theme.TextDim
    infoLbl.Font = Enum.Font.Code
    infoLbl.TextSize = 11
    infoLbl.TextXAlignment = Enum.TextXAlignment.Left
    infoLbl.TextYAlignment = Enum.TextYAlignment.Top
    infoLbl.TextWrapped = true
    infoLbl.Text = [[  CẤP ĐỘ:
  1 = Yếu: shadows
  2 = TB: + particles + decals
  3 = Mạnh: + sounds + anim + postFX
  4 = Cực mạnh: + accessories + fog
  5 = Hủy diệt: + terrain + GUI + extreme]]
    infoLbl.BorderSizePixel = 0
    infoLbl.ZIndex = 54
    infoLbl.Parent = fixTab
    local ifc = Instance.new("UICorner") ifc.CornerRadius = UDim.new(0, 8) ifc.Parent = infoLbl

    local function doApply(level)
        saveOrig()
        local o = FL.orig
        if level >= 1 then
            pcall(function()
                Lighting.GlobalShadows = false
                Lighting.ShadowSoftness = 0
            end)
        end
        if level >= 2 then
            for _, t in ipairs(o.particles or {}) do pcall(function() if t.obj and t.obj.Parent then t.obj.Enabled = false end end) end
            for _, t in ipairs(o.decals or {}) do pcall(function() if t.obj and t.obj.Parent then t.obj.Transparency = 1 end end) end
        end
        if level >= 3 then
            for _, t in ipairs(o.sounds or {}) do pcall(function() if t.obj and t.obj.Parent then t.obj.Volume = 0 end end) end
            for _, t in ipairs(o.animTracks or {}) do pcall(function() t.track:AdjustSpeed(0) end) end
            for _, t in ipairs(o.postFX or {}) do pcall(function() if t.obj and t.obj.Parent then t.obj.Enabled = false end end) end
        end
        if level >= 4 then
            for _, t in ipairs(o.accessories or {}) do pcall(function() if t.obj and t.obj.Parent and t.obj.Handle then t.obj.Handle.Transparency = 1 end end) end
            pcall(function()
                Lighting.FogEnd = 9e9
                Lighting.FogStart = 9e9
            end)
        end
        if level >= 5 then
            pcall(function()
                Lighting.Brightness = 2
                Lighting.ClockTime = 12
                Lighting.EnvironmentDiffuseScale = 0
                Lighting.EnvironmentSpecularScale = 0
                Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
                Lighting.Ambient = Color3.fromRGB(150, 150, 150)
                if o.terrain then
                    Workspace.Terrain.WaterWaveSize = 0
                    Workspace.Terrain.WaterWaveStrength = 0
                end
            end)
            pcall(function()
                for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
                    for _, obj in ipairs(gui:GetDescendants()) do
                        if obj:IsA("UIGradient") then obj.Enabled = false
                        elseif obj:IsA("UIStroke") then obj.Thickness = 0
                        elseif obj:IsA("UICorner") then obj.CornerRadius = UDim.new(0, 0) end
                    end
                end
            end)
        end
        FL.applied = true
        statusLbl.Text = "✅ Đã áp dụng cấp " .. level .. " (" .. #(o.particles or {}) .. " hiệu ứng bị tắt)"
        statusLbl.TextColor3 = Theme.AccentCyan
    end

    bindClick(applyBtn, function()
        local lv = FL.level
        applyBtn.Text = "🚀 ĐANG XỬ LÝ..."
        task.spawn(function()
            doApply(lv)
            applyBtn.Text = "🚀 ÁP DỤNG THEO CẤP ĐỘ"
        end)
    end)

    bindClick(turboBtn, function()
        turboBtn.Text = "💀 ĐANG XỬ LÝ..."
        task.spawn(function()
            doApply(5)
            local count = 0
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character) then
                    local s = obj.Size
                    if s.X < 0.5 and s.Y < 0.5 and s.Z < 0.5 and obj.Transparency < 1 then
                        pcall(function() obj.Transparency = 1 count = count + 1 end)
                    end
                end
            end
            if setfpscap then pcall(function() setfpscap(60) end) end
            turboBtn.Text = "✅ ĐÃ TURBO! (" .. count .. " parts ẩn)"
            task.wait(3)
            turboBtn.Text = "💀 TURBO MAX (HỦY DIỆT)"
        end)
    end)

    bindClick(restoreBtn, function()
        restoreBtn.Text = "↩️ ĐANG KHÔI PHỤC..."
        task.spawn(function()
            restoreAll()
            statusLbl.Text = "Đã hoàn tác tất cả"
            statusLbl.TextColor3 = Theme.Text
            restoreBtn.Text = "↩️ HOÀN TÁC TẤT CẢ"
        end)
    end)

    createToggle(fixTab, "🔄 Auto clean (xóa particles/decals mới)", false, function(s)
        FL.autoClean = s
        if s then
            if FL.autoThread then pcall(task.cancel, FL.autoThread) end
            FL.autoThread = task.spawn(function()
                while FL.autoClean do
                    task.wait(0.5)
                    pcall(function()
                        for _, obj in ipairs(Workspace:GetDescendants()) do
                            if (obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Beam") or obj:IsA("Trail")) and obj.Enabled then
                                obj.Enabled = false
                            end
                            if (obj:IsA("Decal") or obj:IsA("Texture")) and obj.Transparency < 1 then
                                obj.Transparency = 1
                            end
                        end
                    end)
                end
            end)
        else
            if FL.autoThread then pcall(task.cancel, FL.autoThread) FL.autoThread = nil end
        end
    end)

    createToggle(fixTab, "🔓 Unlock FPS (240fps)", false, function(s)
        if setfpscap then pcall(function() setfpscap(s and 240 or 60) end) end
    end)
end
end)

-- ==========================================
-- TAB 12: BYPASS (OMEGA)
-- ==========================================
pcall(function()
do
    local bypassTab = createTab("Bypass", "🔓")
    local logBox = Instance.new("ScrollingFrame")
    logBox.Size = UDim2.new(1, -10, 0, 160)
    logBox.BackgroundColor3 = Theme.MainBG
    logBox.BackgroundTransparency = 0.3
    logBox.BorderSizePixel = 0
    logBox.ScrollBarThickness = 4
    logBox.ScrollBarImageColor3 = Theme.AccentPink
    logBox.ZIndex = 54
    logBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
    logBox.CanvasSize = UDim2.new(0, 0, 0, 0)
    logBox.Parent = bypassTab
    local lbc = Instance.new("UICorner") lbc.CornerRadius = UDim.new(0, 8) lbc.Parent = logBox
    local ll = Instance.new("UIListLayout") ll.Padding = UDim.new(0, 2) ll.Parent = logBox

    local function logUI(text, color)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color or Theme.TextDim
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = "> " .. text
        lbl.ZIndex = 55
        lbl.Parent = logBox
        task.defer(function() logBox.CanvasPosition = Vector2.new(0, ll.AbsoluteContentSize.Y) end)
    end

    -- 1. HOOK MARKETPLACE (DEEP)
    createToggle(bypassTab, "Bypass Gamepass (Deep Hook)", false, function(s)
        States.BypassGamepass = s
        if s then
            pcall(function()
                if not oldNamecallHook then
                    oldNamecallHook = hookmetamethod(game, "__namecall", function(self, ...)
                        local method = getnamecallmethod()
                        if not checkcaller() and States.BypassGamepass then
                            if self == MarketplaceService then
                                if method == "UserOwnsGamePassAsync" or method == "PlayerOwnsAsset" then return true end
                            end
                        end
                        return oldNamecallHook(self, ...)
                    end)
                    logUI("Hook __namecall Marketplace: ON", Theme.AccentCyan)
                end
                if not oldIndexHook then
                    oldIndexHook = hookmetamethod(game, "__index", function(self, key)
                        if not checkcaller() and States.BypassGamepass then
                            if self == MarketplaceService then
                                if key == "UserOwnsGamePassAsync" or key == "PlayerOwnsAsset" then
                                    return function() return true end
                                end
                            end
                        end
                        return oldIndexHook(self, key)
                    end)
                    logUI("Hook __index Marketplace: ON", Theme.AccentCyan)
                end
            end)
        else
            logUI("Đã tắt Hook (Cần Rejoin để reset hoàn toàn)", Theme.AccentGold)
        end
    end)

    -- 2. SPAM REMOTES (ĐA DẠNG THAM SỐ)
    local bruteBtn = Instance.new("TextButton")
    bruteBtn.Size = UDim2.new(1, -10, 0, 40)
    bruteBtn.BackgroundColor3 = Theme.AccentPurple
    bruteBtn.TextColor3 = Theme.Text
    bruteBtn.Font = Enum.Font.GothamBold
    bruteBtn.TextSize = 13
    bruteBtn.Text = "🔨 SPAM REMOTES (BYPASS SERVER)"
    bruteBtn.BorderSizePixel = 0
    bruteBtn.ZIndex = 54
    bruteBtn.Parent = bypassTab
    local bbc = Instance.new("UICorner") bbc.CornerRadius = UDim.new(0, 8) bbc.Parent = bruteBtn

    bindClick(bruteBtn, function()
        bruteBtn.Text = "ĐANG SPAM..."
        logUI("Spam mua Gamepass với nhiều tham số...", Theme.AccentGold)
        task.spawn(function()
            local fired = 0
            local argsList = {{}, {0}, {1}, {true}, {LocalPlayer}, {LocalPlayer.UserId}}
            for _, remote in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
                if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                    local n = string.lower(remote.Name)
                    if string.find(n, "buy") or string.find(n, "purchase") or string.find(n, "gamepass") or string.find(n, "product") then
                        for _, args in ipairs(argsList) do
                            pcall(function()
                                if remote:IsA("RemoteEvent") then remote:FireServer(table.unpack(args))
                                else remote:InvokeServer(table.unpack(args)) end
                            end)
                            fired = fired + 1
                        end
                    end
                end
            end
            logUI("Đã bắn " .. fired .. " lệnh mua với đa tham số.", Theme.AccentCyan)
            bruteBtn.Text = "🔨 SPAM REMOTES (BYPASS SERVER)"
        end)
    end)

    -- 3. FORCE UNLOCK UI (LOOP)
    createToggle(bypassTab, "Force Unlock UI (Loop liên tục)", false, function(s)
        if s then
            if bypassLoop then pcall(task.cancel, bypassLoop) end
            bypassLoop = task.spawn(function()
                while true do
                    task.wait(1)
                    local count = 0
                    local pg = LocalPlayer:FindFirstChild("PlayerGui")
                    if pg then
                        for _, obj in ipairs(pg:GetDescendants()) do
                            if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                                local t = ""
                                pcall(function() t = string.lower(obj.Text) end)
                                if string.find(t, "mua") or string.find(t, "buy") or string.find(t, "khóa") or string.find(t, "locked") then
                                    pcall(function()
                                        obj.Visible = true
                                        obj.Active = true
                                        for _, child in ipairs(obj:GetChildren()) do
                                            if child:IsA("LocalScript") then child.Disabled = true end
                                        end
                                        count = count + 1
                                    end)
                                end
                            end
                        end
                    end
                end
            end)
            logUI("Bật Force Unlock UI (Loop).", Theme.AccentCyan)
        else
            if bypassLoop then pcall(task.cancel, bypassLoop) bypassLoop = nil end
            logUI("Tắt Force Unlock UI.", Theme.TextDim)
        end
    end)

    -- 4. SPOOF VALUES
    local spoofValBtn = Instance.new("TextButton")
    spoofValBtn.Size = UDim2.new(1, -10, 0, 40)
    spoofValBtn.BackgroundColor3 = Theme.AccentCyan
    spoofValBtn.TextColor3 = Theme.Text
    spoofValBtn.Font = Enum.Font.GothamBold
    spoofValBtn.TextSize = 13
    spoofValBtn.Text = "🔓 SPOOF VALUES (Ép Gamepass = True)"
    spoofValBtn.BorderSizePixel = 0
    spoofValBtn.ZIndex = 54
    spoofValBtn.Parent = bypassTab
    local svc = Instance.new("UICorner") svc.CornerRadius = UDim.new(0, 8) svc.Parent = spoofValBtn

    bindClick(spoofValBtn, function()
        spoofValBtn.Text = "ĐANG SPOOF..."
        local count = 0
        local valKeywords = {"gamepass", "pass", "premium", "vip", "product", "owned", "unlock"}
        for _, obj in ipairs(LocalPlayer:GetDescendants()) do
            if obj:IsA("BoolValue") or obj:IsA("IntValue") then
                local n = string.lower(obj.Name)
                for _, kw in ipairs(valKeywords) do
                    if string.find(n, kw, 1, true) then
                        pcall(function()
                            if obj:IsA("BoolValue") then obj.Value = true
                            else obj.Value = 1 end
                            count = count + 1
                        end)
                        break
                    end
                end
            end
        end
        logUI("Đã Spoof " .. count .. " Values.", Theme.AccentCyan)
        spoofValBtn.Text = "🔓 SPOOF VALUES (Ép Gamepass = True)"
    end)

    -- 5. AUTO OPEN DOORS
    local openDoorsBtn = Instance.new("TextButton")
    openDoorsBtn.Size = UDim2.new(1, -10, 0, 40)
    openDoorsBtn.BackgroundColor3 = Theme.AccentGold
    openDoorsBtn.TextColor3 = Theme.MainBG
    openDoorsBtn.Font = Enum.Font.GothamBold
    openDoorsBtn.TextSize = 13
    openDoorsBtn.Text = "🚪 AUTO OPEN DOORS (Mở khóa cửa)"
    openDoorsBtn.BorderSizePixel = 0
    openDoorsBtn.ZIndex = 54
    openDoorsBtn.Parent = bypassTab
    local odc = Instance.new("UICorner") odc.CornerRadius = UDim.new(0, 8) odc.Parent = openDoorsBtn

    bindClick(openDoorsBtn, function()
        openDoorsBtn.Text = "ĐANG MỞ CỬA..."
        local count = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector") then
                pcall(function()
                    obj.Enabled = true
                    obj.MaxActivationDistance = math.huge
                    if obj:IsA("ProximityPrompt") then
                        obj.HoldDuration = 0
                        if fireproximityprompt then fireproximityprompt(obj) end
                    else
                        if fireclickdetector then fireclickdetector(obj) end
                    end
                    count = count + 1
                end)
            end
        end
        logUI("Đã kích hoạt " .. count .. " Cửa/Nút.", Theme.AccentCyan)
        openDoorsBtn.Text = "🚪 AUTO OPEN DOORS (Mở khóa cửa)"
    end)

    -- 6. BYPASS PLAYTIME REWARDS
    local playtimeBypassBtn = Instance.new("TextButton")
    playtimeBypassBtn.Size = UDim2.new(1, -10, 0, 40)
    playtimeBypassBtn.BackgroundColor3 = Theme.AccentCyan
    playtimeBypassBtn.TextColor3 = Theme.Text
    playtimeBypassBtn.Font = Enum.Font.GothamBold
    playtimeBypassBtn.TextSize = 13
    playtimeBypassBtn.Text = "⏱️ BYPASS THỜI GIAN CHƠI (PLAYTIME)"
    playtimeBypassBtn.BorderSizePixel = 0
    playtimeBypassBtn.ZIndex = 54
    playtimeBypassBtn.Parent = bypassTab
    local pbc = Instance.new("UICorner") pbc.CornerRadius = UDim.new(0, 8) pbc.Parent = playtimeBypassBtn

    bindClick(playtimeBypassBtn, function()
        playtimeBypassBtn.Text = "ĐANG BYPASS..."
        task.spawn(function()
            local function forceTimeZero()
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("StringValue") then
                        local n = string.lower(obj.Name)
                        if string.find(n, "time") or string.find(n, "cooldown") or string.find(n, "playtime") then
                            pcall(function()
                                if obj:IsA("StringValue") then obj.Value = "00:00"
                                else obj.Value = 0 end
                            end)
                        end
                    end
                end
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                if pg then
                    for _, obj in ipairs(pg:GetDescendants()) do
                        if obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("StringValue") then
                            local n = string.lower(obj.Name)
                            if string.find(n, "time") or string.find(n, "cooldown") or string.find(n, "playtime") then
                                pcall(function()
                                    if obj:IsA("StringValue") then obj.Value = "00:00"
                                    else obj.Value = 0 end
                                end)
                            end
                        end
                    end
                end
            end
            forceTimeZero()

            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                for _, gui in ipairs(pg:GetChildren()) do
                    local isPlaytimeUI = false
                    for _, txt in ipairs(gui:GetDescendants()) do
                        if txt:IsA("TextLabel") and (string.find(string.lower(txt.Text), "thời gian chơi") or string.find(string.lower(txt.Text), "playtime")) then
                            isPlaytimeUI = true break
                        end
                    end

                    if isPlaytimeUI then
                        logUI("Tìm thấy UI Thời Gian Chơi!", Theme.AccentCyan)
                        for _, script in ipairs(gui:GetDescendants()) do
                            if script:IsA("LocalScript") then pcall(function() script.Disabled = true end) end
                        end
                        for _, btn in ipairs(gui:GetDescendants()) do
                            if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                                pcall(function()
                                    btn.Visible = true
                                    btn.Active = true
                                    if string.find(string.lower(btn.Text), "nhận tất cả") then
                                        btn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
                                    end
                                    if firesignal then firesignal(btn.MouseButton1Click) end
                                    btn:Activate()
                                end)
                            end
                        end
                    end
                end
            end

            local kws = {"playtime", "time", "reward", "claim", "nhanthuong", "claimall"}
            for _, remote in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
                if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                    local n = string.lower(remote.Name)
                    local match = false
                    for _, k in ipairs(kws) do if string.find(n, k, 1, true) then match = true break end end
                    if match then
                        pcall(function()
                            if remote:IsA("RemoteEvent") then
                                remote:FireServer() remote:FireServer(1) remote:FireServer(0) remote:FireServer("all")
                            else
                                remote:InvokeServer() remote:InvokeServer(1) remote:InvokeServer("all")
                            end
                        end)
                    end
                end
            end
            
            logUI("Đã Bypass Thời Gian Chơi!", Theme.AccentCyan)
            playtimeBypassBtn.Text = "✅ ĐÃ BYPASS THỜI GIAN CHƠI"
            task.wait(3)
            playtimeBypassBtn.Text = "⏱️ BYPASS THỜI GIAN CHƠI (PLAYTIME)"
        end)
    end)

    -- BYPASS ALL BUTTON
    local bypassAllBtn = Instance.new("TextButton")
    bypassAllBtn.Size = UDim2.new(1, -10, 0, 45)
    bypassAllBtn.BackgroundColor3 = Theme.AccentPink
    bypassAllBtn.TextColor3 = Theme.Text
    bypassAllBtn.Font = Enum.Font.GothamBlack
    bypassAllBtn.TextSize = 14
    bypassAllBtn.Text = "⚡ BYPASS TẤT CẢ (OMEGA)"
    bypassAllBtn.BorderSizePixel = 0
    bypassAllBtn.ZIndex = 54
    bypassAllBtn.Parent = bypassTab
    local bac = Instance.new("UICorner") bac.CornerRadius = UDim.new(0, 8) bac.Parent = bypassAllBtn

    bindClick(bypassAllBtn, function()
        bypassAllBtn.Text = "ĐANG BYPASS..."
        
        pcall(function()
            if not oldNamecallHook then
                oldNamecallHook = hookmetamethod(game, "__namecall", function(self, ...)
                    local method = getnamecallmethod()
                    if not checkcaller() and States.BypassGamepass then
                        if self == MarketplaceService then
                            if method == "UserOwnsGamePassAsync" or method == "PlayerOwnsAsset" then return true end
                        end
                    end
                    return oldNamecallHook(self, ...)
                end)
            end
            if not oldIndexHook then
                oldIndexHook = hookmetamethod(game, "__index", function(self, key)
                    if not checkcaller() and States.BypassGamepass then
                        if self == MarketplaceService then
                            if key == "UserOwnsGamePassAsync" or key == "PlayerOwnsAsset" then
                                return function() return true end
                            end
                        end
                    end
                    return oldIndexHook(self, key)
                end)
            end
        end)

        local fired = 0
        local argsList = {{}, {0}, {1}, {true}, {LocalPlayer}, {LocalPlayer.UserId}}
        for _, remote in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                local n = string.lower(remote.Name)
                if string.find(n, "buy") or string.find(n, "purchase") or string.find(n, "gamepass") then
                    for _, args in ipairs(argsList) do
                        pcall(function()
                            if remote:IsA("RemoteEvent") then remote:FireServer(table.unpack(args))
                            else remote:InvokeServer(table.unpack(args)) end
                        end)
                        fired = fired + 1
                    end
                end
            end
        end

        local countVal = 0
        local valKeywords = {"gamepass", "pass", "premium", "vip", "product", "owned", "unlock"}
        for _, obj in ipairs(LocalPlayer:GetDescendants()) do
            if obj:IsA("BoolValue") or obj:IsA("IntValue") then
                local n = string.lower(obj.Name)
                for _, kw in ipairs(valKeywords) do
                    if string.find(n, kw, 1, true) then
                        pcall(function()
                            if obj:IsA("BoolValue") then obj.Value = true else obj.Value = 1 end
                            countVal = countVal + 1
                        end)
                        break
                    end
                end
            end
        end

        local countUI = 0
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, obj in ipairs(pg:GetDescendants()) do
                if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                    local t = "" pcall(function() t = string.lower(obj.Text) end)
                    if string.find(t, "mua") or string.find(t, "buy") or string.find(t, "khóa") or string.find(t, "locked") then
                        pcall(function()
                            obj.Visible = true obj.Active = true
                            for _, child in ipairs(obj:GetChildren()) do
                                if child:IsA("LocalScript") then child.Disabled = true end
                            end
                            countUI = countUI + 1
                        end)
                    end
                end
            end
        end

        local countDoor = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector") then
                pcall(function()
                    obj.Enabled = true obj.MaxActivationDistance = math.huge
                    if obj:IsA("ProximityPrompt") then
                        obj.HoldDuration = 0
                        if fireproximityprompt then fireproximityprompt(obj) end
                    else
                        if fireclickdetector then fireclickdetector(obj) end
                    end
                    countDoor = countDoor + 1
                end)
            end
        end

        local function forceTimeZero()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("StringValue") then
                    local n = string.lower(obj.Name)
                    if string.find(n, "time") or string.find(n, "cooldown") or string.find(n, "playtime") then
                        pcall(function()
                            if obj:IsA("StringValue") then obj.Value = "00:00"
                            else obj.Value = 0 end
                        end)
                    end
                end
            end
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                for _, obj in ipairs(pg:GetDescendants()) do
                    if obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("StringValue") then
                        local n = string.lower(obj.Name)
                        if string.find(n, "time") or string.find(n, "cooldown") or string.find(n, "playtime") then
                            pcall(function()
                                if obj:IsA("StringValue") then obj.Value = "00:00"
                                else obj.Value = 0 end
                            end)
                        end
                    end
                end
            end
        end
        forceTimeZero()

        if pg then
            for _, gui in ipairs(pg:GetChildren()) do
                local isPlaytimeUI = false
                for _, txt in ipairs(gui:GetDescendants()) do
                    if txt:IsA("TextLabel") and (string.find(string.lower(txt.Text), "thời gian chơi") or string.find(string.lower(txt.Text), "playtime")) then
                        isPlaytimeUI = true break
                    end
                end
                if isPlaytimeUI then
                    for _, script in ipairs(gui:GetDescendants()) do
                        if script:IsA("LocalScript") then pcall(function() script.Disabled = true end) end
                    end
                    for _, btn in ipairs(gui:GetDescendants()) do
                        if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                            pcall(function()
                                btn.Visible = true btn.Active = true
                                if string.find(string.lower(btn.Text), "nhận tất cả") then
                                    btn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
                                end
                                if firesignal then firesignal(btn.MouseButton1Click) end
                                btn:Activate()
                            end)
                        end
                    end
                end
            end
        end
        local kws = {"playtime", "time", "reward", "claim", "nhanthuong", "claimall"}
        for _, remote in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                local n = string.lower(remote.Name)
                local match = false
                for _, k in ipairs(kws) do if string.find(n, k, 1, true) then match = true break end end
                if match then
                    pcall(function()
                        if remote:IsA("RemoteEvent") then
                            remote:FireServer() remote:FireServer(1) remote:FireServer(0) remote:FireServer("all")
                        else
                            remote:InvokeServer() remote:InvokeServer(1) remote:InvokeServer("all")
                        end
                    end)
                end
            end
        end

        logUI("Đã spam " .. fired .. " Remotes, Spoof " .. countVal .. " Values, Mở " .. countUI .. " UI, Mở " .. countDoor .. " Cửa, Bypass Playtime.", Theme.AccentCyan)

        bypassAllBtn.Text = "✅ ĐÃ BYPASS XONG (CHECK GAME)"
        task.wait(3)
        bypassAllBtn.Text = "⚡ BYPASS TẤT CẢ (OMEGA)"
    end)
end
end)

-- ==========================================
-- TAB 13: SETTINGS (UPGRADED)
-- ==========================================
pcall(function()
do
    local settingsTab = createTab("Cài Đặt", "🛠️")

    -- 1. UI Keybinds Info
    local keybindTitle = Instance.new("TextLabel")
    keybindTitle.Size = UDim2.new(1, -10, 0, 25)
    keybindTitle.BackgroundTransparency = 1
    keybindTitle.TextColor3 = Theme.AccentGold
    keybindTitle.Font = Enum.Font.GothamBold
    keybindTitle.TextSize = 14
    keybindTitle.TextXAlignment = Enum.TextXAlignment.Left
    keybindTitle.Text = "Phím Tắt & Tiện Ích"
    keybindTitle.ZIndex = 54
    keybindTitle.Parent = settingsTab

    local keybindFrame = Instance.new("Frame")
    keybindFrame.Size = UDim2.new(1, -10, 0, 65)
    keybindFrame.BackgroundColor3 = Theme.SidebarBtn
    keybindFrame.BackgroundTransparency = 0.5
    keybindFrame.BorderSizePixel = 0
    keybindFrame.ZIndex = 54
    keybindFrame.Parent = settingsTab
    local kfc = Instance.new("UICorner") kfc.CornerRadius = UDim.new(0, 8) kfc.Parent = keybindFrame

    local keybindLbl = Instance.new("TextLabel")
    keybindLbl.Size = UDim2.new(1, -10, 1, 0)
    keybindLbl.Position = UDim2.new(0, 10, 0, 0)
    keybindLbl.BackgroundTransparency = 1
    keybindLbl.TextColor3 = Theme.Text
    keybindLbl.Font = Enum.Font.GothamBold
    keybindLbl.TextSize = 12
    keybindLbl.TextXAlignment = Enum.TextXAlignment.Left
    keybindLbl.Text = "[RightShift] Ẩn/Hiện Menu\n[RightCtrl] Ẩn/Hiện Icon Avatar\n[RightAlt] Reset Vị Trí & Kích Thước Menu"
    keybindLbl.ZIndex = 55
    keybindLbl.Parent = keybindFrame

    -- 2. UI Transparency
    local transTitle = Instance.new("TextLabel")
    transTitle.Size = UDim2.new(1, -10, 0, 25)
    transTitle.BackgroundTransparency = 1
    transTitle.TextColor3 = Theme.AccentGold
    transTitle.Font = Enum.Font.GothamBold
    transTitle.TextSize = 14
    transTitle.TextXAlignment = Enum.TextXAlignment.Left
    transTitle.Text = "Độ Trong Suốt Của Menu"
    transTitle.ZIndex = 54
    transTitle.Parent = settingsTab

    createSlider(settingsTab, "Độ mờ (0 = đặc, 0.9 = trong)", 0, 0.9, 0.15, function(v)
        menu.BackgroundTransparency = v
        bgOverlay.BackgroundTransparency = math.min(v + 0.15, 0.95)
        titleFrame.BackgroundTransparency = math.min(v + 0.15, 0.95)
    end)

    -- 3. Color Section
    local colorTitle = Instance.new("TextLabel")
    colorTitle.Size = UDim2.new(1, -10, 0, 25)
    colorTitle.BackgroundTransparency = 1
    colorTitle.TextColor3 = Theme.AccentGold
    colorTitle.Font = Enum.Font.GothamBold
    colorTitle.TextSize = 14
    colorTitle.TextXAlignment = Enum.TextXAlignment.Left
    colorTitle.Text = "Đổi Màu Chủ Đạo"
    colorTitle.ZIndex = 54
    colorTitle.Parent = settingsTab

    local colorFrame = Instance.new("Frame")
    colorFrame.Size = UDim2.new(1, -10, 0, 45)
    colorFrame.BackgroundColor3 = Theme.SidebarBtn
    colorFrame.BackgroundTransparency = 0.5
    colorFrame.BorderSizePixel = 0
    colorFrame.ZIndex = 54
    colorFrame.Parent = settingsTab
    local cfc = Instance.new("UICorner") cfc.CornerRadius = UDim.new(0, 8) cfc.Parent = colorFrame
    local cfl = Instance.new("UIListLayout")
    cfl.FillDirection = Enum.FillDirection.Horizontal
    cfl.HorizontalAlignment = Enum.HorizontalAlignment.Center
    cfl.VerticalAlignment = Enum.VerticalAlignment.Center
    cfl.Padding = UDim.new(0, 10)
    cfl.Parent = colorFrame

    local function createColorBtn(color)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 25, 0, 25) btn.BackgroundColor3 = color btn.Text = ""
        btn.BorderSizePixel = 0 btn.ZIndex = 55 btn.Parent = colorFrame
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = btn
        bindClick(btn, function()
            Theme.AccentPink = color Theme.SidebarBtnActive = color
            Theme.AccentPurple = Color3.new(color.R * 0.7, color.G * 0.7, color.B * 0.7)
            ms.Color = color openBtnStroke.Color = color
            if ColorableElements.ActiveTabBtn then ColorableElements.ActiveTabBtn.BackgroundColor3 = color end
            for _, data in ipairs(ColorableElements.Toggles) do if data.State then data.Button.BackgroundColor3 = color end end
        end)
    end
    createColorBtn(Color3.fromRGB(255, 105, 180))
    createColorBtn(Color3.fromRGB(255, 182, 193))
    createColorBtn(Color3.fromRGB(0, 150, 255))
    createColorBtn(Color3.fromRGB(50, 255, 100))
    createColorBtn(Color3.fromRGB(255, 150, 0))
    createColorBtn(Color3.fromRGB(150, 50, 255))

    -- 4. Background Section
    local bgTitle = Instance.new("TextLabel")
    bgTitle.Size = UDim2.new(1, -10, 0, 25)
    bgTitle.BackgroundTransparency = 1
    bgTitle.TextColor3 = Theme.AccentGold
    bgTitle.Font = Enum.Font.GothamBold
    bgTitle.TextSize = 14
    bgTitle.TextXAlignment = Enum.TextXAlignment.Left
    bgTitle.Text = "Đổi Hình Nền (Nhập ID ảnh)"
    bgTitle.ZIndex = 54
    bgTitle.Parent = settingsTab

    local bgInputFrame = Instance.new("Frame")
    bgInputFrame.Size = UDim2.new(1, -10, 0, 45)
    bgInputFrame.BackgroundColor3 = Theme.SidebarBtn
    bgInputFrame.BackgroundTransparency = 0.5
    bgInputFrame.BorderSizePixel = 0
    bgInputFrame.ZIndex = 54
    bgInputFrame.Parent = settingsTab
    local bifc = Instance.new("UICorner") bifc.CornerRadius = UDim.new(0, 8) bifc.Parent = bgInputFrame
    local bifp = Instance.new("UIPadding")
    bifp.PaddingTop = UDim.new(0, 8)
    bifp.PaddingBottom = UDim.new(0, 8)
    bifp.PaddingLeft = UDim.new(0, 8)
    bifp.PaddingRight = UDim.new(0, 8)
    bifp.Parent = bgInputFrame

    local bgInput = Instance.new("TextBox")
    bgInput.Size = UDim2.new(1, -80, 1, 0) bgInput.Position = UDim2.new(0, 0, 0, 0)
    bgInput.BackgroundColor3 = Theme.MainBG bgInput.TextColor3 = Theme.Text
    bgInput.PlaceholderText = "Nhập ID ảnh (VD: 13476434849)" bgInput.PlaceholderColor3 = Theme.TextDim
    bgInput.Text = "13476434849" bgInput.TextSize = 13 bgInput.Font = Enum.Font.GothamBold
    bgInput.BorderSizePixel = 0 bgInput.ClearTextOnFocus = false bgInput.ZIndex = 55 bgInput.Parent = bgInputFrame
    local bic = Instance.new("UICorner") bic.CornerRadius = UDim.new(0, 6) bic.Parent = bgInput

    local applyBgBtn = Instance.new("TextButton")
    applyBgBtn.Size = UDim2.new(0, 70, 1, 0) applyBgBtn.Position = UDim2.new(1, -70, 0, 0)
    applyBgBtn.BackgroundColor3 = Theme.AccentPink applyBgBtn.TextColor3 = Theme.Text
    applyBgBtn.Font = Enum.Font.GothamBold applyBgBtn.TextSize = 13 applyBgBtn.Text = "Áp Dụng"
    applyBgBtn.BorderSizePixel = 0 applyBgBtn.ZIndex = 55 applyBgBtn.Parent = bgInputFrame
    local abc = Instance.new("UICorner") abc.CornerRadius = UDim.new(0, 6) abc.Parent = applyBgBtn
    bindClick(applyBgBtn, function()
        local id = bgInput.Text
        if id ~= "" then id = string.gsub(id, "rbxassetid://", "") bgImage.Image = "rbxassetid://" .. id end
    end)

    -- 5. Reset Button
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1, -10, 0, 40)
    resetBtn.BackgroundColor3 = Theme.AccentPink
    resetBtn.TextColor3 = Theme.Text
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 13
    resetBtn.Text = "🔄 RESET VỊ TRÍ & KÍCH THƯỚC MENU"
    resetBtn.BorderSizePixel = 0
    resetBtn.ZIndex = 54
    resetBtn.Parent = settingsTab
    local rbc = Instance.new("UICorner") rbc.CornerRadius = UDim.new(0, 8) rbc.Parent = resetBtn

    bindClick(resetBtn, function()
        menu.Position = UDim2.new(0.5, 0, 0.5, 0)
        menuScale = 1
        TweenService:Create(uiScale, TweenInfo.new(0.3), {Scale = 1}):Play()
    end)

    local firstTab = sidebar:GetChildren()[1]
    if firstTab and firstTab:IsA("TextButton") then
        firstTab.BackgroundTransparency = 0.1 firstTab.TextColor3 = Theme.Text
        firstTab:FindFirstChild("UIStroke").Thickness = 1
        firstTab:FindFirstChild("UIStroke").Color = Theme.AccentCyan
        infoTab.Visible = true ColorableElements.ActiveTabBtn = firstTab
    end
end
end)

-- ==========================================
-- LOGIC UPDATES & HEARTBEAT
-- ==========================================
local lastFpsUpdate = tick() local frameCount = 0
table.insert(Connections, RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    if tick() - lastFpsUpdate >= 1 then
        currentFps = frameCount frameCount = 0 lastFpsUpdate = tick()
        fpsLabel.Text = "FPS: " .. currentFps
    end
end))

task.spawn(function()
    while task.wait(1) do
        pcall(function() currentPing = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        pingLabel.Text = "Ping: " .. currentPing .. " ms"
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = char.HumanoidRootPart.Position
            posLabel.Text = string.format("Pos: %d, %d, %d", pos.X, pos.Y, pos.Z)
        end
        timeLbl.Text = "Giờ: " .. os.date("%H:%M:%S")
        local playSecs = math.floor(tick() - joinTime)
        playtimeLbl.Text = string.format("Đã chơi: %02d:%02d:%02d", math.floor(playSecs/3600), math.floor((playSecs%3600)/60), playSecs%60)
    end
end)

table.insert(Connections, RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    if States.AntiFling and hrp.Velocity.Magnitude > 50 then hrp.Velocity = Vector3.new(0, hrp.Velocity.Y, 0) end
    if States.Glide and hum:GetState() == Enum.HumanoidStateType.Freefall and hrp.Velocity.Y < -15 then hrp.Velocity = Vector3.new(hrp.Velocity.X, -15, hrp.Velocity.Z) end
    if States.AntiVoid and hrp.Position.Y < -50 then hrp.CFrame = CFrame.new(0, 50, 0) end
    if States.XRay then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj:IsDescendantOf(char) then obj.LocalTransparencyModifier = 0.5 end
        end
    end
    if States.ItemESP then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if (obj:IsA("BasePart") or obj:IsA("Model")) and not obj:IsDescendantOf(char) then
                local n = string.lower(obj.Name)
                if string.find(n, "coin") or string.find(n, "cash") or string.find(n, "gem") or string.find(n, "xu") then
                    if not obj:FindFirstChild("LermItemESP") then
                        local h = Instance.new("Highlight") h.Name = "LermItemESP" h.FillColor = Theme.AccentPink h.OutlineColor = Theme.Text h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop h.Parent = obj
                        table.insert(ESPObjects, h)
                    end
                end
            end
        end
    end
    if States.Noclip then
        for _, p in pairs(char:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end
    end
    if not States.FreeCam then
        local targetSpeed = States.Speed * States.GameSpeed
        local targetJump = States.JumpPower * States.GameSpeed
        if targetSpeed > 5000 then targetSpeed = 5000 end
        if targetJump > 5000 then targetJump = 5000 end
        if hum.WalkSpeed ~= targetSpeed then hum.WalkSpeed = targetSpeed end
        if hum.JumpPower ~= targetJump then hum.JumpPower = targetJump end
    end
    if States.Fly then
        local bv = hrp:FindFirstChild("LermMaxFlyVel") local bg = hrp:FindFirstChild("LermMaxFlyGyro")
        if not bv then
            hum.PlatformStand = true
            bv = Instance.new("BodyVelocity") bv.Name = "LermMaxFlyVel" bv.MaxForce = Vector3.new(1e9, 1e9, 1e9) bv.Velocity = Vector3.zero bv.Parent = hrp
            bg = Instance.new("BodyGyro") bg.Name = "LermMaxFlyGyro" bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9) bg.P = 10000 bg.D = 500 bg.CFrame = hrp.CFrame bg.Parent = hrp
        end
        if bv and bg then
            local dir = Vector3.zero
            if hum.MoveDirection.Magnitude > 0 then dir = hum.MoveDirection end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or States.FlyUp then dir += Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or States.FlyDown then dir -= Vector3.new(0, 1, 0) end
            local flySpd = States.FlySpeed * States.GameSpeed
            if flySpd > 5000 then flySpd = 5000 end
            bv.Velocity = dir.Magnitude > 0 and dir.Unit * flySpd or Vector3.zero
            bg.CFrame = CFrame.new(hrp.Position, hrp.Position + Camera.CFrame.LookVector)
        end
    else
        local bv = hrp:FindFirstChild("LermMaxFlyVel") if bv then bv:Destroy() end
        local bg = hrp:FindFirstChild("LermMaxFlyGyro") if bg then bg:Destroy() end
        if hum.PlatformStand then hum.PlatformStand = false end
    end
    if States.ESP then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                if not plr.Character.HumanoidRootPart:FindFirstChild("LermMaxESP") then
                    local h = Instance.new("Highlight") h.Name = "LermMaxESP" h.FillColor = Theme.AccentPink h.OutlineColor = Theme.Text h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop h.Parent = plr.Character
                    table.insert(ESPObjects, h)
                end
            end
        end
    end
    if States.Hitbox then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                plr.Character.HumanoidRootPart.Size = Vector3.new(States.HitboxSize, States.HitboxSize, States.HitboxSize)
                plr.Character.HumanoidRootPart.Transparency = 0.7
                plr.Character.HumanoidRootPart.BrickColor = BrickColor.new("Really red")
                plr.Character.HumanoidRootPart.Material = Enum.Material.Neon
            end
        end
    else
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                if plr.Character.HumanoidRootPart.Size ~= Vector3.new(2, 2, 1) then
                    plr.Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1)
                    plr.Character.HumanoidRootPart.Transparency = 1
                    plr.Character.HumanoidRootPart.Material = Enum.Material.Plastic
                end
            end
        end
    end

    if States.KillAura then
        local currentTime = tick()
        if currentTime - lastAuraAttack > 0.1 then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                local closestTarget = nil
                local shortestDist = States.AuraRange
                for _, plr in pairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character then
                        local targetHum = plr.Character:FindFirstChildOfClass("Humanoid")
                        local targetHrp = plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Head")
                        if targetHum and targetHrp and targetHum.Health > 0 then
                            local dist = (hrp.Position - targetHrp.Position).Magnitude
                            if dist < shortestDist then
                                shortestDist = dist
                                closestTarget = targetHrp
                            end
                        end
                    end
                end

                if closestTarget then
                    local oldCamCFrame = Camera.CFrame
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, closestTarget.Position)
                    hrp.CFrame = CFrame.lookAt(hrp.Position, closestTarget.Position)
                    
                    tool:Activate()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton1(Vector2.new(500, 500))
                    
                    task.delay(0.1, function()
                        if Camera then Camera.CFrame = oldCamCFrame end
                    end)
                    
                    lastAuraAttack = currentTime
                end
            end
        end
    end

    if States.Dodge then
        local currentTime = tick()
        if currentTime - lastDodgeTime > 0.8 then
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local targetHrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    local targetHum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if targetHrp and targetHum and targetHum.Health > 0 then
                        local dist = (hrp.Position - targetHrp.Position).Magnitude
                        if dist < 15 then
                            local behindPos = targetHrp.CFrame * CFrame.new(0, 0, 3)
                            local rayParams = RaycastParams.new()
                            rayParams.FilterDescendantsInstances = {char, plr.Character}
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            local ray = workspace:Raycast(hrp.Position, (behindPos.Position - hrp.Position), rayParams)
                            
                            if not ray then
                                hrp.CFrame = behindPos
                                lastDodgeTime = currentTime
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    if States.Aimbot and not States.FreeCam and not States.KillAura then
        local closestPlr = nil local shortestDist = math.huge
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
                local dist = (plr.Character.Head.Position - Camera.CFrame.Position).Magnitude
                if dist < shortestDist then shortestDist = dist closestPlr = plr.Character.Head end
            end
        end
        if closestPlr then Camera.CFrame = CFrame.new(Camera.CFrame.Position, closestPlr.Position) end
    end
    if States.AutoJump and not States.FreeCam then
        if hum:GetState() ~= Enum.HumanoidStateType.Jumping and hum:GetState() ~= Enum.HumanoidStateType.Freefall then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
    if States.AutoRun and not States.Fly and not States.FreeCam then
        local flatLook = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
        if flatLook.Magnitude > 0 then hum:Move(flatLook.Unit, true) hum:MoveTo(hrp.Position + flatLook.Unit * 10) end
    end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function(dt)
    if States.FreeCam then
        freeCamCFrame = CFrame.new(freeCamCFrame.Position) * CFrame.Angles(0, freeCamRotX, 0) * CFrame.Angles(freeCamRotY, 0, 0)
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) or freeCamInput.F then moveDir += Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) or freeCamInput.B then moveDir += Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or freeCamInput.L then moveDir += Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or freeCamInput.R then moveDir += Vector3.new(1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or freeCamInput.U then moveDir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or freeCamInput.D then moveDir += Vector3.new(0, -1, 0) end
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
            local finalMove = (freeCamCFrame.RightVector * moveDir.X) + (Vector3.new(0,1,0) * moveDir.Y) + (freeCamCFrame.LookVector * -moveDir.Z)
            freeCamCFrame = freeCamCFrame + (finalMove * States.FreeCamSpeed * States.GameSpeed * dt)
        end
        Camera.CFrame = freeCamCFrame
    else
        freeCamCFrame = Camera.CFrame
    end
end))

table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
    if not States.FreeCam then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Delta
        if delta.Magnitude > 0 then
            freeCamRotX = freeCamRotX - math.rad(delta.X * 0.5)
            freeCamRotY = math.clamp(freeCamRotY - math.rad(delta.Y * 0.5), math.rad(-89), math.rad(89))
        end
    end
end))

table.insert(Connections, UserInputService.JumpRequest:Connect(function()
    if States.InfJump and not States.FreeCam then
        local char = LocalPlayer.Character
        if char then local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end
    end
end))

table.insert(Connections, LocalPlayer.Idled:Connect(function()
    if States.AntiAFK then VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end
end))

table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if States.Fly then States.Fly = false States.FlyUp = false States.FlyDown = false flyOverlay.Visible = false end
    if States.FreeCam then States.FreeCam = false fcOverlay.Visible = false Camera.CameraType = Enum.CameraType.Custom end
    if States.UnlockFPS and setfpscap then pcall(function() setfpscap(60) end) end
end))

-- LẮNG NGHE PHÍM TẮT (RightShift, RightCtrl, RightAlt)
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if menu.Visible then closeMenu() else openMenu() end
    elseif input.KeyCode == Enum.KeyCode.RightControl then
        openButton.Visible = not openButton.Visible
    elseif input.KeyCode == Enum.KeyCode.RightAlt then
        menu.Position = UDim2.new(0.5, 0, 0.5, 0)
        menuScale = 1
        TweenService:Create(uiScale, TweenInfo.new(0.3), {Scale = 1}):Play()
    end
end))

gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

getgenv().HTrungCleanup = function()
    pcall(function()
        if getgenv().HTrungRebirth then
            getgenv().HTrungRebirth.enabled = false
            if getgenv().HTrungRebirth.thread then
                pcall(task.cancel, getgenv().HTrungRebirth.thread)
                getgenv().HTrungRebirth.thread = nil
            end
        end
    end)
    pcall(function()
        if getgenv().HTrungAntiBan then
            local AB = getgenv().HTrungAntiBan
            AB.kick = false AB.report = false AB.tp = false AB.detect = false AB.screenshot = false AB.spoof = false
            if AB.kickThread then pcall(task.cancel, AB.kickThread) end
            if AB.tpThread then pcall(task.cancel, AB.tpThread) end
            if AB.detectThread then pcall(task.cancel, AB.detectThread) end
            if AB.screenThread then pcall(task.cancel, AB.screenThread) end
            if AB.hookApplied and AB.mtOldNamecall and getrawmetatable and setreadonly then
                local mt = getrawmetatable(game)
                setreadonly(mt, false)
                mt.__namecall = AB.mtOldNamecall
                setreadonly(mt, true)
            end
            if AB.oldReportAbuse then pcall(function() LocalPlayer.ReportAbuse = AB.oldReportAbuse end) end
        end
    end)
    pcall(function()
        if getgenv().HTrungFixLag then
            getgenv().HTrungFixLag.autoClean = false
            if getgenv().HTrungFixLag.autoThread then pcall(task.cancel, getgenv().HTrungFixLag.autoThread) end
            if getgenv().HTrungFixLag.restore then pcall(getgenv().HTrungFixLag.restore) end
        end
    end)
    if autoItemTpThread then task.cancel(autoItemTpThread) end
    if autoTpSelectedThread then task.cancel(autoTpSelectedThread) end
    if autoRewardThread then task.cancel(autoRewardThread) end
    if autoRewardConn then task.cancel(autoRewardConn) end
    if bypassThread then task.cancel(bypassThread) end
    if bypassLoop then task.cancel(bypassLoop) end
    if autoLoopThread then task.cancel(autoLoopThread) end
    if godModeThread then task.cancel(godModeThread) end
    if autoClickThread then task.cancel(autoClickThread) end
    if oldRaycast then hookfunction(workspace.Raycast, oldRaycast) end
    if setfpscap then pcall(function() setfpscap(60) end) end
    if blur then blur:Destroy() end
    for _, conn in pairs(Connections) do if conn then conn:Disconnect() end end
    if gui then gui:Destroy() end
end