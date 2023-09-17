local addonName = "DingClassic"
local ding_version = "1.0.0"
local max_level = 60
local showDingMessages = true  -- Initialize with messages being shown
local sendToYell = true
local sendToSay = true
local sendToGuild = true

-- Define an array of random ding messages
local dingMessages = {
    "Ding! Level %d! My character's leveling is so epic, even dragons ask for tips on breathing fire.",
    "Ding! Level %d! My character has gained more levels than I've had hot dinners.",
    "Ding! Level %d! I've leveled up so much, I'm considering opening a 'Level Up' consultancy.",
    "Ding! Level %d! My character is so legendary, they put 'Legend of Zelda' to shame.",
    "Ding! Level %d! My character's leveling speed is faster than a caffeinated squirrel on a double espresso.",
    "Ding! Level %d! My character is now so powerful, they don't defeat bosses, bosses defeat themself out of fear.",
    "Ding! Level %d! I've leveled up so much, even Gandalf asked for leveling advice.",
    "Ding! Level %d! My character is so maxed out, they can high-five Thor without flinching.",
    "Ding! Level %d! My character is so overpowered, they can sneeze and defeat an entire army.",
    "Ding! Level %d! My character's leveling speed is faster than my WiFi... most of the time.",
    "Ding! Level %d! My character is so strong, they can open a pickle jar on the first try.",
    "Ding! Level %d! I've leveled up so many times, my character has a Ph.D. in Dingology.",
    "Ding! Level %d! I'm not addicted, I'm just passionately committed to my character's success.",
    "Ding! Level %d! My character is now eligible for the 'Most Leveled' award at the MMO Oscars.",
    "Ding! Level %d! My character is so fast at leveling, they give The Flash a run for his money.",
    "Ding! Level %d! I've leveled up so much, even the loading screen tips ask me for advice.",
    "Ding! Level %d! My character is so good, they leveled up while I was writing this message.",
    "Ding! Level %d! My character now has a better credit score than I do.",
    "Ding! Level %d! I've leveled up so much, I'm considering a second life as a professional leveler.",
    "Ding! Level %d! My character is so maxed out, they're on the cover of Leveler's Weekly.",
    "Ding! Level %d! My character has more XP than all the coffee I've ever consumed.",
    "Ding! Level %d! My character is now legally allowed to carry an oversized weapon.",
    "Ding! Level %d! I've spent more time in Azeroth than I have in reality.",
    "Ding! Level %d! My character is so legendary, they put Chuck Norris out of a job.",
    "Ding! Level %d! I've leveled up more times than I've changed my profile picture.",
    "Ding! Level %d! My character is so overpowered, even Chuck Norris asks for tips.",
    "Ding! Level %d! My character is so epic, they can even butter toast perfectly.",
    "Ding! Level %d! My character is now old enough to vote in Azeroth.",
    "Ding! Level %d! I've spent more time leveling than I have at family gatherings.",
    "Ding! Level %d! My character's Tinder profile just got a lot more impressive.",
    "Ding! Level %d! My character is so fit from all this leveling, even the NPCs are mirin'.",
    "Ding! Level %d! I've achieved the level of procrastination master.",
    "Ding! Level %d! I've probably defeated more dragons than all medieval knights combined.",
    "Ding! Level %d! If only I could level up my cooking skills as fast as my character.",
    "Ding! Level %d! My character is leveling faster than my plants are growing.",
    "Ding! Level %d! I'm so good at this game, I should put it on my resume.",
    "Ding! Level %d! My character is more maxed out than my credit cards.",
    "Ding! Level %d! Now I can finally tell my parents I've achieved something in life.",
    "Ding! Level %d! My social life may be in ruins, but at least my character is thriving!",
    "Ding! Level %d! I swear I'll go outside... after just one more level.",
    "Ding! Level %d! My parents said I'd never amount to anything. Look at me now, Mom!",
    "Ding! Level %d! Who needs sleep when there are epic loot and quests to conquer?",
    "Ding! Level %d! I'd like to thank my coffee maker for keeping me awake on this journey.",
    "Ding! Level %d! My character is leveling up faster than my bank account is depleting.",
    "Ding! Level %d! I may not have a real job, but I'm %d level in a fantasy world!",
    "Ding! Level %d! I've reached the level where I can procrastinate even more effectively.",
    "Ding! Level %d! I'm not addicted; I just have an intense dedication to my virtual self.",
    "Ding! Level %d! My character is now officially better at life than I am.",
    "Ding! Level %d! I'd like to thank my pizza delivery guy for sustaining me through this journey.",
    "Ding! Level %d! I may not have a real diploma, but I have a %d character!",
    "Ding! Level %d! If only I could level up my real-life responsibilities as easily.",
    "Ding! Level %d! Who needs a gym when you can level up from the comfort of your chair?",
    "Ding! Level %d! I told my boss I'm 'leveling up' my skills while working from home.",
    "Ding! Level %d! At this point, I think my character deserves a virtual Ph.D.",
    "Ding! Level %d! I've spent more time in Azeroth than I have in my own hometown.",
    "Ding! Level %d! My character is so legendary, even NPCs ask for autographs.",
    "Ding! Level %d! I've reached the level where I can procrastinate professionally.",
    "Ding! Level %d! My character's leveling speed could break the space-time continuum.",
    "Ding! Level %d! My character is so buffed, even Hercules asked for workout tips.",
    "Ding! Level %d! I've spent more time leveling than I have sleeping... and that's saying something.",
}

