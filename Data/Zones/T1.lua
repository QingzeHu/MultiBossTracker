-- Zone Data: T1 (Molten Core / Onyxia / Magmadar)
local addonName, MBT = ...

local tZonesData = {}
tZonesData.sName = "T1"
tZonesData.tBlacklistKey = "tT1"
tZonesData.tZones = {
    ["熔火之心"] = {
        ["Encounters"] = {
            [665] = {
                ["A"] = { sNPCID = "12259", sTarName = "基赫纳斯",  iIcon = 254652 },
                ["B"] = { sNPCID = "11661", sTarName = "烈焰行者",  iIcon = 133932 },
                iNextEncounter = 666,
            },
            [666] = {
                ["A"] = { sNPCID = "12057", sTarName = "加尔",      iIcon = 136024 },
                ["B"] = { sNPCID = "12099", sTarName = "火誓者",    iIcon = 136027 },
                iNextEncounter = 668,
            },
            [668] = {
                ["A"] = { sNPCID = "12056", sTarName = "迦顿男爵",  iIcon = 135790 },
                iNextEncounter = 667,
            },
            [667] = {
                ["A"] = { sNPCID = "12264", sTarName = "沙斯拉尔",  iIcon = 298644 },
            },
            [669] = {
                ["A"] = { sNPCID = "12098", sTarName = "萨弗隆先驱者", iIcon = 254652 },
                ["B"] = { sNPCID = "11662", sTarName = "烈焰行者祭司", iIcon = 134301 },
            },
            [670] = {
                ["A"] = { sNPCID = "11988", sTarName = "焚化者古雷曼格", iIcon = 133886 },
                ["B"] = { sNPCID = "11672", sTarName = "熔火怒犬",       iIcon = 236191 },
            },
            [671] = {
                ["A"] = { sNPCID = "12018", sTarName = "管理者埃克索图斯", iIcon = 236436 },
                ["B"] = { sNPCID = "11663", sTarName = "烈焰行者医师",     iIcon = 135916 },
                ["C"] = { sNPCID = "11664", sTarName = "烈焰行者精英",     iIcon = 236425 },
            },
        },
    },

    ["玛格曼达洞穴"] = {
        ["Encounters"] = {
            iStartingFight = 663,
            [663] = {
                ["A"] = { sNPCID = "12118", sTarName = "鲁西弗隆",       iIcon = 136133 },
                ["B"] = { sNPCID = "12119", sTarName = "烈焰行者护卫",   iIcon = 133103 },
                iNextEncounter = 664,
            },
            [664] = {
                ["A"] = { sNPCID = "11982", sTarName = "玛格曼达",       iIcon = 236191 },
            },
        },
    },

    ["拉格纳罗斯之巢"] = {
        ["A"] = { sNPCID = "11502", sTarName = "拉格纳罗斯",         iIcon = 5332198 },
    },
}

MBT:RegisterZonesSection(tZonesData)
