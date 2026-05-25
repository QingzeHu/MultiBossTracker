-- ClickCast: builds the macrotext attribute for each boss-frame button so clicks resolve to:
--   /tar [@target,noexists] player    (save current target placeholder)
--   /cleartarget; /targetlasttarget   (rotate target stack)
--   /targetexact <BossName>           (switch to the boss this frame represents)
--   /cast <spell>                     (or /focus / /target / /petattack)
--   /targetlasttarget...              (restore prior target)
--
-- The "spell" can also be one of three special keywords: "target", "focus", "petattack" — in
-- which case we don't /cast, we issue the action directly with [mod:...] modifier branches.
local addonName, MBT = ...

local sSetupTargetMacro   = "/tar [@target,noexists] player\n/cleartarget\n/targetlasttarget\n"
local sRestoreTargetMacro = "/targetlasttarget\n/targetlasttarget [@target,noexists]\n/cleartarget [@target,help]\n"

local tReservedSpells = {
    ["focus"]     = true,
    ["target"]    = true,
    ["petattack"] = true,
}

-- Build the modifier-branch portion of an action keyword (target/focus/petattack).
-- Returns: bIsSet, bossPrefixedAction (e.g. "\n/targetexact [nomod][mod:shift]<Boss>\n"),
-- and the action invocation (e.g. "\n/focus [nomod][mod:shift] ").
local function GetMacroAction(sAction, sSpell, sShiftSpell, sCtrlSpell, sAltSpell, bossName)
    local sMacro1, sMacro2 = "", ""
    local bIsSet = false
    local function add(modSpell, modName)
        if modSpell == sAction then
            if not bIsSet then
                sMacro1 = "\n/targetexact "
                sMacro2 = "\n/" .. sAction .. " "
            end
            sMacro1 = sMacro1 .. "[mod:" .. modName .. "]"
            sMacro2 = sMacro2 .. "[mod:" .. modName .. "]"
            bIsSet = true
        end
    end
    if sAction == sSpell then
        sMacro1 = "\n/targetexact [nomod]"
        sMacro2 = "\n/" .. sAction .. " [nomod]"
        bIsSet = true
    end
    add(sShiftSpell, "shift")
    add(sCtrlSpell, "ctrl")
    add(sAltSpell, "alt")
    if bIsSet then
        sMacro1 = sMacro1 .. (bossName or "") .. "\n"
    end
    return bIsSet, sMacro1, sMacro2
end

-- Build the "/cast [...]" spell list — only includes non-reserved, non-empty spell names.
local function GetMacroSpell(sSpell, sShiftSpell, sCtrlSpell, sAltSpell)
    local sMacro = ""
    local bHasSpell = false
    local function add(modSpell, modName)
        if modSpell ~= "" and tReservedSpells[modSpell] == nil then
            if bHasSpell then sMacro = sMacro .. "; " end
            sMacro = sMacro .. "[mod:" .. modName .. "] " .. modSpell
            bHasSpell = true
        end
    end
    if sSpell ~= "" and tReservedSpells[sSpell] == nil then
        sMacro = sMacro .. "[nomod] " .. sSpell
        bHasSpell = true
    end
    add(sShiftSpell, "shift")
    add(sCtrlSpell, "ctrl")
    add(sAltSpell, "alt")
    return bHasSpell, sMacro
end

-- Compose the full macrotext for one click button (1..5).
local function GetBindingMacro(sSpell, sShiftSpell, sCtrlSpell, sAltSpell, bossName, frameID)
    local _, spellPart = GetMacroSpell(sSpell, sShiftSpell, sCtrlSpell, sAltSpell)
    local hasSpell = spellPart ~= ""
    local hasTarget,    targetPart,    _ = GetMacroAction("target",    sSpell, sShiftSpell, sCtrlSpell, sAltSpell, bossName)
    local hasFocus,     focusPart1, focusPart2     = GetMacroAction("focus",     sSpell, sShiftSpell, sCtrlSpell, sAltSpell, bossName)
    local hasPet,       petPart1,   petPart2       = GetMacroAction("petattack", sSpell, sShiftSpell, sCtrlSpell, sAltSpell, bossName)

    local out = ""
    if hasSpell then
        out = sSetupTargetMacro
            .. "/targetexact " .. (bossName or "") .. "\n"
            .. "/cast " .. spellPart .. "\n"
            .. sRestoreTargetMacro
    end
    if hasTarget then
        out = out .. targetPart
    end
    if hasPet then
        out = out .. sSetupTargetMacro .. petPart1 .. petPart2 .. "\n" .. sRestoreTargetMacro
    end
    if hasFocus then
        out = out .. sSetupTargetMacro .. focusPart1 .. focusPart2 .. "\n" .. sRestoreTargetMacro
    end
    return out
