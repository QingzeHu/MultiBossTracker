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
local MAX_DOT_SLOTS = 8

-- 像素风格尺寸（唯一样式）
-- 极简（单行）：行高 = DoT + 2px 边，HP 高 = DoT，HP 宽 160，DoT 7 个 + 6 个 2px gap
-- 标准（双行）：行高 = 1 + HP + 1 + DoT + 1，头像方块 = 行高 - 2，HP 高 = max(30, DoT)
local COMPACT_HP_WIDTH   = 160
local STANDARD_HP_WIDTH  = 200
local STANDARD_HP_HEIGHT_MIN = 30
local STANDARD_CAST_HEIGHT = 10        -- overlay 在 HP 底
local DOT_GAP            = 2
local BORDER_PX          = 1            -- 元素内缩量 = bd 黑底漏出形成"1px 硬边框"

local HP_COLOR_NORMAL    = { 0.78, 0.18, 0.20, 1 }   -- 饱和深红
local HP_COLOR_HIGHLIGHT = { 0.95, 0.30, 0.30, 1 }   -- 当前 target 高亮（更亮）
local CAST_COLOR         = { 0.96, 0.78, 0.27, 1 }   -- 暖琥珀
local PCAST_COLOR        = { 0.30, 0.85, 1.00, 1 }   -- 玩家施法条青色

-- Stack pips（印记层数指示器）尺寸
local PIP_H              = 13    -- 单格高（上段 6 + 中间 1px 黑 gap + 下段 6）
local PIP_HALF_H         = 6     -- 每段高（top + bot 各画 6px，中间留 1px 露黑底）
local PIP_GAP            = 2     -- 格与格水平间距
local PIP_MIN_W          = 10    -- 单格最小宽度兜底（极窄框时）
local PIP_TEXT_W         = 32    -- 单个数字预留宽（"6/6" 14pt OUTLINE 约 28-30px）
local PIP_TEXT_GAP       = 4     -- 两个数字之间间距
local PIP_TEXT_PAD       = 6     -- 第二个数字右边到首个 pip 之间的间距
local PIP_MAX_DEFAULT    = 8     -- 预创建 pip widget 上限（覆盖常见 iMaxStacks）
local PIP_INSET_Y        = 1     -- pip 行底部上抬量（暗影段下方留 1px 黑底当"间隔"）
local PIP_DARK           = { 0.10, 0.10, 0.10 }   -- 未点亮段颜色
local PIP_FONT_SIZE      = 14

-- channelRow 复用 pip 行的同一块底部空间（同 spec 不会同时激活，channel 是痛苦专属、pip 是毁灭专属）
-- 共用 PIP_H / PIP_INSET_Y / indicatorExtraH
local CHANNEL_DMG_FONT_SIZE = 12
local CHANNEL_BAR_BG_RGBA   = { 0.05, 0.02, 0.08, 0.75 }
local CHANNEL_TICK_RGBA     = { 0, 0, 0, 1 }
local CHANNEL_HAUNT_RGBA    = { 1, 0, 0, 1 }

-- DoT 尺寸（响应用户 iDotSize）—— 16-48 clamp
local function getDotSize()
    local d = (MBT.db and MBT.db.profile and MBT.db.profile.iDotSize) or 20
    if d < 16 then d = 16 end
    if d > 48 then d = 48 end
    return d
end
local function dotArea(d) return d * 7 + DOT_GAP * 6 end

-- 标准模式 HP 宽度：默认 200 / DoT 行更宽时跟着涨（保持视觉对齐）
local function standardContentW(d) return math.max(STANDARD_HP_WIDTH, dotArea(d)) end
-- 标准模式 HP 高度：默认 30 / DoT 更大时 HP 跟着涨保持比例
local function standardHpHeight(d) return math.max(STANDARD_HP_HEIGHT_MIN, d) end

-- 给整个容器用的总宽度
local function totalWidth(compact)
    local d = getDotSize()
    if compact then
        return COMPACT_HP_WIDTH + dotArea(d) + 6   -- 1L + HP + 2mid + DoT + 1R
    end
    local rowH = BORDER_PX * 3 + standardHpHeight(d) + d
    local portrait = rowH - BORDER_PX * 2
    return portrait + standardContentW(d) + BORDER_PX * 3
end
MBT.BossFrameTotalWidth = totalWidth

local SOLID = "Interface\\Buttons\\WHITE8X8"

-- HP 条颜色：常态 / 高亮（当前 target）
local HP_COLOR_NORMAL    = { 0.62, 0.00, 0.00, 1 }
local HP_COLOR_HIGHLIGHT = { 0.90, 0.15, 0.15, 1 }

-- 透明模式下血条区域的分层透明度。血条 = 黑底 + 暗红底 + 红色填充三层叠加，
-- 必须每层单独调透才有效（只调整帧 alpha 时三层叠加后仍接近不透明，看不出透）：
--   黑底 / 暗红底 → HP_TRANSPARENT_BG_ALPHA（很透 → 掉血的部分能清楚透出场景）
--   红色填充 / 文字 → 跟随 hp 整帧 alpha = HP_TRANSPARENT_ALPHA（稍微透一点）
local HP_TRANSPARENT_ALPHA    = 0.7
local HP_TRANSPARENT_BG_ALPHA = 0.25
-- HP 条暗红底色（不透明模式的基准值；透明模式下 alpha 换成 HP_TRANSPARENT_BG_ALPHA）
local HP_BG_RGBA = { 0.15, 0.05, 0.05, 0.7 }

-- Format remaining time the WoW way
local function FormatTime(t)
    if t > 60 then return ("%dm"):format(math.floor(t / 60)) end
    if t > 10 then return ("%d"):format(math.floor(t)) end
    return ("%.1f"):format(t)
end

