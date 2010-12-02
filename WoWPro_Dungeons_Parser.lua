--------------------------------------
--      WoWPro_Dungeons_Parser      --
--------------------------------------
	
local L = WoWPro_Locale
local tinsert = table.insert
local safecall = pcall
local myclass, myrace = UnitClass("player"), UnitRace("player")


WoWPro.Dungeons.actiontypes = {
	A = "Interface\\GossipFrame\\AvailableQuestIcon",
	C = "Interface\\Icons\\Ability_DualWield",
	T = "Interface\\GossipFrame\\ActiveQuestIcon",
	K = "Interface\\Icons\\Ability_Creature_Cursed_02",
	R = "Interface\\Icons\\Ability_Tracking",
	H = "Interface\\Icons\\INV_Misc_Rune_01",
	h = "Interface\\AddOns\\WoWPro\\Textures\\resting.tga",
	F = "Interface\\Icons\\Ability_Druid_FlightForm",
	f = "Interface\\Icons\\Ability_Hunter_EagleEye",
	N = "Interface\\Icons\\INV_Misc_Note_01",
	B = "Interface\\Icons\\INV_Misc_Coin_01",
	b = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
	U = "Interface\\Icons\\INV_Misc_Bag_08",
	L = "Interface\\Icons\\Spell_ChargePositive",
	l = "Interface\\Icons\\INV_Misc_Bag_08",
	r = "Interface\\Icons\\Ability_Repair",
	S = -- spell/ability
}
WoWPro.Dungeons.actionlabels = {
	A = "Accept",
	C = "Complete",
	T = "Turn in",
	K = "Kill",
	R = "Run to",
	H = "Hearth to",
	h = "Set hearth to",
	F = "Fly to",
	f = "Get flight path for",
	N = "Note:",
	B = "Buy",
	b = "Boat or Zeppelin",
	U = "Use",
	L = "Level",
	l = "Loot",
	r = "Repair/Restock",
	S = -- spell/ability
}

-- util
function WoWPro.Dungeons:IsDungeonGuide(GuideID)
	local GID = GuideID or WoWProDB.char.currentguide
	local guidetype
	if WoWPro.Guides[GID] then
		guidetype = WoWPro.Guides[GID].guidetype
	end
	
	if guidetype == "Dungeons" then
		return true
	else
		return false
	end
end

-- util
local function resetTable(tbl)
	if tbl and type(tbl) == "table" then
		wipe(tbl)
	else
		tbl = {}
	end
	return tbl
end

local function skipRecursive(index, steplist, GID)
	if WoWPro.action[index] == "A" or WoWPro.action[index] == "C" or WoWPro.action[index] == "T" then
		WoWPro.Dungeons.db.skippedQIDs[WoWPro.QID[index]] = true
	end 
	WoWPro.Dungeons.db.guide[GID].skipped[index] = true

	for j = 1,WoWPro.stepcount do 
		if WoWPro.prereq[j] then
			local numprereqs = select("#", string.split(";", WoWPro.prereq[j]))
			for k=1,numprereqs do
				local kprereq = select(numprereqs-k+1, string.split(";", WoWPro.prereq[j]))
				if tonumber(kprereq) == WoWPro.QID[index] and WoWPro.Dungeons.db.skippedQIDs[WoWPro.QID[index]] then
					steplist = steplist.."- "..WoWPro.step[j].."\n"
					skipRecursive(j, steplist, GID)
					break
				end
			end
		end
	end
end


-- Skip a step --
function WoWPro.Dungeons:SkipStep(index)
	local GID = WoWProDB.char.currentguide
	if not WoWPro.Dungeons:IsDungeonGuide(GID) or not WoWPro.QID[index] then return "" end
	
	local steplist = ""
	
	-- Changed here, to a recursive function
	skipRecursive(index, steplist, GID)
	
	WoWPro:MapPoint() -- necessary??
	return steplist
end

local function unskipRecursive(index, GID)
	WoWPro.Dungeons.db.guide[GID].completion[index] = nil
	
	if WoWPro.action[index] == "A" or WoWPro.action[index] == "C" or WoWPro.action[index] == "T" then
		WoWPro.Dungeons.db.skippedQIDs[WoWPro.QID[index]] = nil
	end 
	WoWPro.Dungeons.db.guide[GID].skipped[index] = nil
	
	for j = 1,WoWPro.stepcount do 
		if WoWPro.prereq[j] then
			local numprereqs = select("#", string.split(";", WoWPro.prereq[j]))
			for k=1,numprereqs do
				local kprereq = select(numprereqs-k+1, string.split(";", WoWPro.prereq[j]))
				if tonumber(kprereq) == WoWPro.QID[index] then
					unskipRecursive(j, GID)
					break
				end
			end
		end
	end
end

-- Unskip a step --
function WoWPro.Dungeons:UnSkipStep(index)
	local GID = WoWProDB.char.currentguide
	if not WoWPro.Dungeons:IsDungeonGuide(GID) or not WoWPro.QID[index] then return end
	
	unskipRecursive(index, GID)
		
	WoWPro:UpdateGuide()
	WoWPro:MapPoint()
end

-- utils

