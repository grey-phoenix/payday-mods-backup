local button

local old_node_selected = MenuManager._node_selected

function MenuManager:_node_selected(menu_name, node)
	old_node_selected(self, menu_name, node)
	if type(node) == "table" then
		if node._parameters.name == "lobby" or node._parameters.name == "pause" then
			button:set_enabled(false)
		end
		if node._parameters.name == "main" then
			button:set_enabled(true)
		end
	end
end

function MenuCallbackHandler:become_infamous(params)
	if not self:can_become_infamous() then
		return
	end
	local infamous_cost = Application:digest_value(tweak_data.infamy.ranks[managers.experience:current_rank() + 1], false)
	local yes_clbk = params and params.yes_clbk or false
	local no_clbk = params and params.no_clbk
	local params = {}
	params.cost = managers.experience:cash_string(infamous_cost)
	params.cost2 = managers.experience:cash_string(math.floor(infamous_cost / 4))
	params.free = infamous_cost == 0
	if infamous_cost <= managers.money:offshore() and managers.experience:current_level() >= 100 and math.floor(infamous_cost / 4) <= managers.money:total() then
		function params.yes_func()
			local rank = managers.experience:current_rank() + 1
			managers.menu:open_node("blackmarket_preview_node", {
				{
					back_callback = callback(MenuCallbackHandler, MenuCallbackHandler, "_increase_infamous", yes_clbk)
				}
			})
			local tmpRank = rank % 100
			if tmpRank == 0 then
				tmpRank = 10
			end
			if tmpRank <= InfamyUp.HIGHEST_INF + 1 then
				managers.menu:post_event("infamous_stinger_level_" .. (tmpRank < 10 and "0" or "") .. tostring(tmpRank))
			else
				local sD = ((tmpRank - 1) % 10) + 1
				managers.menu:post_event("infamous_stinger_level_" .. (sD < 10 and "0" or "") .. tostring(sD))
			end
			if tmpRank <= InfamyUp.HIGHEST_INF then
				managers.menu_scene:spawn_infamy_card(tmpRank)
			else
				managers.menu_scene:spawn_infamy_card(1)
			end
		end
	end
	function params.no_func()
		if no_clbk then
			no_clbk()
		end
	end
	managers.menu:show_confirm_become_infamous(params)
end

function MenuCallbackHandler:_increase_infamous(yes_clbk)
	managers.menu_scene:destroy_infamy_card()
	if managers.experience:current_level() < 100 or managers.experience:current_rank() >= #tweak_data.infamy.ranks then
		return
	end
	local rank = managers.experience:current_rank() + 1
	managers.experience:reset()
	managers.experience:set_current_rank(rank)
	local offshore_cost = Application:digest_value(tweak_data.infamy.ranks[rank], false)
	if offshore_cost > 0 then
		if rank < InfamyUp.HIGHEST_INF then
			managers.money:deduct_from_total(managers.money:total())
		else
			managers.money:deduct_from_total(math.floor(offshore_cost / 4))
		end
		managers.money:deduct_from_offshore(offshore_cost)
	end
	managers.skilltree:infamy_reset()
	managers.blackmarket:reset_equipped()
	if managers.menu_component then
		managers.menu_component:refresh_player_profile_gui()
	end
	local logic = managers.menu:active_menu().logic
	if logic then
		logic:refresh_node()
		logic:select_item("crimenet")
	end
	managers.savefile:save_progress()
	managers.savefile:save_setting(true)
	managers.menu:post_event("infamous_player_join_stinger")
	if yes_clbk then
		yes_clbk()
	end
	if SystemInfo:distribution() == Idstring("STEAM") then
		managers.statistics:publish_level_to_steam()
	end
end


---------------------------------------------- Localization ------------------------------------------------



Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_InfamyUp", function(loc)

	for _, filename in pairs(file.GetFiles(InfamyUp._path .. "loc/")) do
		local str = filename:match('^(.*).txt$')
		if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
			loc:load_localization_file(InfamyUp._path .. "loc/" .. filename)
			break
		end
	end

	loc:load_localization_file(InfamyUp._path .. "loc/english.txt", false)
end)

---------------------------------------------- Undo -------------------------------------------------------
Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_InfamyUp", function(menu_manager)

	function MenuCallbackHandler:set_back_infamy_warning()
		local dialog_data = {}
		if managers.experience:current_rank() <= InfamyUp.HIGHEST_INF then
				dialog_data.title = string.upper(managers.localization:text("dialog_error_title"))
				dialog_data.text = managers.localization:text("infamy_up_not_enough", {
					level = InfamyUp.HIGHEST_INF
				})
				
				local ok_button = {}
				ok_button.text = managers.localization:text("dialog_ok")
				ok_button.callback_func = callback(self, self, "_dialog_clear_progress_no")
				ok_button.cancel_button = true
				dialog_data.button_list = {ok_button}
				managers.system_menu:show(dialog_data)
				return
		end
		dialog_data.title = string.upper(managers.localization:text("dialog_warning_title"))
		dialog_data.text = managers.localization:text("infamy_up_reset_warning", {
					level = InfamyUp.HIGHEST_INF
				})
		local yes_button = {}
		yes_button.text = managers.localization:text("dialog_yes")
		yes_button.callback_func = callback(self, self, "set_back_infamy_callback")
		local no_button = {}
		no_button.text = managers.localization:text("dialog_no")
		no_button.callback_func = callback(self, self, "_dialog_clear_progress_no")
		no_button.cancel_button = true
		dialog_data.button_list = {yes_button, no_button}
		managers.system_menu:show(dialog_data)
	end

	MenuCallbackHandler.set_back_infamy_callback = function(this,item)
		managers.menu_scene:destroy_infamy_card()
		managers.menu_scene:set_character_equipped_card(nil,InfamyUp.HIGHEST_INF - 1)
		local totalcash = 0
		local offshore = 0
		for i = managers.experience:current_rank(), InfamyUp.HIGHEST_INF + 1, -1 do
			local cash = Application:digest_value(tweak_data.infamy:calcInfamyCosts(i), false)
			totalcash = totalcash + math.floor(cash / 4)
			offshore = offshore + cash
		end
		managers.money:deduct_from_total(-totalcash)
		managers.money:deduct_from_offshore(-offshore)

		managers.experience:set_current_rank(InfamyUp.HIGHEST_INF)
		if managers.menu_component then
			managers.menu_component:refresh_player_profile_gui()
		end
		managers.savefile:save_progress()
		managers.savefile:save_setting(true)
		managers.menu:post_event("infamous_player_join_stinger")
	end

	Hooks:Add("MenuManagerBuildCustomMenus", "Base_BuildCustomMenuss_InfamyUp", function(menu_manager, nodes)
		if nodes.options then
			button=nodes.options:create_item(nil, {
				name="infamyUp_reset",
				text_id= "infamy_up_reset_button",
				help_id= "infamy_up_reset_button_desc",
				callback="set_back_infamy_warning"
				})
			nodes.options:add_item(button)
		end
	end)

end)