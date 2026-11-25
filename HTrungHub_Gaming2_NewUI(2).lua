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
    MainBG = Color3.fromRGB(11, 13, 20), TopBar = Color3.fromRGB(16, 19, 30),
    SidebarBtn = Color3.fromRGB(23, 27, 40), SidebarBtnActive = Color3.fromRGB(52, 232, 158),
    Text = Color3.fromRGB(236, 241, 252), TextDim = Color3.fromRGB(128, 140, 166),
    AccentPink = Color3.fromRGB(52, 232, 158), AccentPurple = Color3.fromRGB(124, 108, 255),
    AccentCyan = Color3.fromRGB(56, 189, 248), AccentGold = Color3.fromRGB(251, 191, 36)
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

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- Nhấn nút: chỉ kích hoạt khi ngón tay/chuột không kéo đi xa (tránh bấm nhầm khi cuộn)
local function bindClick(button, callback)
    local lastFire = 0
    local startPos = nil
    local function fire()
        local now = tick()
        if now - lastFire < 0.2 then return end
        lastFire = now
        callback()
    end
    button.Activated:Connect(fire)
    button.InputBegan:Connect(function(input)
        if isPress(input) then startPos = input.Position end
    end)
    button.InputEnded:Connect(function(input)
        if startPos and isPress(input) then
            local moved = (input.Position - startPos).Magnitude
            startPos = nil
            if moved < 12 then fire() end
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
-- GUI BASE + UI KIT (GIAO DIỆN MỚI)
-- ==========================================
local gui, openButton, openBtnStroke
local menu, ms, menuStrokeGradient, uiScale, bgImage, bgOverlay, titleFrame, title, sidebar, contentFrame
local openMenu, closeMenu
local createTab, createToggle, createSlider, createSection
local Skin = {}

do
    ColorableElements.Off = Color3.fromRGB(38, 44, 64)
    ColorableElements.Track = Color3.fromRGB(28, 33, 48)
    ColorableElements.Fills = {}

    local OFF = ColorableElements.Off
    local WHITE = Color3.fromRGB(255, 255, 255)
    local DARK = Color3.fromRGB(10, 14, 22)
    local KNOB_OFF = Color3.fromRGB(150, 160, 185)
    local F_REG, F_BOLD, F_BLACK = Enum.Font.GothamMedium, Enum.Font.GothamBold, Enum.Font.GothamBlack
    local LEFT, CENTER, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Center, Enum.TextXAlignment.Right

    -- ---------- helper dựng UI ----------
    local function new(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do o[k] = v end
        if parent then o.Parent = parent end
        return o
    end
    local function round(parent, r)
        return new("UICorner", {CornerRadius = UDim.new(0, r)}, parent)
    end
    local function outline(parent, col, th, tr)
        return new("UIStroke", {Color = col, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, parent)
    end
    local function pad(parent, l, t, r, b)
        return new("UIPadding", {PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b)}, parent)
    end
    local function tween(o, t, props)
        TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
    end
    local function lum(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end
    local function accentSeq()
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.AccentPink),
            ColorSequenceKeypoint.new(0.5, Theme.AccentCyan),
            ColorSequenceKeypoint.new(1, Theme.AccentPurple)
        })
    end

    -- ==========================================
    -- SKIN: nâng cấp nút / ô nhập / khung tạo thủ công
    -- ==========================================
    function Skin.contrast(btn)
        if btn.BackgroundTransparency < 0.5 then
            btn.TextColor3 = lum(btn.BackgroundColor3) > 0.6 and DARK or Theme.Text
        end
    end

    function Skin.button(btn, keepSize)
        if btn:GetAttribute("HTSkin") then return end
        btn:SetAttribute("HTSkin", true)
        btn.AutoButtonColor = false
        btn.TextSize = math.min(btn.TextSize, 13)
        btn.TextWrapped = not keepSize
        if keepSize then btn.TextTruncate = Enum.TextTruncate.AtEnd end
        if btn.Font == F_BLACK then btn.Font = F_BOLD end
        local cr = btn:FindFirstChildOfClass("UICorner") or round(btn, 10)
        cr.CornerRadius = UDim.new(0, 10)
        local st = btn:FindFirstChildOfClass("UIStroke")
        if st then st.Thickness = 1 st.Transparency = 0.4 else st = outline(btn, OFF, 1, 0.2) end
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        if not keepSize and btn.Size.Y.Scale == 0 and btn.Size.Y.Offset < 38 then
            btn.Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset, 0, 38)
        end
        Skin.contrast(btn)
        btn:GetPropertyChangedSignal("BackgroundColor3"):Connect(function() Skin.contrast(btn) end)
        local sc = new("UIScale", {Scale = 1}, btn)
        btn.InputBegan:Connect(function(i) if isPress(i) then tween(sc, 0.08, {Scale = 0.98}) end end)
        btn.InputEnded:Connect(function(i) if isPress(i) then tween(sc, 0.12, {Scale = 1}) end end)
    end

    function Skin.input(box)
        if box:GetAttribute("HTSkin") then return end
        box:SetAttribute("HTSkin", true)
        box.Font = F_REG box.TextSize = 13 box.TextXAlignment = LEFT
        box.BackgroundColor3 = Theme.MainBG box.BackgroundTransparency = 0.25
        local cr = box:FindFirstChildOfClass("UICorner") or round(box, 10)
        cr.CornerRadius = UDim.new(0, 10)
        local st = box:FindFirstChildOfClass("UIStroke") or outline(box, OFF, 1, 0.1)
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        if not box:FindFirstChildOfClass("UIPadding") then pad(box, 12, 0, 12, 0) end
        if box.Size.Y.Scale == 0 and box.Size.Y.Offset < 38 then
            box.Size = UDim2.new(box.Size.X.Scale, box.Size.X.Offset, 0, 38)
        end
        box.Focused:Connect(function() tween(st, 0.15, {Color = Theme.AccentPink, Transparency = 0.1}) end)
        box.FocusLost:Connect(function() tween(st, 0.15, {Color = OFF, Transparency = 0.1}) end)
    end

    function Skin.panel(o)
        if o:GetAttribute("HTSkin") then return end
        o:SetAttribute("HTSkin", true)
        local cr = o:FindFirstChildOfClass("UICorner") or round(o, 10)
        cr.CornerRadius = UDim.new(0, 10)
        local st = o:FindFirstChildOfClass("UIStroke") or outline(o, OFF, 1, 0.3)
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        if o:IsA("TextLabel") then
            o.BackgroundTransparency = 0.3
            o.TextXAlignment = LEFT
            if o.Font ~= Enum.Font.Code then o.Font = F_BOLD end
            if not o:FindFirstChildOfClass("UIPadding") then pad(o, 12, 8, 12, 8) end
        elseif o:IsA("ScrollingFrame") then
            o.ScrollBarThickness = 3
            o.ScrollBarImageColor3 = Color3.fromRGB(90, 100, 130)
            o.BackgroundColor3 = Theme.MainBG
            o.BackgroundTransparency = 0.35
            if not o:FindFirstChildOfClass("UIPadding") then pad(o, 5, 5, 5, 5) end
        end
    end

    function Skin.floating(f)
        f.BackgroundColor3 = Theme.MainBG f.BackgroundTransparency = 0.1
        local cr = f:FindFirstChildOfClass("UICorner") or round(f, 14)
        cr.CornerRadius = UDim.new(0, 14)
        local st = f:FindFirstChildOfClass("UIStroke") or outline(f, OFF, 1, 0.2)
        st.Color = Color3.fromRGB(70, 80, 112) st.Thickness = 1 st.Transparency = 0.15
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    end

    function Skin.tab(frame)
        for _, ch in ipairs(frame:GetChildren()) do
            if ch:IsA("TextButton") and ch.Text ~= "" then Skin.button(ch)
            elseif ch:IsA("TextBox") then Skin.input(ch)
            elseif ch:IsA("TextLabel") and ch.BackgroundTransparency < 1 then Skin.panel(ch)
            elseif ch:IsA("ScrollingFrame") then Skin.panel(ch) end
        end
    end

    function Skin.all()
        for _, tab in ipairs(contentFrame:GetChildren()) do
            if tab:IsA("ScrollingFrame") and tab.Name ~= "Tab_Thông Tin" and tab.Name ~= "Tab_Cài Đặt" then
                pcall(Skin.tab, tab)
            end
        end
    end

    -- ==========================================
    -- NÚT MỞ MENU (AVATAR)
    -- ==========================================
    gui = new("ScreenGui", {Name = "HTrungVip", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Global, DisplayOrder = 999999})

    openButton = new("ImageButton", {
        Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 10, 0, 100), BackgroundColor3 = Theme.MainBG,
        BorderSizePixel = 0, ZIndex = 100, ScaleType = Enum.ScaleType.Crop,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
    }, gui)
    round(openButton, 100)
    openBtnStroke = outline(openButton, WHITE, 2.5, 0)
    local openGrad = new("UIGradient", {Color = accentSeq()}, openBtnStroke)
    makeDraggable(openButton, openButton)

    -- ==========================================
    -- KHUNG MENU CHÍNH
    -- ==========================================
    local vp = Camera.ViewportSize
    menuScale = math.clamp(math.min(vp.X / 760, vp.Y / 480), 0.5, 1)

    menu = new("Frame", {
        Size = UDim2.fromOffset(680, 430), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.MainBG, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false, ZIndex = 50
    }, gui)
    round(menu, 16)
    ms = outline(menu, WHITE, 1.5, 0.35)
    menuStrokeGradient = new("UIGradient", {Color = accentSeq()}, ms)
    ColorableElements.MenuStroke = ms
    uiScale = new("UIScale", {Scale = 0.8}, menu)

    bgImage = new("ImageLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = "rbxassetid://13476434849",
        ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0.9, ZIndex = 50
    }, menu)
    round(bgImage, 16)
    bgOverlay = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.MainBG, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 51}, menu)
    round(bgOverlay, 16)

    -- ---------- thanh tiêu đề ----------
    titleFrame = new("Frame", {
        Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(1, -16, 0, 46), BackgroundColor3 = Theme.TopBar,
        BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 52
    }, menu)
    round(titleFrame, 12)
    outline(titleFrame, OFF, 1, 0.5)

    local logo = new("Frame", {Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0, 10, 0.5, -15), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 53}, titleFrame)
    round(logo, 9)
    new("UIGradient", {Color = ColorSequence.new(Theme.AccentPink, Theme.AccentCyan), Rotation = 45}, logo)
    new("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "H", Font = F_BLACK, TextSize = 18, TextColor3 = DARK, ZIndex = 54}, logo)

    title = new("TextLabel", {
        Size = UDim2.new(0, 116, 1, 0), Position = UDim2.new(0, 50, 0, 0), BackgroundTransparency = 1, Text = "HTRUNG HUB",
        Font = F_BLACK, TextSize = 15, TextColor3 = Theme.Text, TextXAlignment = LEFT, ZIndex = 53
    }, titleFrame)

    local verPill = new("TextLabel", {
        Size = UDim2.new(0, 40, 0, 18), Position = UDim2.new(0, 172, 0.5, -9), BackgroundColor3 = WHITE, BackgroundTransparency = 0.9,
        Text = "V6.3", Font = F_BLACK, TextSize = 10, TextColor3 = Theme.TextDim, ZIndex = 53
    }, titleFrame)
    round(verPill, 6)
    outline(verPill, OFF, 1, 0.3)

    local crumb = new("TextLabel", {
        Size = UDim2.new(1, -350, 1, 0), Position = UDim2.new(0, 224, 0, 0), BackgroundTransparency = 1, Text = "",
        Font = F_REG, TextSize = 13, TextColor3 = Theme.TextDim, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 53
    }, titleFrame)

    local function headBtn(text, x, col)
        local b = new("TextButton", {
            Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, x, 0.5, -15), BackgroundColor3 = col, BackgroundTransparency = 0.2,
            Text = text, Font = F_BOLD, TextSize = 14, TextColor3 = Theme.Text, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 54
        }, titleFrame)
        round(b, 9)
        outline(b, col, 1, 0.6)
        return b
    end
    local closeBtn = headBtn("X", -40, Color3.fromRGB(255, 70, 90))
    closeBtn.BackgroundTransparency = 0.78 closeBtn.TextColor3 = Color3.fromRGB(255, 110, 125)
    local scaleInBtn = headBtn("+", -76, ColorableElements.Off)
    local scaleOutBtn = headBtn("-", -112, ColorableElements.Off)

    local isAnimating = false
    openMenu = function()
        if isAnimating or menu.Visible then return end
        isAnimating = true menu.Visible = true uiScale.Scale = 0.5 menu.BackgroundTransparency = 1 bgOverlay.BackgroundTransparency = 1 blur.Size = 0
        TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = menuScale}):Play()
        TweenService:Create(menu, TweenInfo.new(0.4), {BackgroundTransparency = ColorableElements.MenuAlpha or 0.06}):Play()
        TweenService:Create(bgOverlay, TweenInfo.new(0.4), {BackgroundTransparency = math.min((ColorableElements.MenuAlpha or 0.06) + 0.12, 0.95)}):Play()
        TweenService:Create(blur, TweenInfo.new(0.4), {Size = (ColorableElements.BlurOn == false) and 0 or 15}):Play()
        task.wait(0.4) isAnimating = false
    end
    closeMenu = function()
        if isAnimating or not menu.Visible then return end
        isAnimating = true
        TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.5}):Play()
        TweenService:Create(menu, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(bgOverlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(blur, TweenInfo.new(0.3), {Size = 0}):Play()
        task.wait(0.3) menu.Visible = false isAnimating = false
    end
    bindClick(closeBtn, function() closeMenu() end)
    bindClick(scaleOutBtn, function() menuScale = math.max(menuScale - 0.1, 0.5) TweenService:Create(uiScale, TweenInfo.new(0.2), {Scale = menuScale}):Play() end)
    bindClick(scaleInBtn, function() menuScale = math.min(menuScale + 0.1, 1.5) TweenService:Create(uiScale, TweenInfo.new(0.2), {Scale = menuScale}):Play() end)
    bindClick(openButton, function() if menu.Visible then closeMenu() else openMenu() end end)
    makeDraggable(menu, titleFrame)

    -- viền gradient + nút avatar xoay nhẹ
    task.spawn(function()
        local r = 0
        while menu.Parent do
            if ColorableElements.Anim ~= false then
                r = (r + 2) % 360
                menuStrokeGradient.Rotation = r
                openGrad.Rotation = r
            end
            task.wait(0.04)
        end
    end)

    -- ---------- thanh bên (tab) ----------
    local sideBox = new("Frame", {
        Position = UDim2.new(0, 8, 0, 62), Size = UDim2.new(0, 150, 1, -70), BackgroundColor3 = Theme.TopBar,
        BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 52
    }, menu)
    round(sideBox, 12)
    outline(sideBox, OFF, 1, 0.55)

    sidebar = new("ScrollingFrame", {
        Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(1, -12, 1, -64), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = Color3.fromRGB(90, 100, 130), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), ScrollingDirection = Enum.ScrollingDirection.Y, ClipsDescendants = true, ZIndex = 53
    }, sideBox)
    new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)

    local userCard = new("Frame", {
        Position = UDim2.new(0, 6, 1, -52), Size = UDim2.new(1, -12, 0, 46), BackgroundColor3 = Theme.SidebarBtn,
        BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 53
    }, sideBox)
    round(userCard, 10)
    outline(userCard, OFF, 1, 0.4)
    local av = new("ImageLabel", {
        Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0, 8, 0.5, -15), BackgroundColor3 = Theme.MainBG, ScaleType = Enum.ScaleType.Crop,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150", ZIndex = 54
    }, userCard)
    round(av, 15)
    new("TextLabel", {
        Size = UDim2.new(1, -50, 0, 16), Position = UDim2.new(0, 44, 0, 8), BackgroundTransparency = 1, Text = LocalPlayer.DisplayName,
        Font = F_BOLD, TextSize = 12, TextColor3 = Theme.Text, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 54
    }, userCard)
    new("TextLabel", {
        Size = UDim2.new(1, -50, 0, 14), Position = UDim2.new(0, 44, 0, 24), BackgroundTransparency = 1, Text = "● Online",
        Font = F_REG, TextSize = 10, TextColor3 = Color3.fromRGB(80, 255, 140), TextXAlignment = LEFT, ZIndex = 54
    }, userCard)

    contentFrame = new("Frame", {
        Position = UDim2.new(0, 166, 0, 62), Size = UDim2.new(1, -174, 1, -70), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 52
    }, menu)

    -- ==========================================
    -- TAB
    -- ==========================================
    local tabs = {}
    local function selectTab(entry)
        for _, t in ipairs(tabs) do
            local on = (t == entry)
            t.frame.Visible = on
            tween(t.btn, 0.18, {BackgroundTransparency = on and 0.88 or 1})
            tween(t.label, 0.18, {TextColor3 = on and Theme.Text or Theme.TextDim})
            t.stroke.Thickness = on and 1 or 0
            t.stroke.Color = Theme.AccentPink
            t.bar.BackgroundColor3 = Theme.AccentPink
            tween(t.bar, 0.18, {BackgroundTransparency = on and 0 or 1})
        end
        ColorableElements.ActiveTabBtn = entry.btn
        crumb.Text = "›  " .. entry.icon .. "  " .. entry.name
    end
    ColorableElements.SelectFirst = function() if tabs[1] then selectTab(tabs[1]) end end

    createTab = function(name, icon)
        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 54, LayoutOrder = #tabs + 1
        }, sidebar)
        btn:SetAttribute("HTSkin", true)
        round(btn, 9)
        local stroke = outline(btn, Theme.AccentPink, 0, 0.55)
        local bar = new("Frame", {
            Name = "Bar", Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, 0, 0.5, -9), BackgroundColor3 = Theme.AccentPink,
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 55
        }, btn)
        round(bar, 2)
        new("TextLabel", {
            Size = UDim2.new(0, 24, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = icon,
            Font = F_BOLD, TextSize = 15, TextColor3 = Theme.Text, ZIndex = 55
        }, btn)
        local label = new("TextLabel", {
            Size = UDim2.new(1, -44, 1, 0), Position = UDim2.new(0, 38, 0, 0), BackgroundTransparency = 1, Text = name,
            Font = F_BOLD, TextSize = 12, TextColor3 = Theme.TextDim, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 55
        }, btn)

        local frame = new("ScrollingFrame", {
            Name = "Tab_" .. name, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(90, 100, 130), Visible = false, ZIndex = 53,
            ClipsDescendants = true, ScrollingEnabled = true, ScrollingDirection = Enum.ScrollingDirection.Y,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0)
        }, contentFrame)
        new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, frame)
        pad(frame, 0, 2, 0, 12)
        -- tự gán thứ tự hiển thị cho phần tử tạo thủ công (giữ đúng thứ tự tạo)
        local counter = 1000
        frame.ChildAdded:Connect(function(ch)
            if ch:IsA("GuiObject") and ch.LayoutOrder == 0 then
                counter = counter + 1
                ch.LayoutOrder = counter
            end
        end)

        local entry = {btn = btn, frame = frame, label = label, stroke = stroke, bar = bar, name = name, icon = icon}
        table.insert(tabs, entry)
        bindClick(btn, function() selectTab(entry) end)
        return frame
    end

    -- ==========================================
    -- TIÊU ĐỀ NHÓM
    -- ==========================================
    createSection = function(parent, text)
        local f = new("Frame", {Size = UDim2.new(1, -10, 0, 26), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 54}, parent)
        local dot = new("Frame", {Size = UDim2.new(0, 3, 0, 12), Position = UDim2.new(0, 2, 0, 8), BackgroundColor3 = Theme.AccentPink, BorderSizePixel = 0, ZIndex = 55}, f)
        round(dot, 2)
        table.insert(ColorableElements.Fills, dot)
        new("TextLabel", {
            Size = UDim2.new(1, -14, 0, 28), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1, Text = text,
            Font = F_BOLD, TextSize = 11, TextColor3 = Theme.TextDim, TextXAlignment = LEFT, ZIndex = 55
        }, f)
        return f
    end

    -- ==========================================
    -- CÔNG TẮC
    -- ==========================================
    createToggle = function(parent, text, initialState, callback)
        local container = new("Frame", {
            Size = UDim2.new(1, -10, 0, 44), BackgroundColor3 = Theme.SidebarBtn, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 54
        }, parent)
        round(container, 10)
        local s = outline(container, initialState and Theme.AccentPink or OFF, 1, initialState and 0.45 or 0.35)
        local bar = new("Frame", {
            Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, 0, 0.5, -9), BackgroundColor3 = Theme.AccentPink,
            BackgroundTransparency = initialState and 0 or 1, BorderSizePixel = 0, ZIndex = 55
        }, container)
        round(bar, 2)
        local label = new("TextLabel", {
            Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 16, 0, 0), BackgroundTransparency = 1, Text = text,
            Font = F_REG, TextSize = 13, TextWrapped = true, TextXAlignment = LEFT,
            TextColor3 = initialState and Theme.Text or Theme.TextDim, ZIndex = 55
        }, container)
        local track = new("Frame", {
            Size = UDim2.new(0, 42, 0, 22), Position = UDim2.new(1, -54, 0.5, -11), BorderSizePixel = 0, ZIndex = 55,
            BackgroundColor3 = initialState and Theme.AccentPink or OFF
        }, container)
        round(track, 11)
        local knob = new("Frame", {
            Size = UDim2.new(0, 16, 0, 16), BorderSizePixel = 0, ZIndex = 56,
            Position = initialState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = initialState and WHITE or KNOB_OFF
        }, track)
        round(knob, 8)
        local hit = new("TextButton", {Size = UDim2.new(0, 60, 0, 36), Position = UDim2.new(1, -63, 0.5, -18), BackgroundTransparency = 1, Text = "", ZIndex = 57}, container)
        hit:SetAttribute("HTSkin", true)

        local state = initialState
        local data = {Button = track, State = state, Bar = bar, Stroke = s}
        table.insert(ColorableElements.Toggles, data)
        bindClick(hit, function()
            state = not state data.State = state
            local on = Theme.AccentPink
            tween(track, 0.2, {BackgroundColor3 = state and on or OFF})
            tween(bar, 0.2, {BackgroundColor3 = on, BackgroundTransparency = state and 0 or 1})
            tween(s, 0.2, {Color = state and on or OFF, Transparency = state and 0.45 or 0.35})
            tween(label, 0.2, {TextColor3 = state and Theme.Text or Theme.TextDim})
            tween(knob, 0.2, {
                Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
                BackgroundColor3 = state and WHITE or KNOB_OFF
            })
            callback(state)
        end)
    end

    -- ==========================================
    -- THANH TRƯỢT (KÉO ĐƯỢC + NÚT -/+)
    -- ==========================================
    local dragUpdate, dragScroll = nil, nil
    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if dragUpdate and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            dragUpdate(input.Position.X)
        end
    end))
    table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
        if dragUpdate and isPress(input) then
            dragUpdate = nil
            if dragScroll then dragScroll.ScrollingEnabled = true dragScroll = nil end
        end
    end))

    createSlider = function(parent, text, min, max, initial, callback)
        local frame = new("Frame", {
            Size = UDim2.new(1, -10, 0, 60), BackgroundColor3 = Theme.SidebarBtn, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 54
        }, parent)
        round(frame, 10)
        outline(frame, OFF, 1, 0.35)
        new("TextLabel", {
            Size = UDim2.new(1, -140, 0, 24), Position = UDim2.new(0, 14, 0, 6), BackgroundTransparency = 1, Text = text,
            Font = F_REG, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 55
        }, frame)

        local function stepBtn(sym, x)
            local b = new("TextButton", {
                Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, x, 0, 6), BackgroundColor3 = OFF, Text = sym, Font = F_BOLD,
                TextSize = 14, TextColor3 = Theme.Text, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 56
            }, frame)
            b:SetAttribute("HTSkin", true)
            round(b, 8)
            return b
        end
        local minus = stepBtn("-", -118)
        local plus = stepBtn("+", -38)
        local valLbl = new("TextLabel", {
            Size = UDim2.new(0, 52, 0, 24), Position = UDim2.new(1, -92, 0, 6), BackgroundTransparency = 1, Text = "",
            Font = F_BLACK, TextSize = 13, TextColor3 = Theme.AccentPink, ZIndex = 56
        }, frame)

        local track = new("Frame", {
            Size = UDim2.new(1, -28, 0, 6), Position = UDim2.new(0, 14, 1, -18), BackgroundColor3 = ColorableElements.Track, BorderSizePixel = 0, ZIndex = 55
        }, frame)
        round(track, 3)
        local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.AccentPink, BorderSizePixel = 0, ZIndex = 56}, track)
        round(fill, 3)
        table.insert(ColorableElements.Fills, fill)
        local knob = new("Frame", {
            Size = UDim2.new(0, 16, 0, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 57
        }, track)
        round(knob, 8)
        outline(knob, DARK, 1, 0.6)

        local range = max - min
        local fineStep = 0.1
        if range >= 200 then fineStep = 10 elseif range >= 20 then fineStep = 1 end
        if min == 1 and max == 5 then fineStep = 1 end
        local dragStep = 0.05
        if range >= 20 or (min == 1 and max == 5) then dragStep = 1 elseif range >= 10 then dragStep = 0.5 end

        local val = initial
        local function fmt(v)
            if math.abs(v - math.floor(v + 0.5)) < 0.0001 then return tostring(math.floor(v + 0.5)) end
            return range <= 3 and string.format("%.2f", v) or string.format("%.1f", v)
        end
        local function visual(animate)
            local frac = range ~= 0 and math.clamp((val - min) / range, 0, 1) or 0
            valLbl.Text = fmt(val)
            if animate then
                tween(fill, 0.08, {Size = UDim2.new(frac, 0, 1, 0)})
                tween(knob, 0.08, {Position = UDim2.new(frac, 0, 0.5, 0)})
            else
                fill.Size = UDim2.new(frac, 0, 1, 0)
                knob.Position = UDim2.new(frac, 0, 0.5, 0)
            end
        end
        local function setVal(v, fire)
            v = math.clamp(v, min, max)
            v = math.floor(v * 1000 + 0.5) / 1000
            val = v
            visual(true)
            if fire then callback(val) end
        end
        visual(false)

        bindClick(minus, function() setVal(val - fineStep, true) end)
        bindClick(plus, function() setVal(val + fineStep, true) end)

        local hit = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -32), BackgroundTransparency = 1, Text = "", ZIndex = 58
        }, frame)
        hit:SetAttribute("HTSkin", true)
        local function updateFromX(x)
            local w = track.AbsoluteSize.X
            if w <= 0 then return end
            local frac = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
            local raw = min + frac * range
            setVal(min + math.floor((raw - min) / dragStep + 0.5) * dragStep, true)
        end
        hit.InputBegan:Connect(function(input)
            if isPress(input) then
                dragUpdate = updateFromX
                if parent:IsA("ScrollingFrame") then dragScroll = parent parent.ScrollingEnabled = false end
                updateFromX(input.Position.X)
            end
        end)
    end
