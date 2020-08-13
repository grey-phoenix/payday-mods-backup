function PlayerManager:get_infamy_exp_multiplier()
	local multiplier = 1
	if managers.experience:current_rank() > 0 then
		for infamy, item in pairs(tweak_data.infamy.items) do
			if managers.infamy:owned(infamy) and item.upgrades and item.upgrades.infamous_xp then
				multiplier = multiplier + math.abs(item.upgrades.infamous_xp - 1)
			end
		end
	end
	if(managers.experience:current_rank() > InfamyUp.HIGHEST_INF) then
		multiplier = multiplier + (0.05 * (managers.experience:current_rank() - InfamyUp.HIGHEST_INF))
	end
	return multiplier
end