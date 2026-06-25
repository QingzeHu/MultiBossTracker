-- 触发器：把三个情境接到检查引擎 + 弹窗上。
--   1) 术士拉人  → CONFIRM_SUMMON（拦默认弹窗，先看清单再决定接/拒）
--   2) 自己进本  → PLAYER_ENTERING_WORLD（每个副本周期弹一次）
--   3) 开战前    → READY_CHECK（团队倒计时时针对下一个 boss 弹）
local addonName, RPF = ...

-- 跑一次检查并弹窗。summon=true 时走召唤模式（接受/取消召唤）。
local function runChecklist(sContext, tBoss, summon)
    local function build()
        local list = RPF:GetActiveChecklist(sContext, tBoss)
        return RPF:EvaluateChecklist(list)
    end
    local results, allOK = build()

    local sTitle, sSubtitle
    if sContext == "summon" then
        sTitle = "召唤检查"
        local area = GetSummonConfirmAreaName and GetSummonConfirmAreaName()
        sSubtitle = area and ("目的地：" .. area) or "确认进入团队前的检查"
    elseif sContext == "pull" then
        sTitle = "开战前检查"
        sSubtitle = (tBoss and tBoss.sName) and ("下一个：" .. tBoss.sName) or "即将开战"
    else
        sTitle = "进本检查"
        local name = GetInstanceInfo()
        sSubtitle = name and ("副本：" .. name) or ""
    end

    if summon then
        RPF:ShowChecklist({
            sTitle = sTitle, sSubtitle = sSubtitle,
            tResults = results, bAllOK = allOK, sMode = "summon",
            fnConfirm = function() if _G.ConfirmSummon then ConfirmSummon() end end,
            fnCancel  = function() if _G.CancelSummon then CancelSummon() end end,
        })
    else
        RPF:ShowChecklist({
            sTitle = sTitle, sSubtitle = sSubtitle,
            tResults = results, bAllOK = allOK, sMode = "normal",
            fnRecheck = build,
        })
    end
end

-- ---------------------------------------------------------------------
-- 进本去重
-- ---------------------------------------------------------------------
local function enterKey()
    local name, instanceType, difficultyID, _, _, _, _, instanceMapID = GetInstanceInfo()
    if instanceType ~= "party" and instanceType ~= "raid" then return nil end
    return (instanceMapID or 0) .. ":" .. (difficultyID or 0)
end

local function shouldShowEnter()
    local key = enterKey()
    if not key then return false, nil end
    local last = RPF.db.tShownEnter[key] or 0
    if (time() - last) < (RPF.db.iEnterCooldown or 0) then return false, key end
    return true, key
end

-- ---------------------------------------------------------------------
-- 事件接线（等 SavedVariables 就绪后再注册）
-- ---------------------------------------------------------------------
RPF:On("RPF_Ready", function()
    local f = CreateFrame("Frame")
    f:RegisterEvent("CONFIRM_SUMMON")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("READY_CHECK")
    f:SetScript("OnEvent", function(_, event)
        if not RPF.db.bEnabled then return end

        if event == "CONFIRM_SUMMON" then
            if not RPF.db.bOnSummon then return end
            StaticPopup_Hide("CONFIRM_SUMMON")  -- 收起暴雪默认弹窗，用我们的替代
            runChecklist("summon", nil, true)

        elseif event == "PLAYER_ENTERING_WORLD" then
            if not RPF.db.bOnEnter then return end
            local show, key = shouldShowEnter()
            if show and key then
                RPF.db.tShownEnter[key] = time()
                runChecklist("enter", RPF:GetUpcomingBoss(), false)
            end

        elseif event == "READY_CHECK" then
            if not RPF.db.bOnPull then return end
            if not IsInInstance() then return end
            runChecklist("pull", RPF:GetUpcomingBoss(), false)
        end
    end)

    -- 手动触发（/rpf）：在本看情境，给 pull 风格；否则 enter 风格。
    RPF:On("RPF_ManualCheck", function()
        if IsInInstance() then
            runChecklist("pull", RPF:GetUpcomingBoss(), false)
        else
            runChecklist("enter", nil, false)
        end
    end)
end)
