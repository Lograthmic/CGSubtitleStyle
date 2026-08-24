local addonName, addon = ...
local L = addon.L
local Themes = addon.Themes
local Media = addon.Media
local Serializer = addon.Serializer
local Core = addon.Core

local Options = {}
addon.Options = Options

local function ActiveTheme()
    return Themes.GetActive()
end

local function AfterChange()
    local okT, errT = pcall(Core.ApplyTheme, Core, ActiveTheme())
    if not okT and errT then
        print("CGUI ApplyTheme error: " .. tostring(errT))
    end
    local okR, errR = pcall(Options.RefreshVisuals, Options)
    if not okR and errR then
        print("CGUI RefreshVisuals error: " .. tostring(errR))
    end
end

local function Bind(rootGetter, path)
    return {
        get = function()
            local cur = rootGetter()
            if not cur then return nil end
            for seg in string.gmatch(path, "[^%.]+") do
                cur = cur[seg]
                if cur == nil then return nil end
            end
            return cur
        end,
        set = function(v)
            local root = rootGetter()
            local segs = {}
            for seg in string.gmatch(path, "[^%.]+") do
                segs[#segs + 1] = seg
            end
            local cur = root
            for i = 1, #segs - 1 do
                local seg = segs[i]
                if cur[seg] == nil then cur[seg] = {} end
                cur = cur[seg]
            end
            cur[segs[#segs]] = v
            AfterChange()
        end,
    }
end

local function BindGlobal(path)
    return Bind(function() return ActiveTheme().global end, path)
end

local function BindSection(section)
    return function(path)
        return Bind(function() return ActiveTheme()[section] end, path)
    end
end

local controls = {}

local function RegisterControl(control)
    controls[#controls + 1] = control
    return control
end

function Options:RefreshVisuals()
    for _, control in ipairs(controls) do
        if control.refresh then
            control.refresh()
        end
    end
end

local function CreateRow(parent, labelText, y, height)
    height = height or 26
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
    row:SetHeight(height)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(labelText)
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.label = label
    return row
end

local function CreateHeader(parent, text, y)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
    header:SetHeight(24)
    local textFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    textFS:SetText(text)
    textFS:SetJustifyH("LEFT")
    textFS:SetTextColor(1, 0.82, 0)
    textFS:SetPoint("LEFT", header, "LEFT", 2, 0)
    return header
end

local function CreateCheckbox(row, bind, tooltip)
    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    cb:SetChecked(not not bind.get())
    cb:SetScript("OnClick", function(self)
        bind.set(not not self:GetChecked())
    end)
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    RegisterControl({
        refresh = function()
            cb:SetChecked(bind.get())
        end,
    })
    return cb
end

local function CreateSlider(row, bind, min, max, step, formatValue)
    local slider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
    slider:SetSize(150, 18)
    slider:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetJustifyH("RIGHT")
    valueText:SetPoint("RIGHT", slider, "LEFT", -6, 0)
    local function SetValueText(v)
        valueText:SetText(formatValue(v))
    end
    slider:SetScript("OnValueChanged", function(self, value)
        if not self.locked then
            bind.set(value)
        end
        SetValueText(value)
    end)
    slider.locked = true
    local initial = bind.get()
    if type(initial) ~= "number" then initial = min end
    slider:SetValue(initial)
    SetValueText(initial)
    slider.locked = false
    RegisterControl({
        refresh = function()
            slider.locked = true
            local v = bind.get()
            if type(v) ~= "number" then v = min end
            slider:SetValue(v)
            SetValueText(v)
            slider.locked = false
        end,
    })
    return slider
end

local openDropdownMenu = nil

local function CloseDropdown()
    if openDropdownMenu then
        openDropdownMenu:Hide()
        openDropdownMenu = nil
    end
end

local dropdownGuard = CreateFrame("Frame", "CGUIDropdownCloseGuard")
dropdownGuard:RegisterEvent("GLOBAL_MOUSE_DOWN")
dropdownGuard:SetScript("OnEvent", function()
    local menu = openDropdownMenu
    if not menu then return end
    local foci = (GetMouseFoci and GetMouseFoci()) or {}
    if #foci == 0 and GetMouseFocus then
        local f = GetMouseFocus()
        if f then foci = { f } end
    end
    for _, f in ipairs(foci) do
        while f do
            if f == menu or f == menu.toggle then
                return
            end
            f = f.GetParent and f:GetParent() or nil
        end
    end
    menu:Hide()
    openDropdownMenu = nil
end)

local function CreateDropdown(row, bind, optionsProvider, width)
    width = width or 150
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    button:SetNormalFontObject(GameFontNormalSmall)
    button:SetHighlightFontObject(GameFontHighlightSmall)

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetToplevel(true)
    menu:SetSize(width, 1)
    menu:EnableMouse(true)
    menu:Hide()
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menu:SetBackdropColor(0.1, 0.1, 0.12, 1)
    menu:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    menu.toggle = button

    local items = {}
    local function CloseMenu()
        menu:Hide()
        if openDropdownMenu == menu then openDropdownMenu = nil end
    end

    local function SetDisplayText()
        local current = bind.get()
        for _, opt in ipairs(optionsProvider()) do
            if opt.key == current then
                button:SetText(opt.text)
                return
            end
        end
        button:SetText(tostring(current))
    end

    button:SetScript("OnClick", function()
        if openDropdownMenu == menu then
            CloseMenu()
            return
        end
        if openDropdownMenu then
            openDropdownMenu:Hide()
        end
        openDropdownMenu = menu
        local options = optionsProvider()
        for i, opt in ipairs(options) do
            local item = items[i]
            if not item then
                item = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
                item:SetHeight(24)
                item:SetNormalFontObject(GameFontNormalSmall)
                item:SetHighlightFontObject(GameFontHighlightSmall)
                items[i] = item
            end
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * 26)
            item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2 - (i - 1) * 26)
            item:SetHeight(24)
            item:SetText(opt.text)
            item:SetScript("OnClick", function()
                bind.set(opt.key)
                CloseMenu()
            end)
            item:Show()
        end
        for i = #options + 1, #items do
            items[i]:Hide()
        end
        local menuWidth = width
        for i = 1, #options do
            local fs = items[i]:GetFontString()
            if fs then
                menuWidth = math.max(menuWidth, fs:GetStringWidth() + 24)
            end
        end
        menu:SetWidth(menuWidth)
        menu:SetHeight(#options * 26 + 4)
        menu:ClearAllPoints()
        local btnBottom = button:GetBottom()
        if btnBottom and (btnBottom - 2 - menu:GetHeight()) < 0 then
            menu:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 2)
        else
            menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
        end
        menu:Show()
    end)

    RegisterControl({
        refresh = SetDisplayText,
    })
    SetDisplayText()
    return button
end

local function CopyColor(c)
    c = c or { 1, 1, 1, 1 }
    return {
        c[1] or 1,
        c[2] or 1,
        c[3] or 1,
        c[4] or 1,
    }
end

local function UpdateSwatchColor(swatch, c)
    c = c or { 1, 1, 1, 1 }
    local r, g, b, a = c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
    swatch.color:SetVertexColor(r, g, b, 1)
    swatch.color:SetAlpha(a)
end

local function ReadPickerRGBA()
    if not ColorPickerFrame or not ColorPickerFrame.GetColorRGB then
        return nil
    end
    local r, g, b = ColorPickerFrame:GetColorRGB()
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if not r or not g or not b then
        return nil
    end
    local a = 1
    if ColorPickerFrame.GetColorAlpha then
        a = tonumber(ColorPickerFrame:GetColorAlpha())
    elseif OpacitySliderFrame and OpacitySliderFrame.GetValue then
        a = tonumber(OpacitySliderFrame:GetValue())
    elseif type(ColorPickerFrame.opacity) == "number" then
        a = ColorPickerFrame.opacity
    end
    if not a then
        a = 1
    end
    if a < 0 then a = 0 end
    if a > 1 then a = 1 end
    return r, g, b, a
end

local function CreateColorSwatch(row, bind, tooltip, opts)
    opts = opts or {}
    local hasOpacity = opts.hasOpacity ~= false
    local alphaPath = opts.alphaPath
    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
    swatch:SetSize(30, 20)
    swatch:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    swatch:SetBackdropBorderColor(0, 0, 0, 0.8)
    swatch.color = swatch:CreateTexture(nil, "ARTWORK")
    swatch.color:SetPoint("TOPLEFT", 3, -3)
    swatch.color:SetPoint("BOTTOMRIGHT", -3, 3)
    swatch.color:SetTexture("Interface\\Buttons\\WHITE8X8")
    swatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(tooltip or L.CLICK_TO_CHANGE, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function GetEffectiveColor()
        local c = CopyColor(bind.get())
        if alphaPath then
            local a = alphaPath.get()
            if type(a) == "number" then
                c[4] = a
            end
        end
        return c
    end

    -- Always assign a fresh table through bind.set so wrappers run and
    -- SavedVariables stay consistent.
    local function ApplyColor(r, g, b, a)
        r = tonumber(r)
        g = tonumber(g)
        b = tonumber(b)
        a = tonumber(a)
        if not r or not g or not b then
            return
        end
        if not a then a = 1 end
        if a < 0 then a = 0 end
        if a > 1 then a = 1 end

        if alphaPath then
            bind.set({ r, g, b, 1 })
            alphaPath.set(a)
        else
            bind.set({ r, g, b, a })
        end
    end

    swatch:SetScript("OnClick", function()
        local c = GetEffectiveColor()
        local previous = CopyColor(c)
        -- Tracks whether the picker was closed via cancel (so the OnHide
        -- final-sync does not undo a cancel).
        local cancelled = false

        local function DoApply(r, g, b, a)
            if not r then
                return
            end
            -- Always reflect the picked color on the swatch immediately, even
            -- if the theme write is delayed/fails.
            UpdateSwatchColor(swatch, { r, g, b, a })
            local ok, err = pcall(ApplyColor, r, g, b, a)
            if not ok then
                print("CGUI color apply error: " .. tostring(err))
            end
        end

        local function onChanged()
            cancelled = false
            local r, g, b, a = ReadPickerRGBA()
            DoApply(r, g, b, a)
        end

        local function onCancel(prev)
            cancelled = true
            if type(prev) == "table" then
                DoApply(
                    prev.r or previous[1],
                    prev.g or previous[2],
                    prev.b or previous[3],
                    prev.a or prev.opacity or previous[4]
                )
            else
                DoApply(previous[1], previous[2], previous[3], previous[4])
            end
        end

        local function finalSync()
            if cancelled then
                return
            end
            local r, g, b, a = ReadPickerRGBA()
            if r then
                DoApply(r, g, b, a)
            end
        end

        -- Final safety net: when the picker closes via OK (or outside click
        -- that isn't a cancel), re-read the picker and apply once more.
        if not ColorPickerFrame._cguiHooked then
            ColorPickerFrame:HookScript("OnHide", function()
                if ColorPickerFrame._cguiOnHide then
                    ColorPickerFrame._cguiOnHide()
                end
            end)
            ColorPickerFrame._cguiHooked = true
        end
        ColorPickerFrame._cguiOnHide = finalSync

        local info = {
            r = c[1],
            g = c[2],
            b = c[3],
            opacity = hasOpacity and c[4] or 1,
            hasOpacity = hasOpacity,
            swatchFunc = onChanged,
            opacityFunc = onChanged,
            cancelFunc = onCancel,
        }

        local okSetup, setupErr = pcall(ColorPickerFrame.SetupColorPickerAndShow, ColorPickerFrame, info)
        if not okSetup then
            print("CGUI color picker error: " .. tostring(setupErr))
            -- Fallback to the classic API.
            ColorPickerFrame.func = onChanged
            ColorPickerFrame.swatchFunc = onChanged
            ColorPickerFrame.opacityFunc = onChanged
            ColorPickerFrame.cancelFunc = onCancel
            ColorPickerFrame.hasOpacity = hasOpacity
            ColorPickerFrame.opacity = hasOpacity and c[4] or 1
            ColorPickerFrame.previousValues = { r = c[1], g = c[2], b = c[3], a = c[4], opacity = c[4] }
            ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
            ColorPickerFrame:Hide()
            ColorPickerFrame:Show()
        else
            if hasOpacity and ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker and ColorPickerFrame.Content.ColorPicker.SetColorAlpha then
                ColorPickerFrame.Content.ColorPicker:SetColorAlpha(info.opacity)
            end
        end
    end)
    RegisterControl({
        refresh = function()
            UpdateSwatchColor(swatch, GetEffectiveColor())
        end,
    })
    UpdateSwatchColor(swatch, GetEffectiveColor())
    return swatch
end

-- Field groups shown as tabs inside the Speaker / Subtitle categories.
local LINE_TABS = {
    { title = L.TAB_TEXT, order = {
        { "font", "dropdown" },
        { "fontSize", "slider" },
        { "textColor", "color" },
    } },
    { title = L.TAB_OUTLINE, order = {
        { "outlineStyle", "dropdown" },
        { "outlineColor", "color" },
        { "outlineWidth", "slider" },
    } },
    { title = L.TAB_SHADOW, order = {
        { "shadow.enabled", "checkbox" },
        { "shadow.color", "color" },
    } },
    { title = L.TAB_BACKGROUND, order = {
        { "background.enabled", "checkbox" },
        { "background.color", "color" },
        { "background.alpha", "slider" },
    } },
    { title = L.TAB_BORDER, order = {
        { "border.enabled", "checkbox" },
        { "border.style", "dropdown" },
        { "border.color", "color" },
        { "border.thickness", "slider" },
        { "padding", "slider" },
    } },
}

local function BuildLineRows(parent, sectionBind, order, y)
    for _, item in ipairs(order) do
        local path = item[1]
        local kind = item[2]
        local bind = sectionBind(path)
        local row

        if kind == "dropdown" then
            if path == "font" then
                row = CreateRow(parent, L.FONT, y)
                CreateDropdown(row, bind, function() return Media.fonts end, 150)
            elseif path == "outlineStyle" then
                row = CreateRow(parent, L.OUTLINE_STYLE, y)
                CreateDropdown(row, bind, function() return Media.outlineStyles end, 150)
            elseif path == "border.style" then
                row = CreateRow(parent, L.BORDER_STYLE, y)
                CreateDropdown(row, bind, function() return Media.borderStyles end, 150)
            end
        elseif kind == "checkbox" then
            if path == "shadow.enabled" then
                row = CreateRow(parent, L.SHADOW, y)
                CreateCheckbox(row, bind)
            elseif path == "background.enabled" then
                row = CreateRow(parent, L.BACKGROUND, y)
                CreateCheckbox(row, bind)
            elseif path == "border.enabled" then
                row = CreateRow(parent, L.BORDER, y)
                CreateCheckbox(row, bind)
            end
        elseif kind == "color" then
            if path == "textColor" then
                row = CreateRow(parent, L.TEXT_COLOR, y)
                CreateColorSwatch(row, bind)
            elseif path == "outlineColor" then
                row = CreateRow(parent, L.OUTLINE_COLOR, y)
                CreateColorSwatch(row, bind)
            elseif path == "shadow.color" then
                row = CreateRow(parent, L.SHADOW_COLOR, y)
                CreateColorSwatch(row, bind)
            elseif path == "background.color" then
                row = CreateRow(parent, L.BACKGROUND_COLOR, y)
                -- Background uses separate alpha slider; color picker writes RGB + syncs alpha.
                CreateColorSwatch(row, bind, nil, {
                    hasOpacity = true,
                    alphaPath = sectionBind("background.alpha"),
                })
            elseif path == "border.color" then
                row = CreateRow(parent, L.BORDER_COLOR, y)
                CreateColorSwatch(row, bind)
            end
        elseif kind == "slider" then
            if path == "fontSize" then
                row = CreateRow(parent, L.FONT_SIZE, y)
                CreateSlider(row, bind, 10, 60, 1, function(v) return string.format("%d", v) end)
            elseif path == "outlineWidth" then
                row = CreateRow(parent, L.OUTLINE_WIDTH, y)
                CreateSlider(row, bind, 1, 4, 1, function(v) return string.format("%d", v) end)
                -- Only shown when the outline style is "custom".
                local styleBind = sectionBind("outlineStyle")
                RegisterControl({
                    refresh = function()
                        row:SetShown(styleBind.get() == "CUSTOM")
                    end,
                })
            elseif path == "background.alpha" then
                row = CreateRow(parent, L.BACKGROUND_ALPHA, y)
                CreateSlider(row, bind, 0, 1, 0.01, function(v) return string.format("%.2f", v) end)
            elseif path == "border.thickness" then
                row = CreateRow(parent, L.BORDER_THICKNESS, y)
                CreateSlider(row, bind, 1, 8, 1, function(v) return string.format("%d", v) end)
            elseif path == "padding" then
                row = CreateRow(parent, L.PADDING, y)
                local padBind = sectionBind("padding")
                local sliderBind = {
                    get = function()
                        local p = padBind.get() or {}
                        local v = p.left
                        if type(v) ~= "number" then v = 12 end
                        return v
                    end,
                    set = function(v)
                        padBind.set({ left = v, right = v, top = v, bottom = v })
                    end,
                }
                local slider = CreateSlider(row, sliderBind, 0, 60, 1, function(v) return string.format("%d", v) end)
                -- Padding only applies while the border is enabled.
                local borderEnabledBind = sectionBind("border.enabled")
                RegisterControl({
                    refresh = function()
                        slider:SetEnabled(not not borderEnabledBind.get())
                    end,
                })
            end
        end

        y = y - (row and row:GetHeight() or 26) - 4
    end

    return y
end

local function BuildTabbedFrame(parent, title, sectionName)
    local sectionBind = BindSection(sectionName)
    CreateHeader(parent, title, -2)

    local tabBar = CreateFrame("Frame", nil, parent)
    tabBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -30)
    tabBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -30)
    tabBar:SetHeight(37)

    -- Rounded rectangle panel that wraps all the tab options, matching the
    -- in-game options-menu style (the active tab opens downward into it).
    local contentBox = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    contentBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -64)
    contentBox:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    contentBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    contentBox:SetBackdropColor(0.05, 0.05, 0.08, 0.55)
    contentBox:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)

    local tabs = {}
    local panels = {}

    local function SelectTab(index)
        for i, tab in ipairs(tabs) do
            if tab.SetSelected then
                tab:SetSelected(i == index)
            end
        end
        for i, panel in ipairs(panels) do
            panel:SetShown(i == index)
        end
    end

    local x = 0
    for i, tabDef in ipairs(LINE_TABS) do
        local tab = CreateFrame("Button", nil, tabBar, "MinimalTabTemplate")
        tab:SetID(i)
        tab.tabText = tabDef.title
        tab.Text:SetText(tabDef.title)
        tab:SetWidth(tab.Text:GetStringWidth() + 40)
        tab:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", x, 0)
        tab:SetScript("OnClick", function(self)
            SelectTab(self:GetID())
            Options:RefreshVisuals()
        end)
        x = x + tab:GetWidth() + 4
        tabs[i] = tab

        local panel = CreateFrame("Frame", nil, contentBox)
        panel:SetPoint("TOPLEFT", contentBox, "TOPLEFT", 14, -14)
        panel:SetPoint("TOPRIGHT", contentBox, "TOPRIGHT", -14, -14)
        panel:SetPoint("BOTTOMRIGHT", contentBox, "BOTTOMRIGHT", -14, 14)
        BuildLineRows(panel, sectionBind, tabDef.order, -4)
        panels[i] = panel
        panel:Hide()
    end

    SelectTab(1)
