-- 设置面板（AceConfig 实现）。
-- 结构镜像的 authorOptions 树，但所有 UI 字符串硬编码中文。
local addonName, MBT = ...

local AceConfig         = LibStub("AceConfig-3.0")
local AceConfigDialog   = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDBOptions      = LibStub("AceDBOptions-3.0")
local LSM               = LibStub("LibSharedMedia-3.0", true)  -- 材质选框 / 取色器用；缺库时材质退化为普通下拉

-- 职业组：(配置子键, 显示名)。子键对应 db.tCastingModeBindings/tForceDoTOrder 里的字段名。
local CLASS_GROUPS = {
    { key = "tWarlock",     label = "术士" },
    { key = "tMage",        label = "法师" },
    { key = "tDeathKnight", label = "死亡骑士" },
    { key = "tPriest",      label = "牧师" },
    { key = "tDruid",       label = "德鲁伊" },
    { key = "tShaman",      label = "萨满" },
    { key = "tHunter",      label = "猎人" },
    { key = "tOther",       label = "其他职业（默认）" },
}

local CLICK_BUTTONS = {
    { suffix = "L", label = "左键" },
    { suffix = "R", label = "右键" },
    { suffix = "M", label = "中键" },
    { suffix = "4", label = "侧键 4" },
    { suffix = "5", label = "侧键 5" },
}

local MODIFIERS = {
    { prefix = "t",  label = "无修饰" },
    { prefix = "tS", label = "Shift" },
    { prefix = "tC", label = "Ctrl" },
    { prefix = "tA", label = "Alt" },
}

-- 单个职业的点击施法子表
-- 把所有 zone 数据扁平化遍历：fn(tierName, zoneName, encounterID|nil, slotKey, slotData)
local function walkAllZoneSlots(fn)
    if not MBT.zonesSections then return end
    for tierName, tierData in pairs(MBT.zonesSections) do
        for zoneName, zoneData in pairs(tierData.tZones or {}) do
            if type(zoneData) == "table" then
                if zoneData["Encounters"] then
                    for encID, enc in pairs(zoneData["Encounters"]) do
                        if type(enc) == "table" then
                            for slotKey, slotData in pairs(enc) do
                                if type(slotData) == "table" and slotData.sNPCID then
                                    fn(tierName, zoneName, encID, slotKey, slotData)
                                end
                            end
                        end
                    end
                else
                    for slotKey, slotData in pairs(zoneData) do
                        if type(slotData) == "table" and slotData.sNPCID then
                            fn(tierName, zoneName, nil, slotKey, slotData)
                        end
                    end
                end
            end
        end
    end
end

