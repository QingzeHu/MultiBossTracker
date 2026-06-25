-- 设置面板（暴雪原生 Interface Options，无 Ace）
local addonName, RPF = ...

local panel
local controls = {}   -- 注册需要随 db 刷新的控件

local function makeCheck(parent, name, label, x, y, getf, setf)
    local cb = CreateFrame("CheckButton", "RaidPreflightCheck" .. name, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb:SetScript("OnClick", function(self) setf(self:GetChecked() and true or false) end)
    controls[#controls + 1] = function() cb:SetChecked(getf()) end
    return cb
end

local function buildPanel()
    panel = CreateFrame("Frame", "RaidPreflightOptionsPanel")
    panel.name = "RaidPreflight"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("RaidPreflight — 进本检查清单")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText("进本前 / 开战前自动核对消耗品、增益、团队职业与专精。")

    local db = function() return RPF.db end

    makeCheck(panel, "Enabled", "启用插件总开关", 16, -64,
        function() return db().bEnabled end,
        function(v) db().bEnabled = v end)
    makeCheck(panel, "Summon", "术士拉人时检查（拦截召唤弹窗）", 32, -94,
        function() return db().bOnSummon end,
        function(v) db().bOnSummon = v end)
    makeCheck(panel, "Enter", "自己进本时检查（每副本周期一次）", 32, -120,
        function() return db().bOnEnter end,
        function(v) db().bOnEnter = v end)
    makeCheck(panel, "Pull", "开战前检查（团队 ready check 时）", 32, -146,
        function() return db().bOnPull end,
        function(v) db().bOnPull = v end)

    -- 进本冷却滑条（小时）
    local slider = CreateFrame("Slider", "RaidPreflightCooldownSlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 32, -200)
    slider:SetWidth(260)
    slider:SetMinMaxValues(1, 24)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    _G[slider:GetName() .. "Low"]:SetText("1h")
    _G[slider:GetName() .. "High"]:SetText("24h")
    local slabel = _G[slider:GetName() .. "Text"]
    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val + 0.5)
        RPF.db.iEnterCooldown = val * 3600
        slabel:SetText("进本弹窗冷却：" .. val .. " 小时")
    end)
    controls[#controls + 1] = function()
        slider:SetValue(math.floor((RPF.db.iEnterCooldown or 21600) / 3600 + 0.5))
    end

    -- 按钮区
    local function makeButton(text, x, y, onclick)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(150, 24)
        b:SetPoint("TOPLEFT", x, y)
        b:SetText(text)
        b:SetScript("OnClick", onclick)
        return b
    end

    makeButton("编辑检查清单", 32, -250, function() RPF:ShowEditor() end)
    makeButton("导出 / 分享", 196, -250, function() RPF:ShowExportFrame() end)
    makeButton("导入", 360, -250, function() RPF:ShowImportFrame() end)
    makeButton("重置进本弹窗记录", 32, -284, function()
        wipe(RPF.db.tShownEnter)
        print("|cff66ccffRaidPreflight|r：进本弹窗记录已清空。")
    end)

    local function refresh()
        for _, fn in ipairs(controls) do fn() end
    end
    panel:SetScript("OnShow", refresh)
    panel.refresh = refresh   -- 旧式接口名，OptionsFrame 会调

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    RPF._panel = panel
end

RPF:On("RPF_Ready", buildPanel)

-- 配置被导入后刷新面板
RPF:On("RPF_ConfigChanged", function()
    if panel and panel:IsShown() then
        for _, fn in ipairs(controls) do fn() end
    end
end)

-- 打开设置面板
function RPF:OpenPanel()
    if panel and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)  -- 暴雪 bug：调两次才定位对
    end
end
