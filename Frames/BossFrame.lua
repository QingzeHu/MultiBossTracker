-- BossFrame: one row of UI per boss slot (A/B/C/D/E).
-- Contains icon, HP bar, cast bar, name text, DoT-icon row.
-- The container itself is a SecureActionButton — that's what's clicked for click-cast.
--
-- Visual style:
--   HP bar:    175x30, red 0.769/0.122/0.231/1, solid texture
--   Cast bar:  175x14, gold-ish, behind HP bar (14px 给字留够空间，玩家施法条覆盖底 4 时上方 10 仍可读)
--   Icon:      55x54 on the left, square
--   Backdrop:  black 0.4 alpha behind the whole row
--   Border:    1px black edge
--   DoT row:   stretches right of the bars, max ~6 icons of 26x26
local addonName, MBT = ...

MBT.BossFrames = {}     -- [frameID] = BossFrame
local FRAME_WIDTH  = 230
local FRAME_HEIGHT = 54
local ICON_SIZE    = 54
local HP_HEIGHT    = 30
local CAST_HEIGHT  = 14    -- boss 施法条高度。需≥10 让字显示，≤22 不撞 HP 中心的 name/百分比文字
local DOT_SIZE     = 32      -- DoT 图标边长 fallback（用户没改设置时的默认）
local MAX_DOT_SLOTS = 8

-- Compact 模式尺寸（紧凑外观）：单条窄血条 + 右侧贴近的 DoT 行
local COMPACT_HEIGHT     = 26     -- 行高（同时也是 DoT 图标尺寸基准）
local COMPACT_HP_WIDTH   = 200    -- 血条占的宽度
local COMPACT_DOT_SIZE   = 24     -- 紧凑模式下 DoT 图标尺寸（≤ COMPACT_HEIGHT）
local COMPACT_DOT_AREA   = 180    -- DoT 行总宽度

-- 给整个容器在紧凑模式下用的总宽度
local function totalWidth(compact)
    if compact then return COMPACT_HP_WIDTH + COMPACT_DOT_AREA + 4 end
    return ICON_SIZE + FRAME_WIDTH
end
MBT.BossFrameTotalWidth = totalWidth

-- 取当前 DoT 图标边长：完整模式从用户设置读，紧凑模式固定（受行高约束）
local function getDotSize(compact)
    if compact then return COMPACT_DOT_SIZE end
    return (MBT.db and MBT.db.profile and MBT.db.profile.iDotSize) or DOT_SIZE
end

local SOLID = "Interface\\Buttons\\WHITE8X8"

-- HP 条颜色：常态 / 高亮（当前 target）
local HP_COLOR_NORMAL    = { 0.62, 0.00, 0.00, 1 }
local HP_COLOR_HIGHLIGHT = { 0.90, 0.15, 0.15, 1 }

-- Format remaining time the WoW way
local function FormatTime(t)
    if t > 60 then return ("%dm"):format(math.floor(t / 60)) end
    if t > 10 then return ("%d"):format(math.floor(t)) end
    return ("%.1f"):format(t)
end

