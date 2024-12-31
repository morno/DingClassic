--- DingClassic.lua - Core Addon Logic
local addonName, DingClassic = ...

DingClassic = DingClassic or {} -- Global reference for the addon
_G.DingClassic = DingClassic

DingClassic.settings = DingClassic.settings or {}
DingClassic.Locales = DingClassic.Locales or {} -- Ensure Locales table exists
DingClassic.translations = DingClassic.translations or {} -- Active translations

-- Debug utility function
function DingClassic:Debug(msg)
    if self.settings.debugMode then
        print("[Ding Classic Debug]: " .. tostring(msg))
    end
end

-- Cache the TOC flavor immediately upon loading
DingClassic.tocFlavor = GetAddOnMetadata("DingClassic", "X-Flavor") or "Unknown Flavor"

function DingClassic:GetTOCFlavor()
    return self.tocFlavor
end

-- Locale loading function
function DingClassic:LoadLocale(locale)
    locale = locale or GetLocale() -- Use the provided locale or default to the client's locale
    local localeTable = self.Locales[locale]

    if localeTable then
        self.translations = localeTable
        self.messagePools = localeTable.messagePools or {}
        self.messagePoolDescriptions = localeTable.messagePoolDescriptions or {}
        print("|cff00ff00[Ding Classic]:|r Locale loaded: " .. locale)
    else
        print("|cff00ff00[Ding Classic]:|r Locale not found: " .. locale .. ". Falling back to enUS.")
        self.translations = self.Locales["enUS"] or {}
        self.messagePools = self.translations.messagePools or {}
        self.messagePoolDescriptions = self.translations.messagePoolDescriptions or {}
    end

    -- Refresh options panel UI with the new locale
    if DingClassic.optionsPanel and DingClassic.optionsPanel.RefreshOptionsPanel then
        DingClassic.optionsPanel.RefreshOptionsPanel()
    end
end

function DingClassic:Localize(key)
    if self.translations and self.translations[key] then
        return self.translations[key]
    else
        if self.settings.debugMode then
            print("[Ding Classic Debug] Missing localization for key: " .. tostring(key))
        end
        return key
    end
end

function DingClassic:SaveSettings()
    if not DingClassicSavedSettings then
        DingClassicSavedSettings = {} -- Ensure the table exists
        DingClassic:Debug("Created new saved settings table.")
    end

    -- Copy current settings into the saved variables table
    for k, v in pairs(self.settings) do
        DingClassicSavedSettings[k] = v
    end
    self:Debug("Settings saved successfully.")
end

-- Function to securely send chat messages
local function SendSecureChatMessage(msg, channel)
    local success, errorMessage = pcall(function()
        SendChatMessage(tostring(msg), channel)
    end)
    if not success then
        DingClassic:Debug("Failed to send message to " .. channel .. ": " .. tostring(errorMessage))
        -- Retry sending the message after a short delay
        C_Timer.After(1, function() SendSecureChatMessage(msg, channel) end)
    else
        DingClassic:Debug("Successfully sent message to " .. channel .. ": " .. msg)
    end
end

