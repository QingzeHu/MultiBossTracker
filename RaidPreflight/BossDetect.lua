-- Boss 推断：开战前判断「下一个要打谁」，喂给模板做 boss 级匹配。
-- 思路照搬 MultiBossTracker：地点能定就用地点，定不了就硬编码顺序，
-- 玩家鼠标悬浮/选中某 boss 视为「就打它」，优先级最高。
local addonName, RPF = ...

local iCurMapID = nil
local iPendingEncID = nil   -- 悬浮/目标表态出来的 boss
local iOrderPtr = 1         -- 硬编码顺序指针（1-based，指向 tOrder）

local function npcIDFromUnit(unit)
    if not UnitExists(unit) or UnitIsDead(unit) then return nil end
    if UnitIsPlayer(unit) or UnitIsFriend("player", unit) then return nil end
    local guid = UnitGUID(unit) or ""
    return select(6, strsplit("-", guid))
end

local function noteUnit(unit)
    local npcID = npcIDFromUnit(unit)
    if not npcID then return end
    local hit = RPF:LookupBossByNPCID(npcID)
    if hit and hit.iMapID == iCurMapID then
        iPendingEncID = hit.iEncID
    end
end

-- ENCOUNTER_END 成功 → 顺序指针推进到该 boss 之后。
local function advanceOrder(iEncID)
    local zone = iCurMapID and RPF.Zones[iCurMapID]
    if not zone or not zone.tOrder then return end
    for idx, enc in ipairs(zone.tOrder) do
        if enc == iEncID then
            iOrderPtr = math.min(idx + 1, #zone.tOrder + 1)
            return
        end
    end
end

local function refreshZone()
    local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    if instanceMapID ~= iCurMapID then
        iCurMapID = instanceMapID
        iPendingEncID = nil
        iOrderPtr = 1
    end
end

-- 对外：返回 {iMapID, iEncID, sName} 或 nil。
function RPF:GetUpcomingBoss()
    refreshZone()
    local zone = iCurMapID and RPF.Zones[iCurMapID]
    if not zone then return nil end

    -- 1) 玩家表态（悬浮/目标）
    if iPendingEncID and zone.tEnc[iPendingEncID] then
        return { iMapID = iCurMapID, iEncID = iPendingEncID, sName = zone.tEnc[iPendingEncID].sName }
    end
    -- 2) 子地点唯一对应
    local sub = GetSubZoneText()
    if sub and zone.tBySubZone and zone.tBySubZone[sub] then
        local enc = zone.tBySubZone[sub]
        return { iMapID = iCurMapID, iEncID = enc, sName = zone.tEnc[enc] and zone.tEnc[enc].sName }
    end
    -- 3) 硬编码顺序指针
    if zone.tOrder and zone.tOrder[iOrderPtr] then
        local enc = zone.tOrder[iOrderPtr]
        return { iMapID = iCurMapID, iEncID = enc, sName = zone.tEnc[enc] and zone.tEnc[enc].sName }
    end
    return nil
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
        noteUnit("mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then
        noteUnit("target")
    elseif event == "ENCOUNTER_END" then
        local iEncID, _, _, _, success = ...
        if success == 1 then advanceOrder(iEncID) end
    else
        refreshZone()
    end
end)
