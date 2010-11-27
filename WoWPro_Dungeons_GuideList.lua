-- WoWPro.Dungeons.actionlabels = {
	-- A = "Accept",
	-- C = "Complete",
	-- T = "Turn in",
	-- K = "Kill",
	-- R = "Run to",
	-- H = "Hearth to",
	-- h = "Set hearth to",
	-- F = "Fly to",
	-- f = "Get flight path for",
	-- N = "Note:",
	-- B = "Buy",
	-- b = "Boat or Zeppelin",
	-- U = "Use",
	-- L = "Level",
	-- l = "Loot",
	-- r = "Repair/Restock"
-- }

---------------------------------------------
--      WoWPro_Dungeons_GuideList.lua      --
---------------------------------------------

local L = WoWPro_Locale
local ROWHEIGHT, GAP, EDGEGAP = 17, 8, 16
local rows = {}
local NUMROWS = 17

local tinsert = table.insert

local sorttype
local tsort = table.sort

local EXPANSION_LEVEL = GetExpansionLevel();
local TYPEID_DUNGEON = 1;
local TYPEID_HEROIC_DIFFICULTY = 5;
--local wprint = WoWPro:Print
local DungeonInfo = GetLFGDungeonInfo

local function CreateSubTypeList()
	if WoWPro.Dungeons.SubTypeList then return end
	local list = {}
	tinsert(list, { subtype = "location", label = L["Location"],
					texture = "Interface\\MINIMAP\\ROTATING-MINIMAPGUIDEARROW", 
					actions = {"R", },
					tags = { "action", "step", "note", "index", "map", "sticky", 
							"unsticky", "use", "zone", "lootitem", "lootqty", "optional", 
							"level", "target", "prof", "rep", "waypcomplete", "rank",  }
					})
					
	tinsert(list, { subtype = "questlist", label = L["Quest List"],
					texture = "Interface\\GossipFrame\\AvailableQuestIcon", 
					actions = {"A", "C", "T", },
					tags = { "action", "step", "note", "index", "map", "sticky", 
							"unsticky", "use", "zone", "lootitem", "lootqty", "optional", 
							"level", "target", "prof", "rep", "waypcomplete", "rank",  }
					})
					
	tinsert(list, { subtype = "bosses", label = L["Boss Fights"],
					texture = "Interface\\Icons\\Ability_Creature_Cursed_02", })
					
	tinsert(list, { subtype = "walkthrough", label = L["Walkthrough Guide"],
					texture = "Interface\\Icons\\Ability_Tracking", })
					
	tinsert(list, { subtype = "achievements", label = L["Achievements"],
					texture = "Interface\\ACHIEVEMENTFRAME\\UI-ACHIEVEMENT-SHIELDS-NOPOINTS", })
					
	WoWPro.Dungeons.SubTypeList = list
end
	
	
-- print dungeons names for debug and guide writing purposes
function WoWPro.Dungeons.PrintDungeonList()
	--print("Fail")
	if not WoWPro.Dungeons.DungeonList then return end
	WoWPro:Print("Dungeons:")
	WoWPro:Print("level, name")
	for i=1,#WoWPro.Dungeons.DungeonList do
		local name = WoWPro.Dungeons.DungeonList[i].name
		local recLevel = WoWPro.Dungeons.DungeonList[i].recLevel
		WoWPro:Print(recLevel.." , "..name)
	end
end

local function UpdateGuideList()
	return WoWPro.Dungeons.UpdateGuideList()
end

-- Sorting Functions --
local function dungeonSortAsc(a,b)
	return a.name < b.name
end

local function dungeonSortDesc(a,b)
	return a.name > b.name
end
	
local function dungeonSort()
	if sorttype == "DungeonAsc" then
		tsort(WoWPro.Dungeons.DungeonList, dungeonSortDesc)
		UpdateGuideList()
		sorttype = "DungeonDesc"
	else
		tsort(WoWPro.Dungeons.DungeonList, dungeonSortAsc)
		UpdateGuideList()
		sorttype = "DungeonAsc"
	end
