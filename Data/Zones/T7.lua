-- Zone Data: T7 (Naxxramas + Obsidian Sanctum)
local addonName, MBT = ...

local tZonesData = {}
tZonesData.sName = "T7"
tZonesData.tBlacklistKey = "tT7"
tZonesData.tZones = {
    ["The Obsidian Sanctum"] = {
        ["A"] = { sNPCID = "30452", sTarName = "Tenebron", iIcon = 236473, tEnabledOptions = {"bSartharionFight","bTenebron"} },
        ["B"] = { sNPCID = "30451", sTarName = "Shadron",  iIcon = 236470, tEnabledOptions = {"bSartharionFight","bShadron"} },
        ["C"] = { sNPCID = "30449", sTarName = "Vesperon", iIcon = 236473, tEnabledOptions = {"bSartharionFight","bVesperon"} },
    },
    ["The Horsemen's Assembly"] = {
        ["A"] = { sNPCID = "30549", sTarName = "Baron Rivendare", iIcon = 132264, tEnabledOptions = {"b4HMFight","bRivendare"} },
        ["B"] = { sNPCID = "16064", sTarName = "Thane Korth'azz", iIcon = 135821, tEnabledOptions = {"b4HMFight","bThane"} },
        ["C"] = { sNPCID = "16065", sTarName = "Lady Blaumeux",   iIcon = 136192, tEnabledOptions = {"b4HMFight","bBlaumeux"} },
        ["D"] = { sNPCID = "16063", sTarName = "Sir Zeliek",      iIcon = 135972, tEnabledOptions = {"b4HMFight","bZeliek"} },
    },
}

MBT:RegisterZonesSection(tZonesData)