-- 手工策划的阶段 / 副本 / boss 列表。结构：
--   PHASES = { { key, label, sections = { { header?, bosses = { {name, npcID|npcIDs, adds?} } } } } }
--   adds 是该 boss 的小怪，UI 里会缩进显示
--   npcIDs（复数）= 一个勾选框控制多个 NPCID 同步隐藏（如天启四骑士）
local PHASES = {
    {
        key = "P1", label = "P1 — 熔火之心",
        sections = {
            {
                header = nil,    -- 单副本，不需要表头
                bosses = {
                    { name = "鲁西弗隆",         npcID = "12118",
                      adds = { { name = "烈焰行者护卫", npcID = "12119" } } },
                    { name = "玛格曼达",         npcID = "11982" },
                    { name = "基赫纳斯",         npcID = "12259",
                      adds = { { name = "烈焰行者",     npcID = "11661" } } },
                    { name = "加尔",             npcID = "12057",
                      adds = { { name = "火誓者",       npcID = "12099" } } },
                    { name = "沙斯拉尔",         npcID = "12264" },
                    { name = "迦顿男爵",         npcID = "12056" },
                    { name = "焚化者古雷曼格",   npcID = "11988",
                      adds = { { name = "熔火怒犬",     npcID = "11672" } } },
                    { name = "萨弗隆先驱者",     npcID = "12098",
                      adds = { { name = "烈焰行者祭司", npcID = "11662" } } },
                    { name = "管理者埃克索图斯", npcID = "12018",
                      adds = {
                          { name = "烈焰行者医师", npcID = "11663" },
                          { name = "烈焰行者精英", npcID = "11664" },
                      } },
                    { name = "拉格纳罗斯",       npcID = "11502" },
                },
            },
        },
    },

    {
        key = "P2", label = "P2 — 风暴要塞 / 毒蛇神殿",
        sections = {
            {
                header = "风暴要塞",
                bosses = {
                    { name = "奥",                 npcID = "19514" },
                    { name = "空灵机甲",           npcID = "19516" },
                    { name = "大星术师索兰莉安",   npcID = "18805" },
                    { name = "凯尔萨斯·逐日者",    npcID = "19622",
                      adds = {
                          { name = "亵渎者萨拉德雷",       npcID = "20064" },
                          { name = "萨古纳尔男爵",         npcID = "20060" },
                          { name = "星术师卡波妮娅",       npcID = "20062" },
                          { name = "首席技师塔隆尼库斯",   npcID = "20063" },
                      } },
                },
            },
            {
                header = "毒蛇神殿",
                bosses = {
                    { name = "不稳定的海度斯",         npcID = "21216" },
                    { name = "鱼斯拉",                 npcID = "21217" },
                    { name = "盲眼者莱欧瑟拉斯",       npcID = "21215" },
                    { name = "深水领主卡拉瑟雷斯",     npcID = "21214",
                      adds = {
                          { name = "深水卫士卡莉蒂丝",   npcID = "21964" },
                          { name = "深水卫士沙克基斯",   npcID = "21966" },
                          { name = "深水卫士泰达维斯",   npcID = "21965" },
                      } },
                    { name = "莫洛格里·踏潮者",        npcID = "21213" },
                    { name = "瓦丝琪",                 npcID = "21212",
                      adds = { { name = "被污染的元素", npcID = "22009" } } },
                },
            },
        },
    },

    {
        key = "P3", label = "P3 — 纳克萨玛斯 / 永恒之眼 / 黑曜石圣殿",
        sections = {
            {
                header = "纳克萨玛斯 - 蜘蛛区",
                bosses = {
                    { name = "阿努布雷坎",     npcID = "15956" },
                    { name = "黑女巫法琳娜",   npcID = "15953" },
                    { name = "迈克斯纳",       npcID = "15952" },
                },
            },
            {
                header = "纳克萨玛斯 - 瘟疫区",
                bosses = {
                    { name = "瘟疫使者诺斯",   npcID = "15954" },
                    { name = "肮脏的希尔盖",   npcID = "15936" },
                    { name = "洛欧塞布",       npcID = "16011" },
                },
            },
            {
                header = "纳克萨玛斯 - 军事区",
                bosses = {
                    { name = "教官拉苏维奥斯", npcID = "16061" },
                    { name = "收割者戈提克",   npcID = "16060" },
                    -- 4HM 一个勾选框控制 4 个 NPCID 一起隐藏
                    { name = "天启四骑士",     npcIDs = { "30549", "16064", "16065", "16063" } },
                },
            },
            {
                header = "纳克萨玛斯 - 建筑区",
                bosses = {
                    { name = "帕奇维克",       npcID = "16028" },
                    { name = "格罗布鲁斯",     npcID = "15931" },
                    { name = "格拉斯",         npcID = "15932" },
                    { name = "塔迪乌斯",       npcID = "15928",
                      adds = {
                          { name = "费尔根",   npcID = "15930" },
                          { name = "斯塔拉格", npcID = "15929" },
                      } },
                },
            },
            {
                header = "纳克萨玛斯 - 冰霜巨龙之巢",
                bosses = {
                    { name = "萨菲隆",         npcID = "15989" },
                    { name = "克尔苏加德",     npcID = "15990" },
                },
            },
            {
                header = "黑曜石圣殿",
                bosses = {
                    { name = "萨塔里奥",       npcID = "28860",
                      adds = {
                          { name = "塔纳布隆", npcID = "30452" },
                          { name = "沙德隆",   npcID = "30451" },
                          { name = "瓦斯佩隆", npcID = "30449" },
                      } },
                },
            },
            {
                header = "永恒之眼",
                bosses = {
                    { name = "玛里苟斯",       npcID = "28859" },
                },
            },
        },
    },

    {
        key = "P4", label = "P4 — 十字军的试炼 / 祖尔格拉布",
        sections = {
            {
                header = "十字军的试炼 - 诺森德猛兽",
                bosses = {
                    { name = "穿刺者戈莫克",   npcID = "34796",
                      adds = { { name = "雪地狗头人奴隶", npcID = "34800" } } },
                    { name = "酸喉",           npcID = "35144" },
                    { name = "恐鳞",           npcID = "34799" },
                    { name = "冰吼",           npcID = "34797" },
                },
            },
            {
                header = "十字军的试炼 - 加拉克苏斯大王",
                bosses = {
                    { name = "加拉克苏斯大王", npcID = "34780",
                      adds = {
                          { name = "痛苦女王",     npcID = "34826" },
                          { name = "魔焰地狱火",   npcID = "34815" },
                      } },
                },
            },
            {
                header = "十字军的试炼 - 阵营冠军",
                bosses = {
                    { name = "增强萨满",   npcIDs = { "34463", "34455" } },
                    { name = "戒律牧师",   npcIDs = { "34466", "34447" } },
                    { name = "恢复德鲁伊", npcIDs = { "34469", "34459" } },
                    { name = "恢复萨满",   npcIDs = { "34470", "34444" } },
                    { name = "盗贼",       npcIDs = { "34472", "34454" } },
                    { name = "战士",       npcIDs = { "34475", "34453" } },
                    { name = "猎人",       npcIDs = { "34467", "34448" } },
                    { name = "死亡骑士",   npcIDs = { "34461", "34458" } },
                    { name = "术士",       npcIDs = { "34474", "34450" } },
                    { name = "惩戒骑士",   npcIDs = { "34471", "34456" } },
                    { name = "神圣骑士",   npcIDs = { "34465", "34445" } },
                    { name = "平衡德",     npcIDs = { "34460", "34451" } },
                    { name = "暗影牧师",   npcIDs = { "34473", "34441" } },
                    { name = "法师",       npcIDs = { "34468", "34449" } },
                },
            },
            {
                header = "十字军的试炼 - 瓦格里双子",
                bosses = {
                    { name = "光明邪使菲奥拉", npcID = "34497" },
                    { name = "黑暗邪使艾蒂丝", npcID = "34496" },
                },
            },
            {
                header = "十字军的试炼 - 寒冰深渊",
                bosses = {
                    { name = "阿努巴拉克",     npcID = "34564",
                      adds = { { name = "蛛魔掘地者", npcID = "34607" } } },
                },
            },
            {
                header = "祖尔格拉布",
                bosses = {
                    { name = "高阶祭司耶克里克", npcID = "14517" },
                    { name = "高阶祭司温诺希斯", npcID = "14507" },
                    { name = "高阶祭司玛尔里",   npcID = "14510" },
                    { name = "血领主曼多基尔",   npcID = "11382",
                      adds = { { name = "奥甘", npcID = "14988" } } },
                    -- 疯狂之缘一勾控制 4 个备选巨魔（每周服务器 RNG 出 1 个）
                    { name = "疯狂之缘 (4 选 1: 格里雷克/哈扎拉尔/雷纳塔基/乌苏雷)",
                      npcIDs = { "15082", "15083", "15084", "15085" } },
                    { name = "高阶祭司塞卡尔",   npcID = "14509",
                      adds = {
                          { name = "狂热者洛卡恩", npcID = "11347" },
                          { name = "狂热者扎斯",     npcID = "11348" },
                      } },
                    { name = "加兹兰卡",         npcID = "15114" },
                    { name = "高阶祭司娅尔罗",   npcID = "14515" },
                    { name = "妖术师金度",       npcID = "11380",
                      adds = { { name = "金度的影像", npcID = "14986" } } },
                    { name = "哈卡",             npcID = "14834",
                      adds = { { name = "哈卡之子", npcID = "11357" } } },
                },
            },
        },
    },

    {
        key = "P5", label = "P5 — 祖阿曼 / 太阳之井高地",
        sections = {
            {
                header = "祖阿曼",
                bosses = {
                    { name = "埃基尔松",         npcID = "23574",
                      adds = { { name = "翱翔的雄鹰", npcID = "24858" } } },
                    { name = "纳洛拉克",         npcID = "23576" },
                    { name = "加亚莱",           npcID = "23578",
                      adds = {
                          { name = "阿曼尼孵化者",   npcID = "23818" },
                          { name = "阿曼尼龙鹰幼崽", npcID = "23598" },
                      } },
                    { name = "哈尔拉兹",         npcID = "23577",
                      adds = {
                          { name = "山猫之灵",     npcID = "24143" },
                          { name = "腐化闪电图腾", npcID = "24224" },
                      } },
                    -- 随从 8 选 4（每周服务器随机），靠名牌/悬浮只显示在场的
                    { name = "妖术领主玛拉卡斯", npcID = "24239",
                      adds = {
                          { name = "阿莱松·安提雷", npcID = "24240" },
                          { name = "索尔格",       npcID = "24241" },
                          { name = "滑行者",       npcID = "24242" },
                          { name = "兰尔丹",       npcID = "24243" },
                          { name = "卡扎克洛斯",   npcID = "24244" },
                          { name = "沼泽猎手",     npcID = "24245" },
                          { name = "黑心",         npcID = "24246" },
                          { name = "库拉格",       npcID = "24247" },
                      } },
                    { name = "祖尔金",           npcID = "23863" },
                },
            },
            {
                header = "太阳之井高地",
                bosses = {
                    { name = "卡雷苟斯",         npcID = "24850",
                      adds = { { name = "腐蚀者萨索瓦尔", npcID = "24892" } } },
                    { name = "布鲁塔卢斯",       npcID = "24882" },
                    { name = "菲米丝",           npcID = "25038",
                      adds = { { name = "顽强的死尸", npcID = "25268" } } },
                    { name = "萨洛拉丝女王",     npcID = "25165" },
                    { name = "高阶术士奥蕾塞丝", npcID = "25166" },
                    { name = "穆鲁",             npcID = "25741",
                      adds = {
                          { name = "熵魔",         npcID = "25840" },
                          { name = "暗誓狂暴者",   npcID = "25798" },
                          { name = "暗誓怒火法师", npcID = "25799" },
                          { name = "虚空戒卫",     npcID = "25772" },
                      } },
                    { name = "基尔加丹",         npcID = "25315",
                      adds = {
                          { name = "基尔加丹之手", npcID = "25588" },
                          { name = "邪恶镜像",     npcID = "25708" },
                          { name = "护盾宝珠",     npcID = "25502" },
                      } },
                },
            },
        },
    },
}