end

local function rangeSortAsc(a,b)
	if a.recLevel == b.recLevel or a.recLevel < 1 or b.recLevel < 1 then
		if a.minLevel == b.minLevel or a.minLevel < 1 or b.minLevel < 1 then
			if a.maxLevel == b.maxLevel or a.maxLevel < 1 or b.maxLevel < 1 then
				return a.name < b.name
			else
				return a.maxLevel < b.maxLevel
			end
		else
			return a.minLevel < b.minLevel
		end
	else
		return a.recLevel < b.recLevel 
	end
end

local function rangeSortDesc(a,b)
	if a.recLevel == b.recLevel or a.recLevel < 1 or b.recLevel < 1 then
		if a.minLevel == b.minLevel or a.minLevel < 1 or b.minLevel < 1 then
			if a.maxLevel == b.maxLevel or a.maxLevel < 1 or b.maxLevel < 1 then
				return a.name < b.name
			else
				return a.maxLevel > b.maxLevel
			end
		else
			return a.minLevel > b.minLevel
		end
	else
		return a.recLevel > b.recLevel 
	end
end

local function rangeSort()
	if sorttype == "RangeAsc" then
		tsort(WoWPro.Dungeons.DungeonList, rangeSortDesc)
		UpdateGuideList()
		sorttype = "RangeDesc"
	else
		tsort(WoWPro.Dungeons.DungeonList, rangeSortAsc)
		UpdateGuideList()
		sorttype = "RangeAsc"
	end
end

local function achievementSortAsc(a,b)
	local a_complete = a.achievement.current / a.achievement.total
	local b_complete = b.achievement.current / b.achievement.total
	
	if a_complete == b_complete then
		if a.recLevel == b.recLevel or a.recLevel < 1 or b.recLevel < 1 then
			if a.minLevel == b.minLevel or a.minLevel < 1 or b.minLevel < 1 then
				if a.maxLevel == b.maxLevel or a.maxLevel < 1 or b.maxLevel < 1 then
					return a.name < b.name
				else
					return a.maxLevel < b.maxLevel
				end
			else
				return a.minLevel < b.minLevel
			end
		else
			return a.recLevel < b.recLevel 
		end
	else
		return a_complete < b_complete
	end
end

local function achievementSortDesc(a,b)
	local a_complete = a.achievement.current / a.achievement.total
	local b_complete = b.achievement.current / b.achievement.total
	
	if a_complete == b_complete then
		if a.recLevel == b.recLevel or a.recLevel < 1 or b.recLevel < 1 then
			if a.minLevel == b.minLevel or a.minLevel < 1 or b.minLevel < 1 then
				if a.maxLevel == b.maxLevel or a.maxLevel < 1 or b.maxLevel < 1 then
					return a.name < b.name
				else
					return a.maxLevel > b.maxLevel
				end
			else
				return a.minLevel > b.minLevel
			end
		else
			return a.recLevel > b.recLevel 
		end
	else
		return a_complete > b_complete
	end
end

local function achievementSort()
	if sorttype == "AchievementAsc" then
		tsort(WoWPro.Dungeons.DungeonList, achievementSortDesc)
		UpdateGuideList()
		sorttype = "AchievementDesc"
	else
		tsort(WoWPro.Dungeons.DungeonList, achievementSortAsc)
		UpdateGuideList()
		sorttype = "AchievementAsc"
	end
end