-- Build a single boss frame. parent should be MBT.containerFrame.
local function CreateBossFrame(frameID, parent)
    -- MoP Classic 5.5 起 Frame 不再原生持有 SetBackdrop，需要叠加 BackdropTemplate。
    -- 老 Classic 客户端没有 BackdropTemplate，但也不需要 —— 它们 Frame 自带 SetBackdrop。
    local templates = "SecureActionButtonTemplate"
    if BackdropTemplateMixin then templates = templates .. ", BackdropTemplate" end
    local btn = CreateFrame("Button", "MultiBossTracker_Slot" .. frameID, parent, templates)
    btn:SetSize(FRAME_WIDTH + ICON_SIZE, FRAME_HEIGHT)
    btn:RegisterForClicks("AnyUp")
    -- 记录最近一次点击：UI_ERROR_MESSAGE 收到 facing 错误时用来定位是哪个 boss 框点的
    -- 同时：如果这个 boss 处于"facing 模式"（最近有过 facing 错误），用户继续狂点视为继续在错
    --      → 直接刷新 1.5s 闪烁 + 续期模式过期时间。绕过 UI_ERROR_MESSAGE 的节流抑制
    btn:HookScript("OnClick", function(self)
        local now = GetTime()
        MBT._lastClickedFrameID = self.frameID
        MBT._lastClickedTime = now
        if self._facingModeExpiry and now < self._facingModeExpiry then
            self._facingModeExpiry = now + 5
            if MBT.RefreshFacingFlash then MBT.RefreshFacingFlash(self) end
        end
    end)
    btn:SetAttribute("*type1", "macro")
    btn:SetAttribute("*type2", "macro")
    btn:SetAttribute("*type3", "macro")
    btn:SetAttribute("*type4", "macro")
    btn:SetAttribute("*type5", "macro")
    btn.frameID = frameID

    -- 半透明黑色背景。靠透明度形成"块感"，不画边框 —— 边界靠间距和黑底来定义。
    local bd = btn:CreateTexture(nil, "BACKGROUND")
    bd:SetAllPoints(btn)
    bd:SetColorTexture(0, 0, 0, 0.75)
    btn.bd = bd

    -- 当前 target 高亮：4px 宽金色竖条贴在 btn 左边缘"外侧"（不和 3D 头像重叠）
    -- 1px 留作缝隙，让竖条像独立锚点而不是黏在框体上
    local accent = btn:CreateTexture(nil, "OVERLAY")
    accent:SetWidth(4)
    accent:SetPoint("TOPRIGHT", btn, "TOPLEFT", -1, 0)
    accent:SetPoint("BOTTOMRIGHT", btn, "BOTTOMLEFT", -1, 0)
    accent:SetColorTexture(1.0, 0.85, 0.30, 1)
    accent:Hide()
    btn.accent = accent

    -- Boss 头像区域：内含两个子组件，3D 模型 / 2D 贴图各一份，按用户设置 Show/Hide。
    -- compact 模式只 Hide 这个父 frame 即可，不用关心里面是哪种。
    local portraitFrame = CreateFrame("Frame", nil, btn)
    portraitFrame:SetSize(ICON_SIZE, FRAME_HEIGHT)
    portraitFrame:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    btn.icon = portraitFrame   -- 保留 .icon 给 compact 模式 Hide/Show 用
    btn.portraitFrame = portraitFrame

    -- 3D 模型（默认）
    local modelFrame = CreateFrame("PlayerModel", nil, portraitFrame)
    modelFrame:SetAllPoints(portraitFrame)
    btn.modelFrame = modelFrame

    -- 2D 静态头像（备选）
    local portrait2D = portraitFrame:CreateTexture(nil, "ARTWORK")
    portrait2D:SetAllPoints(portraitFrame)
    portrait2D:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- 裁掉边缘白边
    portrait2D:Hide()
    btn.portrait2D = portrait2D

    -- HP bar (右于图标，整行高度)
    -- 注意：HP 满高度填整个帧高，施法条作为 OVERLAY 叠在底部（见下）。
    -- 这样 boss 没读条时 HP 看起来一直是完整的一条，不留空白。
    local hp = CreateFrame("StatusBar", nil, btn)
    hp:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    hp:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 1, 0)
    hp:SetStatusBarTexture(SOLID)
    -- WoW 经典敌方单位的血红，调暗一档（原 0.78 → 0.62），更稳重不刺眼
    hp:SetStatusBarColor(unpack(HP_COLOR_NORMAL))
    hp:SetMinMaxValues(0, 100)
    hp:SetValue(100)
    -- HP bar background
    local hpbg = hp:CreateTexture(nil, "BACKGROUND")
    hpbg:SetAllPoints(hp)
    hpbg:SetColorTexture(0.15, 0.05, 0.05, 0.7)
    btn.hp = hp

    -- HP bar text overlay: name (left) + percent (right) + raid marker prefix
    local nameText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", hp, "LEFT", 4, 0)
    nameText:SetTextColor(1, 1, 1, 1)
    nameText:SetJustifyH("LEFT")
    btn.nameText = nameText

    local pctText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pctText:SetPoint("RIGHT", hp, "RIGHT", -4, 0)
    pctText:SetTextColor(1, 1, 1, 1)
    pctText:SetJustifyH("RIGHT")
    btn.pctText = pctText

    -- 状态提示文字：HP 内嵌右上角，单一 FontString 按状态切显示
    -- 状态："range" → 黄色"超出范围"（持续）；"facing" → 橙色"面对目标"（闪 1.5s）
    -- facing 闪烁期间优先级高于 range（更紧迫的信号）
    local statusText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPRIGHT", hp, "TOPRIGHT", -3, -2)
    statusText:SetText("")
    btn.statusText = statusText

    -- Cast bar — 叠在 HP 条底部 OVERLAY 层
    local cast = CreateFrame("StatusBar", nil, btn)
    cast:SetSize(FRAME_WIDTH, CAST_HEIGHT)
    cast:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", 0, 0)
    cast:SetFrameLevel(hp:GetFrameLevel() + 2)   -- 在 HP 之上
    cast:SetStatusBarTexture(SOLID)
    cast:SetStatusBarColor(0.85, 0.71, 0.20, 1)
    cast:SetMinMaxValues(0, 1)
    cast:SetValue(0)
    cast:Hide()
    local castbg = cast:CreateTexture(nil, "BACKGROUND")
    castbg:SetAllPoints(cast)
    castbg:SetColorTexture(0.1, 0.1, 0.1, 0.7)
    local castText = cast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    castText:SetPoint("CENTER", cast, "CENTER", 0, 0)
    castText:SetTextColor(1, 1, 1, 1)
    btn.cast = cast
    btn.castText = castText

    -- 玩家自己的施法条 —— 紧贴 boss 框下方（DoT 行上方那 4px），全宽青色条
    -- 多 boss 点击切换时一眼看出"我现在的 cast 是对着哪只"
    -- 锚点和宽度在 ApplyCompactMode 里按模式重设，这里只创建 widget
    local pcast = CreateFrame("StatusBar", nil, btn)
    pcast:SetSize(FRAME_WIDTH + ICON_SIZE, 4)
    pcast:SetFrameLevel(btn:GetFrameLevel() + 5)
    pcast:SetStatusBarTexture(SOLID)
    pcast:SetStatusBarColor(0.30, 0.85, 1.00, 1)   -- 亮青色
    pcast:SetMinMaxValues(0, 1)
    pcast:SetValue(0)
    local pcastBg = pcast:CreateTexture(nil, "BACKGROUND")
    pcastBg:SetAllPoints(pcast)
    pcastBg:SetColorTexture(0.05, 0.15, 0.20, 0.85)
    pcast:Hide()
    btn.playerCast = pcast

    -- DoT row container (below the row, attached to right of icon)
    local dotRow = CreateFrame("Frame", nil, btn)
    dotRow:SetSize(FRAME_WIDTH, getDotSize(false))
    dotRow:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", ICON_SIZE + 1, -2)
    btn.dotRow = dotRow
    btn.dotSlots = {}      -- [sSlotName] = slotFrame
    btn.dotSlotOrder = {}  -- ordered list of active slot names for layout

    -- Each DoT slot: texture + cooldown swipe + our own centered countdown text + stack count.
    local function CreateDotSlot()
        local f = CreateFrame("Frame", nil, dotRow)
        local s = getDotSize(btn.compact)
        f:SetSize(s, s)

        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints(f)
        t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        f.tex = t

        local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        cd:SetAllPoints(f)
        cd:SetDrawEdge(false)
        cd:SetDrawSwipe(true)              -- 雷达遮罩开着 —— 视觉上能看到时间走过的部分
        cd:SetDrawBling(false)             -- 结束时的闪光仍然关着（要的话改 true）
        cd:SetReverse(true)                -- DoT/BUFF 模式：暗色面积随剩余时间减少而增大
        cd:SetHideCountdownNumbers(true)   -- 我们自己画数字以保证居中
        f.cd = cd

        -- 把数字放到一个 frame level 比 swipe 更高的容器里，这样遮罩不会盖在数字上
        local textHolder = CreateFrame("Frame", nil, f)
        textHolder:SetAllPoints(f)
        textHolder:SetFrameLevel(cd:GetFrameLevel() + 10)

        -- 自渲染的倒计时数字（居中、永远不被遮罩压暗）
        local timeText = textHolder:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
        timeText:SetPoint("CENTER", textHolder, "CENTER", 0, 0)
        timeText:SetJustifyH("CENTER")
        timeText:SetTextColor(1, 1, 0.4, 1)
        -- 应用用户配置的字号
        local fp, _, ff = timeText:GetFont()
        timeText:SetFont(fp, MBT.db and MBT.db.profile.iDotTextSize or 14, ff)
        f.timeText = timeText

        local stacks = textHolder:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        stacks:SetPoint("BOTTOMRIGHT", textHolder, "BOTTOMRIGHT", -1, 1)
        stacks:SetTextColor(1, 1, 1, 1)
        f.stacks = stacks

        -- 满层高亮：用 Blizzard 原生的 ActionButton_ShowOverlayGlow / HideOverlayGlow
        -- 就是动作条上技能 proc 时那一圈金色脉动 + 火花特效，全游戏一致
        -- 不需要自定义贴图/动画 —— 在 UpdateSlotGlow 里直接调即可

        f:Hide()
        return f
    end
    btn.CreateDotSlot = CreateDotSlot

    -- The whole UI gets hidden when there's no boss for this slot.
    btn:Hide()

    return btn
