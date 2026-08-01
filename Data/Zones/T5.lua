-- Zone Data: T5 (泰坦怀旧时光 P5 — 祖阿曼 / 太阳之井高地)
-- Encounter 编号与 boss 译名取自客户端内置 DungeonEncounter 表（build 3.80.1.68768）；
-- NPCID 为 TBC 原版编号（本服复刻沿用原 ID，缓存中 23863 祖尔金 / 25315 基尔加丹 已证实）。
-- 祖阿曼客户端无任何子区域、太阳之井的子区域不按 boss 划分 —— 两本都按主区域名 +
-- encounter 链驱动，开打前靠名牌/悬浮把 iCurrentEncounter 切到正确房间。
local addonName, MBT = ...

local tZonesData = {}
tZonesData.sName = "T5"
tZonesData.tBlacklistKey = "tT5"
tZonesData.tZones = {
    -- 祖阿曼 (TBC 团本版，本服 25 人泰坦重铸) -----------------------------
    -- 前四个 boss 可乱序开；链条按客户端表顺序排，实际乱序时名牌/悬浮检测会自动纠正。
    ["Zul'Aman"] = {
        ["Encounters"] = {
            iStartingFight = 1189,
            [1189] = { -- 埃基尔松 (雄鹰化身)
                ["A"] = { sNPCID = "23574", sTarName = "Akil'zon",      iIcon = 136050 }, -- 埃基尔松 (BOSS)
                ["B"] = { sNPCID = "24858", sTarName = "Soaring Eagle", iIcon = 626000 }, -- 翱翔的雄鹰 (风暴阶段俯冲的鹰群)
                iNextEncounter = 1190,
            },
            [1190] = { -- 纳洛拉克 (巨熊化身)
                ["A"] = { sNPCID = "23576", sTarName = "Nalorakk", iIcon = 132189 }, -- 纳洛拉克 (BOSS)
                iNextEncounter = 1191,
            },
            [1191] = { -- 加亚莱 (龙鹰化身)
                ["A"] = { sNPCID = "23578", sTarName = "Jan'alai",                   iIcon = 134153 }, -- 加亚莱 (BOSS)
                ["B"] = { sNPCID = "23818", sTarName = "Amani'shi Hatcher",          iIcon = 134168 }, -- 阿曼尼孵化者 (去孵蛋的小怪，优先杀)
                ["C"] = { sNPCID = "23598", sTarName = "Amani Dragonhawk Hatchling", iIcon = 132225 }, -- 阿曼尼龙鹰幼崽 (孵出来的幼龙鹰，AOE)
                iNextEncounter = 1192,
            },
            [1192] = { -- 哈尔拉兹 (山猫化身)
                ["A"] = { sNPCID = "23577", sTarName = "Halazzi",                   iIcon = 132225 }, -- 哈尔拉兹 (BOSS)
                ["B"] = { sNPCID = "24143", sTarName = "Spirit of the Lynx",        iIcon = 136041 }, -- 山猫之灵 (分身阶段的猫灵)
                ["C"] = { sNPCID = "24224", sTarName = "Corrupted Lightning Totem", iIcon = 136051 }, -- 腐化闪电图腾 (放下立刻打掉)
                iNextEncounter = 1193,
            },
            [1193] = { -- 妖术领主玛拉卡斯 (8 个随从每周随机上 4 个，靠名牌/悬浮只显示在场的)
                bDynamicRoster = true,
                ["A"] = { sNPCID = "24239", sTarName = "Hex Lord Malacrass", iIcon = 134301 }, -- 妖术领主玛拉卡斯 (BOSS 本体)
                ["B"] = { sNPCID = "24240", sTarName = "Alyson Antille",     iIcon = 135987 }, -- 阿莱松·安提雷 (血精灵治疗，优先杀/断)
                ["C"] = { sNPCID = "24241", sTarName = "Thurg",              iIcon = 132355 }, -- 索尔格 (食人魔战士)
                ["D"] = { sNPCID = "24242", sTarName = "Slither",            iIcon = 132320 }, -- 滑行者 (蛇形盗贼系)
                ["E"] = { sNPCID = "24243", sTarName = "Lord Raadan",        iIcon = 136172 }, -- 兰尔丹 (龙人)
                ["F"] = { sNPCID = "24244", sTarName = "Gazakroth",          iIcon = 626007 }, -- 卡扎克洛斯 (小鬼术士系)
                ["G"] = { sNPCID = "24245", sTarName = "Fenstalker",         iIcon = 134437 }, -- 沼泽猎手 (沼泽兽)
                ["H"] = { sNPCID = "24246", sTarName = "Darkheart",          iIcon = 136207 }, -- 黑心 (暗影系)
                ["I"] = { sNPCID = "24247", sTarName = "Koragg",             iIcon = 135771 }, -- 库拉格 (死亡骑士系)
                iNextEncounter = 1194,
            },
            [1194] = { -- 祖尔金 (五化身连续切换)
                ["A"] = { sNPCID = "23863", sTarName = "Zul'jin", iIcon = 132212 }, -- 祖尔金 (最终 BOSS)
            },
        },
    },
    -- 太阳之井高地 (本服 25 人泰坦重铸；子区域"幻日广场"/"死亡之痕"统一走主区域名) --
    ["Sunwell Plateau"] = {
        ["Encounters"] = {
            iStartingFight = 724,
            [724] = { -- 卡雷苟斯 (双位面：普通位面龙体 + 灵体位面萨索瓦尔)
                ["A"] = { sNPCID = "24850", sTarName = "Kalecgos",                 iIcon = 134153 }, -- 卡雷苟斯 (蓝龙本体)
                ["B"] = { sNPCID = "24892", sTarName = "Sathrovarr the Corruptor", iIcon = 136172 }, -- 腐蚀者萨索瓦尔 (灵体位面的恶魔，跨位面点击无效属正常)
                iNextEncounter = 725,
            },
            [725] = { -- 布鲁塔卢斯 (打桩)
                ["A"] = { sNPCID = "24882", sTarName = "Brutallus", iIcon = 135790 }, -- 布鲁塔卢斯 (BOSS)
                iNextEncounter = 726,
            },
            [726] = { -- 菲米丝 (空中阶段毒雾复活的骷髅要点杀)
                ["A"] = { sNPCID = "25038", sTarName = "Felmyst",         iIcon = 298670 }, -- 菲米丝 (BOSS)
                ["B"] = { sNPCID = "25268", sTarName = "Unyielding Dead", iIcon = 134435 }, -- 顽强的死尸 (毒雾拉起的骷髅)
                iNextEncounter = 727,
            },
            [727] = { -- 艾瑞达双子 (暗影 + 火焰，血量不共享但要同时倒)
                ["A"] = { sNPCID = "25165", sTarName = "Lady Sacrolash",         iIcon = 237565 }, -- 萨洛拉丝女王 (暗影近战)
                ["B"] = { sNPCID = "25166", sTarName = "Grand Warlock Alythess", iIcon = 298674 }, -- 高阶术士奥蕾塞丝 (火焰施法)
                iNextEncounter = 728,
            },
            [728] = { -- 穆鲁 (P1 两侧门口刷小怪压制，P2 熵魔)
                ["A"] = { sNPCID = "25741", sTarName = "M'uru",                 iIcon = 136006 }, -- 穆鲁 (P1 本体，站桩虚空纳鲁)
                ["B"] = { sNPCID = "25840", sTarName = "Entropius",             iIcon = 136045 }, -- 熵魔 (P2 本体)
                ["C"] = { sNPCID = "25798", sTarName = "Shadowsword Berserker", iIcon = 132355 }, -- 暗誓狂暴者 (门口小怪，点杀)
                ["D"] = { sNPCID = "25799", sTarName = "Shadowsword Fury Mage", iIcon = 135932 }, -- 暗誓怒火法师 (门口小怪，点杀/断)
                ["E"] = { sNPCID = "25772", sTarName = "Void Sentinel",         iIcon = 298643 }, -- 虚空戒卫 (穆鲁召的大元素)
                iNextEncounter = 729,
            },
            [729] = { -- 基尔加丹 (开场先清三只手)
                ["A"] = { sNPCID = "25315", sTarName = "Kil'jaeden",           iIcon = 254652 }, -- 基尔加丹 (最终 BOSS)
                ["B"] = { sNPCID = "25588", sTarName = "Hand of the Deceiver", iIcon = 136207 }, -- 基尔加丹之手 (开场三只，全清才现身)
                ["C"] = { sNPCID = "25708", sTarName = "Sinister Reflection",  iIcon = 136045 }, -- 邪恶镜像 (玩家分身，即时点杀)
                ["D"] = { sNPCID = "25502", sTarName = "Shield Orb",           iIcon = 134157 }, -- 护盾宝珠 (空中绕圈，远程打)
            },
        },
    },
}

MBT:RegisterZonesSection(tZonesData)
