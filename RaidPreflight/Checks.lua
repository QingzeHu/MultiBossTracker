-- 检查引擎：把模板里的描述符逐条判定为 通过 / 不通过。
local addonName, RPF = ...

-- 收集自己身上所有 buff 的名字（小写化便于关键字匹配）。
local function GetPlayerBuffNames()
    local names = {}
    for i = 1, 40 do
        local name = UnitAura("player", i, "HELPFUL")
        if not name then break end
        names[#names + 1] = name
    end
    return names
end

-- 团队里是否存在某些职业之一（职业 token，如 "WARLOCK"）。
local function GroupHasAnyClass(aClasses)
    local want = {}
    for _, c in ipairs(aClasses) do want[c] = true end
    for _, unit in ipairs(RPF:IterGroupUnits()) do
        local _, token = UnitClass(unit)
        if token and want[token] then return true end
    end
    return false
end

-- 判定单条描述符 → bOK, sDetail
local function evalOne(desc, buffNames)
    local t = desc.sType
    if t == "aura_keyword" then
        for _, kw in ipairs(desc.aKeywords or {}) do
            for _, name in ipairs(buffNames) do
                if name:find(kw, 1, true) then
                    return true, name
                end
            end
        end
        return false, "未生效"
    elseif t == "item" then
        local n = GetItemCount(desc.iItemID or 0)
        local need = desc.iMin or 1
        return n >= need, ("携带 %d / 需 %d"):format(n, need)
    elseif t == "comp" then
        local ok = GroupHasAnyClass(desc.aClasses or {})
        return ok, ok and "在场" or "缺职业"
    end
    return false, "未知检查类型"
end

-- 对外：评估整张清单。返回 results 数组与汇总 bAllOK。
-- results[i] = { sLabel, bOK, sDetail }
function RPF:EvaluateChecklist(tList)
    local buffNames = GetPlayerBuffNames()
    local results, bAllOK = {}, true
    for _, desc in ipairs(tList) do
        local bOK, sDetail = evalOne(desc, buffNames)
        if not bOK then bAllOK = false end
        results[#results + 1] = { sLabel = desc.sLabel or "?", bOK = bOK, sDetail = sDetail }
    end
    return results, bAllOK
end
