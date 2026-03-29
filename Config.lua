-- StrongAuras Config
-- In-game designer UI for creating and editing auras.

local SA = StrongAuras

SA.Config = {}
local C = SA.Config

local PANEL_W = 340
local PANEL_H = 520

-- ─── Toggle ──────────────────────────────────────────────────────────────────

function C:Toggle()
    if not self.panel then
        self:Build()
    end
    if self.panel:IsShown() then
        self.panel:Hide()
        SA.Display:SetDraggable(false)
    else
        self:Populate()
        self.panel:Show()
        SA.Display:SetDraggable(true)
    end
end

-- ─── Panel construction ──────────────────────────────────────────────────────

function C:Build()
    local p = CreateFrame("Frame", "StrongAurasConfig", UIParent, "BackdropTemplate")
    p:SetSize(PANEL_W, PANEL_H)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    p:SetFrameStrata("HIGH")
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop",  p.StopMovingOrSizing)
    p:SetClampedToScreen(true)

    p:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left=8, right=8, top=8, bottom=8 },
    })

    -- Title
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", p, "TOP", 0, -14)
    title:SetText("StrongAuras Designer")
    title:SetTextColor(0, 1, 1)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() C:Toggle() end)

    -- ── Aura list ──────────────────────────────────────────────────────────

    local listLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -44)
    listLabel:SetText("Auras:")

    local listFrame = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    listFrame:SetPoint("TOPLEFT",  p, "TOPLEFT",  14, -60)
    listFrame:SetPoint("TOPRIGHT", p, "TOPRIGHT", -30, -60)
    listFrame:SetHeight(120)

    local listContent = CreateFrame("Frame", nil, listFrame)
    listContent:SetSize(PANEL_W - 44, 400)
    listFrame:SetScrollChild(listContent)

    p.listContent = listContent

    -- ── Editor section ────────────────────────────────────────────────────

    local editorY = -200

    local function MakeLabel(text, offsetY)
        local lbl = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", p, "TOPLEFT", 16, offsetY)
        lbl:SetText(text)
        return lbl
    end

    local function MakeEditBox(offsetY, width)
        local eb = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
        eb:SetPoint("TOPLEFT", p, "TOPLEFT", 110, offsetY + 2)
        eb:SetSize(width or 180, 20)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(128)
        return eb
    end

    MakeLabel("Name:",      editorY)
    local nameBox = MakeEditBox(editorY)
    p.nameBox = nameBox

    MakeLabel("Spell ID:",  editorY - 28)
    local spellBox = MakeEditBox(editorY - 28)
    p.spellBox = spellBox

    MakeLabel("Type:",      editorY - 56)
    -- Simple dropdown via a button cycling through types
    local typeBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    typeBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 110, editorY - 52)
    typeBtn:SetSize(130, 22)
    local typeOrder = { SA.Aura.TYPE.BUFF, SA.Aura.TYPE.DEBUFF, SA.Aura.TYPE.TARGET_DEBUFF, SA.Aura.TYPE.COOLDOWN }
    local typeIdx = 1
    typeBtn:SetText(typeOrder[typeIdx])
    typeBtn:SetScript("OnClick", function()
        typeIdx = typeIdx % #typeOrder + 1
        typeBtn:SetText(typeOrder[typeIdx])
    end)
    p.typeBtn  = typeBtn
    p.typeOrder = typeOrder
    p.typeIdx   = function() return typeIdx end

    MakeLabel("Shape:",     editorY - 84)
    local shapeBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    shapeBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 110, editorY - 80)
    shapeBtn:SetSize(80, 22)
    local shapeOrder = { SA.Aura.SHAPE.ICON, SA.Aura.SHAPE.BAR }
    local shapeIdx = 1
    shapeBtn:SetText(shapeOrder[shapeIdx])
    shapeBtn:SetScript("OnClick", function()
        shapeIdx = shapeIdx % #shapeOrder + 1
        shapeBtn:SetText(shapeOrder[shapeIdx])
    end)
    p.shapeBtn   = shapeBtn
    p.shapeOrder = shapeOrder
    p.shapeIdx   = function() return shapeIdx end

    MakeLabel("Size:",      editorY - 112)
    local sizeBox = MakeEditBox(editorY - 112, 60)
    sizeBox:SetText("48")
    p.sizeBox = sizeBox

    -- ── Action buttons ────────────────────────────────────────────────────

    local saveBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    saveBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 16)
    saveBtn:SetSize(90, 24)
    saveBtn:SetText("Save Aura")
    saveBtn:SetScript("OnClick", function() C:SaveCurrent() end)

    local deleteBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    deleteBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 116, 16)
    deleteBtn:SetSize(90, 24)
    deleteBtn:SetText("Delete")
    deleteBtn:SetScript("OnClick", function() C:DeleteCurrent() end)

    local newBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    newBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 16)
    newBtn:SetSize(90, 24)
    newBtn:SetText("New Aura")
    newBtn:SetScript("OnClick", function() C:ClearEditor() end)

    -- Status text
    local status = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("BOTTOM", p, "BOTTOM", 0, 44)
    p.status = status

    self.panel  = p
    self.typeOrder  = typeOrder
    self.shapeOrder = shapeOrder
    self._typeIdx   = function() return typeIdx end
    self._shapeIdx  = function() return shapeIdx end
    self._setType   = function(i) typeIdx = i; typeBtn:SetText(typeOrder[i]) end
    self._setShape  = function(i) shapeIdx = i; shapeBtn:SetText(shapeOrder[i]) end