-- 单个 boss 框应用/取消透明模式。创建末尾和开关切换时共用，保证两条路径状态一致。
-- 只改贴图 alpha / 显隐，不动尺寸/锚点，战斗中也能安全执行。
local function ApplyFrameTransparency(btn, transparent)
    -- 整框黑底：透明模式下完全隐去 → DoT 区域 / 元素缝隙透出场景
    if btn.bd then btn.bd:SetColorTexture(0, 0, 0, transparent and 0 or 1) end
    -- 血条三层分别调透：黑底 + 暗红底调到很透（掉血部分透场景），红色填充和文字跟整帧 alpha 稍微透
    if btn.hpBd then
        btn.hpBd:SetColorTexture(0, 0, 0, HP_TRANSPARENT_BG_ALPHA)
        btn.hpBd:SetShown(transparent)
    end
    if btn.hpbg then
        btn.hpbg:SetColorTexture(HP_BG_RGBA[1], HP_BG_RGBA[2], HP_BG_RGBA[3],
            transparent and HP_TRANSPARENT_BG_ALPHA or HP_BG_RGBA[4])
    end
    if btn.hp then btn.hp:SetAlpha(transparent and HP_TRANSPARENT_ALPHA or 1) end
    -- 头像 / 印记行 / 引导条：透明模式下用各自的实心局部黑底兜底
    if btn.portraitBd then btn.portraitBd:SetShown(transparent) end
    if btn.pipRowBd then btn.pipRowBd:SetShown(transparent) end
    if btn.channelRowBd then btn.channelRowBd:SetShown(transparent) end
end