-- Creating Dungeon List --
WoWPro.Dungeons.DungeonList = {}
local function CreateDungeonList()
	--if (WoWPro.Dungeons.DungeonList) then
	--	return
	--end
	local dungeonListInfo = GetLFDChoiceInfo()
	-- some memory waste here, but CreateDungeonList will be called just once at addon load
	-- FIXME: only dealing with non-heroic dungeons for now
	for id,_ in pairs(dungeonListInfo) do
		local dungeonName, typeID, dungeonMinLevel, dungeonMaxLevel, dungeonRecLevel, dungeonMinRecLevel,
		      dungeonMaxRecLevel, expansionLevel, groupID, texture, difficulty,
		      maxPlayers, dungeonDescription, isHoliday = DungeonInfo(id)
		if typeID == TYPEID_DUNGEON and difficulty == 0 and expansionLevel <= EXPANSION_LEVEL and
		   maxPlayers <= 5 and not isHoliday then -- maxPlayers to garantee reg dungeon and not raid. Necessary??
		   	-- TODO: get achievement info: current and total
		   	-- see APIs and achievementIDs
		   	tinsert(WoWPro.Dungeons.DungeonList, {
		   		["name"] = dungeonName,
		   		["isExpanded"] = false,
		   		["minLevel"] = dungeonMinLevel,
		   		["maxLevel"] = dungeonMaxLevel,
		   		["recLevel"] = dungeonRecLevel,
		   		["minRecLevel"] = dungeonMinRecLevel,
		   		["maxRecLevel"] = dungeonMaxRecLevel,
		   		["achievement"] = { ["current"] = 1,
		   				  ["total"] = 1, },
		   	})
		   	-- default, initial sort: by recLevel
		   	tsort(WoWPro.Dungeons.DungeonList, rangeSortAsc)
		   	sorttype = "RangeAsc"
		end
	end

end

-- function only to be called on achievement_update event, etc
local function UpdateDungeonList()
	if not (WoWPro.Dungeons.DungeonList) then
		return
	end
	-- TODO: get achievement info: current and total
	-- see APIs and achievementIDs
	-- everything else should not change while logged in
	-- also update upon quest completion??
end

-- Creating Dungeon List --
WoWPro.Dungeons.GuideList = {}
local function CreateGuideList()
	--if (WoWPro.Dungeons.GuideList) then
	--	return
	--end
	for guidID,guide in pairs(WoWPro.Guides) do
		if guide.guidetype == "Dungeons" then
			local dungeon = guide.dungeon
			local subtype = guide.guidesubtype
			local GIDvalue = guidID
			local authorname = guide.author
			-- local sequencevalue = guide["sequence"]
		
			if dungeon and subtype and GIDvalue then
				WoWPro.Dungeons.GuideList[dungeon] = WoWPro.Dungeons.GuideList[dungeon] or {}
				WoWPro.Dungeons.GuideList[dungeon][subtype] = WoWPro.Dungeons.GuideList[dungeon][subtype] or {}
				tinsert(WoWPro.Dungeons.GuideList[dungeon][subtype], {
					GID = GIDvalue,
					author = authorname,
					-- sequence = sequencevalue,
				})
			end
		end
	end
end

-- Filter functions to populate guide list --
local function isFilteredByLevel(playerLevel, dungeon)
	local filterByLevel = false -- TODO: move this to a toggeable option
	local showRecLevel = false -- TODO: create an option for that later, to show recLevel or enterLevel

	if filterByLevel then
		local startLevel, endLevel
		if showRecLevel then
			startLevel, endLevel = dungeon.minRecLevel, dungeon.maxRecLevel
		else
			startLevel, endLevel = dungeon.minLevel, dungeon.maxLevel
		end
		return playerLevel >= startLevel and playerLevel <= endLevel
	else
		return true
	end
end

local function isFilteredByName(dungeon)
	local textFilter = "" -- TODO: :GetText from the editbox
	local textFilterDefault = L["Filter by dungeon name"] -- include when editbox created

	if #textFilter > 0 and textFilter ~= textFilterDefault then
		local name = dungeon.name
		return true -- strfind, TODO: see book example
	else
		return true
	end
end


local function FindInitialRows(scrollOffset, playerLevel)
	local count = 0
	local DungeonList = WoWPro.Dungeons.DungeonList
	local numSubType = #WoWPro.Dungeons.SubTypeList
	for i=1,#DungeonList do
		local dungeon = DungeonList[i]
		if isFilteredByLevel(playerLevel, dungeon) and isFilteredByName(dungeon) then
			for j=0,numSubType do
				count = count + 1
				if count > scrollOffset then
					return i, j
				end
				if not DungeonList[i].isExpanded then
					break
				end
			end
		end
	end
	return 1, 0
