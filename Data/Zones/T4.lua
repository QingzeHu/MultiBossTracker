-- Zone Data: T4 (泰坦怀旧时光 P4 — 十字军的试炼 / 奥妮克希亚 / 祖尔格拉布)
-- WLK 客户端语义下 TOC 原本是 T9，但本服把它和重开的老团本 ZG 一起作为 P4 开放。
-- 文件名跟随服务器 phase 而非客户端 tier。
local addonName, MBT = ...

local bIsHorde = (UnitFactionGroup("player") == "Horde")
local tZonesData = {}
tZonesData.sName = "T4"
tZonesData.tBlacklistKey = "tT4"
tZonesData.tZones = {
    -- 十字军的试炼 -------------------------------------------------------
    ["Trial of the Crusader"] = {
        ["Encounters"] = {
            iStartingFight = 629,
            [629] = { -- 北裂境野兽群 (戈莫克 → 酸喉/恐鳞 → 冰吼)
                ["A"] = { sNPCID = "34796", sTarName = "Gormok the Impaler", iIcon = 236697, tEnabledOptions = {"bBeastsFight","bGormok"} },     -- 穿刺者戈莫克
                ["B"] = { sNPCID = "35144", sTarName = "Acidmaw",            iIcon = 134437, tEnabledOptions = {"bBeastsFight","bAcidmaw"} },    -- 酸喉
                ["C"] = { sNPCID = "34799", sTarName = "Dreadscale",         iIcon = 236197, tEnabledOptions = {"bBeastsFight","bDreadscale"} }, -- 恐鳞
                ["D"] = { sNPCID = "34797", sTarName = "Icehowl",            iIcon = 132189, tEnabledOptions = {"bBeastsFight","bIcehowl"} },    -- 冰吼
                ["E"] = { sNPCID = "34800", sTarName = "Snobold Vassal",     iIcon = 134168, tEnabledOptions = {"bBeastsFight","bSnobold"} },    -- 狗头人奴隶 (戈莫克身上跳下来的小怪)
                iNextEncounter = 633,
            },
            [633] = { -- 加拉克苏斯大王 (魔王召唤)
                ["A"] = { sNPCID = "34780", sTarName = "Lord Jaraxxus",     iIcon = 136172, tEnabledOptions = {"bJaraxxusFight","bJaraxxus"} },        -- 加拉克苏斯大王 (BOSS 本体)
                ["B"] = { sNPCID = "34825", sTarName = "Nether Portal",     iIcon = 237560, tEnabledOptions = {"bJaraxxusFight","bNetherPortal"} },   -- 虚空传送门 (召小鬼的门，要打掉)
                ["C"] = { sNPCID = "34813", sTarName = "Infernal Volcano",  iIcon = 135830, tEnabledOptions = {"bJaraxxusFight","bInfernalVolcano"} },-- 地狱火山 (召地狱火的小怪)
                ["D"] = { sNPCID = "34826", sTarName = "Mistress of Pain",  iIcon = 136220, tEnabledOptions = {"bJaraxxusFight","bMistressOfPain"} }, -- 痛苦女王 (魅魔小 boss)
                iNextEncounter = 637,
            },
            [637] = { -- 阵营冠军赛 (8 人 vs 8 人，部落/联盟阵容互换；下面 A-N 14 个职业代表都会随机抽出现)
                ["A"] = { sNPCID = bIsHorde and "34463" or "34455", sTarName = bIsHorde and "Shaabad" or "Broln Stouthorn",                         iIcon = 136051, tEnabledOptions = {"bChampionsFight","bChampionsEnh"} },     -- 增强萨满 (部落:沙拜德 / 联盟:布罗恩·粗角)
                ["B"] = { sNPCID = bIsHorde and "34466" or "34447", sTarName = bIsHorde and "Anthar Forgemender" or "Caiphus the Stern",           iIcon = 135987, tEnabledOptions = {"bChampionsFight","bChampionsDisc"} },    -- 戒律牧师 (部落:安塔尔·缮炉者 / 联盟:严肃的凯普斯)
                ["C"] = { sNPCID = bIsHorde and "34469" or "34459", sTarName = bIsHorde and "Melador Valestrider" or "Erin Misthoof",              iIcon = 136041, tEnabledOptions = {"bChampionsFight","bChampionsRDruid"} },  -- 恢复德鲁伊 (部落:麦拉多·深谷游者 / 联盟:伊林·雾蹄)
                ["D"] = { sNPCID = bIsHorde and "34470" or "34444", sTarName = bIsHorde and "Saamul" or "Thrakgar",                                iIcon = 136043, tEnabledOptions = {"bChampionsFight","bChampionsRSham"} },   -- 恢复萨满 (部落:萨缪尔 / 联盟:萨卡加尔)
                ["E"] = { sNPCID = bIsHorde and "34472" or "34454", sTarName = bIsHorde and "Irieth Shadowstep" or "Maz'dinah",                    iIcon = 132320, tEnabledOptions = {"bChampionsFight","bChampionsRogue"} },   -- 盗贼 (部落:伊锐丝·影踪 / 联盟:玛兹迪娜)
                ["F"] = { sNPCID = bIsHorde and "34475" or "34453", sTarName = bIsHorde and "Shocuul" or "Narrhok Steelbreaker",                   iIcon = 132355, tEnabledOptions = {"bChampionsFight","bChampionsWar"} },     -- 战士 (部落:索库尔 / 联盟:断钢者纳霍克)
                ["G"] = { sNPCID = bIsHorde and "34467" or "34448", sTarName = bIsHorde and "Alyssia Moonstalker" or "Ruj'kah",                    iIcon = 626000, tEnabledOptions = {"bChampionsFight","bChampionsHunter"} },  -- 猎人 (部落:阿莱希娅·月行者 / 联盟:鲁姬卡)
                ["H"] = { sNPCID = bIsHorde and "34461" or "34458", sTarName = bIsHorde and "Tyrius Duskblade" or "Gorgrim Shadowcleave",          iIcon = 135771, tEnabledOptions = {"bChampionsFight","bChampionsDK"} },      -- 死亡骑士 (部落:泰利乌斯·达斯布雷德 / 联盟:戈瑞姆·影斩)
                ["I"] = { sNPCID = bIsHorde and "34474" or "34450", sTarName = bIsHorde and "Serissa Grimdabbler" or "Harkzog",                    iIcon = 626007, tEnabledOptions = {"bChampionsFight","bChampionsWarlock"} }, -- 术士 (部落:塞瑞莎·术轮 / 联盟:德拉克道格)
                ["J"] = { sNPCID = bIsHorde and "34471" or "34456", sTarName = bIsHorde and "Baelnor Lightbearer" or "Malithas Brightblade",       iIcon = 135873, tEnabledOptions = {"bChampionsFight","bChampionsRet"} },     -- 惩戒骑 (部落:圣光使者巴尔诺 / 联盟:玛里萨斯·辉刃)
                ["K"] = { sNPCID = bIsHorde and "34465" or "34445", sTarName = bIsHorde and "Velanaa" or "Liandra Suncaller",                      iIcon = 135920, tEnabledOptions = {"bChampionsFight","bChampionsHPal"} },    -- 神圣骑 (部落:维兰纳 / 联盟:莉安德拉·唤日者)
                ["L"] = { sNPCID = bIsHorde and "34460" or "34451", sTarName = bIsHorde and "Kavina Grovesong" or "Birana Stormhoof",              iIcon = 236168, tEnabledOptions = {"bChampionsFight","bChampionsMoonkin"} }, -- 平衡德/枭兽 (部落:卡雯娜·林歌 / 联盟:比莱纳·雷蹄)
                ["M"] = { sNPCID = bIsHorde and "34473" or "34441", sTarName = bIsHorde and "Brienna Nightfell" or "Vivienne Blackwhisper",        iIcon = 136207, tEnabledOptions = {"bChampionsFight","bChampionsSP"} },      -- 暗牧 (部落:布瑞娜·沉夜 / 联盟:暗语者维维尼)
                ["N"] = { sNPCID = bIsHorde and "34468" or "34449", sTarName = bIsHorde and "Noozle Whizzlestick" or "Ginselle Blightslinger",     iIcon = 135932, tEnabledOptions = {"bChampionsFight","bChampionsMage"} },    -- 法师 (部落:努兹尔·啸钉 / 联盟:凋零者吉塞尔)
                iNextEncounter = 641,
            },
            [641] = { -- 双子瓦格里 (光明 + 黑暗，颜色机制)
                ["A"] = { sNPCID = "34497", sTarName = "Fjola Lightbane", iIcon = 298674, tEnabledOptions = {"bValkyrTwinsFight","bFjolaLightbane"} }, -- 光明邪使菲奥拉 (白色)
                ["B"] = { sNPCID = "34496", sTarName = "Eydis Darkbane",  iIcon = 237565, tEnabledOptions = {"bValkyrTwinsFight","bEydisDarkbane"} }, -- 黑暗邪使艾蒂丝 (黑色)
            },
        },
    },
    -- 寒冰深渊 (TOC 第 5 个 boss 房间，掉冰窟后) -------------------------
    ["The Icy Depths"] = {
        ["A"] = { sNPCID = "34564", sTarName = "Anub'arak",         iIcon = 298643, tEnabledOptions = {"bTOCAnubFight","bTOCAnub"} },    -- 阿努巴拉克 (蛛魔王)
        ["B"] = { sNPCID = "34607", sTarName = "Nerubian Burrower", iIcon = 134435, tEnabledOptions = {"bTOCAnubFight","bTOCBurrower"} },-- 蛛魔掘地者 (从地里钻出来的小怪)
    },
    -- 奥妮克希亚的巢穴 (本服 P4 暂不开放，等服务器公告后取消注释即可) ---
    -- ["Onyxia's Lair"] = {
    --     ["A"] = { sNPCID = "10184", sTarName = "Onyxia",             iIcon = 134153, tEnabledOptions = {"bOnyxiaFight","bOnyxiaBoss"} }, -- 奥妮克希亚 (黑龙妹妹)
    --     ["B"] = { sNPCID = "36561", sTarName = "Onyxian Lair Guard", iIcon = 236429, tEnabledOptions = {"bOnyxiaFight","bOnyxiaAdd"} },  -- 奥妮克希亚巢穴守卫 (P2 空中阶段地面刷的小龙崽)
    -- },

    -- 祖尔格拉布 ---------------------------------------------------------
    -- 9 个 boss + 疯狂之痕 4 选 1。Vanilla 副本无官方 EJ 编号，ENCOUNTER_END
    -- 大概率不触发；走 Naxx 那套 mouseover 驱动：不设 iStartingFight，
    -- 鼠标悬浮到哪只 boss 就出哪只的框体。整个团本共享 "Zul'Gurub" 主 zone，
    -- vanilla 客户端没给 boss 房间细分 subzone，主 zone 名足够覆盖。
    ["Zul'Gurub"] = {
        ["Encounters"] = {
            [1300] = { -- 高阶祭司耶克里克 (蝙蝠化身)
                ["A"] = { sNPCID = "14517", sTarName = "High Priestess Jeklik",    iIcon = 134301 }, -- 高阶祭司耶克里克 (BOSS)
                ["B"] = { sNPCID = "11368", sTarName = "Bloodseeker Bat",          iIcon = 134437 }, -- 嗜血蝙蝠 (召唤小蝙蝠)
                ["C"] = { sNPCID = "14965", sTarName = "Frenzied Bloodseeker Bat", iIcon = 134437 }, -- 狂乱的嗜血蝙蝠 (狂暴版小蝙蝠)
            },
            [1301] = { -- 高阶祭司温诺希斯 (蛇化身)
                ["A"] = { sNPCID = "14507", sTarName = "High Priest Venoxis", iIcon = 134301 }, -- 高阶祭司温诺希斯 (BOSS)
            },
            [1302] = { -- 高阶祭司玛尔里 (蜘蛛化身)
                ["A"] = { sNPCID = "14510", sTarName = "High Priestess Mar'li", iIcon = 136116 }, -- 高阶祭司玛尔里 (BOSS)
            },
            [1303] = { -- 血领主曼多基尔 (+ 坐骑奥甘)
                ["A"] = { sNPCID = "11382", sTarName = "Bloodlord Mandokir", iIcon = 132212 }, -- 血领主曼多基尔 (BOSS，骑迅猛龙)
                ["B"] = { sNPCID = "14988", sTarName = "Ohgan",              iIcon = 132225 }, -- 奥甘 (曼多基尔的迅猛龙坐骑)
            },
            [1304] = { -- 疯狂之缘：每周服务器 RNG 出 4 选 1
                ["A"] = { sNPCID = "15082", sTarName = "Gri'lek",   iIcon = 132212 }, -- 格里雷克 (碎石巨魔)
                ["B"] = { sNPCID = "15083", sTarName = "Hazza'rah", iIcon = 132212 }, -- 哈扎拉尔 (法师巨魔，召小怪)
                ["C"] = { sNPCID = "15084", sTarName = "Renataki",  iIcon = 132212 }, -- 雷纳塔基 (盗贼巨魔)
                ["D"] = { sNPCID = "15085", sTarName = "Wushoolay", iIcon = 132212 }, -- 乌苏雷 (雷电巨魔)
            },
            [1305] = { -- 高阶祭司塞卡尔 (老虎化身) + 两个狂热者
                ["A"] = { sNPCID = "14509", sTarName = "High Priest Thekal", iIcon = 134301 }, -- 高阶祭司塞卡尔 (BOSS)
                ["B"] = { sNPCID = "11347", sTarName = "Zealot Lor'Khan",    iIcon = 132355 }, -- 狂热者罗尔卡恩 (萨满小弟)
                ["C"] = { sNPCID = "11348", sTarName = "Zealot Zath",        iIcon = 132320 }, -- 狂热者扎斯 (盗贼小弟)
            },
            [1306] = { -- 加兹兰卡 (用大鳗鱼诱饵召唤)
                ["A"] = { sNPCID = "15114", sTarName = "Gahz'ranka", iIcon = 135862 }, -- 加兹兰卡 (大青蛙 boss)
            },
            [1307] = { -- 高阶祭司娅尔罗 (豹化身)
                ["A"] = { sNPCID = "14515", sTarName = "High Priestess Arlokk", iIcon = 132225 }, -- 高阶祭司娅尔罗 (BOSS)
            },
            [1308] = { -- 妖术师金度 + 影像
                ["A"] = { sNPCID = "11380", sTarName = "Jin'do the Hexxer", iIcon = 134301 }, -- 妖术师金度 (BOSS)
                ["B"] = { sNPCID = "14986", sTarName = "Shade of Jin'do",   iIcon = 136045 }, -- 金度的影像 (诅咒目标身上召的影子，要立刻杀)
            },
            [1309] = { -- 哈卡 + 哈卡之子 (用来减毒血印记的小怪)
                ["A"] = { sNPCID = "14834", sTarName = "Hakkar",        iIcon = 134337 }, -- 哈卡 (最终 BOSS，灵魂剥夺者)
                ["B"] = { sNPCID = "11357", sTarName = "Son of Hakkar", iIcon = 132307 }, -- 哈卡之子 (毒蛇小怪，杀掉留绿池减"血之印记"DEBUFF)
            },
        },
    },
}

MBT:RegisterZonesSection(tZonesData)