-- Build a single boss frame. parent should be MBT.containerFrame.
local function CreateBossFrame(frameID, parent)
    -- MoP Classic 5.5 起 Frame 不再原生持有 SetBackdrop，需要叠加 BackdropTemplate。
    -- 老 Classic 客户端没有 BackdropTemplate，但也不需要 —— 它们 Frame 自带 SetBackdrop。
    local templates = "SecureActionButtonTemplate"
    if BackdropTemplateMixin then templates = templates .. ", BackdropTemplate" end
    local btn = CreateFrame("Button", "MultiBossTracker_Slot" .. frameID, parent, templates)
    btn:SetSize(260, 60)   -- 占位尺寸，ApplyCompactMode 在 STATUS 时立刻覆盖
    -- 显式列出 5 个按钮的 Up + Down，避免某些 Classic 客户端 "AnyUp/AnyDown" 不包含 Button4/5 的边界情况。
    -- 同时注册 Down：暴雪 DF 后把 ActionButtonUseKeyDown CVar 默认值改成 1，安全派发层会按 CVar
    -- 匹配 down 状态，只接 Up 时该 CVar=1 的用户点击不会触发宏。两边都接，CVar 任意值都派发一次。
    btn:RegisterForClicks(
        "LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up",
        "LeftButtonDown", "RightButtonDown", "MiddleButtonDown", "Button4Down", "Button5Down"
    )
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

    -- 全黑不透明背景。元素内缩 1px 让 bd 黑底从边缘漏出，形成 1px"硬边框"
    -- 透明模式（bTransparentBG）的处理统一在 ApplyFrameTransparency（CreateBossFrame 末尾调用）
    local bd = btn:CreateTexture(nil, "BACKGROUND")
    bd:SetAllPoints(btn)
    bd:SetColorTexture(0, 0, 0, 1)
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
    portraitFrame:SetSize(54, 54)   -- 占位
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

    -- 透明模式下头像区域的局部黑底（外扩 1px 保留"硬边框"观感）。
    -- 挂在 portraitFrame 下 → 紧凑模式 icon:Hide() 时自动跟着隐藏，不会在没头像的位置留黑块
    local portraitBd = portraitFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
    portraitBd:SetPoint("TOPLEFT", portraitFrame, "TOPLEFT", -1, 1)
    portraitBd:SetPoint("BOTTOMRIGHT", portraitFrame, "BOTTOMRIGHT", 1, -1)
    portraitBd:SetColorTexture(0, 0, 0, 1)
    portraitBd:Hide()
    btn.portraitBd = portraitBd

    -- 团标（团长设置的星星/圈圈/菱形等）
    -- holder 直接挂 btn 上、frame level 抬到所有元素之上（盖在 3D 模型 / glow 之上都行）
    -- 位置 + 尺寸由 applyStandard / applyCompact 各自重置：
    --   标准：贴在头像左上角内部，1/4 头像大小
    --   紧凑：贴在 btn 左外侧、当前 target 黄竖线的左边
    local markerHolder = CreateFrame("Frame", nil, btn)
    markerHolder:SetFrameLevel(btn:GetFrameLevel() + 10)
    local markerIcon = markerHolder:CreateTexture(nil, "OVERLAY")
    markerIcon:SetAllPoints(markerHolder)
    -- 关键：必须先把团标图集文件挂上。本客户端（5.4.3）的 SetRaidTargetIconTexture
    -- 只设 TexCoord、不设贴图文件 —— 不预先 SetTexture 的话贴图为空，永远渲染不出来。
    markerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    markerIcon:Hide()
    btn.markerHolder = markerHolder
    btn.markerIcon = markerIcon

    -- HP bar (右于图标，整行高度)
    -- 注意：HP 满高度填整个帧高，施法条作为 OVERLAY 叠在底部（见下）。
    -- 这样 boss 没读条时 HP 看起来一直是完整的一条，不留空白。
    local hp = CreateFrame("StatusBar", nil, btn)
    hp:SetSize(200, 30)   -- 占位
    hp:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)   -- 占位锚点
    hp:SetStatusBarTexture(SOLID)
    -- WoW 经典敌方单位的血红，调暗一档（原 0.78 → 0.62），更稳重不刺眼
    hp:SetStatusBarColor(unpack(HP_COLOR_NORMAL))
    hp:SetMinMaxValues(0, 100)
    hp:SetValue(100)
    -- HP bar background（透明模式下 alpha 由 ApplyFrameTransparency 调低）
    local hpbg = hp:CreateTexture(nil, "BACKGROUND")
    hpbg:SetAllPoints(hp)
    hpbg:SetColorTexture(unpack(HP_BG_RGBA))
    btn.hpbg = hpbg
    -- 透明模式下 HP 条的局部底板（外扩 1px 保留"硬边框"轮廓）
    -- 锚到 hp 自身 → applyCompact/applyStandard 移动血条时自动跟随，不用单独维护
    local hpBd = hp:CreateTexture(nil, "BACKGROUND", nil, -1)
    hpBd:SetPoint("TOPLEFT", hp, "TOPLEFT", -1, 1)
    hpBd:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", 1, -1)
    hpBd:SetColorTexture(0, 0, 0, 1)
    hpBd:Hide()
    btn.hpBd = hpBd
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
    -- 字号比默认 GameFontNormal 小 2pt（→ Small），避免和 pctText 在右侧纵向重合
    local statusText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOPRIGHT", hp, "TOPRIGHT", -3, -2)
    statusText:SetText("")
    btn.statusText = statusText

    -- Cast bar — 叠在 HP 条底部 OVERLAY 层
    local cast = CreateFrame("StatusBar", nil, btn)
    cast:SetSize(200, 14)   -- 占位
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
    pcast:SetSize(200, 4)   -- 占位
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

    -- DoT row container（占位，ApplyCompactMode 会重设位置和尺寸）
    local dotRow = CreateFrame("Frame", nil, btn)
    dotRow:SetSize(200, 32)
    dotRow:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    btn.dotRow = dotRow
    btn.dotSlots = {}      -- [sSlotName] = slotFrame
    btn.dotSlotOrder = {}  -- ordered list of active slot names for layout

    -- 印记/层数指示器行：tStackPips 配置驱动。尺寸由 applyStandard/applyCompact 重置。
    -- 每格 = 上下两段贴图（中间留 1px 露黑底当分隔），独立亮灭显示各自 stacks
    -- 左侧两个数字 "X/N Y/N"（上印记色 / 下印记色）。pip 块在右侧拉伸填满 frame 宽。
    local pipRow = CreateFrame("Frame", nil, btn)
    pipRow:Hide()
    btn.pipRow = pipRow
    pipRow.pips = {}

    -- 透明模式下印记 pip 行的局部黑底（外扩 1px）。挂在 pipRow 下 → 行隐藏时自动跟着隐藏
    local pipRowBd = pipRow:CreateTexture(nil, "BACKGROUND", nil, -1)
    pipRowBd:SetPoint("TOPLEFT", pipRow, "TOPLEFT", -1, 1)
    pipRowBd:SetPoint("BOTTOMRIGHT", pipRow, "BOTTOMRIGHT", 1, -1)
    pipRowBd:SetColorTexture(0, 0, 0, 1)
    pipRowBd:Hide()
    btn.pipRowBd = pipRowBd

    local function makePipText(xOffset, r, g, b)
        local t = pipRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("LEFT", pipRow, "LEFT", xOffset, 0)
        t:SetJustifyH("LEFT")
        t:SetFont(t:GetFont(), PIP_FONT_SIZE, "OUTLINE")
        t:SetTextColor(r, g, b, 1)
        return t
    end
    pipRow.text1 = makePipText(2, 0.98, 0.35, 0.10)                                    -- 余烬橙
    pipRow.text2 = makePipText(2 + PIP_TEXT_W + PIP_TEXT_GAP, 0.55, 0.30, 0.95)        -- 暗影紫（提亮版；原色配 OUTLINE 在黑底上几乎看不见）

    -- 创建 PIP_MAX_DEFAULT 个 pip widget；位置/宽度由 LayoutPipRow 在 layout 时计算
    -- 上下两段纹理用 LEFT+RIGHT 锚点，宽度自动跟随父 pip frame，无需手动 SetSize
    for i = 1, PIP_MAX_DEFAULT do
        local p = CreateFrame("Frame", nil, pipRow)
        p:SetHeight(PIP_H)
        local top = p:CreateTexture(nil, "ARTWORK")
        top:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
        top:SetHeight(PIP_HALF_H)
        top:SetColorTexture(PIP_DARK[1], PIP_DARK[2], PIP_DARK[3], 1)
        p.top = top
        local bot = p:CreateTexture(nil, "ARTWORK")
        bot:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
        bot:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
        bot:SetHeight(PIP_HALF_H)
        bot:SetColorTexture(PIP_DARK[1], PIP_DARK[2], PIP_DARK[3], 1)
        p.bot = bot
        pipRow.pips[i] = p
    end

    -- 引导技能条（痛苦术专属）：跟 pipRow 占同一块底部空间，由 spec gating 互斥显示
    -- bar 从右往左倒数（默认 SetValue 方向）；4 条固定 tick + 1 条动态 Haunt 红线 + 右端伤害数字
    local channelRow = CreateFrame("Frame", nil, btn)
    channelRow:Hide()
    btn.channelRow = channelRow

    -- 透明模式下吸取灵魂引导条的局部黑底（外扩 1px）。同 pipRowBd，跟随行显隐
    local channelRowBd = channelRow:CreateTexture(nil, "BACKGROUND", nil, -1)
    channelRowBd:SetPoint("TOPLEFT", channelRow, "TOPLEFT", -1, 1)
    channelRowBd:SetPoint("BOTTOMRIGHT", channelRow, "BOTTOMRIGHT", 1, -1)
    channelRowBd:SetColorTexture(0, 0, 0, 1)
    channelRowBd:Hide()
    btn.channelRowBd = channelRowBd

    -- bar：TOP/BOTTOM 永远贴 channelRow 顶底；LEFT/RIGHT 在 layout 时设（紧凑全宽 / 标准让出标签宽度）
    local bar = CreateFrame("StatusBar", nil, channelRow)
    bar:SetPoint("TOP", channelRow, "TOP", 0, 0)
    bar:SetPoint("BOTTOM", channelRow, "BOTTOM", 0, 0)
    bar:SetPoint("RIGHT", channelRow, "RIGHT", 0, 0)
    bar:SetPoint("LEFT", channelRow, "LEFT", 0, 0)
    bar:SetStatusBarTexture(SOLID)
    bar:SetStatusBarColor(0.40, 0.10, 0.55, 1)   -- 占位色，UpdateChannelBar 会按配置覆盖
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    channelRow.bar = bar

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints(bar)
    barBg:SetColorTexture(CHANNEL_BAR_BG_RGBA[1], CHANNEL_BAR_BG_RGBA[2], CHANNEL_BAR_BG_RGBA[3], CHANNEL_BAR_BG_RGBA[4])

    -- 标签（位置/宽度由 LayoutChannelRow 设）
    -- 必须创建在 bar 上而不是 channelRow —— 因为 bar 的 statusbar 纹理会盖住 channelRow 的 OVERLAY 层，
    -- 而 bar 自己的 OVERLAY 层永远在 bar 内容之上。dmgText/ticks 也是同样原因都建在 bar 上
    local channelLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetJustifyH("CENTER")
    local lfp = channelLabel:GetFont()
    if lfp then channelLabel:SetFont(lfp, 10, "OUTLINE") end
    channelLabel:SetTextColor(1, 1, 1, 1)
    channelLabel:SetText("")
    channelRow.label = channelLabel

    -- 4 条固定分隔线（按 iTickCount-1 创建，最多 8 条覆盖常见情况）
    -- 宽度 2px：1px 纹理在 UI 缩放下会落到亚像素位置被抗锯齿成"忽粗忽细"，2px 在任何缩放下都稳定可见
    channelRow.ticks = {}
    for i = 1, 8 do
        local t = bar:CreateTexture(nil, "OVERLAY")
        t:SetSize(2, PIP_H)
        t:SetColorTexture(CHANNEL_TICK_RGBA[1], CHANNEL_TICK_RGBA[2], CHANNEL_TICK_RGBA[3], CHANNEL_TICK_RGBA[4])
        t:Hide()
        channelRow.ticks[i] = t
    end

    -- Haunt 续断标记（红色，2px 宽）
    local hauntTick = bar:CreateTexture(nil, "OVERLAY")
    hauntTick:SetSize(2, PIP_H)
    hauntTick:SetColorTexture(CHANNEL_HAUNT_RGBA[1], CHANNEL_HAUNT_RGBA[2], CHANNEL_HAUNT_RGBA[3], CHANNEL_HAUNT_RGBA[4])
    hauntTick:Hide()
    channelRow.hauntTick = hauntTick

    -- 伤害数字（右端内侧，OUTLINE 抗黑底）
    local dmgText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dmgText:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    dmgText:SetJustifyH("RIGHT")
    local dfp = dmgText:GetFont()
    if dfp then dmgText:SetFont(dfp, CHANNEL_DMG_FONT_SIZE, "OUTLINE") end
    dmgText:SetTextColor(1, 1, 0.6, 1)
    dmgText:SetText("")
    channelRow.dmgText = dmgText

    -- Each DoT slot: texture + cooldown swipe + our own centered countdown text + stack count.
    local function CreateDotSlot()
        local f = CreateFrame("Frame", nil, dotRow)
        local s = getDotSize()
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
        -- 应用用户配置的字号（0 = 隐藏数字，交给 OmniCC 等插件显示）
        local dotTextSize = MBT.db and MBT.db.profile.iDotTextSize or 14
        if dotTextSize > 0 then
            local fp, _, ff = timeText:GetFont()
            timeText:SetFont(fp, dotTextSize, ff)
        else
            timeText:Hide()
        end
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

    -- 透明模式初始状态。注：插件加载阶段 MBT.db 还是 nil（读到 false = 不透明），
    -- 真实配置由 Layout 的 STATUS handler 调 MBT:ApplyBackgroundOpacity() 补应用
    ApplyFrameTransparency(btn, (MBT.db and MBT.db.profile.bTransparentBG) and true or false)

    -- The whole UI gets hidden when there's no boss for this slot.
    btn:Hide()

    return btn
