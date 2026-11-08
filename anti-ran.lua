--[[
    MUSIC ONLY + ANTI-STEAL V2  (Lloyd-Grade Payload)
    - เปิดเพลงผ่าน Boombox / Skateboard
    - กันดัก: spy เห็น "กันเจาะกากๆรัน" (122657934666702)
    - เพลงจริงเล่นได้ผ่าน C++ Parser (Space-Fractured &id=)
    - 4 Chameleon Modes + Digit-Split fallback
]]

local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local SoundService       = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local gethui = gethui or function() return game:GetService("CoreGui") end
local GuiParent = (function()
    local ok, r = pcall(gethui); if ok and r then return r end
    return LocalPlayer:WaitForChild("PlayerGui")
end)()

for _, n in ipairs({"MusicOnlyRoot","MusicOnlyToggle"}) do
    local old = GuiParent:FindFirstChild(n); if old then old:Destroy() end
end

------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------
local BAIT_ID          = "122657934666702"        -- กันเจาะกากๆรัน
local BAIT_NAME        = "กันเจาะกากๆรัน"
local ANTI_STEAL_ON    = true
local CURRENT_MODE     = "URI"                    -- "URI" | "DIGIT"
local SELECTED_DEVICE  = "Boombox"
local MUSIC_RESET_HOLD = 0.65
local MUSIC_RESET_ID   = "84899763517255"

local DEVICES = {"Boombox","Skateboard","Hoverboard","PogoStick","Sled","CarrotPogoStick","PinkScooter","BlueScooter"}

------------------------------------------------------------------
-- REMOTES
------------------------------------------------------------------
local function findRemotes()
    local folder = ReplicatedStorage:FindFirstChild("RE") or ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not folder then
        for _, v in ipairs(ReplicatedStorage:GetChildren()) do
            if v:IsA("Folder") and (v:FindFirstChild("PlayerToolEvent") or v:FindFirstChild("PlayerScooterEvent")) then
                folder = v; break
            end
        end
    end
    local t, s
    if folder then
        t = folder:FindFirstChild("PlayerToolEvent")
        s = folder:FindFirstChild("PlayerScooterEvent")
            or folder:FindFirstChild("1NoMoto1rVehicle1s")
            or folder:FindFirstChild("1NoMo1torVeh1icle1s")
    end
    return t, s
end
local ToolEvent, ScooterEvent = findRemotes()

------------------------------------------------------------------
-- ▓▓ ANTI-STEAL ENGINE (Lloyd-Grade) ▓▓
------------------------------------------------------------------
local REAL_AUDIO_POOL = {
    "1848354536","1837879082","9043887091","1845756489","9048375035",
    "1836842899","1843404009","7029024726","5410086218","1846458016",
    "1839841807","1841647093","9046863253","9047050075","1837474337",
    "1842802203","1845554017","1838673350","9045766377","1840684529",
    "1836009206","1847853099","9039767824","9042666762","1835337424",
    "1841998846","1839246711","9044565954","1846088038","1837070127",
    "129138368026497",
}
local GARBAGE_KEYS = {
    "real_id","true_id","actual_id","play_id","main_id","raw_id","clean_id","source_id",
    "id_real","id_true","id_main","id_play","id_0","id_1","id_stream","id_override",
    "sound_id","asset_id","audio_id","music_id","track_id","stream_id","clip_id","song_id",
    "media_id","voice_id","tune_id","beat_id","record_id","channel_id","buffer_id",
}

local HEX  = "0123456789ABCDEF"
local ZWS  = string.char(226,128,139)
local ZWNJ = string.char(226,128,140)
local ZWJ  = string.char(226,128,141)
local WJ   = string.char(226,129,160)
local BOM  = string.char(239,187,191)
local NBSP = string.char(194,160)

