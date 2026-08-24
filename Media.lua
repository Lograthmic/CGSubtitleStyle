local addonName, addon = ...
local L = addon.L

local Media = {}

-- Font files are shipped per client locale, so the font list must follow the
-- client locale: Western fonts cannot render (and are not present) on a
-- zhCN/zhTW/koKR client, and CJK fonts do not exist on Western clients.
-- The chosen UI language only affects the localized labels, not which fonts
-- are actually usable on this client.
local locale = GetLocale()
local clientLocale = locale

local function BuildFontList()
    local fonts = {
        { text = L.FONT_DEFAULT, key = "" },
    }
    if locale == "zhCN" then
        fonts[#fonts + 1] = { text = L.FONT_ARKAI_T, key = "Fonts\\ARKai_T.ttf" }
        fonts[#fonts + 1] = { text = L.FONT_ARKAI_C, key = "Fonts\\ARKai_C.ttf" }
        fonts[#fonts + 1] = { text = L.FONT_ARHEI, key = "Fonts\\ARHei.ttf" }
    elseif locale == "zhTW" then
        fonts[#fonts + 1] = { text = L.FONT_BLEI, key = "Fonts\\bLEI00D.ttf" }
        fonts[#fonts + 1] = { text = L.FONT_BKAI, key = "Fonts\\bKAI00M.ttf" }
        fonts[#fonts + 1] = { text = L.FONT_BHEI, key = "Fonts\\bHEI00M.ttf" }
        fonts[#fonts + 1] = { text = L.FONT_BHEI1, key = "Fonts\\bHEI01B.ttf" }
    elseif locale == "koKR" then
        fonts[#fonts + 1] = { text = "2002", key = "Fonts\\2002.TTF" }
        fonts[#fonts + 1] = { text = "2002B", key = "Fonts\\2002B.TTF" }
        fonts[#fonts + 1] = { text = "K_Damage", key = "Fonts\\K_Damage.TTF" }
        fonts[#fonts + 1] = { text = "K_Pagetext", key = "Fonts\\K_Pagetext.TTF" }
    elseif locale == "ruRU" then
        fonts[#fonts + 1] = { text = "FRIZQT___CYR", key = "Fonts\\FRIZQT___CYR.TTF" }
        fonts[#fonts + 1] = { text = "MORPHEUS_CYR", key = "Fonts\\MORPHEUS_CYR.TTF" }
        fonts[#fonts + 1] = { text = "SKURRI_CYR", key = "Fonts\\SKURRI_CYR.TTF" }
    else
        fonts[#fonts + 1] = { text = "Friz Quadrata", key = "Fonts\\FRIZQT__.TTF" }
        fonts[#fonts + 1] = { text = "Arial Narrow", key = "Fonts\\ARIALN.TTF" }
        fonts[#fonts + 1] = { text = "Morpheus", key = "Fonts\\MORPHEUS.TTF" }
        fonts[#fonts + 1] = { text = "Skurri", key = "Fonts\\SKURRI.TTF" }
    end
    -- ARIALN has broad Latin/Cyrillic coverage but no CJK/Hangul glyphs, so it
    -- is only offered where it can actually render the locale's text.
    local hasArial = false
    for _, f in ipairs(fonts) do
        if f.key == "Fonts\\ARIALN.TTF" then
            hasArial = true
            break
        end
    end
    if not hasArial and locale ~= "zhCN" and locale ~= "zhTW" and locale ~= "koKR" then
        fonts[#fonts + 1] = { text = "Arial Narrow", key = "Fonts\\ARIALN.TTF" }
    end
    return fonts
end

Media.fonts = BuildFontList()

Media.outlineStyles = {
    { text = L.OUTLINE_NONE, key = "NONE", width = 0 },
    { text = L.OUTLINE_THIN, key = "OUTLINE", width = 1 },
    { text = L.OUTLINE_THICK, key = "THICKOUTLINE", width = 2 },
    { text = L.OUTLINE_CUSTOM, key = "CUSTOM", width = 0 },
}

Media.borderStyles = {
    { text = L.BORDER_NONE, key = "none", edgeFile = nil },
    { text = L.BORDER_SOLID, key = "solid", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } },
    { text = L.BORDER_TOOLTIP, key = "tooltip", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
    { text = L.BORDER_DIALOG, key = "dialog", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } },
}

Media.anchors = { "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

function Media.GetOutlineBaseWidth(key)
    for _, style in ipairs(Media.outlineStyles) do
        if style.key == key then return style.width or 0 end
    end
    return 0
end

function Media.GetFontIndex(path)
    for i, font in ipairs(Media.fonts) do
        if font.key == path then return i end
    end
    return 1
end

function Media.GetBorderInfo(key)
    for _, style in ipairs(Media.borderStyles) do
        if style.key == key then return style end
    end
    return Media.borderStyles[1]
end

function Media.GetDefaultFontFile()
    if STANDARD_TEXT_FONT and STANDARD_TEXT_FONT ~= "" then
        return STANDARD_TEXT_FONT
    end
    if MovieSubtitleFont then
        local file = MovieSubtitleFont:GetFont()
        if file and file ~= "" then
            return file
        end
    end
    if clientLocale == "zhCN" then
        return "Fonts\\ARKai_T.ttf"
    end
    if clientLocale == "zhTW" then
        return "Fonts\\bLEI00D.ttf"
    end
    if clientLocale == "koKR" then
        return "Fonts\\2002.TTF"
    end
    return "Fonts\\FRIZQT__.TTF"
end

addon.Media = Media
