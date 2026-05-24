-- ChannelTracker: 玩家自身的引导技能跟踪（当前唯一使用方：痛苦术士的 Drain Soul）
-- 渲染目标：每个 boss 框底部的 channelRow（widget 在 BossFrame.lua 创建）
--
-- 数据流：
--   UNIT_SPELLCAST_CHANNEL_START(player, ..., spellID)
--     → 如果 spellID 匹配 tChannelBar.iSpellID
--     → 在玩家当前 target 对应的 boss 框上启动 channelRow
--   COMBAT_LOG_EVENT_UNFILTERED SPELL_PERIODIC_DAMAGE
--     → 如果 spell 是 Drain Soul + sourceGUID = player
--     → 在 destGUID 对应的 boss 框右端闪一下伤害数字
--   OnUpdate (20Hz)
--     → 推 bar 进度，重算 Haunt 续断标记位置
local addonName, MBT = ...

-- Haunt 续断标记计算：基于 Fojji 的 WA 公式
-- relativeTick = dsChannel - dsSinceCast - hauntRemaining + hauntCastTime
-- 即"如果现在断引导立刻施 Haunt，等 Haunt 落地时旧 Haunt 刚好快没"的那一时刻
local function getHauntCastTime(refSpellID)
    -- Fear 基础 1.5s 施法 —— 当前急速下的施法时间就是当前 GCD 长度
    local _, _, _, castMS = GetSpellInfo(refSpellID)
    if castMS and castMS > 0 then return castMS / 1000 end
    return 1.5
end

local function getHauntRemainingOnTarget(hauntSpellID)
    if not hauntSpellID then return nil end
    local hauntName = GetSpellInfo(hauntSpellID)
    if not hauntName or not UnitExists("target") then return nil end
    -- 按 index 迭代 target 上的 debuff（这是 DotDispatcher 已验证能用的模式，
    -- 比 UnitDebuff(unit, name, rank, "PLAYER") 的 filter form 在私服上更可靠）
    for i = 1, 40 do
        local name, _, _, _, _, expirationTime, caster = UnitDebuff("target", i)
        if not name then break end
        if name == hauntName and caster == "player" and expirationTime and expirationTime > 0 then
            return expirationTime - GetTime()
        end
    end
    return nil
end

local function getLatencySec()
    local _, _, _, worldMS = GetNetStats()
    return (worldMS or 0) / 1000
end

-- ---------------------------------------------------------------------
-- Snapshot DPS delta
-- store：cast 时锁定（SP / mod / dur 全锁）= 当前 channel 实际在做的 DPS
-- live：每帧重读（SP + mod 当前值；dur 用当前急速反推） = 假想现在 recast 会做的 DPS
-- delta = live - store →
--   > 0：proc / buff 涨了 / 急速上来了 → 显示 ▲ N（绿）→ recast 抢快照
--   < 0：cast 时的 proc / buff 没了 → 显示 ▼ N（红）→ 继续吸别断
--   = 0（或 |delta| ≤ 3 dead zone）→ 显示默认 label
-- 数据源：GetSpellBonusDamage(6) / UnitDamage[7] / GetSpellInfo(Fear).castTime
-- ---------------------------------------------------------------------
local function getDamageMod()
    local _, _, _, _, _, _, mod = UnitDamage("player")
    return mod or 1
end

local function calculateDPS(spellPower, cfg, channelDur)
    if not cfg.fSnapshotBase or not cfg.fSnapshotCoef or not cfg.fSnapshotMult then return nil end
    if not channelDur or channelDur <= 0 then return nil end
    local spellDamage = spellPower * cfg.fSnapshotCoef
    return (cfg.fSnapshotBase + spellDamage) * cfg.fSnapshotMult * getDamageMod() / channelDur
end

-- Live dur：每帧从急速参考咒语（Fear, 6215）的当前施法时间反推
-- DS 引导时长跟 Fear 共享急速曲线（DS = Fear × 10），所以 Fear 当前施法时间 × 10 = 当前急速下的引导时长
-- 即"如果现在 recast，引导会持续多久" —— 这才是 recast 决策的正确分母
local function getLiveDur(cfg, fallback)
    if not cfg.iHasteRefSpell or not GetSpellInfo then return fallback end
    local _, _, _, castMS = GetSpellInfo(cfg.iHasteRefSpell)
    if not castMS or castMS <= 0 then return fallback end
    return (castMS / 1000) * 10