end
MBT.CreateBossFrame = CreateBossFrame

-- 当前激活的职业 tStackPips 配置（无 = 不画 pip 行）。仅在 layout 计算时读，无副作用。
-- 配置可选 fnEnabled() —— 返回 false（含 nil）时视为不激活（用于天赋/spec 门控）
local function getPipConfig()
    local cd = MBT.formattedClassData
    local cfg = cd and cd.tStackPips
    if not cfg then return nil end
    if cfg.fnEnabled and not cfg.fnEnabled() then return nil end
    return cfg
end
-- 同上，channel bar 配置（痛苦术专属）
local function getChannelConfig()
    local cd = MBT.formattedClassData
    local cfg = cd and cd.tChannelBar
    if not cfg then return nil end
    if cfg.fnEnabled and not cfg.fnEnabled() then return nil end
    return cfg
end
MBT.GetChannelConfig = getChannelConfig
-- 底部指示器额外占用的垂直空间。pip 行 / channel 行复用同一块空间（不同 spec 互斥），
-- 任一激活就加高
local function pipExtraH()
    if getPipConfig() or getChannelConfig() then return PIP_H + PIP_INSET_Y end
    return 0
end

-- 布局 channelRow：
--   labelW > 0：左 labelW 给标签（标准模式 = 头像列下方），右边给 bar
--   labelW = 0：bar 全宽（紧凑模式），label 盖在 bar 内部左端，伤害数字仍在右端
-- 同时画 N-1 条固定 tick 分隔线（在 bar 上、按宽度比例）
local function LayoutChannelRow(btn, cfg, labelW)
    local cr = btn and btn.channelRow
    if not cr or not cfg then return end

    -- bar 锚点：LEFT 让出 labelW，RIGHT 贴 channelRow 右边
    cr.bar:ClearAllPoints()
    cr.bar:SetPoint("LEFT", cr, "LEFT", labelW or 0, 0)
    cr.bar:SetPoint("RIGHT", cr, "RIGHT", 0, 0)
    cr.bar:SetPoint("TOP", cr, "TOP", 0, 0)
    cr.bar:SetPoint("BOTTOM", cr, "BOTTOM", 0, 0)

    -- 标签：两种模式都显示，但位置不同（切换时要重新锚点）
    cr.label:ClearAllPoints()
    if labelW and labelW > 0 then
        -- 标准模式：占 portrait 列下方，居中
        cr.label:SetPoint("LEFT", cr, "LEFT", 0, 0)
        cr.label:SetPoint("TOP", cr, "TOP", 0, 0)
        cr.label:SetPoint("BOTTOM", cr, "BOTTOM", 0, 0)
        cr.label:SetWidth(labelW)
        cr.label:SetJustifyH("CENTER")
    else
        -- 紧凑模式：盖在 bar 内部左端，左对齐；宽度 80 给右端伤害数字留位
        cr.label:SetPoint("LEFT", cr.bar, "LEFT", 4, 0)
        cr.label:SetPoint("TOP", cr.bar, "TOP", 0, 0)
        cr.label:SetPoint("BOTTOM", cr.bar, "BOTTOM", 0, 0)
        cr.label:SetWidth(80)
        cr.label:SetJustifyH("LEFT")
    end
    cr.label:SetText(cfg.sLabel or GetSpellInfo(cfg.iSpellID) or "")
    cr.label:Show()

    -- 配置色刷新（StatusBar 主色 + 伤害数字色）
    local c = cfg.tBarColor
    if c then cr.bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1) end
    local dc = cfg.tDamageColor
    if dc then cr.dmgText:SetTextColor(dc[1], dc[2], dc[3], dc[4] or 1) end

    -- N-1 条分隔线（按 bar 实际宽度等分）
    local barW = cr.bar:GetWidth()
    local n = cfg.iTickCount or 5
    for i = 1, #cr.ticks do
        local t = cr.ticks[i]
        if i < n then
            t:ClearAllPoints()
            t:SetPoint("LEFT", cr.bar, "LEFT", math.floor(barW * i / n), 0)
            t:Show()
        else
            t:Hide()
        end
    end
