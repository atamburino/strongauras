-- StrongAuras Display
-- Creates and manages WoW frames for each aura (icon or bar style).

local SA = StrongAuras

SA.Display = {}
local D = SA.Display

-- Live frame pool keyed by aura name
D.frames = {}

-- ─── Public API ──────────────────────────────────────────────────────────────

-- Re-create frames for all loaded auras (called on login).
function D:RefreshAll()
    SA:LoadAuras()
    for _, aura in pairs(SA.auras) do
        self:Refresh(aura)
    end
end

-- Create or recreate the frame for a single aura.
function D:Refresh(aura)
    self:Remove(aura.name)
    if not aura.enabled then return end

    if aura.shape == SA.Aura.SHAPE.ICON then
        self.frames[aura.name] = D:CreateIconFrame(aura)
    elseif aura.shape == SA.Aura.SHAPE.BAR then
        self.frames[aura.name] = D:CreateBarFrame(aura)
    end
end

-- Update an existing frame's visual state from aura runtime data.
function D:Update(aura)
    local f = self.frames[aura.name]
    if not f then return end
    f:SAUpdate(aura)
end

-- Destroy a frame by aura name.
function D:Remove(name)
    if self.frames[name] then
        self.frames[name]:Hide()
        self.frames[name] = nil
    end
end

-- Reset all aura anchor positions to center of screen.
function D:ResetPositions()
    for name, f in pairs(self.frames) do
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        local aura = SA.auras[name]
        if aura then
            aura.x, aura.y = 0, 0
            SA:SaveAura(aura)
        end
    end
end

-- ─── Icon frame ──────────────────────────────────────────────────────────────

function D:CreateIconFrame(aura)
    local sz = aura.size

    local f = CreateFrame("Frame", "SAIcon_" .. aura.name, UIParent)
    f:SetSize(sz, sz)
    f:SetPoint("CENTER", UIParent, "CENTER", aura.x, aura.y)
    f:SetAlpha(aura.alpha)
    f:SetMovable(true)
    f:EnableMouse(false)  -- mouse enabled only in config mode
    f:SetClampedToScreen(true)

    -- Spell icon texture
    local icon = f:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(f)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- trim default WoW icon border
    f.icon = icon

    -- Cooldown swipe overlay
    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints(f)
    cd:SetDrawSwipe(true)
    cd:SetDrawEdge(true)
    cd:SetSwipeColor(0, 0, 0, 0.8)
    f.cooldown = cd

    -- Countdown text
    if aura.showText then
        local txt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        txt:SetPoint("CENTER", f, "CENTER", 0, 0)
        txt:SetJustifyH("CENTER")
        txt:SetTextColor(1, 1, 1)
        f.countText = txt
    end

    -- Dim overlay when inactive
    local dimmer = f:CreateTexture(nil, "OVERLAY")
    dimmer:SetAllPoints(f)
    dimmer:SetColorTexture(0, 0, 0, 0.6)
    dimmer:Hide()
    f.dimmer = dimmer

    -- Glow frame (simple border flash when CD is ready)
    if aura.glowOnReady then
        local glow = CreateFrame("Frame", nil, f, "BackdropTemplate")
        glow:SetPoint("TOPLEFT",     f, "TOPLEFT",     -3, 3)
        glow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  3, -3)
        glow:SetBackdrop({
            edgeFile = "Interface\\Buttons\\UI-ActionButton-Border",
            edgeSize = 14,
        })
        glow:SetBackdropBorderColor(1, 1, 0, 1)  -- yellow glow
        glow:Hide()
        f.glow = glow
    end

    -- Load icon texture
    D:SetIconTexture(f, aura)

    -- Update function called by Triggers
    f.SAUpdate = function(self, a)
        if a.auraType == SA.Aura.TYPE.COOLDOWN then
            D:UpdateIconCooldown(self, a)
        else
            D:UpdateIconBuff(self, a)
        end
    end

    return f
end

function D:SetIconTexture(f, aura)
    local tex = aura.iconPath
    if not tex and aura.spellID and aura.spellID ~= 0 then
        tex = select(3, GetSpellInfo(aura.spellID))
    end
    if not tex and aura.spellName and aura.spellName ~= "" then
        tex = select(3, GetSpellInfo(aura.spellName))
    end
    f.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
end

