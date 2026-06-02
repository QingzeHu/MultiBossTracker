-- Layout: top-level container that holds the 5 boss frames, handles dragging, and wires
-- the dispatched events into per-frame UI updates.
local addonName, MBT = ...

local FRAME_IDS = MBT.FRAME_IDS

-- 初始化用：容器和首次 frame 放置时用的占位尺寸（实际尺寸由 getRowHeight/getRowGap 决定）
local INIT_ROW_H = 54
local INIT_ROW_GAP = 40

-- 行高 / 行间距：动态随 iDotSize 缩放（像素风格唯一样式）
-- iSkin: 1=极简（单行）/ 2=标准（双行带头像）
local DEFAULT_FRAME_GAP   = 40
local COMPACT_GAP         = 6      -- 极简行间距固定，省空间
local HP_HEIGHT_MIN       = 30     -- 标准模式 HP 最小高度（DoT 更大时 HP 跟着涨）
local BORDER              = 1      -- 1px 黑边

local function isCompact() return MBT.db.profile.iSkin == 1 end
local function getDotSize() return MBT.db.profile.iDotSize or 32 end

local function getRowHeight()
    -- 优先读真实 frame 高度 —— applyStandard/Compact 已把 pip 行加高算进去了
    -- 这样不用在两处重复 pip 高度逻辑，且 pip 显隐切换时间距自动跟上
    local btn = MBT.BossFrames and MBT.BossFrames["A"]
    if btn then
        local h = btn:GetHeight()
        if h and h > 0 then return h end
    end
    -- 兜底：frames 还没被 ApplyCompactMode 跑过时（理论上不会发生，STATUS 必先布局）
    local d = getDotSize()
    if isCompact() then return d + BORDER * 2 end
    local hpH = math.max(HP_HEIGHT_MIN, d)
    return BORDER + hpH + BORDER + d + BORDER
end

local function getRowGap()
    if isCompact() then return COMPACT_GAP end
    return MBT.db.profile.fRowGap or DEFAULT_FRAME_GAP
end

-- Root container: invisible parent that we move/anchor + drag.
local container = CreateFrame("Frame", "MultiBossTracker_Container", UIParent)
container:SetSize(300, INIT_ROW_H * 5 + INIT_ROW_GAP * 5)
container:SetMovable(true)
container:SetClampedToScreen(true)

local function ApplyAnchor()
    container:ClearAllPoints()
    local a = MBT.db.profile.anchor
    container:SetPoint(a.point or "CENTER", UIParent, a.relPoint or "CENTER", a.x or 0, a.y or 0)
end
MBT.ApplyAnchor = ApplyAnchor

-- 拖动条：解锁时显示在容器顶部的"标题栏"风格条带，长得就像窗口标题栏。
-- 用户从这里点击拖动，比把整个容器染色直观得多。
local dragBar = CreateFrame("Frame", nil, container,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
dragBar:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 4)
dragBar:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 0, 4)
dragBar:SetHeight(20)
dragBar:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
})
dragBar:SetBackdropColor(0.18, 0.13, 0.05, 0.92)        -- 暗金棕背景
dragBar:SetBackdropBorderColor(0.75, 0.55, 0.20, 1)     -- 浅金属金边

-- 标题文字 + 两侧 grip dots，明显是"标题栏"
local label = dragBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
-- WoW 字体的 baseline 比几何中心稍偏下，垂直居中要往上挪 1px 视觉才正
label:SetPoint("CENTER", dragBar, "CENTER", 0, 1)
label:SetText("多目标 Boss 追踪")
label:SetTextColor(1, 0.85, 0.4, 1)

-- 鼠标悬停时浅高亮，提供"可点击"反馈
local hoverHL = dragBar:CreateTexture(nil, "ARTWORK")
hoverHL:SetAllPoints(dragBar)
hoverHL:SetColorTexture(1, 0.85, 0.3, 0.10)
hoverHL:Hide()

dragBar:EnableMouse(true)
dragBar:RegisterForDrag("LeftButton")
dragBar:SetScript("OnEnter", function() hoverHL:Show() end)
dragBar:SetScript("OnLeave", function() hoverHL:Hide() end)
dragBar:SetScript("OnDragStart", function()
    if not MBT.db.profile.bLocked then container:StartMoving() end
end)
dragBar:SetScript("OnDragStop", function()
    container:StopMovingOrSizing()
    local cx, cy = container:GetCenter()
    local px, py = UIParent:GetCenter()
    if cx and cy and px and py then
        MBT.db.profile.anchor = {
            point    = "CENTER",
            relPoint = "CENTER",
            x        = cx - px,
            y        = cy - py,
        }
        ApplyAnchor()
    end
end)

-- 创建时先隐藏，避免插件加载到 STATUS 事件之间那一帧的视觉闪烁
-- STATUS handler 会按 db.bLocked 重设：默认 bLocked = false → 拖动条 Show，可拖动
dragBar:Hide()
container.dragBar = dragBar

