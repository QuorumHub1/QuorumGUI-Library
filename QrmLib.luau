print"dsioasdduisjsduisdyuidsyusdiudsyiusdduiassdyuisdaiu"
local _oldQrm = getgenv and getgenv().QuorumLib
if _oldQrm and _oldQrm.Unload then
    pcall(function() _oldQrm:Unload() end)
end

local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();
local HttpService = game:GetService('HttpService');

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local IsTouchDevice = InputService.TouchEnabled and not InputService.KeyboardEnabled;
local IsMobile = IsTouchDevice;

local function GetInputPosition(Input)
    if Input and (Input.UserInputType == Enum.UserInputType.Touch or Input.UserInputType == Enum.UserInputType.MouseMovement) then
        return Vector2.new(Input.Position.X, Input.Position.Y)
    end
    return Vector2.new(Mouse.X, Mouse.Y)
end

local function GetCursorPosition()
    return Vector2.new(Mouse.X, Mouse.Y)
end

local function IsPrimaryPress(Input)
    return Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch
end

local function IsSecondaryPress(Input)
    if IsTouchDevice then return false end
    return Input.UserInputType == Enum.UserInputType.MouseButton2
end

local function IsPrimaryHeld()
    if IsTouchDevice then return #InputService:GetMouseLocations() > 0 end
    return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
end

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.IgnoreGuiInset = true;
ScreenGui.ResetOnSpawn = false;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local QuorumLib = {
    Registry = {};
    RegistryMap = {},
    HudRegistry = {},
    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(26, 27, 38);
    BackgroundColor = Color3.fromRGB(22, 22, 30);
    AccentColor = Color3.fromRGB(122, 162, 247);
    OutlineColor = Color3.fromRGB(41, 46, 66);
    RiskColor = Color3.fromRGB(255, 50, 50),
    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,
    OpenedFrames = {};
    DependencyBoxes = {};
    Signals = {};
    ScreenGui = ScreenGui;
    UseCustomCursor = true;
    MobileToggle = nil;
    KeybindFrame = nil;
    CursorThread = nil;
    CursorDrawing = nil;
    CursorOutlineDrawing = nil;
    MenuToggled = false;
    UnlockCamera = true;
    NotificationAreas = {};
    UseIcons = false;
    IconCache = {};
    IconAssetCache = {};
    LoadingIcons = {};
};

local RainbowStep = 0
local Hue = 0

table.insert(QuorumLib.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0
        Hue = Hue + (1 / 400);
        if Hue > 1 then Hue = 0; end;
        QuorumLib.CurrentRainbowHue = Hue;
        QuorumLib.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();
    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;
    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);
    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();
    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;
    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    return TeamList;
end;

local function FetchIcon(Name)
    if QuorumLib.IconAssetCache[Name] then
        return QuorumLib.IconAssetCache[Name]
    end
    
    if not QuorumLib.LoadingIcons[Name] then
        QuorumLib.LoadingIcons[Name] = true
        task.spawn(function()
            local rawUrl = "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/" .. Name .. ".svg"
            local success, data = pcall(function() return game:HttpGet(rawUrl) end)
            if success and data and #data > 0 then
                local path = "QuorumLib/Icons"
                if isfolder and not isfolder(path) then makefolder(path) end
                if isfolder and not isfolder(path .. "/lucide") then makefolder(path .. "/lucide") end
                local file = path .. "/lucide/" .. Name .. ".svg"
                if writefile then
                    pcall(writefile, file, data)
                    if getcustomasset then
                        local assetSuccess, asset = pcall(getcustomasset, file)
                        if assetSuccess then
                            QuorumLib.IconAssetCache[Name] = asset
                        end
                    end
                end
            end
            QuorumLib.LoadingIcons[Name] = nil
        end)
    end
    return nil
end

function QuorumLib:ParseIcon(Text)
    local iconName = string.match(Text, "<([%w%-_]+)>")
    if iconName then
        local cleanText = string.gsub(Text, "<" .. iconName .. ">%s*", "")
        return iconName, cleanText
    end
    return nil, Text
end

function QuorumLib:SafeCallback(f, ...)
    if (not f) then return; end;
    if not QuorumLib.NotifyOnError then return f(...); end;
    local success, event = pcall(f, ...);
    if not success then
        local _, i = event:find(":%d+: ");
        if not i then return QuorumLib:Notify(event); end;
        return QuorumLib:Notify(event:sub(i + 1), 3);
    end;
end;

function QuorumLib:AttemptSave()
    if QuorumLib.SaveManager then
        QuorumLib.SaveManager:Save();
    end;
end;

function QuorumLib:Create(Class, Properties)
    local _Instance = Class;
    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;
    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;
    return _Instance;
end;

function QuorumLib:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;
    QuorumLib:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function QuorumLib:CreateLabel(Properties, IsHud)
    local _Instance = QuorumLib:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = QuorumLib.Font;
        TextColor3 = QuorumLib.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    });

    QuorumLib:ApplyTextStroke(_Instance);
    QuorumLib:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return QuorumLib:Create(_Instance, Properties);
end;

function QuorumLib:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;
    local Dragging = false
    local DragStart
    local StartPosition

    Instance.InputBegan:Connect(function(Input)
        if not IsPrimaryPress(Input) then return end
        local StartPos = GetInputPosition(Input)
        local Relative = StartPos - Instance.AbsolutePosition
        if Relative.Y > (Cutoff or 40) then return end

        Dragging = true
        DragStart = StartPos
        StartPosition = Instance.Position
    end)

    InputService.InputChanged:Connect(function(Input)
        if not Dragging then return end
        if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then return end

        local Cur = GetInputPosition(Input)
        local Delta = Cur - DragStart

        Instance.Position = UDim2.new(
            StartPosition.X.Scale,
            StartPosition.X.Offset + Delta.X,
            StartPosition.Y.Scale,
            StartPosition.Y.Offset + Delta.Y
        )
    end)

    InputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging = false
            DragStart = nil
        end
    end)
end