end
MBT.CreateBossFrame = CreateBossFrame

-- 在紧凑/完整模式间切换布局。每次外观切换都会调用一次。
local function ApplyCompactMode(btn, compact)
    if compact then
        btn:SetSize(COMPACT_HP_WIDTH + COMPACT_DOT_AREA + 4, COMPACT_HEIGHT)
        btn.icon:Hide()
        btn.cast:Hide()

        -- HP 条改窄改高 + 占据左侧
        btn.hp:ClearAllPoints()
        btn.hp:SetSize(COMPACT_HP_WIDTH, COMPACT_HEIGHT)
        btn.hp:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

        -- DoT 行紧贴血条右边，同高
        btn.dotRow:ClearAllPoints()
        btn.dotRow:SetSize(COMPACT_DOT_AREA, COMPACT_HEIGHT)
        btn.dotRow:SetPoint("LEFT", btn.hp, "RIGHT", 4, 0)

        -- 玩家施法条：紧凑模式没有"框外空间"，贴在 HP 条最底 2px（HP 内 OVERLAY）
        btn.playerCast:ClearAllPoints()
        btn.playerCast:SetSize(COMPACT_HP_WIDTH, 2)
        btn.playerCast:SetPoint("BOTTOMLEFT", btn.hp, "BOTTOMLEFT", 0, 0)
    else
        btn:SetSize(ICON_SIZE + FRAME_WIDTH, FRAME_HEIGHT)
        btn.icon:Show()
        -- 施法条始终默认隐藏 —— 只有 CastDispatcher 收到真实读条事件才会 Show 出来
        btn.cast:Hide()

        btn.hp:ClearAllPoints()
        -- HP 填满整行高度（54），不再留 13px 空白
        btn.hp:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
        btn.hp:SetPoint("TOPLEFT", btn.icon, "TOPRIGHT", 1, 0)

        -- 施法条贴在 HP 条底部 OVERLAY 上
        btn.cast:ClearAllPoints()
        btn.cast:SetSize(FRAME_WIDTH, CAST_HEIGHT)
        btn.cast:SetPoint("BOTTOMLEFT", btn.hp, "BOTTOMLEFT", 0, 0)

        -- DoT 行紧贴 boss 框下方（恢复原位，无空隙）
        btn.dotRow:ClearAllPoints()
        btn.dotRow:SetSize(FRAME_WIDTH, getDotSize(false))
        btn.dotRow:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", ICON_SIZE + 1, -2)

        -- 玩家施法条：叠在 HP 条最底部，**最顶层 z-order**
        -- - 仅 HP 区域宽（不占头像区）
        -- - 4px 高，覆盖 boss 施法条底部 4px；boss 条上方 6px 仍可见
        -- - 单独显示时呈现纯青色 4px 条；与 boss 条同时显示时 stack 在底（青上、黄下藏在青条下方）
        --   但 boss 条 10 - 4 = 6px 仍然在青条上方露出来
        btn.playerCast:ClearAllPoints()
        btn.playerCast:SetSize(FRAME_WIDTH, 4)
        btn.playerCast:SetPoint("BOTTOMLEFT", btn.hp, "BOTTOMLEFT", 0, 0)
    end
    btn.compact = compact
    -- 现有 DoT 槽位也得跟着重新排
    for _, slot in pairs(btn.dotSlots) do
        local size = getDotSize(compact)
        slot:SetSize(size, size)
    end
    if MBT.LayoutDotRow then MBT.LayoutDotRow(btn) end
