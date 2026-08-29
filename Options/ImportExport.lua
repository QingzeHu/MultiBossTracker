-- 配置档导入 / 导出
-- 把当前 profile 里与默认值不同的项序列化成可分享的字符串：Lua 源码 → base64 → 加版本前缀。
-- 导入时反解，按 profile 名直接写入（重名覆盖，不询问）。
local addonName, MBT = ...

local PREFIX = "MBT1!"  -- 版本前缀；将来格式不兼容就 bump 成 MBT2!

-- =====================================================================
-- 序列化：table → Lua 源码字符串（loadstring 可执行，返回原表）
-- 只支持 string / number / boolean / table；遇到 function / userdata 直接跳过
-- =====================================================================
local function isIdentifier(s)
    return type(s) == "string" and s:match("^[%a_][%w_]*$") ~= nil
        and not s:match("^%d") -- 双保险
end

local function serializeKey(k)
    if type(k) == "string" then
        if isIdentifier(k) then return k end
        return ("[%q]"):format(k)
    elseif type(k) == "number" then
        return ("[%s]"):format(tostring(k))
    end
    return nil
end

local function serializeValue(v, indent)
    local t = type(v)
    if t == "string" then
        return ("%q"):format(v)
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        local pad = string.rep("  ", indent)
        local padInner = string.rep("  ", indent + 1)
        local parts = { "{" }
        -- 先按 key 排序，保证两次导出字符串一致 —— 方便人肉 diff
        local keys = {}
        for k in pairs(v) do keys[#keys+1] = k end
        table.sort(keys, function(a, b)
            if type(a) ~= type(b) then return type(a) < type(b) end
            return a < b
        end)
        for _, k in ipairs(keys) do
            local val = v[k]
            local sk = serializeKey(k)
            local sv = serializeValue(val, indent + 1)
            if sk and sv then
                parts[#parts+1] = padInner .. sk .. " = " .. sv .. ","
            end
        end
        parts[#parts+1] = pad .. "}"
        return table.concat(parts, "\n")
    end
    return nil
end

local function serializeTable(tbl)
    return "return " .. serializeValue(tbl, 0)
end

-- =====================================================================
-- Base64（标准 RFC 4648，无换行）
-- =====================================================================
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local b64Decode_lookup
local function buildDecodeLookup()
    if b64Decode_lookup then return end
    b64Decode_lookup = {}
    for i = 1, #B64_CHARS do
        b64Decode_lookup[B64_CHARS:sub(i, i)] = i - 1
    end
end

local function base64Encode(data)
    local out = {}
    local n = #data
    local i = 1
    while i <= n do
        local b1 = data:byte(i) or 0
        local b2 = data:byte(i + 1)
        local b3 = data:byte(i + 2)
        local n1 = math.floor(b1 / 4)
        local n2 = (b1 % 4) * 16 + math.floor((b2 or 0) / 16)
        local n3 = ((b2 or 0) % 16) * 4 + math.floor((b3 or 0) / 64)
        local n4 = (b3 or 0) % 64
        out[#out+1] = B64_CHARS:sub(n1 + 1, n1 + 1)
        out[#out+1] = B64_CHARS:sub(n2 + 1, n2 + 1)
        out[#out+1] = b2 and B64_CHARS:sub(n3 + 1, n3 + 1) or "="
        out[#out+1] = b3 and B64_CHARS:sub(n4 + 1, n4 + 1) or "="
        i = i + 3
    end
    return table.concat(out)
end

local function base64Decode(s)
    buildDecodeLookup()
    -- 末尾 '=' 只是补位，去掉后剩余字符数就决定了输出字节数（4→3、3→2、2→1）
    s = s:gsub("%s+", ""):gsub("=+$", "")
    if #s % 4 == 1 then return nil, "base64 长度不合法" end

    local out = {}
    local n = #s
    local i = 1
    while i <= n do
        local c1 = b64Decode_lookup[s:sub(i, i)]
        local c2 = b64Decode_lookup[s:sub(i + 1, i + 1)]
        local c3 = b64Decode_lookup[s:sub(i + 2, i + 2)]
        local c4 = b64Decode_lookup[s:sub(i + 3, i + 3)]
        if not c1 or not c2
            or (not c3 and i + 2 <= n) or (not c4 and i + 3 <= n) then
            return nil, "base64 含非法字符"
        end
        out[#out+1] = string.char(c1 * 4 + math.floor(c2 / 16))
        if c3 then out[#out+1] = string.char((c2 % 16) * 16 + math.floor(c3 / 4)) end
        if c4 then out[#out+1] = string.char((c3 % 4) * 64 + c4) end
        i = i + 4
    end
    return table.concat(out)
end

-- =====================================================================
-- 沙盒化 loadstring：避免恶意字符串调用 _G 里的函数
-- =====================================================================
local function safeLoadTable(src)
    local f, err = loadstring(src, "MBTImport")
    if not f then return nil, "解析失败：" .. tostring(err) end
    setfenv(f, {}) -- 空环境，只能构造表字面量
    local ok, result = pcall(f)
    if not ok then return nil, "执行失败：" .. tostring(result) end
    if type(result) ~= "table" then return nil, "导入内容不是有效的配置数据" end
    return result
end

-- =====================================================================
-- 深拷贝（导入时把数据塞进 db.profile）
-- =====================================================================
local function deepCopyInto(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            deepCopyInto(v, dst[k])
        else
            dst[k] = v
        end
    end
end

-- =====================================================================
-- 只挑出与默认值不同的项 —— 导入侧会先 ResetProfile 铺好默认值，没带的自然回落
-- =====================================================================
local function diffDefaults(cur, def)
    local out, bAny = {}, false
    for k, v in pairs(cur) do
        -- 不能写成 `def and def[k] or nil`：默认值是 false 时会被 or 吃成 nil
        local d
        if type(def) == "table" then d = def[k] end
        if type(v) == "table" then
            local sub, bSubAny = diffDefaults(v, d)
            if bSubAny then out[k] = sub; bAny = true end
        elseif d ~= v then
            out[k] = v; bAny = true
        end
    end
    return out, bAny
end

-- =====================================================================
-- 公共 API
-- =====================================================================

-- 导出当前 profile 为可分享的字符串
function MBT:ExportCurrentProfile()
    local name = MBT.db:GetCurrentProfile()
    local payload = {
        name = name,
        profile = diffDefaults(MBT.db.profile, MBT.defaults and MBT.defaults.profile),
    }
    local src = serializeTable(payload)
    return PREFIX .. base64Encode(src), name
end

-- 解析字符串，返回 { name=..., profile=... } 或 nil + 错误信息
-- 不写入数据库，只用于预览 / 校验
function MBT:DecodeImportString(str)
    if type(str) ~= "string" or str == "" then
        return nil, "导入字符串为空"
    end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    if str:sub(1, #PREFIX) ~= PREFIX then
        return nil, "前缀错误：应以 " .. PREFIX .. " 开头"
    end
    local b64 = str:sub(#PREFIX + 1)
    local raw, err = base64Decode(b64)
    if not raw then return nil, err end
    local payload, perr = safeLoadTable(raw)
    if not payload then return nil, perr end
    if type(payload.name) ~= "string" or payload.name == "" then
        return nil, "数据缺少 profile 名"
    end
    if type(payload.profile) ~= "table" then
        return nil, "数据缺少 profile 内容"
    end
    return payload
end

-- 真正执行导入：按 name 写入 / 覆盖一个 profile，并切换过去
function MBT:ImportProfile(str)
    local payload, err = self:DecodeImportString(str)
    if not payload then return false, err end

    local name = payload.name

    -- 切换到目标 profile（不存在时 AceDB 会自动创建）
    MBT.db:SetProfile(name)
    -- 清空现有内容（重名覆盖语义），再深拷入新数据
    -- 注意：直接对 db.profile 做 wipe 不靠谱（带 metatable），用 ResetProfile
    MBT.db:ResetProfile(false, true)
    deepCopyInto(payload.profile, MBT.db.profile)

    -- AceDB 的 profile 切换回调里 OnProfileChanged 已经被注册，会刷新所有 UI；
    -- 这里再显式调一次保险：拷贝完后 UI 才看到完整数据
    if MBT.OnProfileChanged then MBT:OnProfileChanged() end
    return true, name
end

-- =====================================================================
-- 弹窗 UI（用 AceGUI Frame 自建独立窗口）
-- 之前尝试过把导入/导出框直接内嵌进设置面板，但 AceConfig 在 MoP Classic 的
-- BlizOptions 下重绘逻辑不会刷新 input 控件 —— 即使手动 SetText 内部数据正确，
-- 视觉上还是空的。回退用独立弹窗最可靠。
-- =====================================================================
local AceGUI = LibStub("AceGUI-3.0")

-- 导出窗口：只读多行框，自动全选好让用户直接 Ctrl+C
function MBT:ShowExportFrame()
    local ok, str, profileName = pcall(MBT.ExportCurrentProfile, MBT)
    if not ok then
        print("|cFFFF6666[多目标 Boss 追踪]|r 导出失败：" .. tostring(str))
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("导出配置档：" .. profileName)
    frame:SetStatusText(("共 %d 字符 — Ctrl+A 全选 → Ctrl+C 复制 → 发给朋友"):format(#str))
    frame:SetLayout("Fill")
    frame:SetWidth(680)
    frame:SetHeight(440)
    frame:EnableResize(false)

    local eb = AceGUI:Create("MultiLineEditBox")
    eb:SetLabel("")
    eb:DisableButton(true)
    eb:SetText(str)
    -- 用户可能误编辑：内容一变就还原 + 重新全选
    eb:SetCallback("OnTextChanged", function(self)
        self:SetText(str)
        self.editBox:HighlightText()
    end)
    frame:AddChild(eb)

    -- 等 frame 上屏后再聚焦 + 全选 —— 当前帧聚焦容易被 AceGUI 自己的 init 覆盖
    C_Timer.After(0, function()
        if eb.editBox then
            eb.editBox:HighlightText()
            eb:SetFocus()
        end
    end)
end

-- 导入窗口：粘贴 → 点导入按钮 → 成功就关窗、失败就在状态栏显红字
function MBT:ShowImportFrame()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("导入配置档")
    frame:SetStatusText("把朋友给你的 MBT1! 字符串粘贴到下面，再点 导入 按钮")
    frame:SetLayout("Flow")
    frame:SetWidth(680)
    frame:SetHeight(460)
    frame:EnableResize(false)

    local pasted = ""

    local eb = AceGUI:Create("MultiLineEditBox")
    eb:SetLabel("配置字符串")
    eb:DisableButton(true)
    eb:SetFullWidth(true)
    eb:SetNumLines(13)
    eb:SetCallback("OnTextChanged", function(_, _, text) pasted = text end)
    frame:AddChild(eb)

    local statusLabel = AceGUI:Create("Label")
    statusLabel:SetText(" ")
    statusLabel:SetFullWidth(true)
    statusLabel:SetFontObject(GameFontHighlight)
    frame:AddChild(statusLabel)

    local importBtn = AceGUI:Create("Button")
    importBtn:SetText("导入")
    importBtn:SetWidth(140)
    importBtn:SetCallback("OnClick", function()
        local ok, info = MBT:ImportProfile(pasted)
        if ok then
            print(("|cFF66CCFF[多目标 Boss 追踪]|r 导入成功，已切换到配置档 |cFFFFD200%s|r。"):format(info))
            frame:Release()
        else
            statusLabel:SetText("|cFFFF6666导入失败：" .. tostring(info) .. "|r")
        end
    end)
    frame:AddChild(importBtn)

    local closeBtn = AceGUI:Create("Button")
    closeBtn:SetText("关闭")
    closeBtn:SetWidth(140)
    closeBtn:SetCallback("OnClick", function() frame:Release() end)
    frame:AddChild(closeBtn)
end
