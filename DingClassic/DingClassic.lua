-- Debug mode function
local function DebugPrint(...)
    if DingClassicSettings and DingClassicSettings.debugMode then
        print(...)
    end
end

local addonName = "DingClassic"
local ding_version = "1.0.9"
local max_level = 60
local isAddonLoaded = false  -- Variable to track if the addon has been loaded
local pendingMessages = {}
local lastLevel = 0

-- Function to set max level based on game version
local function SetMaxLevel()
    max_level = GetMaxLevelForExpansionLevel(GetExpansionLevel())
end


-- Function to initialize the settings
local function InitializeSettings()
    if not DingClassicSavedSettings then
        -- Initialize the saved settings for the first time
        DingClassicSavedSettings = {
            showDingMessages = true,
            sendToSay = true,
            sendToGuild = true,
            messageSent = {},
            selectedMessagePool = "Default",
            debugMode = false,
            lastLevel = 1, -- Default to level 1
        }
        DebugPrint("[INFO] Settings initialized for the first time. Default lastLevel set to 1.")
    end

    -- Load the saved settings
    DingClassicSettings = DingClassicSavedSettings

    -- Ensure lastLevel is correctly initialized
    if not DingClassicSettings.lastLevel or DingClassicSettings.lastLevel > UnitLevel("player") then
        DingClassicSettings.lastLevel = UnitLevel("player")
        DebugPrint("[INFO] lastLevel corrected to current player level:", UnitLevel("player"))
    end

    lastLevel = DingClassicSettings.lastLevel -- Load saved last level
    DebugPrint("[INFO] Settings loaded. lastLevel set to:", lastLevel)
end

local messagePoolDescriptions = {
    Default = "The default pool of ding messages.",
    WoWHardCore = "Hardcore-themed ding messages for the ultimate leveling experience.",
    WoWFunny = "Funny and lighthearted ding messages for a good laugh while leveling.",
    WoWLore = "Discover bite-sized tales, lore snippets, and legendary quotes from the vast world of Azeroth.",
    WoWSuperFunny = "Happy leveling and laughing in your WoW adventures!",
}