end

-- FindTotalRows
local function FindTotalRows(playerLevel)
	local DungeonList = WoWPro.Dungeons.DungeonList
	local numSubType = #WoWPro.Dungeons.SubTypeList
	local count = 0
	for i=1,#DungeonList do
		local dungeon = DungeonList[i]
		if isFilteredByLevel(playerLevel, dungeon) and isFilteredByName(dungeon) then
			count = count + 1
			if dungeon.isExpanded then
				count = count + (numSubType or 0)
			end
		end
	end
	return count
end


-- Populating Guide List --
function WoWPro.Dungeons.UpdateGuideList(scrollOffset)
	if not WoWPro_Dungeons_GuideListFrame:IsVisible() then return end
	local DungeonList = WoWPro.Dungeons.DungeonList
	local SubTypeList = WoWPro.Dungeons.SubTypeList
	local GuideList = WoWPro.Dungeons.GuideList
	
	if not (DungeonList and SubTypeList and GuideList) then return end
	
	local offset = scrollOffset or WoWPro_Dungeons_GuideListFrame.scrollbar:GetValue()

	local myLevel = UnitLevel("player")
	
	local TotalRows = FindTotalRows(myLevel)
	WoWPro_Dungeons_GuideListFrame.scrollbar:SetMinMaxValues(0, math.max(0, TotalRows - NUMROWS))
	
	local iDungeon, iSubType = FindInitialRows(offset, myLevel)

	local showRecLevel = false -- TODO: create an option for that later, to show recLevel or enterLevel
	
	for i,row in ipairs(rows) do
		if iDungeon <= #DungeonList then
			row.iDungeon, row.iSubType = iDungeon, iSubType
			local dungeon = DungeonList[iDungeon]
			-- checking filters, by level and by dungeon name
			if isFilteredByLevel(myLevel, dungeon) and isFilteredByName(dungeon) then
		
				if iSubType == 0 then -- row shows dungeon info
					local startlevel, endlevel
					if showRecLevel then
						startlevel, endlevel = dungeon.minRecLevel, dungeon.maxRecLevel
					else
						startlevel, endlevel = dungeon.minLevel, dungeon.maxLevel
					end
					local achievementCurrent = dungeon.achievement.current
					local achievementTotal = dungeon.achievement.total
					local dungeonname = dungeon.name
					row.dungeon:SetText(dungeonname)
					row.range:SetText("("..startlevel.."-"..endlevel..")")
					if (achievementCurrent/achievementTotal) == 1 then
						row.achievement:SetText("completed")
					else
						row.achievement:SetText(achievementCurrent.." / "..achievementTotal)
					end
	
					row.dungeon:Show()
					row.range:Show()
					row.achievement:Show()
					row.subtype:Hide()
					row.subtypeicon:Hide()
	
					row:SetScript("OnClick", function(self, ...)
							if WoWPro.Dungeons.DungeonList[self.iDungeon].isExpanded then
								WoWPro.Dungeons.DungeonList[self.iDungeon].isExpanded = false
								row:SetChecked(false)
							else
								WoWPro.Dungeons.DungeonList[self.iDungeon].isExpanded = true
								row:SetChecked(true)
							end
							WoWPro.Dungeons.UpdateGuideList()		
					end)
				
					if dungeon.isExpanded then
						row:SetChecked(true)
						iSubType = iSubType + 1
						row.icon:SetTexture("Interface\\Buttons\\UI-MinusButton-UP")
					else 
						iSubType = 0
						iDungeon = iDungeon + 1
						row:SetChecked(false)
						row.icon:SetTexture("Interface\\Buttons\\UI-PlusButton-UP")
					end
					row.icon:Show()
					row:Enable()
					
				else	-- row shows subtype
				
					local subtype = SubTypeList[iSubType].subtype
					local subtypeText = SubTypeList[iSubType].label
					local texture = SubTypeList[iSubType].texture
					
					row.subtypeicon:SetTexture(texture)
					row.subtype:SetText(subtypeText)
					
					if subtype == "achievements" then
						row.subtypeicon:SetTexCoord(0, 0.5, 0, 0.5)
					elseif subtype == "location" then
						row.subtypeicon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
					else
						row.subtypeicon:SetTexCoord(0, 1, 0, 1)
					end
					
					row.subtypeicon:SetVertexColor(1, 1, 1)
					row.subtype:SetVertexColor(1, 1, 1)
					
					row.icon:Hide()
					row.dungeon:Hide()
					row.range:Hide()
					row.achievement:Hide()
					row.subtype:Show()
					row.subtypeicon:Show()
	
					-- setting guide info for onclick, etc
					local guide
					if GuideList[dungeon.name] then
						guide = GuideList[dungeon.name][subtype]
					end
					local GID
					if guide then 
						GID = guide[1]["GID"]
					end
					if guide and GID then
						if WoWProDB.char.currentguide == GID then
							row:SetChecked(true)
						else
							row:SetChecked(false)
						end
						row:SetScript("OnClick", function(self, ...)
							if not WoWPro.Dungeons:IsEnabled() then return end
							local dungeon = WoWPro.Dungeons.DungeonList[self.iDungeon]
							local subtype = WoWPro.Dungeons.SubTypeList[self.iSubType].subtype
							local guide = WoWPro.Dungeons.GuideList[dungeon.name][subtype]
							WoWPro:LoadGuide(guide[1]["GID"])
						end)
						row:Enable()
					else
						row:SetScript("OnClick", nil)
						row:SetChecked(false)
						row.subtypeicon:SetVertexColor(0.5, 0.5, 0.5)
						row.subtype:SetVertexColor(0.5, 0.5, 0.5)
						row:Disable() -- TODO: disable row, check texture
					end
					
				
					if iSubType < #SubTypeList then
						iSubType = iSubType + 1
					else
						iSubType = 0
						iDungeon = iDungeon + 1
					end
		
					
				end
				rows[i] = row
			else
				iDungeon = iDungeon + 1
				iSubType = 0
			end
		else
			row:Hide()
		end
		
	end
