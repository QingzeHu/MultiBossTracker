-- Class Data: Mage
local addonName, MBT = ...

local tAuraData = {}
tAuraData.tDotOrderIndices = { [1]="None", [2]="Living Bomb", [3]="Pyroblast" }

tAuraData.tDotAuras = {
    [44457] = "Living Bomb", [55359] = "Living Bomb", [55360] = "Living Bomb",
    [11366] = "Pyroblast", [12505] = "Pyroblast", [12522] = "Pyroblast",
    [12523] = "Pyroblast", [12524] = "Pyroblast", [12525] = "Pyroblast",
    [12526] = "Pyroblast", [18809] = "Pyroblast", [27132] = "Pyroblast",
    [33938] = "Pyroblast", [42890] = "Pyroblast", [42891] = "Pyroblast",
}
tAuraData.tDamageTriggers = {}
tAuraData.tDamageInfos    = {}
tAuraData.tSpellsInfos = {
    ["Living Bomb"] = { iDuration=12, sName="Living Bomb", iIcon=236220, iColorR=1.000, iColorG=0.247, iColorB=0.247 },
    ["Pyroblast"]   = { iDuration=12, sName="Pyroblast",   iIcon=135808, iColorR=0.796, iColorG=0.147, iColorB=0.147 },
}
tAuraData.fExecuteRange = 0.35

MBT:RegisterClassData("MAGE", tAuraData)