end

-- ─── List population ─────────────────────────────────────────────────────────

function C:Populate()
    local content = self.panel.listContent
    -- Clear old buttons
    for _, child in pairs({ content:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    local y = 0
    for name, aura in pairs(SA.auras or {}) do
        local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        btn:SetSize(PANEL_W - 60, 22)
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        btn:SetText((aura.enabled and "" or "|cff888888") .. name .. " [" .. aura.auraType .. "]")
        btn:SetScript("OnClick", function() C:LoadEditor(aura) end)
        y = y - 26
    end

    if not next(SA.auras or {}) then
        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", 4, 0)
        hint:SetText("No auras yet. Click 'New Aura' to create one.")
        hint:SetTextColor(0.7, 0.7, 0.7)
    end
end

-- ─── Editor helpers ──────────────────────────────────────────────────────────

function C:LoadEditor(aura)
    local p = self.panel
    p.nameBox:SetText(aura.name)
    p.spellBox:SetText(tostring(aura.spellID or ""))
    p.sizeBox:SetText(tostring(aura.size or 48))

    for i, t in ipairs(self.typeOrder) do
        if t == aura.auraType then self._setType(i) break end
    end
    for i, s in ipairs(self.shapeOrder) do
        if s == aura.shape then self._setShape(i) break end
    end

    self._editing = aura.name
    p.status:SetText("Editing: " .. aura.name)
end

function C:ClearEditor()
    local p = self.panel
    p.nameBox:SetText("")
    p.spellBox:SetText("")
    p.sizeBox:SetText("48")
    self._setType(1)
    self._setShape(1)
    self._editing = nil
    p.status:SetText("New aura")
end

function C:SaveCurrent()
    local p = self.panel
    local name = strtrim(p.nameBox:GetText())
    if name == "" then
        p.status:SetText("|cffff4444Name cannot be empty.|r")
        return
    end

    local spellID = tonumber(p.spellBox:GetText()) or 0
    local size    = tonumber(p.sizeBox:GetText()) or 48

    SA:UpsertAura(name, {
        spellID   = spellID,
        spellName = spellID > 0 and (GetSpellInfo(spellID) or "") or name,
        auraType  = self.typeOrder[self._typeIdx()],
        shape     = self.shapeOrder[self._shapeIdx()],
        size      = size,
    })

    self._editing = name
    p.status:SetText("|cff00ff00Saved: " .. name .. "|r")
    self:Populate()
end

function C:DeleteCurrent()
    local name = self._editing or strtrim(self.panel.nameBox:GetText())
    if name == "" then return end
    SA:DeleteAura(name)
    self:ClearEditor()
    self.panel.status:SetText("|cffffaa00Deleted: " .. name .. "|r")
    self:Populate()
end