-- 一个 boss/小怪条目的 hidden 状态：单个 NPCID 直接查；多 NPCID 全部隐藏才算 true
local function entryIsHidden(entry)
    if entry.npcIDs then
        for _, id in ipairs(entry.npcIDs) do
            if not MBT.db.profile.hiddenNPCs[id] then return false end
        end
        return true
    end
    return MBT.db.profile.hiddenNPCs[entry.npcID] or false
end

local function entrySetHidden(entry, v)
    if entry.npcIDs then
        for _, id in ipairs(entry.npcIDs) do
            MBT.db.profile.hiddenNPCs[id] = v or nil
        end
    else
        MBT.db.profile.hiddenNPCs[entry.npcID] = v or nil
    end
    MBT:FireEvent("MultiBossTracker_ZoneData_LateInit")
end

-- 构建一个 boss / 小怪条目的 toggle args。所有条目视觉一致 —— 层级靠顺序传达。
local function makeEntryToggle(entry, _unused, order)
    return {
        order = order, type = "toggle",
        name = entry.name,
        desc = entry.npcIDs
            and ("NPCID: %s"):format(table.concat(entry.npcIDs, ", "))
            or  ("NPCID: %s"):format(entry.npcID),
        width = "full",
        get = function() return entryIsHidden(entry) end,
        set = function(_, v) entrySetHidden(entry, v) end,
    }
end

local function buildHidePhaseGroup(phase)
    local args = {
        _intro = {
            order = 0, type = "description", fontSize = "medium",
            name = "勾选要隐藏的 boss / 小怪。被隐藏的单位不会显示在框体上。\n常用场景：boss 战里的同名小怪（点击施法对它们无效），勾掉只留 boss 本体。\n",
        },
    }
    local order = 10
    for sIdx, section in ipairs(phase.sections) do
        if section.header then
            args["h" .. sIdx] = {
                order = order, type = "header", name = section.header,
            }
            order = order + 1
        end
        for bIdx, boss in ipairs(section.bosses) do
            args[("b%d_%d"):format(sIdx, bIdx)] = makeEntryToggle(boss, false, order)
            order = order + 1
            if boss.adds then
                for aIdx, add in ipairs(boss.adds) do
                    args[("b%d_%d_a%d"):format(sIdx, bIdx, aIdx)] = makeEntryToggle(add, true, order)
                    order = order + 1
                end
            end
            -- 每个 boss 的"组"（boss + 它的 adds）后面加一条细分隔线，最后一只不加（让 section 表头自然分隔）
            -- 用 description + 暗灰线条；视觉上比 header 弱一档，明确是"组内分隔"而不是"副本分隔"
            if bIdx < #section.bosses then
                args[("d%d_%d"):format(sIdx, bIdx)] = {
                    order = order, type = "description",
                    name = "|cFF444444────────────────────────────────────|r",
                    width = "full",
                    fontSize = "small",
                }
                order = order + 1
            end
        end
    end
    return args
end

-- 反向映射：UI 配置 key (tWarlock) -> 类令牌 (WARLOCK)
local BINDING_KEY_TO_CLASS = {
    tWarlock = "WARLOCK", tMage = "MAGE", tDeathKnight = "DEATHKNIGHT",
    tPriest = "PRIEST",   tDruid = "DRUID", tShaman = "SHAMAN",
    tHunter = "HUNTER",
}

-- 拿 DoT 在 WoW 客户端里的本地化名字（用 GetSpellInfo，取该 DoT 的任一 spellID）
local function getLocalizedDotName(classData, dotName)
    if dotName == "None" then return "（空）" end
    if not classData.tDotAuras then return dotName end
    for spellID, name in pairs(classData.tDotAuras) do
        if name == dotName then
            local localizedName = GetSpellInfo(spellID)
            if localizedName and localizedName ~= "" then return localizedName end
        end
    end
    return dotName    -- 兜底：客户端没认到就用英文 key
end

local function notifyOptionsRefresh()
    LibStub("AceConfigRegistry-3.0"):NotifyChange("MultiBossTracker")
end