function QuorumLib:AddToolTip(InfoStr, HoverInstance)
    local X, Y = QuorumLib:GetTextBounds(InfoStr, QuorumLib.Font, 14);
    local Tooltip = QuorumLib:Create('Frame', {
        BackgroundColor3 = QuorumLib.MainColor,
        BorderColor3 = QuorumLib.OutlineColor,
        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100,
        Parent = QuorumLib.ScreenGui,
        Visible = false,
    })

    local Label = QuorumLib:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y);
        TextSize = 14;
        Text = InfoStr,
        TextColor3 = QuorumLib.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,
        Parent = Tooltip;
    });

    QuorumLib:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    QuorumLib:AddToRegistry(Label, {
        TextColor3 = 'FontColor';
    });

    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if IsTouchDevice then return end
        if QuorumLib:MouseIsOverOpenedFrame() then return end

        IsHovering = true
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function QuorumLib:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = QuorumLib.RegistryMap[Instance];
        for Property, ColorIdx in next, Properties do
            Instance[Property] = QuorumLib[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = QuorumLib.RegistryMap[Instance];
        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = QuorumLib[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function QuorumLib:MouseIsOverOpenedFrame()
    for Frame, _ in next, QuorumLib.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
            return true;
        end;
    end;
end;

function QuorumLib:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
        return true;
    end;
end;

function QuorumLib:UpdateDependencyBoxes()
    for _, Depbox in next, QuorumLib.DependencyBoxes do
        Depbox:Update();
    end;
end;

function QuorumLib:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function QuorumLib:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function QuorumLib:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
QuorumLib.AccentColorDark = QuorumLib:GetDarkerColor(QuorumLib.AccentColor);

function QuorumLib:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #QuorumLib.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };
    table.insert(QuorumLib.Registry, Data);
    QuorumLib.RegistryMap[Instance] = Data;
    if IsHud then table.insert(QuorumLib.HudRegistry, Data); end;
end;

function QuorumLib:RemoveFromRegistry(Instance)
    local Data = QuorumLib.RegistryMap[Instance];
    if Data then
        for Idx = #QuorumLib.Registry, 1, -1 do
            if QuorumLib.Registry[Idx] == Data then table.remove(QuorumLib.Registry, Idx); end;
        end;
        for Idx = #QuorumLib.HudRegistry, 1, -1 do
            if QuorumLib.HudRegistry[Idx] == Data then table.remove(QuorumLib.HudRegistry, Idx); end;
        end;
        QuorumLib.RegistryMap[Instance] = nil;
    end;
end;

function QuorumLib:UpdateColorsUsingRegistry()
    for Idx, Object in next, QuorumLib.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = QuorumLib[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function QuorumLib:GiveSignal(Signal)
    table.insert(QuorumLib.Signals, Signal)
end

local function SpawnCustomCursor()
    if QuorumLib.CursorThread then return end
    if IsTouchDevice then return end

    local InitialState = InputService.MouseIconEnabled;
    
    QuorumLib.CursorDrawing = Drawing.new('Triangle');
    QuorumLib.CursorDrawing.Thickness = 1;
    QuorumLib.CursorDrawing.Filled = true;
    QuorumLib.CursorDrawing.Visible = false;
    
    QuorumLib.CursorOutlineDrawing = Drawing.new('Triangle');
    QuorumLib.CursorOutlineDrawing.Thickness = 1;
    QuorumLib.CursorOutlineDrawing.Filled = false;
    QuorumLib.CursorOutlineDrawing.Color = Color3.new(0, 0, 0);
    QuorumLib.CursorOutlineDrawing.Visible = false;

    QuorumLib.CursorThread = task.spawn(function()
        while QuorumLib.MenuToggled and QuorumLib.UseCustomCursor and ScreenGui.Parent do
            InputService.MouseIconEnabled = false;
            
            if QuorumLib.UnlockCamera then
                local isFirstPerson = LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson
                local isShiftLock = InputService.MouseBehavior == Enum.MouseBehavior.LockCenter
                
                if isFirstPerson or isShiftLock then
                    InputService.MouseBehavior = Enum.MouseBehavior.Default
                end
            end
            
            local mPos = InputService:GetMouseLocation();
            QuorumLib.CursorDrawing.Color = QuorumLib.AccentColor;
            QuorumLib.CursorDrawing.Visible = true;
            QuorumLib.CursorOutlineDrawing.Visible = true;
            
            QuorumLib.CursorDrawing.PointA = Vector2.new(mPos.X, mPos.Y);
            QuorumLib.CursorDrawing.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6);
            QuorumLib.CursorDrawing.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16);
            
            QuorumLib.CursorOutlineDrawing.PointA = QuorumLib.CursorDrawing.PointA;
            QuorumLib.CursorOutlineDrawing.PointB = QuorumLib.CursorDrawing.PointB;
            QuorumLib.CursorOutlineDrawing.PointC = QuorumLib.CursorDrawing.PointC;
            
            RunService.RenderStepped:Wait();
        end
        
        InputService.MouseIconEnabled = InitialState;
        if QuorumLib.CursorDrawing then QuorumLib.CursorDrawing.Visible = false; QuorumLib.CursorDrawing:Remove(); QuorumLib.CursorDrawing = nil; end
        if QuorumLib.CursorOutlineDrawing then QuorumLib.CursorOutlineDrawing.Visible = false; QuorumLib.CursorOutlineDrawing:Remove(); QuorumLib.CursorOutlineDrawing = nil; end
        
        QuorumLib.CursorThread = nil
    end)
end

function QuorumLib:SetCustomCursor(Enabled)
    QuorumLib.UseCustomCursor = Enabled and true or false;
    if QuorumLib.UseCustomCursor and QuorumLib.MenuToggled then
        SpawnCustomCursor()
    end
end;

function QuorumLib:SetKeybindVisibility(Bool)
    if QuorumLib.KeybindFrame then
        QuorumLib.KeybindFrame.Visible = Bool and true or false;
    end
end

function QuorumLib:Unload()
    for Idx = #QuorumLib.Signals, 1, -1 do
        local Connection = table.remove(QuorumLib.Signals, Idx)
        Connection:Disconnect()
    end

    if QuorumLib.OnUnload then QuorumLib.OnUnload() end

    if QuorumLib.MobileToggle then
        pcall(function() QuorumLib.MobileToggle:Destroy() end)
        QuorumLib.MobileToggle = nil
    end

    if getgenv and getgenv().QuorumLib == QuorumLib then
        getgenv().QuorumLib = nil
    end

    ScreenGui:Destroy()
end

function QuorumLib:OnUnload(Callback)
    QuorumLib.OnUnload = Callback
end

QuorumLib:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if QuorumLib.RegistryMap[Instance] then
        QuorumLib:RemoveFromRegistry(Instance);
    end;
end))

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);
            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = QuorumLib:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = QuorumLib:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 28, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        local CheckerFrame = QuorumLib:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });

        local PickerFrameOuter = QuorumLib:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end)

        local PickerFrameInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.BackgroundColor;
            BorderColor3 = QuorumLib.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });

        local Highlight = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapOuter = QuorumLib:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.BackgroundColor;
            BorderColor3 = QuorumLib.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });

        local SatVibMap = QuorumLib:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });

        local CursorOuter = QuorumLib:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        local CursorInner = QuorumLib:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = QuorumLib:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });

        local HueCursor = QuorumLib:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = QuorumLib:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });

        local HueBoxInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.MainColor;
            BorderColor3 = QuorumLib.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });

        QuorumLib:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = QuorumLib:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = QuorumLib.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = QuorumLib.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });

        QuorumLib:ApplyTextStroke(HueBox);

        local RgbBoxBase = QuorumLib:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });

        local RgbBox = QuorumLib:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = QuorumLib.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;

        if Info.Transparency then
            TransparencyBoxOuter = QuorumLib:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = QuorumLib:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = QuorumLib.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });

            QuorumLib:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

            QuorumLib:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });

            TransparencyCursor = QuorumLib:Create('Frame', {
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = QuorumLib:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title,--Info.Default;
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });

        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = QuorumLib:Create('Frame', {
                BorderColor3 = Color3.new(),
                ZIndex = 14,
                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = QuorumLib:Create('Frame', {
                BackgroundColor3 = QuorumLib.BackgroundColor;
                BorderColor3 = QuorumLib.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            });

            QuorumLib:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });

            QuorumLib:Create('UIPadding', {
                Name = 'Padding',
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            QuorumLib:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            function ContextMenu:Show()
                self.Container.Visible = true
            end

            function ContextMenu:Hide()
                self.Container.Visible = false
            end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then
                    Callback = function() end
                end

                local Button = QuorumLib:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });

                QuorumLib:OnHighlight(Button, Button,
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );

                Button.InputBegan:Connect(function(Input)
                    if not IsPrimaryPress(Input) then return end
                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                QuorumLib.ColorClipboard = ColorPicker.Value
                QuorumLib:Notify('Copied color!', 2)
            end)

            ContextMenu:AddOption('Paste color', function()
                if not QuorumLib.ColorClipboard then
                    return QuorumLib:Notify('You have not copied a color!', 2)
                end
                ColorPicker:SetValueRGB(QuorumLib.ColorClipboard)
            end)

            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                QuorumLib:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                QuorumLib:Notify('Copied RGB values to clipboard!', 2)
            end)

        end

        QuorumLib:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        QuorumLib:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        QuorumLib:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        QuorumLib:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        QuorumLib:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        QuorumLib:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        QuorumLib:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        local HueSelectorGradient = QuorumLib:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end
            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end
            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            QuorumLib:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = QuorumLib:GetDarkerColor(ColorPicker.Value);
            });

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            QuorumLib:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            QuorumLib:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        function ColorPicker:Show()
            for Frame, Val in next, QuorumLib.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    QuorumLib.OpenedFrames[Frame] = nil;
                end;
            end
            PickerFrameOuter.Visible = true;
            QuorumLib.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            QuorumLib.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if not IsPrimaryPress(Input) then return end
            while IsPrimaryHeld() do
                local M = GetCursorPosition()
                local MinX = SatVibMap.AbsolutePosition.X;
                local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                local MouseX = math.clamp(M.X, MinX, MaxX);
                local MinY = SatVibMap.AbsolutePosition.Y;
                local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                local MouseY = math.clamp(M.Y, MinY, MaxY);
                ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                ColorPicker:Display();
                RenderStepped:Wait();
            end;
            QuorumLib:AttemptSave();
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if not IsPrimaryPress(Input) then return end
            while IsPrimaryHeld() do
                local M = GetCursorPosition()
                local MinY = HueSelectorInner.AbsolutePosition.Y;
                local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                local MouseY = math.clamp(M.Y, MinY, MaxY);
                ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                ColorPicker:Display();
                RenderStepped:Wait();
            end;
            QuorumLib:AttemptSave();
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if IsPrimaryPress(Input) and not QuorumLib:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            elseif IsSecondaryPress(Input) and not QuorumLib:MouseIsOverOpenedFrame() then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if not IsPrimaryPress(Input) then return end
                while IsPrimaryHeld() do
                    local M = GetCursorPosition()
                    local MinX = TransparencyBoxInner.AbsolutePosition.X;
                    local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                    local MouseX = math.clamp(M.X, MinX, MaxX);
                    ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));
                    ColorPicker:Display();
                    RenderStepped:Wait();
                end;
                QuorumLib:AttemptSave();
            end);
        end;

        QuorumLib:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if IsPrimaryPress(Input) then
                local M = GetCursorPosition()
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;
                if M.X < AbsPos.X or M.X > AbsPos.X + AbsSize.X
                    or M.Y < (AbsPos.Y - 20 - 1) or M.Y > AbsPos.Y + AbsSize.Y then
                    ColorPicker:Hide();
                end;
                if not QuorumLib:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end;
            if IsSecondaryPress(Input) and ContextMenu.Container.Visible then
                if not QuorumLib:IsMouseOverFrame(ContextMenu.Container) and not QuorumLib:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame
        Options[Idx] = ColorPicker;
        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;
        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle';
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;
            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = QuorumLib:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        local PickInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.BackgroundColor;
            BorderColor3 = QuorumLib.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        });

        QuorumLib:AddToRegistry(PickInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local DisplayLabel = QuorumLib:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        });

        local ModeSelectOuter = QuorumLib:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60, 0, 45 + 2);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);

        local ModeSelectInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.BackgroundColor;
            BorderColor3 = QuorumLib.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        });

        QuorumLib:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        QuorumLib:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });

        local ContainerLabel = QuorumLib:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18);
            TextSize = 13;
            Visible = false;
            ZIndex = 110;
            Parent = QuorumLib.KeybindContainer;
        },  true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};

            local Label = QuorumLib:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect();
                end;
                KeyPicker.Mode = Mode;
                Label.TextColor3 = QuorumLib.AccentColor;
                QuorumLib.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';
                ModeSelectOuter.Visible = false;
            end;

            function ModeButton:Deselect()
                KeyPicker.Mode = nil;
                Label.TextColor3 = QuorumLib.FontColor;
                QuorumLib.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if IsPrimaryPress(Input) then
                    ModeButton:Select();
                    QuorumLib:AttemptSave();
                end
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;
            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then return; end;
            local State = KeyPicker:GetState();
            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);
            ContainerLabel.Visible = true;
            ContainerLabel.TextColor3 = State and QuorumLib.AccentColor or QuorumLib.FontColor;
            QuorumLib.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';

            local YSize = 0
            local XSize = 0
            for _, Label in next, QuorumLib.KeybindContainer:GetChildren() do
                if Label:IsA('TextLabel') and Label.Visible then
                    YSize = YSize + 18;
                    if (Label.TextBounds.X > XSize) then
                        XSize = Label.TextBounds.X
                    end
                end
            end;
            QuorumLib.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then return false; end
                local Key = KeyPicker.Value;
                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback) KeyPicker.Clicked = Callback end
        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then table.insert(ParentObj.Addons, KeyPicker) end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end
            QuorumLib:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            QuorumLib:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;

        PickOuter.InputBegan:Connect(function(Input)
            if IsPrimaryPress(Input) and not QuorumLib:MouseIsOverOpenedFrame() then
                Picking = true;
                DisplayLabel.Text = '';
                local Break;
                local Text = '';
                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then Text = ''; end;
                        Text = Text .. '.';
                        DisplayLabel.Text = Text;
                        wait(0.4);
                    end;
                end);

                wait(0.2);
                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;
                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    elseif Input.UserInputType == Enum.UserInputType.Touch then
                        Key = 'Touch';
                    end;
                    if not Key then return end
                    Break = true;
                    Picking = false;
                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;
                    QuorumLib:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    QuorumLib:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)
                    QuorumLib:AttemptSave();
                    Event:Disconnect();
                end);
            elseif IsSecondaryPress(Input) and not QuorumLib:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
            end
        end);

        QuorumLib:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;
                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                end;
                KeyPicker:Update();
            end;

            if IsPrimaryPress(Input) then
                local M = GetCursorPosition()
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;
                if M.X < AbsPos.X or M.X > AbsPos.X + AbsSize.X
                    or M.Y < (AbsPos.Y - 20 - 1) or M.Y > AbsPos.Y + AbsSize.Y then
                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        QuorumLib:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then KeyPicker:Update(); end;
        end))

        KeyPicker:Update();
        Options[Idx] = KeyPicker;
        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;
        QuorumLib:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            ZIndex = 1;
            Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local IconName, CleanText = QuorumLib:ParseIcon(Text)
        local Label = {};
        local Groupbox = self;
        local Container = Groupbox.Container;
        local TextLabel = QuorumLib:CreateLabel({
            Size = UDim2.new(1, IconName and -24 or -4, 0, 15);
            Position = UDim2.new(0, IconName and 24 or 0, 0, 0);
            TextSize = 14;
            Text = CleanText;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if IconName then
            local iconImage = QuorumLib:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 2);
                Size = UDim2.new(0, 14, 0, 14);
                Image = QuorumLib.IconAssetCache[IconName] or "",
                ImageColor3 = QuorumLib.FontColor,
                ZIndex = 5;
                Parent = Container;
            });
            if not QuorumLib.IconAssetCache[IconName] then
                task.spawn(function()
                    while not QuorumLib.IconAssetCache[IconName] do
                        FetchIcon(IconName)
                        task.wait(0.1)
                    end
                    iconImage.Image = QuorumLib.IconAssetCache[IconName]
                end)
            end
        end

        if DoesWrap then
            local Y = select(2, QuorumLib:GetTextBounds(CleanText, QuorumLib.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, IconName and -24 or -4, 0, Y)
        else
            QuorumLib:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(NewText)
            local NewIcon, NewClean = QuorumLib:ParseIcon(NewText)
            TextLabel.Text = NewClean
            if DoesWrap then
                local Y = select(2, QuorumLib:GetTextBounds(NewClean, QuorumLib.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, NewIcon and -24 or -4, 0, Y)
            end
            Groupbox:Resize();
        end;

        if (not DoesWrap) then setmetatable(Label, BaseAddons); end;
        Groupbox:AddBlank(5);
        Groupbox:Resize();
        return Label;
    end;

    function Funcs:AddButton(...)
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end
            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)
        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local IconName, CleanText = QuorumLib:ParseIcon(Button.Text)
            local Outer = QuorumLib:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20);
                ZIndex = 5;
            });

            local Inner = QuorumLib:Create('Frame', {
                BackgroundColor3 = QuorumLib.MainColor;
                BorderColor3 = QuorumLib.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            });

            local Label = QuorumLib:CreateLabel({
                Size = UDim2.new(1, IconName and -24 or 0, 1, 0);
                Position = UDim2.new(0, IconName and 24 or 0, 0, 0);
                TextSize = 14;
                Text = CleanText;
                ZIndex = 6;
                Parent = Inner;
            });

            if IconName then
                local iconImage = QuorumLib:Create('ImageLabel', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 6, 0.5, 0);
                    Size = UDim2.new(0, 14, 0, 14);
                    AnchorPoint = Vector2.new(0, 0.5);
                    Image = QuorumLib.IconAssetCache[IconName] or "",
                    ImageColor3 = QuorumLib.FontColor,
                    ZIndex = 7;
                    Parent = Inner;
                });
                if not QuorumLib.IconAssetCache[IconName] then
                    task.spawn(function()
                        while not QuorumLib.IconAssetCache[IconName] do
                            FetchIcon(IconName)
                            task.wait(0.1)
                        end
                        iconImage.Image = QuorumLib.IconAssetCache[IconName]
                    end)
                end
            end

            QuorumLib:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            });

            QuorumLib:AddToRegistry(Outer, { BorderColor3 = 'Black'; });
            QuorumLib:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

            QuorumLib:OnHighlight(Outer, Outer,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'Black' }
            );

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)
                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if QuorumLib:MouseIsOverOpenedFrame() then return false end
                if not IsPrimaryPress(Input) then return false end
                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    QuorumLib:RemoveFromRegistry(Button.Label)
                    QuorumLib:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })
                    Button.Label.TextColor3 = QuorumLib.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true
                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)
                    QuorumLib:RemoveFromRegistry(Button.Label)
                    QuorumLib:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })
                    Button.Label.TextColor3 = QuorumLib.FontColor
                    local IconName, CleanText = QuorumLib:ParseIcon(Button.Text)
                    Button.Label.Text = CleanText
                    task.defer(rawset, Button, 'Locked', false)
                    if clicked then QuorumLib:SafeCallback(Button.Func) end
                    return
                end

                QuorumLib:SafeCallback(Button.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container
        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then QuorumLib:AddToolTip(tooltip, self.Outer) end
            return self
        end

        function Button:AddButton(...)
            local SubButton = {}
            ProcessButtonParams('SubButton', SubButton, ...)
            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)
            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)
            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then QuorumLib:AddToolTip(tooltip, self.Outer) end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then SubButton:AddTooltip(SubButton.Tooltip) end
            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then Button:AddTooltip(Button.Tooltip) end
        Groupbox:AddBlank(5);
        Groupbox:Resize();
        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container
        local Divider = { Type = 'Divider', }
        Groupbox:AddBlank(2);
        local DividerOuter = QuorumLib:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 5);
            ZIndex = 5;
            Parent = Container;
        });

        local DividerInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.MainColor;
            BorderColor3 = QuorumLib.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DividerOuter;
        });

        QuorumLib:AddToRegistry(DividerOuter, { BorderColor3 = 'Black'; });
        QuorumLib:AddToRegistry(DividerInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

        Groupbox:AddBlank(9);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')
        local IconName, CleanText = QuorumLib:ParseIcon(Info.Text)
        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;
        local InputLabel = QuorumLib:CreateLabel({
            Size = UDim2.new(1, IconName and -24 or 0, 0, 15);
            Position = UDim2.new(0, IconName and 24 or 0, 0, 0);
            TextSize = 14;
            Text = CleanText;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if IconName then
            local iconImage = QuorumLib:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 2);
                Size = UDim2.new(0, 14, 0, 14);
                Image = QuorumLib.IconAssetCache[IconName] or "",
                ImageColor3 = QuorumLib.FontColor,
                ZIndex = 5;
                Parent = Container;
            });
            if not QuorumLib.IconAssetCache[IconName] then
                task.spawn(function()
                    while not QuorumLib.IconAssetCache[IconName] do
                        FetchIcon(IconName)
                        task.wait(0.1)
                    end
                    iconImage.Image = QuorumLib.IconAssetCache[IconName]
                end)
            end
        end

        Groupbox:AddBlank(1);
        local TextBoxOuter = QuorumLib:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        local TextBoxInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.MainColor;
            BorderColor3 = QuorumLib.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        });

        QuorumLib:AddToRegistry(TextBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        QuorumLib:OnHighlight(TextBoxOuter, TextBoxOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' });

        if type(Info.Tooltip) == 'string' then QuorumLib:AddToolTip(Info.Tooltip, TextBoxOuter) end

        QuorumLib:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        });

        local Container = QuorumLib:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            ZIndex = 7;
            Parent = TextBoxInner;
        })

        local Box = QuorumLib:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),
            Font = QuorumLib.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or '';
            Text = Info.Default or '';
            TextColor3 = QuorumLib.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 7;
            Parent = Container;
        });

        QuorumLib:ApplyTextStroke(Box);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then Text = Text:sub(1, Info.MaxLength); end;
            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then Text = Textbox.Value end
            end
            Textbox.Value = Text;
            Box.Text = Text;
            QuorumLib:SafeCallback(Textbox.Callback, Textbox.Value);
            QuorumLib:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end
                Textbox:SetValue(Box.Text);
                QuorumLib:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                QuorumLib:AttemptSave();
            end);
        end

        local function Update()
            local PADDING = 2
            local reveal = Container.AbsoluteSize.X
            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X
                    local currentCursorPos = Box.Position.X.Offset + width
                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)
        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)
        QuorumLib:AddToRegistry(Box, { TextColor3 = 'FontColor'; });

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(5);
        Groupbox:Resize();
        Options[Idx] = Textbox;
        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')
        local IconName, CleanText = QuorumLib:ParseIcon(Info.Text)
        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';
            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleContainer = QuorumLib:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        local ToggleOuter = QuorumLib:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13, 0, 13);
            ZIndex = 5;
            Parent = ToggleContainer;
        });

        QuorumLib:AddToRegistry(ToggleOuter, { BorderColor3 = 'Black'; });

        local ToggleInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.MainColor;
            BorderColor3 = QuorumLib.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        });

        QuorumLib:AddToRegistry(ToggleInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

        local ToggleLabel = QuorumLib:CreateLabel({
            Size = UDim2.new(1, IconName and -44 or -20, 1, 0);
            Position = UDim2.new(0, IconName and 44 or 20, 0, 0);
            TextSize = 14;
            Text = CleanText;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleContainer;
        });

        if IconName then
            local iconImage = QuorumLib:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 22, 0.5, 0);
                Size = UDim2.new(0, 14, 0, 14);
                AnchorPoint = Vector2.new(0, 0.5);
                Image = QuorumLib.IconAssetCache[IconName] or "",
                ImageColor3 = QuorumLib.FontColor,
                ZIndex = 6;
                Parent = ToggleContainer;
            });
            if not QuorumLib.IconAssetCache[IconName] then
                task.spawn(function()
                    while not QuorumLib.IconAssetCache[IconName] do
                        FetchIcon(IconName)
                        task.wait(0.1)
                    end
                    iconImage.Image = QuorumLib.IconAssetCache[IconName]
                end)
            end
        end

        local ToggleRegion = QuorumLib:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 8;
            Parent = ToggleContainer;
        });

        QuorumLib:OnHighlight(ToggleRegion, ToggleOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' });

        function Toggle:UpdateColors() Toggle:Display(); end;
        if type(Info.Tooltip) == 'string' then QuorumLib:AddToolTip(Info.Tooltip, ToggleRegion) end

        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and QuorumLib.AccentColor or QuorumLib.MainColor;
            ToggleInner.BorderColor3 = Toggle.Value and QuorumLib.AccentColorDark or QuorumLib.OutlineColor;
            QuorumLib.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            QuorumLib.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);
            Toggle.Value = Bool;
            Toggle:Display();
            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end
            QuorumLib:SafeCallback(Toggle.Callback, Toggle.Value);
            QuorumLib:SafeCallback(Toggle.Changed, Toggle.Value);
            QuorumLib:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if IsPrimaryPress(Input) and not QuorumLib:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value)
                QuorumLib:AttemptSave();
            end
        end);

        if Toggle.Risky then
            QuorumLib:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = QuorumLib.RiskColor
            QuorumLib:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);
        Toggles[Idx] = Toggle;
        QuorumLib:UpdateDependencyBoxes();
        Toggle:SetValue(Toggle.Value);

        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local IconName, CleanText = QuorumLib:ParseIcon(Info.Text)
        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            QuorumLib:CreateLabel({
                Size = UDim2.new(1, IconName and -24 or 0, 0, 10);
                Position = UDim2.new(0, IconName and 24 or 0, 0, 0);
                TextSize = 14;
                Text = CleanText;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });
            if IconName then
                local iconImage = QuorumLib:Create('ImageLabel', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 0);
                    Size = UDim2.new(0, 14, 0, 14);
                    Image = QuorumLib.IconAssetCache[IconName] or "",
                    ImageColor3 = QuorumLib.FontColor,
                    ZIndex = 5;
                    Parent = Container;
                });
                if not QuorumLib.IconAssetCache[IconName] then
                    task.spawn(function()
                        while not QuorumLib.IconAssetCache[IconName] do
                            FetchIcon(IconName)
                            task.wait(0.1)
                        end
                        iconImage.Image = QuorumLib.IconAssetCache[IconName]
                    end)
                end
            end
            Groupbox:AddBlank(3);
        end

        local SliderOuter = QuorumLib:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        QuorumLib:AddToRegistry(SliderOuter, { BorderColor3 = 'Black'; });

        local SliderInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.MainColor;
            BorderColor3 = QuorumLib.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderOuter;
        });

        QuorumLib:AddToRegistry(SliderInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

        local Fill = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.AccentColor;
            BorderColor3 = QuorumLib.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        });

        QuorumLib:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor'; BorderColor3 = 'AccentColorDark'; });

        local HideBorderRight = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = Fill;
        });

        QuorumLib:AddToRegistry(HideBorderRight, { BackgroundColor3 = 'AccentColor'; });

        local DisplayLabel = QuorumLib:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = 'Infinite';
            ZIndex = 9;
            Parent = SliderInner;
        });

        QuorumLib:OnHighlight(SliderOuter, SliderOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' });
        if type(Info.Tooltip) == 'string' then QuorumLib:AddToolTip(Info.Tooltip, SliderOuter) end

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = QuorumLib.AccentColor;
            Fill.BorderColor3 = QuorumLib.AccentColorDark;
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';
            if Info.Compact then
                DisplayLabel.Text = CleanText .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
            end

            local X = math.ceil(QuorumLib:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2.new((Slider.Value - Slider.Min) / (Slider.Max - Slider.Min), 0, 1, 0);
            HideBorderRight.Visible = not (Slider.Value == Slider.Max or Slider.Value == Slider.Min);
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        local function Round(Value)
            if Slider.Rounding == 0 then return math.floor(Value); end;
            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;

        function Slider:GetValueFromXOffset(X)
            return Round(QuorumLib:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);
            if (not Num) then return; end;
            Num = math.clamp(Num, Slider.Min, Slider.Max);
            Slider.Value = Num;
            Slider:Display();
            QuorumLib:SafeCallback(Slider.Callback, Slider.Value);
            QuorumLib:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if IsPrimaryPress(Input) and not QuorumLib:MouseIsOverOpenedFrame() then
                local mPos = GetInputPosition(Input).X;
                local gPos = Fill.AbsoluteSize.X;
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos);
                while IsPrimaryHeld() do
                    local nMPos = GetCursorPosition().X;
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize);
                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;
                    Slider:Display();
                    if nValue ~= OldValue then
                        QuorumLib:SafeCallback(Slider.Callback, Slider.Value);
                        QuorumLib:SafeCallback(Slider.Changed, Slider.Value);
                    end;
                    RenderStepped:Wait();
                end;
                QuorumLib:AttemptSave();
            end;
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();
        Options[Idx] = Slider;
        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then Info.Compact = true; end;

        local IconName, CleanText = QuorumLib:ParseIcon(Info.Text or '')
        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType;
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;
        local RelativeOffset = 0;

        if not Info.Compact then
            local DropdownLabel = QuorumLib:CreateLabel({
                Size = UDim2.new(1, IconName and -24 or 0, 0, 10);
                Position = UDim2.new(0, IconName and 24 or 0, 0, 0);
                TextSize = 14;
                Text = CleanText;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });
            if IconName then
                local iconImage = QuorumLib:Create('ImageLabel', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 0);
                    Size = UDim2.new(0, 14, 0, 14);
                    Image = QuorumLib.IconAssetCache[IconName] or "",
                    ImageColor3 = QuorumLib.FontColor,
                    ZIndex = 5;
                    Parent = Container;
                });
                if not QuorumLib.IconAssetCache[IconName] then
                    task.spawn(function()
                        while not QuorumLib.IconAssetCache[IconName] do
                            FetchIcon(IconName)
                            task.wait(0.1)
                        end
                        iconImage.Image = QuorumLib.IconAssetCache[IconName]
                    end)
                end
            end
            Groupbox:AddBlank(3);
        end

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA('UIListLayout') then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
            end
        end;

        local DropdownOuter = QuorumLib:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        QuorumLib:AddToRegistry(DropdownOuter, { BorderColor3 = 'Black'; });

        local DropdownInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.MainColor;
            BorderColor3 = QuorumLib.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        });

        QuorumLib:AddToRegistry(DropdownInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

        QuorumLib:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        });

        local DropdownArrow = QuorumLib:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ZIndex = 8;
            Parent = DropdownInner;
        });

        local ItemList = QuorumLib:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = true;
            ZIndex = 7;
            Parent = DropdownInner;
        });

        QuorumLib:OnHighlight(DropdownOuter, DropdownOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' });
        if type(Info.Tooltip) == 'string' then QuorumLib:AddToolTip(Info.Tooltip, DropdownOuter) end

        local MAX_DROPDOWN_ITEMS = 8;

        local ListOuter = QuorumLib:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
        end;

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end;

        RecalculateListPosition();
        RecalculateListSize();
        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        local ListInner = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.MainColor;
            BorderColor3 = QuorumLib.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        });

        QuorumLib:AddToRegistry(ListInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

        local Scrolling = QuorumLib:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;
            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = QuorumLib.AccentColor,
        });

        QuorumLib:AddToRegistry(Scrolling, { ScrollBarImageColor3 = 'AccentColor' })

        QuorumLib:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';
            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then Str = Str .. Value .. ', '; end;
                end;
                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end
            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};
                for Value, Bool in next, Dropdown.Value do table.insert(T, Value); end;
                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};
            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then Element:Destroy(); end;
            end

            local Count = 0;
            for Idx, Value in next, Values do
                local Table = {};
                Count = Count + 1;
                local Button = QuorumLib:Create('Frame', {
                    BackgroundColor3 = QuorumLib.MainColor;
                    BorderColor3 = QuorumLib.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    ZIndex = 23;
                    Active = true,
                    Parent = Scrolling;
                });

                QuorumLib:AddToRegistry(Button, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

                local ButtonLabel = QuorumLib:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 25;
                    Parent = Button;
                });

                QuorumLib:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 }
                );

                local Selected;
                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end
                    ButtonLabel.TextColor3 = Selected and QuorumLib.AccentColor or QuorumLib.FontColor;
                    QuorumLib.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                ButtonLabel.InputBegan:Connect(function(Input)
                    if IsPrimaryPress(Input) then
                        local Try = not Selected;
                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;
                                if Selected then Dropdown.Value[Value] = true; else Dropdown.Value[Value] = nil; end;
                            else
                                Selected = Try;
                                if Selected then Dropdown.Value = Value; else Dropdown.Value = nil; end;
                                for _, OtherButton in next, Buttons do OtherButton:UpdateButton(); end;
                            end;
                            Table:UpdateButton();
                            Dropdown:Display();
                            QuorumLib:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            QuorumLib:SafeCallback(Dropdown.Changed, Dropdown.Value);
                            QuorumLib:AttemptSave();
                        end;
                    end;
                end);

                Table:UpdateButton();
                Dropdown:Display();
                Buttons[Button] = Table;
            end

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);
            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then Dropdown.Values = NewValues; end;
            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            ListOuter.Visible = true;
            QuorumLib.OpenedFrames[ListOuter] = true;
            DropdownArrow.Rotation = 180;
        end;

        function Dropdown:CloseDropdown()
            ListOuter.Visible = false;
            QuorumLib.OpenedFrames[ListOuter] = nil;
            DropdownArrow.Rotation = 0;
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};
                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then nTable[Value] = true end;
                end
                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end
            end
            Dropdown:BuildDropdownList();
            QuorumLib:SafeCallback(Dropdown.Callback, Dropdown.Value);
            QuorumLib:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if IsPrimaryPress(Input) and not QuorumLib:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then Dropdown:CloseDropdown();
                else Dropdown:OpenDropdown(); end
            end
        end);

        InputService.InputBegan:Connect(function(Input)
            if IsPrimaryPress(Input) then
                local M = GetCursorPosition()
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;
                if M.X < AbsPos.X or M.X > AbsPos.X + AbsSize.X
                    or M.Y < (AbsPos.Y - 20 - 1) or M.Y > AbsPos.Y + AbsSize.Y then
                    Dropdown:CloseDropdown();
                end
            end
        end);

        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {}

        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then table.insert(Defaults, Idx) end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then table.insert(Defaults, Idx) end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end
                if (not Info.Multi) then break end
            end
            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();
        Options[Idx] = Dropdown;
        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = { Dependencies = {}; };
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Holder = QuorumLib:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

        local Frame = QuorumLib:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });

        local Layout = QuorumLib:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Depbox:Resize(); end);
        Holder:GetPropertyChangedSignal('Visible'):Connect(function() Depbox:Resize(); end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];
                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end
            Holder.Visible = true;
            Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end
            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;
        setmetatable(Depbox, BaseGroupbox);
        table.insert(QuorumLib.DependencyBoxes, Depbox);
        return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

