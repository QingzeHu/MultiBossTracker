-- Zone Data: Testing zones (training dummies)
local addonName, MBT = ...

local tZonesData = {}
tZonesData.sName = "Testing"
tZonesData.tBlacklistKey = "tTesting"  -- look up MBT.db.profile.tNPCBlackList.tTesting at use time
tZonesData.tZones = {
    ["Forlorn Woods"] = {
        ["A"] = { sNPCID = "33422", sTarName = "Unbound Seer",          iIcon = 132765 },
        ["B"] = { sNPCID = "31228", sTarName = "Heroic Training Dummy", iIcon = 132765 },
    },
    ["Borean Tundra"] = {
        ["A"] = { sNPCID = "25611", sTarName = "Heroic Training Dummy", iIcon = 132765 },
        ["B"] = { sNPCID = "25600", sTarName = "Heroic Training Dummy", iIcon = 132765 },
    },
    ["Valley of Honor"] = {
        ["A"] = { sNPCID = "31146", sTarName = "Heroic Training Dummy",      iIcon = 132765,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyHeroic"} },
        ["B"] = { sNPCID = "31144", sTarName = "Grandmaster's Training Dummy", iIcon = 132177,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyGrandmaster"} },
        ["C"] = { sNPCID = "32666", sTarName = "Expert's Training Dummy",     iIcon = 134152,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyExpert"} },
    },
    ["水晶大厅"] = {
        ["A"] = { sNPCID = "31146", sTarName = "Heroic Training Dummy",      iIcon = 132765,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyHeroic"} },
        ["B"] = { sNPCID = "31144", sTarName = "Grandmaster's Training Dummy", iIcon = 132177,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyGrandmaster"} },
        ["C"] = { sNPCID = "32666", sTarName = "Expert's Training Dummy",     iIcon = 134152,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyExpert"} },
    },
    ["The Great Forge"] = {
        ["A"] = { sNPCID = "31146", sTarName = "Heroic Training Dummy",      iIcon = 132765,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyHeroic"} },
        ["B"] = { sNPCID = "31144", sTarName = "Grandmaster's Training Dummy", iIcon = 132177,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyExpert"} },
        ["C"] = { sNPCID = "32666", sTarName = "Expert's Training Dummy",     iIcon = 134152,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyExpert"} },
    },
    -- Silvermoon City (银月城) — added for Blood Elves
    -- 训练假人在杀戮街、远行者广场都有；NPCID 跨城共享，用通用的一组
    ["杀戮街"] = {
        ["A"] = { sNPCID = "31146", sTarName = "英雄训练假人",       iIcon = 132765,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyHeroic"} },
        ["B"] = { sNPCID = "31144", sTarName = "宗师的训练假人",     iIcon = 132177,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyGrandmaster"} },
        ["C"] = { sNPCID = "32666", sTarName = "专家的训练假人",     iIcon = 134152,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyExpert"} },
    },
    ["远行者广场"] = {
        ["A"] = { sNPCID = "31146", sTarName = "英雄训练假人",       iIcon = 132765,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyHeroic"} },
        ["B"] = { sNPCID = "31144", sTarName = "宗师的训练假人",     iIcon = 132177,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyGrandmaster"} },
        ["C"] = { sNPCID = "32666", sTarName = "专家的训练假人",     iIcon = 134152,
                  tEnabledOptions = {"bTargetDummiesFight","bTargetDummyExpert"} },
    },
    ["Murder Row"] = {
        ["A"] = { sNPCID = "31146", sTarName = "Heroic Training Dummy",      iIcon = 132765 },
        ["B"] = { sNPCID = "31144", sTarName = "Grandmaster's Training Dummy", iIcon = 132177 },
        ["C"] = { sNPCID = "32666", sTarName = "Expert's Training Dummy",     iIcon = 134152 },
    },
    -- 暴风城 (Stormwind) — Old Town has dummies
    ["旧城区"] = {
        ["A"] = { sNPCID = "31146", sTarName = "英雄训练假人",       iIcon = 132765 },
        ["B"] = { sNPCID = "31144", sTarName = "宗师的训练假人",     iIcon = 132177 },
        ["C"] = { sNPCID = "32666", sTarName = "专家的训练假人",     iIcon = 134152 },
    },
    ["Old Town"] = {
        ["A"] = { sNPCID = "31146", sTarName = "Heroic Training Dummy",      iIcon = 132765 },
        ["B"] = { sNPCID = "31144", sTarName = "Grandmaster's Training Dummy", iIcon = 132177 },
        ["C"] = { sNPCID = "32666", sTarName = "Expert's Training Dummy",     iIcon = 134152 },
    },
    -- 雷霆崖 (Thunder Bluff)
    ["艾森娜高地"] = {
        ["A"] = { sNPCID = "31146", sTarName = "英雄训练假人",       iIcon = 132765 },
        ["B"] = { sNPCID = "31144", sTarName = "宗师的训练假人",     iIcon = 132177 },
        ["C"] = { sNPCID = "32666", sTarName = "专家的训练假人",     iIcon = 134152 },
    },
    ["Elder Rise"] = {
        ["A"] = { sNPCID = "31146", sTarName = "Heroic Training Dummy",      iIcon = 132765 },
        ["B"] = { sNPCID = "31144", sTarName = "Grandmaster's Training Dummy", iIcon = 132177 },
        ["C"] = { sNPCID = "32666", sTarName = "Expert's Training Dummy",     iIcon = 134152 },
    },
    -- 达纳苏斯 (Darnassus)
    ["战士露台"] = {
        ["A"] = { sNPCID = "31146", sTarName = "英雄训练假人",       iIcon = 132765 },
        ["B"] = { sNPCID = "31144", sTarName = "宗师的训练假人",     iIcon = 132177 },
        ["C"] = { sNPCID = "32666", sTarName = "专家的训练假人",     iIcon = 134152 },
    },
    ["Warrior's Terrace"] = {
        ["A"] = { sNPCID = "31146", sTarName = "Heroic Training Dummy",      iIcon = 132765 },
        ["B"] = { sNPCID = "31144", sTarName = "Grandmaster's Training Dummy", iIcon = 132177 },
        ["C"] = { sNPCID = "32666", sTarName = "Expert's Training Dummy",     iIcon = 134152 },
    },
}

MBT:RegisterZonesSection(tZonesData)
