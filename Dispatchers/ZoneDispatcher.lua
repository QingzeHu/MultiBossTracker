-- Zone Dispatcher
-- Watches map / encounter / mouseover events and broadcasts MultiBossTracker_ChangeZone with
-- the (localized) zone data subtable for the current encounter slot, or nil to hide all frames.
local addonName, MBT = ...

local sEventName = "MultiBossTracker_ChangeZone"
local sLastZone, iLastEncounter, iCurrentEncounter = nil, 0, 0
local tLocalizedZones = {}    -- merged across all tier sections, with localized keys
local bLastResult = false

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

-- Mouseover an NPC inside the zone and we'll switch to that encounter automatically.
local function HandleMouseoverChanged()
    local tZoneData = tLocalizedZones[sLastZone]
    if not tZoneData then return false end
    if UnitIsDead("mouseover") then return false end

    local guid = UnitGUID("mouseover") or ""
    local npcID = select(6, strsplit("-", guid))
    if not npcID then return end
    local enc = tZoneData["Encounters"]
    if not enc then return end
    for iEncID, tEncData in pairs(enc) do
        if type(tEncData) == "table" then
            for _, tFrameData in pairs(tEncData) do
                if type(tFrameData) == "table" and tFrameData.sNPCID == npcID then
                    iCurrentEncounter = iEncID
                    return
                end
            end
        end
    end
end

-- Resolve the current zone + which encounter slot to broadcast.
local function GetZoneData()
    local newZone = GetSubZoneText()
    if newZone == "" then newZone = GetZoneText() end

    local tZoneData = tLocalizedZones[newZone]
    if tZoneData and tZoneData["Encounters"] then
        local enc = tZoneData["Encounters"]
        tZoneData = enc[iCurrentEncounter] or enc[enc.iStartingFight]
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
    if sLastZone ~= newZone or iLastEncounter ~= iCurrentEncounter or event == "MultiBossTracker_ZoneData_LateInit" then
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
        -- Short delay so other modules' STATUS work has run, then schedule a late-init.
        C_Timer.After(0.1, function() MBT:FireEvent("MultiBossTracker_ZoneData_LateInit") end)
    elseif event == "ENCOUNTER_END" then
        return HandleEncounterEnd(...)
    end

    if InCombatLockdown() then
        return bLastResult
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        HandleMouseoverChanged()
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
frame:SetScript("OnEvent", function(_, event, ...) Tick(event, ...) end)

MBT:RegisterMDFEvent("STATUS", function() Tick("STATUS") end)
MBT:RegisterMDFEvent("MultiBossTracker_ZoneData_LateInit", function() Tick("MultiBossTracker_ZoneData_LateInit") end)