end

local function BuildAboutFrame(parent)
    local version = ""
    if GetAddOnMetadata then
        version = GetAddOnMetadata(addonName, "Version") or ""
    end
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetText(L.ADDON_NAME .. (version ~= "" and (" " .. version) or ""))
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)
    title:SetTextColor(1, 0.82, 0)

    local sub = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sub:SetText(L.NOTE_SLASH)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    sub:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    sub:SetJustifyH("LEFT")
    sub:SetTextColor(0.8, 0.8, 0.8)
end

local function BuildGlobalSection(parent, y)
    local header = CreateHeader(parent, L.SECTION_GLOBAL, y)
    y = y - 28

    local langOptions = {
        { text = L.LANGUAGE_AUTO, key = "auto" },
        { text = L.LANGUAGE_ZHCN, key = "zhCN" },
        { text = L.LANGUAGE_ZHTW, key = "zhTW" },
        { text = L.LANGUAGE_ENUS, key = "enUS" },
    }
    row = CreateRow(parent, L.LANGUAGE, y)
    local langBind = {
        get = function() return addon.GetLanguage and addon.GetLanguage() or "auto" end,
        set = function(v)
            addon.SetLanguage(v)
            if C_UI and C_UI.Reload then
                C_UI.Reload()
            else
                ReloadUI()
            end
        end,
    }
    CreateDropdown(row, langBind, function() return langOptions end, 150)
    y = y - 30

    local row = CreateRow(parent, L.ENABLED, y)
    CreateCheckbox(row, BindGlobal("enabled"), L.ENABLED_TOOLTIP)
    y = y - 30

    row = CreateRow(parent, L.RESPECT_CVAR, y)
    CreateCheckbox(row, BindGlobal("respectCvar"), L.RESPECT_CVAR_TOOLTIP)
    y = y - 30

    row = CreateRow(parent, L.ALPHA, y)
    CreateSlider(row, BindGlobal("alpha"), 0, 1, 0.01, function(v) return string.format("%.2f", v) end)
    y = y - 30

    local anchorOptions = {}
    for _, anchor in ipairs(Media.anchors) do
        anchorOptions[#anchorOptions + 1] = { text = L["ANCHOR_" .. anchor], key = anchor }
    end
    row = CreateRow(parent, L.ANCHOR, y)
    local anchorBind = {
        get = BindGlobal("anchor").get,
        set = function(v)
            local g = ActiveTheme().global
            g.anchor = v
            g.x = 0
            g.y = 0
            AfterChange()
        end,
    }
    CreateDropdown(row, anchorBind, function() return anchorOptions end, 140)
    y = y - 30

    row = CreateRow(parent, L.OFFSET_X, y)
    CreateSlider(row, BindGlobal("x"), -600, 600, 1, function(v) return string.format("%d", v) end)
    y = y - 30

    row = CreateRow(parent, L.OFFSET_Y, y)
    CreateSlider(row, BindGlobal("y"), -400, 800, 1, function(v) return string.format("%d", v) end)
    y = y - 30

    row = CreateRow(parent, L.MAX_WIDTH, y)
    CreateSlider(row, BindGlobal("maxWidth"), 200, 1400, 10, function(v) return string.format("%d", v) end)
    y = y - 30

    row = CreateRow(parent, L.GAP, y)
    CreateSlider(row, BindGlobal("gap"), 0, 60, 1, function(v) return string.format("%d", v) end)
    y = y - 30

    return y
end

local function BuildThemeSection(parent)
    local y = -2

    local header = CreateHeader(parent, L.SECTION_THEME, y)
    y = y - 30

    local row = CreateRow(parent, L.THEME_SELECT, y)
    local themeBind = {
        get = function() return Themes.GetActiveName() end,
        set = function(name)
            Themes.Apply(name)
            Options:RefreshVisuals()
        end,
    }
    CreateDropdown(row, themeBind, function()
        local options = {}
        for _, name in ipairs(Themes.List()) do
            options[#options + 1] = { text = name, key = name }
        end
        return options
    end, 170)
    y = y - 30

    row = CreateRow(parent, L.THEME_NEW_NAME, y)
    local nameBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    nameBox:SetSize(170, 20)
    nameBox:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(40)
    y = y - 30

    local function MakeButton(text, width)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(width, 24)
        btn:SetText(text)
        return btn
    end

    local saveBtn = MakeButton(L.THEME_SAVE, 130)
    saveBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
    saveBtn:SetScript("OnClick", function()
        local name = strtrim(nameBox:GetText())
        if name == "" then
            print(L.NAME_EMPTY)
            return
        end
        local theme = Themes.Save(name, ActiveTheme())
        Core:ApplyTheme(theme)
        nameBox:SetText("")
        print(string.format(L.THEME_SAVED, name))
        Options:RefreshVisuals()
    end)

    local deleteBtn = MakeButton(L.THEME_DELETE, 100)
    deleteBtn:SetPoint("RIGHT", saveBtn, "LEFT", -6, 0)
    deleteBtn:SetScript("OnClick", function()
        local name = Themes.GetActiveName()
        if name == L.DEFAULT_THEME or not Themes.Delete(name) then
            print(L.CANNOT_DELETE_DEFAULT)
            return
        end
        print(string.format(L.THEME_DELETED, name))
        Options:RefreshVisuals()
    end)
    y = y - 30

    local exportBtn = MakeButton(L.THEME_EXPORT, 110)
    exportBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
    exportBtn:SetScript("OnClick", function()
        local str = Serializer.Serialize(ActiveTheme(), Themes.GetDefaults())
        if Options.importBox then
            Options.importBox:SetText(str)
            Options.importBox:HighlightText()
        end
        print(L.EXPORTED)
    end)

    local importBtn = MakeButton(L.THEME_IMPORT, 110)
    importBtn:SetPoint("RIGHT", exportBtn, "LEFT", -6, 0)
    importBtn:SetScript("OnClick", function()
        if not Options.importBox then return end
        local theme, err = Serializer.Parse(Options.importBox:GetText(), Themes.GetDefaults())
        if not theme then
            local msg = err == "empty" and L.IMPORT_ERROR_EMPTY or (err == "version" and L.IMPORT_ERROR_VERSION or L.IMPORT_ERROR_FORMAT)
            print(string.format(L.IMPORT_FAILED, msg))
            return
        end
        local name = theme.name
        if name == "" then name = "Imported" end
        Themes.Save(name, theme)
        Core:ApplyTheme(Themes.GetActive())
        print(string.format(L.IMPORTED, name))
        Options:RefreshVisuals()
    end)

    local resetBtn = MakeButton(L.RESET, 110)
    resetBtn:SetPoint("RIGHT", importBtn, "LEFT", -6, 0)
    resetBtn:SetScript("OnClick", function()
        Themes.ResetActive()
        Options:RefreshVisuals()
    end)
    y = y - 26

    local previewBtn = MakeButton(L.PREVIEW_TOGGLE, 110)
    previewBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
    previewBtn:SetScript("OnClick", function(self)
        local ok, shown = pcall(Core.Preview, Core)
        if not ok then
            print("CGUI: " .. tostring(shown))
        end
    end)
    RegisterControl({
        refresh = function()
            local shown = addon.Core and addon.Core.previewShown or false
        end,
    })
    y = y - 30

    row = CreateRow(parent, L.IMPORT_EXPORT_LABEL, y)
    y = y - 34

    local importBoxBg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    importBoxBg:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)
    importBoxBg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, y)
    importBoxBg:SetHeight(180)
    importBoxBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    importBoxBg:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    importBoxBg:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)

    -- Scrollable multiline box so long exported themes can be read without
    -- overflowing (a visible scrollbar is provided by the scroll frame).
    local importScroll = CreateFrame("ScrollFrame", nil, importBoxBg, "UIPanelScrollFrameTemplate")
    importScroll:SetPoint("TOPLEFT", importBoxBg, "TOPLEFT", 6, -6)
    importScroll:SetPoint("BOTTOMRIGHT", importBoxBg, "BOTTOMRIGHT", -6, 6)

    local importBox = CreateFrame("EditBox", nil, importScroll)
    importBox:SetMultiLine(true)
    importBox:EnableMouse(true)
    importBox:SetAutoFocus(false)
    importBox:SetMaxLetters(0)
    importBox:SetFontObject(GameFontHighlightSmall)
    importBox:SetTextInsets(2, 2, 2, 2)
    importBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    importScroll:SetScrollChild(importBox)

    local function UpdateImportScroll()
        local width = importScroll:GetWidth()
        if width and width > 0 then
            importBox:SetWidth(width - 24)
        end
        local lines = importBox:GetNumLines() or 1
        if lines < 1 then lines = 1 end
        importBox:SetHeight(lines * 16 + 8)
        if importScroll.UpdateScrollChildRect then
            importScroll:UpdateScrollChildRect()
        end
    end
    importBox:SetScript("OnTextChanged", UpdateImportScroll)
    importScroll:SetScript("OnSizeChanged", UpdateImportScroll)
    Options.importBox = importBox
    y = y - 186

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetText(L.IMPORT_HINT)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(0.7, 0.7, 0.7)
    hint:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)

    return y - 20
