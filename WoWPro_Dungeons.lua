-------------------------------
--      WoWPro_Dungeons      --
-------------------------------

local L = WoWPro_Locale
local myUFG = UnitFactionGroup("player")

WoWPro.Dungeons = WoWPro:NewModule("Dungeons")

--function WoWPro.Dungeons:OnInitialize()
--end

WoWPro.Dungeons.EventList = {
		"QUEST_LOG_UPDATE", "QUEST_COMPLETE", "QUEST_QUERY_COMPLETE", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
		"MINIMAP_ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "UI_INFO_MESSAGE", "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT",
		"UPDATE_MOUSEOVER_UNIT",
	}

function WoWPro.Dungeons:OnEnable()

	WoWPro:dbp("|cff33ff33Enabled|r: Dungeons Module")
	
	WoWPro:RegisterTags({"QID", "questtext", "prereq", "noncombat", "leadin", "mode",
			     "prof", "race", "class", "role", "minlevel", "ghost", }) -- mode: normal or heroic
	
	WoWPro:RegisterEvents(WoWPro.Dungeons.EventList)
	
	--Loading Frames--
	if not WoWPro.Dungeons.FramesLoaded then --First time the addon has been enabled since UI Load
		WoWPro.Dungeons:CreateConfig()
		WoWPro.Dungeons.FramesLoaded = true
	end

	-- Creating empty user settings if none exist
	WoWPro.Dungeons.db = WoWPro.Dungeons.db or {}
	WoWPro.Dungeons.db.guide = WoWPro.Dungeons.db.guide or {}
	-- TODO: revise next 2 lines later
	WoWPro.Dungeons.completedQIDs = WoWPro_LevelingDB.completedQIDs or {}
	WoWPro.Dungeons.skippedQIDs = WoWPro_LevelingDB.skippedQIDs or {}
	
	if WoWPro.Dungeons.db.lastguide and not WoWProDB.char.currentguide then
		WoWPro:LoadGuide(WoWPro.Dungeons.db.lastguide)
	end
	
	WoWPro.Dungeons.FirstMapCall = true
	
	-- Server query for completed quests --
	-- TODO: Move this elsewhere?
	QueryQuestsCompleted()
end

function WoWPro.Dungeons:OnDisable()
	-- Unregistering Leveling Module Events --
	for _, event in pairs (WoWPro.Dungeons.EventList) do
		WoWPro.GuideFrame:UnregisterEvent(event)
	end
	
	WoWPro:RemoveMapPoint()
	WoWPro.Dungeons.db.lastguide = WoWProDB.char.currentguide
	WoWProDB.char.currentguide = nil
	WoWPro:LoadGuide()
end

-- WoWPro.Dungeons:RegisterGuide("GuideID", "Dungeon", "Subtype", "Author", "Zone", "NextGuideID", "Faction", function()
-- Guide Registration Function --
function WoWPro.Dungeons:RegisterGuide(GIDvalue, dungeonname, guidesubtypename, authorname, zonename, nextGIDvalue, factionname, sequencevalue)
	if factionname and factionname ~= myUFG and factionname ~= "Neutral" then return end
	WoWPro:dbp("Guide Registered: "..GIDvalue)
	WoWPro.Guides[GIDvalue] = {
		guidetype = "Dungeons",
		guidesubtype = guidesubtypename,
		dungeon = dungeonname,
		author = authorname,
		zone = zonename or dungeonname,
		nextGID = nextGIDvalue,
		sequence = sequencevalue,
	}
end