end

-- 给定 pipRow（已 SetSize），把 N 个 pip widget 等宽拉伸排满右侧剩余空间
-- 纹理宽度通过 LEFT+RIGHT 锚点自动跟随 pip frame，这里只管 pip 自己的宽度和锚点
-- labelW：左侧文字区宽度（含两个数字 + 中间 gap + 右 padding）。pip 块从 labelW 开始
--   • 标准模式调用方传 b + portraitW，让 pip 块跟 HP 条左边像素对齐、文字区跟头像同宽
--   • 紧凑模式或没传值时回退到默认（两个 26px 文字 + gap + pad = 64px）
local PIP_FIRST_X_DEFAULT = 2 + PIP_TEXT_W + PIP_TEXT_GAP + PIP_TEXT_W + PIP_TEXT_PAD
local function LayoutPipRow(btn, n, labelW)
    labelW = labelW or PIP_FIRST_X_DEFAULT

    -- 把 labelW 平分给两个文字（减左 pad 和中间 gap）
    local textPadL = 2
    local eachTextW = math.max(8, math.floor((labelW - textPadL - PIP_TEXT_GAP) / 2))

    btn.pipRow.text1:ClearAllPoints()
    btn.pipRow.text1:SetPoint("LEFT", btn.pipRow, "LEFT", textPadL, 0)
    btn.pipRow.text1:SetWidth(eachTextW)
    btn.pipRow.text1:SetJustifyH("CENTER")

    btn.pipRow.text2:ClearAllPoints()
    btn.pipRow.text2:SetPoint("LEFT", btn.pipRow, "LEFT", textPadL + eachTextW + PIP_TEXT_GAP, 0)
    btn.pipRow.text2:SetWidth(eachTextW)
    btn.pipRow.text2:SetJustifyH("CENTER")

    -- pip 块从 labelW 开始
    local rowW = btn.pipRow:GetWidth()
    local pipW = math.floor((rowW - labelW - (n - 1) * PIP_GAP) / n)
    if pipW < PIP_MIN_W then pipW = PIP_MIN_W end
    for i = 1, PIP_MAX_DEFAULT do
        local p = btn.pipRow.pips[i]
        if i <= n then
            p:ClearAllPoints()
            p:SetWidth(pipW)
            p:SetPoint("LEFT", btn.pipRow, "LEFT", labelW + (i-1) * (pipW + PIP_GAP), 0)
            p:Show()
        else
            p:Hide()
        end
    end
end

