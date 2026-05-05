-- Class Data: Death Knight
local addonName, MBT = ...

local tAuraData = {}
tAuraData.tDotOrderIndices = { [1]="None", [2]="Frost Fever", [3]="Blood Plague" }

tAuraData.tDotAuras = {
    [55095] = "Frost Fever",
    [55078] = "Blood Plague",
}
tAuraData.tCastTriggers = { [50842] = "Pestilence" }
tAuraData.tCastInfos = {
    ["Pestilence"] = {
        tRefreshAura = {
            tRefreshGlyph = { iGlyphID = 237635 },  -- WotLK glyph; MoP glyph API differs
            tAuras = { "Frost Fever", "Blood Plague" },
        },
    },
}
tAuraData.tDamageTriggers = {}
tAuraData.tDamageInfos    = {}

tAuraData.tSpellsInfos = {
    ["Frost Fever"] = {
        iDuration=15, sName="Frost Fever", iIcon=237522,
        iColorR=0.254, iColorG=0.247, iColorB=9.247,
        iTalentedDuration = { iTalentPage=3, iTalentID=5, tIncDurations={[1]=3,[2]=6} },
    },
    ["Blood Plague"] = {
        iDuration=15, sName="Blood Plague", iIcon=237514,
        iColorR=0.296, iColorG=0.947, iColorB=0.147,
        iTalentedDuration = { iTalentPage=3, iTalentID=5, tIncDurations={[1]=3,[2]=6} },
    },
}
tAuraData.fExecuteRange = 0.0
tAuraData.iRangeCheckSpellID = 47541  -- 死亡缠绕 30y

MBT:RegisterClassData("DEATHKNIGHT", tAuraData)