-- C++ engine strips ASCII space (0x20) THEN urlDecodes
-- % 6 9 % 6 4 → %69%64 → "id"   (valid for C++)
-- Lua spy's urlDecode(% 6 9) fails (space between % and digit) → can't parse
local function encodeSpaceFractured(s)
    s = tostring(s)
    local out = {}
    for i = 1, #s do
        local b = string.byte(s, i)
        if math.random(1,4) == 1 and b >= 48 and b <= 57 then
            out[#out+1] = " " .. string.char(b) .. " "
        else
            local hi = math.floor(b/16)+1
            local lo = (b%16)+1
            out[#out+1] = string.rep(" ", math.random(0,2)) .. "%" ..
                          string.rep(" ", math.random(1,2)) ..
                          string.sub(HEX,hi,hi) .. string.rep(" ", math.random(0,2)) ..
                          string.sub(HEX,lo,lo)
        end
    end
    return table.concat(out)
end

local function encodeGarbageKeyName(key)
    local pos = math.random(1, #key)
    local out = {}
    for i = 1, #key do
        if i == pos then out[#out+1] = (math.random(1,2)==1) and "% 0 0 " or ZWS end
        local b = string.byte(key, i)
        if i == 1 or math.random(1,2) == 1 then
            local hi = math.floor(b/16)+1
            local lo = (b%16)+1
            out[#out+1] = "% " .. string.sub(HEX,hi,hi) .. " " .. string.sub(HEX,lo,lo) .. " "
        else
            out[#out+1] = string.sub(key,i,i) .. string.rep(" ", math.random(0,1))
        end
    end
    return table.concat(out)
end

local function mutateNearClone(base)
    local s = tostring(base):match("%d+") or "1848354536"
    if #s < 5 then s = "1848354536" end
    local chars = {}
    for i=1,#s do chars[i] = string.sub(s,i,i) end
    for _ = 1, math.random(2, math.min(4, #chars-1)) do
        local p = math.random(2, #chars)
        chars[p] = tostring((tonumber(chars[p]) + math.random(1,8)) % 10)
    end
    return table.concat(chars)
end

local function randomGarbageNum(exclude)
    local m = math.random(1, 10)
    local c
    if m <= 3 then c = tostring(math.random(18300,18499)) .. tostring(math.random(10000,99999))
    elseif m <= 5 then c = tostring(math.random(90380,90489)) .. tostring(math.random(10000,99999))
    elseif m <= 7 then c = tostring(math.random(1000,9999)) .. tostring(math.random(100000,999999)) .. tostring(math.random(1000,9999))
    elseif m <= 9 then c = mutateNearClone(exclude or BAIT_ID)
    else c = tostring(math.random(10500,13999)) .. tostring(math.random(10000,99999)) .. tostring(math.random(10000,99999)) end
    if c == tostring(exclude) then c = c .. tostring(math.random(1,9)) end
    return c
end

local function pickBait(exclude)
    for _ = 1, 12 do
        local p = REAL_AUDIO_POOL[math.random(1, #REAL_AUDIO_POOL)]
        if p ~= tostring(exclude) then return p end
    end
    return "1848354536"
end

-- Variants C++ ACCEPTS (space-strip + decode gives "id")
local VALID_CPP_KEYS = {
    "& % 6 9 % 6 4 = ",
    "&  % 6 9  % 6 4  =  ",
    "&   % 6 9   d   =   ",
    "&  i   % 6 4   =  ",
    "& % 6 9  d =  ",
    "&  i  % 6 4 = ",
    "&   i   d   =   ",
}

-- Variants C++ IGNORES (has \t, \r, \n, %00, ZWS, etc. → key ≠ "id") but spy's gsub("%s+","") may match
local POISONED_KEYS = {
    "& \t% 6 9 % 6 4 = ",
    "& \r% 6 9 % 6 4 = ",
    "& \n% 6 9 % 6 4 = ",
    "& % 6 9 \t% 6 4 = ",
    "& % 6 9 % 6 4 \t= ",
    "& % 6 9 % 0 0 % 6 4 = ",
    "& % 0 0 % 6 9 % 6 4 = ",
    "& % 6 9 % 6 4 % 0 0 = ",
    "& % 6 9 % 0 1 % 6 4 = ",
    "& % 6 9 % 0 7 % 6 4 = ",
    "& % 6 9 % 1 F % 6 4 = ",
    "& % 6 9 % 7 F % 6 4 = ",
    "&" .. ZWS .. "% 6 9 % 6 4 = ",
    "& % 6 9 " .. ZWS .. "% 6 4 = ",
    "&" .. ZWNJ .. "% 6 9 % 6 4 = ",
    "&" .. ZWJ .. "% 6 9 % 6 4 = ",
    "&" .. BOM .. "% 6 9 % 6 4 = ",
    "&" .. NBSP .. "% 6 9 % 6 4 = ",
    "& % 2 6 % 6 9 % 6 4 % 3 D ",
    "& % 6 9 % 6 4 % 3 D ",
    "& i d % 3 D ",
}

local function buildFakeKey(exclude)
    local k = GARBAGE_KEYS[math.random(1,#GARBAGE_KEYS)]
    local v = (math.random(1,3)==1) and pickBait(exclude) or randomGarbageNum(exclude)
    return "& " .. encodeGarbageKeyName(k) .. "= " .. encodeSpaceFractured(v) .. "&%00"
end

local function buildPoisoned(exclude)
    local v = (math.random(1,3)==1) and pickBait(exclude) or randomGarbageNum(exclude)
    return POISONED_KEYS[math.random(1,#POISONED_KEYS)] .. encodeSpaceFractured(v) .. "&%00"
end

local function buildValidDecoy(exclude)
    local v = pickBait(exclude)
    return VALID_CPP_KEYS[math.random(1,#VALID_CPP_KEYS)] .. encodeSpaceFractured(v) .. "&%00"
end

-- ▓▓ URI PAYLOAD BUILDER ▓▓
local function buildUriPayload(rawId)
    local cleanId = tostring(rawId):match("%d+") or tostring(rawId)
    _G.MusicRound = (_G.MusicRound or 0) + 1
    local round = _G.MusicRound

    local totalLines = math.random(115, 140) + math.min((round-1)*14, 130)
    local chameleonMode = ((round + math.random(1,3)) % 4) + 1

    local lines = {}

    -- LINE 1: bait first — any match("%d+") gets 122657934666702
    lines[#lines+1] = BAIT_ID .. "&lloyd_auth=1&%00"

    -- Header entropy (rotates every round)
    local h1 = randomGarbageNum(cleanId)
    local h2 = randomGarbageNum(cleanId)
    lines[#lines+1] = "; ===== ANTI-STEAL ROUND-" .. string.format("%04d", round) .. " [MODE-" .. chameleonMode .. "] ====="
    lines[#lines+1] = "; SALT=" .. h1 .. "_" .. h2 .. "&%00" .. buildFakeKey(cleanId)

    -- Real ID line position depends on chameleon mode
    local realLine
    if chameleonMode == 1 then realLine = math.random(math.floor(totalLines*0.18), math.floor(totalLines*0.32))
    elseif chameleonMode == 2 then realLine = math.random(math.floor(totalLines*0.72), math.floor(totalLines*0.86))
    elseif chameleonMode == 3 then realLine = math.random(math.floor(totalLines*0.35), math.floor(totalLines*0.65))
    else realLine = math.random(math.floor(totalLines*0.42), math.floor(totalLines*0.58)) end

    for i = 1, totalLines do
        if i == realLine then
            -- REAL ID — C++ parses (space-strip + decode), spy can't
            local key = VALID_CPP_KEYS[math.random(1,#VALID_CPP_KEYS)]
            local zeros = encodeSpaceFractured(string.rep("0", math.random(2,5)))
            local segs = {
                buildFakeKey(cleanId), buildPoisoned(cleanId),
                key .. zeros .. encodeSpaceFractured(cleanId) .. "&%00",
                buildPoisoned(cleanId), buildFakeKey(cleanId),
            }
            lines[#lines+1] = "%E2%80%AE" .. table.concat(segs)
        else
            local segs = {}
            local n = math.random(2,4)
            for _ = 1, n do
                local r = math.random(1,100)
                if i < realLine then
                    if r <= 40 then segs[#segs+1] = buildValidDecoy(cleanId)
                    elseif r <= 70 then segs[#segs+1] = buildPoisoned(cleanId)
                    else segs[#segs+1] = buildFakeKey(cleanId) end
                else
                    if r <= 62 then segs[#segs+1] = buildPoisoned(cleanId)
                    else segs[#segs+1] = buildFakeKey(cleanId) end
                end
            end
            lines[#lines+1] = "%E2%80%AE" .. table.concat(segs)
        end
    end

    -- Tail flood
    for _ = 1, math.random(14,22) do
        lines[#lines+1] = "%E2%80%AE" .. buildPoisoned(cleanId) .. buildFakeKey(cleanId) .. buildPoisoned(cleanId)
    end

    return table.concat(lines, "\r\n")
end

-- ▓▓ DIGIT-SPLIT BUILDER ▓▓
local ALPHA_NOISE = {
    "SoundService_Stream_Buffer_Init","AudioChannel_Replication_Sync",
    "AssetDelivery_ContentProvider_Load","Waveform_Decoder_Chunk_Verify",
    "SpatialVoice_Emitter_Transform","Equalizer_Filter_Bypass_State",
}
local function buildDigitPayload(rawId)
    local cleanId = tostring(rawId):match("%d+") or tostring(rawId)
    local chunks = {}
    -- Bait prefix
    for i = 1, #BAIT_ID do
        local d = string.sub(BAIT_ID, i, i)
        chunks[#chunks+1] = ALPHA_NOISE[math.random(1,#ALPHA_NOISE)] .. "::[" .. d .. "]::" .. ALPHA_NOISE[math.random(1,#ALPHA_NOISE)]
    end
    for _ = 1, math.random(6,11) do
        chunks[#chunks+1] = ALPHA_NOISE[math.random(1,#ALPHA_NOISE)] .. "::[" .. tostring(math.random(0,9)) .. "]::" .. ALPHA_NOISE[math.random(1,#ALPHA_NOISE)]
    end
    -- Real ID
    for i = 1, #cleanId do
        chunks[#chunks+1] = ALPHA_NOISE[math.random(1,#ALPHA_NOISE)] .. "::[" .. string.sub(cleanId,i,i) .. "]::" .. ALPHA_NOISE[math.random(1,#ALPHA_NOISE)]
    end
    return table.concat(chunks, "\n")
end

local function buildAntiStealPayload(rawId)
    if CURRENT_MODE == "DIGIT" then return buildDigitPayload(rawId) end
    return buildUriPayload(rawId)
end

local function cleanAudioId(v)
    local t = tostring(v or ""):match("^%s*(.-)%s*$") or ""
    return t:match("rbxassetid://(%d+)") or t:match("[?&]id=(%d+)")
        or t:match("library/(%d+)") or t:match("(%d+)") or ""
end

------------------------------------------------------------------
-- PLAY / STOP LOGIC
------------------------------------------------------------------
local function refreshRemotes() ToolEvent, ScooterEvent = findRemotes() end

local function flushServerReset()
    refreshRemotes()
    pcall(function()
        if ToolEvent then
            ToolEvent:FireServer("ToolMusicStop","",nil)
            ToolEvent:FireServer("ToolMusicText", MUSIC_RESET_ID)
            ToolEvent:FireServer("ToolMusic", MUSIC_RESET_ID, 1)
            ToolEvent:FireServer("ToolMusicPlay","",nil)
        end
    end)
    pcall(function()
        if ScooterEvent then
            ScooterEvent:FireServer("PickingScooterMusicStop","",nil)
            ScooterEvent:FireServer("PickingScooterMusicText", MUSIC_RESET_ID)
            ScooterEvent:FireServer("PickingScooterMusic", MUSIC_RESET_ID, 1)
        end
    end)
end

local function equipBoombox()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    if not bp or not char then return nil end
    local tool = char:FindFirstChild("Boombox") or bp:FindFirstChild("Boombox")
    if not tool then
        for _, n in ipairs({"Super Boombox","BoomBox","Radio"}) do
            tool = char:FindFirstChild(n) or bp:FindFirstChild(n)
            if tool then break end
        end
    end
    if tool and tool.Parent == bp then pcall(function() tool.Parent = char end) end
    return tool
end

local function stopMusic()
    flushServerReset()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("Sound") and (d.Name == "PlayersChoice" or d.Name == "MusicOnlyLocalSound" or d.Name == BAIT_NAME) then
                d:Stop()
                if d.Name == "MusicOnlyLocalSound" then d:Destroy() else d.SoundId = "" end
            end
        end
    end)
end

-- ▓▓ ENFORCE BAIT NAME + PAYLOAD SOUNDID (C++ PARSES → REAL, SPY SEES BAIT) ▓▓
local function attachEnforcer(sound, expectedUri)
    if not sound or not expectedUri then return end
    pcall(function()
        sound.Name = BAIT_NAME
        sound.SoundId = expectedUri
        sound.Looped = true
        if sound.Volume <= 0.05 then sound.Volume = 1 end
        sound:Play()
    end)
end

local function playMusic(audioId)
    local cleaned = cleanAudioId(audioId)
    if cleaned == "" then return false, "กรุณาใส่ Audio ID" end

    refreshRemotes()
    if not ToolEvent and not ScooterEvent then
        return false, "ไม่พบ Remote เพลง (Brookhaven)"
    end

    local useAnti = ANTI_STEAL_ON
    local payload = useAnti and buildAntiStealPayload(cleaned) or cleaned
    -- ★ Local override: C++ parses "rbxassetid://" + payload → finds valid &id= → real ID plays
    -- ★ Spy reads Sound.SoundId (raw payload) + Sound.Name ("กันเจาะกากๆรัน") → bait wins
    local expectedUri = "rbxassetid://" .. payload

    flushServerReset()
    task.wait(MUSIC_RESET_HOLD)

    -- ── Server fire (broadcast → others hear music via C++ replication) ──
    pcall(function()
        if ToolEvent then
            if useAnti then
                ToolEvent:FireServer("ToolMusicText", payload, nil, true)
            else
                ToolEvent:FireServer("ToolMusicText", cleaned)
                ToolEvent:FireServer("ToolMusic", cleaned, 1)
                ToolEvent:FireServer("ToolMusicPlay","",nil)
            end
        end
    end)
    pcall(function()
        if ScooterEvent and (SELECTED_DEVICE ~= "Boombox") then
            if useAnti then
                for _ = 1, 2 do
                    ScooterEvent:FireServer("PickingScooterMusicText", payload, nil, true)
                    task.wait(0.06)
                end
            else
                ScooterEvent:FireServer("PickingScooterMusicText", cleaned)
                ScooterEvent:FireServer("PickingScooterMusic", cleaned, 1)
            end
        end
    end)

    -- ── Local Sound enforcement loop ──
    task.spawn(function()
        task.wait(0.35)
        local tool = equipBoombox()
        local snd
        if tool then
            snd = tool:FindFirstChild(BAIT_NAME, true)
                or tool:FindFirstChild("PlayersChoice", true)
                or tool:FindFirstChild(BAIT_ID, true)
                or tool:FindFirstChildWhichIsA("Sound", true)
        end
        if not snd then
            local char = LocalPlayer.Character
            if char then
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("Sound") then snd = d; break end
                end
            end
        end

        attachEnforcer(snd, expectedUri)

        -- Kill any existing loop, start a new one
        if _G.MusicEnforceConn then
            pcall(function() _G.MusicEnforceConn:Disconnect() end)
            _G.MusicEnforceConn = nil
        end
        if useAnti then
            _G.MusicEnforceConn = RunService.Heartbeat:Connect(function()
                if not ANTI_STEAL_ON then return end
                local t = equipBoombox()
                if not t then return end
                local s = t:FindFirstChild(BAIT_NAME, true)
                    or t:FindFirstChild("PlayersChoice", true)
                    or t:FindFirstChildWhichIsA("Sound", true)
                if s and s:IsA("Sound") then
                    pcall(function()
                        if s.Name ~= BAIT_NAME then s.Name = BAIT_NAME end
                        -- If server overwrote SoundId with plain ID (or bait), restore payload
                        local sid = tostring(s.SoundId or "")
                        if not sid:find(BAIT_ID, 1, true) and not sid:find("id", 1, true) then
                            s.SoundId = expectedUri
                            s.Looped = true
                            if not s.IsPlaying then s:Play() end
                        end
                    end)
                end
            end)
        end
    end)

    return true, cleaned
end

------------------------------------------------------------------
-- UI (keep original style, RGB title, mobile drag)
------------------------------------------------------------------
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,r or 10); c.Parent = p; return c end
local function stroke(p, col, w) local s = Instance.new("UIStroke"); s.Color = col or Color3.fromRGB(255,255,255); s.Thickness = w or 1.2; s.Transparency = 0.35; s.Parent = p; return s end
local function pad(p,t,b,l,r) local u = Instance.new("UIPadding"); u.PaddingTop=UDim.new(0,t or 8); u.PaddingBottom=UDim.new(0,b or 8); u.PaddingLeft=UDim.new(0,l or 10); u.PaddingRight=UDim.new(0,r or 10); u.Parent=p; return u end

local Root = Instance.new("ScreenGui")
Root.Name = "MusicOnlyRoot"
Root.ResetOnSpawn = false
Root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Root.Parent = GuiParent

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "MusicOnlyToggle"
ToggleBtn.Size = UDim2.new(0,52,0,52)
ToggleBtn.Position = UDim2.new(0,16,0.55,0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20,20,28)
ToggleBtn.Text = "♪"
ToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
ToggleBtn.TextSize = 22
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = Root
corner(ToggleBtn, 14)
stroke(ToggleBtn, Color3.fromRGB(255,80,200), 1.5)

local Win = Instance.new("Frame")
Win.Name = "Window"
Win.Size = UDim2.new(0, isMobile and 320 or 360, 0, isMobile and 420 or 460)
Win.Position = UDim2.new(0.5, -(isMobile and 160 or 180), 0.5, -(isMobile and 210 or 230))
Win.BackgroundColor3 = Color3.fromRGB(14,14,20)
Win.BackgroundTransparency = 0.08
Win.Active = true
Win.Parent = Root
corner(Win, 16)
stroke(Win, Color3.fromRGB(255,255,255), 1.2)

local WinGrad = Instance.new("UIGradient")
WinGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,60,120)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80,120,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40,255,180)),
})
WinGrad.Rotation = 45
WinGrad.Parent = Win

local WinInner = Instance.new("Frame")
WinInner.Size = UDim2.new(1,-2,1,-2)
WinInner.Position = UDim2.new(0,1,0,1)
WinInner.BackgroundColor3 = Color3.fromRGB(16,16,24)
WinInner.BackgroundTransparency = 0.05
WinInner.Parent = Win
corner(WinInner, 15)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1,0,0,44)
TitleBar.BackgroundColor3 = Color3.fromRGB(22,22,32)
TitleBar.BackgroundTransparency = 0.2
TitleBar.Parent = WinInner
corner(TitleBar, 15)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1,-50,1,0)
TitleLabel.Position = UDim2.new(0,14,0,0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "♪  Music Only  ·  " .. BAIT_NAME
TitleLabel.TextColor3 = Color3.fromRGB(255,255,255)
TitleLabel.TextSize = 15
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,32,0,32)
CloseBtn.Position = UDim2.new(1,-38,0.5,-16)
CloseBtn.BackgroundColor3 = Color3.fromRGB(40,20,28)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255,120,140)
CloseBtn.TextSize = 20
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = TitleBar
corner(CloseBtn, 8)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1,-16,1,-56)
Content.Position = UDim2.new(0,8,0,48)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(255,100,180)
Content.CanvasSize = UDim2.new(0,0,0,520)
Content.Parent = WinInner

local List = Instance.new("UIListLayout")
List.Padding = UDim.new(0,10)
List.SortOrder = Enum.SortOrder.LayoutOrder
List.Parent = Content

local function makeSection(title, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,-4,0,0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.BackgroundColor3 = Color3.fromRGB(24,24,34)
    f.BackgroundTransparency = 0.15
    f.LayoutOrder = order
    f.Parent = Content
    corner(f, 12)
    stroke(f, Color3.fromRGB(255,255,255), 0.8)
    pad(f, 10, 12, 12, 12)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,0,0,20)
    t.BackgroundTransparency = 1
    t.Text = title
    t.TextColor3 = Color3.fromRGB(200,210,255)
    t.TextSize = 13
    t.Font = Enum.Font.GothamBold
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = f
    local inner = Instance.new("Frame")
    inner.Size = UDim2.new(1,0,0,0)
    inner.Position = UDim2.new(0,0,0,26)
    inner.AutomaticSize = Enum.AutomaticSize.Y
    inner.BackgroundTransparency = 1
    inner.Parent = f
    local il = Instance.new("UIListLayout")
    il.Padding = UDim.new(0,8)
    il.SortOrder = Enum.SortOrder.LayoutOrder
    il.Parent = inner
    return inner
end

local function makeLabel(parent, txt, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,16); l.BackgroundTransparency = 1
    l.Text = txt; l.TextColor3 = Color3.fromRGB(160,170,190); l.TextSize = 12
    l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order; l.Parent = parent; return l
end

local function makeInput(parent, ph, order)
    local b = Instance.new("TextBox")
    b.Size = UDim2.new(1,0,0,36); b.BackgroundColor3 = Color3.fromRGB(30,30,42)
    b.Text = ""; b.PlaceholderText = ph; b.PlaceholderColor3 = Color3.fromRGB(110,115,140)
    b.TextColor3 = Color3.fromRGB(240,240,255); b.TextSize = 13; b.Font = Enum.Font.Gotham
    b.ClearTextOnFocus = false; b.LayoutOrder = order; b.Parent = parent
    corner(b, 9); stroke(b, Color3.fromRGB(120,100,255), 1); pad(b, 0, 0, 10, 10)
    return b
end

local function makeBtn(parent, txt, col, order)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,38); b.BackgroundColor3 = col or Color3.fromRGB(80,60,200)
    b.Text = txt; b.TextColor3 = Color3.fromRGB(255,255,255); b.TextSize = 13
    b.Font = Enum.Font.GothamBold; b.AutoButtonColor = false
    b.LayoutOrder = order; b.Parent = parent
    corner(b, 10); stroke(b, Color3.fromRGB(255,255,255), 0.9)
    b.MouseButton1Down:Connect(function() TweenService:Create(b, TweenInfo.new(0.08), {BackgroundTransparency = 0.25}):Play() end)
    b.MouseButton1Up:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play() end)
    return b
end

local function makeToggle(parent, label, default, order, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,32); row.BackgroundTransparency = 1; row.LayoutOrder = order; row.Parent = parent
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,-56,1,0); t.BackgroundTransparency = 1
    t.Text = label; t.TextColor3 = Color3.fromRGB(220,225,245); t.TextSize = 12
    t.Font = Enum.Font.Gotham; t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = row
    local track = Instance.new("Frame")
    track.Size = UDim2.new(0,46,0,24)
    track.Position = UDim2.new(1,-46,0.5,-12)
    track.BackgroundColor3 = default and Color3.fromRGB(60,200,140) or Color3.fromRGB(60,60,80)
    track.Parent = row; corner(track, 12)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,20,0,20)
    knob.Position = default and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255); knob.Parent = track; corner(knob, 10)
    local state = default
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(track, TweenInfo.new(0.15), {BackgroundColor3 = state and Color3.fromRGB(60,200,140) or Color3.fromRGB(60,60,80)}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = state and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)}):Play()
        if cb then cb(state) end
    end)
    return row
end

local function makeDropdown(parent, opts, default, order, cb)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1,0,0,36); holder.BackgroundTransparency = 1; holder.LayoutOrder = order
    holder.Parent = parent; holder.ClipsDescendants = false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,36); btn.BackgroundColor3 = Color3.fromRGB(30,30,42)
    btn.Text = "  " .. default .. "  ▼"; btn.TextColor3 = Color3.fromRGB(230,230,255)
    btn.TextSize = 12; btn.Font = Enum.Font.Gotham; btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false; btn.Parent = holder
    corner(btn, 9); stroke(btn, Color3.fromRGB(100,140,255), 1)
    local open = false; local listFrame
    btn.MouseButton1Click:Connect(function()
        if open and listFrame then listFrame:Destroy(); listFrame = nil; open = false; return end
        open = true
        listFrame = Instance.new("Frame")
        listFrame.Size = UDim2.new(1,0,0,math.min(#opts*32,160))
        listFrame.Position = UDim2.new(0,0,0,38)
        listFrame.BackgroundColor3 = Color3.fromRGB(28,28,40); listFrame.ZIndex = 20
        listFrame.Parent = holder
        corner(listFrame, 9); stroke(listFrame, Color3.fromRGB(120,100,255), 1)
        local sf = Instance.new("ScrollingFrame")
        sf.Size = UDim2.new(1,0,1,0); sf.BackgroundTransparency = 1
        sf.ScrollBarThickness = 3; sf.CanvasSize = UDim2.new(0,0,0,#opts*32); sf.ZIndex = 21; sf.Parent = listFrame
        local ll = Instance.new("UIListLayout"); ll.Parent = sf
        for _, opt in ipairs(opts) do
            local ob = Instance.new("TextButton")
            ob.Size = UDim2.new(1,0,0,32); ob.BackgroundColor3 = Color3.fromRGB(28,28,40)
            ob.Text = "  " .. opt; ob.TextColor3 = Color3.fromRGB(220,225,255); ob.TextSize = 12
            ob.Font = Enum.Font.Gotham; ob.TextXAlignment = Enum.TextXAlignment.Left
            ob.ZIndex = 22; ob.AutoButtonColor = false; ob.Parent = sf
            ob.MouseButton1Click:Connect(function()
                btn.Text = "  " .. opt .. "  ▼"
                if cb then cb(opt) end
                listFrame:Destroy(); listFrame = nil; open = false
            end)
        end
    end)
    return holder
end

local function notify(msg, ok)
    local n = Instance.new("TextLabel")
    n.Size = UDim2.new(0,280,0,36); n.Position = UDim2.new(0.5,-140,0,20)
    n.BackgroundColor3 = ok and Color3.fromRGB(30,80,60) or Color3.fromRGB(80,30,40)
    n.Text = msg; n.TextColor3 = Color3.fromRGB(255,255,255); n.TextSize = 12
    n.Font = Enum.Font.GothamBold; n.ZIndex = 50; n.Parent = Root
    corner(n, 10)
    task.delay(2.2, function() if n then n:Destroy() end end)
end

------------------------------------------------------------------
-- BUILD SECTIONS
------------------------------------------------------------------
local secPlay = makeSection("ระบบควบคุมเพลง", 1)
makeLabel(secPlay, "รหัสเสียง (Audio ID)", 1)
local idBox = makeInput(secPlay, "ใส่ Audio ID หรือลิงก์...", 2)
makeLabel(secPlay, "อุปกรณ์ส่งสัญญาณเสียง", 3)
makeDropdown(secPlay, DEVICES, SELECTED_DEVICE, 4, function(v) SELECTED_DEVICE = v end)
makeToggle(secPlay, "กันเจาะกากๆรัน (Anti-Steal)", ANTI_STEAL_ON, 5, function(v) ANTI_STEAL_ON = v end)
makeLabel(secPlay, "โหมดกันดัก", 6)
makeDropdown(secPlay, {"URI", "DIGIT"}, CURRENT_MODE, 7, function(v) CURRENT_MODE = v end)

local playBtn = makeBtn(secPlay, "▶  เริ่มเล่นเพลง", Color3.fromRGB(60,160,100), 8)
local stopBtn = makeBtn(secPlay, "■  หยุดเพลง", Color3.fromRGB(160,50,70), 9)

playBtn.MouseButton1Click:Connect(function()
    local ok, msg = playMusic(idBox.Text)
    notify(ok and ("กำลังเล่น: " .. tostring(msg)) or tostring(msg), ok)
end)
stopBtn.MouseButton1Click:Connect(function()
    if _G.MusicEnforceConn then pcall(function() _G.MusicEnforceConn:Disconnect() end) _G.MusicEnforceConn = nil end
    stopMusic(); notify("หยุดเพลงแล้ว", true)
end)

local secInfo = makeSection("สถานะ", 2)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1,0,0,60); statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Bait: " .. BAIT_NAME .. "\nID: " .. BAIT_ID .. "\nโหมด: " .. CURRENT_MODE
statusLabel.TextColor3 = Color3.fromRGB(170,180,210); statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham; statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.LayoutOrder = 1; statusLabel.Parent = secInfo

task.spawn(function()
    local h = 0
    while Root.Parent do
        h = (h + 0.004) % 1
        local c = Color3.fromHSV(h, 0.7, 1)
        TitleLabel.TextColor3 = c
        local st = ToggleBtn:FindFirstChildOfClass("UIStroke"); if st then st.Color = c end
        task.wait(0.03)
    end
end)

------------------------------------------------------------------
-- DRAG
------------------------------------------------------------------
local dragging, dragStart, startPos
local function beginDrag(input) dragging=true; dragStart=input.Position; startPos=Win.Position
    input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
end
local function updateDrag(input)
    if not dragging then return end
    local d = input.Position - dragStart
    Win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
end
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then beginDrag(i) end
end)
UserInputService.InputChanged:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then updateDrag(i) end
end)

local visible = true
ToggleBtn.MouseButton1Click:Connect(function() visible = not visible; Win.Visible = visible end)
CloseBtn.MouseButton1Click:Connect(function() Win.Visible = false end)

do
    local tDrag, tStart, tPos
    ToggleBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            tDrag = true; tStart = i.Position; tPos = ToggleBtn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not tDrag then return end
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - tStart
            if d.Magnitude > 8 then
                ToggleBtn.Position = UDim2.new(tPos.X.Scale, tPos.X.Offset+d.X, tPos.Y.Scale, tPos.Y.Offset+d.Y)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then tDrag = false end
    end)
end

print("[Music Only V2] Loaded · Bait = " .. BAIT_NAME .. " (" .. BAIT_ID .. ") · Anti-Steal Ready")