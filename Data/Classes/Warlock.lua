-- Class Data: Warlock
local addonName, MBT = ...

local tAuraData = {}

tAuraData.tDotOrderIndices = {
    [1]  = "None",
    [2]  = "Corruption",
    [3]  = "Haunt",
    [4]  = "Curse of Agony",
    [5]  = "Curse of Doom",
    [6]  = "Unstable Affliction",
    [7]  = "Shadow Embrace",
    [8]  = "Immolation",
    [9]  = "Seed of Corruption",
    [10] = "Ember Brand",
    [11] = "Shadow Brand",
}

tAuraData.tDotAuras = {
    [172]   = "Corruption", [6222]  = "Corruption", [6223]  = "Corruption", [7648]  = "Corruption",
    [11671] = "Corruption", [11672] = "Corruption", [25311] = "Corruption", [27216] = "Corruption",
    [47812] = "Corruption", [47813] = "Corruption",
    [48181] = "Haunt", [59161] = "Haunt", [59163] = "Haunt", [59164] = "Haunt",
    [980] = "Curse of Agony", [1014] = "Curse of Agony", [6217] = "Curse of Agony",
    [11711] = "Curse of Agony", [11712] = "Curse of Agony", [11713] = "Curse of Agony",
    [27218] = "Curse of Agony", [47863] = "Curse of Agony", [47864] = "Curse of Agony",
    [603] = "Curse of Doom", [30910] = "Curse of Doom", [47867] = "Curse of Doom",
    [30108] = "Unstable Affliction", [30404] = "Unstable Affliction", [30405] = "Unstable Affliction",
    [47841] = "Unstable Affliction", [47843] = "Unstable Affliction",
    [32386] = "Shadow Embrace", [32388] = "Shadow Embrace", [32389] = "Shadow Embrace",
    [32390] = "Shadow Embrace", [32391] = "Shadow Embrace",
    [348] = "Immolation", [707] = "Immolation", [1094] = "Immolation", [2941] = "Immolation",
    [11665] = "Immolation", [11667] = "Immolation", [11668] = "Immolation",
    [25309] = "Immolation", [27215] = "Immolation", [47810] = "Immolation", [47811] = "Immolation",
    [27243] = "Seed of Corruption", [47835] = "Seed of Corruption", [47836] = "Seed of Corruption",
    [1120] = "Drain Soul", [8288] = "Drain Soul", [8289] = "Drain Soul",
    [11675] = "Drain Soul", [27217] = "Drain Soul", [47855] = "Drain Soul",
    [689] = "Drain Life", [699] = "Drain Life", [709] = "Drain Life",
    [7651] = "Drain Life", [11699] = "Drain Life", [11700] = "Drain Life",
    [27219] = "Drain Life", [27220] = "Drain Life", [47857] = "Drain Life",
    [1490] = "Curse of the Elements", [11721] = "Curse of the Elements",
    [11722] = "Curse of the Elements", [27228] = "Curse of the Elements",
    [47865] = "Curse of the Elements",
    -- 自定义印记 debuff（私服扩展）
    [1295144] = "Ember Brand",
    [1295140] = "Shadow Brand",
}

tAuraData.tDamageTriggers = {
    [686]=  "Shadow Bolt", [695]=  "Shadow Bolt", [705]=  "Shadow Bolt",
    [1088]= "Shadow Bolt", [1106]= "Shadow Bolt", [7641]= "Shadow Bolt",
    [11659]="Shadow Bolt", [11660]="Shadow Bolt", [11661]="Shadow Bolt",
    [25307]="Shadow Bolt", [27209]="Shadow Bolt", [47808]="Shadow Bolt", [47809]="Shadow Bolt",
    [2912]= "Starfire", [8949]= "Starfire", [8950]= "Starfire", [8951]= "Starfire",
    [9875]= "Starfire", [9876]= "Starfire", [25298]="Starfire", [26986]="Starfire",
    [48464]="Starfire", [48465]="Starfire",
}

tAuraData.tDamageInfos = {
    ["Shadow Bolt"] = {
        tRefreshAura = {
            tRefreshTalent = { iRow = 1, iIndex = 24 },  -- WotLK Pandemic; talent API differs in MoP
            tAuras = { "Corruption" },
        },
    },
}