end
MBT.GetBindingMacro = GetBindingMacro

-- Apply macros to one frame's button using the active class bindings + this frame's boss name.
local function SetupSecureFrame(btn, bindings, bossName)
    if InCombatLockdown() then return end       -- can't mutate secure attributes in combat
    if not btn then return end
    btn.bossName = bossName

    -- DoT 点击模式：boss 框本体 5 个鼠标键统一变成 /targetexact <boss>，修饰键全部失效
    -- DoT 图标的点击由 BossFrame.RebuildDotClickSlots 单独写宏到每个 slot 上
    if MBT.IsDotClickMode and MBT:IsDotClickMode() then
        local m = "/targetexact " .. (bossName or "")
        btn:SetAttribute("*macrotext1", m)
        btn:SetAttribute("*macrotext2", m)
        btn:SetAttribute("*macrotext3", m)
        btn:SetAttribute("*macrotext4", m)
        btn:SetAttribute("*macrotext5", m)
        return
    end

    if not bindings then return end
    local function build(prefix)
        local k = "t" .. prefix .. "Click"
        local s = "tS" .. prefix .. "Click"
        local c = "tC" .. prefix .. "Click"
        local a = "tA" .. prefix .. "Click"
        return GetBindingMacro(
            (bindings[k] and bindings[k].sSpell) or "",
            (bindings[s] and bindings[s].sSpell) or "",
            (bindings[c] and bindings[c].sSpell) or "",
            (bindings[a] and bindings[a].sSpell) or "",
            bossName,
            btn.frameID
        )
    end
    btn:SetAttribute("*macrotext1", build("L"))
    btn:SetAttribute("*macrotext2", build("R"))
    btn:SetAttribute("*macrotext3", build("M"))
    btn:SetAttribute("*macrotext4", build("4"))
    btn:SetAttribute("*macrotext5", build("5"))
end
MBT.SetupSecureFrame = SetupSecureFrame

-- Refresh secure macros on every visible frame using the latest zone data.
local function RefreshAll(tZoneData)
    if InCombatLockdown() then
        -- Defer until we leave combat — secure attributes can't be mutated mid-fight.
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
            RefreshAll(tZoneData)
        end)
        return
    end
    local class = MBT.formattedClassData
    -- 修饰键模式必须有 bindings；dot-click 模式不依赖 bindings（宏只用 boss 名）
    local isDotClick = MBT.IsDotClickMode and MBT:IsDotClickMode()
    if not isDotClick and (not class or not class.tCastingModeBindings) then return end
    local bindings = class and class.tCastingModeBindings or nil
    for fid, btn in pairs(MBT.BossFrames) do
        local slot = tZoneData and tZoneData[fid]
        if slot and slot.sTarName then
            SetupSecureFrame(btn, bindings, slot.sTarName)
        end
    end
end
MBT.RefreshAllClickCast = RefreshAll

MBT:RegisterMDFEvent("MultiBossTracker_RefreshClickCast", function(_, tZoneData)
    RefreshAll(tZoneData)
end)

-- When the user changes a binding in the options panel, BindingsChanged → Formatter re-runs →
-- ClassData_Formatted fires. We re-apply the macros using the cached zone data so the change
-- takes effect immediately, no zone change required.
MBT:RegisterMDFEvent("MultiBossTracker_ClassData_Formatted", function()
    if MBT.lastZoneData then RefreshAll(MBT.lastZoneData) end
end)