local function IsActionValid(action, subtypeGuide)
	local SubTypeList = WoWPro.Dungeons.SubTypeList
	local validActions
	for _,itype in pairs(SubTypeList) do
		if itype.subtype == subtypeGuide then
			validActions = itype.actions
			break
		end
	end
	if action and validActions then
		for _,valid in pairs(validActions) do
			if action == valid then
				return true
			end
		end
	end
	return false
end

local function IsTagValid(tag, subtype)
	local SubTypeList = WoWPro.Dungeons.SubTypeList
	local validTags
	for _,itype in pairs(SubTypeList) do
		if itype.subtype == subtypeGuide then
			validTags = itype.tags
			break
		end
	end
	if tag and validTags then
		for _,valid in pairs(validTags) do
			if tag == valid then
				return true
			end
		end
	end
	return false
end

-- dont restric now per class, race or anything else, only checks overall validity
-- dont restrict anything, because these steps/guides can still be shared to others
-- Quest parsing function --
function WoWPro.Dungeons.ParseGuide(GID, ...)
	WoWPro:dbp("Parsing Guide...")
	local subtypeguide = WoWPro.Guides[GID].guidesubtype or "walkthrough"
	
	local i = 1
	for j=1,select("#", ...) do
		local text = select(j, ...)
		if text ~= "" then
			_, _, WoWPro.action[i], WoWPro.step[i] = text:find("^(%a) ([^|]*)(.*)")
			--print(WoWPro.action[i], WoWPro.step[i], subtypeguide)
			
			if IsActionValid(WoWPro.action[i], subtypeguide) and WoWPro.step[i] then
				-- first tags that exist for all guide types
				WoWPro.step[i] = WoWPro.step[i]:trim()
				WoWPro.note[i] = text:match("|N|([^|]*)|?")
				WoWPro.map[i] = text:match("|M|([^|]*)|?")
				WoWPro.use[i] = text:match("|U|([^|]*)|?")
				WoWPro.zone[i] = text:match("|Z|([^|]*)|?")
				
				if WoWPro.action[i] == "R" and WoWPro.map[i] then
					if text:find("|CC|") then WoWPro.waypcomplete[i] = 1
					elseif text:find("|CS|") then WoWPro.waypcomplete[i] = 2
					else WoWPro.waypcomplete[i] = false end
				end
				
				if IsTagValid("QID", subtypeguide) then
					WoWPro.QID[i] = tonumber(text:match("|QID|([^|]*)|?"))
					if not QID and (WoWPro.action[i] == "A" or WoWPro.action[i] == "C" or WoWPro.action[i] == "T") then
						local message = "Guide: "..GID..";Line: "..j.." - Missing QuestID"
						WoWPro:Print(message)
					end
				end
				
				if IsTagValid("sticky", subtypeguide) then
					if text:find("|S|") then 
						WoWPro.sticky[i] = true; 
						WoWPro.stickycount = WoWPro.stickycount + 1 
					end
					if text:find("|US|") then 
						WoWPro.unsticky[i] = true 
					end
				end
				
				if IsTagValid("lootitem", subtypeguide) then
					_, _, WoWPro.lootitem[i], WoWPro.lootqty[i] = text:find("|L|(%d+)%s?(%d*)|")
				end
				
				if IsTagValid("optional", subtypeguide) then
					if text:find("|O|") then 
						WoWPro.optional[i] = true
						WoWPro.optionalcount = WoWPro.optionalcount + 1 
					end
				end
				
				if IsTagValid("target", subtypeguide) then
					WoWPro.target[i] = text:match("|T|([^|]*)|?")
				end
				
				if IsTagValid("prof", subtypeguide) then
					WoWPro.prof[i] = text:match("|P|([^|]*)|?")
				end
				
				if IsTagValid("rank", subtypeguide) then
					WoWPro.rank[i] = text:match("|RANK|([^|]*)|?")
				end
				
				if IsTagValid("questtext", subtypeguide) then
					WoWPro.questtext[i] = text:match("|QO|([^|]*)|?")
				end
				
				if IsTagValid("prereq", subtypeguide) then
					WoWPro.prereq[i] = text:match("|PRE|([^|]*)|?")
				end
				
				if IsTagValid("leadin", subtypeguide) then
					WoWPro.leadin[i] = text:match("|LEAD|([^|]*)|?")
				end
				
				if IsTagValid("mode", subtypeguide) then
					if text:find("|HERO|") then
						WoWPro.mode[i] = 1
					elseif text:find("|NOR|") then
						WoWPro.mode[i] = 0
					end
				end
				
				if IsTagValid("race", subtypeguide) then
					WoWPro.class[i], WoWPro.race[i] = text:match("|C|([^|]*)|?"), text:match("|R|([^|]*)|?")
					local ok, role = safecall(strupper, text:match("|ROLE|([^|]*)|?"))
					if ok and role and ( role ~= "HEALER" or role ~= "TANK" or role ~= "DPS" ) then
						WoWPro.role[i] = role
					end
				end
				
				if IsTagValid("minlevel", subtypeguide) then
					WoWPro.minlevel[i] = tonumber(text:match("|lvl|([^|]*)|?"))
				end
				
				if text:find("|NC|") then WoWPro.noncombat[i] = true end -- check this
				-- rep by Twists
				
				i = i + 1
				
			else
				local message = "Guide: "..GID..";Line: "..j.." - Wrong action or step"
				WoWPro:Print(message)
			end
		end
	end
	WoWPro.stepcount = i - 1
