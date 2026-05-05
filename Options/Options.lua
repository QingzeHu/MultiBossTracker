-- 设置面板（AceConfig 实现）。
-- 结构镜像的 authorOptions 树，但所有 UI 字符串硬编码中文。
local addonName, MBT = ...

local AceConfig         = LibStub("AceConfig-3.0")
local AceConfigDialog   = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDBOptions      = LibStub("AceDBOptions-3.0")

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
                      adds = { { name = "火妖祭司",     npcID = "11662" } } },
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
                    { name = "塔迪乌斯",       npcID = "15928" },
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

-- DoT 黑名单清单
local SPELL_BLACKLIST_KEYS = {
    "Corruption", "Faerie Fire", "Living Bomb", "Insect Swarm", "Shadow Word: Pain",
    "Immolation", "Unstable Affliction", "Seed of Corruption", "Flame Shock",
    "Devouring Plague", "Moonfire", "Shadow Embrace", "Haunt", "Vampiric Touch",
    "Curse of Doom", "Curse of Agony",
}
-- 黑名单显示名（中文）
local SPELL_BLACKLIST_LABELS = {
    ["Corruption"]          = "腐蚀术",
    ["Faerie Fire"]         = "精灵之火",
    ["Living Bomb"]         = "活体炸弹",
    ["Insect Swarm"]        = "虫群",
    ["Shadow Word: Pain"]   = "暗言术：痛",
    ["Immolation"]          = "灼烧",
    ["Unstable Affliction"] = "痛苦无常",
    ["Seed of Corruption"]  = "腐蚀之种",
    ["Flame Shock"]         = "烈焰震击",
    ["Devouring Plague"]    = "吞噬瘟疫",
    ["Moonfire"]            = "月火术",
    ["Shadow Embrace"]      = "暗影之拥",
    ["Haunt"]               = "鬼影缠身",
    ["Vampiric Touch"]      = "吸血鬼之触",
    ["Curse of Doom"]       = "厄运诅咒",
    ["Curse of Agony"]      = "痛苦诅咒",
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
                        order = 11, type = "select", name = "样式",
                        desc = "紧凑：单条窄血条 + 右侧 DoT，没有大图标和独立施法条\n完整：图标 + HP + 施法条 + 下方 DoT 行",
                        values = { [1] = "紧凑", [2] = "完整" },
                        get = function() return MBT.db.profile.iSkin end,
                        set = function(_, v)
                            MBT.db.profile.iSkin = v
                            if MBT.ApplyCompactToAll then MBT.ApplyCompactToAll() end
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
                        desc = "调整两个相邻 boss 行之间的纵向空白。值越大间隔越宽，0 = 紧贴在一起。\n（仅在 完整 外观下生效，紧凑模式固定为紧凑间距）",
                        width = "full",
                        min = 0, max = 80, step = 1,
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
                        get = function() return MBT.db.profile.bUse3DPortrait end,
                        set = function(_, v)
                            MBT.db.profile.bUse3DPortrait = v
                            if MBT.ApplyPortraitMode then MBT:ApplyPortraitMode() end
                        end,
                    },
                    iDotTextSize = {
                        order = 15, type = "range", name = "DoT 倒计时字号",
                        desc = "DoT 图标中央倒计时数字的字符大小",
                        width = "full",
                        min = 8, max = 28, step = 1,
                        get = function() return MBT.db.profile.iDotTextSize end,
                        set = function(_, v)
                            MBT.db.profile.iDotTextSize = v
                            if MBT.UpdateDotTextSize then MBT:UpdateDotTextSize() end
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
                        get = function() return MBT.db.profile.bShowNPCCasts end,
                        set = function(_, v) MBT.db.profile.bShowNPCCasts = v end,
                    },
                    fHealthUpdateInterval = {
                        order = 23, type = "range", name = "血量刷新间隔（秒）",
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

                    -- ===== QQ 交流群 =====
                    hCommunity = { order = 50, type = "header", name = "QQ 交流群" },
                    qqGroup = {
                        order = 51, type = "execute",
                        -- 用 InteractiveLabel 让这条渲染成可点击的文本，而不是按钮
                        dialogControl = "InteractiveLabel",
                        name = "多目标 Boss 追踪交流群\n群号：|cFFFFD200124134274|r\n密码：|cFFFFD200多目标|r\n|cFF888888（点击复制群号到聊天框）|r",
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
                            name = "勾选后这些 DoT 不会显示在框体下方。\n",
                        },
                    }
                    for i, name in ipairs(SPELL_BLACKLIST_KEYS) do
                        args[name] = {
                            order = i, type = "toggle",
                            name = SPELL_BLACKLIST_LABELS[name] or name,
                            width = "full",
                            get = function() return MBT.db.profile.tBlacklist[name] end,
                            set = function(_, v)
                                MBT.db.profile.tBlacklist[name] = v
                                MBT:FireEvent("MultiBossTracker_BlacklistChanged")
                            end,
                        }
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