end



	
-- function to create the row of titles --
local function CreateTitleRow(box, scrollbar)

	local titlerow = {}
	
	-- Title Backdrop Settings --
	titlerowBG = {
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		tile = true,
		tileSize = 16,
		insets = { left = 0, right = 0, top = 5, bottom = -5}
	}

	-- Title Row --
	titlerow.icon = CreateFrame("CheckButton", nil, box)
	titlerow.icon:SetBackdrop(titlerowBG)
	titlerow.icon:SetBackdropColor(0.3, 0.2, 0.2, 1)
	titlerow.icon:SetHeight(ROWHEIGHT)

	titlerow.dungeon = CreateFrame("CheckButton", nil, box)
	titlerow.dungeon:SetBackdrop(titlerowBG)
	titlerow.dungeon:SetBackdropColor(0.3, 0.2, 0.2, 1)
	titlerow.dungeon:SetHeight(ROWHEIGHT)

	titlerow.range = CreateFrame("CheckButton", nil, box)
	titlerow.range:SetBackdrop(titlerowBG)
	titlerow.range:SetBackdropColor(0.3, 0.2, 0.2, 1)
	titlerow.range:SetHeight(ROWHEIGHT)

	titlerow.achievement = CreateFrame("CheckButton", nil, box)
	titlerow.achievement:SetBackdrop(titlerowBG)
	titlerow.achievement:SetBackdropColor(0.3, 0.2, 0.2, 1)
	titlerow.achievement:SetHeight(ROWHEIGHT)

	titlerow.icon:SetPoint("TOPLEFT", 4, 0)
	titlerow.icon:SetWidth(17)
	titlerow.dungeon:SetPoint("LEFT", titlerow.icon, "RIGHT", 0, 0)
	titlerow.dungeon:SetWidth(155)
	titlerow.range:SetPoint("LEFT", titlerow.dungeon, "RIGHT", 0, 0)
	titlerow.range:SetWidth(50)
	titlerow.achievement:SetPoint("LEFT", titlerow.range, "RIGHT", 0, 0)
	titlerow.achievement:SetPoint("TOPRIGHT", scrollbar, "TOPLEFT", -5, 22)

	-- Title Row Text Fields --
	local dungeon = titlerow.dungeon:CreateFontString(nil, nil, "GameFontWhite")
	local range = titlerow.range:CreateFontString(nil, nil, "GameFontWhite")
	local achievement = titlerow.achievement:CreateFontString(nil, nil, "GameFontWhite")
	
	dungeon:SetPoint("LEFT", 0, -5)
	dungeon:SetWidth(155)
	range:SetPoint("LEFT", dungeon, "RIGHT", 0, 0)
	range:SetWidth(50)
	achievement:SetPoint("LEFT", range, "RIGHT", 0, 0)
	achievement:SetPoint("TOPRIGHT", scrollbar, "TOPLEFT", -5, 14)
		
	dungeon:SetText(L["Dungeon"])
	range:SetText(L["Level"])
	achievement:SetText(L["Progress"])
			
	dungeon:SetJustifyH("LEFT")
	range:SetJustifyH("LEFT")
	achievement:SetJustifyH("LEFT")
			
	titlerow.dungeon.text = zone
	titlerow.range.text = range
	titlerow.achievement.text = progress

	titlerow.dungeon:SetScript("OnClick", dungeonSort)
	titlerow.range:SetScript("OnClick", rangeSort)
	titlerow.achievement:SetScript("OnClick", achievementSort)

	return titlerow
