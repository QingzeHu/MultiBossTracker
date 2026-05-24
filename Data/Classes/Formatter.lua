-- Class Data Formatter
-- Picks the right class table for the player, attaches config-based bindings/blacklist/order,
-- runs the (stubbed) talent/glyph pass, and re-broadcasts as MultiBossTracker_ClassData_Formatted.
local addonName, MBT = ...

local function CheckForGlyph(iGlyphID)
    -- WoW MoP Classic 5.5 reworked the glyph API. Returning false here means duration extension
    -- glyphs and refresh-glyph triggers are simply skipped — DoT tracking still works on base
    -- durations, just without the bonus seconds. Patch this when adding MoP glyph detection.
    return false
end

local function HandleRefreshTalents(tSpell)
    if tSpell.tRefreshAura then
        if tSpell.tRefreshAura.tRefreshTalent then
            -- WotLK GetTalentInfo(row, index) is gone in MoP. Defaulting to true so refresh-on-cast
            -- behaviour is permissive: assume the talent is taken if the user dotted with this spell.
            tSpell.tRefreshAura.bEnabled = true
        elseif tSpell.tRefreshAura.tRefreshGlyph then
            tSpell.tRefreshAura.bEnabled = CheckForGlyph(tSpell.tRefreshAura.tRefreshGlyph.iGlyphID)
        else
            tSpell.tRefreshAura.bEnabled = true
        end
    end
end

local function HandleIncreaseDurationGlyphs(tSpell)
    if tSpell.tIncreaseDurationAura then
        if tSpell.tIncreaseDurationAura.iGlyphID then
            tSpell.tIncreaseDurationAura.bEnabled = CheckForGlyph(tSpell.tIncreaseDurationAura.iGlyphID)
        end
    end
end

local function CheckForSet(tSetData)
    local iEquipped = 0
    for _, v in ipairs(tSetData.tItems) do
        if IsEquippedItem(v) then
            iEquipped = iEquipped + 1
        end
    end
    return (iEquipped >= tSetData.iItemCount)
end

local function CalculateDurationFromTalents(tAuraTable)
    local iFinalDuration = tAuraTable.iDuration
    -- WotLK talent point lookup omitted (API differs in MoP). Glyph + set bonus paths still work.
    if tAuraTable.tGlyphDuration ~= nil then
        if CheckForGlyph(tAuraTable.tGlyphDuration.iGlyphID) then
            iFinalDuration = iFinalDuration + tAuraTable.tGlyphDuration.iExtraDuration
        end
    end
    if tAuraTable.iSetBonusDuration ~= nil then
        if CheckForSet(tAuraTable.iSetBonusDuration) then
            iFinalDuration = iFinalDuration + tAuraTable.iSetBonusDuration.iIncDuration
        end
    end
    return iFinalDuration
end

local function HandleRefreshAndIncreasedDurationOnTable(tData)
    for _, v in pairs(tData) do
        HandleRefreshTalents(v)
        HandleIncreaseDurationGlyphs(v)
    end
end

local function CheckTalentsAndGlyphs(tAuraData)
    HandleRefreshAndIncreasedDurationOnTable(tAuraData.tDamageInfos)
    HandleRefreshAndIncreasedDurationOnTable(tAuraData.tCastInfos or {})
    for _, v in pairs(tAuraData.tSpellsInfos) do
        HandleRefreshTalents(v)
        v.iFinalDuration = CalculateDurationFromTalents(v)
    end
end

local function SetupSpellGroups(tAuraData)
    for _, v in pairs(tAuraData.tSpellsInfos) do
        v.sSlotName = v.sGroup or v.sName
    end
end

local function SetupBlacklist(tAuraData, blacklist)
    for _, v in pairs(tAuraData.tSpellsInfos) do
        v.bEnabled = true
    end
    if blacklist then
        for k, v in pairs(blacklist) do
            if v and tAuraData.tSpellsInfos[k] then
                tAuraData.tSpellsInfos[k].bEnabled = false
            end
        end
    end
