-- Zone Data: T3 (泰坦怀旧时光 P3 — 纳克萨玛斯 / 黑曜石圣殿 / 永恒之眼)
-- Vanilla 时序里 Naxxramas 算 T3，所以文件叫 T3；服务器把它和 OS / EoE 这两个 Wrath 副本打包到 P3 阶段开。
local addonName, MBT = ...

local tZonesData = {}
tZonesData.sName = "T3"
tZonesData.tBlacklistKey = "tT3"
tZonesData.tZones = {
    -- 纳克萨玛斯 ----------------------------------------------------------
    -- 每翼一个 zone（subzone 走翼级名）；翼内 boss 全部作为候选框。
    -- 如果某个 boss 房有更精确的 subzone（如已知的骑士议会厅 / 4HM 房间），
    -- 单独再开一个 zone entry 即可。
    -- 每翼的 boss 房没有独立 subzone（除天启议事厅 / Frostwyrm 之外），
    -- 用毒蛇神殿那套：Encounters 链路 + 不写 iStartingFight
    -- → 进翼时框体不出，鼠标悬浮哪只 boss 才出哪只；ENCOUNTER_END 走 iNextEncounter 自动推进
    ["The Arachnid Quarter"] = {
        ["Encounters"] = {
            [1107] = { ["A"] = { sNPCID = "15956", sTarName = "Anub'Rekhan",          iIcon = 134337 }, iNextEncounter = 1110 },
            [1110] = { ["A"] = { sNPCID = "15953", sTarName = "Grand Widow Faerlina", iIcon = 136033 }, iNextEncounter = 1116 },
            [1116] = { ["A"] = { sNPCID = "15952", sTarName = "Maexxna",              iIcon = 136116 } },
        },
    },
    ["The Plague Quarter"] = {
        ["Encounters"] = {
            [1117] = { ["A"] = { sNPCID = "15954", sTarName = "Noth the Plaguebringer", iIcon = 136181 }, iNextEncounter = 1112 },
            [1112] = { ["A"] = { sNPCID = "15936", sTarName = "Heigan the Unclean",     iIcon = 136127 }, iNextEncounter = 1115 },
            [1115] = { ["A"] = { sNPCID = "16011", sTarName = "Loatheb",                iIcon = 136045 } },
        },
    },
    -- 洛欧塞布房间在 MoP Classic 客户端有独立 subzone（"死灵穹顶"），用单 boss entry 直接命中
    ["Loatheb's Chamber"] = {
        ["A"] = { sNPCID = "16011", sTarName = "Loatheb", iIcon = 136045 },
    },
    ["The Military Quarter"] = {
        ["Encounters"] = {
            [1113] = { ["A"] = { sNPCID = "16061", sTarName = "Instructor Razuvious", iIcon = 132326 }, iNextEncounter = 1109 },
            [1109] = { ["A"] = { sNPCID = "16060", sTarName = "Gothik the Harvester", iIcon = 136093 } },
        },
    },
    -- 4HM 在军事区里有自己的精确 subzone（议事厅）—— 单独保留
    ["The Horsemen's Assembly"] = {
        -- 顺序：女公爵 / 领主 / 男爵 / 爵士
        ["A"] = { sNPCID = "16065", sTarName = "Lady Blaumeux",   iIcon = 136192, tEnabledOptions = {"b4HMFight","bBlaumeux"} },
        ["B"] = { sNPCID = "16064", sTarName = "Thane Korth'azz", iIcon = 135821, tEnabledOptions = {"b4HMFight","bThane"} },
        ["C"] = { sNPCID = "30549", sTarName = "Baron Rivendare", iIcon = 132264, tEnabledOptions = {"b4HMFight","bRivendare"} },
        ["D"] = { sNPCID = "16063", sTarName = "Sir Zeliek",      iIcon = 135972, tEnabledOptions = {"b4HMFight","bZeliek"} },
    },
    ["The Construct Quarter"] = {
        ["Encounters"] = {
            [1118] = { ["A"] = { sNPCID = "16028", sTarName = "Patchwerk", iIcon = 132092 }, iNextEncounter = 1111 },
            [1111] = { ["A"] = { sNPCID = "15931", sTarName = "Grobbulus", iIcon = 132307 }, iNextEncounter = 1108 },
            [1108] = { ["A"] = { sNPCID = "15932", sTarName = "Gluth",     iIcon = 132202 }, iNextEncounter = 1120 },
            [1120] = { ["A"] = { sNPCID = "15928", sTarName = "Thaddius",  iIcon = 136015 } },
        },
    },
    -- Frostwyrm 翼有独立的 boss 房 subzone（萨菲隆之巢 / 克尔苏加德之巢），分开建表
    ["Sapphiron's Lair"] = {
        ["A"] = { sNPCID = "15989", sTarName = "Sapphiron",  iIcon = 135862 },
    },
    ["Kel'Thuzad's Lair"] = {
        ["A"] = { sNPCID = "15990", sTarName = "Kel'Thuzad", iIcon = 136186 },
    },

    -- 黑曜石圣殿 ----------------------------------------------------------
    -- 完整 0/1/2/3 龙难度：萨塔里奥本体 + 3 个龙小弟（开龙难度时同房间）
    ["The Obsidian Sanctum"] = {
        ["A"] = { sNPCID = "28860", sTarName = "Sartharion", iIcon = 134158, tEnabledOptions = {"bSartharionFight","bSartharion"} },
        ["B"] = { sNPCID = "30452", sTarName = "Tenebron",   iIcon = 236473, tEnabledOptions = {"bSartharionFight","bTenebron"} },
        ["C"] = { sNPCID = "30451", sTarName = "Shadron",    iIcon = 236470, tEnabledOptions = {"bSartharionFight","bShadron"} },
        ["D"] = { sNPCID = "30449", sTarName = "Vesperon",   iIcon = 236473, tEnabledOptions = {"bSartharionFight","bVesperon"} },
    },

    -- 永恒之眼 ------------------------------------------------------------
    -- 单房间（螺旋平台），zone key 用副本名即可
    ["The Eye of Eternity"] = {
        ["A"] = { sNPCID = "28859", sTarName = "Malygos", iIcon = 134146, tEnabledOptions = {"bMalygosFight","bMalygos"} },
    },
}

MBT:RegisterZonesSection(tZonesData)
