-- 专精检测（inspect 管理器）
-- 目的：进本前/开战前把团队扫一遍，知道每个人的「专精」，给 comp 检查判断
-- 「能提供法术易伤/精灵火这类的职业，专精对不对」。绝不在战斗中跑。
--
-- ⚠️ MoP Classic 5.5 现实：
--   - 专精(specialization)可读：自己 GetSpecialization；别人 NotifyInspect → INSPECT_READY → GetInspectSpecialization。
--   - 单个天赋点不可靠读取（WotLK 的 GetTalentInfo(row,index) 已删，被检视单位拿不到），
--     所以这里只做到「专精」粒度——多数团队 debuff 来源按职业/专精就够判断。
--   - inspect 有节流 + 距离/可见限制，所以是「常驻预热缓存」：组队后慢慢扫，
--     ready check 时多半已就绪；没读到的回退职业级并在清单标「专精待确认」。

local addonName, RPF = ...

RPF._specByGUID = {}              -- guid -> specID（别人）；自己实时算
local queue = {}                  -- 待 inspect 的 unit token 列表
local pendingUnit, pendingGUID, fPendingSince = nil, nil, 0

local function playerSpecID()
    local idx = GetSpecialization and GetSpecialization()
    if not idx then return nil end
    local id = GetSpecializationInfo and GetSpecializationInfo(idx)
    return id
end

-- 对外：取某单位的专精 ID（取不到返回 nil）。
function RPF:GetUnitSpec(unit)
    if UnitIsUnit(unit, "player") then return playerSpecID() end
    local guid = UnitGUID(unit)
    return guid and RPF._specByGUID[guid] or nil
end

-- 把组里还没缓存专精的成员排进队列。
local function rebuildQueue()
    wipe(queue)
    for _, unit in ipairs(RPF:IterGroupUnits()) do
        if not UnitIsUnit(unit, "player") then
            local guid = UnitGUID(unit)
            if guid and not RPF._specByGUID[guid]
               and UnitExists(unit) and CanInspect(unit) then
                queue[#queue + 1] = unit
            end
        end
    end
end

-- 节流泵：每 ~1.5s 处理一个，被卡住 >3s 就放弃换下一个。
local pump = CreateFrame("Frame")
local fAccum = 0
pump:Hide()
pump:SetScript("OnUpdate", function(self, elapsed)
    fAccum = fAccum + elapsed
    if fAccum < 1.5 then return end
    fAccum = 0
    if InCombatLockdown() then return end

    -- 还在等上一个的结果
    if pendingUnit then
        if GetTime() - fPendingSince < 3 then return end
        pendingUnit, pendingGUID = nil, nil   -- 超时，放弃
    end

    -- 取下一个有效目标
    while #queue > 0 do
        local unit = table.remove(queue, 1)
        local guid = UnitGUID(unit)
        if guid and not RPF._specByGUID[guid]
           and UnitExists(unit) and CanInspect(unit) and UnitIsConnected(unit) then
            pendingUnit, pendingGUID, fPendingSince = unit, guid, GetTime()
            NotifyInspect(unit)
            return
        end
    end
    -- 队列空了，歇着
    self:Hide()
end)

local function kick()
    rebuildQueue()
    if #queue > 0 then
        fAccum = 1.5  -- 立刻处理一个
        pump:Show()
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("INSPECT_READY")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "INSPECT_READY" then
        -- arg1 = guid。只认我们正在等的那个。
        if pendingUnit and arg1 == pendingGUID then
            local spec = GetInspectSpecialization and GetInspectSpecialization(pendingUnit)
            if spec and spec > 0 then RPF._specByGUID[pendingGUID] = spec end
            if ClearInspectPlayer then ClearInspectPlayer() end
            pendingUnit, pendingGUID = nil, nil
            fAccum = 1.5  -- 接着下一个
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- 别人换专精会触发（带 unit），缓存作废后重扫；自己实时算无需缓存。
        if arg1 and arg1 ~= "player" and UnitExists(arg1) then
            local guid = UnitGUID(arg1)
            if guid then RPF._specByGUID[guid] = nil end
        end
        kick()
    else -- PLAYER_LOGIN / GROUP_ROSTER_UPDATE
        kick()
    end
end)
