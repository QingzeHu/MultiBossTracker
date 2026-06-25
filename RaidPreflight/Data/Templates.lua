-- 检查模板
-- 一条「检查项」是一个描述符，引擎照它去判定通过/不通过：
--   { sType="aura_keyword", aKeywords={"合剂"}, sLabel="合剂" }   -- 自己身上有名字含关键字的 buff
--   { sType="item",  iItemID=5512, iMin=1, sLabel="治疗石" }       -- 包裹里该物品数量 >= iMin
--   { sType="comp",  aClasses={"WARLOCK"}, sLabel="法术易伤来源（术士）" } -- 团队里有该职业
--
-- 模板三级覆盖：通用(global) → 副本(zone, by mapID) → boss(by encounterID)，逐级追加。
-- v1 内置一套合理默认；用户覆盖写在 db.tZones（UI 配置面板留到 v2）。

local addonName, RPF = ...
local C = RPF.Consumables

-- 通用自身检查（所有职业都该有的）
local function BuildGlobalSelf()
    local t = {
        { sType = "aura_keyword", aKeywords = C.flaskAuraKeywords,   sLabel = "合剂 / 药剂" },
        { sType = "aura_keyword", aKeywords = C.wellFedAuraKeywords, sLabel = "食物增益（营养充足）" },
    }
    if C.items.healthstone then
        t[#t + 1] = { sType = "item", iItemID = C.items.healthstone, iMin = 1, sLabel = "治疗石" }
    end
    return t
end

-- 通用团队构成检查。
-- comp 检查支持可选的 aSpecIDs（专精 ID 列表）：给了就要求「职业在场 + 专精匹配」，
-- 没给就只看职业在不在。专精靠 Inspect.lua 后台 inspect 读，读不到会标「专精待确认」(黄)。
-- ⚠️ 职业/专精归类是种子，按你服务器的技能改动调整。专精 ID 见暴雪 specialization ID，
--    本服若改过专精机制需自行校对。示例（注释掉的）：精灵火只要德鲁伊职业即可，无需专精。
local function BuildGlobalComp()
    return {
        { sType = "comp", aClasses = { "SHAMAN", "MAGE", "HUNTER" },
          sLabel = "嗜血 / 时空扭曲 来源" },
        -- 想精确到专精时这样写（示例 ID，请校对）：
        -- { sType = "comp", aClasses = { "WARLOCK" }, aSpecIDs = { 265, 266, 267 },
        --   sLabel = "法术易伤来源（术士）" },
        { sType = "comp", aClasses = { "WARLOCK" },
          sLabel = "法术易伤来源（术士 元素诅咒）" },
        { sType = "comp", aClasses = { "WARRIOR", "ROGUE", "DEATHKNIGHT", "HUNTER", "DRUID" },
          sLabel = "破甲 / 物理易伤来源" },
    }
end

-- 对外：取某情境下的完整检查清单（已合并三级）。
-- sContext: "summon" | "enter" | "pull"
-- tBoss:    {iMapID=, iEncID=, sName=} 或 nil
function RPF:GetActiveChecklist(sContext, tBoss)
    local out = {}
    local function append(list)
        if type(list) ~= "table" then return end
        for _, c in ipairs(list) do out[#out + 1] = c end
    end

    -- 1) 通用：进本/召唤偏重自身物资 + 团队构成；开战前同样需要。
    append(BuildGlobalSelf())
    if sContext == "enter" or sContext == "summon" or sContext == "pull" then
        append(BuildGlobalComp())
    end

    -- 2) 副本级覆盖
    local iMapID = tBoss and tBoss.iMapID
    local zone = iMapID and self.db.tZones[iMapID]
    if zone then
        append(zone.tItems)
        append(zone.tAuras)
        append(zone.tComp)
        -- 3) boss 级覆盖
        local iEncID = tBoss and tBoss.iEncID
        if iEncID and zone.tBosses and zone.tBosses[iEncID] then
            local b = zone.tBosses[iEncID]
            append(b.tItems)
            append(b.tAuras)
            append(b.tComp)
        end
    end

    return out
end
