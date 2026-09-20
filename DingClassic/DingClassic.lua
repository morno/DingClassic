-- DingClassic.lua - Core Addon Logic (Refactored for Ace3)

-- BARE DIAGNOSTIC: a raw ADDON_LOADED listener with zero dependency on
-- AceAddon or any other library. Only prints when Debug Mode was on in the
-- last saved profile (checked directly on the raw table, since this fires
-- before self.db exists).
do
    local bareFrame = CreateFrame("Frame")
    bareFrame:RegisterEvent("ADDON_LOADED")
    bareFrame:SetScript("OnEvent", function(_, _, loadedName)
        if loadedName == "DingClassic" then
            local raw = _G["DingClassicDB"]
            if type(raw) == "table" and raw.profile and raw.profile.debugMode then
                print("|cffff00ff[DC DEBUG]|r type(_G.DingClassicDB) = " .. type(raw))
                if raw.profile.channels then
                    print("|cffff00ff[DC DEBUG]|r profile.channels.party = " .. tostring(raw.profile.channels.party))
                end
            end
        end
    end)
end

local addonName, DingClassic = ...
DingClassic = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")

-- BUG WORKAROUND: this bundled AceAddon-3.0's ADDON_LOADED handler calls
-- OnInitialize on ANY addon's ADDON_LOADED event (only a small hardcoded
-- Blizzard-internal blocklist is excluded) instead of waiting for THIS
-- addon's own ADDON_LOADED. That means OnInitialize can fire before our own
-- SavedVariables (DingClassicDB) have actually been populated from disk by
-- the client - we'd create a fresh/default table, and when the real saved
-- data loads moments later the global gets replaced out from under us, so
-- nothing we do afterwards ever reaches what actually gets saved at logout.
-- Fix: don't name our setup function "OnInitialize" (so AceAddon's automatic,
-- wrongly-timed call finds nothing to run), and instead register our own
-- ADDON_LOADED listener that checks the addon name explicitly, exactly like
-- Warcraft Wiki's own SavedVariables example recommends.
local dcLoadFrame = CreateFrame("Frame")
dcLoadFrame:RegisterEvent("ADDON_LOADED")
dcLoadFrame:SetScript("OnEvent", function(_, _, loadedName)
    if loadedName == addonName then
        DingClassic:RealOnInitialize()
    end
end)

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
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
                        hidden = function() return not LDBIcon end,
                        get = function() return self.db.profile.minimap.hide end,
                        set = function(_, value)
                            self.db.profile.minimap.hide = value
                            if LDBIcon then
                                if value then
                                    LDBIcon:Hide("DingClassic")
                                else
                                    LDBIcon:Show("DingClassic")
                                end
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
                    debugMode = {
                        type = "toggle",
                        name = L["DEBUG"] or "Enable Debug Mode",
                        desc = L["DEBUG_DESC"] or "Prints extra [DEBUG] trace lines to chat when gratz/welcome logic runs, to help diagnose why a message did or didn't send.",
                        get = function() return self.db.profile.debugMode end,
                        set = function(_, value) self:SetDebugMode(value) end,
                        order = 10,
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
                    interval = {
                        type = "select",
                        name = "Ding Interval",
                        desc = "Choose how often to send ding messages",
                        values = {
                            [1] = "Every Level",
                            [5] = "Every 5 Levels",
                            [10] = "Every 10 Levels",
                        },
                        get = function() return self.db.profile.levelInterval or 1 end,
                        set = function(_, value) self.db.profile.levelInterval = value end,
                        order = 3,
                    },
                    channels = {
                        type = "multiselect",
                        name = self.L["CHANNELS"] or "Channels",
                        desc = self.L["CHANNELS_DESC"] or "Select the channels to send the message to.",
                        values = {
                            party = self.L["PARTY"] or "Party",
                            guild = self.L["GUILD"] or "Guild",
                            raid = self.L["RAID"] or "Raid",
                        },
                        get = function(_, key)
                            return self.db.profile.channels[key]
                        end,
                        set = function(_, key, value)
                            self.db.profile.channels[key] = value
                        end,
                        order = 4,
                    },
                    channels_note = {
                        type = "description",
                        name = self.L["CHANNELS_NOTE"] or "Note: 'Party', 'Raid' and 'Guild' always send automatically.",
                        fontSize = "medium",
                        order = 4.1,
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
            gratz = {
                type = "group",
                name = L["TABS_GRATZ"] or "Gratz & Welcome",
                desc = L["TABS_GRATZ_DESC"] or "Achievement congratulations and guild welcome messages (ported from AutoGratzer).",
                order = 1.5,
                args = {
                    gratzHeader = {
                        type = "header",
                        name = L["GRATZ_HEADER"] or "Achievement Gratz",
                        order = 1,
                    },
                    gratzEnable = {
                        type = "toggle",
                        name = L["GRATZ_ENABLE"] or "Enable Achievement Gratz",
                        desc = L["GRATZ_ENABLE_DESC"] or "Automatically congratulate guild/party/raid members when they earn an achievement.",
                        get = function() return self.db.profile.gratz.achievementEnable end,
                        set = function(_, value) self.db.profile.gratz.achievementEnable = value end,
                        order = 2,
                    },
                    gratzMessage = {
                        type = "input",
                        name = L["GRATZ_MESSAGE"] or "Gratz Message",
                        desc = L["GRATZ_MESSAGE_DESC"] or "The message sent when someone earns an achievement.",
                        get = function() return self.db.profile.gratz.message end,
                        set = function(_, value) self.db.profile.gratz.message = value end,
                        width = "full",
                        order = 3,
                    },
                    gratzChannels = {
                        type = "multiselect",
                        name = L["GRATZ_CHANNELS"] or "Gratz Channels",
                        desc = L["GRATZ_CHANNELS_DESC"] or "Select which channels get achievement gratz.",
                        values = {
                            guild = L["GUILD"] or "Guild",
                            party = L["PARTY"] or "Party",
                            raid = L["RAID"] or "Raid",
                        },
                        get = function(_, key) return self.db.profile.gratz.channels[key] end,
                        set = function(_, key, value) self.db.profile.gratz.channels[key] = value end,
                        order = 4,
                    },
                    gratzDelayMin = {
                        type = "range",
                        name = L["GRATZ_DELAY_MIN"] or "Delay Min (ms)",
                        desc = L["GRATZ_DELAY_MIN_DESC"] or "The message is sent after a random delay between Min and Max, instead of instantly, so it feels a bit more human. Set both to 0 to send instantly.",
                        min = 0, max = 10000, step = 250,
                        get = function() return self.db.profile.gratz.delayMin end,
                        set = function(_, value)
                            self.db.profile.gratz.delayMin = value
                            if self.db.profile.gratz.delayMax < value then
                                self.db.profile.gratz.delayMax = value
                            end
                        end,
                        order = 5,
                    },
                    gratzDelayMax = {
                        type = "range",
                        name = L["GRATZ_DELAY_MAX"] or "Delay Max (ms)",
                        desc = L["GRATZ_DELAY_MAX_DESC"] or "The upper end of the random delay range described above.",
                        min = 0, max = 10000, step = 250,
                        get = function() return self.db.profile.gratz.delayMax end,
                        set = function(_, value)
                            self.db.profile.gratz.delayMax = value
                            if self.db.profile.gratz.delayMin > value then
                                self.db.profile.gratz.delayMin = value
                            end
                        end,
                        order = 5.1,
                    },
                    gratzGroupingTime = {
                        type = "range",
                        name = L["GRATZ_GROUPING"] or "Minimum Gap Between Messages (ms)",
                        desc = L["GRATZ_GROUPING_DESC"] or "Prevents spam when several achievements/joins happen close together.",
                        min = 0, max = 60000, step = 500,
                        get = function() return self.db.profile.gratz.groupingTime end,
                        set = function(_, value) self.db.profile.gratz.groupingTime = value end,
                        order = 6,
                    },
                    levelUpHeader = {
                        type = "header",
                        name = L["LEVELUP_HEADER"] or "Party/Raid Level Up Gratz",
                        order = 6.1,
                    },
                    levelUpEnable = {
                        type = "toggle",
                        name = L["LEVELUP_ENABLE"] or "Enable Level Up Gratz",
                        desc = L["LEVELUP_ENABLE_DESC"] or "Automatically congratulate party/raid members when they level up (uses the same channels above).",
                        get = function() return self.db.profile.gratz.levelUpEnable end,
                        set = function(_, value) self.db.profile.gratz.levelUpEnable = value end,
                        order = 6.2,
                    },
                    levelUpMessage = {
                        type = "input",
                        name = L["LEVELUP_MESSAGE"] or "Level Up Message",
                        desc = L["LEVELUP_MESSAGE_DESC"] or "The message sent when a party/raid member levels up. Use %s for their name and %d for their new level.",
                        get = function() return self.db.profile.gratz.levelUpMessage end,
                        set = function(_, value) self.db.profile.gratz.levelUpMessage = value end,
                        width = "full",
                        order = 6.3,
                    },
                    guildLevelUpEnable = {
                        type = "toggle",
                        name = L["GUILD_LEVELUP_ENABLE"] or "Also Congratulate the Whole Guild",
                        desc = L["GUILD_LEVELUP_ENABLE_DESC"] or "Extends level up gratz to ANY guild member (not just people in your group) by watching the guild roster for level changes, same as Guild Roster Manager's own level-up log does internally. Off by default - can mean a lot of guild chat traffic in a big guild. Uses the Level Up Message above and the Guild channel toggle.",
                        get = function() return self.db.profile.gratz.guildLevelUpEnable end,
                        set = function(_, value) self.db.profile.gratz.guildLevelUpEnable = value end,
                        order = 6.4,
                    },
                    minLevel = {
                        type = "range",
                        name = L["GRATZ_MINLEVEL"] or "Only Congratulate Above Level",
                        desc = L["GRATZ_MINLEVEL_DESC"] or "Level Up Gratz (party/raid and, if enabled, guild-wide) only fires once the character's NEW level is at least this high. Set to 1 to congratulate every level up.",
                        min = 1, max = 60, step = 1,
                        get = function() return self.db.profile.gratz.minLevel end,
                        set = function(_, value) self.db.profile.gratz.minLevel = value end,
                        order = 6.5,
                    },
                    levelInterval = {
                        type = "range",
                        name = L["GRATZ_LEVEL_INTERVAL"] or "Congratulate Every N Levels",
                        desc = L["GRATZ_LEVEL_INTERVAL_DESC"] or "Only send Level Up Gratz on levels that are a multiple of this (combined with the Min Level above). E.g. 5 with Min Level 15 congratulates at 15, 20, 25, 30... Set to 1 to congratulate every level up.",
                        min = 1, max = 20, step = 1,
                        get = function() return self.db.profile.gratz.levelInterval end,
                        set = function(_, value) self.db.profile.gratz.levelInterval = value end,
                        order = 6.6,
                    },
                    welcomeHeader = {
                        type = "header",
                        name = L["WELCOME_HEADER"] or "Guild Welcome",
                        order = 7,
                    },
                    welcomeEnable = {
                        type = "toggle",
                        name = L["WELCOME_ENABLE"] or "Enable Guild Welcome",
                        desc = L["WELCOME_ENABLE_DESC"] or "Automatically welcome new members when they join the guild (never retroactively for people who joined while you were offline).",
                        get = function() return self.db.profile.guildWelcome.enable end,
                        set = function(_, value) self.db.profile.guildWelcome.enable = value end,
                        order = 8,
                    },
                    welcomeMessage = {
                        type = "input",
                        name = L["WELCOME_MESSAGE"] or "Welcome Message",
                        desc = L["WELCOME_MESSAGE_DESC"] or "The message sent to guild chat when a new member joins.",
                        get = function() return self.db.profile.guildWelcome.message end,
                        set = function(_, value) self.db.profile.guildWelcome.message = value end,
                        width = "full",
                        order = 9,
                    },
                    welcomeDelayMin = {
                        type = "range",
                        name = L["WELCOME_DELAY_MIN"] or "Welcome Delay Min (ms)",
                        desc = L["WELCOME_DELAY_MIN_DESC"] or "The welcome message is sent after a random delay between Min and Max, instead of instantly. Set independently from the Gratz delay above. Set both to 0 to send instantly.",
                        min = 0, max = 30000, step = 500,
                        get = function() return self.db.profile.guildWelcome.delayMin end,
                        set = function(_, value)
                            self.db.profile.guildWelcome.delayMin = value
                            if self.db.profile.guildWelcome.delayMax < value then
                                self.db.profile.guildWelcome.delayMax = value
                            end
                        end,
                        order = 9.5,
                    },
                    welcomeDelayMax = {
                        type = "range",
                        name = L["WELCOME_DELAY_MAX"] or "Welcome Delay Max (ms)",
                        desc = L["WELCOME_DELAY_MAX_DESC"] or "The upper end of the random welcome delay range described above.",
                        min = 0, max = 30000, step = 500,
                        get = function() return self.db.profile.guildWelcome.delayMax end,
                        set = function(_, value)
                            self.db.profile.guildWelcome.delayMax = value
                            if self.db.profile.guildWelcome.delayMin > value then
                                self.db.profile.guildWelcome.delayMin = value
                            end
                        end,
                        order = 9.6,
                    },
                    gratzNote = {
                        type = "description",
                        name = function()
                            local grmStatus = self:IsGRMLoaded()
                                and (L["GRM_DETECTED"] or "Guild Roster Manager detected - no conflicts, we only read the public note, never write it.")
                                or (L["GRM_NOT_DETECTED"] or "Guild Roster Manager not detected.")
                            return (L["GRATZ_NOTE"] or "Tip: anyone can opt themselves out of gratz/welcome guild-wide by putting '[ng]' anywhere in their own public note (Guild Roster right-click > Edit Public Note).") .. "\n" .. grmStatus
                        end,
                        fontSize = "medium",
                        order = 10,
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


-- Opens the native (canvas) settings panel using Blizzard's own auto-assigned
-- numeric category ID (via :GetID()) - NOT a manually-set string ID, which a
-- recent patch broke for Settings.OpenToCategory even though several addons
-- (and Blizzard's own older example code) still use that now-broken pattern.
-- Falls back to a chat message instead of a Lua error if anything about this
-- still doesn't work on a given client.
function DingClassic:OpenNativeSettings()
    local ok = false
    if self.nativeCategory and self.nativeCategory.GetID then
        ok = pcall(Settings.OpenToCategory, self.nativeCategory:GetID())
    end
    if not ok then
        self:Print("Couldn't open the settings panel automatically - open it manually via Esc > Options > AddOns > Ding Classic Options.")
    end
end

function DingClassic:RefreshOptions()
    AceConfigRegistry:NotifyChange("DingClassic")
end

-- Does this client have the modern Settings API (Retail / "Forever")?
-- We check for the exact functions we use rather than WOW_PROJECT_ID, since
-- that constant isn't guaranteed to reflect a new client flavor correctly.
-- Every known Classic-family client (Classic Era, Anniversary, TBC, Wrath,
-- Cata, MoP Classic, ...) reports one of these WOW_PROJECT_* constants. We
-- explicitly exclude all of them so those clients always keep using the
-- old, proven Ace3+AceDB path - even if Blizzard ever backports the modern
-- Settings API to them (feature-detection alone would otherwise wrongly
-- switch them to the new native/no-AceDB path meant for Forever/Retail).
local function IsClassicFamily()
    return (WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
        or (WOW_PROJECT_BURNING_CRUSADE_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
        or (WOW_PROJECT_WRATH_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)
        or (WOW_PROJECT_CATACLYSM_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC)
        or (WOW_PROJECT_MISTS_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC)
        or false
end

local function HasNativeSettingsAPI()
    if IsClassicFamily() then
        return false
    end
    return Settings
        and Settings.RegisterCanvasLayoutCategory
        and Settings.RegisterCanvasLayoutSubcategory
        and Settings.RegisterAddOnCategory
        and true or false
end

-- Widget builders for the canvas-layout native panel. Built from raw
-- CreateFrame + texture file paths rather than named XML templates
-- (e.g. "InterfaceOptionsCheckButtonTemplate"), since this beta client has
-- already been seen to be missing/rename base-UI templates. Every widget
-- writes straight to the caller-supplied get/set - no reliance on Settings'
-- own auto-persistence (that's the part that isn't saving reliably here).
local ROW_HEIGHT = 26

local function AttachTooltip(frame, title, tooltip)
    if not tooltip then return end
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function AddCanvasCheckbox(parent, y, label, tooltip, getFn, setFn)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", 16, y)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb:SetChecked(getFn() and true or false)
    cb:SetScript("OnClick", function(self)
        setFn(self:GetChecked() and true or false)
    end)
    local text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    AttachTooltip(cb, label, tooltip)
    return y - ROW_HEIGHT
end

-- A simple "current value + click to cycle" button, used instead of a real
-- dropdown menu (avoids depending on UIDropDownMenuTemplate).
-- A real dropdown: click the button to show a small list of options below it,
-- click an option to pick it. Built entirely from plain frames/textures (no
-- UIDropDownMenuTemplate or other named XML template), consistent with the
-- rest of this panel's defensive approach on this beta client.
local openDropdown = nil -- only one popout list open at a time

local function AddCanvasDropdown(parent, y, label, tooltip, options, getFn, setFn)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText(label)

    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(220, 22)
    btn:SetPoint("TOPLEFT", 260, y + 4)
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.4)
    local btnText = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    btnText:SetPoint("LEFT", 8, 0)
    btnText:SetPoint("RIGHT", -18, 0)
    btnText:SetJustifyH("LEFT")
    local arrow = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("v")

    local popout = CreateFrame("Frame", nil, btn)
    popout:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    popout:SetSize(220, (#options * 20) + 4)
    popout:SetFrameStrata("TOOLTIP")
    local pbg = popout:CreateTexture(nil, "BACKGROUND")
    pbg:SetAllPoints()
    pbg:SetColorTexture(0.06, 0.06, 0.06, 0.97)
    popout:Hide()

    local function Refresh()
        local current = getFn()
        for _, opt in ipairs(options) do
            if opt.value == current then
                btnText:SetText(opt.text)
                return
            end
        end
        btnText:SetText(tostring(current))
    end

    for i, opt in ipairs(options) do
        local row = CreateFrame("Button", nil, popout)
        row:SetSize(220, 20)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
        row:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
        local rowText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        rowText:SetPoint("LEFT", 8, 0)
        rowText:SetText(opt.text)
        row:SetScript("OnClick", function()
            setFn(opt.value)
            Refresh()
            popout:Hide()
            openDropdown = nil
        end)
    end

    btn:SetScript("OnClick", function()
        if popout:IsShown() then
            popout:Hide()
            openDropdown = nil
        else
            if openDropdown and openDropdown ~= popout then
                openDropdown:Hide()
            end
            popout:Show()
            openDropdown = popout
        end
    end)
    AttachTooltip(btn, label, tooltip)
    Refresh()
    return y - ROW_HEIGHT
end

local function AddCanvasEditBox(parent, y, label, tooltip, getFn, setFn)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText(label)

    -- Guaranteed-visible current value, shown as a plain FontString (the
    -- same kind used for checkbox labels elsewhere in this panel, which we
    -- know renders correctly). This client's EditBox widget doesn't seem to
    -- display its own internal text, so we show the value here regardless,
    -- and keep the EditBox below purely for typing a new value.
    local currentValue = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    currentValue:SetPoint("TOPLEFT", 16, y - 20)
    currentValue:SetWidth(360)
    currentValue:SetJustifyH("LEFT")
    local function RefreshCurrentValue()
        currentValue:SetText("|cff888888Current:|r " .. tostring(getFn() or ""))
    end
    RefreshCurrentValue()

    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(360, 22)
    eb:SetPoint("TOPLEFT", 16, y - 40)
    eb:SetAutoFocus(false)

    -- Defensive font setup: try known font objects in order, then fall back
    -- to a raw font file path if none of them are available/valid in this
    -- client (we've already seen other base-UI globals missing this beta).
    local fontOK = false
    for _, fontObj in ipairs({ ChatFontNormal, GameFontHighlight, GameFontNormalSmall, GameFontNormal, NumberFontNormal }) do
        if fontObj and not fontOK then
            fontOK = pcall(eb.SetFontObject, eb, fontObj)
        end
    end
    if not fontOK then
        pcall(eb.SetFont, eb, "Fonts\\FRIZQT__.TTF", 12, "")
        print("|cffff9900[DC EditBox]|r No named font object worked for '" .. label .. "', used raw Fonts\\FRIZQT__.TTF fallback.")
    end

    eb:SetTextColor(1, 1, 1, 1)
    eb:SetTextInsets(4, 4, 0, 0)
    local bg = eb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.3)
    eb:SetText(tostring(getFn() or ""))
    eb:SetScript("OnEnterPressed", function(self)
        setFn(self:GetText())
        RefreshCurrentValue()
        self:ClearFocus()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        setFn(self:GetText())
        RefreshCurrentValue()
    end)
    AttachTooltip(eb, label, tooltip)
    return y - ROW_HEIGHT - 42
end

local function AddCanvasButton(parent, y, buttonText, tooltip, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(200, 24)
    btn:SetPoint("TOPLEFT", 16, y)
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.12, 0.05, 0.9)
    local border = btn:CreateTexture(nil, "BORDER")
    border:SetColorTexture(1, 0.82, 0, 0.6)
    border:SetPoint("TOPLEFT")
    border:SetPoint("BOTTOMRIGHT")
    local innerBg = btn:CreateTexture(nil, "ARTWORK")
    innerBg:SetPoint("TOPLEFT", 1, -1)
    innerBg:SetPoint("BOTTOMRIGHT", -1, 1)
    innerBg:SetColorTexture(0.15, 0.12, 0.05, 0.9)
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText(buttonText)
    btn:SetScript("OnClick", onClick)
    AttachTooltip(btn, buttonText, tooltip)
    return y - ROW_HEIGHT, btn
end

local function AddCanvasSlider(parent, y, label, tooltip, minValue, maxValue, step, getFn, setFn)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, y)

    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(200, 16)
    slider:SetPoint("TOPLEFT", 16, y - 22)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(getFn() or minValue)

    local function UpdateLabel(value)
        title:SetText(label .. ": " .. tostring(value))
    end
    UpdateLabel(getFn() or minValue)

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        setFn(value)
        UpdateLabel(value)
    end)
    AttachTooltip(slider, label, tooltip)
    return y - ROW_HEIGHT - 22
end

-- Native (non-Ace3-GUI) options panel for Retail/Forever-style clients using
-- a Blizzard Settings canvas category (same approach as Auctionator), with
-- hand-built widgets that read/write self.db.profile directly ourselves -
-- Settings.RegisterAddOnSetting's own auto-persistence isn't reliably saving
-- in this beta, so we don't depend on it at all.
function DingClassic:RegisterNativeOptions()
    local L = self.L
    local profile = self.db.profile

    local mainFrame = CreateFrame("Frame")
    local category = Settings.RegisterCanvasLayoutCategory(mainFrame, L["TITLE"] or "Ding Classic")
    local categoryName = L["TITLE"] or "Ding Classic" -- display name only, not used as an ID

    local generalFrame = CreateFrame("Frame")
    local generalCat = Settings.RegisterCanvasLayoutSubcategory(category, generalFrame, L["TABS_GENERAL"] or "General")

    local optionsFrame = CreateFrame("Frame")
    local optionsCat = Settings.RegisterCanvasLayoutSubcategory(category, optionsFrame, L["TABS_OPTIONS"] or "Options")

    local gratzFrame = CreateFrame("Frame")
    local gratzCat = Settings.RegisterCanvasLayoutSubcategory(category, gratzFrame, L["TABS_GRATZ"] or "Gratz & Welcome")

    -- Info header (version/status/locale/pool/debug) on the top-level page
    -- (what you see when you click "Ding Classic Options" itself, before
    -- picking a subcategory) - same at-a-glance info the old Ace3 panel
    -- header used to show. Note: WoW addons cannot make network requests,
    -- so an "update available" check against CurseForge isn't possible
    -- from in-game - use the CurseForge app/WoWUp for that.
    do
        local title = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText(L["TITLE"] or "Ding Classic")

        local info = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        info:SetPoint("TOPLEFT", 16, -44)
        info:SetWidth(460)
        info:SetJustifyH("LEFT")
        info:SetSpacing(4)
        local function RefreshInfo()
            local statusText = profile.enable and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
            local debugText = profile.debugMode and "|cff00ff00On|r" or "|cffaaaaaaOff|r"
            info:SetText(
                "Version: |cffffff00" .. tostring(self.version) .. "|r    "
                .. "Status: " .. statusText .. "    "
                .. "Debug Mode: " .. debugText .. "\n"
                .. "Locale: |cffffff00" .. tostring(profile.selectedLocale) .. "|r    "
                .. "Active Pool: |cffffff00" .. tostring(profile.selectedMessagePool) .. "|r    "
                .. "Author: |cffffff00" .. tostring(self.author) .. "|r\n\n"
                .. "|cff888888Check CurseForge for the latest version. Source & issues on GitHub:|r\n"
                .. "|cff3399ffgithub.com/morno/DingClassic|r\n\n"
                .. "|cff888888Select General, Options, or Gratz & Welcome on the left to change settings.|r"
            )
        end
        RefreshInfo()
        self.RefreshNativeInfoHeader = RefreshInfo
    end

    -- ===== General =====
    local y = -16

    y = AddCanvasCheckbox(generalFrame, y, L["ENABLE"] or "Enable Ding Messages",
        L["ENABLE_DESC"] or "Toggle ding messages on or off.",
        function() return profile.enable end,
        function(v)
            profile.enable = v
            if self.RefreshNativeInfoHeader then self.RefreshNativeInfoHeader() end
        end)

    y = AddCanvasCheckbox(generalFrame, y, L["HIDE_MINIMAP"] or "Hide Minimap Button",
        L["HIDE_MINIMAP_DESC"] or "Toggle the minimap button on or off.",
        function() return profile.minimap.hide end,
        function(v)
            profile.minimap.hide = v
            if LDBIcon then
                if v then LDBIcon:Hide("DingClassic") else LDBIcon:Show("DingClassic") end
            end
        end)

    y = AddCanvasCheckbox(generalFrame, y, L["DEBUG"] or "Enable Debug Mode",
        L["DEBUG_DESC"] or "Prints extra [DEBUG] trace lines to chat when gratz/welcome logic runs, and logs Legacy Challenge events for later review (/dc showlog).",
        function() return profile.debugMode end,
        function(v)
            self:SetDebugMode(v)
            if self.RefreshNativeInfoHeader then self.RefreshNativeInfoHeader() end
            if self.RefreshDebugButtons then self.RefreshDebugButtons() end
        end)

    -- Debug action buttons: only shown while Debug Mode is on. These wrap
    -- the same /dc showlog / clearlog / showallevents / clearallevents
    -- commands, so you don't have to type them.
    do
        local debugFrames = {}
        local dy = y
        local btn
        dy, btn = AddCanvasButton(generalFrame, dy, L["SHOW_LOG"] or "Show Debug Log",
            L["SHOW_LOG_DESC"] or "Print the last 20 debug log entries to chat.",
            function() self:ShowDebugLog() end)
        table.insert(debugFrames, btn)

        dy, btn = AddCanvasButton(generalFrame, dy, L["CLEAR_LOG"] or "Clear Debug Log",
            L["CLEAR_LOG_DESC"] or "Clear the debug log.",
            function() self:ClearDebugLog() end)
        table.insert(debugFrames, btn)

        dy, btn = AddCanvasButton(generalFrame, dy, L["SHOW_ALL_EVENTS"] or "Show All Captured Events",
            L["SHOW_ALL_EVENTS_DESC"] or "Print every distinct game event seen so far (use /dc showallevents <filter> in chat to narrow it down).",
            function() self:ShowAllEvents() end)
        table.insert(debugFrames, btn)

        dy, btn = AddCanvasButton(generalFrame, dy, L["CLEAR_ALL_EVENTS"] or "Clear Captured Events",
            L["CLEAR_ALL_EVENTS_DESC"] or "Clear the list of captured event names.",
            function() self:ClearAllEvents() end)
        table.insert(debugFrames, btn)

        local function RefreshDebugButtons()
            for _, frame in ipairs(debugFrames) do
                if profile.debugMode then frame:Show() else frame:Hide() end
            end
        end
        RefreshDebugButtons()
        self.RefreshDebugButtons = RefreshDebugButtons

        y = dy
    end

    do
        local localeOptions = {}
        for locale, label in pairs(self.availableLocales) do
            table.insert(localeOptions, { value = locale, text = label })
        end
        y = AddCanvasDropdown(generalFrame, y, L["LOCALE_LABEL"] or "Select Locale",
            L["LOCALE_DESC"] or "Choose the language for the addon. Click to cycle, reloads the UI.",
            localeOptions,
            function() return profile.selectedLocale end,
            function(v)
                if v ~= profile.selectedLocale then
                    profile.selectedLocale = v
                    ReloadUI()
                end
            end)
    end

    -- ===== Options =====
    y = -16
    do
        local poolOptions = {}
        for poolName in pairs(self.messagePools) do
            table.insert(poolOptions, { value = poolName, text = poolName })
        end
        y = AddCanvasDropdown(optionsFrame, y, L["POOL_LABEL"] or "Select Message Pool",
            L["POOL_DESC"] or "Choose a set of messages for level-up announcements.",
            poolOptions,
            function() return profile.selectedMessagePool end,
            function(v)
                profile.selectedMessagePool = v
                if self.RefreshNativeInfoHeader then self.RefreshNativeInfoHeader() end
            end)
    end

    y = AddCanvasDropdown(optionsFrame, y, "Ding Interval", "Choose how often to send ding messages",
        { { value = 1, text = "Every Level" }, { value = 5, text = "Every 5 Levels" }, { value = 10, text = "Every 10 Levels" } },
        function() return profile.levelInterval end,
        function(v) profile.levelInterval = v end)

    y = AddCanvasCheckbox(optionsFrame, y, L["SEND_DING_PARTY"] or "Send Ding Messages to Party",
        L["SEND_DING_PARTY_DESC"] or "When you level up, send the ding message to your Party chat.",
        function() return profile.channels.party end,
        function(v) profile.channels.party = v end)
    y = AddCanvasCheckbox(optionsFrame, y, L["SEND_DING_GUILD"] or "Send Ding Messages to Guild",
        L["SEND_DING_GUILD_DESC"] or "When you level up, send the ding message to your Guild chat.",
        function() return profile.channels.guild end,
        function(v) profile.channels.guild = v end)
    y = AddCanvasCheckbox(optionsFrame, y, L["SEND_DING_RAID"] or "Send Ding Messages to Raid",
        L["SEND_DING_RAID_DESC"] or "When you level up, send the ding message to your Raid chat.",
        function() return profile.channels.raid end,
        function(v) profile.channels.raid = v end)

    y = y - 10
    y = AddCanvasButton(optionsFrame, y, L["TEST"] or "Test Ding Message",
        L["TEST_DESC"] or "Send a random test ding message from the selected pool.",
        function()
            self:SendLevelUpMessage(UnitLevel("player"))
        end)

    -- ===== Gratz & Welcome (ported from AutoGratzer) =====
    y = -16
    y = AddCanvasCheckbox(gratzFrame, y, L["GRATZ_ENABLE"] or "Enable Achievement Gratz",
        L["GRATZ_ENABLE_DESC_NATIVE"] or "Automatically congratulate guild/party/raid members when they earn an achievement.",
        function() return profile.gratz.achievementEnable end,
        function(v) profile.gratz.achievementEnable = v end)

    y = AddCanvasCheckbox(gratzFrame, y, L["SEND_GRATZ_GUILD"] or "Send Achievement Gratz to Guild",
        L["SEND_GRATZ_GUILD_DESC"] or "When a guild member earns an achievement, congratulate them in Guild chat.",
        function() return profile.gratz.channels.guild end,
        function(v) profile.gratz.channels.guild = v end)
    y = AddCanvasCheckbox(gratzFrame, y, L["SEND_GRATZ_PARTY"] or "Send Achievement Gratz to Party",
        L["SEND_GRATZ_PARTY_DESC"] or "When a party member earns an achievement, congratulate them in Party chat.",
        function() return profile.gratz.channels.party end,
        function(v) profile.gratz.channels.party = v end)
    y = AddCanvasCheckbox(gratzFrame, y, L["SEND_GRATZ_RAID"] or "Send Achievement Gratz to Raid",
        L["SEND_GRATZ_RAID_DESC"] or "When a raid member earns an achievement, congratulate them in Raid chat.",
        function() return profile.gratz.channels.raid end,
        function(v) profile.gratz.channels.raid = v end)

    y = AddCanvasEditBox(gratzFrame, y, L["GRATZ_MESSAGE"] or "Gratz Message (use %s for name)",
        "Sent when someone earns an achievement.",
        function() return profile.gratz.message end,
        function(v) profile.gratz.message = v end)

    y = AddCanvasCheckbox(gratzFrame, y, L["LEVELUP_ENABLE"] or "Enable Level Up Gratz",
        L["LEVELUP_ENABLE_DESC"] or "Automatically congratulate party/raid members when they level up.",
        function() return profile.gratz.levelUpEnable end,
        function(v) profile.gratz.levelUpEnable = v end)
    y = AddCanvasCheckbox(gratzFrame, y, L["GUILD_LEVELUP_ENABLE"] or "Also Congratulate the Whole Guild",
        L["GUILD_LEVELUP_ENABLE_DESC"] or "Extends level up gratz to any guild member, not just people in your group.",
        function() return profile.gratz.guildLevelUpEnable end,
        function(v) profile.gratz.guildLevelUpEnable = v end)

    y = AddCanvasEditBox(gratzFrame, y, L["LEVELUP_MESSAGE"] or "Level Up Message (%s=name, %d=level)",
        "Sent when a tracked member levels up.",
        function() return profile.gratz.levelUpMessage end,
        function(v) profile.gratz.levelUpMessage = v end)

    y = AddCanvasSlider(gratzFrame, y, L["GRATZ_MINLEVEL"] or "Only Congratulate Above Level",
        L["GRATZ_MINLEVEL_DESC"] or "Level Up Gratz only fires once the new level is at least this high.",
        1, 60, 1,
        function() return profile.gratz.minLevel end,
        function(v) profile.gratz.minLevel = v end)
    y = AddCanvasSlider(gratzFrame, y, L["GRATZ_LEVEL_INTERVAL"] or "Congratulate Every N Levels",
        L["GRATZ_LEVEL_INTERVAL_DESC"] or "Only send Level Up Gratz on levels that are a multiple of this.",
        1, 20, 1,
        function() return profile.gratz.levelInterval end,
        function(v) profile.gratz.levelInterval = v end)

    y = AddCanvasCheckbox(gratzFrame, y, L["WELCOME_ENABLE"] or "Enable Guild Welcome",
        L["WELCOME_ENABLE_DESC"] or "Automatically welcome new members when they join the guild.",
        function() return profile.guildWelcome.enable end,
        function(v) profile.guildWelcome.enable = v end)

    y = AddCanvasEditBox(gratzFrame, y, L["WELCOME_MESSAGE"] or "Welcome Message (use %s for name)",
        "Sent to guild chat when a new member joins.",
        function() return profile.guildWelcome.message end,
        function(v) profile.guildWelcome.message = v end)

    Settings.RegisterAddOnCategory(category)
    self.nativeCategory = category
end

function DingClassic:RegisterOptions()
    if HasNativeSettingsAPI() then
        -- Retail / Forever: use Blizzard's own Settings API, bypass Ace3's GUI entirely.
        self:RegisterNativeOptions()
    else
        -- Classic Era / older clients without the Settings API: keep Ace3.
        local options = self:GetOptions()
        AceConfig:RegisterOptionsTable("DingClassic", options)
        self.configFrame = AceConfigDialog:AddToBlizOptions("DingClassic", "DingClassic")
    end
end

-- Fills in any keys missing from dst using src, recursing into sub-tables.
-- Never overwrites a value the user (or a previous session) already set.
local function DeepMergeDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            DeepMergeDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- Lightweight, AceDB-free SavedVariables handling for Retail/Forever: a plain
-- global table, same approach Wowhead Looter and Auctionator use. No profile
-- switching (this addon has never exposed that in its UI anyway) - every
-- value is written directly into this table so there's no read-through
-- defaults metatable involved anywhere in the chain.
function DingClassic:CreateNativeDB(defaults)
    local raw = _G["DingClassicDB"]
    if type(raw) ~= "table" then
        raw = {}
        _G["DingClassicDB"] = raw
    end
    if type(raw.profile) ~= "table" then
        raw.profile = {}
    end
    DeepMergeDefaults(raw.profile, defaults.profile)
    return {
        profile = raw.profile,
        GetCurrentProfile = function() return "Default" end,
    }
end

function DingClassic:RealOnInitialize()
    -- DEBUG: raw dump of the global SavedVariables table at the exact moment
    -- our ADDON_LOADED handler fires, before anything (including
    -- CreateNativeDB/AceDB) touches it. Only runs if Debug Mode was on in
    -- the last saved profile (checked directly on the raw table, since
    -- self.db doesn't exist yet at this point).
    do
        local raw = _G["DingClassicDB"]
        if type(raw) == "table" and raw.profile and raw.profile.debugMode then
            print("|cff00ffff[DC DEBUG @ RealOnInitialize]|r type = " .. type(raw))
            local function dump(t, indent)
                indent = indent or ""
                for k, v in pairs(t) do
                    if type(v) == "table" then
                        print("|cff00ffff[DC DEBUG]|r " .. indent .. tostring(k) .. " = {")
                        dump(v, indent .. "  ")
                        print("|cff00ffff[DC DEBUG]|r " .. indent .. "}")
                    else
                        print("|cff00ffff[DC DEBUG]|r " .. indent .. tostring(k) .. " = " .. tostring(v))
                    end
                end
            end
            dump(raw)
        end
    end

    -- Load localization
    self.version = self:GetMetadata("Version", "1.0.13")
    self.author = self:GetMetadata("Author", "Morno")    
    self:LoadLocalization()
    self.L = _G.DINGCLASSIC.L

    self.lastKnownLevel = UnitLevel("player")
    self.groupMemberLevels = {}

    local defaults = {
        profile = {
            enable = true,
            selectedMessagePool = "Default",
            selectedLocale = "enUS",
            levelInterval = 5,
            channels = {
                party = false,
                guild = true,
                raid = false,
            },
            debugMode = false,
            eventLog = {},
            allEventsSeen = {},
            -- Ported from AutoGratzer: congratulate guild/party/raid members on achievements,
            -- and welcome new members to the guild.
            gratz = {
                achievementEnable = true,
                message = "Gratzzz %s!",
                levelUpEnable = true,
                guildLevelUpEnable = false, -- off by default: can be a lot of guild-chat traffic in a big guild
                minLevel = 1, -- only send level up gratz once the new level is at least this high
                levelInterval = 1, -- only send level up gratz on levels that are a multiple of this
                levelUpMessage = "Congrats %s, now level %d!",
                delayMin = 1000,     -- ms, random delay range so messages don't fire instantly/robotically
                delayMax = 3500,     -- ms
                groupingTime = 6000, -- ms, minimum gap between two auto-messages (throttle)
                channels = {
                    guild = true,
                    party = false,
                    raid = false,
                },
            },
            guildWelcome = {
                enable = false,
                message = "Welcome %s :D",
                delayMin = 1000, -- ms, random delay range, independent from gratz.delayMin/Max
                delayMax = 3500, -- ms
            },
            minimap = {
                hide = false,
            },
        },
    }

    -- Retail/Forever: skip AceDB entirely and manage SavedVariables ourselves
    -- with a plain global table (same approach as Wowhead Looter/Auctionator),
    -- since AceDB's own load-back-from-disk hasn't been reliable on this beta.
    -- Classic Era/older clients: keep using AceDB as before.
    if HasNativeSettingsAPI() then
        self.db = self:CreateNativeDB(defaults)
    else
        self.db = AceDB:New("DingClassicDB", defaults, true)
    end

    -- Load message pools dynamically from localization
    self.messagePools = {
        Default = self.L["MESSAGE_Default"] or {},
        Funny = self.L["MESSAGE_Funny"] or {},
        HardCore = self.L["MESSAGE_HardCore"] or {},
        Lore = self.L["MESSAGE_Lore"] or {},
    }

    -- Register options
    self:RegisterOptions()

    if self.db.profile.debugMode then
        self:StartEventSniffer()
    end

    -- Add minimap button
    if LDB and LDBIcon then
        local dataObject = LDB:NewDataObject("DingClassic", {
            type = "launcher",
            text = "DingClassic",
            icon = "Interface\\AddOns\\DingClassic\\Icons\\DingClassic-16x16.tga",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    if self.nativeCategory then
                        self:OpenNativeSettings()
                    else
                        AceConfigDialog:Open("DingClassic")
                    end
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

    -- Register achievement-gratz and guild-welcome events (ported from AutoGratzer)
    self:RegisterEvent("CHAT_MSG_GUILD_ACHIEVEMENT", "OnChatMsgGuildAchievement")
    self:RegisterEvent("CHAT_MSG_ACHIEVEMENT", "OnChatMsgAchievement")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnGuildRosterUpdate")

    -- Congratulate party/raid members when they level up
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    self:RegisterEvent("UNIT_LEVEL", "OnUnitLevel")

    -- Ask for a fresh guild roster and give it a few seconds to fully stream in before we start
    -- diffing it for new members - otherwise a partial roster on login could look like everyone
    -- "just joined" and trigger false welcome messages. Anyone who joined while we were offline
    -- gets folded into this first snapshot silently (no retroactive welcome).
    self.rosterReady = false
    if GuildRoster then GuildRoster() end
    C_Timer.After(5, function() self.rosterReady = true end)

    -- Blizzard doesn't reliably push fresh guild roster data (level, notes, etc.) on its own -
    -- GUILD_ROSTER_UPDATE can go a long time between real refreshes unless something actively
    -- asks for one. Guild Roster Manager does this itself (that's why its own level-up log
    -- above showed roughly a minute of lag between the real level-up and the log entry). We
    -- request our own refresh every 30s so guild-wide level-up gratz doesn't lag arbitrarily
    -- long behind an actual level-up.
    if GuildRoster then
        C_Timer.NewTicker(30, function() GuildRoster() end)
    end

    -- Register AceDB callbacks for profile changes (Classic/Ace3 path only -
    -- the lightweight native DB has no callback system, nor needs one)
    if self.db.RegisterCallback then
        self.db.RegisterCallback(self, "OnProfileChanged", "RefreshOptions")
        self.db.RegisterCallback(self, "OnProfileCopied", "RefreshOptions")
        self.db.RegisterCallback(self, "OnProfileReset", "RefreshOptions")
    end
    
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

    if self.db.profile.debugMode then
        self:Print("|cff888888[DEBUG]|r Leveled up to " .. tostring(level) .. ". Building ding message...")
    end

    local poolName = self.db.profile.selectedMessagePool
    local pool = self.messagePools[poolName] or {}
    local message = pool[math.random(#pool)]:gsub("%%d", tostring(level))

    -- Check for combat or NPC interaction delays
    if self.inCombat or self:IsInteractingWithNPC() then
        self.delayedMessage = message
        if self.db.profile.debugMode then
            self:Print("|cff888888[DEBUG]|r In combat or talking to an NPC - message delayed until that ends.")
        end
        return
    end

    -- Send message to allowed channels
    self:SendToAllowedChannels(message)
end

function DingClassic:SendToAllowedChannels(message)
    -- Party/Raid/Guild have no Blizzard restriction on automated SendChatMessage calls.
    local sentAnywhere = false
    local debugMode = self.db.profile.debugMode

    if self.db.profile.channels.guild then
        if IsInGuild() then
            SendChatMessage(message, "GUILD")
            sentAnywhere = true
        elseif debugMode then
            self:Print("|cff888888[DEBUG]|r Guild channel is enabled, but you're not in a guild - nothing sent there.")
        end
    end

    if self.db.profile.channels.raid and IsInRaid() then
        SendChatMessage(message, "RAID")
        sentAnywhere = true
    elseif self.db.profile.channels.party and IsInGroup() and not IsInRaid() then
        SendChatMessage(message, "PARTY")
        sentAnywhere = true
    elseif debugMode then
        if self.db.profile.channels.raid and not IsInRaid() and self.db.profile.channels.party and not IsInGroup() then
            self:Print("|cff888888[DEBUG]|r Party/Raid channels are enabled, but you're not in a group - nothing sent there.")
        elseif self.db.profile.channels.raid and not IsInRaid() and not self.db.profile.channels.party then
            self:Print("|cff888888[DEBUG]|r Raid channel is enabled, but you're not in a raid - nothing sent there.")
        elseif self.db.profile.channels.party and not IsInGroup() and not self.db.profile.channels.raid then
            self:Print("|cff888888[DEBUG]|r Party channel is enabled, but you're not in a group - nothing sent there.")
        end
    end

    if not sentAnywhere then
        if debugMode then
            self:Print("|cff888888[DEBUG]|r Leveled up, but the message wasn't sent to any chat channel (printed locally only):")
        end
        self:Print(message)
    end
end

-- ===== Achievement gratz + guild welcome (ported from AutoGratzer) =====

-- Guild Roster Manager, if installed, manages its own roster/notes database. We only ever READ
-- the public note (for the opt-out tag below) and never write to it, so there's no conflict
-- with GRM's note-tagging features (alts, birthdays, etc). We don't rely on any GRM API for join
-- detection either - GRM doesn't currently expose one (their own GetJoinDates API stub is
-- unimplemented), so this is purely informational.
-- Checked live (not cached at OnInitialize) since addon load order isn't guaranteed - a cached
-- check could run before GRM has actually loaded yet and wrongly report it as absent.
function DingClassic:IsGRMLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Guild_Roster_Manager") and true or false
    elseif IsAddOnLoaded then
        return IsAddOnLoaded("Guild_Roster_Manager") and true or false
    end
    return false
end

-- Compares a chat sender name (possibly "Name-Realm") against the local player.
function DingClassic:IsMe(nameString)
    if not nameString or nameString == "" then return false end
    local name, server = strsplit("-", nameString)
    local myName = UnitName("player")
    if not server or server == "" then
        return name == myName
    end
    return name == myName and server == GetRealmName()
end

-- Schedules an auto-message (gratz or welcome) to fire via sendFn, after a random delay
-- between delayMin/delayMax (for that "not instant/robotic" feel). Unlike the old throttle,
-- which just DROPPED a message that landed too soon after another one - the bug where two
-- people dinging close together meant only one of them got a message - this instead spaces
-- messages out on a shared timeline: if the random slot would land less than groupingTime
-- after the previous scheduled message, it gets pushed later instead of skipped. Every message
-- still eventually sends, nothing is ever silently lost, they're just spread out over time.
function DingClassic:ScheduleGratzSend(sendFn, delayMin, delayMax)
    local groupingTime = (self.db.profile.gratz.groupingTime or 0) / 1000
    delayMin = (delayMin or 0) / 1000
    delayMax = (delayMax or 0) / 1000
    if delayMax < delayMin then delayMax = delayMin end

    local now = GetTime()
    local randomDelay = (delayMax > 0) and (delayMin + math.random() * (delayMax - delayMin)) or 0
    local earliestSlot = math.max(self.nextGratzSendTime or 0, now)
    local sendAt = math.max(now + randomDelay, earliestSlot)

    self.nextGratzSendTime = sendAt + groupingTime

    local wait = sendAt - now
    if wait > 0 then
        C_Timer.After(wait, sendFn)
    else
        sendFn()
    end
end

-- Substitutes "%s" (player name) and/or "%d" (level) in a message template - same convention
-- the ding messages already use "%d" for. Leaves parts untouched when there's nothing to fill in.
function DingClassic:FormatMessage(template, playerName, level)
    local message = template
    if playerName and message:find("%s", 1, true) then
        message = message:gsub("%%s", playerName)
    end
    if level and message:find("%d", 1, true) then
        message = message:gsub("%%d", tostring(level))
    end
    return message
end

-- source: "GUILD" or "GROUP" (party/raid, whichever you're actually in).
-- messageTemplate/level are optional overrides, used by the group-level-up gratz below;
-- achievement gratz just uses the normal gratz.message with no level.
-- Note: no shared "enable" gate here on purpose - each caller checks its OWN toggle
-- (achievementEnable / levelUpEnable / guildLevelUpEnable) before calling this, so the
-- Gratz & Welcome checkboxes are fully independent of each other.
function DingClassic:SendGratz(source, playerName, messageTemplate, level)
    local channel, allowed
    if source == "GUILD" then
        channel = "GUILD"
        allowed = self.db.profile.gratz.channels.guild and IsInGuild()
    elseif IsInRaid() then
        channel = "RAID"
        allowed = self.db.profile.gratz.channels.raid
    else
        channel = "PARTY"
        allowed = self.db.profile.gratz.channels.party and IsInGroup()
    end

    if not allowed then return end

    local template = messageTemplate or self.db.profile.gratz.message or "Gratzzz"
    local message = self:FormatMessage(template, playerName, level)
    self:ScheduleGratzSend(function() SendChatMessage(message, channel) end,
        self.db.profile.gratz.delayMin, self.db.profile.gratz.delayMax)
end

function DingClassic:OnChatMsgGuildAchievement(_, msg, sender)
    if not self.db.profile.gratz.achievementEnable then return end
    if self:IsMe(sender) then return end
    if self.guildDisabledOverride then return end
    if self:IsPlayerOptedOut(sender) then return end
    self:SendGratz("GUILD", (strsplit("-", sender)))
end

function DingClassic:OnChatMsgAchievement(_, msg, sender)
    if not self.db.profile.gratz.achievementEnable then return end
    if self:IsMe(sender) then return end
    if self:IsPlayerOptedOut(sender) then return end
    self:SendGratz("GROUP", (strsplit("-", sender)))
end

-- ===== Congratulate party/raid members when THEY level up =====
-- There's no Blizzard event for "another player leveled up" directly, but UNIT_LEVEL fires for
-- any tracked unit (which includes your party/raid members) when their level actually changes.
-- We keep a baseline of each group member's last-known level: GROUP_ROSTER_UPDATE only ever
-- SEEDS that baseline silently (so joining a group, or someone leveling while you were apart,
-- never triggers a false gratz), while UNIT_LEVEL compares against it and fires only on a real
-- increase witnessed live.
function DingClassic:SeedGroupMemberLevel(unit)
    if not UnitExists(unit) or UnitIsUnit(unit, "player") then return end
    local name = UnitName(unit)
    local level = UnitLevel(unit)
    if not name or not level or level <= 0 then return end
    self.groupMemberLevels[name] = level
end

function DingClassic:OnGroupRosterUpdate()
    self.groupMemberLevels = self.groupMemberLevels or {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            self:SeedGroupMemberLevel("raid" .. i)
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            self:SeedGroupMemberLevel("party" .. i)
        end
    else
        wipe(self.groupMemberLevels)
    end
end

function DingClassic:OnUnitLevel(_, unit)
    if not unit or not (unit:match("^party%d") or unit:match("^raid%d")) then return end
    if not UnitExists(unit) or UnitIsUnit(unit, "player") then return end

    local name = UnitName(unit)
    local level = UnitLevel(unit)
    if not name or not level or level <= 0 then return end

    self.groupMemberLevels = self.groupMemberLevels or {}
    local previous = self.groupMemberLevels[name]
    self.groupMemberLevels[name] = level

    if previous and level > previous and self.db.profile.gratz.levelUpEnable
        and level >= (self.db.profile.gratz.minLevel or 1)
        and level % (self.db.profile.gratz.levelInterval or 1) == 0
        and not self:IsPlayerOptedOut(name) then
        self:SendGratz("GROUP", (strsplit("-", name)), self.db.profile.gratz.levelUpMessage, level)
    end
end

-- Per-player opt-out: looks up ANY guild member's own public note (by name, "Name" or
-- "Name-Realm" as returned by GetGuildRosterInfo) and returns true if it contains "[ng]".
-- This is what actually lets an individual member exclude THEMSELVES from being congratulated -
-- checked against whoever a gratz/welcome message is ABOUT, not against the addon owner.
function DingClassic:IsPlayerOptedOut(name)
    if not name then return false end
    for index = 1, GetNumGuildMembers() do
        local rosterName, _, _, _, _, _, note = GetGuildRosterInfo(index)
        if rosterName == name then
            note = (note or ""):lower()
            return note:find("[ng]", 1, true) ~= nil
        end
    end
    return false
end

-- Lets the addon OWNER specifically silence the whole addon (guild welcome + guild-wide level
-- gratz) by putting the tag "[ng]" in THEIR OWN public note - handy for an officer to flip off
-- without needing to open the options UI. For any OTHER member wanting to opt just themselves
-- out of being congratulated, see IsPlayerOptedOut above.
function DingClassic:CheckGuildNoteOverride()
    for index = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, note = GetGuildRosterInfo(index)
        if self:IsMe(name) then
            note = (note or ""):lower()
            self.guildDisabledOverride = note:find("[ng]", 1, true) ~= nil
            return
        end
    end
end

-- Detects real new guild members by diffing the roster, instead of pattern-matching a
-- locale-dependent system chat string. A name can only appear in GetGuildRosterInfo() once
-- that person has actually accepted the invite, so this can't fire before they've accepted -
-- and since self.rosterReady gates this until 5s after login, someone who joined while we were
-- offline is folded into the first snapshot silently, with no retroactive welcome.
--
-- Two guards against a welcome-message storm to the WHOLE guild:
--  1) If we're not currently in a guild at all (e.g. right after a Hardcore death drops us
--     from the guild), we leave the last known roster snapshot completely untouched instead of
--     wiping it to {} - otherwise rejoining later would make every existing member look "new".
--  2) Even while in a guild, if a large batch of names appear "new" in one diff (rejoining,
--     a guild transfer, any other roster resync) that's not individual people joining one at a
--     time - we adopt the new baseline silently without welcoming any of them.
local GUILD_WELCOME_MASS_JOIN_THRESHOLD = 3

function DingClassic:CheckNewGuildMembers()
    if not IsInGuild() then
        return
    end

    local currentMembers = {}
    for index = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(index)
        if name then
            currentMembers[name] = true
        end
    end

    if self.rosterReady and self.knownGuildMembers and not self.guildDisabledOverride
        and self.db.profile.guildWelcome.enable then
        local newNames = {}
        for name in pairs(currentMembers) do
            if not self.knownGuildMembers[name] then
                table.insert(newNames, name)
            end
        end

        if #newNames > 0 and #newNames <= GUILD_WELCOME_MASS_JOIN_THRESHOLD then
            for _, name in ipairs(newNames) do
                if not self:IsPlayerOptedOut(name) then
                    self:GuildWelcome((strsplit("-", name)))
                end
            end
        elseif #newNames > GUILD_WELCOME_MASS_JOIN_THRESHOLD and self.db.profile.debugMode then
            self:Print(string.format(
                "|cff00ff00[DEBUG]|r Skipped welcome for %d guild members that appeared at once (roster resync, not individual joins).",
                #newNames
            ))
        end
    end

    self.knownGuildMembers = currentMembers
end

-- Guild-wide level-up gratz: works for ANY guild member, not just people in your party/raid.
-- Same technique Guild Roster Manager itself uses internally for its own level-up log (diffing
-- GetGuildRosterInfo's level field against a stored baseline) - there's no event for "a guild
-- member (who I'm not grouped with) leveled up", so periodically re-checking the roster on
-- GUILD_ROSTER_UPDATE is the only way to catch it. self.rosterReady gates this the same way as
-- CheckNewGuildMembers, so the first roster load after login never floods gratz for the whole guild.
function DingClassic:CheckGuildMemberLevels()
    self.knownGuildMemberLevels = self.knownGuildMemberLevels or {}

    for index = 1, GetNumGuildMembers() do
        local name, _, _, level, _, _, note = GetGuildRosterInfo(index)
        if name and level and level > 0 then
            local previous = self.knownGuildMemberLevels[name]

            if previous and level > previous then
                local optedOut = ((note or ""):lower()):find("[ng]", 1, true) ~= nil

                if self.db.profile.debugMode then
                    self:Print(string.format(
                        "|cff00ff00[DEBUG]|r %s: %d -> %d | rosterReady=%s guildLevelUpEnable=%s override=%s optedOut=%s",
                        name, previous, level, tostring(self.rosterReady),
                        tostring(self.db.profile.gratz.guildLevelUpEnable), tostring(self.guildDisabledOverride),
                        tostring(optedOut)
                    ))
                end

                if self.rosterReady and not self.guildDisabledOverride
                    and self.db.profile.gratz.guildLevelUpEnable
                    and level >= (self.db.profile.gratz.minLevel or 1)
                    and level % (self.db.profile.gratz.levelInterval or 1) == 0
                    and not self:IsMe(name)
                    and not optedOut then
                    self:SendGratz("GUILD", (strsplit("-", name)), self.db.profile.gratz.levelUpMessage, level)
                end
            end

            self.knownGuildMemberLevels[name] = level
        end
    end
end

function DingClassic:GuildWelcome(playerName)
    local message = self:FormatMessage(self.db.profile.guildWelcome.message or "Welcome :D", playerName)
    self:ScheduleGratzSend(function() SendChatMessage(message, "GUILD") end,
        self.db.profile.guildWelcome.delayMin, self.db.profile.guildWelcome.delayMax)
end

function DingClassic:OnGuildRosterUpdate()
    self:CheckGuildNoteOverride()
    self:CheckNewGuildMembers()
    self:CheckGuildMemberLevels()
end

function DingClassic:OnPlayerLevelUp(_, level)
    level = level or UnitLevel("player")

    if not self.db.profile.enable then
        self:Print(self.L["DISABLED_WARNING"] or "Ding Classic is currently disabled.")
        return
    end

    local interval = self.db.profile.levelInterval or 1
    if interval > 1 and level % interval ~= 0 then
        return
    end

    self.lastKnownLevel = level
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

-- Debug helper: WoW Forever apparently replaced Achievements with a "Legacy" system
-- (Legacy Challenges), and as of this beta there's no public documentation yet for
-- which event/message fires when one is completed. This registers a temporary
-- listener for ALL events for 2 minutes and prints anything that looks relevant
-- (name contains LEGACY/CHALLENGE/ACHIEVEMENT/REWARD/POINT) plus every system chat
-- message, so we can see the real event name/args the next time a Legacy Challenge
-- completes and wire it into gratz properly.
-- Debug helper: WoW Forever apparently replaced Achievements with a "Legacy"
-- system (Legacy Challenges), and there's no public documentation yet for
-- which event/message fires when one is completed. Rather than a one-off
-- timed sniff, this runs for as long as Debug Mode is on, and writes anything
-- interesting into self.db.profile.eventLog - which is real SavedVariables,
-- so it's still there after the fact even if you miss it scrolling by in
-- chat, and you (or I) can open .../SavedVariables/DingClassic.lua directly
-- to read it.
function DingClassic:StartEventSniffer()
    if not self.eventSniffer then
        self.eventSniffer = CreateFrame("Frame")
    end
    local sniffer = self.eventSniffer

    if not sniffer.RegisterAllEvents then
        self:Print("This client doesn't support RegisterAllEvents(), can't log events.")
        return
    end

    sniffer:RegisterAllEvents()
    sniffer:SetScript("OnEvent", function(_, event, ...)
        -- Silently record the first time we ever see each distinct event
        -- name (with its first set of args), so we catch entirely new
        -- triggers automatically instead of only ones matching our current
        -- keyword guesses. No chat spam - purely written to SavedVariables
        -- for later review via /dc showallevents.
        if not rawget(self.db.profile, "allEventsSeen") then
            self.db.profile.allEventsSeen = {}
        end
        if not self.db.profile.allEventsSeen[event] then
            local args = { ... }
            local parts = {}
            for i, v in ipairs(args) do parts[i] = tostring(v) end
            self.db.profile.allEventsSeen[event] = (#parts > 0) and table.concat(parts, ", ") or "(no args)"
        end

        local line
        if event == "CHAT_MSG_SYSTEM" then
            local msg = tostring(...)
            if msg:lower():match("legacy") or msg:lower():match("achievement") or msg:lower():match("challenge") then
                line = "[SYSTEM] " .. msg
            end
        elseif event:match("LEGACY") or event:match("CHALLENGE") or event:match("ACHIEVEMENT")
            or event:match("REWARD") or event:match("POINT") then
            local args = { ... }
            local parts = {}
            for i, v in ipairs(args) do parts[i] = tostring(v) end
            line = event .. " -> " .. table.concat(parts, ", ")
        end
        if line then
            self:LogDebugEvent(line)
        end
    end)
    self:Print("|cff00ff00[DingClassic]|r Event logging is on while Debug Mode is enabled. Complete a Legacy Challenge - it'll be captured even if you miss it in chat. Check with /dc showlog or /dc showallevents.")
end

function DingClassic:StopEventSniffer()
    if self.eventSniffer and self.eventSniffer.UnregisterAllEvents then
        self.eventSniffer:UnregisterAllEvents()
    end
end

-- Appends a timestamped line to the persistent debug log (real
-- SavedVariables - readable in .../SavedVariables/DingClassic.lua), capped
-- so it doesn't grow forever, and also echoes it to chat.
function DingClassic:ShowDebugLog()
    local log = self.db.profile.eventLog
    if not log or #log == 0 then
        self:Print("Debug event log is empty.")
    else
        self:Print("Debug event log (" .. #log .. " entries, showing last 20):")
        for i = math.max(1, #log - 19), #log do
            print("|cffff9900[Log]|r " .. log[i])
        end
    end
end

function DingClassic:ClearDebugLog()
    self.db.profile.eventLog = {}
    self:Print("Debug event log cleared.")
end

function DingClassic:ShowAllEvents(filter)
    local seen = self.db.profile.allEventsSeen or {}
    local names = {}
    for name in pairs(seen) do
        if not filter or name:lower():match(filter:lower()) then
            table.insert(names, name)
        end
    end
    table.sort(names)
    if #names == 0 then
        self:Print(filter and ("No captured events match '" .. filter .. "'.") or "No events captured yet - enable Debug Mode and play a bit first.")
    else
        self:Print(#names .. " distinct event(s)" .. (filter and (" matching '" .. filter .. "'") or "") .. ":")
        for _, name in ipairs(names) do
            print("|cff00ffff[Event]|r " .. name .. " -> " .. tostring(seen[name]))
        end
    end
end

function DingClassic:ClearAllEvents()
    self.db.profile.allEventsSeen = {}
    self:Print("Captured event-name list cleared.")
end

function DingClassic:LogDebugEvent(line)
    if not rawget(self.db.profile, "eventLog") then
        self.db.profile.eventLog = {}
    end
    local log = self.db.profile.eventLog
    table.insert(log, date("%H:%M:%S") .. "  " .. line)
    while #log > 200 do
        table.remove(log, 1)
    end
    print("|cffff9900[Sniff]|r " .. line)
end

-- Turns the debug event logger on/off to match Debug Mode, from any of the
-- places debugMode can be toggled (native panel, Ace3 panel, or on load if
-- it was already on in the saved profile).
function DingClassic:SetDebugMode(enabled)
    self.db.profile.debugMode = enabled
    if enabled then
        self:StartEventSniffer()
    else
        self:StopEventSniffer()
    end
end

function DingClassic:HandleSlashCommands(input)
    local rawInput = input or "" -- keep original case for message text
    input = input and input:lower() or "" -- Ensure input is a string

    if input == "" then
        -- Open the options page if no argument or "settings" is provided
        if self.nativeCategory then
            self:OpenNativeSettings()
        else
            AceConfigDialog:Open("DingClassic")
        end
    elseif input:match("^setmsg%s") then
        local kind = input:match("^setmsg%s+(%a+)")
        local text = rawInput:match("^%s*[Ss][Ee][Tt][Mm][Ss][Gg]%s+%a+%s+(.+)$")
        if kind == "gratz" and text then
            self.db.profile.gratz.message = text
            self:Print("Gratz message set to: " .. text)
        elseif kind == "levelup" and text then
            self.db.profile.gratz.levelUpMessage = text
            self:Print("Level Up message set to: " .. text)
        elseif kind == "welcome" and text then
            self.db.profile.guildWelcome.message = text
            self:Print("Welcome message set to: " .. text)
        else
            self:Print("Usage: /dc setmsg <gratz|levelup|welcome> <text>")
        end
    elseif input:match("^showallevents") then
        local filter = input:match("^showallevents%s+(.+)$")
        self:ShowAllEvents(filter)
    elseif input == "showlog" then
        self:ShowDebugLog()
    elseif input == "clearallevents" then
        self:ClearAllEvents()
    elseif input == "clearlog" then
        self:ClearDebugLog()
    elseif input == "github" then
        self:Print("Ding Classic on GitHub: https://github.com/morno/DingClassic")
    elseif input == "showmsg" then
        self:Print("Gratz message: " .. tostring(self.db.profile.gratz.message))
        self:Print("Level Up message: " .. tostring(self.db.profile.gratz.levelUpMessage))
        self:Print("Welcome message: " .. tostring(self.db.profile.guildWelcome.message))
    elseif input == "dumpdb" then
        self:Print("enable=" .. tostring(self.db.profile.enable)
            .. " debugMode=" .. tostring(self.db.profile.debugMode)
            .. " locale=" .. tostring(self.db.profile.selectedLocale)
            .. " pool=" .. tostring(self.db.profile.selectedMessagePool)
            .. " interval=" .. tostring(self.db.profile.levelInterval))
        self:Print("channels: party=" .. tostring(self.db.profile.channels.party)
            .. " guild=" .. tostring(self.db.profile.channels.guild)
            .. " raid=" .. tostring(self.db.profile.channels.raid))
        local mm = self.db.profile.minimap
        self:Print("minimap: hide=" .. tostring(mm.hide) .. " minimapPos=" .. tostring(mm.minimapPos))
        local g = self.db.profile.gratz
        self:Print("gratz: achievementEnable=" .. tostring(g.achievementEnable)
            .. " levelUpEnable=" .. tostring(g.levelUpEnable)
            .. " guildLevelUpEnable=" .. tostring(g.guildLevelUpEnable)
            .. " minLevel=" .. tostring(g.minLevel)
            .. " levelInterval=" .. tostring(g.levelInterval))
        self:Print("gratz channels: guild=" .. tostring(g.channels.guild)
            .. " party=" .. tostring(g.channels.party)
            .. " raid=" .. tostring(g.channels.raid))
        local w = self.db.profile.guildWelcome
        self:Print("guildWelcome: enable=" .. tostring(w.enable))
        self:Print("profile key in use: " .. tostring(self.db:GetCurrentProfile()))
    elseif input:match("test") then
        local levelInput = tonumber(input:match("test%s+(%d+)")) -- Extract level if provided
        if levelInput then
            -- If a specific level is provided, use it
            self:SendLevelUpMessage(levelInput)
        else
            -- Otherwise, use the player's current level
            self:SendLevelUpMessage(UnitLevel("player"))
        end
    elseif input:match("sniffevents") then
        self:SetDebugMode(true)
    elseif input:match("checklevels") then
        self:Print("Forcing a guild roster level check now...")
        self:CheckGuildMemberLevels()
    else
        -- Print available commands for invalid input
        self:Print("Available commands: /dc, /dc test, /dc gratzstatus, /dc checklevels, /dc setmsg <gratz|levelup|welcome> <text>, /dc showmsg, /dc dumpdb, /dc sniffevents, /dc showlog, /dc clearlog, /dc showallevents [filter], /dc clearallevents, /dc github")
    end
end

-- Debug helper: dumps every condition that gates guild-wide level-up gratz, so we can see
-- exactly which one is blocking it without having to wait for (and guess about) a real event.
function DingClassic:PrintGratzStatus()
    self:Print("=== Gratz Status ===")
    self:Print("gratz.achievementEnable: " .. tostring(self.db.profile.gratz.achievementEnable))
    self:Print("gratz.guildLevelUpEnable: " .. tostring(self.db.profile.gratz.guildLevelUpEnable))
    self:Print("gratz.channels.guild: " .. tostring(self.db.profile.gratz.channels.guild))
    self:Print("IsInGuild(): " .. tostring(IsInGuild()))
    self:Print("self.rosterReady: " .. tostring(self.rosterReady))
    self:Print("self.guildDisabledOverride: " .. tostring(self.guildDisabledOverride))
    self:Print("self.nextGratzSendTime: " .. tostring(self.nextGratzSendTime) .. " (now: " .. tostring(GetTime()) .. ")")
    local count = 0
    for _ in pairs(self.knownGuildMemberLevels or {}) do count = count + 1 end
    self:Print("Tracked guild member levels: " .. count .. " / GetNumGuildMembers(): " .. tostring(GetNumGuildMembers()))
end

function DingClassic:SendMessageToAllowedChannels(message)
    self:SendToAllowedChannels(message)
end