end

local function snapshotChannelDPS(cr, cfg)
    if not GetSpellBonusDamage then cr.snapshotDPS = nil; return end
    local sp = GetSpellBonusDamage(cfg.iShadowSchool or 6)
    -- store 锁 cast 时的 dur（cr.duration 来自 UnitChannelInfo 实际引导时长）
    cr.snapshotDPS = calculateDPS(sp, cfg, cr.duration)
end

local function updateDeltaLabel(cr, cfg)
    if not cr.snapshotDPS or not GetSpellBonusDamage then return end
    local sp = GetSpellBonusDamage(cfg.iShadowSchool or 6)
    -- live 用当前急速重算 dur（覆盖急速 proc / 灌注 / 嗜血 / Eradication 等）
    local liveDur = getLiveDur(cfg, cr.duration)
    local liveDPS = calculateDPS(sp, cfg, liveDur)
    if not liveDPS then return end
    -- 用 round 而不是 floor，避免负方向偏移；再加 ±3 dead zone 消除"重复 cast 无变化时
    -- 由测量时机/浮点累计产生的 ±1～±2 虚假抖动"
    local raw = liveDPS - cr.snapshotDPS
    local delta = (raw >= 0) and math.floor(raw + 0.5) or -math.floor(-raw + 0.5)
    if math.abs(delta) <= 3 then delta = 0 end

    if delta == 0 then
        cr.label:SetText(cfg.sLabel or GetSpellInfo(cfg.iSpellID) or "")
        cr.label:SetTextColor(1, 1, 1, 1)
    elseif delta > 0 then
        -- 绿 ▲ N：proc/buff 涨了 → 该 recast 抢快照
        cr.label:SetText("▲ " .. delta)
        cr.label:SetTextColor(0.20, 1.00, 0.20, 1)
    else
        -- 红 ▼ N：cast 时的 proc/buff 没了 → 继续吸别断（用绝对值，箭头已表达方向）
        cr.label:SetText("▼ " .. (-delta))
        cr.label:SetTextColor(1.00, 0.25, 0.25, 1)
    end
end

-- 算出 Haunt 续断点的"在条上的相对时间位置"（0 < v < dsChannel）。无 Haunt 或位置无效返回 nil
local function computeHauntBreakValue(cfg, dsChannel, dsStartTime)
    local hauntRem = getHauntRemainingOnTarget(cfg.iHauntSpellID)
    if not hauntRem then return nil end
    local dsSinceCast = GetTime() - dsStartTime
    local castTime = getHauntCastTime(cfg.iHasteRefSpell)
    local travelTime = 0.058 * (cfg.fRangeEstimate or 30)
    local latency = getLatencySec()
    local hauntTime = castTime + travelTime + latency
    local relativeTick = dsChannel - dsSinceCast - hauntRem + hauntTime
    if relativeTick <= 0 or relativeTick > dsChannel then return nil end
    return relativeTick
end

-- 找到当前 target 对应的 boss 框（通过 npcID 匹配）
local function findBossFrameForGUID(guid)
    if not guid then return nil end
    local npcID = select(6, strsplit("-", guid))
    if not npcID then return nil end
    for _, btn in pairs(MBT.BossFrames or {}) do
        if btn.npcID == npcID and btn:IsShown() then return btn end
    end
    return nil
end

-- ---------------------------------------------------------------------
-- 启动 / 停止引导
-- ---------------------------------------------------------------------
local function startChannel(btn, cfg)
    local cr = btn.channelRow
    if not cr then return end
    local _, _, _, startMS, endMS = UnitChannelInfo("player")
    if not startMS or not endMS then return end
    cr.startTime = startMS / 1000
    cr.endTime   = endMS / 1000
    cr.duration  = cr.endTime - cr.startTime
    cr.cfg       = cfg
    cr.bar:SetMinMaxValues(0, cr.duration)
    cr.bar:SetValue(cr.duration)
    cr.dmgText:SetText("")
    cr.dmgFadeAt = nil
    cr.hauntTick:Hide()
    cr:Show()
    snapshotChannelDPS(cr, cfg)
end