-- 单个职业的 "DoT 排序" 子表
local function buildDoTSortGroup(classGroup)
    local classToken = BINDING_KEY_TO_CLASS[classGroup.key]
    local classData = classToken and MBT.classData and MBT.classData[classToken]
    if not classData or not classData.tDotOrderIndices then
        return {
            _info = { order = 0, type = "description",
                name = ("|cFFFFD200%s|r 此职业暂无 DoT 数据。"):format(classGroup.label) },
        }
    end

    -- 准备 select 候选项（值=tDotOrderIndices 的 key，标签=本地化中文名）
    local values = {}
    local maxIdx = 0
    for idx, name in pairs(classData.tDotOrderIndices) do
        values[idx] = getLocalizedDotName(classData, name)
        if idx > maxIdx then maxIdx = idx end
    end

    local function getOrder()
        MBT.db.profile.tForceDoTOrder[classGroup.key] = MBT.db.profile.tForceDoTOrder[classGroup.key] or {}
        return MBT.db.profile.tForceDoTOrder[classGroup.key]
    end

    local args = {
        _intro = {
            order = 0, type = "description", fontSize = "medium",
            name = ("|cFFFFD200%s DoT 排序|r\n\n按你想要的左 → 右顺序排列。槽位 1 显示在最左。可以用下拉重选某个槽位，或者用上移/下移按钮跟相邻槽位互换。改完立刻生效。\n\n|cFFFFFF66提示|r：每个 DoT 只允许出现在一个槽位里。如果你把 X 选到槽位 4 但槽位 1 已经是 X，槽位 1 会自动变空。\n"):format(classGroup.label),
        },
    }
    -- 每行三个 widget 平铺：槽位 N 标签作为 select 的 name；箭头按钮短文字避免被截成 "..."
    for pos = 1, maxIdx do
        args["pos" .. pos .. "_spell"] = {
            order = pos * 10 + 0, type = "select",
            name = ("槽位 %d"):format(pos),
            values = values, width = 1.0,
            get = function() return getOrder()[pos] or 1 end,
            set = function(_, v)
                local order = getOrder()
                -- 防呆：把同一 DoT 重复设置的其他槽位自动清空（"None" 不清，多个空槽位是允许的）
                if v ~= 1 then
                    for otherPos, otherV in pairs(order) do
                        if otherPos ~= pos and otherV == v then
                            order[otherPos] = 1
                        end
                    end
                end
                order[pos] = v
                MBT:FireEvent("MultiBossTracker_BindingsChanged")
                notifyOptionsRefresh()
            end,
        }
        args["pos" .. pos .. "_up"] = {
            order = pos * 10 + 1, type = "execute",
            name = "↑ 上移", width = 0.5,
            disabled = function() return pos == 1 end,
            func = function()
                local o = getOrder()
                o[pos], o[pos-1] = o[pos-1] or 1, o[pos] or 1
                MBT:FireEvent("MultiBossTracker_BindingsChanged")
                notifyOptionsRefresh()
            end,
        }
        args["pos" .. pos .. "_down"] = {
            order = pos * 10 + 2, type = "execute",
            name = "↓ 下移", width = 0.5,
            disabled = function() return pos == maxIdx end,
            func = function()
                local o = getOrder()
                o[pos], o[pos+1] = o[pos+1] or 1, o[pos] or 1
                MBT:FireEvent("MultiBossTracker_BindingsChanged")
                notifyOptionsRefresh()
            end,
        }
    end
    return args
end

-- 取/设单个绑定槽 sSpell 字段的辅助函数
local function bindingGet(classKey, key)
    local b = MBT.db.profile.tCastingModeBindings[classKey]
    return b[key] and b[key].sSpell or ""
end
local function bindingSet(classKey, key, v)
    local b = MBT.db.profile.tCastingModeBindings[classKey]
    b[key] = b[key] or {}
    b[key].sSpell = v or ""
    MBT:FireEvent("MultiBossTracker_BindingsChanged")
    LibStub("AceConfigRegistry-3.0"):NotifyChange("MultiBossTracker")
end

local function buildClassBindingsGroup(classGroup)
    local classKey = classGroup.key
    local args = {
        _intro = {
            order = 0, type = "description", fontSize = "medium",
            name = ("|cFFFFD200%s 点击绑定|r\n\n每个鼠标按键 + 修饰键的组合可设为：选中目标 / 设为焦点 / 命令宠物攻击 / 释放技能（四选一）。\n"):format(classGroup.label),
        },
    }
    local order = 10
    for bIdx, btn in ipairs(CLICK_BUTTONS) do
        -- 大区段：按键名（左键 / 右键 / ...）—— header 横线
        args["h_" .. btn.suffix] = {
            order = order, type = "header", name = btn.label,
        }
        order = order + 1

        for mIdx, mod in ipairs(MODIFIERS) do
            local key = mod.prefix .. btn.suffix .. "Click"

            -- 修饰键标签（无修饰 / Shift / Ctrl / Alt）—— 金色加粗描述
            args["lbl_" .. key] = {
                order = order, type = "description",
                name = ("|cFFFFD200%s|r"):format(mod.label),
                fontSize = "medium",
                width = "full",
            }
            order = order + 1

            args[key .. "_target"] = {
                order = order, type = "toggle", name = "选中目标", width = 0.6,
                get = function() return bindingGet(classKey, key) == "target" end,
                set = function(_, v) bindingSet(classKey, key, v and "target" or "") end,
            }
            order = order + 1
            args[key .. "_focus"] = {
                order = order, type = "toggle", name = "设为焦点", width = 0.6,
                get = function() return bindingGet(classKey, key) == "focus" end,
                set = function(_, v) bindingSet(classKey, key, v and "focus" or "") end,
            }
            order = order + 1
            args[key .. "_pet"] = {
                order = order, type = "toggle", name = "宠物攻击", width = 0.6,
                get = function() return bindingGet(classKey, key) == "petattack" end,
                set = function(_, v) bindingSet(classKey, key, v and "petattack" or "") end,
            }
            order = order + 1
            args[key .. "_spell"] = {
                order = order, type = "input", name = "或施放技能（填技能名，会让上面 3 个自动取消）",
                width = "full",
                get = function()
                    local s = bindingGet(classKey, key)
                    if s == "target" or s == "focus" or s == "petattack" then return "" end
                    return s
                end,
                set = function(_, v) bindingSet(classKey, key, v) end,
            }
            order = order + 1

            -- 修饰键之间加灰色虚线分隔；同 button 下最后一个修饰键不加（让下一个 header 自然分隔）
            if mIdx < #MODIFIERS then
                args["div_" .. key] = {
                    order = order, type = "description",
                    name = "|cFF444444────────────────────────────────────|r",
                    width = "full",
                    fontSize = "small",
                }
                order = order + 1
            end
        end
    end
    return args
end

-- DoT 黑名单清单：按职业分组组织。每条 = { key = 内部英文名, label = 中文显示名 }
-- 加新 DoT 时往对应职业 group 末尾追加即可
local SPELL_BLACKLIST_BY_CLASS = {
    {
        sClass = "术士",
        tSpells = {
            { sKey = "Corruption",          sLabel = "腐蚀术" },
            { sKey = "Curse of Agony",      sLabel = "痛苦诅咒" },
            { sKey = "Curse of Doom",       sLabel = "厄运诅咒" },
            { sKey = "Haunt",               sLabel = "鬼影缠身" },
            { sKey = "Immolation",          sLabel = "灼烧" },
            { sKey = "Seed of Corruption",  sLabel = "腐蚀之种" },
            { sKey = "Shadow Embrace",      sLabel = "暗影之拥" },
            { sKey = "Unstable Affliction", sLabel = "痛苦无常" },
            { sKey = "Ember Brand",         sLabel = "余烬印记" },
            { sKey = "Shadow Brand",        sLabel = "暗影印记" },
            { sKey = "Shadowburn",          sLabel = "暗影灼烧" },
            { sKey = "Conflagrate",         sLabel = "燃烧" },
            { sKey = "Shadow Mastery",      sLabel = "暗影掌握" },
        },
    },
    {
        sClass = "法师",
        tSpells = {
            { sKey = "Living Bomb", sLabel = "活体炸弹" },
        },
    },
    {
        sClass = "牧师",
        tSpells = {
            { sKey = "Shadow Word: Pain", sLabel = "暗言术：痛" },
            { sKey = "Vampiric Touch",    sLabel = "吸血鬼之触" },
            { sKey = "Devouring Plague",  sLabel = "噬灵疫病" },
        },
    },
    {
        sClass = "德鲁伊",
        tSpells = {
            { sKey = "Moonfire",     sLabel = "月火术" },
            { sKey = "Insect Swarm", sLabel = "虫群" },
            { sKey = "Faerie Fire",  sLabel = "精灵之火" },
        },
    },
    {
        sClass = "萨满",
        tSpells = {
            { sKey = "Flame Shock", sLabel = "烈焰震击" },
        },
    },
}

