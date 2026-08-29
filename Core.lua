-- MultiBossTracker Core
-- Native pub/sub event bus + AceDB-backed SavedVariables.

local addonName, MBT = ...
_G.MultiBossTracker = MBT

-- 全局唯一的框体槽位列表。最多 10 个 —— 常规 boss 只用到前几个（其余保持隐藏），
-- 阵营冠军这种随机阵容最多刷 10 个，需要全部槽位。Layout / Dot / Cast dispatcher 共用这一份。
MBT.FRAME_IDS = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J"}

MBT.AceAddon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")

-- =====================================================================
-- Internal pub/sub event bus
-- =====================================================================
local listeners = {}

function MBT:RegisterMDFEvent(event, fn)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
end

function MBT:FireEvent(event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then
            geterrorhandler()(("MBT event handler error (%s): %s"):format(event, err))
        end
    end
end

-- =====================================================================
-- 战斗中安全调用 helper：战斗中执行的函数只要会改 SecureActionButton 的
-- size/point/attribute，都得排队等出战斗。fn() 应该是 idempotent —— 出战
-- 后只跑一次，最终状态正确即可。
-- =====================================================================
function MBT:DeferIfInCombat(fn)
    if InCombatLockdown() then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
            fn()
        end)
    else
        fn()
    end
end

-- =====================================================================
-- Tier-key (T1/T2/T7/T8/T9/T10/Testing) registry — used by Zones
-- =====================================================================
MBT.zonesSections = {}     -- [tierKey] = tZonesData (raw, English keys)
MBT.classData = {}         -- [classID]  = tAuraData
MBT.localizationData = nil -- the locale table for the player's GetLocale()

function MBT:RegisterZonesSection(tZonesData)
    MBT.zonesSections[tZonesData.sName] = tZonesData
    -- Re-broadcast so dispatchers pick it up
    MBT:FireEvent("MultiBossTracker_ZonesData_Section", tZonesData)
end

function MBT:RegisterClassData(classID, tAuraData)
    MBT.classData[classID] = tAuraData
end

function MBT:RegisterLocalization(loc, tLocData)
    if GetLocale() == loc then
        MBT.localizationData = tLocData
    end
end