end
MBT.ApplyCompactMode = ApplyCompactMode

-- Layout DoT slots horizontally, sorted by iOrder.
local function LayoutDotRow(btn)
    local size = getDotSize(btn.compact)
    local order = {}
    for slot, sf in pairs(btn.dotSlots) do
        if sf:IsShown() then
            table.insert(order, { slot = slot, frame = sf, iOrder = sf.iOrder or 999 })
        end
    end
    table.sort(order, function(a, b) return a.iOrder < b.iOrder end)
    for i, entry in ipairs(order) do
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("LEFT", btn.dotRow, "LEFT", (i-1) * (size + 2), 0)
    end
end
MBT.LayoutDotRow = LayoutDotRow

-- Wipe all DoT slots on this frame (called on zone change).
local function ClearDots(btn)
    for slot, f in pairs(btn.dotSlots) do
        f:Hide()
        f.iOrder = nil
        f.cd:Clear()
    end
end
MBT.ClearDots = ClearDots

-- 用户改了 DoT 排序后，从最新的 spellInfos 拉一遍 iOrder 重排所有现存槽位。
-- 不用等下次 DoT 刷新就能看到顺序变化。
function MBT:RefreshAllDotOrders()
    local cd = MBT.formattedClassData
    if not cd or not cd.tSpellsInfos then return end
    for _, btn in pairs(MBT.BossFrames or {}) do
        for _, slot in pairs(btn.dotSlots or {}) do
            if slot.spellName then
                local info = cd.tSpellsInfos[slot.spellName]
                if info and info.iOrder then
                    slot.iOrder = info.iOrder
                end
            end
        end
        if MBT.LayoutDotRow then MBT.LayoutDotRow(btn) end
    end
