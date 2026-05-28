-- Cast Dispatcher
-- Listens for NPC SPELL_CAST_START / FAILED / INTERRUPT and broadcasts MultiBossTracker_CastStarted /
-- MultiBossTracker_CastEnded so the per-frame cast bar can render.
local addonName, MBT = ...

local bActive = false
local tNPCIdToFrames, tFrameToNPCIds = {}, {}
local tFrameList = MBT.FRAME_IDS

local function StartCast(frameID, spellID)
    if not spellID then return end
    local name, _, icon, castTime = GetSpellInfo(spellID)
    if not name then return end
    MBT:FireEvent("MultiBossTracker_CastStarted", frameID, {
        sSpellName     = name,
        icon           = icon,
        iDuration      = (castTime or 0) / 1000,
        iExpirationTime = GetTime() + (castTime or 0) / 1000,
    })
end

local function EndCast(frameID)
    MBT:FireEvent("MultiBossTracker_CastEnded", frameID, { sSpellName = "Failed" })
end

-- Color the source name when an interrupt is reported.
local function ClassColored(name)
    return name or "?"
end

local function InterruptCast(frameID, spellID, sourceName)
    if not spellID then return end
    MBT:FireEvent("MultiBossTracker_CastEnded", frameID, {
        sSpellName = "Interrupted - " .. ClassColored(sourceName),
    })
end

local function HandleCLEU(args)
    if not bActive or not MBT.db.profile.bShowNPCCasts then return end
    local sub = args[2]
    local sourceGUID = args[4]
    local sourceNPCID = sourceGUID and select(6, strsplit("-", sourceGUID)) or nil

    if sourceNPCID and tNPCIdToFrames[sourceNPCID] then
        local frameID = tNPCIdToFrames[sourceNPCID]
        if sub == "SPELL_CAST_START" then
            StartCast(frameID, args[12])
        elseif sub == "SPELL_CAST_FAILED" then
            EndCast(frameID)
        end
    elseif sub == "SPELL_INTERRUPT" then
        local targetGUID = args[8]
        local targetNPCID = targetGUID and select(6, strsplit("-", targetGUID)) or nil
        local frameID = targetNPCID and tNPCIdToFrames[targetNPCID]
        if frameID then InterruptCast(frameID, args[12], args[5]) end
    end
end

local function SetNPCIDToFrame(frameID, tSharedZoneData)
    if not tSharedZoneData then return false end
    local d = tSharedZoneData[frameID]
    if not d or not d.sNPCID then return false end
    if tFrameToNPCIds[frameID] then
        tNPCIdToFrames[tFrameToNPCIds[frameID]] = nil
    end
    tFrameToNPCIds[frameID] = d.sNPCID
    tNPCIdToFrames[d.sNPCID] = frameID
    return true
end

local function SetNPCIDToFrames(tZoneData)
    for _, fid in ipairs(tFrameList) do SetNPCIDToFrame(fid, tZoneData) end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", function(_, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCLEU({ CombatLogGetCurrentEventInfo() })
    end
end)

MBT:RegisterMDFEvent("MultiBossTracker_ChangeZone", function(_, zone, tZoneData)
    bActive = tZoneData ~= nil
    SetNPCIDToFrames(tZoneData)
end)