-- Define arrays of different ding messages
local messagePools = {
    Default = {
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
    },
    WoWHardCore = {
        "Ding! Level %d! I've ascended to a new tier of gaming greatness.",
        "Ding! Level %d! I don't always level up, but when I do, it's hardcore.",
        "Ding! Level %d! I eat mobs for breakfast, and leveling up for dessert.",
        "Ding! Level %d! My keyboard fears me and my leveling prowess.",
        "Ding! Level %d! I measure success in levels, and I'm a level millionaire now.",
        "Ding! Level %d! I level up so fast, the game developers send me thank you cards.",
        "Ding! Level %d! I'd say I'm addicted, but that's an understatement.",
        "Ding! Level %d! My character is a max-level beast with legendary gear.",
        "Ding! Level %d! If leveling up was an Olympic sport, I'd be a gold medalist.",
        "Ding! Level %d! My character is the stuff of legends, literally.",
        "Ding! Level %d! I've leveled up so much, even the NPCs ask for my autograph.",
        "Ding! Level %d! I've conquered more dungeons than I have life responsibilities.",
        "Ding! Level %d! I'm the hero Azeroth deserves, and the one it needs right now.",
        "Ding! Level %d! My character is maxed out, and so is my dedication.",
        "Ding! Level %d! My character has leveled up more times than I've said 'for the Horde!'",
        "Ding! Level %d! My character is so hardcore, even Deathwing gives me a high-five.",
        "Ding! Level %d! I've grinded more mobs than I can count.",
        "Ding! Level %d! I've seen things. Terrible, terrible things in Azeroth.",
        "Ding! Level %d! My character is so maxed out, even Khadgar asks for advice.",
        "Ding! Level %d! My character is max level, and my life is max Azeroth.",
        "Ding! Level %d! I've leveled up so much, I should get an honorary degree in leveling.",
        "Ding! Level %d! My character is the living embodiment of 'No life, only leveling.'",
        "Ding! Level %d! I've spent more time in dungeons than I have in daylight.",
        "Ding! Level %d! My character is so hardcore, they punch Deathwing in the face.",
        "Ding! Level %d! My character has achieved levels beyond mortal comprehension.",
        "Ding! Level %d! I've leveled up so much, my character has a fan club.",
        "Ding! Level %d! My character is so legendary, even Illidan takes notes.",
        "Ding! Level %d! I've leveled up more times than I've had hot meals.",
        "Ding! Level %d! My character is max level, max gear, max awesome.",
        "Ding! Level %d! My character is so buffed, even the Lich King is impressed.",
        "Ding! Level %d! My character is so hardcore, they PvP with their eyes closed.",
        "Ding! Level %d! My character is max level, and I'm max addicted.",
        "Ding! Level %d! I've leveled up so much, even the Old Gods fear me.",
        "Ding! Level %d! My character is so epic, they solo raids for fun.",
        "Ding! Level %d! My character is so hardcore, they dual-wield legendary weapons.",
        "Ding! Level %d! My character has leveled up more times than I've blinked.",
        "Ding! Level %d! I've grinded so hard, my coffee machine is my best friend.",
        "Ding! Level %d! My character is so maxed out, they have their own theme music.",
        "Ding! Level %d! My character is so legendary, even Sargeras is taking notes.",
        "Ding! Level %d! My character is max level, max stats, max dedication.",
        "Ding! Level %d! My character is so hardcore, even Ragnaros calls me 'The Firelord'.",
        "Ding! Level %d! My character has leveled up so much, I should get an achievement for it.",
        "Ding! Level %d! My character is max level, and I'm max in-game hours.",
        "Ding! Level %d! My character is so epic, they defeated the Loading Screen Boss.",
        "Ding! Level %d! My character is so hardcore, they level up while sleeping.",
        "Ding! Level %d! My character is max level, and I've maxed out my keyboard.",
        "Ding! Level %d! My character is so legendary, even Arthas calls for my aid.",
        "Ding! Level %d! My character is so maxed out, even Khadgar asks for selfies.",
        "Ding! Level %d! My character is so hardcore, even Deathwing runs away.",
        "Ding! Level %d! My character is max level, and I've maxed out my social life.",
        "Ding! Level %d! My character is so legendary, they have their own holiday in Azeroth.",
        "Ding! Level %d! My character is so hardcore, they don't level up, levels level them.",
        "Ding! Level %d! My character is max level, and my life is max dungeons.",
        "Ding! Level %d! My character is so epic, they solo raid bosses with one hand.",
        "Ding! Level %d! My character is so hardcore, they have a 'Noob Slayer' title.",
        "Ding! Level %d! My character is max level, max gear, and max raiding.",
        "Ding! Level %d! My character is so legendary, they have a legendary cereal named after them.",
        "Ding! Level %d! My character is so hardcore, they PvP blindfolded and still win.",
        "Ding! Level %d! My character is max level, and my real-life XP is lacking.",
        "Ding! Level %d! My character is so legendary, even Thrall asks for advice.",
    },
    WoWFunny = {
        "Ding! Level %d! My character now qualifies for the 'Azeroth's Next Top Model' competition.",
        "Ding! Level %d! I've leveled up so much, I think I now have a PhD in 'Clicking Random Buttons'.",
        "Ding! Level %d! I've leveled up more times than I've blinked today.",
        "Ding! Level %d! My character is now so legendary, they autograph other player's gear.",
        "Ding! Level %d! I've spent more time leveling than I have at family gatherings... oops!",
        "Ding! Level %d! My character's leveling speed is faster than my Wi-Fi... on a good day.",
        "Ding! Level %d! I'm not addicted, I'm just committed to maxing out my character's awesomeness.",
        "Ding! Level %d! My character is now so epic, they defeat bosses in a rock-paper-scissors game.",
        "Ding! Level %d! I've leveled up so much, even the NPCs call me 'boss'.",
        "Ding! Level %d! My character is now maxed out in levels and bad jokes.",
        "Ding! Level %d! My character is now so good, even the game developers ask for tips.",
        "Ding! Level %d! My character is leveling up faster than my pet cat chasing a laser.",
        "Ding! Level %d! My character is so legendary, they've been nominated for 'Character of the Year'.",
        "Ding! Level %d! My character's leveling speed is faster than a mage trying to conjure snacks.",
        "Ding! Level %d! My character has leveled up so much, they're considering retirement in Dalaran.",
        "Ding! Level %d! My character is now so buffed, even the NPCs ask for workout tips.",
        "Ding! Level %d! I've leveled up more times than I've seen the sun this week.",
        "Ding! Level %d! My character is now so epic, they have their own fan club in Stormwind.",
        "Ding! Level %d! My character is leveling up faster than I can find matching socks.",
        "Ding! Level %d! My character is so powerful, they defeat monsters with a stern look.",
        "Ding! Level %d! My character's leveling speed is faster than a murloc running from a raid group.",
        "Ding! Level %d! My character is now so legendary, they have a constellation named after them.",
        "Ding! Level %d! My character has gained more levels than I've had cups of coffee today.",
        "Ding! Level %d! My character is so maxed out, they can solo a raid while doing the Macarena.",
        "Ding! Level %d! My character is now so epic, even the Lich King wants their autograph.",
        "Ding! Level %d! My character's leveling speed is faster than a mage teleporting to Ironforge.",
        "Ding! Level %d! My character is so good, even the Loading Screen Tips are impressed.",
        "Ding! Level %d! My character has leveled up so much, they're considering starting a 'Levelers Anonymous' group.",
        "Ding! Level %d! My character is so legendary, they have a theme song composed in their honor.",
        "Ding! Level %d! My character's leveling speed is faster than a rogue pickpocketing in a crowded Stormwind.",
        "Ding! Level %d! My character is so buffed, they could flex the Exodar into orbit.",
        "Ding! Level %d! My character has more levels than a multi-story gnome engineering project.",
        "Ding! Level %d! My character's leveling speed is faster than a druid shifting forms.",
        "Ding! Level %d! My character is now so epic, even the NPCs roll out the red carpet.",
        "Ding! Level %d! My character's leveling speed is faster than a warlock summoning a demon.",
        "Ding! Level %d! My character is so legendary, even Illidan is taking notes.",
        "Ding! Level %d! My character is now so maxed out, they can solo a raid with a blindfold on.",
        "Ding! Level %d! My character has gained more levels than I have gold... and that's saying something.",
        "Ding! Level %d! My character is so good, even the bosses need a strategy guide to beat them.",
        "Ding! Level %d! My character's leveling speed is faster than a mage portal network.",
        "Ding! Level %d! My character is so legendary, they've been offered a spot in the 'Epic Hall of Fame'.",
        "Ding! Level %d! My character has more levels than a tower of stacked gnomes.",
        "Ding! Level %d! My character is so buffed, they can do push-ups with an ogre on their back.",
        "Ding! Level %d! My character is now so epic, they have their own theme music when they walk.",
        "Ding! Level %d! My character's leveling speed is faster than a gnome with a rocket pack.",
        "Ding! Level %d! My character is so legendary, even Ragnaros is jealous of their fiery attitude.",
        "Ding! Level %d! My character is now max level, max coolness, and max procrastination.",
        "Ding! Level %d! My character is so good, they've been asked to write a 'Leveling for Dummies' book.",
        "Ding! Level %d! My character's leveling speed is faster than a paladin charging into battle.",
        "Ding! Level %d! My character is so legendary, even the Titans ask for advice.",
        "Ding! Level %d! My character is now so buffed, they can lift Mjolnir with one finger.",
        "Ding! Level %d! My character has gained more levels than I've had epic drops.",
        "Ding! Level %d! My character is so good, even Deathwing bowed down in respect.",
        "Ding! Level %d! My character's leveling speed is faster than a rogue pickpocketing at a trade fair.",
        "Ding! Level %d! My character is so legendary, they have a fan club in Darnassus.",
        "Ding! Level %d! My character has gained more levels than I've had Mage conjured pastries.",
        "Ding! Level %d! My character is now so maxed out, they can bench press Orgrimmar.",
        "Ding! Level %d! My character is so good, even the bosses beg for mercy.",
        "Ding! Level %d! My character's leveling speed is faster than a gnome tinkering with explosives.",
        "Ding! Level %d! My character is now so legendary, even the loading screen admires them.",
    },
    WoWLore = {
        "Ding! Level %d! Just like Thrall, I've risen from the ashes to face the challenges of Azeroth!",
        "Ding! Level %d! I'm channeling my inner Arthas as I march towards max level and beyond.",
        "Ding! Level %d! Like Jaina, I'll stand proud and strong as I progress through Azeroth's trials.",
        "Ding! Level %d! My journey echoes the lore of Illidan Stormrage, embracing power and sacrifice.",
        "Ding! Level %d! I feel the spirit of Uther the Lightbringer guiding me on this path of leveling.",
        "Ding! Level %d! Just like Sylvanas, I'm making my mark in this world, one level at a time.",
        "Ding! Level %d! Much like Malfurion Stormrage, I'm attuned to the natural flow of leveling.",
        "Ding! Level %d! My leveling journey mirrors the rise of the noble Cairne Bloodhoof.",
        "Ding! Level %d! My determination rivals that of Grom Hellscream, charging into the levels ahead.",
        "Ding! Level %d! As a true disciple of the Light, I'm leveling up with the grace of Turalyon.",
        "Ding! Level %d! Like the defiant Varian Wrynn, I stand steadfast in my leveling journey.",
        "Ding! Level %d! My determination matches that of Maiev Shadowsong as I progress in levels.",
        "Ding! Level %d! Much like Khadgar, I seek knowledge and power in the form of leveling up.",
        "Ding! Level %d! My leveling path is reminiscent of the heroic deeds of Anduin Lothar.",
        "Ding! Level %d! Embracing the fire within, I level up with the spirit of Ragnaros.",
        "Ding! Level %d! My leveling journey is a saga worthy of the high chieftain Vol'jin.",
        "Ding! Level %d! Just like the cunning Gul'dan, I'm mastering the levels through intellect and strategy.",
        "Ding! Level %d! I feel the pulse of the Emerald Dream as I level up, much like Ysera.",
        "Ding! Level %d! My leveling journey is a reflection of the fierce warrior Saurfang the Younger.",
        "Ding! Level %d! My leveling path is as legendary as the ancient dragon, Alexstrasza.",
        "Ding! Level %d! I channel the spirit of Jaina Proudmoore as I navigate the levels of Azeroth.",
        "Ding! Level %d! My leveling journey echoes the wisdom of the Prophet Velen.",
        "Ding! Level %d! Just like the legendary Deathwing, I'm causing tremors in the leveling world.",
        "Ding! Level %d! My journey through Azeroth's levels mirrors the vengeance of Akama.",
        "Ding! Level %d! Like Cenarius, I guide my path through leveling with nature's grace.",
        "Ding! Level %d! My leveling adventure is as daring as the deeds of Tirion Fordring.",
        "Ding! Level %d! My leveling journey is a reflection of the resilience of Genn Greymane.",
        "Ding! Level %d! My determination is akin to the bravery of Varok Saurfang.",
        "Ding! Level %d! Like the wise Chen Stormstout, I'm leveling up with jovial determination.",
        "Ding! Level %d! My path through the levels is as iconic as the legendary Medivh.",
        "Ding! Level %d! My leveling journey is a tribute to the legacy of Archmage Antonidas.",
        "Ding! Level %d! My leveling adventure is as enigmatic as the whispers of N'Zoth.",
        "Ding! Level %d! My leveling path mirrors the strategic prowess of Khadgar.",
        "Ding! Level %d! My journey echoes the resilience of the Earthen Ring.",
        "Ding! Level %d! I level up with the wisdom of the mighty Archimonde.",
        "Ding! Level %d! My leveling adventure is a testament to the grit of the Warchief.",
        "Ding! Level %d! I channel the essence of the Dragon Aspects in my leveling journey.",
        "Ding! Level %d! My leveling journey is as fierce as the determination of Grommash Hellscream.",
        "Ding! Level %d! My leveling path is akin to the strength of Cairne Bloodhoof.",
        "Ding! Level %d! Like the legendary Aegwynn, I wield the arcane to level up.",
        "Ding! Level %d! My journey mirrors the might of the ancient Thunderaan, Prince of Air.",
        "Ding! Level %d! My leveling adventure is as legendary as the story of the Ashbringer.",
        "Ding! Level %d! I'm leveling up with the tenacity of the mighty Thoradin.",
        "Ding! Level %d! My path through the levels echoes the lore of the Scarlet Crusade.",
        "Ding! Level %d! My leveling journey is as bold as the tale of The Dark Portal.",
        "Ding! Level %d! I channel the wisdom of the ancients, much like Fandral Staghelm.",
        "Ding! Level %d! Like the resilient Kalecgos, I rise and conquer the levels.",
        "Ding! Level %d! My leveling journey is a tribute to the honor of the Kaldorei.",
        "Ding! Level %d! My leveling adventure mirrors the strength of the mighty Turalyon.",
        "Ding! Level %d! My path through the levels is as noble as the story of Aegwynn.",
        "Ding! Level %d! Like the cunning Blackhand, I dominate the leveling world.",
        "Ding! Level %d! I'm leveling up with the zeal of the Scarlet Crusade.",
        "Ding! Level %d! My leveling journey echoes the legendary tales of the Titans.",
        "Ding! Level %d! My adventure is as mysterious as the whispers of the Old Gods.",
        "Ding! Level %d! My leveling path is as bold as the mighty Khaz'goroth.",
        "Ding! Level %d! My journey is akin to the tales of the legendary Lo'Gosh.",
        "Ding! Level %d! My leveling adventure mirrors the legendary tales of the Titans.",
        "Ding! Level %d! My path through the levels is as enigmatic as the history of Elune.",
        "Ding! Level %d! I'm leveling up with the resilience of the legendary Gnomeregan.",
        "Ding! Level %d! My leveling journey is as legendary as the ancient Tirisfal Glades.",
    },
    WoWSuperFunny = {
        "Ding! Level %d! My mom is so proud, she's putting it on the fridge!",
        "Ding! Level %d! I'd like to thank my guild, my pet cat, and my mom's basement.",
        "Ding! Level %d! I'm not addicted, I'm just... well, maybe a little.",
        "Ding! Level %d! My character is now eligible for 'Azeroth's Next Top Model.'",
        "Ding! Level %d! I've leveled up so much, my /played time has a Ph.D.",
        "Ding! Level %d! Even Hogger is afraid of my leveling skills.",
        "Ding! Level %d! My character is now maxed out in 'Dingology.'",
        "Ding! Level %d! I think my character just wrote a bestseller, 'Leveling for Dummies.'",
        "Ding! Level %d! My character has more levels than I have gold... and that's saying something.",
        "Ding! Level %d! My character is so epic, even the Murlocs fear them.",
        "Ding! Level %d! My character is now so legendary, they have a fan club in Orgrimmar.",
        "Ding! Level %d! I've leveled up so much, I've lost count... literally.",
        "Ding! Level %d! I think I just out-leveled Deathwing's temper.",
        "Ding! Level %d! My character's leveling speed is faster than a gnome on a rocket.",
        "Ding! Level %d! My character is so powerful, they defeat mobs by glaring at them.",
        "Ding! Level %d! I've spent more time leveling than I have sleeping.",
        "Ding! Level %d! My character's leveling speed is faster than a warlock summoning a demon.",
        "Ding! Level %d! I think my character needs a level-up intervention.",
        "Ding! Level %d! My character is so maxed out, even Ragnaros wants tips.",
        "Ding! Level %d! My character is so buffed, they can one-shot a murloc with a finger poke.",
        "Ding! Level %d! I've leveled up more times than I've had hot dinners.",
        "Ding! Level %d! My character's leveling speed is faster than a rogue trying to stealth.",
        "Ding! Level %d! I'd like to thank the pizza delivery guy for fueling this leveling marathon.",
        "Ding! Level %d! My character is now max level and ready to tackle... more leveling.",
        "Ding! Level %d! I've leveled up so much, I've forgotten what sunlight looks like.",
        "Ding! Level %d! My character is so legendary, even the NPCs ask for selfies.",
        "Ding! Level %d! My character's leveling speed is faster than a druid in cheetah form.",
        "Ding! Level %d! I've leveled up so much, even my pet boar is impressed.",
        "Ding! Level %d! My character is so buffed, they can take on the Lich King... in their sleep.",
        "Ding! Level %d! I've leveled up so much, I think my character is considering retirement in Dalaran.",
        "Ding! Level %d! My character is so good, even Illidan is taking notes.",
        "Ding! Level %d! I think I've leveled up more times than I've heard 'Leroy Jenkins'.",
        "Ding! Level %d! My character is now so epic, they have their own theme music.",
        "Ding! Level %d! I've leveled up so much, my character is planning to open a leveling school.",
        "Ding! Level %d! My character is so maxed out, even the dragons are applying for leveling tips.",
        "Ding! Level %d! My character is so legendary, they have a legendary cereal named after them.",
        "Ding! Level %d! I think my character has a level-up addiction, and I'm an enabler.",
        "Ding! Level %d! My character's leveling speed is faster than a gnome with a jetpack.",
        "Ding! Level %d! I've leveled up so much, I'm considering writing a 'Leveling for Dummies' book.",
        "Ding! Level %d! My character is so good, even Deathwing bowed down in respect.",
        "Ding! Level %d! My character's leveling speed is faster than a rogue looting in a crowded city.",
        "Ding! Level %d! I've leveled up more times than I've lost in PvP... and that's saying something.",
        "Ding! Level %d! My character is so buffed, even the NPCs ask for workout tips.",
        "Ding! Level %d! I've leveled up so much, my character's XP bar has its own gravitational pull.",
        "Ding! Level %d! My character is so legendary, even Ragnaros wants their autograph.",
        "Ding! Level %d! I think my character's leveling speed broke the sound barrier.",
        "Ding! Level %d! My character is so good, they've been asked to write a 'Leveling for Dummies' book.",
        "Ding! Level %d! My character is so maxed out, even the Loading Screen Tips are impressed.",
        "Ding! Level %d! I've leveled up so much, even the bosses are planning a congratulatory party.",
        "Ding! Level %d! My character is now so powerful, they defeat monsters with a stern look.",
        "Ding! Level %d! My character is so legendary, they have their own sitcom in Gadgetzan.",
        "Ding! Level %d! My character is so epic, even the Titans are taking notice.",
        "Ding! Level %d! I've leveled up so much, even the game developers are asking for my secrets.",
        "Ding! Level %d! My character is so maxed out, they can solo a raid while juggling gnome plushies.",
        "Ding! Level %d! My character is so good, they've been asked to teach a 'Leveling 101' class.",
        "Ding! Level %d! My character is now so epic, they defeat raid bosses with sarcastic remarks.",
        "Ding! Level %d! My character's leveling speed is faster than a warlock summoning imp.",
        "Ding! Level %d! My character is so legendary, they've been nominated for a Nobel Prize in Levelology.",
        "Ding! Level %d! My character is now max level, max coolness, and max procrastination.",
        "Ding! Level %d! My character is so legendary, even the loading screen worships them.",
    },
}

