-- Zone Dispatcher
-- Watches map / encounter / mouseover events and broadcasts MultiBossTracker_ChangeZone with
-- the (localized) zone data subtable for the current encounter slot, or nil to hide all frames.
local addonName, MBT = ...

local sEventName = "MultiBossTracker_ChangeZone"
local sLastZone, iLastEncounter, iCurrentEncounter = nil, 0, 0
local tLocalizedZones = {}    -- merged across all tier sections, with localized keys
local bLastResult = false

-- 动态阵容（阵营冠军）：本服每周随机刷一部分冠军，靠敌方名牌检测"实际在场的"单位，
-- 按发现顺序分配到框体槽位，而不是用数据里写死的 A-E。受 SecureActionButton 限制，
-- 名单只能在出战前（站进房间出名牌时）建立，开打瞬间冻结。
local tPresentNPCIDs = {}     -- npcID(string) -> 发现顺序序号
local iPresentOrder = 0
local bRosterDirty = false    -- present-set 增长后置位，强制下一次广播即便 encounter 没变
local tDynLetters = MBT.FRAME_IDS

local function RebuildLocalizedZones()
    tLocalizedZones = {}
    for _, section in pairs(MBT.zonesSections) do
        local localized = MBT.LocalizeTable(section.tZones)
        for k, v in pairs(localized) do
            if k ~= "bLocalized" then
                tLocalizedZones[k] = v
            end
        end
    end
    MBT.localizedZones = tLocalizedZones
end

-- ENCOUNTER_END — advance to the next pull's frames if the boss died.
local function HandleEncounterEnd(iEncID, encounterName, difficulty, groupSize, success)
    local tZoneData = tLocalizedZones[sLastZone]
    if not tZoneData then return false end
    if success == 1 then
        local enc = tZoneData["Encounters"]
        if enc and enc[iEncID] and enc[iEncID].iNextEncounter then
            iCurrentEncounter = enc[iEncID].iNextEncounter
        end
    else
        iCurrentEncounter = iEncID
    end
    return true
end

local function notePresent(npcID)
    if not tPresentNPCIDs[npcID] then
        iPresentOrder = iPresentOrder + 1
        tPresentNPCIDs[npcID] = iPresentOrder
        bRosterDirty = true
    end
end

-- 鼠标悬浮 / 名牌出现时，根据这只单位的 NPCID：
--   - flat 动态阵容子区域（ZG"疯狂之缘"4 选 1）→ 记进 present-set，只显示实际刷的那只；
--   - Encounters 里的动态阵容（TOC 阵营冠军）→ 切到该编码 + 记进 present-set；
--   - Encounters 里的普通编码（ZG 没按子区域搬上来的房间）→ 切到该编码。
-- 仅出战前生效（Tick 在战斗中提前 return）。
local function DetectUnit(unit)
    if not UnitExists(unit) or UnitIsDead(unit) then return end
    local guid = UnitGUID(unit) or ""
    local npcID = select(6, strsplit("-", guid))
    if not npcID then return end
    local tZoneData = tLocalizedZones[sLastZone]
    if not tZoneData then return end

    if tZoneData.bDynamicRoster then
        for _, tFrameData in pairs(tZoneData) do
            if type(tFrameData) == "table" and tFrameData.sNPCID == npcID then
                notePresent(npcID)
                return
            end
        end
        return
    end

    local enc = tZoneData["Encounters"]
    if not enc then return end
    for iEncID, tEncData in pairs(enc) do
        if type(tEncData) == "table" then
            local bDyn = tEncData.bDynamicRoster
            for _, tFrameData in pairs(tEncData) do
                if type(tFrameData) == "table" and tFrameData.sNPCID == npcID then
                    iCurrentEncounter = iEncID
                    if bDyn then notePresent(npcID) end
                    return
                end
            end
        end
    end
end