end

-- ==========================================
-- OVERLAYS (BẢNG NỔI)
-- ==========================================
local teleOverlay = Instance.new("Frame")
teleOverlay.Size = UDim2.new(0, 236, 0, 172) teleOverlay.Position = UDim2.new(1, -256, 1, -300)
teleOverlay.BorderSizePixel = 0 teleOverlay.Visible = false teleOverlay.ZIndex = 90 teleOverlay.Parent = gui
Skin.floating(teleOverlay)
local teleTitle = Instance.new("TextLabel")
teleTitle.Size = UDim2.new(1, 0, 0, 34) teleTitle.BackgroundTransparency = 1 teleTitle.TextColor3 = Theme.Text
teleTitle.Font = Enum.Font.GothamBold teleTitle.TextSize = 12 teleTitle.Text = "📍  BẢNG TELE NHANH" teleTitle.TextXAlignment = Enum.TextXAlignment.Left
teleTitle.ZIndex = 91 teleTitle.Parent = teleOverlay
do
    local p = Instance.new("UIPadding") p.PaddingLeft = UDim.new(0, 14) p.Parent = teleTitle
    local line = Instance.new("Frame") line.Size = UDim2.new(1, -20, 0, 1) line.Position = UDim2.new(0, 10, 0, 34)
    line.BackgroundColor3 = ColorableElements.Off line.BorderSizePixel = 0 line.ZIndex = 91 line.Parent = teleOverlay
