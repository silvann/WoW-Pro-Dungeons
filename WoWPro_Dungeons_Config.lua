--------------------------------------
--      WoWPro_Dungeons_Config      --
--------------------------------------

local L = WoWPro_Locale

local config = LibStub("AceConfig-3.0")
local dialog = LibStub("AceConfigDialog-3.0")

local function createBlizzOptions()

	config:RegisterOptionsTable("WoWPro-Dungeons-Bliz", {
		name = "WoW-Pro Dungeons",
		type = "group",
		args = {
			help = {
				order = 0,
				type = "description",
				name = L["Character-specific settings for the WoW-Pro addon's dungeons module."],
			},
			blank = {
				order = 1,
				type = "description",
				name = " ",
			},  
			enable = {
				order = 2,
				type = "toggle",
				name = L["Enable Module"],
				desc = L["Enables/Disables the dungeons module of the WoW-Pro guide addon."],
				width = "full",
				get = function(info) return WoWPro.Dungeons:IsEnabled() end,
				set = function(info,val)  
						if WoWPro.Dungeons:IsEnabled() then WoWPro.Dungeons:Disable() else WoWPro.Dungeons:Enable() end
					end
			},
		},
	})
	dialog:SetDefaultSize("WoWPro-Dungeons-Bliz", 600, 400)
	dialog:AddToBlizOptions("WoWPro-Dungeons-Bliz", "WoW-Pro Dungeons")

	return blizzPanel
end

function WoWPro.Dungeons:CreateConfig()
	blizzPanel = createBlizzOptions()
	WoWPro.Dungeons:CreateGuideListFrame()
	InterfaceOptions_AddCategory(WoWPro_Dungeons_GuideListFrame)
	-- InterfaceOptions_AddCategory(WoWPro_Dungeons_CurrentGuide)
end