do
    local function CreateNotificationArea(Position, AnchorPoint, LayoutOrder)
        local Area = QuorumLib:Create('Frame', {
            BackgroundTransparency = 1;
            Position = Position;
            Size = UDim2.new(1, 0, 1, 0);
            AnchorPoint = AnchorPoint;
            ZIndex = 100;
            Parent = ScreenGui;
        });

        QuorumLib:Create('UIPadding', {
            PaddingTop = UDim.new(0, 60);
            PaddingBottom = UDim.new(0, 50);
            PaddingLeft = UDim.new(0, 10);
            PaddingRight = UDim.new(0, 10);
            Parent = Area;
        });

        local Layout = QuorumLib:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Area;
        });

        if LayoutOrder == 'BottomLeft' or LayoutOrder == 'BottomRight' then
            Layout.VerticalAlignment = Enum.VerticalAlignment.Bottom;
        else
            Layout.VerticalAlignment = Enum.VerticalAlignment.Top;
        end

        if LayoutOrder == 'TopRight' or LayoutOrder == 'BottomRight' then
            Layout.HorizontalAlignment = Enum.HorizontalAlignment.Right;
        else
            Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left;
        end

        return Area;
    end

    QuorumLib.NotificationAreas.TopLeft = CreateNotificationArea(UDim2.new(0, 0, 0, 0), Vector2.new(0, 0))
    QuorumLib.NotificationAreas.TopRight = CreateNotificationArea(UDim2.new(1, 0, 0, 0), Vector2.new(1, 0), 'TopRight')
    QuorumLib.NotificationAreas.BottomLeft = CreateNotificationArea(UDim2.new(0, 0, 1, 0), Vector2.new(0, 1), 'BottomLeft')
    QuorumLib.NotificationAreas.BottomRight = CreateNotificationArea(UDim2.new(1, 0, 1, 0), Vector2.new(1, 1), 'BottomRight')
    
    QuorumLib.NotificationArea = QuorumLib.NotificationAreas.TopLeft

    local WatermarkOuter = QuorumLib:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, -25);
        Size = UDim2.new(0, 213, 0, 20);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });

    local WatermarkInner = QuorumLib:Create('Frame', {
        BackgroundColor3 = QuorumLib.MainColor;
        BorderColor3 = QuorumLib.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    });

    QuorumLib:AddToRegistry(WatermarkInner, { BorderColor3 = 'AccentColor'; });

    local InnerFrame = QuorumLib:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 202;
        Parent = WatermarkInner;
    });

    local Gradient = QuorumLib:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, QuorumLib:GetDarkerColor(QuorumLib.MainColor)),
            ColorSequenceKeypoint.new(1, QuorumLib.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    QuorumLib:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, QuorumLib:GetDarkerColor(QuorumLib.MainColor)),
                ColorSequenceKeypoint.new(1, QuorumLib.MainColor),
            });
        end
    });

    local WatermarkLabel = QuorumLib:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = InnerFrame;
    });

    QuorumLib.Watermark = WatermarkOuter;
    QuorumLib.WatermarkText = WatermarkLabel;
    QuorumLib:MakeDraggable(QuorumLib.Watermark);

    local KeybindOuter = QuorumLib:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });

    local KeybindInner = QuorumLib:Create('Frame', {
        BackgroundColor3 = QuorumLib.MainColor;
        BorderColor3 = QuorumLib.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = KeybindOuter;
    });

    QuorumLib:AddToRegistry(KeybindInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; }, true);

    local ColorFrame = QuorumLib:Create('Frame', {
        BackgroundColor3 = QuorumLib.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 102;
        Parent = KeybindInner;
    });

    QuorumLib:AddToRegistry(ColorFrame, { BackgroundColor3 = 'AccentColor'; }, true);

    local KeybindLabel = QuorumLib:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = 'Keybinds';
        ZIndex = 104;
        Parent = KeybindInner;
    });

    local KeybindContainer = QuorumLib:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex = 1;
        Parent = KeybindInner;
    });

    QuorumLib:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });

    QuorumLib:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    QuorumLib.KeybindFrame = KeybindOuter;
    QuorumLib.KeybindContainer = KeybindContainer;
    QuorumLib:MakeDraggable(KeybindOuter);
