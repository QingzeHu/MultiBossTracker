-- Range / Facing Checker
-- HP 内嵌右上角的状态提示，单一 FontString 复用，按状态切换：
--   "超出范围" —— boss 不在你最远技能射程内（持续，黄色）
--   "面对目标" —— 你点击施法但游戏返回"必须面对目标"错误（闪 1.5s，橙色）
--
-- facing 闪烁期间优先级高于 range（更紧迫，避免被 range 状态覆盖）
-- 距离检测的 IsSpellInRange 是 live 的：天赋 / 雕文 / buff 加成自动算上
local addonName, MBT = ...

local RANGE_COLOR  = {1.00, 0.95, 0.30, 1}   -- 鲜黄
local FACING_COLOR = {1.00, 0.95, 0.30, 1}   -- 鲜黄（跟 range 同色，统一观感）
local RANGE_TEXT   = "超出范围"
local FACING_TEXT  = "面对目标"

-- ---------------------------------------------------------------------
-- 单一状态切换器：facing 优先于 range；nil = 清空
-- ---------------------------------------------------------------------
local function setBossStatus(btn, kind)
    if not btn or not btn.statusText then return end
    local t = btn.statusText
    if kind == "facing" then
        t:SetText(FACING_TEXT)
        t:SetTextColor(FACING_COLOR[1], FACING_COLOR[2], FACING_COLOR[3], FACING_COLOR[4])
    elseif kind == "range" then
        t:SetText(RANGE_TEXT)
        t:SetTextColor(RANGE_COLOR[1], RANGE_COLOR[2], RANGE_COLOR[3], RANGE_COLOR[4])
    else
        t:SetText("")
    end
end

-- ---------------------------------------------------------------------
-- 共用：根据 boss 名字查可用的 unit token
-- ---------------------------------------------------------------------
local UNIT_TOKENS = { "target", "focus", "mouseover" }
for i = 1, 5 do UNIT_TOKENS[#UNIT_TOKENS + 1] = "boss" .. i end
for i = 1, 30 do UNIT_TOKENS[#UNIT_TOKENS + 1] = "nameplate" .. i end

local function findUnitByName(name)
    if not name or name == "" then return nil end
    for _, unit in ipairs(UNIT_TOKENS) do
        if UnitExists(unit) and UnitName(unit) == name then return unit end
    end
    return nil
end

-- ---------------------------------------------------------------------
-- 距离不足扫描：每 0.2s 跑一遍所有可见 boss 框
-- 跳过当前正在 facing 闪烁的框（不抢占）
-- ---------------------------------------------------------------------
local rangeFrame = CreateFrame("Frame")
local rangeAccum = 0

local function evaluateRange(btn, spellName)
    if not btn:IsShown() or not btn.targetName then
        setBossStatus(btn, nil)
        return
    end
    local unit = findUnitByName(btn.targetName)
    if not unit or not UnitCanAttack("player", unit) then
        setBossStatus(btn, nil)
        return
    end
    local inRange = IsSpellInRange(spellName, unit)
    if inRange == 0 then
        setBossStatus(btn, "range")
    else
        setBossStatus(btn, nil)
    end
end

rangeFrame:SetScript("OnUpdate", function(_, elapsed)
    rangeAccum = rangeAccum + elapsed
    if rangeAccum < 0.2 then return end
    rangeAccum = 0

    local profile = MBT.db and MBT.db.profile
    if not profile or not profile.bShowRangeIndicator then
        for _, btn in pairs(MBT.BossFrames or {}) do
            if not btn._facingFlashActive then setBossStatus(btn, nil) end
        end
        return
    end

    local cd = MBT.formattedClassData
    local spellID = cd and cd.iRangeCheckSpellID
    if not spellID then return end
    local spellName = GetSpellInfo(spellID)
    if not spellName then return end

    for _, btn in pairs(MBT.BossFrames or {}) do
        -- facing 闪烁期间不让 range 覆盖（更紧迫的信号优先）
        if not btn._facingFlashActive then
            evaluateRange(btn, spellName)
        end
    end
end)

-- ---------------------------------------------------------------------
-- 朝向错误反应式提示
-- ---------------------------------------------------------------------
local function isFacingError(msg)
    if not msg or msg == "" then return false end
    if msg:find("面对") or msg:find("面向") or msg:find("正前方") then return true end
    local lower = msg:lower()
    if lower:find("facing") or lower:find("in front") then return true end
    return false
end

-- 暴露给 BossFrame.lua 在 OnClick hook 里调用，绕过 UI_ERROR_MESSAGE 节流
function MBT.RefreshFacingFlash(btn)
    if not btn or not btn.statusText then return end
    if not (MBT.db and MBT.db.profile and MBT.db.profile.bShowFacingWarning) then return end

    setBossStatus(btn, "facing")
    btn._facingFlashActive = true

    if btn._facingHideTimer then btn._facingHideTimer:Cancel() end
    btn._facingHideTimer = C_Timer.NewTimer(1.5, function()
        btn._facingFlashActive = false
        -- 闪烁结束后立刻重新评估 range（如果还在范围外，恢复"超出范围"）
        local cd = MBT.formattedClassData
        local sp = cd and cd.iRangeCheckSpellID and GetSpellInfo(cd.iRangeCheckSpellID)
        if sp and (MBT.db and MBT.db.profile.bShowRangeIndicator) then
            evaluateRange(btn, sp)
        else
            setBossStatus(btn, nil)
        end
    end)
end

local errFrame = CreateFrame("Frame")
errFrame:RegisterEvent("UI_ERROR_MESSAGE")
errFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
errFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "UI_ERROR_MESSAGE" then
        local errType, msg = arg1, arg2
        if type(errType) == "string" and not msg then msg = errType end
        if not isFacingError(msg) then return end

        local profile = MBT.db and MBT.db.profile
        if not profile or not profile.bShowFacingWarning then return end

        local fid = MBT._lastClickedFrameID
        local clickTime = MBT._lastClickedTime or 0
        if not fid or (GetTime() - clickTime) > 0.5 then return end

        local btn = MBT.BossFrames and MBT.BossFrames[fid]
        if not btn then return end

        -- 进入"facing 模式" 5 秒；点击 hook 在这窗口内会自动续期闪烁
        btn._facingModeExpiry = GetTime() + 5
        MBT.RefreshFacingFlash(btn)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- 玩家成功施法 → 朝向已经对了，清除最近点击的 boss 框的 facing 模式（避免事后误报）
        local unit = arg1
        if unit ~= "player" then return end
        local fid = MBT._lastClickedFrameID
        if not fid then return end
        if (GetTime() - (MBT._lastClickedTime or 0)) > 1 then return end
        local btn = MBT.BossFrames and MBT.BossFrames[fid]
        if btn then
            btn._facingModeExpiry = nil
        end
    end
end)
