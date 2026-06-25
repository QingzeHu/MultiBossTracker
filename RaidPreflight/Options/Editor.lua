-- 检查清单编辑器（暴雪原生，无 Ace）
-- 选作用域（通用 / 某副本 / 某副本的某 boss）→ 看该作用域的自定义检查 → 增 / 删。
local addonName, RPF = ...

local TYPE_LABELS = {
    item         = "物品（包里数量）",
    aura_keyword = "光环关键字（自身 buff）",
    comp         = "团队职业（可带专精）",
}
local TYPE_ORDER = { "item", "aura_keyword", "comp" }
local TYPE_HINT = {
    item         = "填 itemID（数字），如 5512",
    aura_keyword = "填关键字，逗号分隔，如 合剂,营养充足",
    comp         = "填职业 token（如 WARLOCK），数字视为专精ID，如 WARLOCK 266 267",
}

-- 把表单内容拼成一条检查 descriptor（可单测）。
function RPF:BuildCheckDescriptor(sType, sLabel, sParam)
    sLabel = (sLabel and sLabel:gsub("^%s+", ""):gsub("%s+$", "")) or ""
    if sLabel == "" then return nil, "请填标签" end
    if sType == "item" then
        local id = tonumber(sParam)
        if not id then return nil, "物品需要数字 itemID" end
        return { sType = "item", iItemID = id, iMin = 1, sLabel = sLabel }
    elseif sType == "aura_keyword" then
        local kws = {}
        for w in (sParam or ""):gmatch("[^,，%s]+") do kws[#kws + 1] = w end
        if #kws == 0 then return nil, "请填至少一个关键字" end
        return { sType = "aura_keyword", aKeywords = kws, sLabel = sLabel }
    elseif sType == "comp" then
        local classes, specs = {}, {}
        for tok in (sParam or ""):gmatch("[^,，%s]+") do
            if tok:match("^%d+$") then specs[#specs + 1] = tonumber(tok)
            else classes[#classes + 1] = tok:upper() end
        end
        if #classes == 0 then return nil, "请填至少一个职业（如 WARLOCK）" end
        local d = { sType = "comp", aClasses = classes, sLabel = sLabel }
        if #specs > 0 then d.aSpecIDs = specs end
        return d
    end
    return nil, "未知类型"
end

local function descText(d)
    if d.sType == "item" then
        return ("|cff88ccff[物品]|r %s  (id %s)"):format(d.sLabel or "?", tostring(d.iItemID))
    elseif d.sType == "aura_keyword" then
        return ("|cff88ff88[光环]|r %s  {%s}"):format(d.sLabel or "?", table.concat(d.aKeywords or {}, ","))
    elseif d.sType == "comp" then
        local p = table.concat(d.aClasses or {}, ",")
        if d.aSpecIDs and #d.aSpecIDs > 0 then p = p .. " 专精:" .. table.concat(d.aSpecIDs, "/") end
        return ("|cffffcc66[团队]|r %s  (%s)"):format(d.sLabel or "?", p)
    end
    return d.sLabel or "?"
end

-- 作用域状态
local scope = { kind = "global", zone = nil, enc = nil }
local addType = "item"

-- 取当前作用域的检查列表（create=true 时按需建表）
local function getList(create)
    local db = RPF.db
    if scope.kind == "global" then return db.tGlobal end
    if not scope.zone then return {} end
    local z = db.tZones[scope.zone]
    if not z then
        if not create then return {} end
        z = {}; db.tZones[scope.zone] = z
    end
    if scope.kind == "zone" then
        if not z.tChecks then if not create then return {} end z.tChecks = {} end
        return z.tChecks
    else
        z.tBosses = z.tBosses or {}
        local b = z.tBosses[scope.enc]
        if not b then
            if not create then return {} end
            b = {}; z.tBosses[scope.enc] = b
        end
        if not b.tChecks then b.tChecks = {} end
        return b.tChecks
    end
end

local frame, rows
local function rebuildList() end  -- 前向声明

local function ensureFrame()
    if frame then return frame end
    frame = CreateFrame("Frame", "RaidPreflightEditor", UIParent)
    frame:SetSize(560, 480)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true); frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -14)
    frame.title:SetText("编辑检查清单")

    -- 作用域：副本下拉
    local zlbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zlbl:SetPoint("TOPLEFT", 18, -40); zlbl:SetText("作用域")

    local zoneDD = CreateFrame("Frame", "RaidPreflightEditorZoneDD", frame, "UIDropDownMenuTemplate")
    zoneDD:SetPoint("TOPLEFT", 0, -52)
    local bossDD = CreateFrame("Frame", "RaidPreflightEditorBossDD", frame, "UIDropDownMenuTemplate")
    bossDD:SetPoint("LEFT", zoneDD, "RIGHT", 6, 0)

    local function refreshBossDD()
        UIDropDownMenu_Initialize(bossDD, function()
            local info = UIDropDownMenu_CreateInfo()
            info.text = "整个副本"; info.func = function()
                scope.kind = "zone"; scope.enc = nil
                UIDropDownMenu_SetText(bossDD, "整个副本"); rebuildList()
            end
            UIDropDownMenu_AddButton(info)
            if scope.zone then
                for _, b in ipairs(RPF:GetZoneBosses(scope.zone)) do
                    local bb = b
                    local i2 = UIDropDownMenu_CreateInfo()
                    i2.text = bb.sName; i2.func = function()
                        scope.kind = "boss"; scope.enc = bb.iEncID
                        UIDropDownMenu_SetText(bossDD, bb.sName); rebuildList()
                    end
                    UIDropDownMenu_AddButton(i2)
                end
            end
        end)
        UIDropDownMenu_SetWidth(bossDD, 160)
        UIDropDownMenu_SetText(bossDD, scope.kind == "boss" and "（已选 boss）" or "整个副本")
    end

    UIDropDownMenu_Initialize(zoneDD, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "通用（所有副本）"; info.func = function()
            scope.kind = "global"; scope.zone = nil; scope.enc = nil
            UIDropDownMenu_SetText(zoneDD, "通用（所有副本）")
            UIDropDownMenu_SetText(bossDD, "整个副本")
            rebuildList()
        end
        UIDropDownMenu_AddButton(info)
        for _, z in ipairs(RPF:GetZoneNames()) do
            local zz = z
            local i2 = UIDropDownMenu_CreateInfo()
            i2.text = zz; i2.func = function()
                scope.kind = "zone"; scope.zone = zz; scope.enc = nil
                UIDropDownMenu_SetText(zoneDD, zz)
                refreshBossDD()
                rebuildList()
            end
            UIDropDownMenu_AddButton(i2)
        end
    end)
    UIDropDownMenu_SetWidth(zoneDD, 200)
    UIDropDownMenu_SetText(zoneDD, "通用（所有副本）")
    refreshBossDD()
    frame.refreshBossDD = refreshBossDD

    -- 列表滚动区
    local sf = CreateFrame("ScrollFrame", "RaidPreflightEditorScroll", frame, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 18, -90)
    sf:SetPoint("BOTTOMRIGHT", -34, 150)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(490, 10)
    sf:SetScrollChild(content)
    frame.content = content
    rows = {}

    -- 添加表单
    local fy = -340
    local tlbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tlbl:SetPoint("TOPLEFT", 18, fy + 18); tlbl:SetText("新增检查：")

    local typeDD = CreateFrame("Frame", "RaidPreflightEditorTypeDD", frame, "UIDropDownMenuTemplate")
    typeDD:SetPoint("TOPLEFT", 0, fy)
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 200, fy - 8)
    hint:SetWidth(330); hint:SetJustifyH("LEFT")
    local function setType(t)
        addType = t
        UIDropDownMenu_SetText(typeDD, TYPE_LABELS[t])
        hint:SetText(TYPE_HINT[t])
    end
    UIDropDownMenu_Initialize(typeDD, function()
        for _, t in ipairs(TYPE_ORDER) do
            local tt = t
            local info = UIDropDownMenu_CreateInfo()
            info.text = TYPE_LABELS[tt]; info.func = function() setType(tt) end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(typeDD, 180)
    setType("item")

    local function makeInput(label, x, y, w)
        local l = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", x, y); l:SetText(label)
        local eb = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        eb:SetPoint("TOPLEFT", x + 4, y - 14)
        eb:SetSize(w, 20); eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        return eb
    end
    local labelBox = makeInput("标签", 22, fy - 40, 200)
    local paramBox = makeInput("参数", 250, fy - 40, 270)

    local errLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    errLbl:SetPoint("TOPLEFT", 22, fy - 78); errLbl:SetWidth(400); errLbl:SetJustifyH("LEFT")

    local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addBtn:SetSize(80, 22); addBtn:SetPoint("TOPRIGHT", -18, fy - 62)
    addBtn:SetText("添加")
    addBtn:SetScript("OnClick", function()
        local d, err = RPF:BuildCheckDescriptor(addType, labelBox:GetText(), paramBox:GetText())
        if not d then errLbl:SetText(err or "出错"); return end
        local list = getList(true)
        list[#list + 1] = d
        labelBox:SetText(""); paramBox:SetText(""); errLbl:SetText("")
        rebuildList()
    end)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22); closeBtn:SetPoint("BOTTOMRIGHT", -18, 14)
    closeBtn:SetText("关闭")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    frame:Hide()
    return frame
end

-- 真正的列表重建
rebuildList = function()
    if not frame then return end
    local content = frame.content
    rows = rows or {}
    local list = getList(false)
    for i = 1, #list do
        local r = rows[i]
        if not r then
            r = CreateFrame("Frame", nil, content)
            r:SetSize(480, 22)
            r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.text:SetPoint("LEFT", 2, 0); r.text:SetWidth(400); r.text:SetJustifyH("LEFT")
            r.del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            r.del:SetSize(44, 20); r.del:SetPoint("RIGHT", 0, 0); r.del:SetText("删除")
            rows[i] = r
        end
        r.text:SetText(descText(list[i]))
        r.del:SetScript("OnClick", function()
            table.remove(getList(true), i)
            rebuildList()
        end)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
        r:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    content:SetHeight(math.max(10, #list * 24))
end

function RPF:ShowEditor()
    ensureFrame()
    if frame.refreshBossDD then frame.refreshBossDD() end
    rebuildList()
    frame:Show()
end
