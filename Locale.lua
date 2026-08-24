local addonName, addon = ...

-- Language data lives in Localization/<locale>.lua (pure tables registered on
-- addon.Locales). This file only picks the right table: an explicit user
-- preference stored in the SavedVariables (db.language) wins, otherwise the
-- client locale is used.

local Locales = addon.Locales or {}

local function GetLocaleTable(pref)
    if pref == "zhCN" then return Locales.zhCN end
    if pref == "zhTW" then return Locales.zhTW end
    if pref == "enUS" then return Locales.enUS end
    local locale = GetLocale()
    if locale == "zhCN" then return Locales.zhCN end
    if locale == "zhTW" then return Locales.zhTW end
    return Locales.enUS
end
addon.GetLocaleTable = GetLocaleTable

local function GetLanguage()
    local db = CGSubtitleStyleDB or {}
    local pref = db.language
    if pref == "zhCN" or pref == "zhTW" or pref == "enUS" then
        return pref
    end
    return "auto"
end
addon.GetLanguage = GetLanguage

function addon.SetLanguage(pref)
    if pref ~= "zhCN" and pref ~= "zhTW" and pref ~= "enUS" then
        pref = "auto"
    end
    local db = CGSubtitleStyleDB or {}
    CGSubtitleStyleDB = db
    db.language = pref
    addon.L = GetLocaleTable(pref)
end

addon.L = GetLocaleTable(GetLanguage())