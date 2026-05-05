-- 本地化框架。
-- 设计上只保留一份"英文 boss 名 → 中文"的映射，无论客户端是什么语种都强制走中文。
-- 这样配合数据表里的英文 key，运行时把 zhCN 客户端 GetSubZoneText() 返回的中文区域名匹配上。
local addonName, MBT = ...

MBT.localizations = {}    -- 由 Locale/zhCN.lua 填充

-- 把英文 key 翻成中文（找不到就返回原 key）。
local function L(s)
    if s == nil then return nil end
    return MBT.localizations[s] or s
end
MBT.L = L

-- 递归 walk 一个表，把每个英文 key（和值）翻成中文。

local function LocalizeTable(tIn)
    if tIn.bLocalized then return tIn end
    local tOut = { bLocalized = true }
    local function LocalizeField(srcParent, dstParent, key)
        local locKey = L(key)
        if type(srcParent[key]) == "table" then
            dstParent[locKey] = {}
            for k in pairs(srcParent[key]) do
                LocalizeField(srcParent[key], dstParent[locKey], k)
            end
        else
            local v = srcParent[key]
            if type(v) == "string" then
                dstParent[locKey] = L(v)
            else
                dstParent[locKey] = v
            end
        end
    end
    for k in pairs(tIn) do
        LocalizeField(tIn, tOut, k)
    end
    return tOut
end
MBT.LocalizeTable = LocalizeTable

-- 翻译表注册接口（保持向后兼容，但忽略 locale 参数 —— 永远当中文用）。
function MBT:RegisterLocale(_, t)
    for k, v in pairs(t) do
        MBT.localizations[k] = v
    end
end
