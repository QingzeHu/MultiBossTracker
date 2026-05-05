-- Class Data: Hunter
local addonName, MBT = ...

local tAuraData = {}
tAuraData.tDotOrderIndices = {
    [1]="Explosive Trap",
    [2]="Serpent Sting",
    [3]="Hunter's Mark",
    [4]="Black Arrow",
    [5]="Explosive Shot",
}

tAuraData.tDotAuras = {
    [1978]="Serpent Sting", [13549]="Serpent Sting", [13550]="Serpent Sting",
    [13551]="Serpent Sting", [13552]="Serpent Sting", [13553]="Serpent Sting",
    [13554]="Serpent Sting", [13555]="Serpent Sting",
    [25295]="Serpent Sting", [27016]="Serpent Sting",
    [49000]="Serpent Sting", [49001]="Serpent Sting",
    [1130]="Hunter's Mark", [14323]="Hunter's Mark",
    [14324]="Hunter's Mark", [14325]="Hunter's Mark", [53338]="Hunter's Mark",
    [3674]="Black Arrow", [63668]="Black Arrow", [63669]="Black Arrow",
    [63670]="Black Arrow", [63671]="Black Arrow", [63672]="Black Arrow",
    [53301]="Explosive Shot", [60051]="Explosive Shot",
    [60052]="Explosive Shot", [60053]="Explosive Shot",
    [49065]="Explosive Trap",
}

tAuraData.tDamageTriggers = { [53209] = "Chimera Shot" }
tAuraData.tDamageInfos = {
    ["Chimera Shot"] = {
        tRefreshAura = { tAuras = { "Serpent Sting" } },
    },
}

tAuraData.tSpellsInfos = {
    ["Serpent Sting"] = {
        iDuration=21, sName="Serpent Sting", iIcon=132204,
        tGlyphDuration = { iGlyphID=237645, iExtraDuration=6 },
        iColorR=0.138, iColorG=0.747, iColorB=0.234,
    },
    ["Hunter's Mark"] = {
        iDuration=300, sName="Hunter's Mark", iIcon=132212,
    },
    ["Black Arrow"] = {
        iDuration=15, sName="Black Arrow", iIcon=136181,
        iColorR=0.448, iColorG=0.047, iColorB=0.748,
    },
    ["Explosive Trap"] = {
        iDuration=20, sName="Explosive Trap", iIcon=135826,
        iColorR=0.448, iColorG=0.047, iColorB=0.748,
    },
    ["Explosive Shot"] = {
        iDuration=2, sName="Explosive Shot", iIcon=236178,
        iColorR=0.948, iColorG=0.547, iColorB=0.247,
    },
}
tAuraData.fExecuteRange = 0.2

MBT:RegisterClassData("HUNTER", tAuraData)
