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
    [12] = "Shadowburn",
    [13] = "Conflagrate",
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
    -- 自定义印记 debuff
    [1295144] = "Ember Brand",
    [1295140] = "Shadow Brand",
    [29341]   = "Shadowburn",
    [17962]   = "Conflagrate",
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

-- iCastSpellID（可选字段）：DoT 点击模式用来生成 `/cast [@boss] <spell>` 宏
--   有 ID = 点击该 slot 释放该咒语（用 GetSpellInfo 转本地化名字进宏）
--   nil  = 该 DoT 没有直接对应的释放咒语（如 Shadow Embrace 由暗影箭附带）→ DoT 点击模式下 slot 隐藏
--   未来想 map 间接 DoT 到某个咒语（如 Shadow Embrace → Shadow Bolt），改这个 ID 即可
tAuraData.tSpellsInfos = {
    ["Corruption"] = {
        iDuration = 18, sName = "Corruption", iIcon = 136118,
        iCastSpellID = 47813,
        iColorR = 0.213, iColorG = 0.267, iColorB = 0.945,
        bAffectedByHaste = true,
    },
    ["Haunt"] = {
        iDuration = 12, sName = "Haunt", iIcon = 236298,
        iCastSpellID = 59164,
        iColorR = 0.000, iColorG = 0.757, iColorB = 1.000,
        bRemoveFromOtherFrames = true,
        tRefreshAura = {
            tRefreshTalent = { iRow = 1, iIndex = 24 },
            tAuras = { "Corruption" },
        },
    },
    ["Curse of Agony"] = {
        iDuration = 24, sName = "Curse of Agony", sGroup = "Curses", iIcon = 136139,
        iCastSpellID = 47864,
        iColorR = 0.529, iColorG = 0.529, iColorB = 0.929,
    },
    ["Curse of the Elements"] = {
        iDuration = 300, sName = "Curse of the Elements", sGroup = "Curses", iIcon = 136130,
        iCastSpellID = 47865,
        iColorR = 0.329, iColorG = 0.000, iColorB = 0.654,
    },
    ["Curse of Doom"] = {
        iDuration = 60, sName = "Curse of Doom", sGroup = "Curses", iIcon = 136122,
        iCastSpellID = 47867,
        iColorR = 0.329, iColorG = 0.000, iColorB = 0.654,
    },
    ["Shadow Embrace"] = {
        iDuration = 12, sName = "Shadow Embrace", iIcon = 136198,
        -- Shadow Embrace 是暗影箭/鬼影缠身附带的 debuff，没直接释放咒语
        -- map 到暗影箭（686）—— 点击该 slot = 放一发暗影箭顺带刷新 Shadow Embrace
        iCastSpellID = 47809,
        iColorR = 0.329, iColorG = 0.315, iColorB = 0.854,
    },
    ["Unstable Affliction"] = {
        iDuration = 15, sName = "Unstable Affliction", sGroup = "Immolation", iIcon = 136228,
        iCastSpellID = 47843,
        iColorR = 1.000, iColorG = 0.647, iColorB = 0.031,
    },
    ["Immolation"] = {
        iDuration = 15, sName = "Immolation", sGroup = "Immolation", iIcon = 135817,
        iCastSpellID = 47811,   -- 献祭（Immolate）—— cast 咒语名跟 debuff 名不同：cast = "献祭" / debuff = "灼烧"
        iColorR = 1.000, iColorG = 0.647, iColorB = 0.031,
        iTalentedDuration = {
            iTalentPage = 2, iTalentID = 16,
            tIncDurations = { [1]=3, [2]=6, [3]=9 },
        },
    },
    ["Seed of Corruption"] = {
        iDuration = 18, sName = "Seed of Corruption", sGroup = "Corruption", iIcon = 136193,
        iCastSpellID = 47836,
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
        iCastSpellID = 47838,   -- 烧尽 —— 点击 = 放一发烧尽叠余烬印记
        iColorR = 0.980, iColorG = 0.350, iColorB = 0.100,
        iGlowAtStacks = 6,    -- 单印记满 6 → DoT 图标上轻微旋转火花（信息性）
    },
    ["Shadow Brand"] = {
        iDuration = 12, sName = "Shadow Brand", iIcon = 425951,
        iCastSpellID = 47809,     -- map 到暗影箭 —— 点击 = 放一发暗影箭刷新暗影印记
        iColorR = 0.350, iColorG = 0.050, iColorB = 0.650,
        iGlowAtStacks = 6,
    },
    ["Shadowburn"] = {
        iDuration = 5, sName = "Shadowburn", iIcon = 136191,
        iCastSpellID = 29341,
        iColorR = 0.650, iColorG = 0.100, iColorB = 0.500,
    },
    ["Conflagrate"] = {
        iDuration = 10, sName = "Conflagrate", iIcon = 135807,
        iCastSpellID = 17962,
        iColorR = 0.950, iColorG = 0.450, iColorB = 0.150,
    },
}

