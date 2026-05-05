-- Player Cast Tracker
-- 把玩家自己施放的法术进度显示在对应 boss 框体的顶部条上。
--
-- 解决多目标点击施法时的"我现在的 cast 是对着哪只？"困惑：
--   情景：点 boss A 放影箭（2.5s），施法过程中点 boss B 排队上 dot，
--   再点 boss C —— 中间手忙脚乱时容易忘记 A 的影箭还没落地。
--   现在 A 框体顶部的青条会一直填到 cast 结束，告诉你"还在 A 这边"。
--
-- 信号链：UNIT_SPELLCAST_SENT(target, ...) 给我们 cast 的目标名（本地化），
-- 匹配 btn.targetName 找到对应 boss 框，开始/结束/取消视觉条。
local addonName, MBT = ...

local pendingTargetName = nil   -- 最近一次 SENT 的目标名（本地化字符串）
local activeBtn = nil           -- 当前正在显示 cast 进度的框体

-- 按本地化名字找当前可见的 boss 框
local function findFrameByName(name)
    if not name or name == "" then return nil end
    for _, btn in pairs(MBT.BossFrames or {}) do
        if btn:IsShown() and btn.targetName == name then
            return btn
        end
    end
    return nil
end

local function startCastVisual(btn, duration)
    if not btn or not btn.playerCast then return end
    duration = math.max(duration or 0.001, 0.001)
    local pc = btn.playerCast
    pc:SetMinMaxValues(0, duration)
    pc:SetValue(0)
    pc.startTime = GetTime()
    pc.duration = duration
    pc.reverse = false
    pc:Show()
    if MBT.UpdateBossCastTextPosition then MBT.UpdateBossCastTextPosition(btn) end
    pc:SetScript("OnUpdate", function(self)
        local elapsed = GetTime() - self.startTime
        if elapsed >= self.duration then
            self:SetValue(self.reverse and 0 or self.duration)
            self:Hide()
            self:SetScript("OnUpdate", nil)
            -- 玩家条收起后，把 boss 施法名挪回中心
            if MBT.UpdateBossCastTextPosition then MBT.UpdateBossCastTextPosition(btn) end
            return
        end
        if self.reverse then
            self:SetValue(self.duration - elapsed)
        else
            self:SetValue(elapsed)
        end
    end)
end

-- 引导法术：填充方向反过来（剩余时间随条递减）
local function startChannelVisual(btn, duration)
    startCastVisual(btn, duration)
    if btn and btn.playerCast then
        btn.playerCast.reverse = true
        btn.playerCast:SetValue(duration)
    end
end

local function stopCastVisual(btn)
    if not btn or not btn.playerCast then return end
    btn.playerCast:Hide()
    btn.playerCast:SetScript("OnUpdate", nil)
    if MBT.UpdateBossCastTextPosition then MBT.UpdateBossCastTextPosition(btn) end
end

-- 瞬发法术（SENT 之后没有 START，直接 SUCCEEDED）：闪一下表示"刚 dot 了这只 boss"
local function flashCastVisual(btn)
    if not btn or not btn.playerCast then return end
    local pc = btn.playerCast
    pc:SetMinMaxValues(0, 1)
    pc:SetValue(1)
    pc.reverse = false
    pc:Show()
    pc:SetScript("OnUpdate", nil)
    if MBT.UpdateBossCastTextPosition then MBT.UpdateBossCastTextPosition(btn) end
    C_Timer.After(0.25, function()
        if pc:IsShown() then
            pc:Hide()
            if MBT.UpdateBossCastTextPosition then MBT.UpdateBossCastTextPosition(btn) end
        end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("UNIT_SPELLCAST_SENT")
f:RegisterEvent("UNIT_SPELLCAST_START")
f:RegisterEvent("UNIT_SPELLCAST_STOP")
f:RegisterEvent("UNIT_SPELLCAST_FAILED")
f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

f:SetScript("OnEvent", function(_, event, unit, ...)
    if unit ~= "player" then return end
    -- 用户关闭就完全不处理（哪怕事件来了也不画）
    if not (MBT.db and MBT.db.profile and MBT.db.profile.bShowPlayerCast) then return end

    if event == "UNIT_SPELLCAST_SENT" then
        -- arg1=unit(已 strip), arg2=targetName, arg3=castGUID, arg4=spellID
        pendingTargetName = ...
    elseif event == "UNIT_SPELLCAST_START" then
        local btn = findFrameByName(pendingTargetName)
        if btn then
            local _, _, _, startMS, endMS = UnitCastingInfo("player")
            local duration = (endMS and startMS) and (endMS - startMS) / 1000 or 1.5
            stopCastVisual(activeBtn)
            startCastVisual(btn, duration)
            activeBtn = btn
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local btn = findFrameByName(pendingTargetName)
        if btn then
            local _, _, _, startMS, endMS = UnitChannelInfo("player")
            local duration = (endMS and startMS) and (endMS - startMS) / 1000 or 1.5
            stopCastVisual(activeBtn)
            startChannelVisual(btn, duration)
            activeBtn = btn
        end
    elseif event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        stopCastVisual(activeBtn)
        activeBtn = nil
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if activeBtn then
            -- 读条 / 引导完成：bar 已经填满，直接收掉
            stopCastVisual(activeBtn)
            activeBtn = nil
        else
            -- 瞬发：SENT 后没 START，直接 SUCCEEDED —— 闪一下表示"刚落到这只 boss 上"
            local btn = findFrameByName(pendingTargetName)
            if btn then flashCastVisual(btn) end
        end
        pendingTargetName = nil
    end
end)

-- 用户从设置里关闭时，立刻收掉当前显示的条
MBT:RegisterMDFEvent("STATUS", function()
    if not (MBT.db.profile.bShowPlayerCast) and activeBtn then
        stopCastVisual(activeBtn)
        activeBtn = nil
    end
end)