end
	
-- Guide Load --
function WoWPro.Dungeons:LoadGuide()
	local GID = WoWProDB.char.currentguide
	
	if not WoWPro.Dungeons:IsDungeonGuide(GID) then return end

	-- Parsing steps --
	local sequence = WoWPro.Guides[GID].sequence
	WoWPro.Dungeons.ParseGuide(GID, string.split("\n", sequence()))
	
	WoWPro:dbp("Guide Parsed. "..WoWPro.stepcount.." steps registered.")
	
	WoWPro.Dungeons.db.guide[GID] = WoWPro.Dungeons.db.guide[GID] or {}
	WoWPro.Dungeons.db.guide[GID].completion = WoWPro.Dungeons.db.guide[GID].completion or {}
	WoWPro.Dungeons.db.guide[GID].skipped = WoWPro.Dungeons.db.guide[GID].skipped or {}
		
	WoWPro.Dungeons:PopulateQuestLog() --Calling this will populate our quest log table for use here
	
	-- Checking to see if any steps, IF related to quests, are already complete --
	for i=1, WoWPro.stepcount do
		local QID = WoWPro.QID[i]
		local action = WoWPro.action[i]
		local completion = WoWPro.Dungeons.db.guide[GID].completion[i]		
		
		if QID then
			-- Turned in quests --
			if WoWPro.Dungeons.db.completedQIDs then
				if WoWPro.Dungeons.db.completedQIDs[QID] then
					WoWPro.Dungeons.db.guide[GID].completion[i] = true
				end
			end
	
			-- Quest Accepts and Completions --
			if not completion and WoWPro.QuestLog[QID] then 
				if action == "A" then
					WoWPro.Dungeons.db.guide[GID].completion[i] = true 
				elseif action == "C" and WoWPro.QuestLog[QID].complete then
					WoWPro.Dungeons.db.guide[GID].completion[i] = true
				end
			end
		end
		
		-- not used for dungeons guides
		-- Checking level based completion --
		-- if completion and level and tonumber(level) <= UnitLevel("player") then
			-- WoWPro.Dungeons.db.guide[GID].completion[i] = true
		-- end
	end
	
	-- Checking zone based completion --
	WoWPro:UpdateGuide()
	-- TODO: Check this
	-- WoWPro.Dungeons:AutoCompleteZone()
	
	-- Scrollbar Settings --
	WoWPro.Scrollbar:SetMinMaxValues(1, math.max(1, WoWPro.stepcount - WoWPro.ShownRows)) -- TODO: check WoWPro.ShownRows
end

