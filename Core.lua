local addonName, addon = ...
local L = addon.L
local Themes = addon.Themes
local Media = addon.Media

local Core = {}
addon.Core = Core

-- Filled-square outline: every integer offset with max(|dx|,|dy|) <= width
-- (excluding the centre), so the outline is a continuous even silhouette
-- instead of a sparse set of offset text copies.
local MAX_OUTLINE_LAYERS = 80

local BACKGROUND_TEXTURE = "Interface\\Buttons\\WHITE8X8"

-- Tight padding used when no border is drawn (the "内边距" setting only applies
-- to wrap native UI borders around the text).
local BASE_LINE_PADDING = { left = 12, right = 12, top = 4, bottom = 4 }

local WESTERN_ONLY_FONTS = {
    ["Fonts\\FRIZQT__.TTF"] = true,
    ["Fonts\\FRIZQT__.ttf"] = true,
    ["Fonts\\MORPHEUS.TTF"] = true,
    ["Fonts\\MORPHEUS.ttf"] = true,
    ["Fonts\\SKURRI.TTF"] = true,
    ["Fonts\\SKURRI.ttf"] = true,
    ["Fonts\\ARIALN.TTF"] = true,
    ["Fonts\\ARIALN.ttf"] = true,
}

local function ResolveFontFile(path)
    if path and path ~= "" then
        local locale = GetLocale()
        if (locale == "zhCN" or locale == "zhTW" or locale == "koKR") and WESTERN_ONLY_FONTS[path] then
            return Media.GetDefaultFontFile()
        end
        return path
    end
    return Media.GetDefaultFontFile()
end

local function ApplyFont(fs, fontFile, size, flags)
    flags = flags or ""
    size = size or 18
    if not fontFile or fontFile == "" then
        fontFile = Media.GetDefaultFontFile()
    end
    if fs:SetFont(fontFile, size, flags) then
        return fontFile
    end
    local fallback = Media.GetDefaultFontFile()
    if fallback ~= fontFile then
        if fs:SetFont(fallback, size, flags) then
            return fallback
        end
    end
    -- Last resort: empty flags (some clients reject MONOCHROME on certain fonts).
    if flags ~= "" and fs:SetFont(fallback, size, "") then
        return fallback
    end
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, "")
    return "Fonts\\FRIZQT__.TTF"
end

local function EnsureFont(fs)
    if fs:GetFont() then
        return true
    end
    ApplyFont(fs, Media.GetDefaultFontFile(), 18, "")
    return fs:GetFont() ~= nil
end

local function SafeSetText(fs, text)
    if not EnsureFont(fs) then
        return
    end
    fs:SetText(text)
end

local function CreateLine(parent)
    local line = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    line:Hide()
    line.text = line:CreateFontString(nil, "OVERLAY")
    line.text:SetJustifyH("CENTER")
    line.text:SetJustifyV("MIDDLE")
    line.text:SetWordWrap(true)
    ApplyFont(line.text, Media.GetDefaultFontFile(), 18, "")
    line.outlines = {}
    for i = 1, MAX_OUTLINE_LAYERS do
        local fs = line:CreateFontString(nil, "BORDER")
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:SetWordWrap(true)
        ApplyFont(fs, Media.GetDefaultFontFile(), 18, "")
        fs:Hide()
        line.outlines[i] = fs
    end
    return line
end

local function HideOutlines(line)
    for i = 1, #line.outlines do
        local fs = line.outlines[i]
        fs:Hide()
        if fs:GetFont() then
            fs:SetText("")
        end
    end
end