local function refreshChannel(btn)
    -- UPDATE 事件（haste proc 中途改变引导剩余时间）
    local cr = btn and btn.channelRow
    if not cr or not cr:IsShown() then return end
    local _, _, _, startMS, endMS = UnitChannelInfo("player")
    if not startMS or not endMS then return end
    cr.startTime = startMS / 1000
    cr.endTime   = endMS / 1000
    cr.duration  = cr.endTime - cr.startTime
    cr.bar:SetMinMaxValues(0, cr.duration)
end

local function stopChannel(btn)
    local cr = btn and btn.channelRow
    if not cr then return end
    cr.startTime = nil
    cr.endTime   = nil
    cr.cfg       = nil
    cr.dmgText:SetText("")
    cr.hauntTick:Hide()
    cr:Hide()
end

local function stopAllChannels()
    for _, btn in pairs(MBT.BossFrames or {}) do stopChannel(btn) end
end

-- ---------------------------------------------------------------------
-- 事件
-- ---------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")   -- 出战后兜底清理（漏 STOP 时）

f:SetScript("OnEvent", function(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, sub, _, srcGUID, _, _, _, dstGUID, _, _, _, spellID, _, _, amount = CombatLogGetCurrentEventInfo()
        if sub ~= "SPELL_PERIODIC_DAMAGE" then return end
        local cfg = MBT.GetChannelConfig and MBT.GetChannelConfig()
        if not cfg or spellID ~= cfg.iSpellID then return end
        if srcGUID ~= UnitGUID("player") then return end
        local btn = findBossFrameForGUID(dstGUID)
        if not btn or not btn.channelRow or not btn.channelRow:IsShown() then return end
        if not amount then return end
        btn.channelRow.dmgText:SetText(tostring(amount))
        btn.channelRow.dmgFadeAt = GetTime() + (cfg.fDamageHoldSec or 0.6)
        return
    end

    local unit = ...
    if unit ~= "player" then return end

    if event == "PLAYER_REGEN_ENABLED" then
        stopAllChannels()
        return
    end

    local cfg = MBT.GetChannelConfig and MBT.GetChannelConfig()
    if not cfg then return end

    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        -- 按 spell name 比对（避免 UnitChannelInfo 在不同客户端版本里 spellID 的返回位置不一致）
        local name = UnitChannelInfo("player")
        local cfgName = GetSpellInfo(cfg.iSpellID)
        if not name or name ~= cfgName then return end
        local btn = findBossFrameForGUID(UnitGUID("target"))
        if btn then startChannel(btn, cfg) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        for _, btn in pairs(MBT.BossFrames or {}) do refreshChannel(btn) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        stopAllChannels()
    end
end)

-- ---------------------------------------------------------------------
-- OnUpdate 推进度 + 重算 Haunt 续断 + 淡出伤害数字（20Hz）
-- ---------------------------------------------------------------------
local accum = 0
f:SetScript("OnUpdate", function(_, elapsed)
    accum = accum + elapsed
    if accum < 0.05 then return end
    accum = 0
    local now = GetTime()
    for _, btn in pairs(MBT.BossFrames or {}) do
        local cr = btn.channelRow
        if cr then
            -- 伤害数字淡出 —— 放在 IsShown 检查外面，确保即便引导刚结束的边界也能正确清空
            if cr.dmgFadeAt and now >= cr.dmgFadeAt then
                cr.dmgText:SetText("")
                cr.dmgFadeAt = nil
            end
            if cr:IsShown() and cr.endTime then
                local remaining = cr.endTime - now
                if remaining <= 0 then
                    stopChannel(btn)
                else
                    cr.bar:SetValue(remaining)
                    if cr.cfg then
                        -- Label：snapshot DPS delta → 文字显示 ▲ N / ▼ N / 默认 spell 名
                        updateDeltaLabel(cr, cr.cfg)
                        -- Haunt 续断标记：算出该断的位置，画红线
                        local v = computeHauntBreakValue(cr.cfg, cr.duration, cr.startTime)
                        if v then
                            local barW = cr.bar:GetWidth()
                            if barW > 0 then
                                local offsetX = math.floor((v / cr.duration) * barW)
                                cr.hauntTick:ClearAllPoints()
                                cr.hauntTick:SetPoint("LEFT", cr.bar, "LEFT", offsetX, 0)
                                cr.hauntTick:Show()
                            end
                        else
                            cr.hauntTick:Hide()
                        end
                    end
                end
            end
        end
    end
end)
