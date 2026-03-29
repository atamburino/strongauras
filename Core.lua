-- StrongAuras Core
-- Initializes the addon, registers events, and wires subsystems together.

StrongAuras = {}
local SA = StrongAuras

-- Default saved variable structure
local DB_DEFAULTS = {
    auras = {},   -- keyed by aura name
    version = 1,
}

-- ─── Initialization ──────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame", "StrongAurasEventFrame")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "StrongAuras" then
            SA:OnLoad()
        end

    elseif event == "PLAYER_LOGIN" then
        SA.Triggers:StartTracking()
        SA.Display:RefreshAll()

    elseif event == "PLAYER_LOGOUT" then
        SA:SaveDB()
    end
end)

-- ─── DB helpers ──────────────────────────────────────────────────────────────

function SA:OnLoad()
    if not StrongAurasDB then
        StrongAurasDB = CopyTable(DB_DEFAULTS)
    end
    -- Migrate / fill missing keys
    for k, v in pairs(DB_DEFAULTS) do
        if StrongAurasDB[k] == nil then
            StrongAurasDB[k] = v
        end
    end
    self.db = StrongAurasDB
    print("|cff00ffffStrongAuras|r loaded. Type |cffffd700/sa|r to open the designer.")
end

function SA:SaveDB()
    StrongAurasDB = self.db
end

-- ─── Slash command ───────────────────────────────────────────────────────────

SLASH_STRONGAURAS1 = "/sa"
SLASH_STRONGAURAS2 = "/strongauras"

SlashCmdList["STRONGAURAS"] = function(msg)
    local cmd = strtrim(msg):lower()
    if cmd == "config" or cmd == "" then
        SA.Config:Toggle()
    elseif cmd == "reset" then
        SA.Display:ResetPositions()
        print("|cff00ffffStrongAuras|r: Aura positions reset.")
    else
        print("|cff00ffffStrongAuras|r commands:")
        print("  /sa         - Open designer")
        print("  /sa reset   - Reset all aura positions")
    end
end
