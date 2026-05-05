-- Class Data: Druid
local addonName, MBT = ...

local tAuraData = {}
tAuraData.tDotOrderIndices = { [1]="None", [2]="Insect Swarm", [3]="Moonfire", [4]="Faerie Fire" }

tAuraData.tDotAuras = {
    [5570]="Insect Swarm", [24974]="Insect Swarm", [24975]="Insect Swarm",
    [24976]="Insect Swarm", [24977]="Insect Swarm", [27013]="Insect Swarm", [48468]="Insect Swarm",
    [8921]="Moonfire", [8924]="Moonfire", [8925]="Moonfire", [8926]="Moonfire",
    [8927]="Moonfire", [8928]="Moonfire", [8929]="Moonfire",
    [9833]="Moonfire", [9834]="Moonfire", [9835]="Moonfire",
    [26987]="Moonfire", [26988]="Moonfire", [48462]="Moonfire", [48463]="Moonfire",
    [770]="Faerie Fire", [16857]="Faerie Fire",
    [33876]="Mangle", [33982]="Mangle", [33983]="Mangle", [48565]="Mangle", [48566]="Mangle",
    [33878]="Mangle", [33986]="Mangle", [33987]="Mangle", [48563]="Mangle", [48564]="Mangle",
    [1822]="Rake", [1823]="Rake", [1824]="Rake", [9904]="Rake",
    [27003]="Rake", [48573]="Rake", [48574]="Rake",
    [1079]="Rip", [9492]="Rip", [9493]="Rip", [9752]="Rip",
    [9894]="Rip", [9896]="Rip", [27008]="Rip", [49799]="Rip", [49800]="Rip",
}

tAuraData.tDamageTriggers = {
    [2912]="Starfire", [8949]="Starfire", [8950]="Starfire", [8951]="Starfire",
    [9875]="Starfire", [9876]="Starfire", [25298]="Starfire", [26986]="Starfire",
    [48464]="Starfire", [48465]="Starfire",
    [5221]="Shred", [6800]="Shred", [8992]="Shred", [9829]="Shred", [9830]="Shred",
    [27001]="Shred", [27002]="Shred", [48571]="Shred", [48572]="Shred",
}

tAuraData.tSpellsInfos = {
    ["Insect Swarm"] = {
        iDuration=12, sName="Insect Swarm", iIcon=136045,
        iColorR=0.154, iColorG=0.847, iColorB=0.031,
        iTalentedDuration = { iTalentPage=1, iTalentID=28, tIncDurations = {[1]=2} },
    },
    ["Moonfire"] = {
        iDuration=15, sName="Moonfire", iIcon=136096,
        iColorR=0.121, iColorG=0.145, iColorB=0.931,
        bAffectedByHaste = true,
    },
    ["Faerie Fire"] = {
        iDuration=300, sName="Faerie Fire", iIcon=136033,
        iColorR=0.948, iColorG=0.047, iColorB=0.934,
    },
    ["Mangle"] = {
        iDuration=60, sName="Mangle", iIcon=132135,
        iColorR=1.000, iColorG=0.647, iColorB=0.031,
    },
    ["Rake"] = {
        iDuration=9, sName="Rake", iIcon=132122,
        iColorR=1.000, iColorG=0.247, iColorB=0.247,
    },
    ["Rip"] = {
        iDuration=12, sName="Rip", iIcon=132152,
        iColorR=0.796, iColorG=0.147, iColorB=0.147,
        iSetBonusDuration = {
            iItemCount = 2, iIncDuration = 4,
            tItems = { 39553,39554,39555,39556,39557, 40471,40472,40473,40493,40494 },
        },
    },
}
tAuraData.fExecuteRange = 0

MBT:RegisterClassData("DRUID", tAuraData)
