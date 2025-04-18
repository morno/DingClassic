-- DingClassic.lua - Core Addon Logic (Refactored for Ace3)

local addonName, DingClassic = ...
DingClassic = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true)

-- Ensure global namespace is initialized
_G.DINGCLASSIC = _G.DINGCLASSIC or {}

function DingClassic:GetMetadata(field, fallback)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata("DingClassic", field) or fallback
    elseif GetAddOnMetadata then
        return GetAddOnMetadata("DingClassic", field) or fallback
    else
        return fallback
    end
end

function DingClassic:GetAddonVersion()
    return self.version or "Unknown"
end

function DingClassic:GetAddonAuthor()
    return self.author or "Unknown"
end

function DingClassic:LoadLocalization()
    -- Ensure AceLocale is available
    local AceLocale = LibStub("AceLocale-3.0", true)
    if not AceLocale then
        error("AceLocale-3.0 is not available. Ensure all dependencies are properly included.")
    end

    -- Load localization data
    _G.DINGCLASSIC.L = AceLocale:GetLocale("DingClassic", true)
    if not _G.DINGCLASSIC.L then
        error("Localization for DingClassic not loaded. Ensure the localization file is included.")
    end

    -- Use the LOCALES table from L
    self.availableLocales = _G.DINGCLASSIC.L["LOCALES"] or {}
end

function DingClassic:DebugAvailableLocales()
    if not self.availableLocales or next(self.availableLocales) == nil then
        self:Print("No available locales found.")
        return
    end

    self:Print("Available Locales:")
    for locale in pairs(self.availableLocales) do
        self:Print("- " .. locale)
    end
end