end

local function RegisterCategoryFrame(frame)
    frame:Hide()
    frame.OnRefresh = function()
        CloseDropdown()
        Options:RefreshVisuals()
    end
end

-- Stop the settings preview subtitle and hide the subtitle container.
local function StopPreviewAndHide()
    if addon.Core and addon.Core.StopPreview then
        addon.Core:StopPreview()
    end
    if addon.Core and addon.Core.HideSubtitles then
        addon.Core:HideSubtitles()
    end
end

function Options:Build()
    if self.built then return end
    self.built = true

    if not Settings or not Settings.CreateCategory then
        print("CGUI: 无法注册设置面板")
        return
    end

    local aboutFrame = CreateFrame("Frame", nil, UIParent)
    RegisterCategoryFrame(aboutFrame)
    BuildAboutFrame(aboutFrame)
    local root = Settings.RegisterCanvasLayoutCategory(aboutFrame, L.ADDON_NAME)
    Settings.RegisterAddOnCategory(root)
    self.root = root

    -- Closing the settings panel should clear and hide the settings preview.
    if SettingsPanel and SettingsPanel.HookScript and not self._panelHiddenHooked then
        self._panelHiddenHooked = true
        SettingsPanel:HookScript("OnHide", function()
            StopPreviewAndHide()
        end)
    end

    local generalFrame = CreateFrame("Frame", nil, UIParent)
    RegisterCategoryFrame(generalFrame)
    BuildGlobalSection(generalFrame, -2)
    self.generalCategory = Settings.RegisterCanvasLayoutSubcategory(root, generalFrame, L.SECTION_GLOBAL)

    local themeFrame = CreateFrame("Frame", nil, UIParent)
    RegisterCategoryFrame(themeFrame)
    BuildThemeSection(themeFrame)
    self.themeCategory = Settings.RegisterCanvasLayoutSubcategory(root, themeFrame, L.SECTION_THEME)

    local speakerFrame = CreateFrame("Frame", nil, UIParent)
    RegisterCategoryFrame(speakerFrame)
    BuildTabbedFrame(speakerFrame, L.SECTION_SPEAKER, "speaker")
    self.speakerCategory = Settings.RegisterCanvasLayoutSubcategory(root, speakerFrame, L.SECTION_SPEAKER)

    local contentFrame = CreateFrame("Frame", nil, UIParent)
    RegisterCategoryFrame(contentFrame)
    BuildTabbedFrame(contentFrame, L.SECTION_CONTENT, "content")
    self.contentCategory = Settings.RegisterCanvasLayoutSubcategory(root, contentFrame, L.SECTION_CONTENT)

    self:RefreshVisuals()