-- Updated SendDingMessage function to use SendSecureChatMessage
local function SendDingMessage()
    if not DingClassic.settings.showDingMessages then
        DingClassic:Debug("Ding messages are disabled.")
        return
    end

    -- Check if the player is in combat
    if InCombatLockdown() then
        DingClassic:Debug("Player is in combat lockdown. Delaying ding message.")
        local function RescheduleMessage()
            if not InCombatLockdown() then
                DingClassic:Debug("Combat ended. Scheduling ding message after a short delay.")
                C_Timer.After(0.5, SendDingMessage) -- Delay slightly after combat ends
            else
                DingClassic:Debug("Still in combat. Rescheduling message.")
                C_Timer.After(1, RescheduleMessage) -- Retry in 1 second
            end
        end
        RescheduleMessage()
        return
    end

    local message
    if DingClassic.settings.selectedMessagePool then
        local pool = DingClassic.messagePools and DingClassic.messagePools[DingClassic.settings.selectedMessagePool]
        if pool and #pool > 0 then
            message = string.format(pool[math.random(#pool)], UnitLevel("player"))
            DingClassic:Debug("Selected message: " .. message)
        else
            DingClassic:Debug("No messages found in the selected pool.")
            print(DingClassic:Localize("NO_MESSAGES") or "No messages found in this pool.")
            return
        end
    else
        DingClassic:Debug("No message pool selected.")
        print(DingClassic:Localize("NO_POOL_SELECTED") or "No message pool selected.")
        return
    end

    -- Send to Guild
    if DingClassic.settings.sendToGuild then
        if IsInGuild() then
            DingClassic:Debug("Attempting to send message to guild: " .. message)
            SendSecureChatMessage(message, "GUILD")
        else
            DingClassic:Debug("Cannot send to guild: Not in a guild.")
        end
    else
        DingClassic:Debug("Guild message sending is disabled.")
    end

    -- Send to Say
    if DingClassic.settings.sendToSay then
        if UnitIsDeadOrGhost("player") then
            DingClassic:Debug("Player is dead or a ghost. Suppressing /say message.")
        else
            DingClassic:Debug("Attempting to send message to say: " .. message)
            SendSecureChatMessage(message, "SAY")
        end
    else
        DingClassic:Debug("Say message sending is disabled.")
    end
end

local function CheckForLevelUp(newLevel)
    DingClassic:Debug("Level-up detected! New level: " .. tostring(newLevel))
    DingClassic.settings.lastLevel = newLevel
    DingClassic:SaveSettings()

    -- Retry logic for sending the ding message
    local retries = 0
    local maxRetries = 5
    local retryInterval = 1.0 -- seconds

    local function TrySendDingMessage()
        if QuestFrame:IsShown() or GossipFrame:IsShown() or MerchantFrame:IsShown() then
            DingClassic:Debug("Blocking frame is still open. Retry " .. retries .. "/" .. maxRetries)
            retries = retries + 1
            if retries <= maxRetries then
                C_Timer.After(retryInterval, TrySendDingMessage)
            else
                DingClassic:Debug("Max retries reached. Sending ding message anyway.")
                SendDingMessage(newLevel) -- Pass simulated level
            end
        else
            DingClassic:Debug("Blocking frames closed or not blocking. Sending ding message.")
            SendDingMessage(newLevel) -- Pass simulated level
        end
    end

    -- Start the retry mechanism
    TrySendDingMessage()
end

local function FakeLevelUp(level)
    DingClassic:Debug("Simulating level-up to level " .. tostring(level))
    CheckForLevelUp(level)
end


local function InitializeSettings()
    -- Default settings initialization
    local defaultSettings = {
        showDingMessages = true,
        sendToSay = false,
        sendToGuild = true,
        debugMode = false,
        selectedMessagePool = "Default",
        selectedLocale = "enUS",
    }

    -- Ensure saved settings table exists
    if not DingClassicSavedSettings then
        DingClassicSavedSettings = {}
        DingClassic:Debug("No saved settings found. Initializing new settings.")
    else
        DingClassic:Debug("Saved settings loaded successfully.")
    end

    -- Apply default settings if missing
    for key, defaultValue in pairs(defaultSettings) do
        if DingClassicSavedSettings[key] == nil then
            DingClassicSavedSettings[key] = defaultValue
            DingClassic:Debug("Missing setting '" .. key .. "' initialized to default value: " .. tostring(defaultValue))
        end
    end

    -- Assign the settings table to the addon
    DingClassic.settings = DingClassicSavedSettings

    -- Ensure `sendToSay` is false and refresh the options
    DingClassic.settings.sendToSay = false
    DingClassic:Debug("Forced 'sendToSay' to false for consistency.")

    -- Load locale
    DingClassic:LoadLocale(DingClassic.settings.selectedLocale)

    -- Log TOC flavor once during initialization
    DingClassic:Debug("TOC Flavor resolved during initialization: " .. DingClassic.tocFlavor)

    -- Create or refresh the options panel
    if not DingClassic.optionsPanel and DingClassic.CreateOptionsPanel then
        DingClassic.optionsPanel = DingClassic.CreateOptionsPanel()
        DingClassic:Debug("Options panel created successfully.")
    end

    -- Debug logging for panel registration
    DingClassic:Debug("Options panel registration status:")
    DingClassic:Debug("  DingClassic.optionsPanel: " .. tostring(DingClassic.optionsPanel))
    if DingClassic.optionsPanel and DingClassic.optionsPanel.name then
        DingClassic:Debug("  Panel name: " .. DingClassic.optionsPanel.name)
    end

    -- Ensure RefreshOptionsPanel is called after settings are loaded
    if DingClassic.optionsPanel and DingClassic.optionsPanel.RefreshOptionsPanel then
        C_Timer.After(0.1, function()
            DingClassic:Debug("Calling RefreshOptionsPanel to update controls with saved settings.")
            DingClassic.optionsPanel.RefreshOptionsPanel()
        end)
    else
        DingClassic:Debug("Options panel or RefreshOptionsPanel is not available.")
    end
end

local function OpenOptionsPanel()
    if not DingClassic.optionsPanel then
        print("[Ding Classic] Options panel is not available. Ensure the addon is loaded correctly.")
        DingClassic:Debug("Options panel is nil.")
        return
    end

    if Settings and Settings.OpenToCategory then
        -- Retail WoW Settings API
        Settings.OpenToCategory(DingClassic.optionsPanel)
        DingClassic:Debug("Options panel opened using Retail API.")
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- Classic WoW Interface Options API
        InterfaceOptionsFrame_OpenToCategory(DingClassic.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(DingClassic.optionsPanel) -- Call twice due to Blizzard quirks
        DingClassic:Debug("Options panel opened using Classic API.")
    else
        print("[Ding Classic] Options panel cannot be opened. Ensure the addon is loaded correctly.")
        DingClassic:Debug("No available API to open options panel.")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == addonName then
            InitializeSettings()

            -- Initialize options panel
            if not DingClassic.optionsPanel and DingClassic.CreateOptionsPanel then
                DingClassic.optionsPanel = DingClassic.CreateOptionsPanel()
                DingClassic:Debug("Options panel created successfully.")
            else
                DingClassic:Debug("DingClassic.CreateOptionsPanel is not available during ADDON_LOADED.")
            end

            -- Print the custom loading message
            local version = GetAddOnMetadata(addonName, "Version") or "unknown"
            print("|cff00ff00[Ding Classic]|r " .. version .. " loaded. Available commands:")
            print("|cffffff00/dc test|r - Simulate a level-up at your current level.")
            print("|cffffff00/dc test <level>|r - Simulate a level-up at the specified level.")
            print("|cffffff00/dc o|r - Open the options menu.")

            DingClassic:Debug("Addon loaded and settings initialized.")
        end
    elseif event == "PLAYER_LEVEL_UP" then
        local newLevel = select(1, ...)
        CheckForLevelUp(newLevel)
    end
end)

-- Register slash commands
SLASH_DINGCLASSIC1 = "/dingclassic"
SLASH_DINGCLASSIC2 = "/dc"
SLASH_DINGCLASSIC3 = "/ding"
SlashCmdList["DINGCLASSIC"] = function(input)
    input = input:lower()
    if input == "test" then
        -- Use the player's current level for testing
        local currentLevel = UnitLevel("player")
        DingClassic:Debug("Simulating level-up to level " .. currentLevel)
        CheckForLevelUp(currentLevel)
        print("|cff00ff00[Ding Classic]|r Test level-up simulated for level " .. currentLevel .. ". Check messages!")
    elseif input:match("^test (%d+)$") then
        -- Simulate a specific level
        local level = tonumber(input:match("^test (%d+)$"))
        DingClassic:Debug("Simulating level-up to level " .. level)
        CheckForLevelUp(level)
        print("|cff00ff00[Ding Classic]|r Test level-up simulated for level " .. level .. ". Check messages!")
    elseif input == "o" then
        OpenOptionsPanel()
        print("|cff00ff00[Ding Classic]|r Options panel opened.")
    elseif input == "settings" then
        -- Output current settings
        print("|cff00ff00[Ding Classic Settings]|r")
        for key, value in pairs(DingClassic.settings) do
            print("|cffffff00" .. key .. ":|r " .. tostring(value))
        end
    else
        print("|cff00ff00[Ding Classic]|r Available commands:")
        print("|cffffff00/dc test|r - Simulate a level-up at your current level.")
        print("|cffffff00/dc test <level>|r - Simulate a level-up at the specified level.")
        print("|cffffff00/dc o|r - Open the options menu.")
        print("|cffffff00/dc settings|r - View current Ding Classic settings.")
    end
end