local function SetLocked(locked)
    MBT.db.profile.bLocked = locked
    if locked then dragBar:Hide() else dragBar:Show() end
end
MBT.SetLocked = SetLocked

MBT.containerFrame = container

-- Build the 5 boss frames inside the container, vertically.
for i, fid in ipairs(FRAME_IDS) do
    local btn = MBT.CreateBossFrame(fid, container)
    btn:ClearAllPoints()
    -- Default arrangement: top to bottom. bReverseGrowth flips below.
    btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -((i - 1) * (INIT_ROW_H + INIT_ROW_GAP)))
    MBT.BossFrames[fid] = btn
end

local function ReanchorRows()
    -- btn 是 SecureActionButton，战斗中无法 SetPoint —— 排队等出战
    if InCombatLockdown() then MBT:DeferIfInCombat(ReanchorRows); return end
    local rowH = getRowHeight()
    local rowGap = getRowGap()

    -- 收集"可见"的 boss 框体，按数据顺序
    local visibles = {}
    for _, fid in ipairs(FRAME_IDS) do
        local btn = MBT.BossFrames[fid]
        if btn:IsShown() then
            table.insert(visibles, btn)
        end
    end
    -- 反向堆叠 = 把可见列表反序（不反方向，永远从容器顶部往下排）
    if MBT.db.profile.bReverseGrowth then
        local reversed = {}
        for i = #visibles, 1, -1 do
            table.insert(reversed, visibles[i])
        end
        visibles = reversed
    end
    -- 永远从容器 TOPLEFT 紧贴往下排，没有可见的就跳过位置（不留空）
    for i, btn in ipairs(visibles) do
        btn:ClearAllPoints()
        local yOff = (i - 1) * (rowH + rowGap)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -yOff)
    end
end
MBT.ReanchorRows = ReanchorRows

-- 把容器收缩到刚好包住所有框体（不留尾部空白）
local function ResizeContainer()
    local rowH = getRowHeight()
    local rowGap = getRowGap()
    -- 高度按"可见框数"算，但保留 5 行基准：
    -- - 常规副本 ≤5 个目标 → n=5，容器尺寸与历史版本完全一致，不影响已有锚点/布局。
    -- - 阵营冠军 >5 个目标 → 容器跟着长高，刚好包住所有可见框。
    local visible = 0
    for _, fid in ipairs(FRAME_IDS) do
        local btn = MBT.BossFrames[fid]
        if btn and btn:IsShown() then visible = visible + 1 end
    end
    local n = math.max(visible, 5)
    local h = n * rowH + (n - 1) * rowGap
    -- 宽度按当前框体实际宽度取最大（每种样式宽度不同）
    local w = 0
    for _, fid in ipairs(FRAME_IDS) do
        local bw = MBT.BossFrames[fid]:GetWidth()
        if bw > w then w = bw end
    end
    if w == 0 then w = 320 end
    container:SetSize(w, h)
end
MBT.ResizeContainer = ResizeContainer

-- Apply compact mode to all 5 frames + reanchor.
-- ApplyCompactMode 会 btn:SetSize，战斗中无法执行 —— 排队等出战
local function ApplyCompactToAll()
    if InCombatLockdown() then MBT:DeferIfInCombat(ApplyCompactToAll); return end
    local compact = isCompact()
    for _, fid in ipairs(FRAME_IDS) do
        MBT.ApplyCompactMode(MBT.BossFrames[fid], compact)
    end
    ReanchorRows()
    ResizeContainer()
end
MBT.ApplyCompactToAll = ApplyCompactToAll

-- IMPORTANT: AceDB isn't ready yet at file load time — these all read MBT.db.profile.
-- Defer to STATUS, which Core fires from OnEnable (i.e. after OnInitialize set MBT.db).
MBT:RegisterMDFEvent("STATUS", function()
    ApplyAnchor()
    ApplyCompactToAll()
    if MBT.ApplyPortraitMode then MBT:ApplyPortraitMode() end
    -- 透明模式：框体创建时 db 还没就绪（读到的永远是默认不透明），这里按真实配置补应用一次
    if MBT.ApplyBackgroundOpacity then MBT:ApplyBackgroundOpacity() end
    -- 拖动条按 db 里的锁定状态显示/隐藏
    if MBT.db.profile.bLocked then container.dragBar:Hide() else container.dragBar:Show() end
end)

-- ---------------------------------------------------------------------
-- Wire dispatcher events into UI updates.
-- ---------------------------------------------------------------------