function DingClassic:GetOptions()
    local profiles = AceDBOptions:GetOptionsTable(self.db)
    local L = self.L

    return {
        name = function()
            local version = self:GetAddonVersion()
            return (L["TITLE"] or "Ding Classic Options") .. " |cff00ff00(v" .. version .. ")|r"
        end,
        type = "group",
        args = {
            general = {
                type = "group",
                name = L["TABS_GENERAL"] or "General",
                desc = L["TABS_GENERAL_DESC"] or "General Settings",
                order = 1,
                args = {
                    enable = {
                        type = "toggle",
                        name = L["ENABLE"] or "Enable Ding Messages",
                        desc = L["ENABLE_DESC"] or "Toggle ding messages on or off.",
                        get = function() return self.db.profile.enable end,
                        set = function(_, value) self.db.profile.enable = value end,
                    },
                    minimap = {
                        type = "toggle",
                        name = L["HIDE_MINIMAP"] or "Hide Minimap Button",
                        desc = L["HIDE_MINIMAP_DESC"] or "Toggle the minimap button on or off.",
                        get = function() return self.db.profile.minimap.hide end,
                        set = function(_, value)
                            self.db.profile.minimap.hide = value
                            if value then
                                LDBIcon:Hide("DingClassic")
                            else
                                LDBIcon:Show("DingClassic")
                            end
                        end,
                    },
                    locale = {
                        type = "select",
                        name = L["LOCALE_LABEL"] or "Select Locale",
                        desc = L["LOCALE_DESC"] or "Choose the language for the addon.",
                        values = function()
                            return self.availableLocales
                        end,
                        get = function() return self.db.profile.selectedLocale end,
                        set = function(_, value)
                            self.db.profile.selectedLocale = value
                            ReloadUI() -- Reload the UI to apply the locale
                        end,
                    },
                },
            },
            options = {
                type = "group",
                name = L["TABS_OPTIONS"] or "Options",
                desc = L["TABS_OPTIONS_DESC"] or "Options Settings",
                order = 2,
                args = {
                    messagePool = {
                        type = "select",
                        name = L["POOL_LABEL"] or "Select Message Pool",
                        desc = L["POOL_DESC"] or "Choose a set of messages for level-up announcements.",
                        values = function()
                            local pools = {}
                            for poolName in pairs(self.messagePools) do
                                pools[poolName] = poolName
                            end
                            return pools
                        end,
                        get = function() return self.db.profile.selectedMessagePool end,
                        set = function(_, value) self.db.profile.selectedMessagePool = value end,
                        order = 1, -- Top of the Options tab
                    },
                    testButton = {
                        type = "execute",
                        name = L["TEST"] or "Test Ding Message",
                        desc = L["TEST_DESC"] or "Send a random test ding message from the selected pool.",
                        func = function()
                            if not DingClassic.db.profile.enable then
                                DingClassic:Print(L["DISABLED_WARNING"] or "Ding Classic is currently disabled.")
                                return
                            end
                            
                            local level = UnitLevel("player")
                            local poolName = self.db.profile.selectedMessagePool
                            local pool = DingClassic.messagePools[poolName] or {}
                            local message = pool[math.random(#pool)]:gsub("%%d", tostring(level))
                            DingClassic:SendMessageToAllowedChannels(message)
                        end,
                        order = 2, -- Below "Select Message Pool"
                    },
                    channels = {
                        type = "multiselect",
                        name = self.L["CHANNELS"] or "Channels",
                        desc = self.L["CHANNELS_DESC"] or "Select the channels to send the message to.",
                        values = {
                            say = self.L["SAY"] or "Say",
                            party = self.L["PARTY"] or "Party",
                            guild = self.L["GUILD"] or "Guild",
                            raid = self.L["RAID"] or "Raid",
                        },
                        get = function(_, key)
                            if key == "guild" then
                                return self.db.profile.channels[key]
                            end
                            return false -- Grey out other channels
                        end,
                        set = function(_, key, value)
                            if key == "guild" then
                                self.db.profile.channels[key] = value
                            end
                        end,
                        disabled = function(_, key) return key ~= "guild" end,
                        order = 3,
                    },
                    channels_note = {
                        type = "description",
                        name = self.L["CHANNELS_NOTE"] or "Note: Blizzard restricts automated messaging to 'Say', 'Party', and 'Raid' channels. These options are disabled for automatic level-up messages.",
                        fontSize = "medium",
                        order = 3.1,
                    },
                    previewSection = {
                        type = "group",
                        name = L["PREVIEW_SECTION"] or "Message Preview",
                        desc = L["PREVIEW_SECTION_DESC"] or "Preview random messages from the selected pool.",
                        inline = true, -- Make this visually a box
                        order = 4, -- Place Preview Section at the bottom
                        args = {
                            messagePreview = {
                                type = "description",
                                name = function()
                                    local poolName = self.db.profile.selectedMessagePool
                                    local pool = self.messagePools[poolName] or {}

                                    if #pool == 0 then
                                        return self.L["NO_MESSAGES"] or "No messages available in the selected pool."
                                    end

                                    local previewMessages = {}
                                    local indicesUsed = {}

                                    while #previewMessages < math.min(4, #pool) do
                                        local randomIndex = math.random(1, #pool)
                                        if not indicesUsed[randomIndex] then
                                            indicesUsed[randomIndex] = true
                                            local message = pool[randomIndex]

                                            if type(message) == "string" then
                                                table.insert(previewMessages, message)
                                            else
                                                table.insert(previewMessages, "Invalid message entry")
                                            end
                                        end
                                    end

                                    return table.concat(previewMessages, "\n")
                                end,
                                fontSize = "medium",
                                order = 1,
                            },
                            refreshPreviewButton = {
                                type = "execute",
                                name = self.L["REFRESH_PREV"] or "Refresh Preview",
                                desc = self.L["REFRESH_PREV_DESC"] or "Refresh the displayed messages from the current pool.",
                                func = function()
                                    AceConfigRegistry:NotifyChange("DingClassic")
                                end,
                                order = 2, -- Right below the preview
                            },
                        },
                    },
                },
            },
            profiles = profiles,
            footer = {
                type = "description",
                name = function()
                    -- Fetch dynamic data
                    local addonVersion = self:GetAddonVersion()
                    local addonAuthor = self:GetAddonAuthor()
                    local selectedLocale = DingClassic.db.profile.selectedLocale or "Unknown"
                    local activePool = DingClassic.db.profile.selectedMessagePool or "Default"
                    local isEnabled = DingClassic.db.profile.enable and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
            
                    -- Construct the footer text
                    return string.format(
                        "|cffffff00Ding Classic|r |cff00ff00(v%s)|r    " ..
                        "|cffffffffLocale:|r |cff00ff00%s|r    " ..
                        "|cffffffffStatus:|r %s    " ..
                        "|cffffffffActive Pool:|r |cff00ff00%s|r    " ..
                        "|cffffffffAuthor:|r |cff00ff00%s|r",
                        addonVersion,
                        selectedLocale,
                        isEnabled,
                        activePool,
                        addonAuthor
                    )
                end,
                fontSize = "medium",
                order = -1, -- Ensure it appears at the bottom
            },
        },
    }
end


function DingClassic:RefreshOptions()
    AceConfigRegistry:NotifyChange("DingClassic")
end

function DingClassic:RegisterOptions()
    local options = self:GetOptions()
    AceConfig:RegisterOptionsTable("DingClassic", options)
    self.configFrame = AceConfigDialog:AddToBlizOptions("DingClassic", "DingClassic")
end

function DingClassic:OnInitialize()
    -- Load localization
    self.version = self:GetMetadata("Version", "1.0.13")
    self.author = self:GetMetadata("Author", "Morno")    
    self:LoadLocalization()
    self.L = _G.DINGCLASSIC.L


    -- Initialize AceDB
    self.db = AceDB:New("DingClassicDB", {
        profile = {
            enable = true,
            selectedMessagePool = "Default",
            selectedLocale = "enUS",
            channels = {
                say = false,
                party = false,
                guild = true,
                raid = false,
            },
            minimap = {
                hide = false,
            },
        },
    }, true)

    -- Load message pools dynamically from localization
    self.messagePools = {
        Default = self.L["MESSAGE_Default"] or {},
        Funny = self.L["MESSAGE_Funny"] or {},
        HardCore = self.L["MESSAGE_HardCore"] or {},
        Lore = self.L["MESSAGE_Lore"] or {},
    }

    -- Register options
    self:RegisterOptions()

    -- Add minimap button
    if LDB and LDBIcon then
        local dataObject = LDB:NewDataObject("DingClassic", {
            type = "launcher",
            text = "DingClassic",
            icon = "Interface\\AddOns\\DingClassic\\Icons\\DingClassic-16x16.tga",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    AceConfigDialog:Open("DingClassic")
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("DingClassic")
                tooltip:AddLine("|cffeda55fClick|r to open settings.")
            end,
        })
        LDBIcon:Register("DingClassic", dataObject, self.db.profile.minimap)
    end

    -- Print load message
    print(string.format("|cFF00FF00[DingClassic]:|r Addon loaded successfully! Version: %s", DingClassic:GetAddonVersion()))

    -- Register slash commands
    self:RegisterChatCommand("dc", "HandleSlashCommands")
    self:RegisterChatCommand("ding", "HandleSlashCommands")
    self:RegisterChatCommand("dingclassic", "HandleSlashCommands")
    self:RegisterChatCommand("dcl", "DebugAvailableLocales")

    -- Register level-up event
    self:RegisterEvent("PLAYER_LEVEL_UP", "OnPlayerLevelUp")

    -- Register combat and interaction events
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
    self:RegisterEvent("GOSSIP_SHOW", "OnNPCInteraction")
    self:RegisterEvent("GOSSIP_CLOSED", "OnNPCInteractionEnd")

    -- Register AceDB callbacks for profile changes
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshOptions")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshOptions")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshOptions")
    
    -- Register callback for locale changes or other settings
    self:RegisterMessage("DingClassic_LocaleChanged", "RefreshOptions")

    self.delayedMessage = nil
end

function DingClassic:SendLevelUpMessage(level)
    -- Use the player's current level if the level is not provided
    level = level or UnitLevel("player")

    if not self.db.profile.enable then
        self:Print(self.L["DISABLED_WARNING"] or "Ding Classic is currently disabled.")
        return
    end

    local poolName = self.db.profile.selectedMessagePool
    local pool = self.messagePools[poolName] or {}
    local message = pool[math.random(#pool)]:gsub("%%d", tostring(level))

    -- Check for combat or NPC interaction delays
    if self.inCombat or self:IsInteractingWithNPC() then
        self.delayedMessage = message
        return
    end

    -- Send message to allowed channels
    if self.db.profile.channels.guild then
        SendChatMessage(message, "GUILD")
    else
        self:Print(message)
    end
end

function DingClassic:OnPlayerLevelUp(_, level)
    -- Use the provided level or fallback to the player's current level
    level = level or UnitLevel("player")

    if not self.db.profile.enable then
        self:Print(self.L["DISABLED_WARNING"] or "Ding Classic is currently disabled.")
        return
    end

    self:SendLevelUpMessage(level)
end

function DingClassic:OnCombatStart()
    self.inCombat = true
end

function DingClassic:OnCombatEnd()
    self.inCombat = false
    if self.delayedMessage then
        self:SendMessageToAllowedChannels(self.delayedMessage)
        self.delayedMessage = nil
    end
end

function DingClassic:OnNPCInteraction()
    self.interactingWithNPC = true
end

function DingClassic:OnNPCInteractionEnd()
    self.interactingWithNPC = false
    if self.delayedMessage then
        self:SendMessageToAllowedChannels(self.delayedMessage)
        self.delayedMessage = nil
    end
end

function DingClassic:IsInteractingWithNPC()
    return self.interactingWithNPC
end

function DingClassic:HandleSlashCommands(input)
    input = input and input:lower() or "" -- Ensure input is a string

    if input == "" then
        -- Open the options page if no argument or "settings" is provided
        AceConfigDialog:Open("DingClassic")
    elseif input:match("test") then
        local levelInput = tonumber(input:match("test%s+(%d+)")) -- Extract level if provided
        if levelInput then
            -- If a specific level is provided, use it
            self:SendLevelUpMessage(levelInput)
        else
            -- Otherwise, use the player's current level
            self:SendLevelUpMessage(UnitLevel("player"))
        end
    else
        -- Print available commands for invalid input
        self:Print("Available commands: /dc, /dc test")
    end
end

function DingClassic:SendMessageToAllowedChannels(message)
    if self.db.profile.channels.guild and IsInGuild() then
        SendChatMessage(message, "GUILD")
    else
        self:Print("Cannot send automatic messages to channels other than Guild due to Blizzard restrictions.")
    end
end
