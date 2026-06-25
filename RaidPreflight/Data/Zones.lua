-- 副本 boss 顺序 —— 复用 MultiBossTracker 的数据，不维护两份。
--
-- 首选：运行时直接读 MBT 已本地化好的 _G.MultiBossTracker.localizedZones
--       （装了 MBT 就零拷贝拿到全部副本/顺序，中文 key、中文 boss 名，随 MBT 更新自动同步）。
-- 回退：MBT 没装/没加载时，用下面这张同构的小种子表（仅熔火之心做示例）。
--
-- 数据形状沿用 MBT：
--   [中文区域名] = { Encounters = { iStartingFight=, [encID]={A={sNPCID,sTarName,iIcon}, iNextEncounter=} } }
--   或 flat 单 boss：[中文区域名] = { A={sNPCID,sTarName,iIcon} }

local addonName, RPF = ...

RPF.ZonesFallback = {
    ["熔火之心"] = {
        ["Encounters"] = {
            [665] = {
                ["A"] = { sNPCID = "12259", sTarName = "基赫纳斯",   iIcon = 254652 },
                ["B"] = { sNPCID = "11661", sTarName = "烈焰行者",   iIcon = 133932 },
                iNextEncounter = 666,
            },
            [666] = {
                ["A"] = { sNPCID = "12057", sTarName = "加尔",       iIcon = 136024 },
                ["B"] = { sNPCID = "12099", sTarName = "火誓者",     iIcon = 136027 },
                iNextEncounter = 668,
            },
            [668] = {
                ["A"] = { sNPCID = "12056", sTarName = "迦顿男爵",   iIcon = 135790 },
                iNextEncounter = 667,
            },
            [667] = {
                ["A"] = { sNPCID = "12264", sTarName = "沙斯拉尔",   iIcon = 298644 },
            },
        },
    },
    ["玛格曼达洞穴"] = {
        ["Encounters"] = {
            iStartingFight = 663,
            [663] = {
                ["A"] = { sNPCID = "12118", sTarName = "鲁西弗隆",   iIcon = 136133 },
                iNextEncounter = 664,
            },
            [664] = {
                ["A"] = { sNPCID = "11982", sTarName = "玛格曼达",   iIcon = 236191 },
            },
        },
    },
    ["拉格纳罗斯之巢"] = {
        ["A"] = { sNPCID = "11502", sTarName = "拉格纳罗斯", iIcon = 5332198 },
    },
}