-- 印记层数指示器：boss 框底部一行 N 格"双色叠层"pip，配左侧 X/N 文字
-- 用途：术士两个印记的层数 corner number 在战斗中扫不到，单独画一行"连击点"风格指示器
-- 数据驱动 —— 任何职业加同样的 tStackPips 即可获得这条 UI
tAuraData.tStackPips = {
    tSpells     = { "Ember Brand", "Shadow Brand" },  -- 顺序 = 每格上半 / 下半的颜色归属
    tColors     = {
        { 0.980, 0.350, 0.100 },   -- 余烬橙 #FA591A → 每格上半段
        { 0.350, 0.050, 0.650 },   -- 暗影紫 #590DA6 → 每格下半段
    },
    iMaxStacks  = 6,
    sTextFormat = "%d/%d",         -- 左侧两个数字格式：余烬/max + 暗影/max
    -- 只有毁灭天赋才显示这条 UI；其它天赋下 boss 框退回原始形态、不占空间
    -- 标识符：毁灭专属 talent 赋予的"混沌流星" (技能 ID 1295386)
    -- 选择技能而不是 talent 点：talent API 返回结构异常（name 是数字串、pts 空），
    -- 但 IsPlayerSpell 工作正常 —— talent 选/不选会立刻反映到技能学习状态
    -- 用户也可以在 DoT 黑名单 → 术士 → "隐藏印记层数指示条" 强制关闭这条 UI
    fnEnabled = function()
        if MBT.db and MBT.db.profile and MBT.db.profile.bHideBrandPips then return false end
        if IsPlayerSpell and IsPlayerSpell(1295386) then return true end
        return false
    end,
}

-- 引导技能条配置：在 boss 框底部画一条带 tick 分割的引导进度条
-- 当前用法：痛苦术士的 Drain Soul (47855) —— 跳数固定 5 跳，4 条分隔线在 20/40/60/80%
-- 额外 Haunt 续断红线：算出"该断了去续 Haunt"的位置（公式来自 Fojji 的 WA）
tAuraData.tChannelBar = {
    iSpellID       = 47855,           -- Drain Soul
    iTickCount     = 5,               -- 4 条固定分隔线
    -- 进度条颜色（偏蓝的亮紫，暗副本下也清晰）和文字颜色（淡黄）
    tBarColor      = { 0.45, 0.30, 0.95, 1.0 },   -- ~#734DF2
    tDamageColor   = { 1.00, 1.00, 0.60, 1.0 },
    -- Haunt 续断标记
    iHauntSpellID  = 48181,           -- 查询 target 上自己的 Haunt debuff 剩余时间用
    iHasteRefSpell = 6215,            -- Fear (基础 1.5s 施法) —— 用它的当前施法时间反推急速倍率
    fRangeEstimate = 30,              -- target 距离估算（yd）—— 公式：travel = 0.058 * range

    -- Snapshot DPS delta（基于 Fojji WA 的 WotLK 痛苦术公式）：
    -- 引导开始时锁定当前法强对应的"基线 DPS"，运行中持续对比"当前 DPS"
    --   +delta（绿）= proc 触发了 / SP 涨了 → 当前 channel 没吃到 → recast 划算
    --   -delta（红）= cast 时锁住的 proc 已过期 → 继续吸（channel 还在吃旧 SP）
    --    delta = 0 = 没变化 → 显示默认 "吸取灵魂" 文字
    -- 数值跟实际 DS 平衡绑定，下面是 WotLK rank 9 原值；游戏版本不同请对应调整
    iShadowSchool   = 6,               -- GetSpellBonusDamage(6) = 暗影系
    fSnapshotBase   = 840,             -- 单跳基础伤害
    fSnapshotCoef   = 2.145,           -- 法强系数（5 跳 × 单跳系数 0.429）
    fSnapshotMult   = 5.7152,          -- 1.15(暗影精通) × 1.12(死亡之拥) × 4(执行期 DS 加成)
                                       -- 默认按执行期算（DS 几乎只在 target HP < 25% 时放）
                                       -- 想算非执行期改成 1.4288（÷4）；WA 也是写死 ×4 这个值
    -- 只有痛苦才显示这条 UI；其它天赋下 boss 框不占空间
    -- 用户也可以在 DoT 黑名单 → 术士 → "隐藏吸取灵魂引导条" 强制关闭
    fnEnabled = function()
        if MBT.db and MBT.db.profile and MBT.db.profile.bHideChannelBar then return false end
        if IsPlayerSpell and IsPlayerSpell(48181) then return true end   -- Haunt（痛苦签名天赋技能）
        return false
    end,
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