function D:UpdateIconBuff(f, aura)
    if aura._active then
        f.dimmer:Hide()
        f:SetAlpha(aura.alpha)
        if f.glow then f.glow:Hide() end
        if f.countText then
            if aura._remaining > 0 then
                f.countText:SetText(D:FormatTime(aura._remaining))
            else
                f.countText:SetText("")
            end
        end
        if f.cooldown and aura._duration > 0 then
            local start = GetTime() + aura._remaining - aura._duration
            f.cooldown:SetCooldown(start, aura._duration)
        else
            f.cooldown:SetCooldown(0, 0)
        end
    else
        f.dimmer:Show()
        f:SetAlpha(aura.alpha * 0.5)
        if f.countText then f.countText:SetText("") end
        if f.cooldown then f.cooldown:SetCooldown(0, 0) end
        if f.glow then f.glow:Hide() end
    end
end

function D:UpdateIconCooldown(f, aura)
    if aura._active then
        -- On cooldown
        f.dimmer:Show()
        f:SetAlpha(aura.alpha)
        if f.glow then f.glow:Hide() end
        if f.cooldown and aura._duration > 0 then
            local start = GetTime() + aura._remaining - aura._duration
            f.cooldown:SetCooldown(start, aura._duration)
        end
        if f.countText then
            f.countText:SetText(D:FormatTime(aura._remaining))
        end
    else
        -- Ready
        f.dimmer:Hide()
        f:SetAlpha(aura.alpha)
        if f.cooldown then f.cooldown:SetCooldown(0, 0) end
        if f.countText then f.countText:SetText("") end
        if f.glow then f.glow:Show() end
    end
end

-- ─── Bar frame ───────────────────────────────────────────────────────────────

function D:CreateBarFrame(aura)
    local w = aura.size
    local h = aura.thickness
    local c = aura.barColor

    local f = CreateFrame("Frame", "SABar_" .. aura.name, UIParent)
    f:SetSize(w, h)
    f:SetPoint("CENTER", UIParent, "CENTER", aura.x, aura.y)
    f:SetAlpha(aura.alpha)
    f:SetMovable(true)
    f:EnableMouse(false)
    f:SetClampedToScreen(true)

    -- Background
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0, 0, 0, 0.6)

    -- Foreground bar
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetAllPoints(f)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(c.r, c.g, c.b, c.a)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    f.bar = bar

    -- Label
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", f, "LEFT", 4, 0)
    label:SetTextColor(1, 1, 1)
    label:SetText(aura.spellName)
    f.label = label

    -- Time text
    if aura.showText then
        local timeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        timeText:SetPoint("RIGHT", f, "RIGHT", -4, 0)
        timeText:SetTextColor(1, 1, 1)
        f.timeText = timeText
    end

    f.SAUpdate = function(self, a)
        local pct = 0
        if a._duration > 0 then
            if a.auraType == SA.Aura.TYPE.COOLDOWN then
                -- Bar drains as CD ticks down
                pct = a._remaining / a._duration
            else
                -- Bar fills as buff duration remains
                pct = a._remaining / a._duration
            end
        elseif a._active then
            pct = 1
        end
        self.bar:SetValue(math.max(0, math.min(1, pct)))
        if self.timeText then
            self.timeText:SetText(a._remaining > 0 and D:FormatTime(a._remaining) or "")
        end
    end

    return f
end

-- ─── Utilities ───────────────────────────────────────────────────────────────

-- Format seconds into "1:23" or "45" or "4.2"
function D:FormatTime(seconds)
    if seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    elseif seconds >= 10 then
        return string.format("%d", math.floor(seconds))
    else
        return string.format("%.1f", seconds)
    end
end

-- Enable or disable drag for all frames (used by config mode).
function D:SetDraggable(state)
    for _, f in pairs(self.frames) do
        f:EnableMouse(state)
        if state then
            f:SetScript("OnMouseDown", function(self, btn)
                if btn == "LeftButton" then self:StartMoving() end
            end)
            f:SetScript("OnMouseUp", function(self, btn)
                if btn == "LeftButton" then
                    self:StopMovingOrSizing()
                    -- Persist new position
                    local name = self:GetName():match("^SA%a+_(.+)$")
                    local aura = name and SA.auras[name]
                    if aura then
                        local point, _, _, x, y = self:GetPoint()
                        aura.x, aura.y = x, y
                        SA:SaveAura(aura)
                    end
                end
            end)
        else
            f:SetScript("OnMouseDown", nil)
            f:SetScript("OnMouseUp", nil)
        end
    end
end