end

-- 滑动条调整 DoT 图标尺寸时调用：重新设置每个 boss 的 dotRow 高度 + 所有现存槽位大小，再 relayout
function MBT:UpdateDotSize()
    for _, btn in pairs(MBT.BossFrames or {}) do
        local size = getDotSize(btn.compact)
        if not btn.compact then
            btn.dotRow:SetSize(FRAME_WIDTH, size)
        end
        for _, slot in pairs(btn.dotSlots) do
            slot:SetSize(size, size)
        end
        if MBT.LayoutDotRow then MBT.LayoutDotRow(btn) end
    end
end

-- 让所有已创建的 DoT 槽位重新应用配置里的字号（滑动条调整时调用）
function MBT:UpdateDotTextSize()
    local size = (MBT.db and MBT.db.profile.iDotTextSize) or 14
    for _, btn in pairs(MBT.BossFrames or {}) do
        for _, slot in pairs(btn.dotSlots) do
            if slot.timeText then
                local fp, _, ff = slot.timeText:GetFont()
                slot.timeText:SetFont(fp, size, ff)
            end
        end
    end
end

-- 单一 OnUpdate 周期性更新所有 DoT 槽位的倒计时数字（节流 0.05s = 20Hz）。
local cdUpdater = CreateFrame("Frame")
local cdAccum = 0
cdUpdater:SetScript("OnUpdate", function(_, elapsed)
    cdAccum = cdAccum + elapsed
    if cdAccum < 0.05 then return end
    cdAccum = 0
    local now = GetTime()
    for _, btn in pairs(MBT.BossFrames) do
        for _, slot in pairs(btn.dotSlots) do
            if slot:IsShown() and slot.expirationTime then
                local rem = slot.expirationTime - now
                if rem > 0 then
                    if rem >= 60 then
                        slot.timeText:SetText(("%dm"):format(math.ceil(rem / 60)))
                    elseif rem >= 10 then
                        slot.timeText:SetText(("%d"):format(math.floor(rem)))
                    else
                        slot.timeText:SetText(("%.1f"):format(rem))
                    end
                else
                    slot.timeText:SetText("")
                end
            else
                if slot.timeText then slot.timeText:SetText("") end
            end
        end
    end
end)