local function BuildOutlineOffsets(width)
    -- Solid filled square of radius w: no gaps between directions, so thicker
    -- outlines read as one even border instead of visibly stacked text copies.
    local w = math.max(1, math.min(4, math.floor(width + 0.5)))
    local offsets = {}
    for dy = -w, w do
        for dx = -w, w do
            if dx ~= 0 or dy ~= 0 then
                offsets[#offsets + 1] = { dx, dy }
            end
        end
    end
    return offsets
end

local function ApplyLineTheme(line, st, globalTheme)
    local fontFile = ResolveFontFile(st.font)
    local size = st.fontSize or 18
    local outlineKey = st.outlineStyle or "OUTLINE"

    line.maxWidth = globalTheme.maxWidth or 800

    fontFile = ApplyFont(line.text, fontFile, size, "")

    local function Chan(c, i, fallback)
        local v = c and c[i]
        if type(v) == "number" then
            return v
        end
        return fallback
    end

    local tc = st.textColor or { 1, 1, 1, 1 }
    line.text:SetTextColor(Chan(tc, 1, 1), Chan(tc, 2, 1), Chan(tc, 3, 1), Chan(tc, 4, 1))
    line.text:SetWidth(line.maxWidth)

    local shadow = st.shadow or {}
    if shadow.enabled then
        local sc = shadow.color or { 0, 0, 0, 1 }
        line.text:SetShadowColor(Chan(sc, 1, 0), Chan(sc, 2, 0), Chan(sc, 3, 0), Chan(sc, 4, 1))
        line.text:SetShadowOffset(shadow.x or 1, shadow.y or -1)
    else
        line.text:SetShadowColor(0, 0, 0, 0)
        line.text:SetShadowOffset(0, 0)
    end

    HideOutlines(line)

    local outlineWidth = 0
    if outlineKey == "CUSTOM" then
        outlineWidth = math.max(1, math.min(4, math.floor(tonumber(st.outlineWidth) or 1)))
    else
        outlineWidth = Media.GetOutlineBaseWidth(outlineKey)
    end

    if outlineWidth > 0 then
        local ocolor = st.outlineColor or { 0, 0, 0, 1 }
        local offsets = BuildOutlineOffsets(outlineWidth)
        local count = math.min(#offsets, #line.outlines)
        for i = 1, count do
            local fs = line.outlines[i]
            ApplyFont(fs, fontFile, size, "")
            fs:SetTextColor(Chan(ocolor, 1, 0), Chan(ocolor, 2, 0), Chan(ocolor, 3, 0), Chan(ocolor, 4, 1))
            fs:SetShadowColor(0, 0, 0, 0)
            fs:SetShadowOffset(0, 0)
            fs:SetWidth(line.maxWidth)
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", line.text, "CENTER", offsets[i][1], offsets[i][2])
            fs:Show()
        end
    end

    local bg = st.background or {}
    local bd = st.border or {}
    local borderInfo = Media.GetBorderInfo(bd.style)
    local bgTexture = BACKGROUND_TEXTURE
    local bgColor = bg.color or { 0, 0, 0, 1 }
    local bdColor = bd.color or { 1, 1, 1, 1 }
    local bgAlpha = bg.alpha
    if type(bgAlpha) ~= "number" then
        bgAlpha = Chan(bgColor, 4, 1)
    end

    local backdrop = {}
    if bg.enabled then
        backdrop.bgFile = bgTexture
    end
    if bd.enabled and borderInfo.edgeFile then
        backdrop.edgeFile = borderInfo.edgeFile
        if bd.style == "solid" then
            backdrop.edgeSize = bd.thickness or 1
        else
            backdrop.edgeSize = borderInfo.edgeSize
        end
        backdrop.insets = borderInfo.insets
    end

    if next(backdrop) then
        line:SetBackdrop(backdrop)
        if bg.enabled then
            line:SetBackdropColor(Chan(bgColor, 1, 0), Chan(bgColor, 2, 0), Chan(bgColor, 3, 0), bgAlpha)
        else
            line:SetBackdropColor(0, 0, 0, 0)
        end
        if bd.enabled and borderInfo.edgeFile then
            line:SetBackdropBorderColor(Chan(bdColor, 1, 1), Chan(bdColor, 2, 1), Chan(bdColor, 3, 1), Chan(bdColor, 4, 1))
        else
            line:SetBackdropBorderColor(0, 0, 0, 0)
        end
    else
        line:SetBackdrop(nil)
    end

    -- Only apply the user "内边距" when a border is actually drawn; otherwise
    -- use the tight base padding so the subtitle isn't stretched.
    if bd.enabled and borderInfo.edgeFile then
        local p = st.padding or {}
        line.padding = {
            left = type(p.left) == "number" and p.left or 12,
            right = type(p.right) == "number" and p.right or 12,
            top = type(p.top) == "number" and p.top or 12,
            bottom = type(p.bottom) == "number" and p.bottom or 12,
        }
    else
        line.padding = BASE_LINE_PADDING
    end
end

local function SetLineText(line, text)
    SafeSetText(line.text, text)
    for i = 1, #line.outlines do
        local fs = line.outlines[i]
        if fs:IsShown() then
            SafeSetText(fs, text)
        end
    end
end

local function SizeLine(line)
    local pad = line.padding or { left = 0, right = 0, top = 0, bottom = 0 }
    local maxW = line.maxWidth or 800
    local textW = line.text:GetStringWidth() or 0
    if textW > maxW then textW = maxW end
    local w = textW + pad.left + pad.right
    local h = (line.text:GetStringHeight() or 0) + pad.top + pad.bottom
    if w < 8 then w = 8 end
    if h < 8 then h = 8 end
    line:SetWidth(w)
    line:SetHeight(h)
    line.text:ClearAllPoints()
    line.text:SetPoint("TOPLEFT", line, "TOPLEFT", pad.left, -pad.top)
    line.text:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", -pad.right, pad.bottom)
end

local function GetLayoutParent()
    -- Prefer the active cinematic/movie frame so coords match the visible screen
    -- and the frame stays shown while UIParent is hidden during pre-rendered CG.
    if MovieFrame and MovieFrame:IsShown() then
        return MovieFrame
    end
    if CinematicFrame and CinematicFrame:IsShown() then
        return CinematicFrame
    end
    if UIParent then
        return UIParent
    end
    return nil
end

-- Normalize the container's effective scale so subtitles render at the same
-- size in the preview (parented to UIParent) and inside a cinematic (parented
-- to MovieFrame/CinematicFrame, which have a different effective scale).
local function NormalizeContainerScale(container)
    if not container then return end
    local parent = container:GetParent()
    if not parent or not parent.GetEffectiveScale then return end
    local uiScale = UIParent and UIParent:GetEffectiveScale() or 1
    local parentScale = parent:GetEffectiveScale() or 1
    if parentScale > 0 then
        container:SetScale(uiScale / parentScale)
    end
end

function Core:Layout()
    local t = self.theme and self.theme.global
    if not t then return end
    local contentLine = self.contentLine
    local speakerLine = self.speakerLine
    local gap = t.gap or 0

    local cw = contentLine:GetWidth()
    local ch = contentLine:GetHeight()
    local speakerShown = speakerLine:IsShown()
    local sw = speakerShown and speakerLine:GetWidth() or 0
    local sh = speakerShown and speakerLine:GetHeight() or 0

    self.container:SetWidth(math.max(cw, sw, 8))
    local totalH = ch
    if speakerShown then
        totalH = ch + gap + sh
    end
    self.container:SetHeight(math.max(totalH, 8))

    contentLine:ClearAllPoints()
    contentLine:SetPoint("BOTTOM", self.container, "BOTTOM", 0, 0)
    speakerLine:ClearAllPoints()
    speakerLine:SetPoint("TOP", self.container, "TOP", 0, 0)

    local parent = GetLayoutParent()
    if parent and self.container:GetParent() ~= parent then
        self.container:SetParent(parent)
    end
    NormalizeContainerScale(self.container)

    local anchor = t.anchor or "BOTTOM"
    local x = t.x or 0
    local y = t.y or 0
    self.container:ClearAllPoints()
    if parent then
        self.container:SetPoint(anchor, parent, anchor, x, y)
    else
        self.container:SetPoint(anchor, nil, anchor, x, y)
    end
end

function Core:EnsureReady()
    if not self.container then
        self:BuildFrames()
    end
    if not self.theme then
        self:ApplyTheme(Themes.GetActive())
    end
end

function Core:Render(subtitle, sender, isPreview)
    self:EnsureReady()
    local theme = self.theme
    if not theme then return end
    local t = theme.global
    if isPreview then
        -- Preview must never become the "last real subtitle" shown on CG start.
        self.lastRender = nil
    else
        self.lastRender = { subtitle, sender }
    end

    local showSpeaker = sender ~= nil and sender ~= ""

    local contentLine = self.contentLine
    local speakerLine = self.speakerLine

    ApplyLineTheme(contentLine, theme.content, t)
    SetLineText(contentLine, subtitle)
    SizeLine(contentLine)
    contentLine:Show()

    if showSpeaker then
        ApplyLineTheme(speakerLine, theme.speaker, t)
        SetLineText(speakerLine, sender)
        SizeLine(speakerLine)
        speakerLine:Show()
    else
        speakerLine:Hide()
    end

    self:Layout()
    if not self.cinematicActive then
        self.container:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    self.container:SetAlpha(t.alpha)
    self.container:Show()
end

function Core:OnSubtitle(subtitle, sender)
    self:EnsureReady()
    local theme = self.theme
    if not theme or not theme.global.enabled then return false end
    if theme.global.respectCvar and not GetCVarBool("movieSubtitle") then return false end
    self.previewShown = false
    self:Render(subtitle, sender, false)
    return true
end

function Core:HideSubtitles()
    if not self.container then return end
    self.speakerLine:Hide()
    self.contentLine:Hide()
    self.container:Hide()
end

function Core:StopPreview()
    if not self.previewShown then return end
    self.previewShown = false
    self:HideSubtitles()
end

local SilenceNativeSubtitles

function Core:ApplyTheme(theme)
    self.theme = Themes.Sanitize and Themes.Sanitize(theme) or theme
    SilenceNativeSubtitles()
    if self.previewShown then
        self:Render(L.CONTENT_PREVIEW, L.SPEAKER_PREVIEW, true)
    elseif self.container and self.container:IsShown() and self.lastRender then
        if self:IsEnabled() then
            self:Render(self.lastRender[1], self.lastRender[2], false)
        else
            self:HideSubtitles()
            self.lastRender = nil
        end
    end
end

function Core:Preview()
    if self.previewShown then
        self:StopPreview()
        return false
    end
    self.previewShown = true
    self:Render(L.CONTENT_PREVIEW, L.SPEAKER_PREVIEW, true)
    return true
end

local nativeSilenced = false
local savedMixinMethods = nil
local savedFrameMethods = nil

local MIXIN_METHODS = {
    "OnLoad",
    "OnEvent",
    "OnMovieCinematicPlay",
    "OnMovieCinematicStop",
    "AddSubtitle",
    "HideSubtitles",
}

function Core:IsEnabled()
    local theme = self.theme
    return theme ~= nil and theme.global ~= nil and theme.global.enabled ~= false
end

-- Capture the real Blizzard methods before we start overwriting them, so the
-- native subtitles can be restored when the addon is toggled off.
local function SaveNativeState()
    if savedMixinMethods then return true end
    if not SubtitlesFrameMixin or not SubtitlesFrameMixin.OnEvent then return false end
    savedMixinMethods = {}
    for k, v in pairs(SubtitlesFrameMixin) do
        savedMixinMethods[k] = v
    end
    savedFrameMethods = {}
    if SubtitlesFrame then
        for _, name in ipairs(MIXIN_METHODS) do
            savedFrameMethods[name] = SubtitlesFrame[name]
        end
    end
    return true
end

local function RestoreNativeState()
    if not nativeSilenced then return end
    if savedMixinMethods and SubtitlesFrameMixin then
        for k, v in pairs(savedMixinMethods) do
            SubtitlesFrameMixin[k] = v
        end
    end
    if savedFrameMethods and SubtitlesFrame then
        for name, fn in pairs(savedFrameMethods) do
            SubtitlesFrame[name] = fn
        end
        SubtitlesFrame:RegisterEvent("SHOW_SUBTITLE")
        SubtitlesFrame:RegisterEvent("HIDE_SUBTITLE")
        if EventRegistry then
            EventRegistry:RegisterCallback("Subtitles.OnMovieCinematicPlay", savedFrameMethods.OnMovieCinematicPlay, SubtitlesFrame)
            EventRegistry:RegisterCallback("Subtitles.OnMovieCinematicStop", savedFrameMethods.OnMovieCinematicStop, SubtitlesFrame)
        end
        if GetCVarBool then
            SubtitlesFrame.showSubtitles = GetCVarBool("movieSubtitle")
        end
        if (MovieFrame and MovieFrame:IsShown()) or (CinematicFrame and CinematicFrame:IsShown()) then
            local active = (MovieFrame and MovieFrame:IsShown()) and MovieFrame or CinematicFrame
            if active and SubtitlesFrame.OnMovieCinematicPlay then
                pcall(SubtitlesFrame.OnMovieCinematicPlay, SubtitlesFrame, active)
            else
                SubtitlesFrame:Show()
            end
        end
    end
    nativeSilenced = false
end

local function DoSilenceNativeSubtitles()
    if not SubtitlesFrame then return end
    if nativeSilenced then
        SubtitlesFrame:Hide()
        return
    end
    if not SaveNativeState() then return end
    if SubtitlesFrameMixin then
        SubtitlesFrameMixin.OnEvent = function() end
        SubtitlesFrameMixin.OnMovieCinematicPlay = function() end
        SubtitlesFrameMixin.OnMovieCinematicStop = function() end
        SubtitlesFrameMixin.AddSubtitle = function() end
        SubtitlesFrameMixin.HideSubtitles = function() end
    end
    local origPlay = savedFrameMethods.OnMovieCinematicPlay
    local origStop = savedFrameMethods.OnMovieCinematicStop
    if EventRegistry then
        if origPlay then
            pcall(EventRegistry.UnregisterCallback, EventRegistry, "Subtitles.OnMovieCinematicPlay", origPlay, SubtitlesFrame)
        end
        if origStop then
            pcall(EventRegistry.UnregisterCallback, EventRegistry, "Subtitles.OnMovieCinematicStop", origStop, SubtitlesFrame)
        end
    end
    SubtitlesFrame:UnregisterAllEvents()
    SubtitlesFrame:Hide()
    SubtitlesFrame.OnEvent = function() end
    SubtitlesFrame.OnMovieCinematicPlay = function() end
    SubtitlesFrame.OnMovieCinematicStop = function() end
    SubtitlesFrame.AddSubtitle = function() end
    SubtitlesFrame.HideSubtitles = function() end
    nativeSilenced = true
end

-- Only silence the native subtitles while the addon is enabled; when the user
-- turns the addon off, restore the Blizzard system subtitles instead.
SilenceNativeSubtitles = function()
    if Core:IsEnabled() then
        DoSilenceNativeSubtitles()
    else
        RestoreNativeState()
    end
end

function Core:BuildFrames()
    self.container = CreateFrame("Frame", "CGUISubtitleContainer", UIParent)
    self.container:SetFrameStrata("FULLSCREEN_DIALOG")
    self.container:SetFrameLevel(100)
    self.container:Hide()
    self.speakerLine = CreateLine(self.container)
    self.contentLine = CreateLine(self.container)
end

function Core:AttachToCinematic(frame)
    if not self.container then return end
    local parent = frame
    if not parent or not parent.IsObjectType or not parent:IsObjectType("Frame") then
        parent = GetLayoutParent() or UIParent
    end
    self.container:SetParent(parent)
    NormalizeContainerScale(self.container)
    local strata = "FULLSCREEN_DIALOG"
    local level = 100
    if parent.GetFrameStrata then
        local fs = parent:GetFrameStrata()
        if fs and fs ~= "" then
            strata = fs
        end
    end
    if parent.GetFrameLevel then
        level = (parent:GetFrameLevel() or 0) + 10
    end
    self.container:SetFrameStrata(strata)
    self.container:SetFrameLevel(level)
end

function Core:DetachFromCinematic()
    if not self.container then return end
    self.container:SetParent(UIParent)
    NormalizeContainerScale(self.container)
    self.container:SetFrameStrata("FULLSCREEN_DIALOG")
    self.container:SetFrameLevel(100)
end

function Core:OnMovieCinematicPlay(frame)
    self.cinematicActive = true
    SilenceNativeSubtitles()
    if not self:IsEnabled() then
        if SubtitlesFrame and SubtitlesFrame.OnMovieCinematicPlay then
            pcall(SubtitlesFrame.OnMovieCinematicPlay, SubtitlesFrame, frame)
        end
        return
    end
    self:StopPreview()
    self:HideSubtitles()
    self.lastRender = nil
    self:EnsureReady()
    self:AttachToCinematic(frame)
    -- Do not paint anything here; wait for SHOW_SUBTITLE.
end

function Core:OnMovieCinematicStop()
    self.cinematicActive = false
    SilenceNativeSubtitles()
    if not self:IsEnabled() then
        if SubtitlesFrame and SubtitlesFrame.OnMovieCinematicStop then
            pcall(SubtitlesFrame.OnMovieCinematicStop, SubtitlesFrame)
        end
        return
    end
    self:StopPreview()
    self:HideSubtitles()
    self.lastRender = nil
    self:DetachFromCinematic()
end

function Core:OnAddonLoaded()
    Themes.Init()
    self:BuildFrames()
    self:ApplyTheme(Themes.GetActive())
    if EventRegistry then
        EventRegistry:RegisterCallback("Subtitles.OnMovieCinematicPlay", self.OnMovieCinematicPlay, self)
        EventRegistry:RegisterCallback("Subtitles.OnMovieCinematicStop", self.OnMovieCinematicStop, self)
    end
end

local eventFrame = CreateFrame("Frame", "CGUISubtitleEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("SHOW_SUBTITLE")
eventFrame:RegisterEvent("HIDE_SUBTITLE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            Core:OnAddonLoaded()
        elseif loaded == "Blizzard_Subtitles" then
            SilenceNativeSubtitles()
        end
    elseif event == "PLAYER_LOGIN" then
        SilenceNativeSubtitles()
    elseif event == "SHOW_SUBTITLE" then
        local subtitle, sender = ...
        SilenceNativeSubtitles()
        Core:StopPreview()
        if not Core:OnSubtitle(subtitle, sender) then
            Core:HideSubtitles()
        end
    elseif event == "HIDE_SUBTITLE" then
        if Core.container then
            Core.lastRender = nil
            if not Core.previewShown then
                Core:HideSubtitles()
            end
        end
    end
end)