-- ===== 极简（单行）—— 行高随 iDotSize 缩放 =====
local function applyCompact(btn)
    local b = BORDER_PX
    local d = getDotSize()
    local pipH = pipExtraH()                   -- 0（无配置）/ PIP_H + PIP_INSET_Y
    local rowH = d + b * 2 + pipH               -- 行高 = DoT + 上下 1px 边 (+ pip 行)
    local hpH  = d                              -- HP 同高（贴齐 DoT）
    local da = dotArea(d)
    local W = COMPACT_HP_WIDTH + da + b * 2 + 2
    btn:SetSize(W, rowH)
    btn.icon:Hide()
    btn.cast:Hide()

    btn.hp:ClearAllPoints()
    btn.hp:SetSize(COMPACT_HP_WIDTH, hpH)
    btn.hp:SetPoint("TOPLEFT", btn, "TOPLEFT", b, -b)
    btn.hp:SetStatusBarColor(unpack(HP_COLOR_NORMAL))

    btn.dotRow:ClearAllPoints()
    btn.dotRow:SetSize(da, hpH)
    btn.dotRow:SetPoint("LEFT", btn.hp, "RIGHT", 2, 0)

    btn.playerCast:ClearAllPoints()
    btn.playerCast:SetSize(COMPACT_HP_WIDTH, 1)
    btn.playerCast:SetPoint("BOTTOMLEFT", btn.hp, "BOTTOMLEFT", 0, 0)
    btn.playerCast:SetStatusBarColor(unpack(PCAST_COLOR))

    -- 团标：紧凑模式没头像，挂在 btn 左外侧 accent（黄竖线）的左边
    -- accent 占 btn 外 -5..-1（4px 宽 + 1px 缝隙），团标右边贴到 -6 留 1px 间距
    if btn.markerHolder then
        local m = hpH
        btn.markerHolder:ClearAllPoints()
        btn.markerHolder:SetSize(m, m)
        btn.markerHolder:SetPoint("RIGHT", btn, "LEFT", -6, 0)
    end

    -- pip 行 —— 在底部、HP 下方
    if btn.pipRow then
        local pipCfg = getPipConfig()
        if pipCfg then
            btn.pipRow:ClearAllPoints()
            btn.pipRow:SetSize(W - b * 2, PIP_H)
            btn.pipRow:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", b, PIP_INSET_Y)
            btn.pipRow:Show()
            -- 紧凑模式：文字区 = HP 宽 + 2px gap，让 pip 块从 DoT 区起始位置开始
            LayoutPipRow(btn, pipCfg.iMaxStacks, COMPACT_HP_WIDTH + 2)
            if MBT.UpdatePipsForBoss then MBT.UpdatePipsForBoss(btn) end
        else
            btn.pipRow:Hide()
        end
    end
    -- channel 行：跟 pip 行占同一位置，互斥（不同 spec）
    -- 紧凑模式：bar 全宽，无标签
    if btn.channelRow then
        local chCfg = getChannelConfig()
        if chCfg then
            btn.channelRow:ClearAllPoints()
            btn.channelRow:SetSize(W - b * 2, PIP_H)
            btn.channelRow:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", b, PIP_INSET_Y)
            LayoutChannelRow(btn, chCfg, 0)
        else
            btn.channelRow:Hide()
            btn.channelRow.startTime = nil
            btn.channelRow.endTime = nil
        end
    end

    btn.compact = true
    for _, slot in pairs(btn.dotSlots) do slot:SetSize(d, d) end
end

-- ===== 标准（双行，带头像 + boss 施法条 overlay）—— 整行随 iDotSize 缩放 =====
local function applyStandard(btn)
    local b = BORDER_PX
    local d = getDotSize()
    local pipH = pipExtraH()                          -- 0（无配置）/ PIP_H + PIP_INSET_Y
    local hpH = standardHpHeight(d)                   -- HP 高度 = max(30, DoT)
    local rowH = b + hpH + b + d + b + pipH           -- 1 + HP + 1 + DoT + 1 (+ pip + 1)
    local portraitH = b + hpH + d                     -- 头像盖 HP+DoT 区域（= rowH - 2b - pipH，pip 在头像下方占整行宽）
    local portraitW = portraitH                       -- 正方形
    local portraitX = b
    local hpX = portraitX + portraitW + b
    local da = dotArea(d)
    local hpW = standardContentW(d)                   -- HP 宽 = max(默认 200, DoT 行宽)
    local W = hpX + hpW + b

    btn:SetSize(W, rowH)

    btn.icon:Show()
    btn.icon:ClearAllPoints()
    btn.icon:SetSize(portraitW, portraitH)
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", portraitX, -b)

    -- 团标：挂在 btn 左外侧 accent（黄竖线）的左边，跟紧凑模式一致 ——
    -- 不再贴头像左上角，避免被 3D 头像模型挡住看不见。
    -- accent 占 btn 外 -5..-1（4px 宽 + 1px 缝隙），团标右边贴到 -6 留 1px 间距，竖直居中。
    if btn.markerHolder then
        local m = math.min(hpH, 22)
        btn.markerHolder:ClearAllPoints()
        btn.markerHolder:SetSize(m, m)
        btn.markerHolder:SetPoint("RIGHT", btn, "LEFT", -6, 0)
    end

    btn.hp:ClearAllPoints()
    btn.hp:SetSize(hpW, hpH)
    btn.hp:SetPoint("TOPLEFT", btn, "TOPLEFT", hpX, -b)
    btn.hp:SetStatusBarColor(unpack(HP_COLOR_NORMAL))

    btn.cast:ClearAllPoints()
    btn.cast:SetSize(hpW, STANDARD_CAST_HEIGHT)
    btn.cast:SetPoint("BOTTOMLEFT", btn.hp, "BOTTOMLEFT", 0, 0)
    btn.cast:SetStatusBarColor(unpack(CAST_COLOR))
    btn.cast:Hide()   -- dispatcher 按事件 Show

    btn.playerCast:ClearAllPoints()
    btn.playerCast:SetSize(hpW, 1)
    btn.playerCast:SetPoint("BOTTOMLEFT", btn.hp, "BOTTOMLEFT", 0, 0)
    btn.playerCast:SetStatusBarColor(unpack(PCAST_COLOR))

    btn.dotRow:ClearAllPoints()
    btn.dotRow:SetSize(da, d)
    btn.dotRow:SetPoint("TOPLEFT", btn.hp, "BOTTOMLEFT", 0, -b)

    -- pip 行 —— 在底部内侧、DoT 下方
    if btn.pipRow then
        local pipCfg = getPipConfig()
        if pipCfg then
            btn.pipRow:ClearAllPoints()
            btn.pipRow:SetSize(W - b * 2, PIP_H)
            btn.pipRow:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", b, PIP_INSET_Y)
            btn.pipRow:Show()
            -- 标准模式：文字区宽度 = 头像列宽，让右侧 pip 块跟 HP 条左边对齐
            LayoutPipRow(btn, pipCfg.iMaxStacks, b + portraitW)
            if MBT.UpdatePipsForBoss then MBT.UpdatePipsForBoss(btn) end
        else
            btn.pipRow:Hide()
        end
    end
    -- channel 行：跟 pip 行占同一位置，互斥（不同 spec）
    -- 标准模式：labelW = b + portraitW，让 bar 的左边跟 HP 条左边对齐，标签区在头像下方
    if btn.channelRow then
        local chCfg = getChannelConfig()
        if chCfg then
            btn.channelRow:ClearAllPoints()
            btn.channelRow:SetSize(W - b * 2, PIP_H)
            btn.channelRow:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", b, PIP_INSET_Y)
            LayoutChannelRow(btn, chCfg, b + portraitW)
        else
            btn.channelRow:Hide()
            -- spec 切走时如果正在引导，强制收掉
            btn.channelRow.startTime = nil
            btn.channelRow.endTime = nil
        end
    end

    btn.compact = false
    for _, slot in pairs(btn.dotSlots) do slot:SetSize(d, d) end
