-- 弹窗 UI：一张可复用的检查清单面板。
-- 工业 HMI 风格：每行一个检查项，绿勾 / 红叉 + 明细；底部按情境给按钮。
local addonName, RPF = ...

local ROW_H   = 20
local PAD     = 14
local WIDTH   = 320
local frame   -- 懒创建的主框
local rows    = {}

local function makeRow(parent, i)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(WIDTH - PAD * 2, ROW_H)
    r.mark = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.mark:SetPoint("LEFT", 0, 0)
    r.mark:SetWidth(18)
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.label:SetPoint("LEFT", r.mark, "RIGHT", 4, 0)
    r.label:SetJustifyH("LEFT")
    r.detail = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.detail:SetPoint("RIGHT", 0, 0)
    r.detail:SetJustifyH("RIGHT")
    r.label:SetPoint("RIGHT", r.detail, "LEFT", -6, 0)
    return r
end

local function ensureFrame()
    if frame then return frame end
    frame = CreateFrame("Frame", "RaidPreflightPopup", UIParent)
    frame:SetSize(WIDTH, 200)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- 开战即自动消失：preflight 是「开战前」的事，一旦进战斗立刻收起，
    -- 免得用户忘了点、又被人意外开团，多一步确认手忙脚乱。绝不触碰开战逻辑。
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function(self) self:Hide() end)
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -16)

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -4)

    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.summary:SetPoint("BOTTOM", 0, 46)

    -- 主按钮（确认 / 重新检查）
    frame.btnMain = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.btnMain:SetSize(130, 24)
    frame.btnMain:SetPoint("BOTTOMLEFT", PAD, 14)
    -- 次按钮（取消 / 关闭）
    frame.btnAlt = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.btnAlt:SetSize(130, 24)
    frame.btnAlt:SetPoint("BOTTOMRIGHT", -PAD, 14)

    frame:Hide()
    return frame
end

local function layout(tResults)
    local n = #tResults
    for i = 1, n do
        local r = rows[i]
        if not r then r = makeRow(frame, i); rows[i] = r end
        local res = tResults[i]
        if res.bOK and res.bWarn then
            r.mark:SetText("|cffffcc00!|r")            -- 黄：通过但有保留（如专精待确认）
            r.label:SetTextColor(1, 0.85, 0.3)
        elseif res.bOK then
            r.mark:SetText("|cff33ff33✓|r")
            r.label:SetTextColor(0.9, 0.9, 0.9)
        else
            r.mark:SetText("|cffff4040✗|r")
            r.label:SetTextColor(1, 0.4, 0.4)
        end
        r.label:SetText(res.sLabel)
        r.detail:SetText(res.sDetail or "")
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -56 - (i - 1) * ROW_H)
        r:Show()
    end
    for i = n + 1, #rows do rows[i]:Hide() end
    frame:SetHeight(56 + n * ROW_H + 80)
end

-- 对外主入口。
-- opts = {
--   sTitle, sSubtitle, tResults, bAllOK,
--   sMode = "summon" | "normal",
--   fnConfirm, fnCancel,   -- summon 模式：接受/拒绝召唤
--   fnRecheck,             -- normal 模式：返回 tResults, bAllOK
-- }
function RPF:ShowChecklist(opts)
    ensureFrame()
    frame.title:SetText(opts.sTitle or "进本检查")
    frame.subtitle:SetText(opts.sSubtitle or "")

    local function paint(tResults, bAllOK)
        layout(tResults)
        local miss, warn = 0, 0
        for _, r in ipairs(tResults) do
            if not r.bOK then miss = miss + 1
            elseif r.bWarn then warn = warn + 1 end
        end
        if miss > 0 then
            frame.summary:SetText(("|cffff4040缺 %d 项|r"):format(miss))
        elseif warn > 0 then
            frame.summary:SetText(("|cffffcc00就绪（%d 项待确认）|r"):format(warn))
        else
            frame.summary:SetText("|cff33ff33全部就绪|r")
        end
    end
    paint(opts.tResults, opts.bAllOK)

    if opts.sMode == "summon" then
        frame.btnMain:SetText("接受召唤")
        frame.btnMain:SetScript("OnClick", function()
            if opts.fnConfirm then opts.fnConfirm() end
            frame:Hide()
        end)
        frame.btnAlt:SetText("取消")
        frame.btnAlt:SetScript("OnClick", function()
            if opts.fnCancel then opts.fnCancel() end
            frame:Hide()
        end)
    else
        frame.btnMain:SetText("重新检查")
        frame.btnMain:SetScript("OnClick", function()
            if opts.fnRecheck then
                local tR, bAll = opts.fnRecheck()
                opts.tResults, opts.bAllOK = tR, bAll
                paint(tR, bAll)
            end
        end)
        frame.btnAlt:SetText("关闭")
        frame.btnAlt:SetScript("OnClick", function() frame:Hide() end)
    end

    frame:Show()
end