-- LibCustomGlow（WeakAuras / ElvUI 通用 glow 库）
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-- 单个 DoT 槽位高亮：仅当 spell 配了 iGlowAtStacks 时启用
-- 当前没有任何 spell 用这个 —— 印记的"双 6 终结技"信号走 combo glow（见下）
local function UpdateSlotGlow(slot, threshold, stacks)
    if not slot or not LCG then return end
    local shouldOn = threshold and stacks and stacks >= threshold
    if shouldOn then
        if not slot.glowOn then
            LCG.AutoCastGlow_Start(slot, {0.95, 0.95, 0.32, 1}, 4, 0.5, 1, 0, 0, "fullstack")
            slot.glowOn = true
        end
    else
        if slot.glowOn then
            LCG.AutoCastGlow_Stop(slot, "fullstack")
            slot.glowOn = false
        end
    end
end

-- Boss 框体级 combo 高亮：多个 DoT 同时满足条件 → 整框亮起特效
-- 数据驱动 —— 读 tAuraData.tComboGlows，所以扩展到其它职业零代码
local function startComboGlow(btn, c)
    if c.sStyle == "pixel" then
        LCG.PixelGlow_Start(btn, c.tColor, c.iDots or 8, c.fFrequency or 0.5, nil, c.iThickness or 2, 0, 0, false, c.sName)
    elseif c.sStyle == "button" then
        LCG.ButtonGlow_Start(btn, c.tColor, c.fFrequency or 0.125)
    else  -- autocast 默认
        LCG.AutoCastGlow_Start(btn, c.tColor, 4, c.fFrequency or 0.5, 1, 0, 0, c.sName)
    end
end

local function stopComboGlow(btn, c)
    if c.sStyle == "pixel" then
        LCG.PixelGlow_Stop(btn, c.sName)
    elseif c.sStyle == "button" then
        LCG.ButtonGlow_Stop(btn)
    else
        LCG.AutoCastGlow_Stop(btn, c.sName)
    end
end

local function UpdateBossComboGlow(btn)
    if not LCG or not btn then return end
    local cd = MBT.formattedClassData
    if not cd or not cd.tComboGlows then return end
    btn.comboGlows = btn.comboGlows or {}

    for _, combo in ipairs(cd.tComboGlows) do
        local allReady = true
        for _, spellName in ipairs(combo.tSpells) do
            local slot = btn.dotSlots and btn.dotSlots[spellName]
            local stacks = (slot and slot:IsShown()) and (slot.stackCount or 0) or 0
            if stacks < (combo.iAtStacks or 1) then
                allReady = false
                break
            end
        end

        if allReady and not btn.comboGlows[combo.sName] then
            startComboGlow(btn, combo)
            btn.comboGlows[combo.sName] = true
        elseif not allReady and btn.comboGlows[combo.sName] then
            stopComboGlow(btn, combo)
            btn.comboGlows[combo.sName] = nil
        end
    end
end

-- Apply a "package" payload onto the frame's slot ("Add" semantics).
local function ApplyDotAdd(btn, pkg)
    local slot = btn.dotSlots[pkg.sSlotName]
    if not slot then
        slot = btn.CreateDotSlot()
        btn.dotSlots[pkg.sSlotName] = slot
    end
    slot.tex:SetTexture(pkg.icon)
    slot.spellName = pkg.sSpellName    -- 记下当前展示的具体咒语，方便排序变更时重读 iOrder
    slot.iOrder = pkg.iOrder or 999
    -- DoT 存在时 -> 显示原始图标颜色（不染色）。过期后由 ApplyDotRemove 改成灰色。
    slot.tex:SetVertexColor(1, 1, 1)
    slot:Show()
    -- Cooldown swipe + 记录到期时间给 OnUpdate 用
    if pkg.duration and pkg.expirationTime then
        slot.cd:SetCooldown(pkg.expirationTime - pkg.duration, pkg.duration)
        slot.expirationTime = pkg.expirationTime
    else
        slot.expirationTime = nil
        slot.timeText:SetText("")
    end
    -- 初始 APPLY 时如果 boss 身上已经多层（部分技能首次 apply 就带层数），从 pkg.iStacks 读
    slot.stackCount = pkg.iStacks or 1
    slot.stacks:SetText(pkg.iStacks and tostring(pkg.iStacks) or "")
    UpdateSlotGlow(slot, pkg.iGlowAtStacks, pkg.iStacks)
    UpdateBossComboGlow(btn)
    LayoutDotRow(btn)
