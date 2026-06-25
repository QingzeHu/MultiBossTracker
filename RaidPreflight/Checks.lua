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

-- 团队构成判定：要求某职业之一在场；若 desc.aSpecIDs 给了专精，还要求专精匹配。
-- 返回 bOK, sDetail, bWarn。bWarn=职业在但专精还没 inspect 到（待确认，黄色）。
local function evalComp(desc)
    local want = {}
    for _, c in ipairs(desc.aClasses or {}) do want[c] = true end
    local wantSpec = desc.aSpecIDs and #desc.aSpecIDs > 0
    local specSet = {}
    if wantSpec then for _, s in ipairs(desc.aSpecIDs) do specSet[s] = true end end

    local bClassFound, bUnknown = false, false
    for _, unit in ipairs(RPF:IterGroupUnits()) do
        local _, token = UnitClass(unit)
        if token and want[token] then
            if not wantSpec then return true, "在场" end
            bClassFound = true
            local spec = RPF:GetUnitSpec(unit)
            if spec and specSet[spec] then
                return true, "专精在场"
            elseif not spec then
                bUnknown = true   -- 职业对，专精还没读到
            end
        end
    end

    if not wantSpec then return false, "缺职业" end
    if bClassFound and bUnknown then return true, "职业在场（专精待确认）", true end
    if bClassFound then return false, "职业在但专精不符" end
    return false, "缺职业"
end

-- 判定单条描述符 → bOK, sDetail, bWarn
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
        return evalComp(desc)
    end
    return false, "未知检查类型"
end

-- 对外：评估整张清单。返回 results 数组与汇总 bAllOK。
-- results[i] = { sLabel, bOK, sDetail }
function RPF:EvaluateChecklist(tList)
    local buffNames = GetPlayerBuffNames()
    local results, bAllOK = {}, true
    for _, desc in ipairs(tList) do
        local bOK, sDetail, bWarn = evalOne(desc, buffNames)
        if not bOK then bAllOK = false end
        results[#results + 1] = { sLabel = desc.sLabel or "?", bOK = bOK, sDetail = sDetail, bWarn = bWarn }
    end
    return results, bAllOK
end
