toggle_ingredients_chat = not toggle_ingredients_chat
if toggle_ingredients_chat then
    managers.hud:show_hint({text = "Chat mode on"})
elseif not toggle_ingredients_chat then
    managers.hud:show_hint({text = "Silent mode on"})
end