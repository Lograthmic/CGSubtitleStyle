local addonName, addon = ...

local Serializer = {}

local FORMAT = "CGSUB"
local VERSION = 1

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_REV = {}
for i = 0, 63 do
    B64_REV[B64:sub(i + 1, i + 1)] = i
end

local function b64encode(s)
    local out = {}
    local i, n = 1, #s
    while i <= n do
        local c1 = string.byte(s, i, i) or 0
        local c2 = string.byte(s, i + 1, i + 1) or 0
        local c3 = string.byte(s, i + 2, i + 2) or 0
        out[#out + 1] = B64:sub(math.floor(c1 / 4) + 1, math.floor(c1 / 4) + 1)
        out[#out + 1] = B64:sub((c1 % 4) * 16 + math.floor(c2 / 16) + 1, (c1 % 4) * 16 + math.floor(c2 / 16) + 1)
        out[#out + 1] = B64:sub((c2 % 16) * 4 + math.floor(c3 / 64) + 1, (c2 % 16) * 4 + math.floor(c3 / 64) + 1)
        out[#out + 1] = B64:sub(c3 % 64 + 1, c3 % 64 + 1)
        i = i + 3
    end
    local result = table.concat(out)
    local r = n % 3
    if r == 1 then
        result = result:sub(1, -3) .. "=="
    elseif r == 2 then
        result = result:sub(1, -2) .. "="
    end
    return result
end

local function b64decode(s)
    if #s % 4 ~= 0 then return nil end
    local out = {}
    local i, n = 1, #s
    while i <= n do
        local a1 = B64_REV[s:sub(i, i)]
        local a2 = B64_REV[s:sub(i + 1, i + 1)]
        local a3 = B64_REV[s:sub(i + 2, i + 2)]
        local a4 = B64_REV[s:sub(i + 3, i + 3)]
        if not a1 or not a2 then return nil end
        out[#out + 1] = string.char((a1 * 4) + math.floor(a2 / 16))
        if a3 then
            out[#out + 1] = string.char(((a2 % 16) * 16) + math.floor(a3 / 4))
        end
        if a4 then
            out[#out + 1] = string.char(((a3 % 4) * 64) + a4)
        end
        i = i + 4
    end
    return table.concat(out)
end

local function IsArray(t)
    for k in pairs(t) do
        if type(k) ~= "number" then return false end
    end
    return true
end

local function Flatten(t, prefix, out)
    for k, v in pairs(t) do
        local key = prefix == "" and k or (prefix .. "." .. k)
        if type(v) == "table" and not IsArray(v) then
            Flatten(v, key, out)
        else
            out[key] = v
        end
    end
    return out
end

local function escape(str)
    str = tostring(str)
    str = str:gsub("\\", "\\\\")
    str = str:gsub("\n", "\\n")
    str = str:gsub("|", "\\p")
    str = str:gsub("=", "\\e")
    str = str:gsub(",", "\\c")
    return str
end

local function unescape(str)
    local out = {}
    local i, n = 1, #str
    local map = { n = "\n", p = "|", e = "=", c = ",", ["\\"] = "\\" }
    while i <= n do
        local c = str:sub(i, i)
        if c == "\\" then
            local nxt = str:sub(i + 1, i + 1)
            if map[nxt] then
                out[#out + 1] = map[nxt]
                i = i + 2
            else
                out[#out + 1] = c
                i = i + 1
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return table.concat(out)
end

local function encodeValue(v)
    local t = type(v)
    if t == "boolean" then
        return v and "1" or "0"
    elseif t == "number" then
        return tostring(v)
    elseif t == "table" then
        local parts = {}
        for i = 1, #v do
            parts[#parts + 1] = tostring(v[i])
        end
        return table.concat(parts, ",")
    end
    return escape(tostring(v))
end

local function coerce(default, raw)
    local t = type(default)
    if t == "boolean" then
        return raw == "1"
    elseif t == "number" then
        return tonumber(raw) or default
    elseif t == "string" then
        return unescape(raw)
    elseif t == "table" then
        local out = {}
        local idx = 1
        for part in string.gmatch(raw, "[^,]+") do
            out[idx] = tonumber(part) or default[idx] or 0
            idx = idx + 1
        end
        return out
    end
    return raw
end

local function setPath(t, path, value)
    local segs = {}
    for seg in string.gmatch(path, "[^%.]+") do
        segs[#segs + 1] = seg
    end
    local cur = t
    for i = 1, #segs - 1 do
        local seg = segs[i]
        if cur[seg] == nil then cur[seg] = {} end
        cur = cur[seg]
    end
    cur[segs[#segs]] = value
end

function Serializer.Serialize(theme, defaults)
    local flat = Flatten(defaults, "", {})
    local keys = {}
    for k in pairs(flat) do
        keys[#keys + 1] = k
    end
    table.sort(keys)

    local parts = {}
    for _, key in ipairs(keys) do
        local cur = theme
        for seg in string.gmatch(key, "[^%.]+") do
            cur = cur and cur[seg]
            if cur == nil then break end
        end
        if cur ~= nil then
            parts[#parts + 1] = key .. "=" .. encodeValue(cur)
        end
    end
    local internal = escape(theme.name or "") .. "|" .. table.concat(parts, "|")
    return FORMAT .. "|" .. tostring(VERSION) .. "|" .. b64encode(internal)
end

function Serializer.Parse(str, defaults)
    if type(str) ~= "string" or str == "" then
        return nil, "empty"
    end
    local header, version, payload = string.match(str, "^(CGSUB)%|(%d+)%|(.*)$")
    if not header then
        return nil, "format"
    end
    if tonumber(version) ~= VERSION then
        return nil, "version"
    end
    local internal = b64decode(payload)
    if not internal then return nil, "format" end
    local name, body = string.match(internal, "^([^|]*)%|?(.*)$")
    local flat = Flatten(defaults, "", {})
    local theme = addon.Themes.NewDefault()
    if name and name ~= "" then
        theme.name = unescape(name)
    end
    for item in string.gmatch(body, "[^|]+") do
        local key, value = string.match(item, "^([^=]+)=(.*)$")
        if key and flat[key] ~= nil then
            setPath(theme, key, coerce(flat[key], value))
        end
    end
    return theme
end

addon.Serializer = Serializer