tAuraData.tSpellsInfos = {
    ["Corruption"] = {
        iDuration = 18, sName = "Corruption", iIcon = 136118,
        iColorR = 0.213, iColorG = 0.267, iColorB = 0.945,
        bAffectedByHaste = true,
    },
    ["Haunt"] = {
        iDuration = 12, sName = "Haunt", iIcon = 236298,
        iColorR = 0.000, iColorG = 0.757, iColorB = 1.000,
        bRemoveFromOtherFrames = true,
        tRefreshAura = {
            tRefreshTalent = { iRow = 1, iIndex = 24 },
            tAuras = { "Corruption" },
        },
    },
    ["Curse of Agony"] = {
        iDuration = 24, sName = "Curse of Agony", sGroup = "Curses", iIcon = 136139,
        iColorR = 0.529, iColorG = 0.529, iColorB = 0.929,
    },
    ["Curse of the Elements"] = {
        iDuration = 300, sName = "Curse of the Elements", sGroup = "Curses", iIcon = 136130,
        iColorR = 0.329, iColorG = 0.000, iColorB = 0.654,
    },
    ["Curse of Doom"] = {
        iDuration = 60, sName = "Curse of Doom", sGroup = "Curses", iIcon = 136122,
        iColorR = 0.329, iColorG = 0.000, iColorB = 0.654,
    },
    ["Shadow Embrace"] = {
        iDuration = 12, sName = "Shadow Embrace", iIcon = 136198,
        iColorR = 0.329, iColorG = 0.315, iColorB = 0.854,
    },
    ["Unstable Affliction"] = {
        iDuration = 15, sName = "Unstable Affliction", sGroup = "Immolation", iIcon = 136228,
        iColorR = 1.000, iColorG = 0.647, iColorB = 0.031,
    },
    ["Immolation"] = {
        iDuration = 15, sName = "Immolation", sGroup = "Immolation", iIcon = 135817,
        iColorR = 1.000, iColorG = 0.647, iColorB = 0.031,
        iTalentedDuration = {
            iTalentPage = 2, iTalentID = 16,
            tIncDurations = { [1]=3, [2]=6, [3]=9 },
        },
    },
    ["Seed of Corruption"] = {
        iDuration = 18, sName = "Seed of Corruption", sGroup = "Corruption", iIcon = 136193,
        iColorR = 0.321, iColorG = 0.047, iColorB = 0.331,
    },
    ["Drain Soul"] = {
        tRefreshAura = {
            tRefreshTalent = { iRow = 1, iIndex = 24 },
            tAuras = { "Corruption" },
        },
    },
    ["Drain Life"] = {
        tRefreshAura = {
            tRefreshTalent = { iRow = 1, iIndex = 24 },
            tAuras = { "Corruption" },
        },
    },
    ["Ember Brand"] = {
        iDuration = 12, sName = "Ember Brand", iIcon = 135265,
        iColorR = 0.980, iColorG = 0.350, iColorB = 0.100,
        iGlowAtStacks = 6,    -- 单印记满 6 → DoT 图标上轻微旋转火花（信息性）
    },
    ["Shadow Brand"] = {
        iDuration = 12, sName = "Shadow Brand", iIcon = 425951,
        iColorR = 0.350, iColorG = 0.050, iColorB = 0.650,
        iGlowAtStacks = 6,
    },
}

-- Combo glow 配置：多个 DoT 同时满足条件时，整个 boss 框体亮起特效
-- 用途：双 6 层印记 = 终结技窗口，给玩家一个"现在可以放！"的强信号
tAuraData.tComboGlows = {
    {
        sName       = "WarlockBrandFinisher",
        tSpells     = {"Ember Brand", "Shadow Brand"},
        iAtStacks   = 6,
        sStyle      = "pixel",        -- pixel | autocast | button
        tColor      = {1.0, 0.6, 0.1, 1.0},   -- 暖橙 → 紧迫感
        fFrequency  = 0.5,            -- 每秒 0.5 周期 = 2 秒一圈，醒目但不晕
        iThickness  = 2,
        iDots       = 8,              -- 8 颗像素点沿框体周长流动
    },
}

tAuraData.fExecuteRange = 0.25
tAuraData.iRangeCheckSpellID = 686    -- 暗影箭 40y

MBT:RegisterClassData("WARLOCK", tAuraData)
