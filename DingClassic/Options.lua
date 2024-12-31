local addonName, DingClassic = ...

local function RefreshOptionsPanel()
    if not DingClassic.optionsPanel then
        DingClassic:Debug("RefreshOptionsPanel: optionsPanel is nil.")
        return
    end

    local controls = DingClassic.optionsPanel.controls
    if not controls then
        DingClassic:Debug("RefreshOptionsPanel: controls are nil.")
        return
    end

    -- Update UI text with localized strings
    if controls.enableCheckbox then
        controls.enableCheckbox.Text:SetText(DingClassic:Localize("ENABLE"))
    end
    if controls.sayCheckbox then
        controls.sayCheckbox.Text:SetText(DingClassic:Localize("SAY"))
    end
    if controls.guildCheckbox then
        controls.guildCheckbox.Text:SetText(DingClassic:Localize("GUILD"))
    end
    if controls.debugCheckbox then
        controls.debugCheckbox.Text:SetText(DingClassic:Localize("DEBUG"))
    end
    if controls.poolDropdown then
        UIDropDownMenu_SetText(controls.poolDropdown, DingClassic:Localize("POOL"))
    end
    if controls.testButton then
        controls.testButton:SetText(DingClassic:Localize("TEST"))
    end

    -- Update the note text under "Send to Say"
    if controls.sayDisabledNote then
        controls.sayDisabledNote:SetText("|cff00ff00Note:|r " .. DingClassic:Localize("SAY_DISABLED_NOTE"))
    end

    -- Refresh checkboxes
    if controls.enableCheckbox then
        controls.enableCheckbox:SetChecked(DingClassic.settings.showDingMessages)
    end
    if controls.sayCheckbox then
        controls.sayCheckbox:SetChecked(DingClassic.settings.sendToSay)
        controls.sayCheckbox:SetEnabled(false) -- Keep disabled since it's broken
    end
    if controls.guildCheckbox then
        controls.guildCheckbox:SetChecked(DingClassic.settings.sendToGuild)
    end
    if controls.debugCheckbox then
        controls.debugCheckbox:SetChecked(DingClassic.settings.debugMode)
    end

    -- Refresh dropdowns
    if controls.localeDropdown then
        UIDropDownMenu_SetText(controls.localeDropdown, DingClassic.settings.selectedLocale or "enUS")
    end
    if controls.poolDropdown then
        UIDropDownMenu_SetText(controls.poolDropdown, DingClassic.settings.selectedMessagePool or "Default")
    end

    DingClassic:Debug("Options panel refreshed with current settings and localization.")
