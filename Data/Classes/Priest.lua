-- Class Data: Priest
local addonName, MBT = ...

local bIsHorde = (UnitFactionGroup("player") == "Horde")
local tAuraData = {}
tAuraData.tDotOrderIndices = { [1]="None", [2]="Vampiric Touch", [3]="Shadow Word: Pain", [4]="Devouring Plague" }

tAuraData.tDotAuras = {
    [34914]="Vampiric Touch", [34916]="Vampiric Touch", [34917]="Vampiric Touch",
    [48159]="Vampiric Touch", [48160]="Vampiric Touch",
    [589]="Shadow Word: Pain", [594]="Shadow Word: Pain", [970]="Shadow Word: Pain",
    [992]="Shadow Word: Pain", [2767]="Shadow Word: Pain",
    [10892]="Shadow Word: Pain", [10893]="Shadow Word: Pain", [10894]="Shadow Word: Pain",
    [25367]="Shadow Word: Pain", [25368]="Shadow Word: Pain",
    [48124]="Shadow Word: Pain", [48125]="Shadow Word: Pain",
    [2944]="Devouring Plague", [19276]="Devouring Plague", [19277]="Devouring Plague",
    [19278]="Devouring Plague", [19279]="Devouring Plague", [19280]="Devouring Plague",
    [25467]="Devouring Plague", [48299]="Devouring Plague", [48300]="Devouring Plague",
    [15407]="Mind Flay", [17311]="Mind Flay", [17312]="Mind Flay",
    [17313]="Mind Flay", [17314]="Mind Flay", [18807]="Mind Flay",
    [25387]="Mind Flay", [48155]="Mind Flay", [48156]="Mind Flay",
}
tAuraData.tDamageTriggers = {}
tAuraData.tDamageInfos    = {}

tAuraData.tSpellsInfos = {
    ["Shadow Word: Pain"] = {
        iDuration=18, sName="Shadow Word: Pain", iIcon=136207,
        iColorR=1.000, iColorG=0.647, iColorB=0.031,
    },
    ["Vampiric Touch"] = {
        iDuration=15, sName="Vampiric Touch", iIcon=135978,
        iColorR=0.213, iColorG=0.267, iColorB=0.945,
        bAffectedByHaste = true,
        iSetBonusDuration = {
            iItemCount = 2, iIncDuration = 6,
            tItems = {
                bIsHorde and 48098 or 48073, bIsHorde and 48097 or 48072,
                bIsHorde and 48101 or 48076, bIsHorde and 48099 or 48074,
                bIsHorde and 48100 or 48075, bIsHorde and 48095 or 48078,
                bIsHorde and 48096 or 48077, bIsHorde and 48092 or 48081,
                bIsHorde and 48094 or 48079, bIsHorde and 48093 or 48080,
                bIsHorde and 48088 or 48085, bIsHorde and 48087 or 48086,
                bIsHorde and 48091 or 48082, bIsHorde and 48089 or 48084,
                bIsHorde and 48090 or 48083,
            },
        },
    },
    ["Devouring Plague"] = {
        iDuration=24, sName="Devouring Plague", iIcon=252996,
        iColorR=0.948, iColorG=0.047, iColorB=0.934,
        bAffectedByHaste = true, bRemoveFromOtherFrames = true,
    },
    ["Mind Flay"] = {
        tRefreshAura = {
            tRefreshTalent = { iRow=3, iIndex=24 },
            tAuras = { "Shadow Word: Pain" },
        },
    },
}
tAuraData.fExecuteRange = 0
tAuraData.iRangeCheckSpellID = 8092   -- 心灵震爆 40y

MBT:RegisterClassData("PRIEST", tAuraData)
