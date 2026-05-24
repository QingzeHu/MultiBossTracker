-- DoT Dispatcher
-- Watches CLEU and routes the player's DoT events to the right boss frame (A/B/C/D/E)
-- by NPCID. Broadcasts MultiBossTracker_DoTUpdate {Add|Remove|Refresh|Stack|IncreaseDuration}.
local addonName, MBT = ...

local sPlayerGUID = UnitGUID("player")
local tAuraData
local bActive = false
local tNPCIdToFrames = {}
local tFrameToNPCIds = {}
local tFrameList = {"A", "B", "C", "D", "E"}

local function GetSpellInfos(name)
    return tAuraData and tAuraData.tSpellsInfos[name]
end

-- 退路用的估算（仅当我们找不到该 boss 对应的 unit token 时才会用到）。
-- 直接用 UnitSpellHaste("player") 拿玩家急速百分比，比 WotLK 的"5 分钟咒语"取巧法靠谱得多。
local function GetDoTDuration(name)
    local info = GetSpellInfos(name)
    if not info then return 0 end
    local base = info.iFinalDuration or info.iDuration or 0
    if not info.bAffectedByHaste then return base end
    local haste = (UnitSpellHaste and UnitSpellHaste("player")) or 0   -- 百分比，30 表示 30%
    return base / (1 + haste / 100)
end

