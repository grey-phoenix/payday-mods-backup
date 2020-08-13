function MenuManager:show_confirm_become_infamous(params)
	local dialog_data = {}
	dialog_data.title = managers.localization:text("dialog_become_infamous")
	local no_button = {}
	no_button.callback_func = params.no_func
	no_button.cancel_button = true
	if params.yes_func then
		no_button.text = managers.localization:text("dialog_no")
		local yes_button = {}
		yes_button.text = managers.localization:text("dialog_yes")
		yes_button.callback_func = params.yes_func
		if managers.experience:current_rank() < InfamyUp.HIGHEST_INF then
			dialog_data.text = managers.localization:text(managers.experience:current_rank() < 5 and "menu_dialog_become_infamous" or "menu_dialog_become_infamous_above_5", {
				level = 100,
				cash = params.cost
			})
		else
			dialog_data.text = managers.localization:text("infamy_up_increase_infamy_warning", {
				level = InfamyUp.HIGHEST_INF,
				offshore = params.cost,
				cash = params.cost2
			})
		end
		dialog_data.focus_button = 2
		dialog_data.button_list = {yes_button, no_button}
		local got_usable_primary_weapon = managers.blackmarket:check_will_have_free_slot("primaries")
		local got_usable_secondary_weapon = managers.blackmarket:check_will_have_free_slot("secondaries")
		local add_weapon_replace_warning = not got_usable_primary_weapon or not got_usable_secondary_weapon
		if add_weapon_replace_warning then
			local primary_weapon = managers.blackmarket:get_crafted_category_slot("primaries", 1)
			local secondary_weapon = managers.blackmarket:get_crafted_category_slot("secondaries", 1)
			local warning_text_id = "menu_dialog_warning_infamy_replace_pri_sec"
			if got_usable_primary_weapon then
				warning_text_id = "menu_dialog_warning_infamy_replace_secondary"
			elseif got_usable_secondary_weapon then
				warning_text_id = "menu_dialog_warning_infamy_replace_primary"
			end
			local params = {
				primary = primary_weapon and managers.localization:to_upper_text(tweak_data.weapon[primary_weapon.weapon_id].name_id),
				secondary = secondary_weapon and managers.localization:to_upper_text(tweak_data.weapon[secondary_weapon.weapon_id].name_id),
				amcar = managers.localization:to_upper_text(tweak_data.weapon.amcar.name_id),
				glock_17 = managers.localization:to_upper_text(tweak_data.weapon.glock_17.name_id)
			}
			dialog_data.text = dialog_data.text .. [[


]] .. managers.localization:text(warning_text_id, params)
		end
	else
		no_button.text = managers.localization:text("dialog_ok")
		if managers.experience:current_rank() < InfamyUp.HIGHEST_INF then
			dialog_data.text = managers.localization:text("menu_dialog_become_infamous_no_cash", {
				cash = params.cost
			})
		else
			dialog_data.text = managers.localization:text("infamy_up_increase_infamy_no_cash", {
				offshore = params.cost,
				cash = params.cost2,
				level = managers.experience:current_rank() + 1
			})
		end
		dialog_data.focus_button = 1
		dialog_data.button_list = {no_button}
	end
	dialog_data.w = 620
	dialog_data.h = 500
	managers.system_menu:show_new_unlock(dialog_data)
end