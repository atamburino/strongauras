-- StrongAuras Triggers
-- Polls or event-listens for buff/debuff/cooldown state and updates auras.

local SA = StrongAuras

SA.Triggers = {}
local T = SA.Triggers

-- How often (seconds) the cooldown/buff poll runs
local POLL_RATE = 0.1

local trackerFrame = CreateFrame("Frame", "StrongAurasTrackerFrame")
local elapsed = 0

-- ─── Event registration ──────────────────────────────────────────────────────

function T:StartTracking()
    -- Unit aura events cover buff/debuff gain/fade
    trackerFrame:RegisterEvent("UNIT_AURA")
    trackerFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    trackerFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    trackerFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

    trackerFrame:SetScript("OnEvent", function(_, event, ...)
        T:OnEvent(event, ...)
    end)

    -- OnUpdate drives cooldown countdown text
    trackerFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= POLL_RATE then
            elapsed = 0
            T:PollCooldowns()
        end
    end)
end

function T:OnEvent(event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            T:CheckBuffs()
            T:CheckDebuffs()
        end

    elseif event == "SPELL_UPDATE_COOLDOWN" then
        T:CheckCooldowns()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        if unit == "player" then
            T:CheckCooldowns()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        T:CheckTargetDebuffs()
    end
end

-- ─── Buff / Debuff checks ─────────────────────────────────────────────────────

function T:CheckBuffs()
    if not SA.auras then return end
    for _, aura in pairs(SA.auras) do
        if aura.enabled and aura.auraType == SA.Aura.TYPE.BUFF then
            local found, remaining, duration = T:FindUnitAura("player", aura.spellName, "HELPFUL")
            aura._active    = found
            aura._remaining = remaining
            aura._duration  = duration
            SA.Display:Update(aura)
        end
    end
end

function T:CheckDebuffs()
    if not SA.auras then return end
    for _, aura in pairs(SA.auras) do
        if aura.enabled and aura.auraType == SA.Aura.TYPE.DEBUFF then
            local found, remaining, duration = T:FindUnitAura("player", aura.spellName, "HARMFUL")
            aura._active    = found
            aura._remaining = remaining
            aura._duration  = duration
            SA.Display:Update(aura)
        end
    end
end

function T:CheckTargetDebuffs()
    if not SA.auras then return end
    for _, aura in pairs(SA.auras) do
        if aura.enabled and aura.auraType == SA.Aura.TYPE.TARGET_DEBUFF then
            local found, remaining, duration = T:FindUnitAura("target", aura.spellName, "HARMFUL")
            aura._active    = found
            aura._remaining = remaining
            aura._duration  = duration
            SA.Display:Update(aura)
        end
    end
end

function T:CheckCooldowns()
    if not SA.auras then return end
    for _, aura in pairs(SA.auras) do
        if aura.enabled and aura.auraType == SA.Aura.TYPE.COOLDOWN then
            T:UpdateCooldownState(aura)
        end
    end
end

-- Called on every poll tick so countdown text stays current
function T:PollCooldowns()
    if not SA.auras then return end
    for _, aura in pairs(SA.auras) do
        if aura.enabled and aura.auraType == SA.Aura.TYPE.COOLDOWN then
            T:UpdateCooldownState(aura)
        end
    end
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────

-- Returns active, remaining, duration for a named buff/debuff on unit.
function T:FindUnitAura(unit, spellName, filter)
    for i = 1, 40 do
        local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not auraData then break end
        if auraData.name == spellName then
            local remaining = 0
            local duration  = auraData.duration or 0
            if auraData.expirationTime and auraData.expirationTime > 0 then
                remaining = auraData.expirationTime - GetTime()
            end
            return true, remaining, duration
        end
    end
    return false, 0, 0
end

-- Updates cooldown aura state using GetSpellCooldown.
function T:UpdateCooldownState(aura)
    local spellID = aura.spellID
    if not spellID or spellID == 0 then
        -- Try looking up by name
        spellID = select(7, GetSpellInfo(aura.spellName)) or 0
    end

    local start, duration, enabled = GetSpellCooldown(spellID)
    if not start then
        aura._active    = false
        aura._remaining = 0
        aura._duration  = 0
        SA.Display:Update(aura)
        return
    end

    local onGCD = (duration and duration <= 1.5)
    if onGCD then
        -- Ignore the GCD; treat as ready
        aura._active    = false
        aura._remaining = 0
        aura._duration  = 0
    else
        local remaining = 0
        if start > 0 and duration > 0 then
            remaining = (start + duration) - GetTime()
        end
        aura._active    = remaining > 0
        aura._remaining = math.max(remaining, 0)
        aura._duration  = duration or 0
    end

    SA.Display:Update(aura)
end
