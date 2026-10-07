-- Zone Data: T6 (泰坦怀旧时光 P6 — 奥杜尔)
-- 子区域名取自客户端 AreaTable / WMOAreaTable（build 3.80.2.69874），每个 boss 房都有独立子区域，
-- 走进房间即出框。NPCID 为 WLK 原版编号。
local addonName, MBT = ...

local tZonesData = {}
tZonesData.sName = "T6"
tZonesData.tBlacklistKey = "tT6"
tZonesData.tZones = {
    ["Formation Grounds"] = { -- 烈焰巨兽
        ["A"] = { sNPCID = "33113", sTarName = "Flame Leviathan", iIcon = 254102 }, -- 烈焰巨兽 (BOSS)
    },
    ["The Colossal Forge"] = { -- 掌炉者伊格尼斯
        ["A"] = { sNPCID = "33118", sTarName = "Ignis the Furnace Master", iIcon = 254092 }, -- 掌炉者伊格尼斯 (BOSS)
    },
    ["Razorscale's Aerie"] = { -- 锋鳞
        ["A"] = { sNPCID = "33186", sTarName = "Razorscale", iIcon = 298670 }, -- 锋鳞 (BOSS)
    },
    ["The Scrapyard"] = { -- XT-002拆解者
        ["A"] = { sNPCID = "33293", sTarName = "XT-002 Deconstructor", iIcon = 254104 }, -- XT-002拆解者 (BOSS)
        ["B"] = { sNPCID = "34004", sTarName = "Life Spark",           iIcon = 136050 }, -- 生命火花
        ["C"] = { sNPCID = "33344", sTarName = "XM-024 Pummeller",     iIcon = 132996 }, -- XM-024击打者
    },
    ["The Assembly of Iron"] = { -- 钢铁议会
        ["A"] = { sNPCID = "32857", sTarName = "Stormcaller Brundir", iIcon = 254108 }, -- 唤雷者布隆迪尔
        ["B"] = { sNPCID = "32927", sTarName = "Runemaster Molgeim",  iIcon = 237375 }, -- 符文大师莫尔基姆
        ["C"] = { sNPCID = "32867", sTarName = "Steelbreaker",        iIcon = 254110 }, -- 断钢者
    },
    ["The Celestial Planetarium"] = { -- 观察者奥尔加隆
        ["A"] = { sNPCID = "32871", sTarName = "Algalon the Observer", iIcon = 254087 }, -- 观察者奥尔加隆 (BOSS)
    },
    ["The Shattered Walkway"] = { -- 科隆加恩
        ["A"] = { sNPCID = "32934", sTarName = "Right Arm", iIcon = 236314 }, -- 右臂
        ["B"] = { sNPCID = "32930", sTarName = "Kologarn",  iIcon = 254095 }, -- 科隆加恩 (BOSS)
        ["C"] = { sNPCID = "32933", sTarName = "Left Arm",  iIcon = 136101 }, -- 左臂
    },
    ["The Observation Ring"] = { -- 欧尔莉亚
        ["A"] = { sNPCID = "33515", sTarName = "Auriaya",        iIcon = 254088 }, -- 欧尔莉亚 (BOSS)
        ["B"] = { sNPCID = "34035", sTarName = "Feral Defender", iIcon = 132225 }, -- 野性防御者
    },
    ["The Halls of Winter"] = { -- 霍迪尔
        ["A"] = { sNPCID = "32845", sTarName = "Hodir", iIcon = 254091 }, -- 霍迪尔 (BOSS)
    },
    ["The Clash of Thunder"] = { -- 托里姆
        ["A"] = { sNPCID = "32865", sTarName = "Thorim", iIcon = 298676 }, -- 托里姆 (BOSS)
    },
    ["The Conservatory of Life"] = { -- 弗蕾亚
        ["A"] = { sNPCID = "32916", sTarName = "Snaplasher",           iIcon = 134196 }, -- 迅疾鞭笞者
        ["B"] = { sNPCID = "32919", sTarName = "Storm Lasher",         iIcon = 135990 }, -- 风暴鞭笞者
        ["C"] = { sNPCID = "33202", sTarName = "Ancient Water Spirit", iIcon = 135862 }, -- 古代水之精魂
        ["D"] = { sNPCID = "32906", sTarName = "Freya",                iIcon = 254089 }, -- 弗蕾亚 (BOSS)
    },
    ["The Spark of Imagination"] = { -- 米米尔隆
        ["A"] = { sNPCID = "33670", sTarName = "Aerial Command Unit", iIcon = 254097 }, -- 空中指挥单位
        ["B"] = { sNPCID = "33651", sTarName = "VX-001",              iIcon = 236221 }, -- VX-001
        ["C"] = { sNPCID = "33432", sTarName = "Leviathan Mk II",     iIcon = 252186 }, -- 巨兽二型
        ["D"] = { sNPCID = "34057", sTarName = "Assault Bot",         iIcon = 132996 }, -- 突击机器人
    },
    ["The Descent into Madness"] = { -- 维扎克斯将军
        ["A"] = { sNPCID = "33271", sTarName = "General Vezax",   iIcon = 254090 }, -- 维扎克斯将军 (BOSS)
        ["B"] = { sNPCID = "33524", sTarName = "Saronite Animus", iIcon = 135862 }, -- 萨隆邪铁畸体
    },
    ["The Prison of Yogg-Saron"] = { -- 尤格-萨隆
        ["A"] = { sNPCID = "33288", sTarName = "Yogg-Saron",         iIcon = 254105 }, -- 尤格-萨隆 (BOSS)
        ["B"] = { sNPCID = "33966", sTarName = "Crusher Tentacle",   iIcon = 133574 }, -- 重压触须
        ["C"] = { sNPCID = "33985", sTarName = "Corruptor Tentacle", iIcon = 237521 }, -- 腐蚀触须
    },
}

MBT:RegisterZonesSection(tZonesData)