-- =====================================================================
-- AceDB defaults.
-- =====================================================================
MBT.defaults = {
    -- 账号级（不随 profile 切换）
    global = {
        iLastUpdateWarning = 0,  -- 上次弹"有新版本"提示的时间戳（VersionCheck.lua 用，20 小时节流）
    },
    profile = {
        -- Layout / general
        iSkin = 2,                       -- 1=极简（单行）2=标准（双行带头像）
        iDotTextSize = 14,               -- DoT 倒计时数字字号
        iDotSize     = 32,               -- DoT 图标边长（仅完整模式；紧凑模式固定，受行高约束）
        fScale       = 1.0,              -- 整体缩放：对最外层 container 调 SetScale，DoT/HP/头像/字体/间距全部等比缩放
        bReverseGrowth = false,          -- frames grow downward by default
        fRowGap = 20,                    -- 完整模式下两行之间的像素间距（紧凑模式总用 6px）
        bShowMissingDoTs = true,         -- show DoT slots even when not applied (faded)
        bShowNPCCasts = true,            -- show enemy castbar — 默认开启（boss 读条时自动显示，平时不挡）
        bShowPlayerCast = true,          -- 顶部青色条显示玩家自己的 cast 在哪只 boss 上 —— 多目标切换关键
        bShowRangeIndicator = true,      -- HP 右上角 "外" 字提示 boss 不在你最远技能射程内
        bShowFacingWarning = true,       -- HP 右上角 "面" 字闪烁提示朝向错误（点击施法返回 facing 错误时）
        bShowRaidMarker = true,          -- 显示团长设置的团标（标准模式：头像左上角；紧凑模式：accent 黄竖线左侧）
        iTargetHighlight = 1,            -- 选中高亮样式：1=左侧黄竖线（默认），2=整框一圈蓝色柔光描边（类 Plater 选中高亮）
        bUse3DPortrait = true,           -- 头像类型：true=3D 模型，false=2D 静态贴图（更省 GPU）
        bTransparentBG = false,          -- true = boss 框黑底全透明（标准/极简通用），不挡后面的视野
        bHideBrandPips = false,          -- true = 隐藏毁灭术士的余烬/暗影印记 pip 行，boss 框退回原始形态
        bHideChannelBar = false,         -- true = 隐藏痛苦术士的吸取灵魂引导条，boss 框退回原始形态
        fHealthUpdateInterval = 0.1,     -- seconds between raid scans (DPS 输出时血量很关键，默认尽量实时)
        fUpdateRate = 0.1,               -- HP bar smoothing rate
        bClassicBarDynamicHeight = false,
        iClassicBarHeight = 12,

        -- 血条材质 / 颜色（仅 boss HP 条），走 LibSharedMedia。默认 = 自注册纯色 + 旧暗红，升级零视觉变化。
        sBarTexture = "MultiBossTracker",
        cBarColor   = { 0.62, 0.00, 0.00 },

        -- 术士专属：余烬 / 暗影印记双 6 层整框光圈。默认全对齐术士数据现值 → 升级零视觉变化。
        sWarlockGlowStyle     = "pixel",     -- pixel | autocast | button | proc
        cWarlockGlowColor     = { 1.0, 0.6, 0.1 },
        fWarlockGlowFreq      = 0.5,         -- 转速（周期/秒，越大越快）；pixel/autocast/button 通用
        iWarlockGlowThickness = 2,           -- 像素线条粗细（仅 pixel）
        iWarlockGlowDots      = 8,           -- 像素流动点数（仅 pixel）
        fWarlockGlowScale     = 2.0,         -- 自动施法光点大小（仅 autocast；lib 原始 1 太小看不清，默认放大）
        iWarlockGlowParticles = 4,           -- 自动施法光点数量（仅 autocast）

        -- Anchor (draggable position) — only saved once first dragged
        anchor = {
            point = "CENTER",
            relPoint = "CENTER",
            x = 0, y = 0,
        },
        bLocked = false,

        -- 小地图按钮位置 / 显隐（LibDBIcon 约定的字段格式）
        minimap = { hide = false },

        -- 用户屏蔽的 NPC（按 NPCID 计）；同 NPCID 的怪在所有副本/遭遇里都会被隐藏
        hiddenNPCs = {},

        -- Per-class click-cast bindings.
        -- Each binding's .sSpell is either "" (none), "target"/"focus"/"petattack" (action keywords),
        -- or any spell name (cast via /cast).
        tCastingModeBindings = {
            tWarlock = {
                tLClick = { sSpell = "target" },  tSLClick = { sSpell = "target" },
                tCLClick = { sSpell = "target" }, tALClick = { sSpell = "target" },
                tRClick = { sSpell = "focus" },   tSRClick = { sSpell = "" },
                tCRClick = { sSpell = "" },       tARClick = { sSpell = "" },
                tMClick = { sSpell = "focus" },   tSMClick = { sSpell = "" },
                tCMClick = { sSpell = "" },       tAMClick = { sSpell = "" },
                t4Click = { sSpell = "" },        tS4Click = { sSpell = "" },
                tC4Click = { sSpell = "" },       tA4Click = { sSpell = "" },
                t5Click = { sSpell = "" },        tS5Click = { sSpell = "" },
                tC5Click = { sSpell = "" },       tA5Click = { sSpell = "" },
            },
            tMage = {
                tLClick = { sSpell = "target" },  tSLClick = { sSpell = "target" },
                tCLClick = { sSpell = "target" }, tALClick = { sSpell = "target" },
                tRClick = { sSpell = "focus" },   tSRClick = { sSpell = "" },
                tCRClick = { sSpell = "" },       tARClick = { sSpell = "" },
                tMClick = { sSpell = "focus" },   tSMClick = { sSpell = "" },
                tCMClick = { sSpell = "" },       tAMClick = { sSpell = "" },
                t4Click = { sSpell = "" },        tS4Click = { sSpell = "" },
                tC4Click = { sSpell = "" },       tA4Click = { sSpell = "" },
                t5Click = { sSpell = "" },        tS5Click = { sSpell = "" },
                tC5Click = { sSpell = "" },       tA5Click = { sSpell = "" },
            },
            tDeathKnight = {
                tLClick = { sSpell = "target" },  tSLClick = { sSpell = "target" },
                tCLClick = { sSpell = "target" }, tALClick = { sSpell = "target" },
                tRClick = { sSpell = "focus" },   tSRClick = { sSpell = "" },
                tCRClick = { sSpell = "" },       tARClick = { sSpell = "" },
                tMClick = { sSpell = "focus" },   tSMClick = { sSpell = "" },
                tCMClick = { sSpell = "" },       tAMClick = { sSpell = "" },
                t4Click = { sSpell = "" },        tS4Click = { sSpell = "" },
                tC4Click = { sSpell = "" },       tA4Click = { sSpell = "" },
                t5Click = { sSpell = "" },        tS5Click = { sSpell = "" },
                tC5Click = { sSpell = "" },       tA5Click = { sSpell = "" },
            },
            tPriest = {
                tLClick = { sSpell = "target" },  tSLClick = { sSpell = "target" },
                tCLClick = { sSpell = "target" }, tALClick = { sSpell = "target" },
                tRClick = { sSpell = "focus" },   tSRClick = { sSpell = "" },
                tCRClick = { sSpell = "" },       tARClick = { sSpell = "" },
                tMClick = { sSpell = "focus" },   tSMClick = { sSpell = "" },
                tCMClick = { sSpell = "" },       tAMClick = { sSpell = "" },
                t4Click = { sSpell = "" },        tS4Click = { sSpell = "" },
                tC4Click = { sSpell = "" },       tA4Click = { sSpell = "" },
                t5Click = { sSpell = "" },        tS5Click = { sSpell = "" },
                tC5Click = { sSpell = "" },       tA5Click = { sSpell = "" },
            },
            tDruid = {
                tLClick = { sSpell = "target" },  tSLClick = { sSpell = "target" },
                tCLClick = { sSpell = "target" }, tALClick = { sSpell = "target" },
                tRClick = { sSpell = "focus" },   tSRClick = { sSpell = "" },
                tCRClick = { sSpell = "" },       tARClick = { sSpell = "" },
                tMClick = { sSpell = "focus" },   tSMClick = { sSpell = "" },
                tCMClick = { sSpell = "" },       tAMClick = { sSpell = "" },
                t4Click = { sSpell = "" },        tS4Click = { sSpell = "" },
                tC4Click = { sSpell = "" },       tA4Click = { sSpell = "" },
                t5Click = { sSpell = "" },        tS5Click = { sSpell = "" },
                tC5Click = { sSpell = "" },       tA5Click = { sSpell = "" },
            },
            tShaman = {
                tLClick = { sSpell = "target" },  tSLClick = { sSpell = "target" },
                tCLClick = { sSpell = "target" }, tALClick = { sSpell = "target" },
                tRClick = { sSpell = "focus" },   tSRClick = { sSpell = "" },
                tCRClick = { sSpell = "" },       tARClick = { sSpell = "" },
                tMClick = { sSpell = "focus" },   tSMClick = { sSpell = "" },
                tCMClick = { sSpell = "" },       tAMClick = { sSpell = "" },
                t4Click = { sSpell = "" },        tS4Click = { sSpell = "" },
                tC4Click = { sSpell = "" },       tA4Click = { sSpell = "" },
                t5Click = { sSpell = "" },        tS5Click = { sSpell = "" },
                tC5Click = { sSpell = "" },       tA5Click = { sSpell = "" },
            },
            tHunter = {
                tLClick = { sSpell = "target" },  tSLClick = { sSpell = "target" },
                tCLClick = { sSpell = "target" }, tALClick = { sSpell = "target" },
                tRClick = { sSpell = "focus" },   tSRClick = { sSpell = "" },
                tCRClick = { sSpell = "" },       tARClick = { sSpell = "" },
                tMClick = { sSpell = "focus" },   tSMClick = { sSpell = "" },
                tCMClick = { sSpell = "" },       tAMClick = { sSpell = "" },
                t4Click = { sSpell = "" },        tS4Click = { sSpell = "" },
                tC4Click = { sSpell = "" },       tA4Click = { sSpell = "" },
                t5Click = { sSpell = "" },        tS5Click = { sSpell = "" },
                tC5Click = { sSpell = "" },       tA5Click = { sSpell = "" },
            },
            tOther = {
                tLClick = { sSpell = "target" },  tSLClick = { sSpell = "target" },
                tCLClick = { sSpell = "target" }, tALClick = { sSpell = "target" },
                tRClick = { sSpell = "focus" },   tSRClick = { sSpell = "" },
                tCRClick = { sSpell = "" },       tARClick = { sSpell = "" },
                tMClick = { sSpell = "focus" },   tSMClick = { sSpell = "" },
                tCMClick = { sSpell = "" },       tAMClick = { sSpell = "" },
                t4Click = { sSpell = "" },        tS4Click = { sSpell = "" },
                tC4Click = { sSpell = "" },       tA4Click = { sSpell = "" },
                t5Click = { sSpell = "" },        tS5Click = { sSpell = "" },
                tC5Click = { sSpell = "" },       tA5Click = { sSpell = "" },
            },
        },

        -- Per-class DoT order (1=topmost).
        tForceDoTOrder = {
            -- pos1=火焰印记(10) pos2=暗影印记(11) pos3=Immolation(8) pos4=Haunt(3) pos5=Corruption(2) pos6=Doom(5) pos7=Agony(4) pos8=Shadow Embrace(7)
            -- 8 个槽位填满；Unstable Affliction 默认不在列表，玩家可在"DoT 排序"里手动加入
            tWarlock = { [1]=10, [2]=11, [3]=8, [4]=3, [5]=2, [6]=5, [7]=4, [8]=7 },
            tMage = {},
            tDeathKnight = {},
            tPriest = {},
            tDruid = {},
            tShaman = {},
            tHunter = {},
        },

        -- Per-class spell blacklist (true = excluded).
        tBlacklist = {
            ["Corruption"]          = false,
            ["Faerie Fire"]         = false,
            ["Living Bomb"]         = false,
            ["Insect Swarm"]        = false,
            ["Shadow Word: Pain"]   = false,
            ["Immolation"]          = false,
            ["Unstable Affliction"] = false,
            ["Seed of Corruption"]  = true,
            ["Flame Shock"]         = false,
            ["Devouring Plague"]    = false,
            ["Moonfire"]            = false,
            ["Shadow Embrace"]      = false,
            ["Haunt"]               = false,
            ["Vampiric Touch"]      = false,
            ["Curse of Doom"]       = false,
            ["Curse of Agony"]      = false,
            ["Shadow Mastery"]      = false,
        },

        -- Per-tier NPC blacklist (each is a flat table of "bOptionName" -> bool).
        tNPCBlackList = {
            tTesting = {}, tT1 = {}, tT2 = {}, tT3 = {}, tT4 = {}, tT5 = {},
        },

        tDebug = {
            bDebug = false,
            bFramesBackdropEvents = false,
            bFramesBorderEvents   = false,
            bFramesCastBarEvents  = false,
            bFramesIconEvents     = false,
            bFramesHPBarEvents    = false,
            bFramesDoTsEvents     = false,
            bDebugBorderSharedTriggerPerf = false,
        },
    },
}