end;

function QuorumLib:SetWatermarkVisibility(Bool)
    QuorumLib.Watermark.Visible = Bool;
end;

function QuorumLib:SetWatermark(Text)
    local X, Y = QuorumLib:GetTextBounds(Text, QuorumLib.Font, 14);
    QuorumLib.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3);
    QuorumLib:SetWatermarkVisibility(true)
    QuorumLib.WatermarkText.Text = Text;
end;

function QuorumLib:Notify(Text, Time, Position)
    local ViewportWidth = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 1920
    local MaxNotifyWidth = math.min(350, ViewportWidth * 0.8)
    
    local XSize, YSize = QuorumLib:GetTextBounds(Text, QuorumLib.Font, 14);
    if XSize > MaxNotifyWidth then
        XSize = MaxNotifyWidth
    end
    YSize = YSize + 7

    local TargetArea = QuorumLib.NotificationAreas[Position or 'TopLeft'] or QuorumLib.NotificationAreas.TopLeft
    local isRight = (Position == 'TopRight' or Position == 'BottomRight')

    local NotifyOuter = QuorumLib:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        AnchorPoint = isRight and Vector2.new(1, 0) or Vector2.new(0, 0);
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(0, 0, 0, YSize);
        ClipsDescendants = true;
        ZIndex = 100;
        Parent = TargetArea;
    });

    local NotifyInner = QuorumLib:Create('Frame', {
        BackgroundColor3 = QuorumLib.MainColor;
        BorderColor3 = QuorumLib.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = NotifyOuter;
    });

    QuorumLib:AddToRegistry(NotifyInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; }, true);

    local InnerFrame = QuorumLib:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 102;
        Parent = NotifyInner;
    });

    local Gradient = QuorumLib:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, QuorumLib:GetDarkerColor(QuorumLib.MainColor)),
            ColorSequenceKeypoint.new(1, QuorumLib.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    QuorumLib:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, QuorumLib:GetDarkerColor(QuorumLib.MainColor)),
                ColorSequenceKeypoint.new(1, QuorumLib.MainColor),
            });
        end
    });

    local NotifyLabel = QuorumLib:CreateLabel({
        Position = UDim2.new(0, 4, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 14;
        ZIndex = 103;
        Parent = InnerFrame;
    });

    local LeftColor = QuorumLib:Create('Frame', {
        BackgroundColor3 = QuorumLib.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, -1, 0, -1);
        Size = UDim2.new(0, 3, 1, 2);
        ZIndex = 104;
        Parent = NotifyOuter;
    });

    QuorumLib:AddToRegistry(LeftColor, { BackgroundColor3 = 'AccentColor'; }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 8 + 4, 0, YSize), 'Out', 'Quad', 0.4, true);

    task.spawn(function()
        wait(Time or 5);
        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true);
        wait(0.4);
        NotifyOuter:Destroy();
    end);