end

Options:Build()

local function OpenSettings()
    if Options.generalCategory then
        Settings.OpenToCategory(Options.generalCategory:GetID())
    end
end

local function PrintHelp()
    for line in string.gmatch(L.NOTE_SLASH, "[^\n]+") do
        print(line)
    end
end

SLASH_CGSUB1 = "/cgsub"
SLASH_CGSUB2 = "/cgs"
SlashCmdList["CGSUB"] = function(msg)
    msg = strtrim(msg)
    if msg == "" then
        OpenSettings()
        return
    end
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and strlower(cmd) or ""
    arg = strtrim(arg or "")

    if cmd == "help" or cmd == "?" then
        PrintHelp()
    elseif cmd == "preview" then
        local ok, shown = pcall(Core.Preview, Core)
        if ok then
            print(shown and L.SLASH_PREVIEW_ON or L.SLASH_PREVIEW_OFF)
        else
            print("CGUI: " .. tostring(shown))
        end
    elseif cmd == "reset" then
        Themes.ResetActive()
        Options:RefreshVisuals()
        print(string.format(L.THEME_APPLIED, Themes.GetActiveName()))
    elseif cmd == "on" or cmd == "enable" then
        ActiveTheme().global.enabled = true
        Core:ApplyTheme(Themes.GetActive())
        Options:RefreshVisuals()
        print(L.SLASH_ENABLED)
    elseif cmd == "off" or cmd == "disable" then
        ActiveTheme().global.enabled = false
        Core:ApplyTheme(Themes.GetActive())
        Options:RefreshVisuals()
        print(L.SLASH_DISABLED)
    elseif cmd == "theme" then
        if arg == "" then
            PrintHelp()
            return
        end
        if Themes.Get(arg) then
            Themes.Apply(arg)
            Options:RefreshVisuals()
            print(string.format(L.THEME_APPLIED, arg))
        else
            print(string.format(L.SLASH_THEME_NOT_FOUND, arg))
        end
    elseif cmd == "themes" or cmd == "list" then
        print(string.format(L.SLASH_THEME_LIST, table.concat(Themes.List(), ", ")))
    elseif cmd == "save" then
        if arg == "" then
            print(L.NAME_EMPTY)
            return
        end
        local theme = Themes.Save(arg, ActiveTheme())
        Core:ApplyTheme(theme)
        Options:RefreshVisuals()
        print(string.format(L.THEME_SAVED, arg))
    elseif cmd == "delete" then
        if arg == "" then
            PrintHelp()
            return
        end
        if not Themes.Get(arg) then
            print(string.format(L.SLASH_THEME_NOT_FOUND, arg))
            return
        end
        if not Themes.Delete(arg) then
            print(L.CANNOT_DELETE_DEFAULT)
            return
        end
        Options:RefreshVisuals()
        print(string.format(L.THEME_DELETED, arg))
    elseif cmd == "export" then
        print(L.EXPORTED)
        print(Serializer.Serialize(ActiveTheme(), Themes.GetDefaults()))
    elseif cmd == "import" then
        if arg == "" then
            print(L.IMPORT_ERROR_EMPTY)
            return
        end
        local theme, err = Serializer.Parse(arg, Themes.GetDefaults())
        if not theme then
            local m = err == "empty" and L.IMPORT_ERROR_EMPTY or (err == "version" and L.IMPORT_ERROR_VERSION or L.IMPORT_ERROR_FORMAT)
            print(string.format(L.IMPORT_FAILED, m))
            return
        end
        local name = theme.name
        if name == "" then name = "Imported" end
        Themes.Save(name, theme)
        Core:ApplyTheme(Themes.GetActive())
        Options:RefreshVisuals()
        print(string.format(L.IMPORTED, name))
    elseif cmd == "language" or cmd == "lang" then
        local langMap = {
            auto = "auto",
            zhcn = "zhCN",
            zhtw = "zhTW",
            enus = "enUS",
        }
        local pref = langMap[strlower(arg)]
        if not pref then
            print(L.SLASH_LANGUAGE_INVALID)
            return
        end
        addon.SetLanguage(pref)
        print(string.format(L.SLASH_LANGUAGE_SET, L["LANGUAGE_" .. pref:upper()] or pref))
        if C_UI and C_UI.Reload then
            C_UI.Reload()
        else
            ReloadUI()
        end
    else
        print(string.format(L.SLASH_UNKNOWN, cmd))
    end
end
