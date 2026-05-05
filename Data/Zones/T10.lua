-- Zone Data: T10 (Icecrown Citadel + Ruby Sanctum)
local addonName, MBT = ...

local bIsHorde = (UnitFactionGroup("player") == "Horde")
local tZonesData = {}
tZonesData.sName = "T10"
tZonesData.tBlacklistKey = "tT10"
tZonesData.tZones = {
    ["The Spire"] = {
        ["A"] = { sNPCID = "36612", sTarName = "Lord Marrowgar", iIcon = 313914, tEnabledOptions = {"bMarrowgarFight","bMarrowgar"} },
        ["B"] = { sNPCID = "36619", sTarName = "Bone Spike",     iIcon = 133718, tEnabledOptions = {"bMarrowgarFight","bBoneSpike"} },
    },
    ["Oratory of the Damned"] = {
        ["A"] = { sNPCID = "36855", sTarName = "Lady Deathwhisper", iIcon = 134437, tEnabledOptions = {"bDeathwhisperFight","bDeathwhisper"} },
        ["B"] = { sNPCID = "37949", sTarName = "Cult Adherent",     iIcon = 133809, tEnabledOptions = {"bDeathwhisperFight","bDeathwhisperAdherent"} },
        ["C"] = { sNPCID = "37890", sTarName = "Cult Fanatic",      iIcon = 133112, tEnabledOptions = {"bDeathwhisperFight","bDeathwhisperFanatic"} },
    },
    ["Rampart of Skulls"] = {
        ["A"] = { sNPCID = bIsHorde and "36948" or "34444",
                  sTarName = bIsHorde and "Muradin Bronzebeard" or "High Overlord Saurfang",
                  iIcon    = bIsHorde and 236444 or 136043,
                  tEnabledOptions = {"bGunshipFight","bGunshipBoss"} },
    },
    ["Deathbringer's Rise"] = {
        ["A"] = { sNPCID = "37813", sTarName = "Deathbringer Saurfang", iIcon = 236452, tEnabledOptions = {"bSaurfangFight","bSaurfang"} },
        ["B"] = { sNPCID = "38508", sTarName = "Blood Beast",           iIcon = 132107, tEnabledOptions = {"bSaurfangFight","bBloodBeast"} },
    },
    ["The Plagueworks"] = {
        ["Encounters"] = {
            [849] = {
                ["A"] = { sNPCID = "36626", sTarName = "Festergut",  iIcon = 135867, tEnabledOptions = {"bFestergutFight","bFestergut"} },
            },
            [850] = {
                ["A"] = { sNPCID = "36627", sTarName = "Rotface",     iIcon = 136159, tEnabledOptions = {"bRotfaceFight","bRotface"} },
                ["B"] = { sNPCID = "36897", sTarName = "Little Ooze", iIcon = 134437, tEnabledOptions = {"bRotfaceFight","bLittleOoze"} },
            },
        },
    },
    ["Putricide's Laboratory of Alchemical Horrors and Fun"] = {
        ["A"] = { sNPCID = "36678", sTarName = "Professor Putricide", iIcon = 341459, tEnabledOptions = {"bPutricideFight","bPutricide"} },
        ["B"] = { sNPCID = "37697", sTarName = "Volatile Ooze",       iIcon = 134437, tEnabledOptions = {"bPutricideFight","bVolatileOoze"} },
        ["C"] = { sNPCID = "37562", sTarName = "Gas Cloud",           iIcon = 135867, tEnabledOptions = {"bPutricideFight","bGasCloud"} },
    },
    ["The Crimson Hall"] = {
        ["A"] = { sNPCID = "37973", sTarName = "Prince Taldaram",  iIcon = 298669, tEnabledOptions = {"bBloodCouncilFight","bTaldaram"} },
        ["B"] = { sNPCID = "37972", sTarName = "Prince Keleseth",  iIcon = 298668, tEnabledOptions = {"bBloodCouncilFight","bKeleseth"} },
        ["C"] = { sNPCID = "37970", sTarName = "Prince Valanar",   iIcon = 343635, tEnabledOptions = {"bBloodCouncilFight","bValanar"} },
    },
    ["The Sanctum of Blood"] = {
        ["A"] = { sNPCID = "37955", sTarName = "Blood-Queen Lana'thel", iIcon = 343633, tEnabledOptions = {"bBQLFight","bBQL"} },
    },
    ["The Frostwing Halls"] = {
        ["A"] = { sNPCID = "36789", sTarName = "Valithria Dreamwalker",   iIcon = 134157, tEnabledOptions = {"bValithriaFight","bValithria"} },
        ["B"] = { sNPCID = "37886", sTarName = "Gluttonous Abomination",  iIcon = 136118, tEnabledOptions = {"bValithriaFight","bGluttonousAbo"} },
        ["C"] = { sNPCID = "37868", sTarName = "Risen Archmage",          iIcon = 135846, tEnabledOptions = {"bValithriaFight","bRisenArchmage"} },
        ["D"] = { sNPCID = "37863", sTarName = "Suppresser",              iIcon = 136198, tEnabledOptions = {"bValithriaFight","bSuppresser"} },
    },
    ["The Frost Queen's Lair"] = {
        ["A"] = { sNPCID = "36853", sTarName = "Sindragosa", iIcon = 341980, tEnabledOptions = {"bSindragosaFight","bSindragosa"} },
    },
    ["The Frozen Throne"] = {
        ["A"] = { sNPCID = "36597", sTarName = "The Lich King",        iIcon = 341221, tEnabledOptions = {"bLKFight","bLK"} },
        ["B"] = { sNPCID = "37698", sTarName = "Shambling Horror",     iIcon = 237568, tEnabledOptions = {"bLKFight","bLKHorror"} },
        ["C"] = { sNPCID = "36633", sTarName = "Ice Sphere",           iIcon = 132872, tEnabledOptions = {"bLKFight","bLKIceSphere"} },
        ["D"] = { sNPCID = "36701", sTarName = "Raging Spirit",        iIcon = 236300, tEnabledOptions = {"bLKFight","bLKRagingSpirit"} },
        ["E"] = { sNPCID = "36609", sTarName = "Val'kyr Shadowguard",  iIcon = 298674, tEnabledOptions = {"bLKFight","bLKValkyr"} },
        ["F"] = { sNPCID = "39190", sTarName = "Wicked Spirit",        iIcon = 236548, tEnabledOptions = {"bLKFight","bLKWickedSpirit"} },
    },
    ["The Ruby Sanctum"] = {
        ["A"] = { sNPCID = "39863", sTarName = "Halion",          iIcon = 134158, tEnabledOptions = {"bHalionFight","bHalion"} },
        ["B"] = { sNPCID = "40142", sTarName = "Halion",          iIcon = 134154, tEnabledOptions = {"bHalionFight","bHalion"} },
        ["C"] = { sNPCID = "40681", sTarName = "Living Inferno",  iIcon = 135790, tEnabledOptions = {"bHalionFight","bHalionElem"} },
        ["D"] = { sNPCID = "40683", sTarName = "Living Ember",    iIcon = 132839, tEnabledOptions = {"bHalionFight","bHalionEmber"} },
    },
}

MBT:RegisterZonesSection(tZonesData)