end

-- 在极简/标准之间切换布局。每次切换或样式调整都会调用。
local function ApplyCompactMode(btn, compact)
    if compact then applyCompact(btn) else applyStandard(btn) end
    if MBT.LayoutDotRow then MBT.LayoutDotRow(btn) end
end
MBT.ApplyCompactMode = ApplyCompactMode

-- Layout DoT slots horizontally, sorted by iOrder.
local function LayoutDotRow(btn)
    local size = getDotSize()
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

-- 滑动条调整 DoT 图标尺寸时调用：DoT 变了 → 重新跑 ApplyCompactMode 即可
-- （像素布局所有尺寸都从 getDotSize 现算，整框会自动跟着重排）
function MBT:UpdateDotSize()
    for _, btn in pairs(MBT.BossFrames or {}) do
        local size = getDotSize()
        for _, slot in pairs(btn.dotSlots) do
            slot:SetSize(size, size)
        end
        if MBT.LayoutDotRow then MBT.LayoutDotRow(btn) end
    end
end

-- 透明模式开关切换 / 插件初始化（STATUS）/ profile 切换时调用：
-- 所有现存 boss 框立刻按配置应用透明状态。逐帧逻辑见 ApplyFrameTransparency。
function MBT:ApplyBackgroundOpacity()
    local transparent = (MBT.db and MBT.db.profile.bTransparentBG) and true or false
    for _, btn in pairs(MBT.BossFrames or {}) do
        ApplyFrameTransparency(btn, transparent)
    end
end

-- 让所有已创建的 DoT 槽位重新应用配置里的字号（滑动条调整时调用）
-- 字号 0 = 隐藏自绘数字（交给 OmniCC 等插件显示）；SetFont 不能传 0，所以用 Hide/Show 切换
function MBT:UpdateDotTextSize()
    local size = (MBT.db and MBT.db.profile.iDotTextSize) or 14
    for _, btn in pairs(MBT.BossFrames or {}) do
        for _, slot in pairs(btn.dotSlots) do
            if slot.timeText then
                if size > 0 then
                    local fp, _, ff = slot.timeText:GetFont()
                    slot.timeText:SetFont(fp, size, ff)
                    slot.timeText:Show()
                else
                    slot.timeText:Hide()
                end
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

-- 更新 boss 框底部 pip 行：读两个印记当前层数 → 染色每格上下两段 + 写两个 X/N 文字
-- 数据驱动 —— 任何职业的 tStackPips 配好就跑
-- 不检查 :IsShown() —— 黑名单中的 pip-tracked 咒语 slot 是隐藏的但 stackCount 真实
-- DoT 自然移除时 ApplyDotRemove 会把 stackCount 重置为 0，所以隐藏 slot 取到的值仍正确
local function readStacks(slot)
    return slot and (slot.stackCount or 0) or 0
end
local function paintSeg(tex, on, c)
    if on then tex:SetColorTexture(c[1], c[2], c[3], 1)
    else       tex:SetColorTexture(PIP_DARK[1], PIP_DARK[2], PIP_DARK[3], 1) end
end
local function UpdatePipsForBoss(btn)
    if not btn.pipRow:IsShown() then return end
    local cfg = getPipConfig()
    local topStacks = readStacks(btn.dotSlots[cfg.tSpells[1]])
    local botStacks = readStacks(btn.dotSlots[cfg.tSpells[2]])
    local tc, bc = cfg.tColors[1], cfg.tColors[2]
    for i = 1, cfg.iMaxStacks do
        local pip = btn.pipRow.pips[i]
        paintSeg(pip.top, topStacks >= i, tc)
        paintSeg(pip.bot, botStacks >= i, bc)
    end
    btn.pipRow.text1:SetText(string.format(cfg.sTextFormat, topStacks, cfg.iMaxStacks))
    btn.pipRow.text2:SetText(string.format(cfg.sTextFormat, botStacks, cfg.iMaxStacks))
end
MBT.UpdatePipsForBoss = UpdatePipsForBoss

-- Apply a "package" payload onto the frame's slot ("Add" semantics).
local function ApplyDotAdd(btn, pkg)
    local slot = btn.dotSlots[pkg.sSlotName]
    if not slot then
        slot = btn.CreateDotSlot()
        btn.dotSlots[pkg.sSlotName] = slot
    end
    slot.spellName = pkg.sSpellName    -- 记下当前展示的具体咒语，方便排序变更时重读 iOrder
    -- 初始 APPLY 时如果 boss 身上已经多层（部分技能首次 apply 就带层数），从 pkg.iStacks 读
    slot.stackCount = pkg.iStacks or 1

    -- 黑名单中的咒语：只跟踪 stackCount 给 pip 行用，不画图标 / 不参与 dot row 布局
    -- （能走到这里说明它是 pip-tracked，dispatcher 透传了事件；否则根本不会进 ApplyDotAdd）
    if MBT.db and MBT.db.profile.tBlacklist[pkg.sSpellName] then
        slot:Hide()
        slot.iOrder = nil
        slot.expirationTime = nil
        UpdateBossComboGlow(btn)
        UpdatePipsForBoss(btn)
        LayoutDotRow(btn)
        return
    end

    slot.tex:SetTexture(pkg.icon)
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
    slot.stacks:SetText(pkg.iStacks and tostring(pkg.iStacks) or "")
    UpdateSlotGlow(slot, pkg.iGlowAtStacks, pkg.iStacks)
    UpdateBossComboGlow(btn)
    UpdatePipsForBoss(btn)
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
    UpdatePipsForBoss(btn)
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
    UpdatePipsForBoss(btn)
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