-- Row Content Update --
function WoWPro.Dungeons:RowUpdate(offset)
	local GID = WoWProDB.char.currentguide
	if InCombatLockdown() or not GID or not WoWPro.Guides[GID] then 
		return 
	end
	local numRows = #WoWPro.rows
	local numSteps = max(numRows, WoWPro.stepcount)
	local i = 1
	
	-- TODO
	-- local mylevel = getplayerlevel
	-- local myrole = getplayerrole (a function: if player in dungeon or not)
	-- local dungeonMode = getdungeonMode (a function: if player in dungeon or not)
	
	WoWPro.ActiveStickyCount = 0
	local initialk = offset or WoWPro.ActiveStep
	local lootcheck = true
	local itemkb = false
	local targetkb = false
	ClearOverrideBindings(WoWPro.MainFrame)
	WoWPro.Dungeons.RowDropdownMenu = resetTable(WoWPro.Dungeons.RowDropdownMenu)
	
	for k=initialk,numSteps do
			
		while i <= numRows do
		
			-- Skipping any skipped steps, unsticky steps, and optional steps unless it's time for them to display --
			if not WoWProDB.profile.guidescroll then
				k = WoWPro:NextStep(k, i) -- TODO: check this
			end
			
			local completion = WoWPro.Dungeons.db.guide[GID].completion
			
			-- Checking off lead in steps --
			local leadin = WoWPro.leadin[k]
			if leadin and WoWPro.Dungeons.db.completedQIDs[tonumber(leadin)] then
				completion[k] = true
				break
			end
			
			local step = WoWPro.step[k]
			
			-- Unstickying stickies --
			local unsticky = WoWPro.unsticky[k]
			if unsticky and i == WoWPro.ActiveStickyCount+1 then
				local nextstep = false
				for j=1,numRows do 
					if step == WoWPro.rows[j].step:GetText() and WoWPro.sticky[WoWPro.rows[j].index] then 
						completion[WoWPro.rows[j].index] = true
						nextstep = true
					end
				end
				if nextstep then 
					break 
				end
			end
			
			-- show/hide steps depending of options
			-- regarding race
			local race = WoWPro.race[k]
			if race and race ~= myrace and WoWPro.Dungeons.db.filterRace then
				break
			end
			-- regarding class 
			local class = WoWPro.class[k]
			if class and class ~= myclass and WoWPro.Dungeons.db.filterClass then
				break
			end
			-- regarding role 
			local role = WoWPro.role[k]
			if role and role ~= myrole and WoWPro.Dungeons.db.filterRole then
				break
			end
			-- regarding minlevel 
			local minlevel = WoWPro.minlevel[k]
			if minlevel and minlevel > mylevel and WoWPro.Dungeons.db.filterMinLevel then
				break
			end
			-- regarding dungeon mode (heroic, normal)
			local mode = WoWPro.mode[k]
			if mode and mode ~= dungeonMode and WoWPro.Dungeons.db.filterMode then
				break
			end
			
			-- Counting stickies that are currently active (at the top) --
			local sticky = WoWPro.sticky[k]
			if sticky and i == WoWPro.ActiveStickyCount+1 then
				WoWPro.ActiveStickyCount = WoWPro.ActiveStickyCount+1
			end
		
			--Loading rest of Variables --
			local row = WoWPro.rows[i]
			row.index = k
			row.num = i
		
			local action = WoWPro.action[k] 
			local note = WoWPro.note[k]
			local QID = WoWPro.QID[k] 
			local coord = WoWPro.map[k] 
		 
		 	local use = WoWPro.use[k] 
			local zone = WoWPro.zone[k] 
			local lootitem = WoWPro.lootitem[k] 
			local lootqty = WoWPro.lootqty[k] 
			local questtext = WoWPro.questtext[k] 
			local optional = WoWPro.optional[k] 
			local prereq = WoWPro.prereq[k]
			local target = WoWPro.target[k]
			
			if WoWPro.prof[k] then
				local prof, proflvl = string.split(" ", WoWPro.prof[k]) 
			end
			
			-- skippedQID, if step is QID
			local skippedQID = false
			if QID then
				skippedQID = WoWPro.Dungeons.db.skippedQIDs[WoWPro.QID[k]]
			end
		
			-- Getting the image and text for the step --
			row.step:SetText(step)
			-- TODO: think about steps (boss fights) with no completion/check
			-- TODO: Is there a way to disable for a while protectiveness of item/target frames?
			if step then 
				row.check:Show() 
			else 
				row.check:Hide() 
			end
			-- check setting
			if completion[k] or WoWPro.Dungeons.db.guide[GID].skipped[k] or skippedQID then
				row.check:SetChecked(true)
				if WoWPro.Dungeons.db.guide[GID].skipped[k] or skippedQID then
					row.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
				else
					row.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
				end
			else
				row.check:SetChecked(false)
				row.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
			end
			
			-- setting note/coords
			if note then note = strtrim(note) end
			if WoWProDB.profile.showcoords and coord and note then note = note.." ("..coord..")" end
			if WoWProDB.profile.showcoords and coord and not note then note = "("..coord..")" end
			if not ( WoWProDB.profile.showcoords and coord ) and not note then note = "" end
			row.note:SetText(note)
			
			-- setting action
			row.action:SetTexture(WoWPro.Dungeons.actiontypes[action])
			if WoWPro.noncombat[k] and WoWPro.action[k] == "C" then
				row.action:SetTexture("Interface\\AddOns\\WoWPro\\Textures\\Config.tga")
			end
		
			-- Checkbox Function --
			row.check:SetScript("OnClick", function(self, button, down)
				row.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
				if button == "LeftButton" and row.check:GetChecked() then
					local steplist = WoWPro.Dungeons:SkipStep(row.index)
					row.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
					if steplist ~= "" then 
						WoWPro:SkipStepDialogCall(row.index, steplist)
					end
				elseif button == "RightButton" and row.check:GetChecked() then
					completion[row.index] = true
					WoWPro:MapPoint()
					if WoWProDB.profile.checksound then	
						PlaySoundFile(WoWProDB.profile.checksoundfile)
					end
				elseif not row.check:GetChecked() then
					WoWPro.Dungeons:UnSkipStep(row.index)
				end
				WoWPro:UpdateGuide()
			end)
		
			-- TODO: Try to change all these, wihtout using easymenu
			-- Right-Click Drop-Down --
			local dropdown = {}
			if step then
				table.insert(dropdown, {text = step.." Options", isTitle = true})
				-- trust in MapPoint
				-- QuestMapUpdateAllQuests()
				-- QuestPOIUpdateIcons()
				-- local _, x, y, obj
				-- if QID then _, x, y, obj = QuestPOIGetIconInfo(QID) end
				-- if coord or x then
				table.insert(dropdown, {text = "Map Coordinates", 	func = function()
																	WoWPro:MapPoint(row.num) end} )
				--end
				-- setting up party options
				if GetNumPartyMembers() > 0 then
					if QID and WoWPro.QuestLog[QID] and WoWPro.QuestLog[QID].index then
						table.insert(dropdown, {text = "Share Quest", func = function()
												QuestLogPushQuest(WoWPro.QuestLog[QID].index) end} )
					end
					-- TODO: setup share step with party
				end
				if sticky then
					table.insert(dropdown, {text = "Un-Sticky", func = function() 
											WoWPro.sticky[row.index] = false
											WoWPro.UpdateGuide()
											WoWPro.UpdateGuide() -- why 2 updates??
											WoWPro.MapPoint()
											end} )
				else
					table.insert(dropdown, {text = "Make Sticky", func = function() 
											WoWPro.sticky[row.index] = true
											WoWPro.unsticky[row.index] = false
											WoWPro.UpdateGuide()
											WoWPro.UpdateGuide() -- again, why 2 updates
											WoWPro.MapPoint()
											end} )
				end
			end
			WoWPro.Dungeons.RowDropdownMenu[i] = dropdown
		
			-- Item Button --
			-- if action == "H" then 
				-- use = 6948 
			-- end
			if ( not use ) and action == "C" and WoWPro.QuestLog[QID] then
				local link, icon, charges = GetQuestLogSpecialItemInfo(WoWPro.QuestLog[QID].index)
				if link then
					local 	_, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, 
							Suffix, Unique, LinkLvl, Name = 
							string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
					use = Id
					WoWPro.use[k] = use
				end
			end
		
			if use and GetItemInfo(use) then
				row.itembutton:Show() 
				row.itemicon:SetTexture(GetItemIcon(use))
				row.itembutton:SetAttribute("type1", "item")
				row.itembutton:SetAttribute("item1", "item:"..use)
				row.cooldown:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
				row.cooldown:SetScript("OnEvent", function() 
										local start, duration, enabled = GetItemCooldown(use)
										if enabled then
											row.cooldown:Show()
											row.cooldown:SetCooldown(start, duration)
										else row.cooldown:Hide() end
										end)
				local start, duration, enabled = GetItemCooldown(use)
				if enabled then
					row.cooldown:Show()
					row.cooldown:SetCooldown(start, duration)
				else 
					row.cooldown:Hide()
				end
				
				-- setting up item keybindings, if not set for a previous row yet
				if not itemkb and row.itembutton:IsVisible() then
					local key1, key2 = GetBindingKey("CLICK WoWPro_FauxItemButton:LeftButton")
					if key1 then
						SetOverrideBinding(WoWPro.MainFrame, false, key1, "CLICK WoWPro_itembutton"..i..":LeftButton")
					end
					if key2 then
						SetOverrideBinding(WoWPro.MainFrame, false, key2, "CLICK WoWPro_itembutton"..i..":LeftButton")
					end
					itemkb = true
				end
			else 
				row.itembutton:Hide() 
			end
		
			-- Target Button --
			if target then
				row.targetbutton:Show() 
				row.targetbutton:SetAttribute("macrotext", "/cleartarget\n/targetexact "..target
					.."\n/run if not GetRaidTargetIndex('target') == 8 and not UnitIsDead('target') then SetRaidTarget('target', 8) end")
				if use then
					row.targetbutton:SetPoint("TOPRIGHT", row.itembutton, "TOPLEFT", -5, 0)
				else
					row.targetbutton:SetPoint("TOPRIGHT", row, "TOPLEFT", -10, -7)
				end 
				
				-- setting up item keybindings, if not set for a previous row yet
				if not targetkb and row.targetbutton:IsVisible() then
					local key1, key2 = GetBindingKey("CLICK WoWPro_FauxTargetButton:LeftButton")
					if key1 then
						SetOverrideBinding(WoWPro.MainFrame, false, key1, "CLICK WoWPro_targetbutton"..i..":LeftButton")
					end
					if key2 then
						SetOverrideBinding(WoWPro.MainFrame, false, key2, "CLICK WoWPro_targetbutton"..i..":LeftButton")
					end
					targetkb = true
				end
			else
				row.targetbutton:Hide() 
			end
		
			-- Setting the zone for the coordinates of the step --
			if zone then 
				row.zone = zone 
			else 
				row.zone = strtrim(strsplit("(",(strsplit("-",WoWPro.Guides[GID].zone)))) 
			end

			-- Checking for loot items in bags --
			local lootqtyi
			if lootcheck and ( lootitem or action == "B" ) then
				if not WoWPro.sticky[index] then 
					lootcheck = false 
				end
				if not lootitem then
					if GetItemCount(step) > 0 and not completion[k] then 
						WoWPro.CompleteStep(k) 
					end
				end
				lootqtyi = tonumber(lootqty) or 1
				if GetItemCount(lootitem) >= lootqtyi and not completion[k] then 
					WoWPro.CompleteStep(k)
				end
			end

			WoWPro.rows[i] = row
			
			-- move to next row, next step
			i = i + 1
			break
		end
	end
	
	WoWPro.ActiveStickyCount = WoWPro.ActiveStickyCount or 0
	WoWPro.CurrentIndex = WoWPro.rows[1+WoWPro.ActiveStickyCount].index
	-- TODO: check this
	-- WoWPro.Dungeons:UpdateQuestTracker()

	return false
