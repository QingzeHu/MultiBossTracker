-- Boss 推断：开战前判断「下一个要打谁」，喂给模板做 boss 级匹配。
-- 数据复用 MultiBossTracker：优先读它已本地化的 localizedZones，没装则用自带回退表。
-- 推断逻辑照搬 MBT：地点(子区域优先>主区域) → 当前 encounter(iStartingFight + ENCOUNTER_END
-- 顺 iNextEncounter 推进) → 鼠标悬浮/选中某 boss 的 NPCID 直接覆盖（玩家表态，优先级最高）。

local addonName, RPF = ...

local LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J" }

local sCurZoneKey = nil   -- 当前命中的中文区域 key
local iCurEnc     = nil   -- 当前 encounterID（nil = 用 iStartingFight 兜底）

-- 数据源：装了 MBT 就用它本地化好的表，否则回退自带种子。
local function getZones()
    local mbt = _G.MultiBossTracker
    if mbt and mbt.localizedZones and next(mbt.localizedZones) then
        return mbt.localizedZones
    end
    return RPF.ZonesFallback
end

-- 区域 key 解析：子区域优先，退回主区域（与 MBT GetZoneData 一致）。
local function resolveZoneKey(zones)
    local sub = GetSubZoneText()
    if sub and sub ~= "" and zones[sub] then return sub end
    local zone = GetZoneText()
    if zone and zones[zone] then return zone end
    return nil
end

local function npcIDFromUnit(unit)
    if not UnitExists(unit) or UnitIsDead(unit) then return nil end
    if UnitIsPlayer(unit) or UnitIsFriend("player", unit) then return nil end
    local guid = UnitGUID(unit) or ""
    return select(6, strsplit("-", guid))
end

-- 从一个 encounter（或 flat 区域）的 A..J 槽位收集 boss 名。
local function bossNameFromSlots(t)
    local names = {}
    for _, L in ipairs(LETTERS) do
        local slot = t[L]
        if type(slot) == "table" and slot.sTarName then
            names[#names + 1] = slot.sTarName
        end
    end
    if #names == 0 then return nil end
    return table.concat(names, " / ")
end

-- 选当前 encounterID：已锁定 > iStartingFight > 最小编号兜底。
local function currentEncID(enc)
    if iCurEnc and enc[iCurEnc] then return iCurEnc end
    if enc.iStartingFight and enc[enc.iStartingFight] then return enc.iStartingFight end
    local best
    for k, v in pairs(enc) do
        if type(k) == "number" and type(v) == "table" then
            if not best or k < best then best = k end
        end
    end
    return best
end

local function refreshZone()
    local zones = getZones()
    local zk = resolveZoneKey(zones)
    if zk ~= sCurZoneKey then
        sCurZoneKey = zk
        iCurEnc = nil
    end
end

-- 鼠标悬浮/选中某 boss → 锁到它所在 encounter。
local function detectUnit(unit)
    if InCombatLockdown() then return end
    local npcID = npcIDFromUnit(unit)
    if not npcID then return end
    refreshZone()
    local zd = sCurZoneKey and getZones()[sCurZoneKey]
    local enc = zd and zd.Encounters
    if not enc then return end
    for iEncID, tEnc in pairs(enc) do
        if type(tEnc) == "table" then
            for _, slot in pairs(tEnc) do
                if type(slot) == "table" and slot.sNPCID == npcID then
                    iCurEnc = iEncID
                    return
                end
            end
        end
    end
end

-- ENCOUNTER_END 成功 → 顺 iNextEncounter 推进。
local function advanceOrder(iEncID)
    local zd = sCurZoneKey and getZones()[sCurZoneKey]
    local enc = zd and zd.Encounters
    if enc and enc[iEncID] and enc[iEncID].iNextEncounter then
        iCurEnc = enc[iEncID].iNextEncounter
    end
end

-- 对外：返回 {sZone, iEncID, sName} 或 nil。
function RPF:GetUpcomingBoss()
    refreshZone()
    local zk = sCurZoneKey
    if not zk then return nil end
    local zd = getZones()[zk]
    if not zd then return nil end

    local enc = zd.Encounters
    if enc then
        local iEncID = currentEncID(enc)
        local slots = iEncID and enc[iEncID]
        if not slots then return { sZone = zk } end
        return { sZone = zk, iEncID = iEncID, sName = bossNameFromSlots(slots) }
    end
    -- flat 区域（单 boss / 动态阵容）
    return { sZone = zk, sName = bossNameFromSlots(zd) }
end

-- 给配置编辑器用：列出可选副本名 / 某副本的 boss 列表。
function RPF:GetZoneNames()
    local zones, out = getZones(), {}
    for k in pairs(zones) do
        if k ~= "bLocalized" and type(k) == "string" then out[#out + 1] = k end
    end
    table.sort(out)
    return out
end

function RPF:GetZoneBosses(sZone)
    local zd = getZones()[sZone]
    local out = {}
    if zd and zd.Encounters then
        for k, v in pairs(zd.Encounters) do
            if type(k) == "number" and type(v) == "table" then
                out[#out + 1] = { iEncID = k, sName = bossNameFromSlots(v) or ("编码 " .. k) }
            end
        end
        table.sort(out, function(a, b) return a.iEncID < b.iEncID end)
    end
    return out
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("ENCOUNTER_END")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "UPDATE_MOUSEOVER_UNIT" then
        detectUnit("mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then
        detectUnit("target")
    elseif event == "ENCOUNTER_END" then
        local iEncID, _, _, _, success = ...
        if success == 1 then advanceOrder(iEncID) end
    else
        refreshZone()
    end
end)