-- Function to initialize the options panel
local function InitializeOptionsPanel()
    local optionsPanel = CreateFrame("Frame", "DingClassicOptionsPanel", InterfaceOptionsFramePanelContainer)
    optionsPanel.name = "Ding Classic"
    optionsPanel.okay = function(self) end
    optionsPanel.cancel = function(self) end

    local checkbox = CreateFrame("CheckButton", "$parentCheckbox", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", 10, -10)
    checkbox.Text:SetText("Show Ding Messages")
    checkbox:SetChecked(showDingMessages)
    checkbox:SetScript("OnClick", function(self)
        showDingMessages = self:GetChecked()
    end)

    local checkboxYell = CreateFrame("CheckButton", "$parentCheckboxYell", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    checkboxYell:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 0, -10)
    checkboxYell.Text:SetText("Send Ding to Yell")
    checkboxYell:SetChecked(sendToYell)
    checkboxYell:SetScript("OnClick", function(self)
        sendToYell = self:GetChecked()
    end)

    local checkboxSay = CreateFrame("CheckButton", "$parentCheckboxSay", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    checkboxSay:SetPoint("TOPLEFT", checkboxYell, "BOTTOMLEFT", 0, -10)
    checkboxSay.Text:SetText("Send Ding to Say")
    checkboxSay:SetChecked(sendToSay)
    checkboxSay:SetScript("OnClick", function(self)
        sendToSay = self:GetChecked()
    end)

    local checkboxGuild = CreateFrame("CheckButton", "$parentCheckboxGuild", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    checkboxGuild:SetPoint("TOPLEFT", checkboxSay, "BOTTOMLEFT", 0, -10)
    checkboxGuild.Text:SetText("Send Ding to Guild")
    checkboxGuild:SetChecked(sendToGuild)
    checkboxGuild:SetScript("OnClick", function(self)
        sendToGuild = self:GetChecked()
    end)

    local testDingButton = CreateFrame("Button", "$parentTestDingButton", optionsPanel, "UIPanelButtonTemplate")
    testDingButton:SetPoint("TOPLEFT", checkboxGuild, "BOTTOMLEFT", 0, -20)
    testDingButton:SetText("Test Ding")
    testDingButton:SetSize(100, 25)
    testDingButton:SetScript("OnClick", function()
        local randomLevel = math.random(1, max_level)
        local randomIndex = math.random(1, #dingMessages)
        local messageTemplate = dingMessages[randomIndex]
        local message = string.format(messageTemplate, randomLevel)

        if sendToYell then
            SendChatMessage("Test Ding " .. randomLevel .. "! [Ding Classic]", "YELL", nil)
        end

        if sendToSay then
            SendChatMessage("Test Ding " .. randomLevel .. "! [Ding Classic]", "SAY", nil)
        end

        if sendToGuild and IsInGuild() then
            SendChatMessage("Test Ding " .. randomLevel .. "!", "GUILD", nil)
            SendChatMessage(message, "GUILD", nil)
        end
    end)

    InterfaceOptions_AddCategory(optionsPanel)
end

local function CreateTestDingButton()
    local testDingButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    testDingButton:SetPoint("CENTER", 0, 0)
    testDingButton:SetText("Test Ding")
    testDingButton:SetSize(100, 25)
    testDingButton:SetScript("OnClick", SendTestDing)
end

-- Event handler for the ding event
local DingClassic_EventFrame = CreateFrame("Frame")
DingClassic_EventFrame:RegisterEvent("PLAYER_LEVEL_UP")
DingClassic_EventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if (event == "PLAYER_LEVEL_UP") then
        local randomIndex = math.random(1, #dingMessages)
        local messageTemplate = dingMessages[randomIndex]
        local message = string.format(messageTemplate, arg1)

        if showDingMessages then
            print(message)
        end

        if sendToYell then
            SendChatMessage("Ding " .. arg1 .. "! " .. (max_level - arg1) .. " levels left until " .. max_level .. "! [Ding Classic]", "YELL", nil)
        end

        if sendToSay then
            SendChatMessage("Ding " .. arg1 .. "! " .. (max_level - arg1) .. " levels left until " .. max_level .. "! [Ding Classic]", "SAY", nil)
        end

        if sendToGuild and IsInGuild() then
            SendChatMessage("Ding " .. arg1 .. "!", "GUILD", nil)
            SendChatMessage(message, "GUILD", nil)
        end
    end
end)

-- Event handler for addon load
function DingClassic_OnLoad(self)
    self:RegisterEvent("ADDON_LOADED")
end

function DingClassic_OnEvent(self, event, ...)
    if (event == "ADDON_LOADED") then
        local addon = select(1, ...)
        if (addon == "DingClassic") then
            DEFAULT_CHAT_FRAME:AddMessage("Ding Classic " .. ding_version .. " loaded!")
        end
    end
end
InitializeOptionsPanel()