end

-- function to create the rows of dungeons/guides --
local function CreateRows(box, titlerow, scrollbar)
	
	for i=1,NUMROWS do
		local row = CreateFrame("CheckButton", nil, box)
		
		local icon = row:CreateTexture()
		icon:SetWidth(15)
		icon:SetHeight(15)
		
		local subtypeicon = row:CreateTexture()
		subtypeicon:SetWidth(15)
		subtypeicon:SetHeight(15)
		
		local dungeon = row:CreateFontString(nil, nil, "GameFontHighlightSmall")
		local range = row:CreateFontString(nil, nil, "GameFontHighlightSmall")
		local achievement = row:CreateFontString(nil, nil, "GameFontHighlightSmall")
		local subtype = row:CreateFontString(nil, nil, "GameFontHighlightSmall")
				
		local prevrow
		
		-- Row Anchor Settings --
		if i == 1 then 
			row:SetPoint("TOPLEFT", titlerow.icon, "BOTTOMLEFT", 0, -10)
			row:SetPoint("TOPRIGHT", titlerow.achievement, "BOTTOMRIGHT", 0, -10)
			prevrow = titlerow
			GAP = -10
				
		else 
			row:SetPoint("TOPLEFT", rows[i-1], "BOTTOMLEFT", 0, 0)
			row:SetPoint("TOPRIGHT", rows[i-1], "BOTTOMRIGHT", 0, 0)
			prevrow = rows[i-1]
			GAP = 0
		end

		row:SetPoint("LEFT", 4, 0)
		row:SetPoint("RIGHT", -4, 0)
		row:SetHeight(ROWHEIGHT)

		-- Icon and Text Settings --
		icon:SetPoint("TOPLEFT", prevrow.icon, "BOTTOMLEFT", 0, GAP)
		icon:SetPoint("TOPRIGHT", prevrow.icon, "BOTTOMRIGHT", 0, GAP)
		icon:SetHeight(ROWHEIGHT)
		
		dungeon:SetPoint("TOPLEFT", prevrow.dungeon, "BOTTOMLEFT", 0, GAP)
		dungeon:SetPoint("TOPRIGHT", prevrow.dungeon, "BOTTOMRIGHT", 0, GAP)
		dungeon:SetHeight(ROWHEIGHT)
		dungeon:SetJustifyH("LEFT")

		range:SetPoint("TOPLEFT", prevrow.range, "BOTTOMLEFT", 0, GAP)
		range:SetPoint("TOPRIGHT", prevrow.range, "BOTTOMRIGHT", 0, GAP)
		range:SetHeight(ROWHEIGHT)
		range:SetJustifyH("LEFT")

		achievement:SetPoint("TOPLEFT", prevrow.achievement, "BOTTOMLEFT", 0, GAP)
		achievement:SetPoint("TOPRIGHT", prevrow.achievement, "BOTTOMRIGHT", 0, GAP)
		achievement:SetHeight(ROWHEIGHT)
		achievement:SetJustifyH("LEFT")

		subtype:SetPoint("TOPLEFT", prevrow.dungeon, "BOTTOMLEFT", 20, GAP)
		subtype:SetPoint("TOPRIGHT", prevrow.dungeon, "BOTTOMRIGHT", 20, GAP)
		subtype:SetHeight(ROWHEIGHT)
		subtype:SetJustifyH("LEFT")	
		
		subtypeicon:SetPoint("TOPLEFT", prevrow.icon, "BOTTOMLEFT", 20, GAP)

		-- highlights settings
		local highlight = row:CreateTexture()
		highlight:SetTexture("Interface\\HelpFrame\\HelpFrameButton-Highlight")
		highlight:SetTexCoord(0, 1, 0, 0.578125)
		highlight:SetAllPoints()
		row:SetHighlightTexture(highlight)
		row:SetCheckedTexture(highlight)
		
		-- text frames to be updated later --
		row.icon = icon
		row.dungeon = dungeon
		row.range = range
		row.achievement = achievement
		row.subtype = subtype
		row.subtypeicon = subtypeicon
		rows[i] = row
	end
