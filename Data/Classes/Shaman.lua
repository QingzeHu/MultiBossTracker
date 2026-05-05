-- Class Data: Shaman
local addonName, MBT = ...

local bIsHorde = (UnitFactionGroup("player") == "Horde")
local tAuraData = {}
tAuraData.tDotOrderIndices = { [1]="None", [2]="Flame Shock" }
tAuraData.tDotAuras = {
    [8050]="Flame Shock", [8052]="Flame Shock", [8053]="Flame Shock",
    [10447]="Flame Shock", [10448]="Flame Shock",
    [29228]="Flame Shock", [25457]="Flame Shock",
    [49232]="Flame Shock", [49233]="Flame Shock",
}
tAuraData.tDamageTriggers = {}
tAuraData.tDamageInfos    = {}
tAuraData.tSpellsInfos = {
    ["Flame Shock"] = {
        iDuration=18, sName="Flame Shock", iIcon=135813,
        iColorR=1.000, iColorG=0.547, iColorB=0.247,
        bAffectedByHaste = true,
        iSetBonusDuration = {
            iItemCount = 2, iIncDuration = 9,
            tItems = {
                bIsHorde and 48337 or 48312, bIsHorde and 48336 or 48310,
                bIsHorde and 48338 or 48313, bIsHorde and 48339 or 48314,
                bIsHorde and 48340 or 48315, bIsHorde and 48334 or 48317,
                bIsHorde and 48335 or 48316, bIsHorde and 48333 or 48318,
                bIsHorde and 48332 or 48319, bIsHorde and 48331 or 48320,
                bIsHorde and 48327 or 48324, bIsHorde and 48326 or 48325,
                bIsHorde and 48328 or 48323, bIsHorde and 48329 or 48322,
                bIsHorde and 48330 or 48321,
            },
        },
    },
}
tAuraData.fExecuteRange = 0
tAuraData.iRangeCheckSpellID = 403    -- 闪电箭 40y

MBT:RegisterClassData("SHAMAN", tAuraData)