end

-- Left-Click Row Function --
-- TODO: Change this later, changing click behavior depending on action type
-- allow: click here to go to another guide
function WoWPro.Dungeons.RowLeftClick(i)
	local k = WoWPro.rows[i].index
	local QID = WoWPro.QID[k]
	if WoWPro.QID[k] and WoWPro.QuestLog[WoWPro.QID[k]] then
		QuestLog_OpenToQuest(WoWPro.QuestLog[WoWPro.QID[k]].index)
	end
end




-- Event Response Logic --
function WoWPro.Dungeons:EventHandler(self, event, ...)

	-- Receiving the result of the completed quest query --
	if event == "QUEST_QUERY_COMPLETE" then
		WoWPro.Dungeons.db.completedQIDs = resetTable(WoWPro.Dungeons.db.completedQIDs)
		GetQuestsCompleted(WoWPro.Dungeons.db.completedQIDs)
		WoWPro.UpdateGuide()
	end
		
	-- Noting that a quest is being completed for quest log update events --
	if event == "QUEST_COMPLETE" then
		WoWPro.Dungeons.CompletingQuest = true -- what's this???
	end
	
	-- Auto-Completion --

	-- prolly wont be used for dungeons
	-- if event == "CHAT_MSG_SYSTEM" then
		-- WoWPro.Dungeons:AutoCompleteSetHearth(...)
	-- end	
	if event == "CHAT_MSG_LOOT" then
		WoWPro.Dungeons:AutoCompleteLoot(...)
	end	
	if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "MINIMAP_ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
		WoWPro.Dungeons:AutoCompleteZone(...)
		-- include autoload guides options
	end
	if event == "QUEST_LOG_UPDATE" then
		WoWPro.Dungeons:PopulateQuestLog(...)
		WoWPro.Dungeons:AutoCompleteQuestUpdate(...)
		WoWPro.Dungeons:UpdateQuestTracker()
	end	
	-- -- prolly wont be used for dungeons
	-- if event == "UI_INFO_MESSAGE" then
		-- WoWPro.Dungeons:AutoCompleteGetFP(...)
	-- end
	-- if event == "PLAYER_LEVEL_UP" then
		-- WoWPro.Dungeons:AutoCompleteLevel(...)
		-- WoWPro.Dungeons.CheckAvailableSpells(...)
