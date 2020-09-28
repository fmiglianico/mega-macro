local LibActionButton

local function ShowTooltipForButton(action)
    local actionType, macroIndex = GetActionInfo(action)

    if actionType == "macro" then
        if macroIndex <= MacroLimits.MaxGlobalMacros and not MegaMacroGlobalData.Activated or macroIndex > MacroLimits.MaxGlobalMacros and not MegaMacroCharacterData.Activated then
            return
        end

        local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)

        if macroId then
			local macro = MegaMacro.GetById(macroId)
			if macro then
				ShowToolTipForMegaMacro(macro)
			end
        end
    end
end

MegaMacroBartender4ActionBarProvider = {}

function MegaMacroBartender4ActionBarProvider.Initialize()
	LibActionButton = LibStub("LibActionButton-1.0")
end

function MegaMacroBartender4ActionBarProvider.Update()
    local focus = GetMouseFocus()

    for i=1, 120 do
        local buttonName = "BT4Button"..i
        local button = _G[buttonName]

        if button then
            local action = ActionButton_CalculateAction(button)
            MegaMacroActionBarEngine.SetIconBasedOnAction(button, button.icon, action)

            if focus == button then
                ShowTooltipForButton(action)
            end
        end
	end

	-- forcing cooldowns, charges and usable to update each frame
	local libActionButtonOnEvent = LibActionButton.eventFrame:GetScript("OnEvent")
	libActionButtonOnEvent(LibActionButton.eventFrame, "ACTIONBAR_UPDATE_COOLDOWN", nil)
	libActionButtonOnEvent(LibActionButton.eventFrame, "SPELL_UPDATE_CHARGES", nil)
	libActionButtonOnEvent(LibActionButton.eventFrame, "ACTIONBAR_UPDATE_USABLE", nil)
end