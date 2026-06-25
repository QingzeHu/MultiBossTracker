-- 序列化 / Base64 / 沙盒 loadstring（纯 Lua，移植自 MultiBossTracker，无 Ace 依赖）
local addonName, RPF = ...

-- =====================================================================
-- table → Lua 源码字符串（loadstring 可执行，返回原表）
-- =====================================================================
local function isIdentifier(s)
    return type(s) == "string" and s:match("^[%a_][%w_]*$") ~= nil and not s:match("^%d")
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
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            if type(a) ~= type(b) then return tostring(a) < tostring(b) end
            return a < b
        end)
        for _, k in ipairs(keys) do
            local sk = serializeKey(k)
            local sv = serializeValue(v[k], indent + 1)
            if sk and sv then
                parts[#parts + 1] = padInner .. sk .. " = " .. sv .. ","
            end
        end
        parts[#parts + 1] = pad .. "}"
        return table.concat(parts, "\n")
    end
    return nil
end

function RPF:SerializeTable(tbl)
    return "return " .. serializeValue(tbl, 0)
end

-- =====================================================================
-- Base64（RFC 4648，无换行）
-- =====================================================================
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local decodeLookup
local function buildDecode()
    if decodeLookup then return end
    decodeLookup = {}
    for i = 1, #B64 do decodeLookup[B64:sub(i, i)] = i - 1 end
end

function RPF:Base64Encode(data)
    local out, n, i = {}, #data, 1
    while i <= n do
        local b1 = data:byte(i) or 0
        local b2 = data:byte(i + 1)
        local b3 = data:byte(i + 2)
        local n1 = math.floor(b1 / 4)
        local n2 = (b1 % 4) * 16 + math.floor((b2 or 0) / 16)
        local n3 = ((b2 or 0) % 16) * 4 + math.floor((b3 or 0) / 64)
        local n4 = (b3 or 0) % 64
        out[#out + 1] = B64:sub(n1 + 1, n1 + 1)
        out[#out + 1] = B64:sub(n2 + 1, n2 + 1)
        out[#out + 1] = b2 and B64:sub(n3 + 1, n3 + 1) or "="
        out[#out + 1] = b3 and B64:sub(n4 + 1, n4 + 1) or "="
        i = i + 3
    end
    return table.concat(out)
end

function RPF:Base64Decode(s)
    buildDecode()
    s = s:gsub("%s+", "")
    local pad = 0
    if s:sub(-2) == "==" then pad = 2; s = s:sub(1, -3)
    elseif s:sub(-1) == "=" then pad = 1; s = s:sub(1, -2) end
    if #s % 4 == 1 then return nil, "base64 长度不合法" end
    local out, i = {}, 1
    while i <= #s do
        local c1 = decodeLookup[s:sub(i, i)]
        local c2 = decodeLookup[s:sub(i + 1, i + 1)]
        local c3 = decodeLookup[s:sub(i + 2, i + 2)]
        local c4 = decodeLookup[s:sub(i + 3, i + 3)]
        if not c1 or not c2 then return nil, "base64 含非法字符" end
        out[#out + 1] = string.char(c1 * 4 + math.floor(c2 / 16))
        if c3 then out[#out + 1] = string.char((c2 % 16) * 16 + math.floor(c3 / 4)) end
        if c4 then out[#out + 1] = string.char((c3 % 4) * 64 + c4) end
        i = i + 4
    end
    -- 注：'=' 已在循环前剥除，循环内 c3/c4 的 nil 守卫已产出正确字节数，
    -- 无需再按 pad 截断（再截会多砍 pad 个字节）。
    return table.concat(out)
end

-- =====================================================================
-- 沙盒化 loadstring：空环境，只能构造表字面量
-- =====================================================================
function RPF:SafeLoadTable(src)
    local f, err = loadstring(src, "RPFImport")
    if not f then return nil, "解析失败：" .. tostring(err) end
    setfenv(f, {})
    local ok, result = pcall(f)
    if not ok then return nil, "执行失败：" .. tostring(result) end
    if type(result) ~= "table" then return nil, "导入内容不是有效配置" end
    return result
end