-- --		WoWPro.Dungeons.CheckAvailableTalents()
	-- end
	-- if event == "TRAINER_UPDATE" then
		-- WoWPro.Dungeons.CheckAvailableSpells()
	-- end

end

-- prolly wont be used for dungeons
-- Auto-Complete: Get flight point --
-- function WoWPro.Dungeons:AutoCompleteGetFP(...)
	-- for i = 1,15 do
		-- local index = WoWPro.rows[i].index
		-- if ... == ERR_NEWTAXIPATH and WoWPro.action[index] == "f" then
			-- WoWPro.Dungeons.db.guide[WoWProDB.char.currentguide].completion[index] = true
			-- if not WoWPro.combat then WoWPro:UpdateGuide() end
			-- WoWPro:MapPoint()
		-- end
	-- end
-- end

-- Populate the Quest Log table for other functions to call on --
function WoWPro.Dungeons:PopulateQuestLog()
	if not WoWPro.action then return end -- Not updating if there is no guide loaded.
	
	WoWPro.oldQuests = WoWPro.QuestLog or {} -- what if comes from Leveling module?
	WoWPro.newQuest, WoWPro.missingQuest = false, false
	
	-- Generating the Quest Log table --
	WoWPro.QuestLog = resetTable(WoWPro.QuestLog) -- Reinitiallizing the Quest Log table
	local i, currentHeader = 1, "None"
	local entries = GetNumQuestLogEntries()
	for i=1,tonumber(entries) do
		local questTitle, level, questTag, suggestedGroup, isHeader, 
			isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(i)
		local leaderBoard
		if isHeader then
			currentHeader = questTitle
		else
			if GetNumQuestLeaderBoards(i) and GetQuestLogLeaderBoard(1, i) then
				leaderBoard = {} 
				for j=1,GetNumQuestLeaderBoards(i) do 
					leaderBoard[j] = GetQuestLogLeaderBoard(j, i)
				end 
			else leaderBoard = nil end
			local link, icon, charges = GetQuestLogSpecialItemInfo(i)
			local use
			if link then
				local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, Name = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
				use = Id
			end
			WoWPro.QuestLog[questID] = {
				title = questTitle,
				level = level,
				tag = questTag,
				group = suggestedGroup,
				complete = isComplete,
				daily = isDaily,
				leaderBoard = leaderBoard,
				header = currentHeader,
				use = use,
				index = i
			}
		end
	end
	if WoWPro.oldQuests == {} then return end

	-- Generating table WoWPro.newQuest --
	for QID, questInfo in pairs(WoWPro.QuestLog) do
		if not WoWPro.oldQuests[QID] then 
			WoWPro.newQuest = QID 
			WoWPro:dbp("New Quest: "..WoWPro.QuestLog[QID].title)
		end
	end
	
	-- Generating table WoWPro.missingQuest --
	for QID, questInfo in pairs(WoWPro.oldQuests) do
		if not WoWPro.QuestLog[QID] then 
			WoWPro.missingQuest = QID 
			WoWPro:dbp("Missing Quest: "..WoWPro.oldQuests[QID].title)
		end
	end
	
end

