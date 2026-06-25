-- RaidPreflight Core
-- 自包含：原生事件总线 + 裸 SavedVariables（带默认值合并），不依赖 Ace / MBT。
-- 命名约定沿用 MultiBossTracker：s=string, t=table, i=integer/number, b=bool, f=float。

local addonName, RPF = ...
_G.RaidPreflight = RPF

RPF.version = "0.1.0"

-- =====================================================================
-- 内部 pub/sub 事件总线（模块间解耦，和 MBT 同一套写法）
-- =====================================================================
local listeners = {}

function RPF:On(event, fn)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
end

function RPF:Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then
            geterrorhandler()(("RaidPreflight handler error (%s): %s"):format(event, err))
        end
    end
end

-- =====================================================================
-- 小工具
-- =====================================================================

-- 深拷贝（只处理 string/number/boolean/table，足够配置表用）
local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deepCopy(v) end
    return out
end
RPF.deepCopy = deepCopy

-- 把 defaults 里缺失的字段补进 dst（递归），不覆盖已有值。
local function applyDefaults(dst, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            applyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = deepCopy(v)
        end
    end
    return dst
end

-- 战斗中安全调用：会动 SecureFrame 的操作等出战斗再跑（弹窗本身不安全，留作扩展用）。
function RPF:DeferIfInCombat(fn)
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

-- 组队单位迭代器（含自己），raid / party / solo 全覆盖。
function RPF:IterGroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else
        units[#units + 1] = "player"
        for i = 1, 4 do
            if UnitExists("party" .. i) then units[#units + 1] = "party" .. i end
        end
    end
    return units
end

-- =====================================================================
-- SavedVariables 默认值
-- =====================================================================
RPF.defaults = {
    bEnabled   = true,
    bOnSummon  = true,   -- 术士拉人时拦截召唤弹窗 → 先看清单
    bOnEnter   = true,   -- 自己跑进本时，每个副本周期弹一次
    bOnPull    = true,   -- 团队 ready check（开战前倒计时）时弹

    -- 进本弹窗去重：key = "mapID:difficulty" → 上次弹出的时间戳（秒）。
    -- 同一副本+难度在 iEnterCooldown 秒内不再弹（近似一个"副本周期"）。
    iEnterCooldown = 6 * 60 * 60,  -- 6 小时
    tShownEnter = {},

    -- 用户对内置模板的覆盖（v1 先留扩展位，UI 配置面板在 v2）。
    -- 结构：tZones[mapID] = { tItems=..., tAuras=..., tComp=..., tBosses={[encID]=...} }
    tZones = {},
}

RPF.db = nil  -- ADDON_LOADED 后指向 RaidPreflightDB（已合并默认值）

-- =====================================================================
-- 生命周期
-- =====================================================================
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
    if name ~= addonName then return end
    RaidPreflightDB = RaidPreflightDB or {}
    RPF.db = applyDefaults(RaidPreflightDB, RPF.defaults)
    RPF:Fire("RPF_Ready")
    loader:UnregisterEvent("ADDON_LOADED")
end)

-- =====================================================================
-- 斜杠命令
-- =====================================================================
SLASH_RAIDPREFLIGHT1 = "/rpf"
SLASH_RAIDPREFLIGHT2 = "/raidpreflight"
SlashCmdList["RAIDPREFLIGHT"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local db = RPF.db
    if not db then return end

    if msg == "" or msg == "check" or msg == "show" then
        -- 手动跑一次"当前情境"检查（进本/开战前都行）
        RPF:Fire("RPF_ManualCheck")
    elseif msg == "reset" then
        wipe(db.tShownEnter)
        print("|cff66ccffRaidPreflight|r: 进本弹窗记录已清空，下次进本会重新弹。")
    elseif msg == "on" then
        db.bEnabled = true
        print("|cff66ccffRaidPreflight|r: 已启用。")
    elseif msg == "off" then
        db.bEnabled = false
        print("|cff66ccffRaidPreflight|r: 已禁用。")
    elseif msg == "summon" or msg == "enter" or msg == "pull" then
        local key = "bOn" .. msg:gsub("^%l", string.upper)
        db[key] = not db[key]
        print(("|cff66ccffRaidPreflight|r: %s 检查 = %s"):format(msg, db[key] and "开" or "关"))
    else
        print("|cff66ccffRaidPreflight|r 用法：")
        print("  /rpf            手动检查当前情境")
        print("  /rpf reset      清空进本弹窗记录（重新弹）")
        print("  /rpf on|off     总开关")
        print("  /rpf summon|enter|pull  切换对应触发器")
    end
end