end
MBT.ApplyDotAdd = ApplyDotAdd

local function ApplyDotRefresh(btn, pkg)
    local slot = btn.dotSlots[pkg.sSlotName]
    if not slot or not slot:IsShown() then return end
    if pkg.duration and pkg.expirationTime then
        slot.cd:SetCooldown(pkg.expirationTime - pkg.duration, pkg.duration)
        slot.expirationTime = pkg.expirationTime
    end
end
MBT.ApplyDotRefresh = ApplyDotRefresh

local function ApplyDotRemove(btn, pkg)
    local slot = btn.dotSlots[pkg.sSlotName]
    if not slot then return end
    -- DoT 移除：层数清零，高亮收掉，combo 重新评估
    slot.stackCount = 0
    UpdateSlotGlow(slot, nil, nil)
    UpdateBossComboGlow(btn)
    if MBT.db.profile.bShowMissingDoTs and not pkg.bForceClear then
        slot.tex:SetVertexColor(0.4, 0.4, 0.4)
        slot.cd:Clear()
        slot.expirationTime = nil
        slot.timeText:SetText("")
    else
        slot:Hide()
        slot.iOrder = nil
        slot.expirationTime = nil
        slot.timeText:SetText("")
        LayoutDotRow(btn)
    end
end
MBT.ApplyDotRemove = ApplyDotRemove

local function ApplyDotStack(btn, pkg)
    local slot = btn.dotSlots[pkg.sSlotName]
    if not slot then return end
    slot.stackCount = pkg.iStacks or 1
    slot.stacks:SetText(pkg.iStacks and pkg.iStacks > 1 and tostring(pkg.iStacks) or "")
    UpdateSlotGlow(slot, pkg.iGlowAtStacks, pkg.iStacks)
    UpdateBossComboGlow(btn)
end
MBT.ApplyDotStack = ApplyDotStack

-- 把某个 boss 框体设为"当前 target"高亮（血条变亮 + 左侧金色竖条）
function MBT:HighlightFrame(btn, on)
    if not btn then return end
    if on then
        btn.hp:SetStatusBarColor(unpack(HP_COLOR_HIGHLIGHT))
        if btn.accent then btn.accent:Show() end
    else
        btn.hp:SetStatusBarColor(unpack(HP_COLOR_NORMAL))
        if btn.accent then btn.accent:Hide() end
    end
end

-- 根据当前玩家 target 的 NPCID 决定哪个框体高亮
function MBT:UpdateTargetHighlight()
    local guid = UnitGUID("target")
    local targetNPCID = guid and select(6, strsplit("-", guid)) or nil
    for _, btn in pairs(MBT.BossFrames or {}) do
        local match = btn:IsShown() and btn.npcID and btn.npcID == targetNPCID
        MBT:HighlightFrame(btn, match)
    end
end

-- 切换 3D / 2D 头像模式（应用到所有框体）。在选项 toggle 时调用。
function MBT:ApplyPortraitMode()
    local use3D = MBT.db and MBT.db.profile.bUse3DPortrait
    if use3D == nil then use3D = true end
    for _, btn in pairs(MBT.BossFrames or {}) do
        if use3D then
            btn.modelFrame:Show()
            btn.portrait2D:Hide()
        else
            btn.modelFrame:Hide()
            btn.portrait2D:Show()
        end
    end
end