end
makeDraggable(teleOverlay, teleTitle)

local function createOverlayBtn(text, x, y, bg, parent)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 68, 0, 32) b.Position = UDim2.new(0, x, 0, y) b.BackgroundColor3 = bg
    b.TextColor3 = Theme.Text b.Font = Enum.Font.GothamBold b.TextSize = 12 b.Text = text b.BorderSizePixel = 0 b.ZIndex = 91 b.Parent = parent
    Skin.button(b, true)
    return b
end

local save1Btn = createOverlayBtn("Lưu 1", 10, 44, Theme.SidebarBtn, teleOverlay)
local tp1Btn = createOverlayBtn("Đến 1", 84, 44, Theme.AccentPurple, teleOverlay)
local auto1Btn = createOverlayBtn("Auto 1", 158, 44, Theme.SidebarBtn, teleOverlay)
local save2Btn = createOverlayBtn("Lưu 2", 10, 82, Theme.SidebarBtn, teleOverlay)
local tp2Btn = createOverlayBtn("Đến 2", 84, 82, Theme.AccentPurple, teleOverlay)
local auto2Btn = createOverlayBtn("Auto 2", 158, 82, Theme.SidebarBtn, teleOverlay)

-- NÚT AUTO LẶP 1 & 2
local autoLoopBtn = createOverlayBtn("Auto Lặp 1 & 2", 10, 124, Theme.SidebarBtn, teleOverlay)
autoLoopBtn.Size = UDim2.new(1, -20, 0, 36)

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
flyOverlay.Size = UDim2.new(0, 196, 0, 58) flyOverlay.Position = UDim2.new(1, -216, 1, -150)
flyOverlay.BorderSizePixel = 0 flyOverlay.Visible = false flyOverlay.ZIndex = 90 flyOverlay.Parent = gui
Skin.floating(flyOverlay)
local btnFlyUp = Instance.new("TextButton") btnFlyUp.Size = UDim2.new(0.5, -12, 1, -14) btnFlyUp.Position = UDim2.new(0, 8, 0, 7) btnFlyUp.BackgroundColor3 = Theme.AccentPurple btnFlyUp.TextColor3 = Theme.Text btnFlyUp.Font = Enum.Font.GothamBold btnFlyUp.Text = "▲  LÊN" btnFlyUp.TextSize = 13 btnFlyUp.ZIndex = 91 btnFlyUp.BorderSizePixel = 0 btnFlyUp.Parent = flyOverlay
local btnFlyDown = Instance.new("TextButton") btnFlyDown.Size = UDim2.new(0.5, -12, 1, -14) btnFlyDown.Position = UDim2.new(0.5, 4, 0, 7) btnFlyDown.BackgroundColor3 = Theme.AccentPink btnFlyDown.TextColor3 = Theme.Text btnFlyDown.Font = Enum.Font.GothamBold btnFlyDown.Text = "▼  XUỐNG" btnFlyDown.TextSize = 13 btnFlyDown.ZIndex = 91 btnFlyDown.BorderSizePixel = 0 btnFlyDown.Parent = flyOverlay
Skin.button(btnFlyUp, true) Skin.button(btnFlyDown, true)
bindHold(btnFlyUp, function() States.FlyUp = true end, function() States.FlyUp = false end)
bindHold(btnFlyDown, function() States.FlyDown = true end, function() States.FlyDown = false end)
makeDraggable(flyOverlay, flyOverlay)