-- Auto-Complete: Quest Update --
function WoWPro.Dungeons:AutoCompleteQuestUpdate()
	local GID = WoWProDB.char.currentguide
	if not GID or not WoWPro.Guides[GID] then return end

	if WoWPro.Dungeons.db.guide then
		for i=1,WoWPro.stepcount do
		
			local action = WoWPro.action[i]
			local QID = WoWPro.QID[i] -- TODO: If QID nil, what happens?
			local completion = WoWPro.Dungeons.db.guide[GID].completion[i]
		
			-- Quest Turn-Ins --
			if WoWPro.Dungeons.CompletingQuest and action == "T" and not completion and WoWPro.missingQuest == QID then
				WoWPro.CompleteStep(i)
				WoWPro.Dungeons.db.completedQIDs[QID] = true
				WoWPro.Dungeons.CompletingQuest = false
			end
			
			-- Abandoned Quests --
			if not WoWPro.Dungeons.CompletingQuest and ( action == "A" or action == "C" ) 
			and completion and WoWPro.missingQuest == QID then
				WoWPro.Dungeons.db.guide[GID].completion[i] = nil
				if not InCombatLockdown() then WoWPro:UpdateGuide() end
				WoWPro:MapPoint()
			end
			
			-- Quest Accepts --
			if WoWPro.newQuest == QID and action == "A" and not completion then
				WoWPro.CompleteStep(i)
			end
			
			-- Quest Completion --
			if WoWPro.QuestLog[QID] and action == "C" and not completion and WoWPro.QuestLog[QID].complete then
				WoWPro.CompleteStep(i)
			end
			
			-- Partial Completion --
			if WoWPro.QuestLog[QID] and WoWPro.QuestLog[QID].leaderBoard and WoWPro.questtext[i] then 
				local numquesttext = select("#", string.split(";", WoWPro.questtext[i]))
				local complete = true
				for l=1,numquesttext do
					local lquesttext = select(numquesttext-l+1, string.split(";", WoWPro.questtext[i]))
					local lcomplete = false
					for _, objective in pairs(WoWPro.QuestLog[QID].leaderBoard) do --Checks each of the quest log objectives
						if lquesttext == objective then --if the objective matches the step's criteria, mark true
							lcomplete = true
						end
					end
					if not lcomplete then complete = false end --if one of the listed objectives isn't complete, then the step is not complete.
				end
				if complete then WoWPro.CompleteStep(i) end --if the step has not been found to be incomplete, run the completion function
			end
		
		end
	
	end
	
	-- First Map Point --
	if WoWPro.Dungeons.FirstMapCall then
		WoWPro:MapPoint()
		WoWPro.Dungeons.FirstMapCall = false
	end
	
end

-- Update Item Tracking --
local function GetLootTrackingInfo(lootitem,lootqty,count)
--[[Purpose: Creates a string containing:
	- tracked item's name
	- how many the user has
	- how many the user needs
	- a complete symbol if the ammount the user has is equal to the ammount they need 
]]
	local track = "" 												--If the function did have a track string, adds a newline
	track = track.." - "..GetItemInfo(lootitem)..": " 	--Adds the item's name to the string
	numinbag = GetItemCount(lootitem)+(count or 1)		--Finds the number in the bag, and adds a count if supplied
	track = track..numinbag										--Adds the number in bag to the string
	track = track.."/"..lootqty								--Adds the total number needed to the string
	if lootqty <= numinbag then
		track = track.." (C)"									--If the user has the requisite number of items, adds a complete marker
	end
	return track													--Returns the track string to the calling function
end

-- Auto-Complete: Loot based --
function WoWPro.Dungeons:AutoCompleteLoot(msg)
	local lootqtyi
	local _, _, itemid, name = msg:find(L["^You .*Hitem:(%d+).*(%[.+%])"])
	local _, _, _, _, count = msg:find(L["^You .*Hitem:(%d+).*(%[.+%]).*x(%d+)."])
	if count == nil then count = 1 end
	for i = 1,1+WoWPro.ActiveStickyCount do
		local index = WoWPro.rows[i].index
		lootqtyi = tonumber(WoWPro.lootqty[index]) or 1
		if WoWProDB.profile.track and WoWPro.lootitem[index] then -- TODO: nao falta ver se WoWPro.lootitem[index] == itemid, etc
			local track = GetLootTrackingInfo(WoWPro.lootitem[index],lootqtyi,count)
			WoWPro.rows[i].track:SetText(strtrim(track))
		end
		if WoWPro.lootitem[index] and WoWPro.lootitem[index] == itemid and GetItemCount(WoWPro.lootitem[index]) + count >= lootqtyi then
			WoWPro.CompleteStep(index)
		end
	end
end

-- prolly wont be used for dungeons			
-- Auto-Complete: Set hearth --
-- function WoWPro.Dungeons:AutoCompleteSetHearth(...)
	-- local msg = ...
	-- local _, _, loc = msg:find(L["(.*) is now your home."])
	-- if loc then
		-- WoWPro.Dungeons.db.guide.hearth = loc
		-- for i = 1,15 do
			-- local index = WoWPro.rows[i].index
			-- if WoWPro.action[index] == "h" and WoWPro.step[index] == loc then
				-- WoWPro.CompleteStep(index)
			-- end
		-- end
	-- end	
-- end

-- Auto-Complete: Zone based --
function WoWPro.Dungeons:AutoCompleteZone()
	WoWPro.ActiveStickyCount = WoWPro.ActiveStickyCount or 0
	local currentindex = WoWPro.rows[1+WoWPro.ActiveStickyCount].index
	local action = WoWPro.action[currentindex]
	local step = WoWPro.step[currentindex]
	local waypcomplete = WoWPro.waypcomplete[currentindex]
	if action == "R" and not waypcomplete then
		local zonetext, subzonetext = GetZoneText(), string.trim(GetSubZoneText())
		if step == zonetext or step == subzonetext then
			WoWPro.CompleteStep(currentindex)
		end
	end
end

