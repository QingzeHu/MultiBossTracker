-- Zone Data: T2 (Tempest Keep + Serpentshrine Cavern — TBC tier)
local addonName, MBT = ...

local tZonesData = {}
tZonesData.sName = "T2"
tZonesData.tBlacklistKey = "tT2"
tZonesData.tZones = {
    ["熔炉"] = {
        ["Encounters"] = {
            [730] = {
                ["A"] = { sNPCID = "19516", sTarName = "空灵机甲",        iIcon = 134157 },
                iNextEncounter = 731,
            },
            [732] = {
                ["A"] = { sNPCID = "18805", sTarName = "大星术师索兰莉安", iIcon = 134153 },
                iNextEncounter = 732,
            },
        },
    },
    ["日晷台"] = {
        ["Encounters"] = {
            iStartingFight = 731,
            [731] = {
                ["A"] = { sNPCID = "18805", sTarName = "大星术师索兰莉安", iIcon = 134153 },
            },
        },
    },
    ["风暴之桥"] = {
        ["Encounters"] = {
            iStartingFight = 663,
            [663] = {
                ["A"] = { sNPCID = "19622", sTarName = "凯尔萨斯·逐日者",  iIcon = 135787 },
                ["B"] = { sNPCID = "20064", sTarName = "亵渎者萨拉德雷",    iIcon = 135771 },
                ["C"] = { sNPCID = "20060", sTarName = "萨古纳尔男爵",      iIcon = 135736 },
                ["D"] = { sNPCID = "20062", sTarName = "星术师卡波妮娅",    iIcon = 135758 },
                ["E"] = { sNPCID = "20063", sTarName = "首席技师塔隆尼库斯", iIcon = 135743 },
            },
        },
    },
    ["毒蛇神殿"] = {
        ["Encounters"] = {
            [623] = { ["A"] = { sNPCID = "21216", sTarName = "不稳定的海度斯",   iIcon = 135862 }, iNextEncounter = 624 },
            [624] = { ["A"] = { sNPCID = "21217", sTarName = "鱼斯拉",            iIcon = 134331 }, iNextEncounter = 625 },
            [625] = { ["A"] = { sNPCID = "21215", sTarName = "盲眼者莱欧瑟拉斯",  iIcon = 135995 }, iNextEncounter = 626 },
            [626] = {
                ["A"] = { sNPCID = "21214", sTarName = "深水领主卡拉瑟雷斯",  iIcon = 132197 },
                ["B"] = { sNPCID = "21964", sTarName = "深水卫士卡莉蒂丝",    iIcon = 132202 },
                ["C"] = { sNPCID = "21966", sTarName = "深水卫士沙克基斯",    iIcon = 524351 },
                ["D"] = { sNPCID = "21965", sTarName = "深水卫士泰达维斯",    iIcon = 133928 },
                iNextEncounter = 627,
            },
            [627] = { ["A"] = { sNPCID = "21213", sTarName = "莫洛格里·踏潮者", iIcon = 237590 }, iNextEncounter = 628 },
            [628] = {
                ["A"] = { sNPCID = "21212", sTarName = "瓦丝琪",           iIcon = 236422 },
                ["B"] = { sNPCID = "22009", sTarName = "被污染的元素",     iIcon = 136006 },
            },
        },
    },
}

MBT:RegisterZonesSection(tZonesData)
