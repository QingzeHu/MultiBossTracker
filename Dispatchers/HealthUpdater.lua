-- Health Updater
-- WoW exposes no API to look up a unit token by NPCID, so this scans target / focus / pettarget /
-- raid<N>target / raid<N>pettarget on every CLEU SPELL_DAMAGE pulse (rate-limited).
local addonName, MBT = ...

local tFramesNPCIDs = {}
local tNPCToFind = {}
local iNPCsToFind = 0
local iNPCsFound = 0
local tUnitCache = {}
local fNextUpdate = 0
local bActive = false
local tZoneData = nil

local function CheckUnitForMatch(unit)
    local guid = UnitGUID(unit)
    if not guid then return false end
    local npcID = select(6, strsplit("-", guid))
    if npcID and tNPCToFind[npcID] then
        MBT:FireEvent("MultiBossTracker_UpdateHealth", npcID, unit)
        tUnitCache[tNPCToFind[npcID]] = unit
        tNPCToFind[npcID] = nil
        iNPCsFound = iNPCsFound + 1
        return true
    end
    return false
end

local function UpdateHealthBars()
    iNPCsFound = 0
    tNPCToFind = {}
    for k, v in pairs(tFramesNPCIDs) do tNPCToFind[v] = k end

    -- Cached unit tokens first.
    for k, v in pairs(tUnitCache) do
        if not CheckUnitForMatch(v) then tUnitCache[k] = nil end
    end

    -- Single targets.
    CheckUnitForMatch("target")
    CheckUnitForMatch("focus")
    CheckUnitForMatch("pettarget")

    -- Raid scan up to 40.
    for i = 0, 40 do
        CheckUnitForMatch("raid" .. i .. "target")
        CheckUnitForMatch("raid" .. i .. "pettarget")
        if iNPCsFound >= iNPCsToFind then break end
    end
end

local function SetupNPCIDs()
    tFramesNPCIDs = {}
    iNPCsToFind = 0
    if not tZoneData then return end
    for k, v in pairs(tZoneData) do
        if type(v) == "table" and v.sNPCID then
            tFramesNPCIDs[k] = v.sNPCID
            iNPCsToFind = iNPCsToFind + 1
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("RAID_TARGET_UPDATE")
frame:SetScript("OnEvent", function(_, event)
    if event == "RAID_TARGET_UPDATE" then
        -- 团长改了团标 → 立刻跑一次扫描刷新所有 boss 框（绕过 fHealthUpdateInterval 节流）
        if not bActive then return end
        UpdateHealthBars()
        fNextUpdate = GetTime() + (MBT.db.profile.fHealthUpdateInterval or 1)
        return
    end
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return end
    if not bActive then return end
    local fTime = GetTime()
    if fTime < fNextUpdate then return end
    UpdateHealthBars()
    fNextUpdate = fTime + (MBT.db.profile.fHealthUpdateInterval or 1)
end)

MBT:RegisterMDFEvent("MultiBossTracker_ChangeZone", function(_, zone, zd)
    bActive = (zd ~= nil) and (MBT.db.profile.fHealthUpdateInterval or 0) > 0
    tZoneData = zd
    SetupNPCIDs()
    fNextUpdate = 0
end)