-- 阵营冠军专用：名字前缀 [天赋+职业]，按职业颜色着色。
-- label 用 sSpec（如"增强萨满"，同职业不同天赋可区分）；颜色用 sClass。
-- 只有冠军才带 sSpec/sClass，其它 boss 两者皆 nil → 前缀为空字符串，名字显示完全不变。
local function BuildClassPrefix(label, classToken)
    if (not label or label == "") and (not classToken or classToken == "") then return "" end
    if not label or label == "" then
        label = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken])
             or (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classToken])
             or classToken
    end
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    local colorStr = (color and color.colorStr) or "ffffffff"
    return "|c" .. colorStr .. "[" .. label .. "]|r"
end

-- Update the frame to reflect new boss data (called on MultiBossTracker_ChangeZone).
local function ApplyZoneSlot(btn, slotData)
    if not slotData or not slotData.sNPCID then
        btn:Hide()
        if btn.modelFrame then btn.modelFrame:ClearModel() end
        if btn.portrait2D then btn.portrait2D:SetTexture("") end
        btn.lastModelGUID = nil
        btn.lastPortraitGUID = nil
        btn.namePrefix = nil
        ClearDots(btn)
        return
    end
    btn:Show()
    btn.npcID = slotData.sNPCID
    btn.targetName = slotData.sTarName
    btn.namePrefix = BuildClassPrefix(slotData.sSpec, slotData.sClass)
    -- 清掉之前的 boss 头像；HealthUpdater 找到 unit token 后会喂新数据
    if btn.modelFrame then btn.modelFrame:ClearModel() end
    if btn.portrait2D then btn.portrait2D:SetTexture("") end
    if btn.markerIcon then btn.markerIcon:Hide() end
    btn.lastModelGUID = nil
    btn.lastPortraitGUID = nil
    -- 切换 boss 时清掉旧高亮，下次 UpdateTargetHighlight 会重新判断
    MBT:HighlightFrame(btn, false)
    btn.nameText:SetText((btn.namePrefix or "") .. (slotData.sTarName or "?"))
    btn.hp:SetValue(100)
    btn.pctText:SetText("100%")
    btn.cast:Hide()
    ClearDots(btn)
    -- zone 切换：pip 行重置为全暗 + 0/N（如果有配置的话）
    UpdatePipsForBoss(btn)
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
    btn.nameText:SetText((btn.namePrefix or "") .. (UnitName(unit) or btn.targetName or "?"))
    if pct <= 0 then
        btn.hp:SetValue(0)
        btn.pctText:SetText("")
    end

    -- 顺便更新头像 —— 3D 模型和 2D 贴图都更新，这样切换模式立即生效。
    -- 关键：用 GUID 而不是 unit token 比对。HealthUpdater 在团战时每 0.1s 会换不同的 raidNNtarget
    -- 来定位同一只 boss，token 一直变但 GUID 不变。如果按 token 比，就会每 0.1s 重新 SetUnit 一次，
    -- 表现为头像鬼畜抖动。
    local guid = UnitGUID(unit)
    if guid then
        if btn.modelFrame and btn.lastModelGUID ~= guid then
            btn.modelFrame:SetUnit(unit)
            if btn.modelFrame.SetPortraitZoom then
                btn.modelFrame:SetPortraitZoom(1)   -- 头肩特写
            end
            if btn.modelFrame.RefreshCamera then
                btn.modelFrame:RefreshCamera()
            end
            btn.lastModelGUID = guid
        end
        if btn.portrait2D and btn.lastPortraitGUID ~= guid then
            SetPortraitTexture(btn.portrait2D, unit)
            btn.lastPortraitGUID = guid
        end
    end

    -- 团标：每次 health 更新时同步一次 boss 当前的团标（星/圈/菱形/...）
    -- 没标记或非 1-8 → 隐藏。SetRaidTargetIconTexture 是引擎自带工具函数。
    -- 开关由 bShowRaidMarker 控制（默认开启）
    if btn.markerIcon then
        local enabled = MBT.db and MBT.db.profile and MBT.db.profile.bShowRaidMarker
        if enabled == nil then enabled = true end
        local idx = enabled and GetRaidTargetIndex(unit) or nil
        if idx and idx >= 1 and idx <= 8 then
            SetRaidTargetIconTexture(btn.markerIcon, idx)
            btn.markerIcon:Show()
        else
            btn.markerIcon:Hide()
        end
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
    -- 紧凑模式：按设计意图（外观选项 desc 里写明"紧凑：单条窄血条 + 右侧 DoT，
    -- 没有大图标和独立施法条"），不显示 boss 施法条 —— 直接 no-op。
    -- 这样 ApplyCompactMode 里的 btn.cast:Hide() 才能持续生效，不被 dispatcher 回头 Show 出来。
    if btn.compact then return end
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
    -- 紧凑模式没显示，直接返回（castText 也不需要写）
    if btn.compact then return end
    btn.castText:SetText(pkg and pkg.sSpellName or "")
    btn.cast:Hide()
    btn.cast:SetScript("OnUpdate", nil)
end
MBT.EndCast = EndCast