-- ---------------------------------------------------------------------
-- 真实 DoT 时长查询 —— 这是关键。
-- 由 NPC GUID 反查我们能拿到的 unit token，然后调 UnitDebuff 拿到 WoW 引擎里
-- 该 DoT 实际的 duration / expirationTime —— 这就是 boss 身上真实的剩余时间。
-- ---------------------------------------------------------------------
local UNIT_TOKENS = { "target", "focus", "mouseover", "pet" }
for i = 1, 5 do UNIT_TOKENS[#UNIT_TOKENS+1] = "boss" .. i end
for i = 1, 30 do UNIT_TOKENS[#UNIT_TOKENS+1] = "nameplate" .. i end
for i = 1, 40 do
    UNIT_TOKENS[#UNIT_TOKENS+1] = "raid" .. i .. "target"
    UNIT_TOKENS[#UNIT_TOKENS+1] = "raid" .. i .. "pettarget"
end

local function FindUnitForGUID(guid)
    if not guid then return nil end
    -- target 命中率最高，先查
    if UnitGUID("target") == guid then return "target" end
    for _, unit in ipairs(UNIT_TOKENS) do
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return unit
        end
    end
    return nil
end

-- 返回 { duration, expirationTime, icon, count } 或 nil
-- 一次性把 boss 身上 debuff 的真实数据全拿回来 —— duration、图标、层数
local function GetRealAuraInfo(targetGUID, spellID)
    local unit = FindUnitForGUID(targetGUID)
    if not unit then return nil end
    for i = 1, 40 do
        local _, icon, count, _, duration, expirationTime, source, _, _, sid = UnitDebuff(unit, i)
        if not expirationTime then return nil end
        if sid == spellID and source == "player" then
            return {
                duration = duration,
                expirationTime = expirationTime,
                icon = icon,
                count = count,
            }
        end
    end
    return nil
end

local function RemoveDebuffFromOtherFrames(self, frameID, name)
    for _, fid in ipairs(tFrameList) do
        if fid ~= frameID then
            self:RemoveDebuff(fid, name, true)
        end
    end
end

local DotDispatcher = {}

function DotDispatcher:AddDebuff(frameID, name, realInfo)
    local info = GetSpellInfos(name)
    if not info then return end
    if info.tRefreshAura and info.tRefreshAura.bEnabled then
        self:AttemptRefresh(frameID, info.tRefreshAura.tAuras)
    end
    -- 黑名单：跳过 dispatch，UI 不画图标；例外是 pip 追踪的咒语 —— 要透传到 BossFrame
    -- 以便 pip 指示器能拿到层数，BossFrame 那边自己决定是否隐藏图标
    if not info.sSlotName then return end
    if not info.bEnabled and not info.bPipTracked then return end
    if info.bRemoveFromOtherFrames then
        RemoveDebuffFromOtherFrames(self, frameID, name)
    end
    -- 优先用 UnitDebuff 读到的真实 duration / icon / 层数；找不到 unit 时退回静态配置
    local duration, expirationTime, icon, stacks
    if realInfo and realInfo.duration and realInfo.duration > 0 then
        duration       = realInfo.duration
        expirationTime = realInfo.expirationTime
        icon           = realInfo.icon
        stacks         = realInfo.count
    else
        duration       = GetDoTDuration(name)
        expirationTime = GetTime() + duration
    end
    local pkg = {
        sSpellName    = name,
        sSlotName     = info.sSlotName,
        duration      = duration,
        expirationTime = expirationTime,
        name          = info.sName,
        icon          = icon or info.iIcon,            -- runtime 优先，静态作 fallback
        iStacks       = (stacks and stacks > 1) and stacks or nil,
        iOrder        = info.iOrder,
        iColorR       = info.iColorR,
        iColorG       = info.iColorG,
        iColorB       = info.iColorB,
        iGlowAtStacks = info.iGlowAtStacks,
        autoHide      = not MBT.db.profile.bShowMissingDoTs,
    }
    MBT:FireEvent("MultiBossTracker_DoTUpdate", "Add", frameID, pkg)
end

function DotDispatcher:AddStack(frameID, name, stacks)
    local info = GetSpellInfos(name)
    if not info then return end
    MBT:FireEvent("MultiBossTracker_DoTUpdate", "Stack", frameID, {
        sSpellName = name, sSlotName = info.sSlotName, iStacks = stacks,
        iGlowAtStacks = info.iGlowAtStacks,
        iColorR = info.iColorR, iColorG = info.iColorG, iColorB = info.iColorB,
    })
end

function DotDispatcher:RemoveDebuff(frameID, name, bForceClear)
    local info = GetSpellInfos(name)
    if not info then return end
    MBT:FireEvent("MultiBossTracker_DoTUpdate", "Remove", frameID, {
        sSpellName = name, sSlotName = info.sSlotName, bForceClear = bForceClear == true,
    })
end

function DotDispatcher:AttemptRefresh(frameID, auras)
    if not auras then return end
    for _, aura in pairs(auras) do
        local info = GetSpellInfos(aura)
        if info then
            local fTime = GetDoTDuration(aura)
            MBT:FireEvent("MultiBossTracker_DoTUpdate", "Refresh", frameID, {
                sSpellName = aura, sSlotName = info.sSlotName,
                duration = fTime, expirationTime = GetTime() + fTime,
            })
        end
    end
end

local function ProcessSpellEvent(frameID, spellInfos)
    if not spellInfos then return end
    local fTime = GetTime()
    if (spellInfos.fLastOcc or 0) + 0.1 < fTime then
        if spellInfos.tRefreshAura and spellInfos.tRefreshAura.bEnabled then
            DotDispatcher:AttemptRefresh(frameID, spellInfos.tRefreshAura.tAuras)
        end
        spellInfos.fLastOcc = fTime
    end
end

local function HandleSpellCLEU(spellID, frameID, args)
    if not tAuraData then return end
    local sub = args[2]
    local name = tAuraData.tDotAuras[spellID]

    if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
        -- 直接问 WoW 引擎该 DoT 在 boss 身上的真实数据：duration / 图标 / 当前层数
        local targetGUID = args[8]
        local realInfo = GetRealAuraInfo(targetGUID, spellID)
        DotDispatcher:AddDebuff(frameID, name, realInfo)
    elseif sub == "SPELL_AURA_APPLIED_DOSE" then
        local stack = args[16]
        DotDispatcher:AddStack(frameID, name, stack)
    elseif sub == "SPELL_DAMAGE" or sub == "SPELL_ABSORBED" then
        local trig = tAuraData.tDamageTriggers[spellID]
        if trig then ProcessSpellEvent(frameID, tAuraData.tDamageInfos[trig]) end
    elseif sub == "SPELL_CAST_SUCCESS" then
        local trig = tAuraData.tCastTriggers and tAuraData.tCastTriggers[spellID]
        if trig then ProcessSpellEvent(frameID, tAuraData.tCastInfos[trig]) end
    elseif sub == "SPELL_AURA_REMOVED" then
        DotDispatcher:RemoveDebuff(frameID, name)
    end
end

local function HandleCLEU(args)
    if not bActive or not tAuraData then return end
    local sourceGUID = args[4]
    local targetGUID = args[8]
    if not targetGUID then return end
    local targetNPCID = select(6, strsplit("-", targetGUID))
    if sourceGUID ~= sPlayerGUID then return end
    local frameID = tNPCIdToFrames[targetNPCID]
    if not frameID then return end
    local spellID = args[12]
    if not spellID then return end
    HandleSpellCLEU(spellID, frameID, args)
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
    local any = false
    for _, fid in ipairs(tFrameList) do
        if SetNPCIDToFrame(fid, tZoneData) then any = true end
    end
    return any
end

-- Real WoW events
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:SetScript("OnEvent", function(_, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCLEU({ CombatLogGetCurrentEventInfo() })
    end
end)

MBT:RegisterMDFEvent("MultiBossTracker_ClassData_Formatted", function(_, data)
    tAuraData = data
end)

-- Reset on zone change.
MBT:RegisterMDFEvent("MultiBossTracker_ChangeZone", function(_, zone, tZoneData)
    bActive = tZoneData ~= nil
    SetNPCIDToFrames(tZoneData)
end)