MBT:RegisterMDFEvent("MultiBossTracker_ChangeZone", function(_, zoneName, tZoneData)
    -- tZoneData is a table { ["A"]={...}, ["B"]={...}, ... } or nil for "no zone match".
    -- Cache for click-cast refresh on later binding changes.
    MBT.lastZoneData = tZoneData
    if not tZoneData then
        for _, fid in ipairs(FRAME_IDS) do MBT.BossFrames[fid]:Hide() end
        ResizeContainer()
        return
    end
    for _, fid in ipairs(FRAME_IDS) do
        MBT.ApplyZoneSlot(MBT.BossFrames[fid], tZoneData[fid])
    end
    ReanchorRows()
    -- 可见框数可能随编码（尤其阵营冠军动态阵容）变化 —— 重算容器高度
    ResizeContainer()
    -- Tell ClickCast to refresh secure macros for all visible frames now that the boss names changed.
    MBT:FireEvent("MultiBossTracker_RefreshClickCast", tZoneData)
end)

MBT:RegisterMDFEvent("MultiBossTracker_UpdateHealth", function(_, npcID, unit)
    for _, fid in ipairs(FRAME_IDS) do
        local btn = MBT.BossFrames[fid]
        if btn:IsShown() and btn.npcID == npcID then
            MBT.UpdateHealthFromUnit(btn, unit)
        end
    end
end)

MBT:RegisterMDFEvent("MultiBossTracker_DoTUpdate", function(_, sub, frameID, pkg)
    local btn = MBT.BossFrames[frameID]
    if not btn or not btn:IsShown() then return end
    if sub == "Add"     then MBT.ApplyDotAdd(btn, pkg)
    elseif sub == "Remove"  then MBT.ApplyDotRemove(btn, pkg)
    elseif sub == "Refresh" then MBT.ApplyDotRefresh(btn, pkg)
    elseif sub == "Stack"   then MBT.ApplyDotStack(btn, pkg)
    end
end)

MBT:RegisterMDFEvent("MultiBossTracker_CastStarted", function(_, frameID, pkg)
    local btn = MBT.BossFrames[frameID]
    if btn and btn:IsShown() then MBT.StartCast(btn, pkg) end
end)
MBT:RegisterMDFEvent("MultiBossTracker_CastEnded", function(_, frameID, pkg)
    local btn = MBT.BossFrames[frameID]
    if btn then MBT.EndCast(btn, pkg) end
end)

-- formatter 完成后（每次 STATUS / Bindings/Blacklist 变化都会跑），重排现存 DoT 槽位
MBT:RegisterMDFEvent("MultiBossTracker_ClassData_Formatted", function()
    if MBT.RefreshAllDotOrders then MBT:RefreshAllDotOrders() end
end)

-- Lock change & anchor reset
MBT:RegisterMDFEvent("MultiBossTracker_LockChanged", function(_, locked) SetLocked(locked) end)
MBT:RegisterMDFEvent("MultiBossTracker_AnchorReset", function() ApplyAnchor() end)

-- Light HP smoothing — re-poll the focused/primary unit on UNIT_HEALTH for whichever boss is targeted.
local hpFrame = CreateFrame("Frame")
hpFrame:RegisterEvent("UNIT_HEALTH")
hpFrame:RegisterEvent("UNIT_HEALTH_FREQUENT")
hpFrame:SetScript("OnEvent", function(_, _, unit)
    if not unit then return end
    local guid = UnitGUID(unit)
    if not guid then return end
    local npcID = select(6, strsplit("-", guid))
    if not npcID then return end
    for _, fid in ipairs(FRAME_IDS) do
        local btn = MBT.BossFrames[fid]
        if btn:IsShown() and btn.npcID == npcID then
            MBT.UpdateHealthFromUnit(btn, unit)
        end
    end
end)

-- 玩家切换 target 时刷新高亮（哪个框体对应当前 target，亮血条 + 左竖条）
local targetFrame = CreateFrame("Frame")
targetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
targetFrame:SetScript("OnEvent", function() MBT:UpdateTargetHighlight() end)
-- 区域 / 遭遇切换后也重判一次（boss 阵容可能变了）
MBT:RegisterMDFEvent("MultiBossTracker_ChangeZone", function() MBT:UpdateTargetHighlight() end)

-- 天赋/spec 切换：旧天赋的 DoT 不再可被刷新，全量清空 + 按新 spec 重排（pip 行可能出现/消失）
-- PLAYER_SPECIALIZATION_CHANGED 带 unit 参数，只关心 player 自己
-- 事件触发时 GetSpecialization() 可能仍返回旧 spec —— 100ms 后再跑 layout，确保读到新值
local specFrame = CreateFrame("Frame")
specFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
specFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
local pendingSpecRefresh = false
local function refreshForSpecChange()
    pendingSpecRefresh = false
    for _, fid in ipairs(FRAME_IDS) do
        local btn = MBT.BossFrames[fid]
        if btn and MBT.ClearDots then MBT.ClearDots(btn) end
    end
    -- ApplyCompactToAll → applyStandard/Compact → pipRow Show/Hide + UpdatePipsForBoss
    ApplyCompactToAll()
end
specFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
    if pendingSpecRefresh then return end
    pendingSpecRefresh = true
    C_Timer.After(0.1, refreshForSpecChange)
end)
