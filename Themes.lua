local addonName, addon = ...
local L = addon.L

local Themes = {}

-- The default theme is stored under this fixed invariant key so that switching
-- the addon's UI language (默认/Default/預設) never orphans or duplicates it.
-- L.DEFAULT_THEME is only the localized display label.
local DEFAULT_KEY = "default"
local LEGACY_DEFAULT_KEYS = { "默认", "預設", "Default" }

local function ResolveKey(name)
    if name == DEFAULT_KEY or name == L.DEFAULT_THEME then
        return DEFAULT_KEY
    end
    for _, legacy in ipairs(LEGACY_DEFAULT_KEYS) do
        if name == legacy then
            return DEFAULT_KEY
        end
    end
    return name
end

local function DisplayName(key)
    if key == DEFAULT_KEY then
        return L.DEFAULT_THEME
    end
    return key
end

local function DeepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function DeepMerge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = DeepCopy(v)
            else
                local isArray = true
                for ak in pairs(v) do
                    if type(ak) ~= "number" then
                        isArray = false
                        break
                    end
                end
                if isArray then
                    if type(dst[k]) ~= "table" then
                        dst[k] = DeepCopy(v)
                    end
                else
                    DeepMerge(dst[k], v)
                end
            end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function Themes.Sanitize(theme)
    if type(theme) ~= "table" then
        return Themes.NewDefault()
    end
    return DeepMerge(theme, Themes.NewDefault())
end

function Themes.NewDefault()
    return {
        name = L.DEFAULT_THEME,
        global = {
            enabled = true,
            respectCvar = true,
            alpha = 1,
            anchor = "BOTTOM",
            x = 0,
            y = 60,
            maxWidth = 800,
            gap = 6,
        },
        speaker = {
            font = "",
            fontSize = 20,
            textColor = { 1, 1, 1, 1 },
            outlineStyle = "OUTLINE",
            outlineColor = { 0, 0, 0, 1 },
            outlineWidth = 1,
            shadow = { enabled = false, color = { 0, 0, 0, 1 }, x = 1, y = -1 },
            background = { enabled = true, color = { 0, 0, 0, 1 }, alpha = 0.55 },
            border = { enabled = false, style = "solid", color = { 1, 1, 1, 1 }, thickness = 1 },
            padding = { left = 12, right = 12, top = 12, bottom = 12 },
        },
        content = {
            font = "",
            fontSize = 22,
            textColor = { 1, 0.85, 0.5, 1 },
            outlineStyle = "OUTLINE",
            outlineColor = { 0, 0, 0, 1 },
            outlineWidth = 1,
            shadow = { enabled = true, color = { 0, 0, 0, 1 }, x = 1, y = -1 },
            background = { enabled = true, color = { 0, 0, 0, 1 }, alpha = 0.6 },
            border = { enabled = true, style = "solid", color = { 0.45, 0.45, 0.45, 1 }, thickness = 1 },
            padding = { left = 12, right = 12, top = 12, bottom = 12 },
        },
    }
end

function Themes.Init()
    local db = CGSubtitleStyleDB or {}
    CGSubtitleStyleDB = db
    addon.db = db
    db.themes = db.themes or {}
    for _, legacy in ipairs(LEGACY_DEFAULT_KEYS) do
        if legacy ~= DEFAULT_KEY and db.themes[legacy] then
            if not db.themes[DEFAULT_KEY] then
                db.themes[DEFAULT_KEY] = db.themes[legacy]
            end
            db.themes[legacy] = nil
            if db.active == legacy then
                db.active = DEFAULT_KEY
            end
        end
    end
    if not db.themes[DEFAULT_KEY] then
        db.themes[DEFAULT_KEY] = Themes.NewDefault()
    end
    for name, theme in pairs(db.themes) do
        db.themes[name] = Themes.Sanitize(theme)
        db.themes[name].name = DisplayName(name)
    end
    if not db.active or not db.themes[db.active] then
        db.active = DEFAULT_KEY
    end
end

function Themes.GetActiveName()
    return DisplayName(addon.db and addon.db.active or DEFAULT_KEY)
end

function Themes.GetActive()
    if not addon.db then
        Themes.Init()
    end
    local name = addon.db.active
    local theme = addon.db.themes[name]
    if not theme then
        theme = addon.db.themes[DEFAULT_KEY]
        addon.db.active = DEFAULT_KEY
    end
    return Themes.Sanitize(theme)
end

function Themes.Get(name)
    return addon.db.themes[ResolveKey(name)]
end

function Themes.List()
    local names = {}
    for name in pairs(addon.db.themes) do
        names[#names + 1] = DisplayName(name)
    end
    table.sort(names)
    return names
end

function Themes.Save(name, theme)
    local key = ResolveKey(name)
    local copy = DeepCopy(theme)
    copy.name = DisplayName(key)
    addon.db.themes[key] = copy
    addon.db.active = key
    return copy
end

function Themes.Apply(name)
    local key = ResolveKey(name)
    local theme = addon.db.themes[key]
    if not theme then return end
    addon.db.active = key
    if addon.Core then
        addon.Core:ApplyTheme(theme)
    end
end

function Themes.Delete(name)
    local key = ResolveKey(name)
    if key == DEFAULT_KEY then return false end
    addon.db.themes[key] = nil
    if addon.db.active == key then
        addon.db.active = DEFAULT_KEY
    end
    return true
end

function Themes.ResetActive()
    local name = addon.db.active
    local theme = Themes.NewDefault()
    theme.name = DisplayName(name)
    addon.db.themes[name] = theme
    if addon.Core then
        addon.Core:ApplyTheme(theme)
    end
end

function Themes.GetDefaults()
    return Themes.NewDefault()
end

addon.Themes = Themes