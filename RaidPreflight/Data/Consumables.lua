-- 消耗品 / 增益 数据
-- ⚠️ 泰坦怀旧时光对掉落和物品多有改动，下面的 itemID / 名称都是「示例种子」，
--    请按你服务器实际情况调整。检查引擎尽量用「光环名关键字」匹配（跨 itemID 稳），
--    包裹物品才用 itemID（GetItemCount）。

local addonName, RPF = ...

RPF.Consumables = {
    -- 合剂类 buff：MoP 合剂 buff 名基本都含「合剂」二字，用关键字匹配最稳。
    flaskAuraKeywords = { "合剂" },

    -- 食物 buff：Well Fed 在 zhCN 显示「营养充足」。
    wellFedAuraKeywords = { "营养充足", "充足" },

    -- 常用包裹物品（itemID）。请按服务器校对。
    items = {
        healthstone = 5512,    -- 治疗石（术士造，示例 ID）
        -- 战斗药水 / 增益药水（示例占位，按服务器填）
        -- potionDPS  = 76093,
        -- potionMana = 76092,
        -- 工程炸弹（示例占位）
        -- bomb       = 89637,
        -- 符文 / 强化剂（示例占位）
    },
}
