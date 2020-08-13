local ingredient_dialog = {}
toggle_ingredients_chat = true
ingredient_dialog["pln_rt1_12"] = "Ingredient added" --Comment out the parts of the script you dont want in chat by adding two dashes at the start of the line
ingredient_dialog["pln_rt1_20"] = "Add Muriatic Acid" --Commenting these parts out will stop them from being shown in game
ingredient_dialog["pln_rt1_22"] = "Add Caustic Soda"
ingredient_dialog["pln_rt1_24"] = "Add Hydrogen Chloride"
ingredient_dialog["pln_rt1_28"] = "Meth batch is complete"
ingredient_dialog["pln_rat_stage1_20"] = "Add Muriatic Acid"
ingredient_dialog["pln_rat_stage1_22"] = "Add Caustic Soda"
ingredient_dialog["pln_rat_stage1_24"] = "Add Hydrogen Chloride"
ingredient_dialog["pln_rat_stage1_28"] = "Meth batch is complete"
ingredient_dialog["Play_loc_mex_cook_03"] = "Add Muriatic Acid"
ingredient_dialog["Play_loc_mex_cook_04"] = "Add Caustic Soda"
ingredient_dialog["Play_loc_mex_cook_05"] = "Add Hydrogen Chloride"
ingredient_dialog["Play_loc_mex_cook_13"] = "Meth batch is complete"
ingredient_dialog["Play_loc_mex_cook_17"] = "Meth batch is complete"
ingredient_dialog["Play_loc_mex_cook_22"] = "Ingredient added"



local _queue_dialog_orig = DialogManager.queue_dialog
function DialogManager:queue_dialog(id, ...)
    if ingredient_dialog[id] and toggle_ingredients_chat then
	managers.chat:send_message(ChatManager.GAME, managers.network.account:username() or "Offline", ingredient_dialog[id])
    elseif ingredient_dialog[id] and not toggle_ingredients_chat then
	managers.hud:show_hint({text = ingredient_dialog[id]})
    end
    return _queue_dialog_orig(self, id, ...)
end