end;

function QuorumLib:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'Quorum UI Library' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 4 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end
    if Config.UseCustomCursor == nil then Config.UseCustomCursor = true end
    if Config.UseIcons == nil then Config.UseIcons = false end
    
    QuorumLib.UseCustomCursor = Config.UseCustomCursor and true or false
    QuorumLib.UseIcons = Config.UseIcons

    local BaseSize = UDim2.fromOffset(550, 600)
    if Config.Size == "Small" then
        BaseSize = UDim2.fromOffset(450, 480)
    elseif Config.Size == "Big" then
        BaseSize = UDim2.fromOffset(700, 700)
    elseif typeof(Config.Size) == "UDim2" then
        BaseSize = Config.Size
    end

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end

    if IsMobile then
        if BaseSize == UDim2.fromOffset(550, 600) or Config.Size == nil then
            local VP = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1024, 768)
            BaseSize = UDim2.fromOffset(math.min(420, VP.X - 40), math.min(360, VP.Y - 80))
        end
        if not Config.Center then Config.Center = true end
    end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = { Tabs = {}; };

    local Outer = QuorumLib:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderSizePixel = 0;
        Position = Config.Position,
        Size = BaseSize,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });

    QuorumLib:MakeDraggable(Outer, 25);

    local Inner = QuorumLib:Create('Frame', {
        BackgroundColor3 = QuorumLib.MainColor;
        BorderColor3 = QuorumLib.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 1;
        Parent = Outer;
    });

    QuorumLib:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'AccentColor'; });

    local WindowLabel = QuorumLib:CreateLabel({
        Position = UDim2.new(0, 7, 0, 0);
        Size = UDim2.new(0, 0, 0, 25);
        Text = Config.Title or '';
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 1;
        Parent = Inner;
    });

    local MainSectionOuter = QuorumLib:Create('Frame', {
        BackgroundColor3 = QuorumLib.BackgroundColor;
        BorderColor3 = QuorumLib.OutlineColor;
        Position = UDim2.new(0, 8, 0, 25);
        Size = UDim2.new(1, -16, 1, -33);
        ZIndex = 1;
        Parent = Inner;
    });

    QuorumLib:AddToRegistry(MainSectionOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

    local MainSectionInner = QuorumLib:Create('Frame', {
        BackgroundColor3 = QuorumLib.BackgroundColor;
        BorderColor3 = Color3.new(0, 0, 0);
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = MainSectionOuter;
    });

    QuorumLib:AddToRegistry(MainSectionInner, { BackgroundColor3 = 'BackgroundColor'; });

    local TabArea = QuorumLib:Create('ScrollingFrame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 8, 0, 8);
        Size = UDim2.new(1, -16, 0, 21);
        CanvasSize = UDim2.new(0, 0, 0, 0);
        AutomaticCanvasSize = Enum.AutomaticSize.None;
        ScrollBarThickness = IsMobile and 2 or 3;
        ScrollBarImageColor3 = QuorumLib.AccentColor;
        ScrollingDirection = Enum.ScrollingDirection.X;
        ZIndex = 1;
        Parent = MainSectionInner;
    });

    QuorumLib:AddToRegistry(TabArea, { ScrollBarImageColor3 = 'AccentColor'; });

    local TabListLayout = QuorumLib:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });

    local function UpdateTabCanvas()
        TabArea.CanvasSize = UDim2.fromOffset(TabListLayout.AbsoluteContentSize.X + 4, 0)
    end

    TabListLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(UpdateTabCanvas)
    task.spawn(UpdateTabCanvas)

    local TabContainer = QuorumLib:Create('Frame', {
        BackgroundColor3 = QuorumLib.MainColor;
        BorderColor3 = QuorumLib.OutlineColor;
        Position = UDim2.new(0, 8, 0, 30);
        Size = UDim2.new(1, -16, 1, -38);
        ZIndex = 2;
        Parent = MainSectionInner;
    });

    QuorumLib:AddToRegistry(TabContainer, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end;

    function Window:SetSize(NewSize)
        if NewSize == "Small" then NewSize = UDim2.fromOffset(450, 480)
        elseif NewSize == "Big" then NewSize = UDim2.fromOffset(700, 700)
        elseif NewSize == "Default" then NewSize = UDim2.fromOffset(550, 600)
        elseif typeof(NewSize) == "number" then NewSize = UDim2.fromOffset(NewSize, NewSize * 1.1) 
        elseif typeof(NewSize) ~= "UDim2" then return end

        if not Config.Center then
            local currentAbs = Outer.AbsolutePosition
            local currentSize = Outer.AbsoluteSize
            local centerX = currentAbs.X + (currentSize.X / 2)
            local centerY = currentAbs.Y + (currentSize.Y / 2)
            local newX = centerX - (NewSize.X.Offset / 2)
            local newY = centerY - (NewSize.Y.Offset / 2)
            
            TweenService:Create(Outer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                Size = NewSize,
                Position = UDim2.fromOffset(newX, newY)
            }):Play()
        else
            TweenService:Create(Outer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                Size = NewSize
            }):Play()
        end
    end

    function Window:AddTab(Name)
        local IconName, CleanName = QuorumLib:ParseIcon(Name)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
        };

        local TabButtonWidth = QuorumLib:GetTextBounds(CleanName, QuorumLib.Font, 16);

        local TabButton = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.BackgroundColor;
            BorderColor3 = QuorumLib.OutlineColor;
            Size = UDim2.new(0, TabButtonWidth + (IconName and 32 or 12), 1, 0);
            ZIndex = 1;
            Parent = TabArea;
        });

        QuorumLib:AddToRegistry(TabButton, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        local TabButtonLabel = QuorumLib:CreateLabel({
            Position = UDim2.new(0, IconName and 28 or 0, 0, 0);
            Size = UDim2.new(1, IconName and -28 or 0, 1, -1);
            Text = CleanName;
            TextXAlignment = IconName and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center;
            ZIndex = 1;
            Parent = TabButton;
        });

        if IconName then
            local iconImage = QuorumLib:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 8, 0.5, 0);
                Size = UDim2.new(0, 14, 0, 14);
                AnchorPoint = Vector2.new(0, 0.5);
                Image = QuorumLib.IconAssetCache[IconName] or "",
                ImageColor3 = QuorumLib.FontColor,
                ZIndex = 1;
                Parent = TabButton;
            });
            if not QuorumLib.IconAssetCache[IconName] then
                task.spawn(function()
                    while not QuorumLib.IconAssetCache[IconName] do
                        FetchIcon(IconName)
                        task.wait(0.1)
                    end
                    iconImage.Image = QuorumLib.IconAssetCache[IconName]
                end)
            end
        end

        local Blocker = QuorumLib:Create('Frame', {
            BackgroundColor3 = QuorumLib.MainColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 0);
            Size = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1;
            ZIndex = 3;
            Parent = TabButton;
        });

        QuorumLib:AddToRegistry(Blocker, { BackgroundColor3 = 'MainColor'; });

        local TabFrame = QuorumLib:Create('Frame', {
            Name = 'TabFrame',
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        });

        local LeftSide = QuorumLib:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 8 - 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 1, -16 + 2);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        local RightSide = QuorumLib:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 1, -16 + 2);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        QuorumLib:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = LeftSide;
        });

        QuorumLib:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = RightSide;
        });

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
            end);
        end;

        function Tab:ShowTab()
            for _, Tab in next, Window.Tabs do
                Tab:HideTab();
            end;
            Blocker.BackgroundTransparency = 0;
            TabButton.BackgroundColor3 = QuorumLib.MainColor;
            QuorumLib.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor';
            TabFrame.Visible = true;
        end;

        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1;
            TabButton.BackgroundColor3 = QuorumLib.BackgroundColor;
            QuorumLib.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor';
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
            TabListLayout:ApplyLayout();
        end;

        function Tab:AddGroupbox(Info)
            local IconName, CleanName = QuorumLib:ParseIcon(Info.Name)
            local Groupbox = {};
            local BoxOuter = QuorumLib:Create('Frame', {
                BackgroundColor3 = QuorumLib.BackgroundColor;
                BorderColor3 = QuorumLib.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 507 + 2);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            QuorumLib:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

            local BoxInner = QuorumLib:Create('Frame', {
                BackgroundColor3 = QuorumLib.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            QuorumLib:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor'; });

            local Highlight = QuorumLib:Create('Frame', {
                BackgroundColor3 = QuorumLib.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 5;
                Parent = BoxInner;
            });

            QuorumLib:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });

            local GroupboxLabel = QuorumLib:CreateLabel({
                Size = UDim2.new(1, IconName and -24 or 0, 0, 18);
                Position = UDim2.new(0, IconName and 24 or 4, 0, 2);
                TextSize = 14;
                Text = CleanName;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxInner;
            });

            if IconName then
                local iconImage = QuorumLib:Create('ImageLabel', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 6, 0, 4);
                    Size = UDim2.new(0, 14, 0, 14);
                    Image = QuorumLib.IconAssetCache[IconName] or "",
                    ImageColor3 = QuorumLib.FontColor,
                    ZIndex = 5;
                    Parent = BoxInner;
                });
                if not QuorumLib.IconAssetCache[IconName] then
                    task.spawn(function()
                        while not QuorumLib.IconAssetCache[IconName] do
                            FetchIcon(IconName)
                            task.wait(0.1)
                        end
                        iconImage.Image = QuorumLib.IconAssetCache[IconName]
                    end)
                end
            end

            local Container = QuorumLib:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, -4, 1, -20);
                ZIndex = 1;
                Parent = BoxInner;
            });

            QuorumLib:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            });

            function Groupbox:Resize()
                local Size = 0;
                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;
                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
            end;

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);
            Groupbox:AddBlank(3);
            Groupbox:Resize();
            Tab.Groupboxes[Info.Name] = Groupbox;
            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name) return Tab:AddGroupbox({ Side = 1; Name = Name; }); end;
        function Tab:AddRightGroupbox(Name) return Tab:AddGroupbox({ Side = 2; Name = Name; }); end;

        function Tab:AddTabbox(Info)
            local Tabbox = { Tabs = {}; };
            local BoxOuter = QuorumLib:Create('Frame', {
                BackgroundColor3 = QuorumLib.BackgroundColor;
                BorderColor3 = QuorumLib.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            QuorumLib:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

            local BoxInner = QuorumLib:Create('Frame', {
                BackgroundColor3 = QuorumLib.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            QuorumLib:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor'; });

            local Highlight = QuorumLib:Create('Frame', {
                BackgroundColor3 = QuorumLib.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 10;
                Parent = BoxInner;
            });

            QuorumLib:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });

            local TabboxButtons = QuorumLib:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 1);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 5;
                Parent = BoxInner;
            });

            QuorumLib:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            function Tabbox:AddTab(Name)
                local IconName, CleanName = QuorumLib:ParseIcon(Name)
                local Tab = {};
                local Button = QuorumLib:Create('Frame', {
                    BackgroundColor3 = QuorumLib.MainColor;
                    BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                });

                QuorumLib:AddToRegistry(Button, { BackgroundColor3 = 'MainColor'; });

                local ButtonLabel = QuorumLib:CreateLabel({
                    Size = UDim2.new(1, IconName and -24 or 0, 1, 0);
                    Position = UDim2.new(0, IconName and 24 or 0, 0, 0);
                    TextSize = 14;
                    Text = CleanName;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                });

                if IconName then
                    local iconImage = QuorumLib:Create('ImageLabel', {
                        BackgroundTransparency = 1;
                        Position = UDim2.new(0, 6, 0.5, 0);
                        Size = UDim2.new(0, 14, 0, 14);
                        AnchorPoint = Vector2.new(0, 0.5);
                        Image = QuorumLib.IconAssetCache[IconName] or "",
                        ImageColor3 = QuorumLib.FontColor,
                        ZIndex = 7;
                        Parent = Button;
                    });
                    if not QuorumLib.IconAssetCache[IconName] then
                        task.spawn(function()
                            while not QuorumLib.IconAssetCache[IconName] do
                                FetchIcon(IconName)
                                task.wait(0.1)
                            end
                            iconImage.Image = QuorumLib.IconAssetCache[IconName]
                        end)
                    end
                end

                local Block = QuorumLib:Create('Frame', {
                    BackgroundColor3 = QuorumLib.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0);
                    Size = UDim2.new(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                });

                QuorumLib:AddToRegistry(Block, { BackgroundColor3 = 'BackgroundColor'; });

                local Container = QuorumLib:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 20);
                    Size = UDim2.new(1, -4, 1, -20);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                });

                QuorumLib:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });

                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do Tab:Hide(); end;
                    Container.Visible = true;
                    Block.Visible = true;
                    Button.BackgroundColor3 = QuorumLib.BackgroundColor;
                    QuorumLib.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';
                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Block.Visible = false;
                    Button.BackgroundColor3 = QuorumLib.MainColor;
                    QuorumLib.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function Tab:Resize()
                    local TabCount = 0;
                    for _, Tab in next, Tabbox.Tabs do TabCount = TabCount + 1; end;
                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA('UIListLayout') then
                            Button.Size = UDim2.new(1 / TabCount, 0, 1, 0);
                        end;
                    end

                    if (not Container.Visible) then return; end;

                    local Size = 0;
                    for _, Element in next, Tab.Container:GetChildren() do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset;
                        end;
                    end
                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
                end;

                Button.InputBegan:Connect(function(Input)
                    if IsPrimaryPress(Input) and not QuorumLib:MouseIsOverOpenedFrame() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;
                setmetatable(Tab, BaseGroupbox);
                Tab:AddBlank(3);
                Tab:Resize();

                if #TabboxButtons:GetChildren() == 2 then Tab:Show(); end;
                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;
            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 1; }); end;
        function Tab:AddRightTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 2; }); end;

        TabButton.InputBegan:Connect(function(Input)
            if IsPrimaryPress(Input) then Tab:ShowTab(); end;
        end);

        if #TabContainer:GetChildren() == 1 then Tab:ShowTab(); end;
        Window.Tabs[Name] = Tab;
        return Tab;
    end;

    local ModalElement = QuorumLib:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = '';
        Modal = false;
        Parent = ScreenGui;
    });

    local TransparencyCache = {};
    local Fading = false;

    function QuorumLib:Toggle()
        if Fading then return; end;

        local FadeTime = Config.MenuFadeTime;
        Fading = true;
        QuorumLib.MenuToggled = (not QuorumLib.MenuToggled);
        ModalElement.Modal = QuorumLib.MenuToggled;

        if QuorumLib.MenuToggled then
            Outer.Visible = true;
            if QuorumLib.UseCustomCursor then SpawnCustomCursor() end;
        else
            if not IsTouchDevice then
                InputService.MouseBehavior = Enum.MouseBehavior.Default
            end
        end;

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {};
            if Desc:IsA('ImageLabel') then
                table.insert(Properties, 'ImageTransparency');
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
                table.insert(Properties, 'TextTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') then
                table.insert(Properties, 'Transparency');
            end;

            local Cache = TransparencyCache[Desc];
            if (not Cache) then
                Cache = {};
                TransparencyCache[Desc] = Cache;
            end;

            for _, Prop in next, Properties do
                if not Cache[Prop] then Cache[Prop] = Desc[Prop]; end;
                if Cache[Prop] == 1 then continue; end;
                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = QuorumLib.MenuToggled and Cache[Prop] or 1 }):Play();
            end;
        end;

        task.wait(FadeTime);
        Outer.Visible = QuorumLib.MenuToggled;
        Fading = false;
    end

    QuorumLib:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(QuorumLib.ToggleKeybind) == 'table' and QuorumLib.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == QuorumLib.ToggleKeybind.Value then
                task.spawn(QuorumLib.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(QuorumLib.Toggle)
        end
    end))

    if IsMobile then
        local MobileBtn = QuorumLib:Create('TextButton', {
            BackgroundColor3 = QuorumLib.MainColor;
            BorderColor3 = QuorumLib.AccentColor;
            BorderMode = Enum.BorderMode.Inset;
            AnchorPoint = Vector2.new(1, 1);
            Position = UDim2.new(1, -20, 1, -20);
            Size = UDim2.fromOffset(44, 44);
            Text = Config.MobileToggleIcon or '☰';
            Font = QuorumLib.Font;
            TextSize = 20;
            TextColor3 = QuorumLib.FontColor;
            AutoButtonColor = false;
            ZIndex = 999;
            Parent = ScreenGui;
        });

        QuorumLib:AddToRegistry(MobileBtn, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'AccentColor'; TextColor3 = 'FontColor'; }, true);
        MobileBtn.MouseButton1Click:Connect(function() task.spawn(QuorumLib.Toggle) end);
        QuorumLib.MobileToggle = MobileBtn;
    end

    if Config.AutoShow then task.spawn(QuorumLib.Toggle) end
    Window.Holder = Outer;
    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();
    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;

Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().QuorumLib = QuorumLib
return QuorumLib