end

-- 标记 tStackPips 引用的咒语为"pip 追踪"：即便用户在黑名单关掉它们的图标显示，
-- dispatcher 仍要把事件透传到 BossFrame，让 pip 指示器能读到 stackCount
local function MarkPipTrackedSpells(tAuraData)
    -- 先清掉上一轮的标记（用户刚解绑黑名单时配置不应残留）
    for _, v in pairs(tAuraData.tSpellsInfos) do v.bPipTracked = nil end
    local pips = tAuraData.tStackPips
    if not pips or not pips.tSpells then return end
    for _, name in ipairs(pips.tSpells) do
        local info = tAuraData.tSpellsInfos[name]
        if info then info.bPipTracked = true end
    end
end

local function SetupDoTOrder(tAuraData, order)
    -- 先清空所有 iOrder（避免上一次设置遗留）
    for _, info in pairs(tAuraData.tSpellsInfos) do info.iOrder = nil end
    if not order then return end

    -- 同一咒语被设到多个槽位时，取最低槽位号（最高优先级）。
    -- pairs() 的迭代顺序不确定，必须用 min 而不是简单赋值。
    local spellToMinPos = {}
    for k, v in pairs(order) do
        local spellName = tAuraData.tDotOrderIndices and tAuraData.tDotOrderIndices[v]
        local pos = tonumber(k)
        if spellName and spellName ~= "None" and pos then
            if not spellToMinPos[spellName] or pos < spellToMinPos[spellName] then
                spellToMinPos[spellName] = pos
            end
        end
    end
    for spellName, pos in pairs(spellToMinPos) do
        local info = tAuraData.tSpellsInfos[spellName]
        if info then info.iOrder = pos end
    end
end

local function SetupSpellData(tAuraData)
    tAuraData.tCastTriggers   = tAuraData.tCastTriggers   or {}
    tAuraData.tDamageTriggers = tAuraData.tDamageTriggers or {}
    tAuraData.tDamageInfos    = tAuraData.tDamageInfos    or {}
    tAuraData.tCastInfos      = tAuraData.tCastInfos      or {}
end

-- Pull the class table for the player (or DEFAULT) and stamp on per-config data.
local function FormatAndBroadcast()
    local _, classToken = UnitClass("player")
    local tAuraData = MBT.classData[classToken] or MBT.classData["DEFAULT"]
    if not tAuraData then return end

    -- Attach config-driven bits from the user's profile
    local p = MBT.db.profile
    local bindKey = MBT:GetBindingKey(classToken)
    tAuraData.tCastingModeBindings = p.tCastingModeBindings[bindKey] or p.tCastingModeBindings.tOther
    tAuraData.tBlacklist           = p.tBlacklist
    tAuraData.tForceDoTOrder       = p.tForceDoTOrder[bindKey]

    SetupSpellData(tAuraData)
    SetupSpellGroups(tAuraData)
    SetupBlacklist(tAuraData, tAuraData.tBlacklist)
    MarkPipTrackedSpells(tAuraData)
    SetupDoTOrder(tAuraData, tAuraData.tForceDoTOrder)
    tAuraData.fnCheckTalentsAndGlyphs = function() CheckTalentsAndGlyphs(tAuraData) end
    CheckTalentsAndGlyphs(tAuraData)

    MBT.formattedClassData = tAuraData
    MBT:FireEvent("MultiBossTracker_ClassData_Formatted", tAuraData)
end
MBT.FormatAndBroadcastClassData = FormatAndBroadcast

-- Drive the formatter on STATUS (initial pulse) — must run after every class file has loaded.
MBT:RegisterMDFEvent("STATUS", function() FormatAndBroadcast() end)
MBT:RegisterMDFEvent("MultiBossTracker_BlacklistChanged", function() FormatAndBroadcast() end)
MBT:RegisterMDFEvent("MultiBossTracker_BindingsChanged", function() FormatAndBroadcast() end)