end

function WoWPro.Dungeons:CreateGuideListFrame()

	CreateSubTypeList()
	CreateGuideList()
	CreateDungeonList()
	
	local frame = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
	frame.name = L["Dungeons Guide List"]
	frame.parent = "WoW-Pro Dungeons"
	frame:Hide()

	local title, subtitle = WoWPro:CreateHeading(frame, "WoW-Pro Dungeons - "..L["Guide List"], 
	L["Dungeons and available WoW-Pro dungeon guides are listed below. \nSelect one to load."])

	local box = WoWPro:CreateBG(frame)
	box:SetPoint("TOP", subtitle, "BOTTOM", 0, -GAP) 
	box:SetPoint("LEFT", EDGEGAP, 0)
	box:SetPoint("BOTTOMRIGHT", -EDGEGAP, EDGEGAP)

	local scrollbar = WoWPro:CreateScrollbar(box, 6, 3)
	local titlerow = CreateTitleRow(box, scrollbar)
	CreateRows(box, titlerow, scrollbar)
	
	-- UpdateGuideList()

	-- scrollframe settings --
	scrollbar:SetValue(0)
	scrollbar:SetValueStep(1)
	local f = scrollbar:GetScript("OnValueChanged")
	scrollbar:SetScript("OnValueChanged", function(self, value, ...)
		local offset = math.floor(value)
		UpdateGuideList(offset)
		return f(self, value, ...)
	end)
	
	frame.scrollbar = scrollbar

	frame:EnableMouseWheel()
	frame:SetScript("OnMouseWheel", function(self, val) self.scrollbar:SetValue(self.scrollbar:GetValue() - val*NUMROWS/3) end)

	local function OnShow(self) 
		WoWPro.NextGuideDialog:Hide()
		return UpdateGuideList()
	end
	frame:SetScript("OnShow", OnShow)
	-- OnShow(frame)

	WoWPro_Dungeons_GuideListFrame = frame

end