local function BuildOptionsTable()
    local opts = {
        type = "group",
        name = "多目标 Boss 追踪",
        childGroups = "tab",
        args = {
            general = {
                order = 1, type = "group", name = "常规",
                args = {
                    intro = {
                        order = 0, type = "description", fontSize = "medium",
                        name = "|cFFFFD200多目标 Boss 追踪|r — 一屏显示最多 5 个 boss 的血条、DoT、施法条，支持隔空点击施法。\n",
                    },

                    -- ===== 外观 =====
                    hAppearance = { order = 10, type = "header", name = "外观" },
                    iSkin = {
                        order = 11, type = "select", name = "样式", width = 0.5,
                        desc = "极简：单条窄血条 + 右侧 DoT，没有大图标和独立施法条，省屏幕\n标准：左侧头像 + HP + 施法条 overlay + 下方 DoT 行\n\n（切换样式后，下方与之无关的选项会自动隐藏 / 显示）",
                        values = { [1] = "极简", [2] = "标准" },
                        get = function() return MBT.db.profile.iSkin end,
                        set = function(_, v)
                            MBT.db.profile.iSkin = v
                            if MBT.ApplyCompactToAll then MBT.ApplyCompactToAll() end
                            AceConfigRegistry:NotifyChange("MultiBossTracker")
                        end,
                    },
                    iTargetHighlight = {
                        order = 11.1, type = "select", name = "选中高亮", width = 0.5,
                        desc = "当前目标所在 boss 框的高亮方式：\n黄竖线：框体左侧一道黄色竖线（默认）\n蓝色光晕：框体外缘一圈蓝色光晕，更醒目",
                        values = { [1] = "黄竖线", [2] = "蓝色光晕" },
                        get = function() return MBT.db.profile.iTargetHighlight end,
                        set = function(_, v)
                            MBT.db.profile.iTargetHighlight = v
                            -- 立即按新样式刷新当前高亮（藏掉旧样式、显示新样式）
                            if MBT.UpdateTargetHighlight then MBT:UpdateTargetHighlight() end
                        end,
                    },
                    sBarTexture = {
                        order = 11.15, type = "select", name = "血条材质", width = 1.0,
                        dialogControl = LSM and "LSM30_Statusbar" or nil,
                        desc = "Boss 血条的填充材质。",
                        values = function() return (LSM and LSM:HashTable("statusbar")) or { MultiBossTracker = "MultiBossTracker" } end,
                        get = function() return MBT.db.profile.sBarTexture end,
                        set = function(_, v)
                            MBT.db.profile.sBarTexture = v
                            if MBT.UpdateBarTexture then MBT:UpdateBarTexture() end
                        end,
                    },
                    cBarColor = {
                        order = 11.16, type = "color", name = "血条颜色", width = 0.5,
                        hasAlpha = false,
                        desc = "Boss 血条的填充颜色。",
                        get = function()
                            local c = MBT.db.profile.cBarColor or { 0.62, 0, 0 }
                            return c[1], c[2], c[3]
                        end,
                        set = function(_, r, g, b)
                            MBT.db.profile.cBarColor = { r, g, b }
                            if MBT.UpdateBarColor then MBT:UpdateBarColor() end
                        end,
                    },
                    bReverseGrowth = {
                        order = 12, type = "toggle", name = "Boss 框体从下往上堆叠",
                        desc = "默认 5 个 boss 框体从屏幕上方往下方依次堆叠。\n勾选后改为从下往上 —— 适合把整个面板放在屏幕下半区的玩家。\n（注：不影响 DoT 图标的左右顺序，那个在 DoT 排序 标签里）",
                        width = "full",
                        get = function() return MBT.db.profile.bReverseGrowth end,
                        set = function(_, v)
                            MBT.db.profile.bReverseGrowth = v
                            if MBT.ReanchorRows then MBT.ReanchorRows() end
                        end,
                    },
                    fRowGap = {
                        order = 13, type = "range", name = "Boss 框体之间的间距（像素）",
                        desc = "调整两个相邻 boss 行之间的纵向空白。值越大间隔越宽，0 = 紧贴在一起。",
                        width = "full",
                        min = 0, max = 80, step = 1,
                        -- 极简（任何主题）固定 6px；标准两个主题都用此设置
                        hidden = function() return MBT.db.profile.iSkin == 1 end,
                        get = function() return MBT.db.profile.fRowGap end,
                        set = function(_, v)
                            MBT.db.profile.fRowGap = v
                            if MBT.ReanchorRows then MBT.ReanchorRows() end
                            if MBT.ResizeContainer then MBT.ResizeContainer() end
                        end,
                    },
                    bUse3DPortrait = {
                        order = 14, type = "toggle", name = "使用 3D 头像",
                        desc = "勾选：显示 boss 的实时 3D 模型（自动旋转，更生动）\n取消：改用 2D 静态头像（性能开销更低，可提升帧数）",
                        -- 极简（任何主题）都没头像。标准下两个主题都有
                        hidden = function() return MBT.db.profile.iSkin == 1 end,
                        get = function() return MBT.db.profile.bUse3DPortrait end,
                        set = function(_, v)
                            MBT.db.profile.bUse3DPortrait = v
                            if MBT.ApplyPortraitMode then MBT:ApplyPortraitMode() end
                        end,
                    },
                    iDotTextSize = {
                        order = 15, type = "range", name = "DoT 倒计时字号",
                        desc = "DoT 图标中央倒计时数字的字符大小。设为 0 可完全隐藏（适合用 OmniCC 等冷却数字插件显示倒计时的玩家）",
                        width = "full",
                        min = 0, max = 28, step = 1,
                        get = function() return MBT.db.profile.iDotTextSize end,
                        set = function(_, v)
                            MBT.db.profile.iDotTextSize = v
                            if MBT.UpdateDotTextSize then MBT:UpdateDotTextSize() end
                        end,
                    },
                    fScale = {
                        order = 11.3, type = "range", name = "整体缩放",
                        desc = "把整个面板一起放大或缩小（血条、头像、DoT、文字都跟着变），位置不动。\n标准样式下还能在下方单独调 DoT 图标大小；极简样式下 DoT 大小与整体缩放等效，故只有这一个。",
                        width = "full",
                        min = 0.5, max = 2.0, step = 0.05,
                        isPercent = true,
                        get = function() return MBT.db.profile.fScale end,
                        set = function(_, v)
                            MBT.db.profile.fScale = v
                            if MBT.ApplyScale then MBT.ApplyScale() end
                        end,
                    },
                    iDotSize = {
                        order = 11.6, type = "range", name = "DoT 图标大小（像素）",
                        -- 极简样式下 DoT 大小 = 行高 = 整条尺寸，与「整体缩放」完全等效，故隐藏避免重复
                        hidden = function() return MBT.db.profile.iSkin == 1 end,
                        desc = "DoT 图标的大小。血条宽度固定不变 —— 图标越大，只会把血条往下挤、变矮，整框宽高都不变。\n代价：图标越大，固定宽度里能并排摆下的 DoT 个数越少（见下方提示）。\n想让整个面板（连字带头像）一起放大缩小，用上面的「整体缩放」。",
                        width = "full",
                        min = 16, max = 48, step = 2,
                        get = function() return MBT.db.profile.iDotSize end,
                        set = function(_, v)
                            MBT.db.profile.iDotSize = v
                            -- 像素模式下 DoT 变化要触发整体 relayout（行高 / 头像 / 总宽都跟着变）
                            if MBT.ApplyCompactToAll then MBT.ApplyCompactToAll() end
                            if MBT.UpdateDotSize then MBT:UpdateDotSize() end
                        end,
                    },
                    iDotSizeHint = {
                        order = 11.65, type = "description", fontSize = "medium",
                        -- 极简样式没有 DoT 大小滑条，提示也一并隐藏
                        hidden = function() return MBT.db.profile.iSkin == 1 end,
                        name = function()
                            local maxN = MBT.MaxStandardDots and MBT.MaxStandardDots() or 7
                            return ("当前大小最多能并排放下 |cFF66FF66%d|r 个 DoT。"):format(maxN)
                        end,
                    },
                    bTransparentBG = {
                        order = 17, type = "toggle", name = "透明模式",
                        desc = "勾选后只有 DoT 显示区域的黑色底板变透明，不再挡住后面的场景 / 单位；血条和头像保留黑底，观感不变。\n标准和极简样式都生效。",
                        width = "full",
                        get = function() return MBT.db.profile.bTransparentBG end,
                        set = function(_, v)
                            MBT.db.profile.bTransparentBG = v
                            if MBT.ApplyBackgroundOpacity then MBT:ApplyBackgroundOpacity() end
                        end,
                    },

                    -- ===== 显示内容 =====
                    hDisplay = { order = 20, type = "header", name = "显示内容" },
                    bShowMissingDoTs = {
                        order = 21, type = "toggle", name = "显示未上的 DoT",
                        desc = "DoT 没上时仍显示一个灰色占位图标",
                        get = function() return MBT.db.profile.bShowMissingDoTs end,
                        set = function(_, v) MBT.db.profile.bShowMissingDoTs = v end,
                    },
                    bShowNPCCasts = {
                        order = 22, type = "toggle", name = "显示 Boss 施法条",
                        desc = "Boss 读条时在血条底部叠加施法进度条",
                        -- 仅极简（任何主题）下没 boss 施法条；标准下两个主题都支持
                        hidden = function() return MBT.db.profile.iSkin == 1 end,
                        get = function() return MBT.db.profile.bShowNPCCasts end,
                        set = function(_, v) MBT.db.profile.bShowNPCCasts = v end,
                    },
                    bShowPlayerCast = {
                        order = 23, type = "toggle", name = "显示自己的施法条",
                        desc = "在每个 boss 框体顶部显示一条青色窄条，表示\"我当前的 cast 正对着这只 boss\"。\n多目标 dot 切换时一眼定位 cast 目标，不再手忙脚乱漏 cast。\n瞬发法术 dot 上去会闪一下；有读条法术（影箭/鬼影）会显示进度。",
                        width = "full",
                        get = function() return MBT.db.profile.bShowPlayerCast end,
                        set = function(_, v) MBT.db.profile.bShowPlayerCast = v end,
                    },
                    bShowRangeIndicator = {
                        order = 24, type = "toggle", name = "显示距离不足提示",
                        desc = "boss 不在你最远技能射程内时，HP 条右上角显示红色\"外\"字。\n基于职业最远射程的代表性技能（暗影箭 / 寒冰箭 / 心灵震爆 / 闪电箭 / 自动射击 / 愤怒 / 死亡缠绕）。\n会自动算上天赋 / 雕文 / buff 加成（IsSpellInRange API 是 live 的）。",
                        width = "full",
                        get = function() return MBT.db.profile.bShowRangeIndicator end,
                        set = function(_, v) MBT.db.profile.bShowRangeIndicator = v end,
                    },
                    bShowFacingWarning = {
                        order = 25, type = "toggle", name = "显示朝向错误提示",
                        desc = "你点击 boss 框体施法但游戏返回\"必须面对目标\"错误时，对应框体右上角闪 1.5 秒红色\"面\"字。\n注：WoW API 不支持 proactive 朝向检测（防作弊），只能在用户尝试施法失败后反应式提示。",
                        width = "full",
                        get = function() return MBT.db.profile.bShowFacingWarning end,
                        set = function(_, v) MBT.db.profile.bShowFacingWarning = v end,
                    },
                    bShowRaidMarker = {
                        order = 25.5, type = "toggle", name = "显示团标",
                        desc = "boss 被团长打了星星 / 圈圈 / 菱形等标记时显示。\n标准模式：头像左上角，1/4 头像大小。\n紧凑模式：boss 框左外侧、当前 target 黄竖线的左边。",
                        width = "full",
                        get = function() return MBT.db.profile.bShowRaidMarker end,
                        set = function(_, v)
                            MBT.db.profile.bShowRaidMarker = v
                            -- 关闭时立刻隐藏所有现存团标；开启则等下次 health 更新自动同步
                            if not v then
                                for _, btn in pairs(MBT.BossFrames or {}) do
                                    if btn.markerIcon then btn.markerIcon:Hide() end
                                end
                            end
                        end,
                    },
                    fHealthUpdateInterval = {
                        order = 26, type = "range", name = "血量刷新间隔（秒）",
                        desc = "数值越小越实时，但开销越高。\n默认 0.1 秒 —— DPS 输出时血量是关键判断依据（处决线、阶段切换），建议保持低值。\n0 = 完全关闭血量更新",
                        width = "full",
                        min = 0, max = 5, step = 0.1,
                        get = function() return MBT.db.profile.fHealthUpdateInterval end,
                        set = function(_, v) MBT.db.profile.fHealthUpdateInterval = v end,
                    },

                    -- ===== 位置 =====
                    hPosition = { order = 30, type = "header", name = "位置" },
                    bLocked = {
                        order = 31, type = "toggle", name = "锁定位置",
                        desc = "锁定后不能拖动",
                        get = function() return MBT.db.profile.bLocked end,
                        set = function(_, v) if MBT.SetLocked then MBT.SetLocked(v) end end,
                    },
                    resetAnchor = {
                        order = 32, type = "execute", name = "复位到屏幕中央",
                        func = function()
                            MBT.db.profile.anchor = { point="CENTER", relPoint="CENTER", x=0, y=0 }
                            if MBT.ApplyAnchor then MBT.ApplyAnchor() end
                        end,
                    },

                    -- ===== 其他 =====
                    hMisc = { order = 40, type = "header", name = "其他" },
                    bMinimap = {
                        order = 41, type = "toggle", name = "显示小地图按钮",
                        desc = "在小地图边上加一个小图标：左键打开设置，右键锁定/解锁框体",
                        get = function() return not MBT.db.profile.minimap.hide end,
                        set = function(_, v)
                            MBT.db.profile.minimap.hide = not v
                            local LDBIcon = LibStub("LibDBIcon-1.0", true)
                            if LDBIcon then
                                if v then LDBIcon:Show("MultiBossTracker")
                                else LDBIcon:Hide("MultiBossTracker") end
                            end
                        end,
                    },

                    -- ===== 术士专属设置 =====
                    hWarlock = { order = 45, type = "header", name = "术士专属设置" },
                    warlockGlow = {
                        order = 46, type = "group", inline = true,
                        name = "余烬 / 暗影印记高亮光圈",
                        args = {
                    sWarlockGlowStyle = {
                        order = 45.1, type = "select", name = "光圈样式", width = 1.0,
                        desc = "余烬 / 暗影印记双 6 层时整框光圈的样式。",
                        values = { pixel = "像素描边", autocast = "自动施法流光", button = "按钮高光", proc = "脉冲流光" },
                        sorting = { "pixel", "autocast", "button", "proc" },
                        get = function() return MBT.db.profile.sWarlockGlowStyle end,
                        set = function(_, v)
                            MBT.db.profile.sWarlockGlowStyle = v
                            if MBT.RefreshComboGlows then MBT:RefreshComboGlows() end
                        end,
                    },
                    cWarlockGlowColor = {
                        order = 45.2, type = "color", name = "光圈颜色", width = 0.5,
                        hasAlpha = false,
                        desc = "余烬 / 暗影印记双 6 层时整框光圈的颜色。",
                        get = function()
                            local c = MBT.db.profile.cWarlockGlowColor or { 1.0, 0.6, 0.1 }
                            return c[1], c[2], c[3]
                        end,
                        set = function(_, r, g, b)
                            MBT.db.profile.cWarlockGlowColor = { r, g, b }
                            if MBT.RefreshComboGlows then MBT:RefreshComboGlows() end
                        end,
                    },
                    fWarlockGlowFreq = {
                        order = 45.3, type = "range", name = "光圈转速", width = "full",
                        desc = "光圈动画的快慢，越大越快。",
                        min = 0.05, max = 2.0, step = 0.05,
                        get = function() return MBT.db.profile.fWarlockGlowFreq end,
                        set = function(_, v)
                            MBT.db.profile.fWarlockGlowFreq = v
                            if MBT.RefreshComboGlows then MBT:RefreshComboGlows() end
                        end,
                    },
                    iWarlockGlowThickness = {
                        order = 45.4, type = "range", name = "光圈线条粗细", width = 0.5,
                        desc = "像素描边的线条粗细。",
                        hidden = function() return MBT.db.profile.sWarlockGlowStyle ~= "pixel" end,
                        min = 1, max = 6, step = 1,
                        get = function() return MBT.db.profile.iWarlockGlowThickness end,
                        set = function(_, v)
                            MBT.db.profile.iWarlockGlowThickness = v
                            if MBT.RefreshComboGlows then MBT:RefreshComboGlows() end
                        end,
                    },
                    iWarlockGlowDots = {
                        order = 45.5, type = "range", name = "光圈流动点数", width = 0.5,
                        desc = "像素描边沿框体周长流动的点数。",
                        hidden = function() return MBT.db.profile.sWarlockGlowStyle ~= "pixel" end,
                        min = 1, max = 16, step = 1,
                        get = function() return MBT.db.profile.iWarlockGlowDots end,
                        set = function(_, v)
                            MBT.db.profile.iWarlockGlowDots = v
                            if MBT.RefreshComboGlows then MBT:RefreshComboGlows() end
                        end,
                    },
                    fWarlockGlowScale = {
                        order = 45.6, type = "range", name = "光点大小", width = 0.5,
                        desc = "自动施法流光每颗光点的大小。",
                        hidden = function() return MBT.db.profile.sWarlockGlowStyle ~= "autocast" end,
                        min = 0.5, max = 5.0, step = 0.1,
                        get = function() return MBT.db.profile.fWarlockGlowScale end,
                        set = function(_, v)
                            MBT.db.profile.fWarlockGlowScale = v
                            if MBT.RefreshComboGlows then MBT:RefreshComboGlows() end
                        end,
                    },
                    iWarlockGlowParticles = {
                        order = 45.7, type = "range", name = "光点数量", width = 0.5,
                        desc = "自动施法流光环绕框体的光点数量。",
                        hidden = function() return MBT.db.profile.sWarlockGlowStyle ~= "autocast" end,
                        min = 1, max = 8, step = 1,
                        get = function() return MBT.db.profile.iWarlockGlowParticles end,
                        set = function(_, v)
                            MBT.db.profile.iWarlockGlowParticles = v
                            if MBT.RefreshComboGlows then MBT:RefreshComboGlows() end
                        end,
                    },
                        }, -- warlockGlow.args
                    },     -- warlockGlow（内联子组）

                    -- ===== QQ 交流群 =====
                    hCommunity = { order = 50, type = "header", name = "QQ 交流群" },
                    qqGroup = {
                        order = 51, type = "execute",
                        -- 用 InteractiveLabel 让这条渲染成可点击的文本，而不是按钮
                        dialogControl = "InteractiveLabel",
                        name = "多目标 Boss 追踪交流群\nQQ群号：|cFFFFD200124134274|r\n密码：|cFFFFD200多目标|r\n|cFF888888（点击复制群号到聊天框）|r",
                        width = "full",
                        desc = "点击后把 QQ 群号自动填进游戏聊天输入框，按 Ctrl+C 即可复制到系统剪贴板。\n注意：不要按 Enter，否则会把群号发送到当前频道。",
                        func = function()
                            -- 把群号塞进默认聊天输入框，并立刻全选 —— 用户按 Ctrl+C 直接复制
                            local cf = DEFAULT_CHAT_FRAME
                            local eb = ChatEdit_ChooseBoxForSend(cf)
                            if not eb then return end
                            ChatEdit_ActivateChat(eb)
                            eb:SetText("124134274")
                            -- 延迟一帧再 SetFocus + 全选：AceConfig 点击释放鼠标时会抢焦点，
                            -- 现帧调用容易被覆盖；下一帧再做能保证选中状态留在聊天框
                            C_Timer.After(0, function()
                                if not eb:IsVisible() then return end
                                eb:SetFocus()
                                eb:HighlightText(0, -1)
                            end)
                        end,
                    },
                },
            },

            blacklist = {
                order = 2, type = "group", name = "DoT 黑名单",
                args = (function()
                    local args = {
                        _intro = {
                            order = 0, type = "description",
                            name = "勾选后这些 DoT 不会显示在框体下方，按职业分组。\n",
                        },
                    }
                    local order = 10
                    for _, group in ipairs(SPELL_BLACKLIST_BY_CLASS) do
                        args["h_" .. group.sClass] = {
                            order = order, type = "header", name = group.sClass,
                        }
                        order = order + 1
                        for _, spell in ipairs(group.tSpells) do
                            local key = spell.sKey
                            args[key] = {
                                order = order, type = "toggle",
                                name = spell.sLabel,
                                width = "full",
                                get = function() return MBT.db.profile.tBlacklist[key] end,
                                set = function(_, v)
                                    MBT.db.profile.tBlacklist[key] = v
                                    MBT:FireEvent("MultiBossTracker_BlacklistChanged")
                                end,
                            }
                            order = order + 1
                        end
                        -- 术士额外开关：隐藏新增的余烬/暗影印记 pip 行（恢复改动前的 boss 框形态）
                        if group.sClass == "术士" then
                            args["_warlock_hide_brand_pips"] = {
                                order = order, type = "toggle",
                                name = "隐藏印记层数指示条",
                                desc = "毁灭术士专属：boss 框底部会出现一条显示余烬印记和暗影印记当前层数的横条（类似盗贼的连击点）。勾选此项后这条指示条会被隐藏，boss 框恢复到没有这条指示的高度。两个印记本身仍然按普通 DoT 图标显示（如未在上方屏蔽）。",
                                width = "full",
                                get = function() return MBT.db.profile.bHideBrandPips end,
                                set = function(_, v)
                                    MBT.db.profile.bHideBrandPips = v
                                    if MBT.ApplyCompactToAll then MBT.ApplyCompactToAll() end
                                end,
                            }
                            order = order + 1
                            args["_warlock_hide_channel_bar"] = {
                                order = order, type = "toggle",
                                name = "隐藏吸取灵魂引导条",
                                desc = "痛苦术士专属：boss 框底部会出现吸取灵魂的引导进度条，红色竖线提示\"该断了去续鬼影缠身\"的最佳位置。勾选此项后这条引导条会被隐藏，boss 框恢复原始高度。",
                                width = "full",
                                get = function() return MBT.db.profile.bHideChannelBar end,
                                set = function(_, v)
                                    MBT.db.profile.bHideChannelBar = v
                                    if MBT.ApplyCompactToAll then MBT.ApplyCompactToAll() end
                                end,
                            }
                            order = order + 1
                        end
                    end
                    return args
                end)(),
            },

            bindings = {
                order = 3, type = "group", name = "点击施法",
                childGroups = "tree",
                args = (function()
                    local args = {}
                    for i, cg in ipairs(CLASS_GROUPS) do
                        args[cg.key] = {
                            order = i, type = "group", name = cg.label,
                            args = buildClassBindingsGroup(cg),
                        }
                    end
                    return args
                end)(),
            },

            sort = {
                order = 4, type = "group", name = "DoT 排序",
                childGroups = "tree",
                args = (function()
                    local args = {}
                    for i, cg in ipairs(CLASS_GROUPS) do
                        args[cg.key] = {
                            order = i, type = "group", name = cg.label,
                            args = buildDoTSortGroup(cg),
                        }
                    end
                    return args
                end)(),
            },


            hide = {
                order = 5, type = "group", name = "隐藏单位",
                childGroups = "tree",
                args = (function()
                    local args = {}
                    for i, p in ipairs(PHASES) do
                        args[p.key] = {
                            order = i, type = "group", name = p.label,
                            args = buildHidePhaseGroup(p),
                        }
                    end
                    return args
                end)(),
            },

        },
    }

    -- 配置档（角色间切换）
    opts.args.profiles = AceDBOptions:GetOptionsTable(MBT.db)
    opts.args.profiles.order = 100
    opts.args.profiles.name = "配置档"

    -- 把"导入 / 导出"追加到配置档 tab 末尾。AceDBOptions 默认 args 的 order 都在 80
    -- 以内（profile 选择 / 复制 / 重置），用 200+ 让它们落在最下面
    local pargs = opts.args.profiles.args
    pargs.mbt_imexport_header = {
        order = 200, type = "header", name = "导入 / 导出",
    }
    pargs.mbt_imexport_intro = {
        order = 201, type = "description", fontSize = "medium",
        name = "把当前配置档导出成字符串发给朋友，或粘贴朋友给你的字符串导入。\n导入时按字符串里附带的配置档名建立新配置档；同名会被直接覆盖。\n",
    }
    pargs.mbt_imexport_export = {
        order = 202, type = "execute", name = "打开导出窗口",
        desc = "弹出独立窗口显示当前配置档的导出字符串，可全选复制",
        func = function() MBT:ShowExportFrame() end,
    }
    pargs.mbt_imexport_import = {
        order = 203, type = "execute", name = "打开导入窗口",
        desc = "弹出独立窗口，粘贴朋友发给你的导出字符串后点 导入",
        func = function() MBT:ShowImportFrame() end,
    }

    return opts