-- =====================================================================
-- Addon lifecycle
-- =====================================================================
-- 小地图按钮：左键打开设置面板，右键锁定/解锁框体。
function MBT:SetupMinimapIcon()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LDB or not LDBIcon then return end

    local dataobj = LDB:NewDataObject("MultiBossTracker", {
        type = "launcher",
        text = "多目标 Boss 追踪",
        icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if MBT.OpenOptions then MBT:OpenOptions() end
            elseif button == "RightButton" then
                local locked = not MBT.db.profile.bLocked
                if MBT.SetLocked then MBT.SetLocked(locked) end
                print(("|cFF66CCFF多目标 Boss 追踪|r 框体已%s。"):format(locked and "锁定" or "解锁"))
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("|cFF66CCFF多目标 Boss 追踪|r")
            tt:AddLine("|cFFFFFFFF左键|r  打开设置")
            tt:AddLine("|cFFFFFFFF右键|r  锁定 / 解锁框体")
        end,
    })

    LDBIcon:Register("MultiBossTracker", dataobj, MBT.db.profile.minimap)
end

-- profile 切换 / 复制 / 重置后，把所有"应用层"重跑一遍：
-- 配置数据已经是新值了，但 UI、安全宏、formatter 缓存等需要主动刷新才能反映。
function MBT:OnProfileChanged()
    -- 触发 formatter 重读 bindings/blacklist → 进而触发 ClickCast.RefreshAll 重生成安全宏
    MBT:FireEvent("MultiBossTracker_BindingsChanged")
    MBT:FireEvent("MultiBossTracker_BlacklistChanged")

    -- UI 类的应用函数（每个都安全：未初始化时直接跳过）
    if MBT.ApplyCompactToAll  then MBT:ApplyCompactToAll() end
    if MBT.ApplyPortraitMode  then MBT:ApplyPortraitMode() end
    if MBT.UpdateDotTextSize  then MBT:UpdateDotTextSize() end
    if MBT.ApplyBackgroundOpacity then MBT:ApplyBackgroundOpacity() end
    if MBT.UpdateBarTexture   then MBT:UpdateBarTexture() end
    if MBT.ApplyScale         then MBT.ApplyScale() end   -- 内部会调 ApplyAnchor
    if MBT.ApplyAnchor        then MBT.ApplyAnchor() end
    if MBT.SetLocked          then MBT.SetLocked(MBT.db.profile.bLocked) end

    -- target 高亮可能因为不同 profile 的 bindings 颜色发生变化
    if MBT.UpdateTargetHighlight then MBT:UpdateTargetHighlight() end
