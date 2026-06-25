-- 副本 boss 顺序数据（自带，独立于 MultiBossTracker）
-- 用途：开战前(ready check)推断「下一个要打的 boss」，给模板做 boss 级匹配。
--
-- 推断优先级（见 BossDetect.lua）：
--   1) 鼠标悬浮 / 当前目标是个已知 boss 的 NPCID → 就是它（玩家用动作表态）
--   2) 当前子地点(SubZone)只对应一个 boss → 就是它
--   3) 都不确定 → 按 tOrder 硬编码顺序里的指针（ENCOUNTER_END 推进）
--
-- ⚠️ 种子数据，仅熔火之心做示例。请按泰坦怀旧时光实际副本补全。
-- iMapID 取 GetInstanceInfo() 的第 8 返回值 instanceMapID。

local addonName, RPF = ...

RPF.Zones = {
    -- 熔火之心（示例）
    [409] = {
        sName  = "熔火之心",
        -- encounterID → boss 信息
        tEnc = {
            [663] = { sName = "鲁西弗隆",          sNPCID = "12118" },
            [664] = { sName = "玛格曼达",          sNPCID = "11982" },
            [665] = { sName = "基赫纳斯",          sNPCID = "12259" },
            [666] = { sName = "加尔",              sNPCID = "12057" },
            [667] = { sName = "沙斯拉尔",          sNPCID = "12264" },
            [668] = { sName = "迦顿男爵",          sNPCID = "12056" },
            [669] = { sName = "萨弗隆先驱者",      sNPCID = "12098" },
            [670] = { sName = "焚化者古雷曼格",    sNPCID = "11988" },
            [671] = { sName = "管理者埃克索图斯",  sNPCID = "12018" },
        },
        -- 硬编码顺序（不确定时的兜底指针）
        tOrder = { 663, 664, 665, 666, 668, 667, 669, 670, 671 },
        -- 子地点 → encounterID（有独立子地点的房间才填；没有就靠悬浮/顺序）
        tBySubZone = {
            ["玛格曼达洞穴"]   = 663,
            ["拉格纳罗斯之巢"] = nil,
        },
    },
}

-- 反查表：NPCID → {iMapID, iEncID}（BossDetect 悬浮/目标检测用），首次访问时惰性构建。
do
    local tByNPCID
    function RPF:LookupBossByNPCID(sNPCID)
        if not tByNPCID then
            tByNPCID = {}
            for iMapID, zone in pairs(RPF.Zones) do
                for iEncID, enc in pairs(zone.tEnc or {}) do
                    if enc.sNPCID then
                        tByNPCID[enc.sNPCID] = { iMapID = iMapID, iEncID = iEncID, sName = enc.sName }
                    end
                end
            end
        end
        return tByNPCID[sNPCID]
    end
end
