-- 导入 / 导出：把用户自定义（触发开关 + 自定义清单）序列化成可分享字符串。
-- 字符串格式：RPF1! + base64(Lua 源码)。UI 走暴雪原生多行 EditBox（无 Ace）。
local addonName, RPF = ...

local PREFIX = "RPF1!"   -- 版本前缀；格式不兼容再 bump 成 RPF2!

-- 导出哪些字段（只导用户配置，不导 tShownEnter 这种瞬时状态）
local function buildPayload()
    local db = RPF.db
    return {
        v = 1,
        settings = {
            bEnabled  = db.bEnabled,
            bOnSummon = db.bOnSummon,
            bOnEnter  = db.bOnEnter,
            bOnPull   = db.bOnPull,
            iEnterCooldown = db.iEnterCooldown,
        },
        tGlobal = db.tGlobal,
        tZones  = db.tZones,
    }
end

-- 导出 → 字符串
function RPF:ExportConfig()
    local src = self:SerializeTable(buildPayload())
    return PREFIX .. self:Base64Encode(src)
end

-- 解析字符串 → payload 或 nil,err（只校验，不写库）
function RPF:DecodeImportString(str)
    if type(str) ~= "string" or str == "" then return nil, "导入字符串为空" end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    if str:sub(1, #PREFIX) ~= PREFIX then
        return nil, "前缀错误：应以 " .. PREFIX .. " 开头"
    end
    local raw, err = self:Base64Decode(str:sub(#PREFIX + 1))
    if not raw then return nil, err end
    local payload, perr = self:SafeLoadTable(raw)
    if not payload then return nil, perr end
    if type(payload.settings) ~= "table" then return nil, "数据缺少 settings" end
    return payload
end

-- 真正导入：覆盖 settings / tGlobal / tZones
function RPF:ImportConfig(str)
    local payload, err = self:DecodeImportString(str)
    if not payload then return false, err end
    local db = self.db
    local s = payload.settings
    if s.bEnabled  ~= nil then db.bEnabled  = s.bEnabled end
    if s.bOnSummon ~= nil then db.bOnSummon = s.bOnSummon end
    if s.bOnEnter  ~= nil then db.bOnEnter  = s.bOnEnter end
    if s.bOnPull   ~= nil then db.bOnPull   = s.bOnPull end
    if type(s.iEnterCooldown) == "number" then db.iEnterCooldown = s.iEnterCooldown end
    db.tGlobal = self.deepCopy(payload.tGlobal or {})
    db.tZones  = self.deepCopy(payload.tZones or {})
    self:Fire("RPF_ConfigChanged")
    return true
end

-- =====================================================================
-- 原生多行文本弹窗（导入/导出共用）
-- =====================================================================
local popup

local function ensurePopup()
    if popup then return popup end
    popup = CreateFrame("Frame", "RaidPreflightTextPopup", UIParent)
    popup:SetSize(560, 380)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetMovable(true); popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("TOP", 0, -16)
    popup.status = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.status:SetPoint("BOTTOM", 0, 46)
    popup.status:SetWidth(520); popup.status:SetJustifyH("CENTER")

    local sf = CreateFrame("ScrollFrame", "RaidPreflightTextPopupScroll", popup, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -44)
    sf:SetPoint("BOTTOMRIGHT", -34, 78)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetMaxLetters(0)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(500)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(eb)
    popup.editbox = eb

    popup.btnMain = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.btnMain:SetSize(150, 24)
    popup.btnMain:SetPoint("BOTTOMLEFT", 16, 14)
    popup.btnAlt = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.btnAlt:SetSize(150, 24)
    popup.btnAlt:SetPoint("BOTTOMRIGHT", -16, 14)
    popup.btnAlt:SetText("关闭")
    popup.btnAlt:SetScript("OnClick", function() popup:Hide() end)

    popup:Hide()
    return popup
end

function RPF:ShowExportFrame()
    local p = ensurePopup()
    local str = self:ExportConfig()
    p.title:SetText("导出配置")
    p.status:SetText(("共 %d 字符 — 点「全选」后 Ctrl+C 复制，发给朋友"):format(#str))
    p.editbox:SetText(str)
    p.editbox:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(str); self:HighlightText() end  -- 防误编辑
    end)
    p.btnMain:SetText("全选")
    p.btnMain:SetScript("OnClick", function() p.editbox:SetFocus(); p.editbox:HighlightText() end)
    p:Show()
    p.editbox:SetFocus(); p.editbox:HighlightText()
end

function RPF:ShowImportFrame()
    local p = ensurePopup()
    p.title:SetText("导入配置")
    p.status:SetText("把朋友给你的 RPF1! 字符串粘贴到下面，再点「导入」")
    p.editbox:SetText("")
    p.editbox:SetScript("OnTextChanged", nil)
    p.btnMain:SetText("导入")
    p.btnMain:SetScript("OnClick", function()
        local ok, err = RPF:ImportConfig(p.editbox:GetText())
        if ok then
            p.status:SetText("|cff33ff33导入成功|r")
            print("|cff66ccffRaidPreflight|r：配置导入成功。")
            p:Hide()
        else
            p.status:SetText("|cffff4040导入失败：" .. tostring(err) .. "|r")
        end
    end)
    p:Show()
    p.editbox:SetFocus()
end