local fcOverlay = Instance.new("Frame")
fcOverlay.Size = UDim2.new(0, 190, 0, 210) fcOverlay.Position = UDim2.new(1, -210, 1, -390)
fcOverlay.BorderSizePixel = 0 fcOverlay.Visible = false fcOverlay.ZIndex = 90 fcOverlay.Parent = gui
Skin.floating(fcOverlay)

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
for _, ch in ipairs(fcOverlay:GetChildren()) do
    if ch:IsA("TextButton") then Skin.button(ch, true) end
end


-- ==========================================
-- TAB 1: INFO (DASHBOARD)
-- ==========================================
local infoTab = createTab("Thông Tin", "🏠")
infoTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
infoTab.CanvasSize = UDim2.new(0, 0, 0, 0)
infoTab.UIListLayout.Padding = UDim.new(0, 10)
infoTab.UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local fpsLabel, pingLabel, posLabel, timeLbl, playtimeLbl

do
    local OFF = ColorableElements.Off
    local rotating = {}
    local WHITE = Color3.fromRGB(255, 255, 255)

    local function corner(parent, r)
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = parent return c
    end
    local function stroke(parent, col, th, tr)
        local st = Instance.new("UIStroke") st.Color = col st.Thickness = th st.Transparency = tr or 0 st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border st.Parent = parent return st
    end
    local function text(parent, str, size, font, col)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1 l.Text = str l.TextSize = size l.Font = font l.TextColor3 = col l.ZIndex = 55 l.Parent = parent
        return l
    end
    local function neonGradient(parent)
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.AccentPink),
            ColorSequenceKeypoint.new(0.5, Theme.AccentCyan),
            ColorSequenceKeypoint.new(1, Theme.AccentPurple)
        })
        g.Parent = parent
        table.insert(rotating, g)
        return g
    end

    -- ========== HEADER CARD ==========
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -10, 0, 136) header.BackgroundColor3 = Theme.SidebarBtn header.BackgroundTransparency = 0.2
    header.BorderSizePixel = 0 header.ZIndex = 54 header.LayoutOrder = 1 header.Parent = infoTab
    corner(header, 12)
    neonGradient(stroke(header, WHITE, 1.5, 0.1))
    local hbg = Instance.new("UIGradient")
    hbg.Color = ColorSequence.new(WHITE, Color3.fromRGB(110, 120, 155)) hbg.Rotation = 20 hbg.Parent = header

    local ringHolder = Instance.new("Frame")
    ringHolder.Size = UDim2.new(0, 92, 0, 92) ringHolder.Position = UDim2.new(0, 16, 0.5, -46)
    ringHolder.BackgroundTransparency = 1 ringHolder.ZIndex = 55 ringHolder.Parent = header
    local ring = Instance.new("Frame")
    ring.Size = UDim2.new(1, 0, 1, 0) ring.BackgroundTransparency = 1 ring.ZIndex = 55 ring.Parent = ringHolder
    corner(ring, 46)
    neonGradient(stroke(ring, WHITE, 3, 0))
    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.new(0, 80, 0, 80) avatar.AnchorPoint = Vector2.new(0.5, 0.5) avatar.Position = UDim2.new(0.5, 0, 0.5, 0)
    avatar.BackgroundColor3 = Color3.fromRGB(20, 24, 36) avatar.ScaleType = Enum.ScaleType.Crop avatar.ZIndex = 56
    avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150" avatar.Parent = ringHolder
    corner(avatar, 40)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 16, 0, 16) dot.Position = UDim2.new(1, -16, 1, -16) dot.BackgroundColor3 = Color3.fromRGB(80, 255, 140)
    dot.BorderSizePixel = 0 dot.ZIndex = 58 dot.Parent = ringHolder
    corner(dot, 8) stroke(dot, Theme.MainBG, 3, 0)

    local nameLbl = text(header, LocalPlayer.DisplayName, 24, Enum.Font.GothamBlack, WHITE)
    nameLbl.Size = UDim2.new(1, -210, 0, 30) nameLbl.Position = UDim2.new(0, 124, 0, 14)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    local ng = Instance.new("UIGradient")
    ng.Color = ColorSequence.new(WHITE, Theme.AccentPink) ng.Parent = nameLbl

    local userLbl2 = text(header, "@" .. LocalPlayer.Name, 13, Enum.Font.GothamBold, Theme.TextDim)
    userLbl2.Size = UDim2.new(1, -210, 0, 18) userLbl2.Position = UDim2.new(0, 124, 0, 44)
    userLbl2.TextXAlignment = Enum.TextXAlignment.Left userLbl2.TextTruncate = Enum.TextTruncate.AtEnd

    local badge = text(header, "V6.3", 12, Enum.Font.GothamBlack, Theme.AccentPink)
    badge.Size = UDim2.new(0, 52, 0, 22) badge.Position = UDim2.new(1, -66, 0, 14)
    badge.BackgroundTransparency = 0.82 badge.BackgroundColor3 = Theme.AccentPink
    corner(badge, 6) stroke(badge, Theme.AccentPink, 1, 0.5)

    local chips = Instance.new("Frame")
    chips.Size = UDim2.new(1, -140, 0, 52) chips.Position = UDim2.new(0, 124, 0, 74)
    chips.BackgroundTransparency = 1 chips.ZIndex = 55 chips.Parent = header
    local chipLayout = Instance.new("UIListLayout")
    chipLayout.FillDirection = Enum.FillDirection.Horizontal chipLayout.Wraps = true
    chipLayout.Padding = UDim.new(0, 6) chipLayout.SortOrder = Enum.SortOrder.LayoutOrder chipLayout.Parent = chips
    local function chip(str, col, order)
        local f = text(chips, str, 11, Enum.Font.GothamBold, col)
        f.AutomaticSize = Enum.AutomaticSize.X f.Size = UDim2.new(0, 0, 0, 22) f.ZIndex = 56 f.LayoutOrder = order
        f.BackgroundTransparency = 0.82 f.BackgroundColor3 = col
        corner(f, 6) stroke(f, col, 1, 0.55)
        local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0, 10) pad.PaddingRight = UDim.new(0, 10) pad.Parent = f
    end
    chip("ID " .. LocalPlayer.UserId, Theme.AccentCyan, 1)
    chip("● ONLINE", Color3.fromRGB(80, 255, 140), 2)
    chip("PREMIUM", Theme.AccentGold, 3)
    chip("📅 " .. LocalPlayer.AccountAge .. " ngày", Theme.AccentPurple, 4)

    -- ========== STAT CARDS ==========
    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, -10, 0, 240) grid.BackgroundTransparency = 1 grid.ZIndex = 54 grid.LayoutOrder = 2 grid.Parent = infoTab
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.5, -5, 0, 115) gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder gridLayout.Parent = grid

    local function makeCard(titleText, icon, accent, order)
        local card = Instance.new("Frame")
        card.BackgroundColor3 = Theme.SidebarBtn card.BackgroundTransparency = 0.25 card.BorderSizePixel = 0
        card.ZIndex = 54 card.LayoutOrder = order card.Parent = grid
        corner(card, 10) stroke(card, OFF, 1, 0.1)
        local topLine = Instance.new("Frame")
        topLine.Size = UDim2.new(1, -24, 0, 2) topLine.Position = UDim2.new(0, 12, 0, 0)
        topLine.BackgroundColor3 = accent topLine.BorderSizePixel = 0 topLine.ZIndex = 55 topLine.Parent = card
        corner(topLine, 1)
        local iconChip = text(card, icon, 12, Enum.Font.GothamBold, WHITE)
        iconChip.Size = UDim2.new(0, 22, 0, 22) iconChip.Position = UDim2.new(0, 10, 0, 8)
        iconChip.BackgroundTransparency = 0.8 iconChip.BackgroundColor3 = accent
        corner(iconChip, 6)
        local t = text(card, titleText, 12, Enum.Font.GothamBlack, accent)
        t.Size = UDim2.new(1, -48, 0, 22) t.Position = UDim2.new(0, 38, 0, 8) t.TextXAlignment = Enum.TextXAlignment.Left
        local div = Instance.new("Frame")
        div.Size = UDim2.new(1, -20, 0, 1) div.Position = UDim2.new(0, 10, 0, 34)
        div.BackgroundColor3 = OFF div.BorderSizePixel = 0 div.ZIndex = 55 div.Parent = card
        local body = Instance.new("Frame")
        body.Size = UDim2.new(1, -20, 1, -42) body.Position = UDim2.new(0, 10, 0, 38)
        body.BackgroundTransparency = 1 body.ZIndex = 55 body.Parent = card
        local ll = Instance.new("UIListLayout") ll.Padding = UDim.new(0, 2) ll.SortOrder = Enum.SortOrder.LayoutOrder ll.Parent = body
        return body
    end

    local function statRow(body, key, value, order, valueColor)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22) row.BackgroundTransparency = 1 row.ZIndex = 55 row.LayoutOrder = order row.Parent = body
        local k = text(row, key, 12, Enum.Font.GothamBold, Theme.TextDim)
        k.Size = UDim2.new(0.38, 0, 1, 0) k.TextXAlignment = Enum.TextXAlignment.Left
        local v = text(row, value, 12, Enum.Font.GothamBold, valueColor or Theme.Text)
        v.Size = UDim2.new(0.62, 0, 1, 0) v.Position = UDim2.new(0.38, 0, 0, 0)
        v.TextXAlignment = Enum.TextXAlignment.Right v.TextTruncate = Enum.TextTruncate.AtEnd
        return v
    end

    local perfBody = makeCard("HIỆU NĂNG", "⚡", Theme.AccentCyan, 1)
    fpsLabel = statRow(perfBody, "FPS", "...", 1)
    pingLabel = statRow(perfBody, "Ping", "... ms", 2)
    posLabel = statRow(perfBody, "Vị trí", "...", 3)

    local sessBody = makeCard("PHIÊN CHƠI", "⏱️", Theme.AccentPink, 2)
    timeLbl = statRow(sessBody, "Giờ", os.date("%H:%M:%S"), 1)
    statRow(sessBody, "Ngày", os.date("%d/%m/%Y"), 2)
    playtimeLbl = statRow(sessBody, "Đã chơi", "00:00:00", 3, Theme.AccentPink)

    local infoBody = makeCard("THÔNG TIN", "👤", Theme.AccentPurple, 3)
    local gameValue = statRow(infoBody, "Game", game.Name, 1)
    statRow(infoBody, "Tên", LocalPlayer.DisplayName, 2)
    local robuxValue = statRow(infoBody, "Robux", currentRobux, 3, Theme.AccentGold)

    local updBody = makeCard("CẬP NHẬT", "🔄", Theme.AccentGold, 4)
    local updText = text(updBody, "V6.3 · Auto Lặp TP 1 & 2 chạy theo Heartbeat (delay 0s).", 12, Enum.Font.GothamBold, Theme.TextDim)
    updText.Size = UDim2.new(1, 0, 1, 0) updText.TextWrapped = true updText.TextXAlignment = Enum.TextXAlignment.Left
    updText.TextYAlignment = Enum.TextYAlignment.Top

    task.spawn(function()
        for _ = 1, 40 do
            if currentRobux ~= "Đang tải..." then break end
            task.wait(0.5)
        end
        local n = tonumber(currentRobux)
        if n then
            robuxValue.Text = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        else
            robuxValue.Text = currentRobux
        end
    end)
    task.spawn(function()
        local ok, infoData = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and infoData and infoData.Name then gameValue.Text = infoData.Name end
    end)

    -- ========== SERVER ACTIONS ==========
    local serverBar = Instance.new("Frame")
    serverBar.Size = UDim2.new(1, -10, 0, 44) serverBar.BackgroundTransparency = 1 serverBar.ZIndex = 54 serverBar.LayoutOrder = 3 serverBar.Parent = infoTab
    local sg = Instance.new("UIGridLayout")
    sg.CellSize = UDim2.new(0.3333, -6, 1, 0) sg.CellPadding = UDim2.new(0, 9, 0, 0) sg.SortOrder = Enum.SortOrder.LayoutOrder sg.Parent = serverBar

    local function createServerBtn(label, icon, col, order, callback)
        local btn = Instance.new("TextButton")
        btn.BackgroundColor3 = col btn.BackgroundTransparency = 0.85 btn.AutoButtonColor = false
        btn.TextColor3 = col btn.Font = Enum.Font.GothamBold btn.TextSize = 12 btn.Text = icon .. "  " .. label
        btn.BorderSizePixel = 0 btn.ZIndex = 55 btn.LayoutOrder = order btn.Parent = serverBar
        corner(btn, 10) stroke(btn, col, 1, 0.4)
        bindClick(btn, function()
            btn.BackgroundTransparency = 0.4
            TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundTransparency = 0.85}):Play()
            callback()
        end)
    end
    createServerBtn("Server Hop", "🔄", Theme.AccentCyan, 1, ServerHop)
    createServerBtn("Rejoin", "🔁", Color3.fromRGB(150, 110, 255), 2, RejoinServer)
    createServerBtn("Server VIP", "👑", Theme.AccentGold, 3, ServerVIP)

    local footer = text(infoTab, "HTrung Hub V6.3", 11, Enum.Font.GothamBold, Theme.TextDim)
    footer.Size = UDim2.new(1, -10, 0, 18) footer.LayoutOrder = 4 footer.ZIndex = 54 footer.TextTransparency = 0.4

    task.spawn(function()
        local r = 0
        while infoTab.Parent do
            if ColorableElements.Anim ~= false then
                r = (r + 2) % 360
                for _, g in ipairs(rotating) do g.Rotation = r end
            end
            task.wait(0.03)
        end
    end)