end

function MBT.AceAddon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MultiBossTrackerDB", MBT.defaults, true)
    MBT.db = self.db

    -- 让 AceDB 的 profile 切换通知到我们 —— 没这一步切 profile 后 UI 显示对了但点击施法不变
    self.db.RegisterCallback(self, "OnProfileChanged", function() MBT:OnProfileChanged() end)
    self.db.RegisterCallback(self, "OnProfileCopied",  function() MBT:OnProfileChanged() end)
    self.db.RegisterCallback(self, "OnProfileReset",   function() MBT:OnProfileChanged() end)

    -- 小地图按钮（用 LibDataBroker + LibDBIcon，是 WoW 插件圈通用方案）
    MBT:SetupMinimapIcon()

    self:RegisterChatCommand("mbt", function(input)
        input = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if input == "lock" then
            MBT.db.profile.bLocked = true
            MBT:FireEvent("MultiBossTracker_LockChanged", true)
            self:Print("|cFF66FF66框体已锁定。|r")
        elseif input == "unlock" then
            MBT.db.profile.bLocked = false
            MBT:FireEvent("MultiBossTracker_LockChanged", false)
            self:Print("|cFFFFFF66框体已解锁，可以拖动。|r")
        elseif input == "reset" then
            MBT.db.profile.anchor = { point="CENTER", relPoint="CENTER", x=0, y=0 }
            MBT:FireEvent("MultiBossTracker_AnchorReset")
            self:Print("位置已复位到屏幕中央。")
        elseif input == "where" then
            -- 诊断命令：打印当前区域 + 目标/鼠标指向单位的 NPCID
            local zone, sub = GetZoneText(), GetSubZoneText()
            self:Print(("|cFFFFFF66区域:|r %s  |cFFFFFF66子区域:|r %s"):format(zone, sub))
            -- 与 GetZoneData 一致：子区域优先，没命中再退回主区域名
            local lz = MBT.localizedZones
            local matchedKey = lz and ((sub ~= "" and lz[sub] and sub) or (lz[zone] and zone))
            if matchedKey then
                self:Print(("|cFF66FF66该区域已在数据集里（匹配键：%s）。|r"):format(matchedKey))
            else
                self:Print("|cFFFF6666该区域不在数据集里 —— 这里不会显示框体。|r")
            end
            if MBT.GetCurrentEncounter then
                local iEnc = MBT.GetCurrentEncounter()
                if iEnc == 0 then
                    self:Print("|cFFFFFF66当前编码:|r 未确定（回退到该副本的第一个 boss）")
                else
                    self:Print(("|cFFFFFF66当前编码:|r %d"):format(iEnc))
                end
            end
            for _, unit in ipairs({"target", "mouseover"}) do
                if UnitExists(unit) then
                    local guid = UnitGUID(unit)
                    local npcID = guid and select(6, strsplit("-", guid)) or "?"
                    self:Print(("  %s: |cFFFFFFFF%s|r  NPCID=%s"):format(unit, UnitName(unit) or "?", npcID))
                end
            end
        elseif input:match("^showmacro") then
            -- 打印当前每个框体的点击施法宏，用来排查"为什么按了没反应"
            local which = input:match("^showmacro%s+(%S+)") or "A"
            which = which:upper()
            local btn = MBT.BossFrames and MBT.BossFrames[which]
            if not btn then
                self:Print("找不到框体 " .. which)
            else
                self:Print(("|cFF66CCFF框体 %s|r 当前 boss：%s"):format(which, btn.bossName or "(空)"))
                local labels = {"左键","右键","中键","侧键4","侧键5"}
                local printed = 0
                for i, name in ipairs(labels) do
                    local m = btn:GetAttribute("*macrotext" .. i) or ""
                    if m ~= "" then
                        -- 把多行宏压成单行 \\n 形式，便于一次看完
                        local oneline = m:gsub("\n+", " / "):gsub("^%s+", ""):gsub("%s+$", "")
                        self:Print(("|cFFFFD200[%s]|r %s"):format(name, oneline))
                        printed = printed + 1
                    end
                end
                if printed == 0 then
                    self:Print("|cFFFF6666没有任何按键绑定。|r 去 /mbt → 点击施法 里设置一下。")
                else
                    self:Print(("|cFF999999（其余 %d 个按键未绑定）|r"):format(#labels - printed))
                end
            end
        elseif input == "config" or input == "" then
            if MBT.OpenOptions then MBT:OpenOptions() end
        else
            self:Print("|cFF66CCFF多目标 Boss 追踪|r 命令列表：")
            self:Print("  /mbt            -- 打开设置面板")
            self:Print("  /mbt where      -- 显示当前区域和目标信息（用于排查）")
            self:Print("  /mbt showmacro [A-E]  -- 打印某个框体的点击施法宏")
            self:Print("  /mbt lock       -- 锁定框体位置")
            self:Print("  /mbt unlock     -- 解锁以便拖动")
            self:Print("  /mbt reset      -- 复位到屏幕中央")
        end
    end)
end

function MBT.AceAddon:OnEnable()
    -- Tell every module to fire its STATUS-equivalent init pulse.
    -- We bounce through a frame so this happens after every Lua file is loaded.
    C_Timer.After(0, function()
        MBT:FireEvent("STATUS")
        -- A delayed second pulse so dispatchers settle before we ask for a zone scan.
        C_Timer.After(0.1, function()
            MBT:FireEvent("MultiBossTracker_ZoneData_LateInit")
        end)
    end)
end

-- =====================================================================
-- Light wrappers used everywhere
-- =====================================================================
function MBT:DebugPrint(category, ...)
    if not MBT.db.profile.tDebug.bDebug then return end
    if category and not MBT.db.profile.tDebug["bFrames" .. category .. "Events"] then return end
    print("|cFF66CCFFMDF|r", ...)
end

-- Map runtime class token to the per-class binding key
local classTokenToBindingKey = {
    WARLOCK = "tWarlock",
    MAGE = "tMage",
    DEATHKNIGHT = "tDeathKnight",
    PRIEST = "tPriest",
    DRUID = "tDruid",
    SHAMAN = "tShaman",
    HUNTER = "tHunter",
}
function MBT:GetBindingKey(classToken)
    return classTokenToBindingKey[classToken] or "tOther"
end