-- prolly wont be used for dungeons	
-- Auto-Complete: Level based --
-- function WoWPro.Dungeons:AutoCompleteLevel(...)
	-- local newlevel = ...
	-- if WoWPro.Dungeons.db.guide then
		-- local GID = WoWProDB.char.currentguide
		-- for i=1,WoWPro.stepcount do
			-- if not WoWPro.Dungeons.db.guide[GID].completion[i] 
				-- and WoWPro.level[i] 
				-- and tonumber(WoWPro.level[i]) <= newlevel then
					-- WoWPro.CompleteStep(i)
			-- end
		-- end
	-- end
-- end

-- Update Quest Tracker --
function WoWPro.Dungeons:UpdateQuestTracker()
	local GID = WoWProDB.char.currentguide
	if not GID or not WoWPro.Guides[GID] then return end
	
	for i,row in ipairs(WoWPro.rows) do
		local index = row.index
		local questtext = WoWPro.questtext[index] 
		local action = WoWPro.action[index] 

		local lootitem = WoWPro.lootitem[index] 
		local lootqty = WoWPro.lootqty[index] 
		local QID = WoWPro.QID[index]
		-- Setting up quest tracker --
		row.trackcheck = false
		if WoWProDB.profile.track and ( action == "C" or questtext or lootitem) then
			if WoWPro.QuestLog[QID] and WoWPro.QuestLog[QID].leaderBoard then
				local j = WoWPro.QuestLog[QID].index
				row.trackcheck = true
				if not questtext and action == "C" then
					track = " - "..WoWPro.QuestLog[QID].leaderBoard[1]
					if select(3,GetQuestLogLeaderBoard(1, j)) then
						track =  track.." (C)"
					end
					for l=1,#WoWPro.QuestLog[QID].leaderBoard do 
						if l > 1 then
							track = track.." \n - "..WoWPro.QuestLog[QID].leaderBoard[l]
							if select(3,GetQuestLogLeaderBoard(l, j)) then
								track =  track.." (C)"
							end
						end
					end
				elseif questtext then --Partial completion steps only track pertinent objective.
					local numquesttext = select("#", string.split(";", questtext))
					for l=1,numquesttext do
						local lquesttext = select(numquesttext-l+1, string.split(";", questtext))
						for m=1,GetNumQuestLeaderBoards(j) do 
							if GetQuestLogLeaderBoard(m, j) then
								local _, _, itemName, _, _ = string.find(GetQuestLogLeaderBoard(m, j), "(.*):%s*([%d]+)%s*/%s*([%d]+)");
								if itemName and lquesttext:match(itemName) then
									track = " - "..GetQuestLogLeaderBoard(m, j)
									if select(3,GetQuestLogLeaderBoard(m, j)) then
										track =  track.." (C)"
									end
								end
							end
						end
						row.track:SetText(track)
					end
				end
				if lootitem then
					if tonumber(lootqty) ~= nil then lootqty = tonumber(lootqty) else lootqty = 1 end
					track = GetLootTrackingInfo(lootitem,lootqty)
				end
				row.track:SetText(strtrim(track))
			end
		end
	end
	if not InCombatLockdown() then WoWPro:RowSizeSet(); WoWPro:PaddingSet() end
end

-- Get Currently Available Spells --
-- Deleted, probably not needed


-- Determine Next Active Step (Dungeons Module Specific)--
-- This function is called by the main NextStep function in the core broker --
function WoWPro.Dungeons:NextStep(k, skip)
	local GID = WoWProDB.char.currentguide

	-- Optional Quests --
	if WoWPro.optional[k] and WoWPro.QID[k] then --check this, could be optional non-quest related
		
		-- Checking Quest Log --
		if WoWPro.QuestLog[WoWPro.QID[k]] then 
			skip = false -- If the optional quest is in the quest log, it's NOT skipped --
		end

		-- Checking Prerequisites --
		if WoWPro.prereq[k] then
			skip = false -- defaulting to NOT skipped
			local numprereqs = select("#", string.split(";", WoWPro.prereq[k]))
			for j=1,numprereqs do
				local jprereq = select(numprereqs-j+1, string.split(";", WoWPro.prereq[k]))
				if not WoWPro.Dungeons.db.completedQIDs[tonumber(jprereq)] then 
					skip = true -- If one of the prereqs is NOT complete, step is skipped.
				end
			end
		end
	end

	-- Skipping quests with prerequisites if their prerequisite was skipped --
	if WoWPro.prereq[k] 
	and not WoWPro.Dungeons.db.guide[GID].skipped[k] 
	and not WoWPro.Dungeons.db.skippedQIDs[WoWPro.QID[k]] then 
		local numprereqs = select("#", string.split(";", WoWPro.prereq[k]))
		for j=1,numprereqs do
			local jprereq = select(numprereqs-j+1, string.split(";", WoWPro.prereq[k]))
			if WoWPro.Dungeons.db.skippedQIDs[tonumber(jprereq)] then
				skip = true

				-- If their prerequisite has been skipped, skipping any dependant quests --
				if WoWPro.action[k] == "A" 
				or WoWPro.action[k] == "C" 
				or WoWPro.action[k] == "T" then
					WoWPro.Dungeons.db.skippedQIDs[WoWPro.QID[k]] = true
					WoWPro.Dungeons.db.guide[GID].skipped[k] = true
				else
					WoWPro.Dungeons.db.guide[GID].skipped[k] = true
				end
			end
		end
	end

	return skip
end