end

-- ==========================================
-- TAB 2: PLAYER
-- ==========================================
local playerTab = createTab("Player", "🎮")
createSection(playerTab, "SINH TỒN") createToggle(playerTab, "God Mode (Bất tử)", false, function(s)
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
createSection(playerTab, "TỐC ĐỘ & NHẢY") createSlider(playerTab, "WalkSpeed", 16, 500, 16, function(v) States.Speed = v end)
createSlider(playerTab, "JumpPower", 50, 500, 50, function(v) States.JumpPower = v end)
createSection(playerTab, "DI CHUYỂN") createToggle(playerTab, "Infinite Jump", false, function(s) States.InfJump = s end)
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
createSection(playerTab, "BAY") createToggle(playerTab, "Fly (Bay)", false, function(s) States.Fly = s flyOverlay.Visible = s end)
createSlider(playerTab, "Fly Speed", 10, 500, 60, function(v) States.FlySpeed = v end)

-- ==========================================
-- TAB 3: VISUALS
-- ==========================================
local visualTab = createTab("Visuals", "👁️")
createSection(visualTab, "HIỂN THỊ") createToggle(visualTab, "Player ESP (Highlight)", false, function(s)
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
createSection(visualTab, "CAMERA TỰ DO") createSlider(visualTab, "FreeCam Speed", 10, 300, 50, function(v) States.FreeCamSpeed = v end)
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
createSection(combatTab, "HITBOX") createToggle(combatTab, "Hitbox Expander", false, function(s) States.Hitbox = s end)
createSlider(combatTab, "Hitbox Size", 5, 50, 10, function(v) States.HitboxSize = v end)
createSection(combatTab, "NGẮM & BẮN") createToggle(combatTab, "Aimbot (Camera Lock)", false, function(s) States.Aimbot = s end)
createToggle(combatTab, "Wallbang (Bắn xuyên tường)", false, function(s) States.Wallbang = s end)
createSection(combatTab, "TẤN CÔNG") createToggle(combatTab, "Silent Kill Aura (Không cần nhìn)", false, function(s) States.KillAura = s end)
createSlider(combatTab, "Aura Range", 10, 2000, 2000, function(v) States.AuraRange = v end)
createSection(combatTab, "NÉ TRÁNH") createToggle(combatTab, "Auto Dodge (VIP Teleport)", false, function(s) States.Dodge = s end)

-- ==========================================
-- TAB 5: FARM REWARD
-- ==========================================
pcall(function()
do
    local rewardTab = createTab("Farm Reward", "🌾")
    createSection(rewardTab, "TỰ ĐỘNG NHẬN THƯỞNG") createToggle(rewardTab, "Ép Thời Gian Về 0 (liên tục)", false, function(s) States.ResetTime = s end)
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

    createSection(rewardTab, "TỐC ĐỘ GAME") createSlider(rewardTab, "SpeedHack (Tốc độ Game)", 1, 1000, 1, function(v)
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

    createSection(rewardTab, "NHẬN THƯỞNG NHANH") local bypassPlaytimeBtn = Instance.new("TextButton")
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
createSection(tpTab, "DỊCH CHUYỂN") local tpMouseBtn = Instance.new("TextButton")
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

createSection(tpTab, "TELE ĐẾN NGƯỜI CHƠI") local plrScroll = Instance.new("ScrollingFrame")
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
            Skin.button(btn, true)
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
createSection(miscTab, "TIỆN ÍCH") createToggle(miscTab, "Anti-AFK (Chống treo)", false, function(s) States.AntiAFK = s end)
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
createSection(scanItemTab, "TÌM KIẾM VẬT PHẨM") local itemInputBox = Instance.new("TextBox")
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

createSection(scanItemTab, "KẾT QUẢ QUÉT") local itemListFrame = Instance.new("ScrollingFrame")
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
    Skin.button(btn, true)
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

createSection(scanItemTab, "TỰ ĐỘNG TELEPORT") createToggle(scanItemTab, "Auto Teleport Item (All)", false, function(s)
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

    createSection(gameTab, "TRẠNG THÁI & NHẬT KÝ") local rebirthStatus = Instance.new("TextLabel")
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

    createSection(gameTab, "TỰ ĐỘNG TÁI SINH") createSlider(gameTab, "Delay auto (giây)", 0, 30.0, 0, function(v) RB.delay = v end)

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
    createSection(antiTab, "NHẬT KÝ")
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

    createSection(antiTab, "BẢO VỆ TÀI KHOẢN") createToggle(antiTab, "Anti-Kick (Chặn Kick)", false, function(s)
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

    createSection(antiTab, "NÂNG CAO") local killACBtn = Instance.new("TextButton")
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

    createSection(fixTab, "TRẠNG THÁI") local statusLbl = Instance.new("TextLabel")
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

    createSection(fixTab, "TỐI ƯU HÓA") createSlider(fixTab, "Cấp độ fix lag (1-5)", 1, 5, 3, function(v) FL.level = v end)

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

    createSection(fixTab, "HƯỚNG DẪN CẤP ĐỘ") local infoLbl = Instance.new("TextLabel")
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

    createSection(fixTab, "TỰ ĐỘNG") createToggle(fixTab, "🔄 Auto clean (xóa particles/decals mới)", false, function(s)
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
    createSection(bypassTab, "NHẬT KÝ")
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
    createSection(bypassTab, "BYPASS") createToggle(bypassTab, "Bypass Gamepass (Deep Hook)", false, function(s)
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
-- TAB 13: SETTINGS (PRO)
-- ==========================================
pcall(function()
do
    local settingsTab = createTab("Cài Đặt", "🛠️")
    settingsTab.UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    settingsTab.UIListLayout.Padding = UDim.new(0, 10)

    local OFF = ColorableElements.Off
    local WHITE = Color3.fromRGB(255, 255, 255)
    local RED = Color3.fromRGB(255, 70, 90)
    local GREEN = Color3.fromRGB(80, 255, 140)
    local CONFIG_FILE = "HTrungHub_Settings.json"

    local defaults = {
        accent = {52, 232, 158}, alpha = 0.06, scale = menuScale, anim = true, blur = true,
        bgVisible = true, bgId = "13476434849", iconSize = 50, toasts = true, autoSave = true
    }
    local cfg = {}
    for k, v in pairs(defaults) do cfg[k] = v end
    cfg.accent = {defaults.accent[1], defaults.accent[2], defaults.accent[3]}

    local apply, ui, accentCallbacks, orders = {}, {}, {}, {}
    local loading = false

    local function safe(fn)
        local ok, err = pcall(fn)
        if not ok then warn("[HTrung Settings] " .. tostring(err)) end
    end

    -- ---------- helpers ----------
    local function corner(parent, r)
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = parent return c
    end
    local function stroke(parent, col, th, tr)
        local st = Instance.new("UIStroke") st.Color = col st.Thickness = th st.Transparency = tr or 0 st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border st.Parent = parent return st
    end
    local function label(parent, str, size, font, col, align)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1 l.Text = str l.TextSize = size l.Font = font l.TextColor3 = col
        l.TextXAlignment = align or Enum.TextXAlignment.Left l.ZIndex = 56 l.Parent = parent
        return l
    end
    local function ord(parent)
        orders[parent] = (orders[parent] or 1) + 1
        return orders[parent]
    end
    local function isPress(input)
        return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
    end
    -- tap an toàn khi cuộn: chỉ kích hoạt nếu ngón tay không kéo đi xa
    local function tap(btn, cb)
        local startPos
        btn.InputBegan:Connect(function(input)
            if isPress(input) then startPos = input.Position end
        end)
        btn.InputEnded:Connect(function(input)
            if startPos and isPress(input) then
                local moved = (input.Position - startPos).Magnitude
                startPos = nil
                if moved < 14 then cb() end
            end
        end)
    end

    -- ---------- cấu hình / lưu ----------
    local saveToken = 0
    local function writeConfig()
        if not writefile then return false end
        return pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end)
    end
    local function scheduleSave()
        if loading or not cfg.autoSave or not writefile then return end
        saveToken = saveToken + 1
        local t = saveToken
        task.delay(1, function() if t == saveToken then writeConfig() end end)
    end
    local function commit(key, value)
        cfg[key] = value
        if apply[key] then apply[key](value) end
        scheduleSave()
    end
    local function setAll(key, value)
        commit(key, value)
        if ui[key] then ui[key](value) end
    end

    -- ---------- thông báo (toast) ----------
    local toastFrame
    local function notify(msg, col)
        if cfg.toasts == false then return end
        col = col or Theme.AccentPink
        if toastFrame then pcall(function() toastFrame:Destroy() end) end
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 290, 0, 38) f.AnchorPoint = Vector2.new(0.5, 0) f.Position = UDim2.new(0.5, 0, 0, -60)
        f.BackgroundColor3 = Theme.MainBG f.BackgroundTransparency = 0.08 f.BorderSizePixel = 0 f.ZIndex = 300 f.Parent = gui
        corner(f, 10) stroke(f, col, 1.5, 0.2)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 4, 0.6, 0) bar.Position = UDim2.new(0, 8, 0.2, 0) bar.BackgroundColor3 = col bar.BorderSizePixel = 0 bar.ZIndex = 301 bar.Parent = f
        corner(bar, 2)
        local l = label(f, msg, 13, Enum.Font.GothamBold, Theme.Text)
        l.Size = UDim2.new(1, -30, 1, 0) l.Position = UDim2.new(0, 22, 0, 0) l.ZIndex = 301 l.TextTruncate = Enum.TextTruncate.AtEnd
        toastFrame = f
        TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 12)}):Play()
        task.delay(2.2, function()
            if f and f.Parent then
                TweenService:Create(f, TweenInfo.new(0.25), {Position = UDim2.new(0.5, 0, 0, -60)}):Play()
                task.wait(0.3)
                if f then f:Destroy() end
            end
        end)
    end

    -- ---------- áp dụng cài đặt ----------
    apply.accent = function(t)
        local color = Color3.fromRGB(t[1], t[2], t[3])
        Theme.AccentPink = color Theme.SidebarBtnActive = color
        local seq = ColorSequence.new({
            ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.5, Theme.AccentCyan), ColorSequenceKeypoint.new(1, Theme.AccentPurple)
        })
        ms.Color = WHITE menuStrokeGradient.Color = seq
        openBtnStroke.Color = WHITE
        local og = openBtnStroke:FindFirstChildOfClass("UIGradient") if og then og.Color = seq end
        local atb = ColorableElements.ActiveTabBtn
        if atb then
            local ab = atb:FindFirstChild("Bar") if ab then ab.BackgroundColor3 = color end
            local ast = atb:FindFirstChild("UIStroke") if ast then ast.Color = color end
        end
        for _, data in ipairs(ColorableElements.Toggles) do
            if data.State then
                data.Button.BackgroundColor3 = color
                if data.Bar then data.Bar.BackgroundColor3 = color end
                if data.Stroke then data.Stroke.Color = color end
            end
        end
        for _, f in ipairs(ColorableElements.Fills or {}) do f.BackgroundColor3 = color end
        for _, fn in ipairs(accentCallbacks) do pcall(fn, color) end
    end
    apply.alpha = function(v)
        ColorableElements.MenuAlpha = v
        menu.BackgroundTransparency = v
        bgOverlay.BackgroundTransparency = math.min(v + 0.12, 0.95)
        titleFrame.BackgroundTransparency = math.min(v + 0.22, 0.95)
    end
    apply.scale = function(v)
        menuScale = v
        if menu.Visible then TweenService:Create(uiScale, TweenInfo.new(0.25), {Scale = v}):Play() end
    end
    apply.anim = function(b)
        ColorableElements.Anim = b
        if not b then title.TextTransparency = 0 title.TextColor3 = Theme.Text end
    end
    apply.blur = function(b)
        ColorableElements.BlurOn = b
        if menu.Visible then TweenService:Create(blur, TweenInfo.new(0.3), {Size = b and 15 or 0}):Play() end
    end
    apply.bgVisible = function(b) bgImage.Visible = b end
    apply.bgId = function(id)
        id = string.gsub(tostring(id), "rbxassetid://", "")
        if id ~= "" then bgImage.Image = "rbxassetid://" .. id end
    end
    apply.iconSize = function(n) openButton.Size = UDim2.new(0, n, 0, n) end

    -- ---------- card ----------
    local function makeCard(order, icon, titleText, accent)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -10, 0, 0) card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = Theme.SidebarBtn card.BackgroundTransparency = 0.25 card.BorderSizePixel = 0
        card.ZIndex = 54 card.LayoutOrder = order card.Parent = settingsTab
        corner(card, 10) stroke(card, OFF, 1, 0.1)
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 12) pad.PaddingBottom = UDim.new(0, 12) pad.PaddingLeft = UDim.new(0, 12) pad.PaddingRight = UDim.new(0, 12) pad.Parent = card
        local list = Instance.new("UIListLayout") list.Padding = UDim.new(0, 8) list.SortOrder = Enum.SortOrder.LayoutOrder list.Parent = card
        local head = Instance.new("Frame")
        head.Size = UDim2.new(1, 0, 0, 24) head.BackgroundTransparency = 1 head.LayoutOrder = 0 head.ZIndex = 55 head.Parent = card
        local chipI = label(head, icon, 12, Enum.Font.GothamBold, WHITE, Enum.TextXAlignment.Center)
        chipI.Size = UDim2.new(0, 24, 0, 24) chipI.BackgroundTransparency = 0.8 chipI.BackgroundColor3 = accent corner(chipI, 6)
        local t = label(head, titleText, 12, Enum.Font.GothamBlack, accent)
        t.Size = UDim2.new(1, -32, 1, 0) t.Position = UDim2.new(0, 32, 0, 0)
        local div = Instance.new("Frame")
        div.Size = UDim2.new(1, 0, 0, 1) div.BackgroundColor3 = OFF div.BorderSizePixel = 0 div.LayoutOrder = 1 div.ZIndex = 55 div.Parent = card
        return card
    end

    local function makeBtn(parent, text, col, cb)
        local btn = Instance.new("TextButton")
        btn.BackgroundColor3 = col btn.BackgroundTransparency = 0.85 btn.AutoButtonColor = false
        btn.TextColor3 = col btn.Font = Enum.Font.GothamBold btn.TextSize = 12 btn.Text = text
        btn.BorderSizePixel = 0 btn.ZIndex = 56 btn.Parent = parent
        corner(btn, 8) stroke(btn, col, 1, 0.4)
        tap(btn, function()
            btn.BackgroundTransparency = 0.45
            TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundTransparency = 0.85}):Play()
            cb()
        end)
        return btn
    end
    local function actionBtn(parent, text, col, cb)
        local b = makeBtn(parent, text, col, cb)
        b.Size = UDim2.new(1, 0, 0, 36) b.LayoutOrder = ord(parent)
        return b
    end
    local function buttonGrid(parent, defs)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 36) row.BackgroundTransparency = 1 row.ZIndex = 55 row.LayoutOrder = ord(parent) row.Parent = parent
        local n = #defs
        local g = Instance.new("UIGridLayout")
        g.CellSize = UDim2.new(1 / n, -math.ceil(8 * (n - 1) / n), 1, 0) g.CellPadding = UDim2.new(0, 8, 0, 0)
        g.SortOrder = Enum.SortOrder.LayoutOrder g.Parent = row
        for i, d in ipairs(defs) do
            local b = makeBtn(row, d[1], d[2], d[3]) b.LayoutOrder = i
        end
    end

    local function kv(parent, key, value, valueColor)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22) row.BackgroundTransparency = 1 row.ZIndex = 55 row.LayoutOrder = ord(parent) row.Parent = parent
        local k = label(row, key, 12, Enum.Font.GothamBold, Theme.TextDim) k.Size = UDim2.new(0.35, 0, 1, 0)
        local v = label(row, value, 12, Enum.Font.GothamBold, valueColor or Theme.Text, Enum.TextXAlignment.Right)
        v.Size = UDim2.new(0.65, 0, 1, 0) v.Position = UDim2.new(0.35, 0, 0, 0) v.TextTruncate = Enum.TextTruncate.AtEnd
        return v
    end

    local function toggleRow(parent, title, desc, key)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, desc and 42 or 34) row.BackgroundTransparency = 1 row.ZIndex = 55 row.LayoutOrder = ord(parent) row.Parent = parent
        local name = label(row, title, 13, Enum.Font.GothamBold, Theme.Text)
        name.Size = UDim2.new(1, -60, 0, desc and 20 or 34) name.Position = UDim2.new(0, 0, 0, desc and 2 or 0)
        if desc then
            local d = label(row, desc, 11, Enum.Font.GothamBold, Theme.TextDim)
            d.Size = UDim2.new(1, -60, 0, 16) d.Position = UDim2.new(0, 0, 0, 22) d.TextTruncate = Enum.TextTruncate.AtEnd
        end
        local sw = Instance.new("Frame")
        sw.Size = UDim2.new(0, 40, 0, 20) sw.Position = UDim2.new(1, -40, 0.5, -10) sw.BorderSizePixel = 0 sw.ZIndex = 56 sw.Parent = row
        corner(sw, 6)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16) knob.BorderSizePixel = 0 knob.ZIndex = 57 knob.Parent = sw
        corner(knob, 4)
        local state = cfg[key]
        local data = {Button = sw, State = state}
        table.insert(ColorableElements.Toggles, data)
        local function visual(v, animate)
            state = v data.State = v
            local ti = TweenInfo.new(animate and 0.2 or 0)
            TweenService:Create(sw, ti, {BackgroundColor3 = v and Theme.AccentPink or OFF}):Play()
            TweenService:Create(knob, ti, {
                Position = v and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                BackgroundColor3 = v and WHITE or Color3.fromRGB(130, 140, 165)
            }):Play()
        end
        visual(state, false)
        local hit = Instance.new("TextButton")
        hit.Size = UDim2.new(1, 0, 1, 0) hit.BackgroundTransparency = 1 hit.Text = "" hit.ZIndex = 58 hit.Parent = row
        tap(hit, function() local nv = not state visual(nv, true) commit(key, nv) end)
        ui[key] = function(v) visual(v, true) end
    end

    local function segmented(parent, title, options, onPick)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 58) row.BackgroundTransparency = 1 row.ZIndex = 55 row.LayoutOrder = ord(parent) row.Parent = parent
        local t = label(row, title, 13, Enum.Font.GothamBold, Theme.Text) t.Size = UDim2.new(1, 0, 0, 20)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, 0, 0, 30) bar.Position = UDim2.new(0, 0, 0, 24) bar.BackgroundTransparency = 1 bar.ZIndex = 55 bar.Parent = row
        local n = #options
        local g = Instance.new("UIGridLayout")
        g.CellSize = UDim2.new(1 / n, -math.ceil(6 * (n - 1) / n), 1, 0) g.CellPadding = UDim2.new(0, 6, 0, 0)
        g.SortOrder = Enum.SortOrder.LayoutOrder g.Parent = bar
        local buttons, selected = {}, 0
        local function refresh()
            for i, b in ipairs(buttons) do
                local on = (i == selected)
                b.BackgroundColor3 = on and Theme.AccentPink or OFF
                b.BackgroundTransparency = on and 0.8 or 0.3
                b.TextColor3 = on and Theme.AccentPink or Theme.TextDim
                local st = b:FindFirstChildOfClass("UIStroke") if st then st.Color = on and Theme.AccentPink or OFF end
            end
        end
        for i, opt in ipairs(options) do
            local b = Instance.new("TextButton")
            b.AutoButtonColor = false b.Font = Enum.Font.GothamBold b.TextSize = 12 b.Text = opt.text
            b.BorderSizePixel = 0 b.LayoutOrder = i b.ZIndex = 56 b.Parent = bar
            corner(b, 8) stroke(b, OFF, 1, 0.2)
            tap(b, function() selected = i refresh() onPick(opt.value, i) end)
            buttons[i] = b
        end
        table.insert(accentCallbacks, refresh)
        return function(i) selected = i refresh() end
    end
    local function nearest(options, v)
        local best, bd = 1, math.huge
        for i, o in ipairs(options) do
            local d = math.abs(o.value - v)
            if d < bd then bd = d best = i end
        end
        return best
    end

    local activeDrag = nil
    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            activeDrag(input.Position.X)
        end
    end))
    table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
        if activeDrag and isPress(input) then
            activeDrag = nil
            settingsTab.ScrollingEnabled = true
        end
    end))

    local function sliderRow(parent, title, key, min, max, fmt)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 48) row.BackgroundTransparency = 1 row.ZIndex = 55 row.LayoutOrder = ord(parent) row.Parent = parent
        local name = label(row, title, 13, Enum.Font.GothamBold, Theme.Text) name.Size = UDim2.new(0.65, 0, 0, 20)
        local valLbl = label(row, "", 13, Enum.Font.GothamBlack, Theme.AccentPink, Enum.TextXAlignment.Right)
        valLbl.Size = UDim2.new(0.35, 0, 0, 20) valLbl.Position = UDim2.new(0.65, 0, 0, 0)
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, 0, 0, 6) track.Position = UDim2.new(0, 0, 0, 32) track.BackgroundColor3 = Color3.fromRGB(30, 36, 54)
        track.BorderSizePixel = 0 track.ZIndex = 56 track.Parent = row
        corner(track, 3)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0) fill.BackgroundColor3 = Theme.AccentPink fill.BorderSizePixel = 0 fill.ZIndex = 57 fill.Parent = track
        corner(fill, 3)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16) knob.AnchorPoint = Vector2.new(0.5, 0.5) knob.Position = UDim2.new(0, 0, 0.5, 0)
        knob.BackgroundColor3 = WHITE knob.BorderSizePixel = 0 knob.ZIndex = 58 knob.Parent = track
        corner(knob, 8) stroke(knob, Theme.AccentPink, 2, 0)
        local function visual(v)
            local frac = math.clamp((v - min) / (max - min), 0, 1)
            fill.Size = UDim2.new(frac, 0, 1, 0)
            knob.Position = UDim2.new(frac, 0, 0.5, 0)
            valLbl.Text = fmt(v)
        end
        visual(cfg[key])
        local hit = Instance.new("TextButton")
        hit.Size = UDim2.new(1, 0, 0, 30) hit.Position = UDim2.new(0, 0, 0, 20) hit.BackgroundTransparency = 1 hit.Text = "" hit.ZIndex = 59 hit.Parent = row
        local function update(x)
            local w = track.AbsoluteSize.X
            if w <= 0 then return end
            local frac = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
            local v = math.floor((min + frac * (max - min)) * 100 + 0.5) / 100
            visual(v) commit(key, v)
        end
        hit.InputBegan:Connect(function(input)
            if isPress(input) then
                activeDrag = update
                settingsTab.ScrollingEnabled = false
                update(input.Position.X)
            end
        end)
        ui[key] = visual
        table.insert(accentCallbacks, function(c)
            fill.BackgroundColor3 = c valLbl.TextColor3 = c
            local ks = knob:FindFirstChildOfClass("UIStroke") if ks then ks.Color = c end
        end)
    end

    local function inputRow(parent, placeholder, defaultText, btnText, onApply)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 36) row.BackgroundTransparency = 1 row.ZIndex = 55 row.LayoutOrder = ord(parent) row.Parent = parent
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -88, 1, 0) box.BackgroundColor3 = Theme.MainBG box.BackgroundTransparency = 0.2
        box.TextColor3 = Theme.Text box.PlaceholderText = placeholder box.PlaceholderColor3 = Theme.TextDim box.Text = defaultText
        box.TextSize = 13 box.Font = Enum.Font.GothamBold box.BorderSizePixel = 0 box.ClearTextOnFocus = false box.ZIndex = 56 box.Parent = row
        corner(box, 8) stroke(box, OFF, 1, 0.1)
        local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0, 10) pad.Parent = box
        local b = makeBtn(row, btnText, Theme.AccentPink, function() onApply(box.Text, box) end)
        b.Size = UDim2.new(0, 80, 1, 0) b.Position = UDim2.new(1, -80, 0, 0)
        return box
    end

    -- ========== CARD 1: GIAO DIỆN ==========
    local cardUI = makeCard(1, "🎨", "GIAO DIỆN", Theme.AccentPink)
    safe(function()
        local t = label(cardUI, "Màu chủ đạo", 13, Enum.Font.GothamBold, Theme.Text)
        t.Size = UDim2.new(1, 0, 0, 18) t.LayoutOrder = ord(cardUI)
        local sw = Instance.new("Frame")
        sw.Size = UDim2.new(1, 0, 0, 34) sw.BackgroundTransparency = 1 sw.ZIndex = 55 sw.LayoutOrder = ord(cardUI) sw.Parent = cardUI
        local swl = Instance.new("UIListLayout")
        swl.FillDirection = Enum.FillDirection.Horizontal swl.Padding = UDim.new(0, 10) swl.VerticalAlignment = Enum.VerticalAlignment.Center swl.Parent = sw
        local colors = {
            {52, 232, 158}, {56, 189, 248}, {99, 125, 255}, {255, 87, 110},
            {255, 159, 67}, {250, 204, 21}, {167, 110, 255}, {255, 105, 200}
        }
        local swBtns = {}
        for i, c in ipairs(colors) do
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 28, 0, 28) b.BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3]) b.Text = ""
            b.AutoButtonColor = false b.BorderSizePixel = 0 b.LayoutOrder = i b.ZIndex = 56 b.Parent = sw
            corner(b, 14)
            local st = stroke(b, WHITE, 0, 0)
            tap(b, function() setAll("accent", {c[1], c[2], c[3]}) end)
            swBtns[i] = {btn = b, stroke = st, c = c}
        end
        local function markSelected(t3)
            for _, s in ipairs(swBtns) do
                local d = math.abs(s.c[1] - t3[1]) + math.abs(s.c[2] - t3[2]) + math.abs(s.c[3] - t3[3])
                s.stroke.Thickness = d < 6 and 2.5 or 0
            end
        end
        ui.accent = markSelected
        markSelected(cfg.accent)

        inputRow(cardUI, "Mã màu HEX, VD: FF3366", "", "Áp dụng", function(txt, box)
            local hex = string.gsub(txt, "[#%s]", "")
            if #hex ~= 6 or string.find(hex, "[^%x]") then notify("Mã HEX không hợp lệ (cần 6 ký tự)", RED) return end
            local ok, col = pcall(function() return Color3.fromHex(hex) end)
            if not ok or not col then notify("Mã HEX không hợp lệ", RED) return end
            setAll("accent", {math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5)})
            notify("Đã đổi màu chủ đạo #" .. string.upper(hex), col)
        end)
    end)
    safe(function()
        sliderRow(cardUI, "Độ trong suốt menu", "alpha", 0, 0.9, function(v) return math.floor(v * 100 + 0.5) .. "%" end)

        local scaleOpts = {{text = "Nhỏ", value = 0.7}, {text = "Vừa", value = 0.85}, {text = "Lớn", value = 1}, {text = "Rất lớn", value = 1.2}}
        local selScale = segmented(cardUI, "Kích thước menu", scaleOpts, function(v) commit("scale", v) end)
        ui.scale = function(v) selScale(nearest(scaleOpts, v)) end
        ui.scale(cfg.scale)

        local iconOpts = {{text = "Nhỏ", value = 40}, {text = "Vừa", value = 50}, {text = "Lớn", value = 64}}
        local selIcon = segmented(cardUI, "Kích thước nút mở menu", iconOpts, function(v) commit("iconSize", v) end)
        ui.iconSize = function(v) selIcon(nearest(iconOpts, v)) end
        ui.iconSize(cfg.iconSize)
    end)
    safe(function()
        toggleRow(cardUI, "Hiệu ứng động", "Tắt để tiết kiệm pin, máy mượt hơn", "anim")
        toggleRow(cardUI, "Làm mờ nền khi mở menu", "Hiệu ứng blur phía sau menu", "blur")
        toggleRow(cardUI, "Hiện ảnh nền menu", nil, "bgVisible")
        local bgBox = inputRow(cardUI, "Nhập ID ảnh nền, VD: 13476434849", defaults.bgId, "Áp dụng", function(txt)
            local id = string.gsub(txt, "[^%d]", "")
            if id == "" then notify("ID ảnh không hợp lệ", RED) return end
            setAll("bgId", id)
            notify("Đã đổi ảnh nền", Theme.AccentPink)
        end)
        ui.bgId = function(v) bgBox.Text = tostring(v) end
    end)

    -- ========== CARD 2: TIỆN ÍCH ==========
    local cardUtil = makeCard(2, "⚙️", "TIỆN ÍCH", Theme.AccentCyan)
    safe(function()
        local fpsOpts = {{text = "30", value = 30}, {text = "60", value = 60}, {text = "120", value = 120}, {text = "240", value = 240}, {text = "∞", value = 0}}
        local selFps = segmented(cardUtil, "Giới hạn FPS", fpsOpts, function(v)
            if not setfpscap then notify("Executor không hỗ trợ đổi FPS", RED) return end
            pcall(setfpscap, v)
            notify(v == 0 and "FPS: không giới hạn" or ("Giới hạn FPS: " .. v), Theme.AccentCyan)
        end)
        selFps(2)
        toggleRow(cardUtil, "Thông báo", "Hiện thông báo nhỏ khi thao tác", "toasts")
    end)

    -- ========== CARD 3: CẤU HÌNH ==========
    local cardCfg = makeCard(3, "💾", "CẤU HÌNH", Theme.AccentGold)
    local function loadConfig(silent)
        if not (isfile and readfile) then
            if not silent then notify("Executor không hỗ trợ đọc file", RED) end
            return
        end
        local okE, exists = pcall(isfile, CONFIG_FILE)
        if not (okE and exists) then
            if not silent then notify("Chưa có file cấu hình", Theme.AccentGold) end
            return
        end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
        if not ok or type(data) ~= "table" then notify("File cấu hình bị lỗi", RED) return end
        loading = true
        for k, dv in pairs(defaults) do
            local v = data[k]
            if v ~= nil and type(v) == type(dv) then
                if k == "accent" then
                    if #v == 3 then
                        setAll(k, {math.clamp(tonumber(v[1]) or 0, 0, 255), math.clamp(tonumber(v[2]) or 0, 0, 255), math.clamp(tonumber(v[3]) or 0, 0, 255)})
                    end
                elseif k == "alpha" then setAll(k, math.clamp(v, 0, 0.9))
                elseif k == "scale" then setAll(k, math.clamp(v, 0.5, 1.5))
                elseif k == "iconSize" then setAll(k, math.clamp(v, 36, 72))
                else setAll(k, v) end
            end
        end
        loading = false
        if not silent then notify("Đã tải cấu hình", GREEN) end
    end
    local function resetAll()
        loading = true
        for k, dv in pairs(defaults) do
            if k == "accent" then setAll(k, {dv[1], dv[2], dv[3]}) else setAll(k, dv) end
        end
        menu.Position = UDim2.new(0.5, 0, 0.5, 0)
        loading = false
        scheduleSave()
        notify("Đã khôi phục giao diện mặc định", Theme.AccentGold)
    end
    safe(function()
        toggleRow(cardCfg, "Tự động lưu", "Tự lưu mỗi khi bạn đổi cài đặt giao diện", "autoSave")
        buttonGrid(cardCfg, {
            {"💾 Lưu cấu hình", Theme.AccentGold, function()
                if not writefile then notify("Executor không hỗ trợ ghi file", RED) return end
                local ok = writeConfig()
                notify(ok and "Đã lưu cấu hình" or "Lưu cấu hình thất bại", ok and GREEN or RED)
            end},
            {"📂 Tải cấu hình", Theme.AccentCyan, function() loadConfig(false) end}
        })
        actionBtn(cardCfg, "🔄 Khôi phục giao diện mặc định", Theme.AccentGold, resetAll)
    end)

    -- ========== CARD 4: SERVER ==========
    local cardSrv = makeCard(4, "🌐", "THÔNG TIN SERVER", Theme.AccentPurple)
    safe(function()
        local execName = "Không rõ"
        if identifyexecutor then
            local ok, n = pcall(identifyexecutor)
            if ok and n then execName = tostring(n) end
        end
        kv(cardSrv, "Executor", execName, Theme.AccentCyan)
        local playersVal = kv(cardSrv, "Người chơi", #Players:GetPlayers() .. "/" .. Players.MaxPlayers)
        kv(cardSrv, "Place ID", tostring(game.PlaceId))
        local jid = game.JobId ~= "" and game.JobId or "Studio / không có"
        kv(cardSrv, "Job ID", #jid > 18 and (string.sub(jid, 1, 8) .. "…" .. string.sub(jid, -6)) or jid)
        task.spawn(function()
            while settingsTab.Parent do
                playersVal.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
                task.wait(3)
            end
        end)
        local function copyText(str, okMsg)
            local fn = setclipboard or toclipboard
            if fn then
                local ok = pcall(fn, str)
                if ok then notify(okMsg, Theme.AccentPurple) return end
            end
            notify("Executor không hỗ trợ sao chép", RED)
        end
        buttonGrid(cardSrv, {
            {"📋 Job ID", Theme.AccentPurple, function() copyText(game.JobId, "Đã sao chép Job ID") end},
            {"📋 Place ID", Theme.AccentPurple, function() copyText(tostring(game.PlaceId), "Đã sao chép Place ID") end},
            {"🔗 Link vào server", Theme.AccentPurple, function()
                copyText("roblox://experiences/start?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId, "Đã sao chép link vào server")
            end}
        })
    end)

    -- ========== CARD 5: PHÍM TẮT ==========
    local cardKeys = makeCard(5, "⌨️", "PHÍM TẮT & HƯỚNG DẪN", Theme.AccentCyan)
    safe(function()
        local function keyRow(keyText, desc)
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 24) row.BackgroundTransparency = 1 row.ZIndex = 55 row.LayoutOrder = ord(cardKeys) row.Parent = cardKeys
            local chipK = label(row, keyText, 11, Enum.Font.Code, Theme.AccentCyan, Enum.TextXAlignment.Center)
            chipK.Size = UDim2.new(0, 100, 0, 22) chipK.Position = UDim2.new(0, 0, 0, 1) chipK.BackgroundColor3 = Theme.AccentCyan chipK.BackgroundTransparency = 0.85
            corner(chipK, 6) stroke(chipK, Theme.AccentCyan, 1, 0.55)
            local d = label(row, desc, 12, Enum.Font.GothamBold, Theme.Text)
            d.Size = UDim2.new(1, -112, 1, 0) d.Position = UDim2.new(0, 112, 0, 0) d.TextTruncate = Enum.TextTruncate.AtEnd
        end
        keyRow("RightShift", "Ẩn / hiện menu")
        keyRow("RightCtrl", "Ẩn / hiện icon avatar")
        keyRow("RightAlt", "Reset vị trí & kích thước")
        local tip = label(cardKeys, "📱 Điện thoại: chạm icon avatar để mở/đóng menu, kéo icon hoặc thanh tiêu đề để di chuyển.", 12, Enum.Font.GothamBold, Theme.TextDim)
        tip.Size = UDim2.new(1, 0, 0, 34) tip.TextWrapped = true tip.TextYAlignment = Enum.TextYAlignment.Top tip.LayoutOrder = ord(cardKeys)
    end)

    -- ========== CARD 6: NGUY HIỂM ==========
    local cardDanger = makeCard(6, "⚠️", "VÙNG NGUY HIỂM", RED)
    safe(function()
        local unloadBtn
        local armed = false
        unloadBtn = actionBtn(cardDanger, "⏻ GỠ UI & DỪNG SCRIPT", RED, function()
            if not armed then
                armed = true
                unloadBtn.Text = "⚠ NHẤN LẦN NỮA ĐỂ XÁC NHẬN"
                task.delay(3, function()
                    armed = false
                    if unloadBtn and unloadBtn.Parent then unloadBtn.Text = "⏻ GỠ UI & DỪNG SCRIPT" end
                end)
                return
            end
            if getgenv().HTrungCleanup then getgenv().HTrungCleanup() end
        end)
    end)

    -- ========== KHỞI TẠO & TỰ ĐỘNG TẢI ==========
    safe(function()
        loading = true
        for k, fn in pairs(apply) do fn(cfg[k]) end
        loading = false
        loadConfig(true)
    end)
end
end)

pcall(Skin.all)
ColorableElements.SelectFirst()

-- ==========================================
-- LOGIC UPDATES & HEARTBEAT
-- ==========================================
local lastFpsUpdate = tick() local frameCount = 0
table.insert(Connections, RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    if tick() - lastFpsUpdate >= 1 then
        currentFps = frameCount frameCount = 0 lastFpsUpdate = tick()
        fpsLabel.Text = tostring(currentFps) fpsLabel.TextColor3 = currentFps >= 50 and Color3.fromRGB(80, 255, 140) or (currentFps >= 30 and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(255, 70, 90))
    end
end))

task.spawn(function()
    while task.wait(1) do
        pcall(function() currentPing = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        pingLabel.Text = currentPing .. " ms" pingLabel.TextColor3 = currentPing <= 80 and Color3.fromRGB(80, 255, 140) or (currentPing <= 150 and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(255, 70, 90))
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = char.HumanoidRootPart.Position
            posLabel.Text = string.format("%d, %d, %d", pos.X, pos.Y, pos.Z)
        end
        timeLbl.Text = os.date("%H:%M:%S")
        local playSecs = math.floor(tick() - joinTime)
        playtimeLbl.Text = string.format("%02d:%02d:%02d", math.floor(playSecs/3600), math.floor((playSecs%3600)/60), playSecs%60)
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