local DingClassicFrame = CreateFrame("Frame")
local sendingMessages = false

-- Function to queue a message
local function QueueMessage(message)
    if #pendingMessages > 10 then
        DebugPrint("[WARNING] Too many messages queued! Check your logic.")
    end
    table.insert(pendingMessages, message)
    DingClassicFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- Function to send a random message
local function SendRandomMessage()
    local selectedPool = messagePools[DingClassicSettings.selectedMessagePool]
    if selectedPool then
        local numMessages = #selectedPool
        if numMessages > 0 then
            local randomIndex = math.random(1, numMessages)
            local message = selectedPool[randomIndex]
            local level = UnitLevel("player")
            message = string.format(message, level)

            if InCombatLockdown() then
                QueueMessage(message)
            else
                if DingClassicSettings.sendToSay then
                    SendChatMessage(message, "SAY")
                end
                if DingClassicSettings.sendToGuild then
                    SendChatMessage(message, "GUILD")
                end
            end
        else
            print("No messages found in the selected pool.")
        end
    else
        print("Selected message pool not found.")
    end
end

-- Function to send queued messages when combat ends
local function SendQueuedMessages()
    if not InCombatLockdown() and not sendingMessages then
        sendingMessages = true
        local co = coroutine.create(function()
            for _, message in ipairs(pendingMessages) do
                if DingClassicSettings.sendToSay then
                    SendChatMessage(message, "SAY")
                    coroutine.yield()
                end
                if DingClassicSettings.sendToGuild then
                    SendChatMessage(message, "GUILD")
                    coroutine.yield()
                end
            end
            wipe(pendingMessages)
            sendingMessages = false
        end)
        C_Timer.NewTicker(0.1, function()
            if coroutine.status(co) == "dead" then
                return
            end
            coroutine.resume(co)
        end, #pendingMessages * 2)
    end
end

-- Function to check for level-up
local function CheckForLevelUp()
    local currentLevel = UnitLevel("player")
    DebugPrint("[INFO] CheckForLevelUp called. Current Level:", currentLevel, "Last Level:", lastLevel)

    if currentLevel == lastLevel then
        DebugPrint("[INFO] No new level detected. Skipping check.")
        return
    end

    -- Only proceed if a message hasn't been sent for this level
    if not DingClassicSettings.messageSent[currentLevel] then
        DebugPrint("[INFO] New level detected. Sending message for Level:", currentLevel)
        SendRandomMessage()
        DingClassicSettings.messageSent[currentLevel] = true
        lastLevel = currentLevel
        DingClassicSettings.lastLevel = currentLevel
        DebugPrint("[INFO] Message sent. Updated Last Level to:", currentLevel)
    else
        DebugPrint("[INFO] Message already sent for Level:", currentLevel)
        lastLevel = currentLevel
        DingClassicSettings.lastLevel = currentLevel
    end
end


local xpUpdateThrottle = false

local function OnPlayerXPUpdate()
    if xpUpdateThrottle then
        DebugPrint("[INFO] PLAYER_XP_UPDATE skipped due to throttle.")
        return
    end

    xpUpdateThrottle = true
    DebugPrint("[INFO] PLAYER_XP_UPDATE triggered. Checking for level-up.")

    C_Timer.After(0.5, function()
        CheckForLevelUp()
        xpUpdateThrottle = false
    end)
end

local function OnPlayerLevelUp(self, event, newLevel)
    DebugPrint("[INFO] PLAYER_LEVEL_UP triggered. New Level:", newLevel)

    if newLevel > lastLevel then
        -- Delay handling to ensure other events (e.g., quest turn-in) are processed
        C_Timer.After(0.1, function()
            if not DingClassicSettings.messageSent[newLevel] then
                DebugPrint("[INFO] Sending level-up message for Level:", newLevel)
                SendRandomMessage()
                DingClassicSettings.messageSent[newLevel] = true
            else
                DebugPrint("[INFO] Message already sent for Level:", newLevel)
            end
            lastLevel = newLevel
            DingClassicSettings.lastLevel = newLevel
            DebugPrint("[INFO] Updated lastLevel to:", newLevel)
        end)
    else
        DebugPrint("[WARNING] PLAYER_LEVEL_UP triggered, but newLevel <= lastLevel. Skipping.")
    end
end

-- Function to handle quest turn-in
local function OnQuestTurnIn(self, event, questID, xpReward, moneyReward)
    DebugPrint("[INFO] QUEST_TURNED_IN triggered. QuestID:", questID, "XP Reward:", xpReward, "Money Reward:", moneyReward)

    C_Timer.After(0.5, function()
        local currentLevel = UnitLevel("player")
        if currentLevel > lastLevel then
            DebugPrint("[INFO] Level-up detected during quest turn-in. Current Level:", currentLevel)
            CheckForLevelUp() -- Ensure only one message is sent
        else
            DebugPrint("[INFO] No level-up detected during quest turn-in.")
        end
    end)
end



local lastCheckTimestamp = 0

-- Function to throttle level-up checks
local function ThrottledCheckForLevelUp()
    local now = GetTime()
    if now - lastCheckTimestamp > 0.5 then -- Only allow a check every 0.5 seconds
        lastCheckTimestamp = now
        CheckForLevelUp()
    end
end

-- Main event handler
DingClassicFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LEVEL_UP" then
        OnPlayerLevelUp(self, event, ...)
    elseif event == "PLAYER_XP_UPDATE" then
        OnPlayerXPUpdate()
    elseif event == "QUEST_TURNED_IN" then
        OnQuestTurnIn(self, event, ...)
    end
end)