end

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "DingClassicOptionsPanel", UIParent)
    panel.name = DingClassic:Localize("TITLE") or "Ding Classic Options"
    panel.controls = {} -- Container for all controls

    -- TOC Flavor Label
    local tocFlavorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tocFlavorLabel:SetPoint("TOPRIGHT", -16, -16)
    tocFlavorLabel:SetText("|cff00ff00TOC Flavor:|r " .. DingClassic:GetTOCFlavor())
    DingClassic:Debug("TOC Flavor added to options: " .. DingClassic:GetTOCFlavor())

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(DingClassic:Localize("TITLE") or "Ding Classic Options")
    panel.controls.title = title
    DingClassic:Debug("Created title.")

    -- Enable Checkbox
    local enableCheckbox = CreateFrame("CheckButton", "DingClassicEnableCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    enableCheckbox.Text:SetText(DingClassic:Localize("ENABLE") or "Enable Ding Messages")
    enableCheckbox:SetScript("OnClick", function(self)
        DingClassic.settings.showDingMessages = self:GetChecked()
        DingClassic:SaveSettings()
    end)
    panel.controls.enableCheckbox = enableCheckbox
    DingClassic:Debug("Created enableCheckbox.")

    -- Send to Say Checkbox
    local sayCheckbox = CreateFrame("CheckButton", "DingClassicSayCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    sayCheckbox:SetPoint("TOPLEFT", enableCheckbox, "BOTTOMLEFT", 0, -10)
    sayCheckbox.Text:SetText(DingClassic:Localize("SAY") or "Send to Say")
    sayCheckbox:SetEnabled(false) -- Disable the checkbox
    sayCheckbox:SetChecked(false) -- Ensure it remains unchecked
    panel.controls.sayCheckbox = sayCheckbox
    DingClassic:Debug("Created sayCheckbox.")

    -- Note under Send to Say
    local sayDisabledNote = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    sayDisabledNote:SetPoint("TOPLEFT", sayCheckbox, "BOTTOMLEFT", 0, -5)
    sayDisabledNote:SetText("|cff00ff00Note:|r " .. DingClassic:Localize("SAY_DISABLED_NOTE"))
    panel.controls.sayDisabledNote = sayDisabledNote
    DingClassic:Debug("Added note for Send to Say being disabled.")

    -- Send to Guild Checkbox
    local guildCheckbox = CreateFrame("CheckButton", "DingClassicGuildCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    guildCheckbox:SetPoint("TOPLEFT", sayDisabledNote, "BOTTOMLEFT", 0, -10)
    guildCheckbox.Text:SetText(DingClassic:Localize("GUILD") or "Send to Guild")
    guildCheckbox:SetScript("OnClick", function(self)
        DingClassic.settings.sendToGuild = self:GetChecked()
        DingClassic:SaveSettings()
    end)
    panel.controls.guildCheckbox = guildCheckbox
    DingClassic:Debug("Created guildCheckbox.")

    -- Debug Mode Checkbox
    local debugCheckbox = CreateFrame("CheckButton", "DingClassicDebugCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", guildCheckbox, "BOTTOMLEFT", 0, -10)
    debugCheckbox.Text:SetText(DingClassic:Localize("DEBUG") or "Enable Debug Mode")
    debugCheckbox:SetScript("OnClick", function(self)
        DingClassic.settings.debugMode = self:GetChecked()
        DingClassic:SaveSettings()
        DingClassic:Debug("Debug mode toggled to: " .. tostring(self:GetChecked()))
    end)
    panel.controls.debugCheckbox = debugCheckbox
    DingClassic:Debug("Created debugCheckbox.")

    -- Locale Dropdown Label
    local localeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    localeLabel:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 16, -10)
    localeLabel:SetText(DingClassic:Localize("LOCALE_LABEL") or "Select Locale:")

    -- Locale Dropdown
    local localeDropdown = CreateFrame("Frame", "DingClassicLocaleDropdown", panel, "UIDropDownMenuTemplate")
    localeDropdown:SetPoint("TOPLEFT", localeLabel, "BOTTOMLEFT", -16, -10)
    UIDropDownMenu_SetWidth(localeDropdown, 160)
    UIDropDownMenu_Initialize(localeDropdown, function(self, level)
        for locale, _ in pairs(DingClassic.Locales) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = locale
            info.checked = DingClassic.settings.selectedLocale == locale
            info.func = function()
                DingClassic.settings.selectedLocale = locale
                DingClassic:LoadLocale(locale)
                DingClassic:SaveSettings()
                UIDropDownMenu_SetText(localeDropdown, locale)
                RefreshOptionsPanel() -- Refresh the options panel to update controls
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    panel.controls.localeDropdown = localeDropdown
    DingClassic:Debug("Created localeDropdown.")

    -- Locale Note
    local localeNote = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    localeNote:SetPoint("TOPLEFT", localeDropdown, "BOTTOMLEFT", 16, -10) -- Adjust spacing and alignment
    localeNote:SetWidth(300) -- Limit the width of the note for wrapping
    localeNote:SetJustifyH("LEFT") -- Align text to the left
    localeNote:SetText("|cff00ff00Note:|r " .. DingClassic:Localize("LOCALE_NOTE"))
    panel.controls.localeNote = localeNote
    DingClassic:Debug("Added locale reload note.")

    -- Message Pool Dropdown Label
    local poolDropdownLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    poolDropdownLabel:SetPoint("TOPLEFT", localeNote, "BOTTOMLEFT", 0, -20) -- Properly space below locale note
    poolDropdownLabel:SetText(DingClassic:Localize("POOL_LABEL") or "Select Message Pool:")
    panel.controls.poolDropdownLabel = poolDropdownLabel

    -- Message Pool Dropdown
    local poolDropdown = CreateFrame("Frame", "DingClassicMessagePoolDropdown", panel, "UIDropDownMenuTemplate")
    poolDropdown:SetPoint("TOPLEFT", poolDropdownLabel, "BOTTOMLEFT", -16, -10) -- Adjust positioning for alignment
    UIDropDownMenu_SetWidth(poolDropdown, 160)
    UIDropDownMenu_Initialize(poolDropdown, function(self, level)
        for poolName, description in pairs(DingClassic.messagePoolDescriptions or {}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = poolName
            info.checked = DingClassic.settings.selectedMessagePool == poolName
            info.tooltipTitle = poolName -- Tooltip title
            info.tooltipText = description -- Tooltip description
            info.tooltipOnButton = true -- Enable tooltips
            info.func = function()
                DingClassic.settings.selectedMessagePool = poolName
                DingClassic:SaveSettings()
                UIDropDownMenu_SetText(poolDropdown, poolName)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    panel.controls.poolDropdown = poolDropdown
    DingClassic:Debug("Created poolDropdown.")

    -- Test Button
    local testButton = CreateFrame("Button", "DingClassicTestButton", panel, "UIPanelButtonTemplate")
    testButton:SetText(DingClassic:Localize("TEST") or "Test Ding Message")
    testButton:SetSize(160, 25)
    testButton:SetPoint("TOPLEFT", poolDropdown, "BOTTOMLEFT", 0, -20) -- Adjusted spacing for alignment
    testButton:SetScript("OnClick", function()
        if DingClassic.settings.selectedMessagePool then
            local pool = DingClassic.messagePools and DingClassic.settings.selectedMessagePool
            if pool and #pool > 0 then
                local message = string.format(pool[math.random(#pool)], UnitLevel("player"))

                -- Respect settings for "Send to Say"
                if DingClassic.settings.sendToSay then
                    if UnitIsDeadOrGhost("player") then
                        DingClassic:Debug("Player is dead or a ghost. Suppressing /say message.")
                    else
                        DingClassic:Debug("Test: Sending message to say: " .. message)
                        SendChatMessage(message, "SAY")
                    end
                else
                    DingClassic:Debug("Test: 'Send to Say' is disabled. Skipping.")
                end

                -- Respect settings for "Send to Guild"
                if DingClassic.settings.sendToGuild and IsInGuild() then
                    DingClassic:Debug("Test: Sending message to guild: " .. message)
                    SendChatMessage(message, "GUILD")
                else
                    DingClassic:Debug("Test: 'Send to Guild' is disabled or player is not in a guild. Skipping.")
                end
            else
                print(DingClassic:Localize("NO_MESSAGES") or "No messages found in this pool.")
            end
        else
            print(DingClassic:Localize("NO_POOL_SELECTED") or "No message pool selected.")
        end
    end)
    panel.controls.testButton = testButton
    DingClassic:Debug("Created testButton.")

    -- Finalize
    panel.RefreshOptionsPanel = RefreshOptionsPanel -- Attach RefreshOptionsPanel
    DingClassic:Debug("Attached RefreshOptionsPanel to the options panel.")

    -- Add the panel to the Blizzard UI
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, addonName)
        Settings.RegisterAddOnCategory(category)
        DingClassic:Debug("Options panel added using Retail API.")
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        DingClassic:Debug("Options panel added using Classic API.")
    else
        DingClassic:Debug("Failed to add options panel. API unavailable.")
    end

    return panel
end


DingClassic.CreateOptionsPanel = CreateOptionsPanel