end

local function Register()
    -- "MultiBossTracker" 这两个字符串是 AceConfig 内部用的注册 key，不能改
    AceConfig:RegisterOptionsTable("MultiBossTracker", BuildOptionsTable)
    -- 加到暴雪原生 "界面 → 插件" 菜单下；第二个参数是侧边栏显示名
    MBT.optsFrame = AceConfigDialog:AddToBlizOptions("MultiBossTracker", "多目标 Boss 追踪")
end

function MBT:OpenOptions()
    if not MBT.optsFrame then Register() end
    -- MoP Classic 5.5 用了新版 Settings API；老 Classic 客户端仍然走 InterfaceOptionsFrame_*。
    if Settings and Settings.OpenToCategory then
        local id = MBT.optsFrame.categoryID or MBT.optsFrame.name or "MultiBossTracker"
        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- 旧 API 有个 bug 必须连调两次才会真的选中分类
        InterfaceOptionsFrame_OpenToCategory(MBT.optsFrame)
        InterfaceOptionsFrame_OpenToCategory(MBT.optsFrame)
    else
        -- 兜底：弹独立窗
        AceConfigDialog:Open("MultiBossTracker")
    end
end

-- 等到 PLAYER_LOGIN 后 db 已经就绪再注册
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Register()
end)