-- 把一个"动态阵容"编码表压成"只含在场单位、按发现顺序排好"的密集 A.. 表。
local function BuildDynamicRoster(tEncData)
    local present = {}
    for _, tFrameData in pairs(tEncData) do
        if type(tFrameData) == "table" and tFrameData.sNPCID and tPresentNPCIDs[tFrameData.sNPCID] then
            present[#present + 1] = tFrameData
        end
    end
    table.sort(present, function(a, b)
        return tPresentNPCIDs[a.sNPCID] < tPresentNPCIDs[b.sNPCID]
    end)
    local out = {}
    for i, tFrameData in ipairs(present) do
        if i > #tDynLetters then break end
        out[tDynLetters[i]] = tFrameData
    end
    return out
end

-- Resolve the current zone + which encounter slot to broadcast.
local function GetZoneData()
    local sub = GetSubZoneText()
    local zone = GetZoneText()
    -- 子区域优先（Naxx/TOC 用子区域区分 boss 房间，如"寒冰深渊"）；子区域在数据集里没命中
    -- 再退回主区域名 —— 祖尔格拉布客户端会返回"希里克祭坛"等子区域，但 boss 数据是按主
    -- zone "Zul'Gurub" 建的，必须退回主 zone 才能匹配（也让 sLastZone 对 mouseover/名牌检测可用）。
    local newZone, tZoneData
    if sub and sub ~= "" and tLocalizedZones[sub] then
        newZone, tZoneData = sub, tLocalizedZones[sub]
    elseif zone and tLocalizedZones[zone] then
        newZone, tZoneData = zone, tLocalizedZones[zone]
    else
        newZone = (sub and sub ~= "" and sub) or zone or ""
    end

    if tZoneData and tZoneData["Encounters"] then
        local enc = tZoneData["Encounters"]
        tZoneData = enc[iCurrentEncounter] or enc[enc.iStartingFight]
    end
    if tZoneData and tZoneData.bDynamicRoster then
        tZoneData = BuildDynamicRoster(tZoneData)
    end
    return newZone, tZoneData
end

-- 把用户在 "隐藏单位" 标签里勾上的 NPCID 从广播数据里剔除
local function filterHiddenNPCs(tZoneData)
    if not tZoneData then return tZoneData end
    local hidden = MBT.db and MBT.db.profile.hiddenNPCs
    if not hidden or not next(hidden) then return tZoneData end
    local out = {}
    for k, v in pairs(tZoneData) do
        if type(v) == "table" and v.sNPCID and hidden[v.sNPCID] then
            -- 跳过这个 slot
        else
            out[k] = v
        end
    end
    return out
end

local function BroadcastZoneData(event, newZone, tZoneData)
    if sLastZone ~= newZone or iLastEncounter ~= iCurrentEncounter
       or event == "MultiBossTracker_ZoneData_LateInit" or bRosterDirty then
        bRosterDirty = false
        if tZoneData then
            MBT:FireEvent(sEventName, newZone, filterHiddenNPCs(tZoneData))
        else
            MBT:FireEvent(sEventName, newZone, nil)
        end
    end
end

local function Tick(event, ...)
    if MBT.db.profile.tDebug.bDebug then
        print("|cFF66CCFFMDF|r Zone:", event, ...)
    end

    -- Zone tables get registered before the dispatcher does, so rebuild on first Tick.
    if not next(tLocalizedZones) then
        RebuildLocalizedZones()
    end

    if event == "STATUS" or event == "PLAYER_ENTERING_WORLD" then
        -- 进副本/重载/登录：清空动态阵容 present-set，避免跨周/跨次残留误判
        wipe(tPresentNPCIDs)
        iPresentOrder = 0
        -- Short delay so other modules' STATUS work has run, then schedule a late-init.
        C_Timer.After(0.1, function() MBT:FireEvent("MultiBossTracker_ZoneData_LateInit") end)
    elseif event == "ENCOUNTER_END" then
        return HandleEncounterEnd(...)
    end

    if InCombatLockdown() then
        return bLastResult
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        DetectUnit("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        DetectUnit(...)
    end

    local newZone, tZoneData = GetZoneData()
    BroadcastZoneData(event, newZone, tZoneData)
    iLastEncounter = iCurrentEncounter
    sLastZone = newZone
    bLastResult = (tZoneData ~= nil)
    return bLastResult
end

-- Each new tier section as it loads triggers a rebuild and a re-evaluate.
MBT:RegisterMDFEvent("MultiBossTracker_ZonesData_Section", function()
    RebuildLocalizedZones()
    Tick("MultiBossTracker_ZoneData_LateInit")
end)

-- Drive Tick from real WoW events (subscribed via AceEvent on enable below).
local frame = CreateFrame("Frame")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:SetScript("OnEvent", function(_, event, ...) Tick(event, ...) end)

MBT:RegisterMDFEvent("STATUS", function() Tick("STATUS") end)
MBT:RegisterMDFEvent("MultiBossTracker_ZoneData_LateInit", function() Tick("MultiBossTracker_ZoneData_LateInit") end)
