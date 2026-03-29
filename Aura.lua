-- StrongAuras Aura
-- Data model for a single aura (spell tracker entry).

local SA = StrongAuras

SA.Aura = {}
local Aura = SA.Aura

-- Aura types
Aura.TYPE = {
    BUFF       = "buff",        -- buff on the player
    DEBUFF     = "debuff",      -- debuff on the player
    TARGET_DEBUFF = "target_debuff", -- debuff on the current target
    COOLDOWN   = "cooldown",    -- spell cooldown
}

-- Display shapes
Aura.SHAPE = {
    ICON = "icon",   -- spell icon with cooldown swipe
    BAR  = "bar",    -- horizontal / vertical progress bar
}

-- ─── Constructor ─────────────────────────────────────────────────────────────

-- Returns a new aura definition table with defaults applied.
-- @param name   string  unique identifier (used as saved variable key)
-- @param opts   table   override any default field
function Aura.New(name, opts)
    opts = opts or {}
    return {
        name        = name,
        enabled     = opts.enabled     ~= false,  -- default true
        spellID     = opts.spellID     or 0,
        spellName   = opts.spellName   or "",
        auraType    = opts.auraType    or Aura.TYPE.BUFF,
        shape       = opts.shape       or Aura.SHAPE.ICON,
        size        = opts.size        or 48,      -- width (icon) or length (bar)
        thickness   = opts.thickness   or 20,      -- bar height only
        x           = opts.x           or 0,
        y           = opts.y           or 0,
        alpha       = opts.alpha       or 1.0,
        showText    = opts.showText    ~= false,   -- cooldown countdown
        iconPath    = opts.iconPath    or nil,     -- override icon texture
        barColor    = opts.barColor    or { r=0.2, g=0.6, b=1.0, a=1.0 },
        glowOnReady = opts.glowOnReady ~= false,   -- glow when CD is ready
        -- runtime state (not persisted)
        _active     = false,
        _remaining  = 0,
        _duration   = 0,
    }
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────

-- Load all auras from saved variables into SA.auras (live table).
function SA:LoadAuras()
    self.auras = {}
    for k, saved in pairs(self.db.auras) do
        self.auras[k] = Aura.New(k, saved)
    end
end

-- Persist a single aura definition (strips runtime _fields).
function SA:SaveAura(aura)
    local out = {}
    for k, v in pairs(aura) do
        if k:sub(1,1) ~= "_" then
            out[k] = v
        end
    end
    self.db.auras[aura.name] = out
end

-- Delete an aura by name.
function SA:DeleteAura(name)
    self.auras[name] = nil
    self.db.auras[name] = nil
    self.Display:Remove(name)
end

-- Add or update an aura definition and immediately refresh its display.
function SA:UpsertAura(name, opts)
    local existing = self.auras and self.auras[name]
    local aura = Aura.New(name, opts)
    if not self.auras then self.auras = {} end
    self.auras[name] = aura
    self:SaveAura(aura)
    self.Display:Refresh(aura)
    return aura
end
