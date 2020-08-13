local old_set_card = MenuSceneManager.set_character_equipped_card


function MenuSceneManager:set_character_equipped_card(unit, card)
	card = card % 100
	if card >= InfamyUp.HIGHEST_INF then
		card = 0
	end
	old_set_card(self,unit,card)
end

function MenuSceneManager:set_character_card(peer_id, rank, unit)
	if rank and rank > 0 then
		local state = unit:play_redirect(Idstring("idle_menu"))
		unit:anim_state_machine():set_parameter(state, "husk_card" .. peer_id, 1)
		local card = rank - 1
		card = card % 100
		if card >= InfamyUp.HIGHEST_INF then
			card = 0
		end
		local card_unit = World:spawn_unit(Idstring("units/menu/menu_scene/infamy_card"), Vector3(0, 0, 0), Rotation(0, 0, 0))
		card_unit:damage():run_sequence_simple("enable_card_" .. (card < 10 and "0" or "") .. tostring(math.min(card, 24)))
		unit:link(Idstring("a_weapon_left_front"), card_unit, card_unit:orientation_object():name())
		self:_delete_character_weapon(unit, "secondary")
		self._card_units = self._card_units or {}
		self._card_units[unit:key()] = card_unit
	end
end