-- Update the frame to reflect new boss data (called on MultiBossTracker_ChangeZone).
local function ApplyZoneSlot(btn, slotData)
    if not slotData or not slotData.sNPCID then
        btn:Hide()
        if btn.modelFrame then btn.modelFrame:ClearModel() end
        if btn.portrait2D then btn.portrait2D:SetTexture("") end
        btn.lastModelUnit = nil
        btn.lastPortraitUnit = nil
        ClearDots(btn)
        return
    end
    btn:Show()
    btn.npcID = slotData.sNPCID
    btn.targetName = slotData.sTarName
    -- 清掉之前的 boss 头像；HealthUpdater 找到 unit token 后会喂新数据
    if btn.modelFrame then btn.modelFrame:ClearModel() end
    if btn.portrait2D then btn.portrait2D:SetTexture("") end
    btn.lastModelUnit = nil
    btn.lastPortraitUnit = nil
    -- 切换 boss 时清掉旧高亮，下次 UpdateTargetHighlight 会重新判断
    MBT:HighlightFrame(btn, false)
    btn.nameText:SetText(slotData.sTarName or "?")
    btn.hp:SetValue(100)
    btn.pctText:SetText("100%")
    btn.cast:Hide()
    ClearDots(btn)
end
MBT.ApplyZoneSlot = ApplyZoneSlot

-- Update HP for a unit (called on MultiBossTracker_UpdateHealth).
local function UpdateHealthFromUnit(btn, unit)
    if not unit or not UnitExists(unit) then return end
    local maxHp = UnitHealthMax(unit)
    if not maxHp or maxHp == 0 then return end
    local pct = UnitHealth(unit) / maxHp * 100
    btn.hp:SetValue(pct)
    btn.pctText:SetText(("%d%%"):format(pct))
    -- Real name (in case the boss was renamed during fight, e.g. Saurfang)
    btn.nameText:SetText(UnitName(unit) or btn.targetName or "?")
    if pct <= 0 then
        btn.hp:SetValue(0)
        btn.pctText:SetText("")
    end

    -- 顺便更新头像 —— 3D 模型和 2D 贴图都更新，这样切换模式立即生效。
    if btn.modelFrame and btn.lastModelUnit ~= unit then
        btn.modelFrame:SetUnit(unit)
        if btn.modelFrame.SetPortraitZoom then
            btn.modelFrame:SetPortraitZoom(1)   -- 头肩特写
        end
        if btn.modelFrame.RefreshCamera then
            btn.modelFrame:RefreshCamera()
        end
        btn.lastModelUnit = unit
    end
    if btn.portrait2D and btn.lastPortraitUnit ~= unit then
        SetPortraitTexture(btn.portrait2D, unit)
        btn.lastPortraitUnit = unit
    end
end
MBT.UpdateHealthFromUnit = UpdateHealthFromUnit

-- 根据玩家施法条是否在显示，调整 boss 施法名的垂直位置
-- - 玩家没施法：文字在 boss 条 10px 中心（y 偏移 0）
-- - 玩家正施法：文字上移到 boss 条上方 6px 区域中心，避免被覆盖（y 偏移 +2）
local function UpdateBossCastTextPosition(btn)
    if not btn or not btn.castText then return end
    btn.castText:ClearAllPoints()
    if btn.playerCast and btn.playerCast:IsShown() then
        btn.castText:SetPoint("CENTER", btn.cast, "CENTER", 0, 2)
    else
        btn.castText:SetPoint("CENTER", btn.cast, "CENTER", 0, 0)
    end
end
MBT.UpdateBossCastTextPosition = UpdateBossCastTextPosition

-- Cast bar drive
local function StartCast(btn, pkg)
    btn.cast:SetMinMaxValues(0, math.max(pkg.iDuration or 1, 0.01))
    btn.cast:SetValue(0)
    btn.cast.startTime = GetTime()
    btn.cast.endTime   = pkg.iExpirationTime
    btn.castText:SetText(pkg.sSpellName or "")
    btn.cast:Show()
    UpdateBossCastTextPosition(btn)
    btn.cast:SetScript("OnUpdate", function(self)
        if not self.endTime then self:Hide(); return end
        local now = GetTime()
        if now >= self.endTime then
            self:SetValue(self:GetMinMaxValues() ~= 0 and select(2, self:GetMinMaxValues()) or 1)
            self:Hide()
            self:SetScript("OnUpdate", nil)
            return
        end
        self:SetValue(now - self.startTime)
    end)
end
MBT.StartCast = StartCast

local function EndCast(btn, pkg)
    btn.castText:SetText(pkg and pkg.sSpellName or "")
    btn.cast:Hide()
    btn.cast:SetScript("OnUpdate", nil)
end
MBT.EndCast = EndCast
