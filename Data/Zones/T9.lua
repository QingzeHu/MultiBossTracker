-- Zone Data: T9 (Trial of the Crusader + Onyxia)
local addonName, MBT = ...

local bIsHorde = (UnitFactionGroup("player") == "Horde")
local tZonesData = {}
tZonesData.sName = "T9"
tZonesData.tBlacklistKey = "tT9"
tZonesData.tZones = {
    ["Trial of the Crusader"] = {
        ["Encounters"] = {
            iStartingFight = 629,
            [629] = { -- Northrend Beasts
                ["A"] = { sNPCID = "34796", sTarName = "Gormok the Impaler", iIcon = 236697, tEnabledOptions = {"bBeastsFight","bGormok"} },
                ["B"] = { sNPCID = "35144", sTarName = "Acidmaw",            iIcon = 134437, tEnabledOptions = {"bBeastsFight","bAcidmaw"} },
                ["C"] = { sNPCID = "34799", sTarName = "Dreadscale",         iIcon = 236197, tEnabledOptions = {"bBeastsFight","bDreadscale"} },
                ["D"] = { sNPCID = "34797", sTarName = "Icehowl",            iIcon = 132189, tEnabledOptions = {"bBeastsFight","bIcehowl"} },
                ["E"] = { sNPCID = "34800", sTarName = "Snobold Vassal",     iIcon = 134168, tEnabledOptions = {"bBeastsFight","bSnobold"} },
                iNextEncounter = 633,
            },
            [633] = { -- Lord Jaraxxus
                ["A"] = { sNPCID = "34780", sTarName = "Lord Jaraxxus",     iIcon = 136172, tEnabledOptions = {"bJaraxxusFight","bJaraxxus"} },
                ["B"] = { sNPCID = "34825", sTarName = "Nether Portal",     iIcon = 237560, tEnabledOptions = {"bJaraxxusFight","bNetherPortal"} },
                ["C"] = { sNPCID = "34813", sTarName = "Infernal Volcano",  iIcon = 135830, tEnabledOptions = {"bJaraxxusFight","bInfernalVolcano"} },
                ["D"] = { sNPCID = "34826", sTarName = "Mistress of Pain",  iIcon = 136220, tEnabledOptions = {"bJaraxxusFight","bMistressOfPain"} },
                iNextEncounter = 637,
            },
            [637] = { -- Faction Champions
                ["A"] = { sNPCID = bIsHorde and "34463" or "34455", sTarName = bIsHorde and "Shaabad" or "Broln Stouthorn",         iIcon = 136051, tEnabledOptions = {"bChampionsFight","bChampionsEnh"} },
                ["B"] = { sNPCID = bIsHorde and "34466" or "34447", sTarName = bIsHorde and "Anthar Forgemender" or "Caiphus the Stern", iIcon = 135987, tEnabledOptions = {"bChampionsFight","bChampionsDisc"} },
                ["C"] = { sNPCID = bIsHorde and "34469" or "34459", sTarName = bIsHorde and "Melador Valestrider" or "Erin Misthoof",    iIcon = 136041, tEnabledOptions = {"bChampionsFight","bChampionsRDruid"} },
                ["D"] = { sNPCID = bIsHorde and "34470" or "34444", sTarName = bIsHorde and "Saamul" or "Thrakgar",                       iIcon = 136043, tEnabledOptions = {"bChampionsFight","bChampionsRSham"} },
                ["E"] = { sNPCID = bIsHorde and "34472" or "34454", sTarName = bIsHorde and "Irieth Shadowstep" or "Maz'dinah",           iIcon = 132320, tEnabledOptions = {"bChampionsFight","bChampionsRogue"} },
                ["F"] = { sNPCID = bIsHorde and "34475" or "34453", sTarName = bIsHorde and "Shocuul" or "Narrhok Steelbreaker",          iIcon = 132355, tEnabledOptions = {"bChampionsFight","bChampionsWar"} },
                ["G"] = { sNPCID = bIsHorde and "34467" or "34448", sTarName = bIsHorde and "Alyssia Moonstalker" or "Ruj'kah",           iIcon = 626000, tEnabledOptions = {"bChampionsFight","bChampionsHunter"} },
                ["H"] = { sNPCID = bIsHorde and "34461" or "34458", sTarName = bIsHorde and "Tyrius Duskblade" or "Gorgrim Shadowcleave", iIcon = 135771, tEnabledOptions = {"bChampionsFight","bChampionsDK"} },
                ["I"] = { sNPCID = bIsHorde and "34474" or "34450", sTarName = bIsHorde and "Serissa Grimdabbler" or "Harkzog",          iIcon = 626007, tEnabledOptions = {"bChampionsFight","bChampionsWarlock"} },
                ["J"] = { sNPCID = bIsHorde and "34471" or "34456", sTarName = bIsHorde and "Baelnor Lightbearer" or "Malithas Brightblade", iIcon = 135873, tEnabledOptions = {"bChampionsFight","bChampionsRet"} },
                ["K"] = { sNPCID = bIsHorde and "34465" or "34445", sTarName = bIsHorde and "Velanaa" or "Liandra Suncaller",            iIcon = 135920, tEnabledOptions = {"bChampionsFight","bChampionsHPal"} },
                ["L"] = { sNPCID = bIsHorde and "34460" or "34451", sTarName = bIsHorde and "Kavina Grovesong" or "Birana Stormhoof",    iIcon = 236168, tEnabledOptions = {"bChampionsFight","bChampionsMoonkin"} },
                ["M"] = { sNPCID = bIsHorde and "34473" or "34441", sTarName = bIsHorde and "Brienna Nightfell" or "Vivienne Blackwhisper", iIcon = 136207, tEnabledOptions = {"bChampionsFight","bChampionsSP"} },
                ["N"] = { sNPCID = bIsHorde and "34468" or "34449", sTarName = bIsHorde and "Noozle Whizzlestick" or "Ginselle Blightslinger", iIcon = 135932, tEnabledOptions = {"bChampionsFight","bChampionsMage"} },
                iNextEncounter = 641,
            },
            [641] = { -- Twin Val'kyr
                ["A"] = { sNPCID = "34497", sTarName = "Fjola Lightbane", iIcon = 298674, tEnabledOptions = {"bValkyrTwinsFight","bFjolaLightbane"} },
                ["B"] = { sNPCID = "34496", sTarName = "Eydis Darkbane",  iIcon = 237565, tEnabledOptions = {"bValkyrTwinsFight","bEydisDarkbane"} },
            },
        },
    },
    ["The Icy Depths"] = {
        ["A"] = { sNPCID = "34564", sTarName = "Anub'arak",         iIcon = 298643, tEnabledOptions = {"bTOCAnubFight","bTOCAnub"} },
        ["B"] = { sNPCID = "34607", sTarName = "Nerubian Burrower", iIcon = 134435, tEnabledOptions = {"bTOCAnubFight","bTOCBurrower"} },
    },
    ["Onyxia's Lair"] = {
        ["A"] = { sNPCID = "10184", sTarName = "Onyxia",             iIcon = 134153, tEnabledOptions = {"bOnyxiaFight","bOnyxiaBoss"} },
        ["B"] = { sNPCID = "36561", sTarName = "Onyxian Lair Guard", iIcon = 236429, tEnabledOptions = {"bOnyxiaFight","bOnyxiaAdd"} },
    },
}

MBT:RegisterZonesSection(tZonesData)