-- Ensure PLAYER_LEVEL_UP is registered and prioritized
DingClassicFrame:RegisterEvent("PLAYER_LEVEL_UP")
DingClassicFrame:RegisterEvent("PLAYER_XP_UPDATE")
DingClassicFrame:RegisterEvent("QUEST_TURNED_IN")

local function SaveDingClassicSettings()
    DingClassicSavedSettings = DingClassicSettings
end

local saveButton -- Declare the saveButton at the top
local testButton -- Declare the testButton at the top

local function InitializeOptionsPanel()
    if optionsPanelInitialized then
        return
    end

    -- Create the options panel
    local optionsPanel = CreateFrame("Frame", "DingClassicOptionsPanel", UIParent)
    optionsPanel.name = "Ding Classic"

    -- Add panel title
    local title = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ding Classic Settings")

    -- Dropdown for message pools
    local dropdown = CreateFrame("Frame", "DingClassicDropdown", optionsPanel, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    UIDropDownMenu_SetWidth(dropdown, 160)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for poolName, poolDescription in pairs(messagePoolDescriptions) do
            info.text = poolName
            info.checked = DingClassicSettings.selectedMessagePool == poolName
            info.func = function(self)
                DingClassicSettings.selectedMessagePool = self.value
                UIDropDownMenu_SetText(dropdown, self:GetText())
            end
            info.value = poolName
            info.tooltipTitle = poolName
            info.tooltipText = poolDescription
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetSelectedValue(dropdown, DingClassicSettings.selectedMessagePool)
    UIDropDownMenu_SetText(dropdown, DingClassicSettings.selectedMessagePool)

    -- Checkbox: Enable Ding Messages
    local checkbox = CreateFrame("CheckButton", "$parentCheckbox", optionsPanel, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -16)
    checkbox.Text:SetText("Enable Ding Messages")
    checkbox:SetChecked(DingClassicSettings.showDingMessages)
    checkbox:SetScript("OnClick", function(self)
        DingClassicSettings.showDingMessages = self:GetChecked()
    end)

    -- Checkbox: Send to Say
    local checkboxSay = CreateFrame("CheckButton", "$parentCheckboxSay", optionsPanel, "UICheckButtonTemplate")
    checkboxSay:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 0, -16)
    checkboxSay.Text:SetText("Send to Say")
    checkboxSay:SetChecked(DingClassicSettings.sendToSay)
    checkboxSay:SetScript("OnClick", function(self)
        DingClassicSettings.sendToSay = self:GetChecked()
    end)

    -- Checkbox: Send to Guild
    local checkboxGuild = CreateFrame("CheckButton", "$parentCheckboxGuild", optionsPanel, "UICheckButtonTemplate")
    checkboxGuild:SetPoint("TOPLEFT", checkboxSay, "BOTTOMLEFT", 0, -16)
    checkboxGuild.Text:SetText("Send to Guild")
    checkboxGuild:SetChecked(DingClassicSettings.sendToGuild)
    checkboxGuild:SetScript("OnClick", function(self)
        DingClassicSettings.sendToGuild = self:GetChecked()
    end)

    -- Checkbox: Enable Debug Mode
    local checkboxDebug = CreateFrame("CheckButton", "$parentCheckboxDebug", optionsPanel, "UICheckButtonTemplate")
    checkboxDebug:SetPoint("TOPLEFT", checkboxGuild, "BOTTOMLEFT", 0, -16)
    checkboxDebug.Text:SetText("Enable Debug Mode")
    checkboxDebug:SetChecked(DingClassicSettings.debugMode)
    checkboxDebug:SetScript("OnClick", function(self)
        DingClassicSettings.debugMode = self:GetChecked()
        DebugPrint("Debug mode", DingClassicSettings.debugMode and "enabled" or "disabled")
    end)

    -- Save Settings Button
    saveButton = CreateFrame("Button", "$parentSaveButton", optionsPanel, "UIPanelButtonTemplate")
    saveButton:SetText("Save Settings")
    saveButton:SetPoint("TOPLEFT", checkboxDebug, "BOTTOMLEFT", 0, -16)
    saveButton:SetSize(120, 25)
    saveButton:SetScript("OnClick", function()
        SaveDingClassicSettings()
    end)

    -- Send Random Message Button
    testButton = CreateFrame("Button", "$parentTestButton", optionsPanel, "UIPanelButtonTemplate")
    testButton:SetText("Send Random Message")
    testButton:SetPoint("TOPLEFT", saveButton, "BOTTOMLEFT", 0, -10)
    testButton:SetSize(160, 25)
    testButton:SetScript("OnClick", function()
        SendRandomMessage()
    end)

    -- Register the panel with the new settings API
    local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "Ding Classic")
    Settings.RegisterAddOnCategory(category)

    optionsPanelInitialized = true
end


local function InitializeLastLevel()
    print(addonName .. " initialized.")
end

local function LoadDingClassic()
    if not isAddonLoaded then
        InitializeSettings()
        SetMaxLevel()
--        InitializeLastLevel()
        InitializeOptionsPanel()
        isAddonLoaded = true
    end
end

local function OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        LoadDingClassic()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnEvent)

SLASH_DINGCLASSIC1 = "/dingclassic"
SLASH_DINGCLASSIC2 = "/ding"
SLASH_DINGCLASSIC3 = "/dc"

local function OpenDingClassicOptions()
    Settings.OpenToCategory("Ding Classic")
end

SlashCmdList["DINGCLASSIC"] = OpenDingClassicOptions
SlashCmdList["DING"] = OpenDingClassicOptions
SlashCmdList["dc"] = OpenDingClassicOptions