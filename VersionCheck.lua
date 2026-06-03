-- 新版本提醒。
-- 插件没有联网能力，唯一的"得知新版本"方式是和队伍/团队/公会里其他玩家装的本插件
-- 互相交换版本号。机制照搬 Details! 的版本检查（Details/core/network.lua）：
--   1. 登录时（含公会频道）+「从无队伍变成有队伍」的瞬间，广播一次自己的版本号；
--   2. 收到比自己新的版本号 → 聊天框提示，20 小时内最多提示一次（跨登录持久化）；
--   3. 不做"回应"—— 持有新版本的玩家自己登录/进组时自然会广播，避免旧版玩家
--      进团时全团新版玩家同时回包刷屏。
local addonName, MBT = ...

-- ===== 客户端兼容层 =====
-- 本客户端（5.5.x 现代引擎）用 C_ChatInfo / C_AddOns 命名空间（DBM 同款用法）；
-- 保留旧全局函数 fallback 以防万一。
local RegisterPrefix = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
local SendAddonMsg   = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
local GetMetadata    = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local INSTANCE_CAT   = LE_PARTY_CATEGORY_INSTANCE or 2

local COMM_PREFIX      = "MBTVersion"   -- 插件消息前缀（上限 16 字符，需注册否则服务器丢弃）
local WARNING_COOLDOWN = 72000          -- 提示节流：20 小时（秒），与 Details 一致

-- ===== 版本号解析 =====
-- "1.8.0" → 10800，纯数字比较（字符串比较会把 1.10.0 排在 1.9.0 前面）。
-- 要求 minor / patch 都小于 100。解析不了的当 0，永远不会触发提示。
local function VersionToNumber(s)
    if type(s) ~= "string" then return 0 end
    local major, minor, patch = s:match("^(%d+)%.(%d+)%.?(%d*)")
    if not major then return 0 end
    return tonumber(major) * 10000 + tonumber(minor) * 100 + (tonumber(patch) or 0)
end

local MY_VERSION_STR = GetMetadata(addonName, "Version") or "0.0.0"
local MY_VERSION     = VersionToNumber(MY_VERSION_STR)

-- Details 同款：记录"当前是否在队伍里"，只在 无队伍→有队伍 的转变瞬间广播一次，
-- 而不是每次 GROUP_ROSTER_UPDATE（组队/退人时会狂刷）都发。
local bInGroup = false

-- ===== 发送 =====
-- 消息格式 "V1:<版本字符串>"，V1 是协议号，将来扩展字段不至于和旧版互相解析失败。
local function BroadcastVersion(bAlsoGuild)
    local msg = "V1:" .. MY_VERSION_STR
    if IsInGroup(INSTANCE_CAT) then
        SendAddonMsg(COMM_PREFIX, msg, "INSTANCE_CHAT")
    elseif IsInRaid() then
        SendAddonMsg(COMM_PREFIX, msg, "RAID")
    elseif IsInGroup() then
        SendAddonMsg(COMM_PREFIX, msg, "PARTY")
    end
    if bAlsoGuild and IsInGuild() then
        SendAddonMsg(COMM_PREFIX, msg, "GUILD")
    end
end

-- ===== 接收 =====
local function OnVersionReceived(sTheirVersion)
    -- 自己广播到 RAID/PARTY/GUILD 也会收到回声，这里 <= 自然滤掉
    if VersionToNumber(sTheirVersion) <= MY_VERSION then return end

    -- 提示节流：时间戳存 SavedVariables（db.global），跨登录生效
    local g = MBT.db and MBT.db.global
    if g then
        if time() < (g.iLastUpdateWarning or 0) + WARNING_COOLDOWN then return end
        g.iLastUpdateWarning = time()
    end

    print(("|cFF66CCFF多目标 Boss 追踪|r 有新版本 |cFF66FF66v%s|r 可用（你当前是 v%s），请从|cFFFFD200新手盒子|r或|cFFFFD200网易DD|r更新。")
        :format(sTheirVersion, MY_VERSION_STR))
end

-- ===== 事件接线 =====
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message = ...
        if prefix ~= COMM_PREFIX then return end
        local v = message:match("^V1:(.+)$")
        if v then OnVersionReceived(v) end

    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        if isLogin or isReload then
            bInGroup = IsInGroup() or IsInRaid()
            -- 登录广播（含公会）：缓几秒，等公会/队伍信息就绪、避开加载高峰
            C_Timer.After(10, function() BroadcastVersion(true) end)
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        local bNow = IsInGroup() or IsInRaid()
        if not bInGroup and bNow then
            -- 刚进队伍/团队：稍等让其他人也稳定下来再广播（Details 同款时机）
            C_Timer.After(3, function() BroadcastVersion(false) end)
        end
        bInGroup = bNow
    end
end)

RegisterPrefix(COMM_PREFIX)
