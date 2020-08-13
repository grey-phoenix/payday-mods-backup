local old_load = ExperienceManager.load

function ExperienceManager:load(data)
	old_load(self,data)
	local rank = Application:digest_value(self._global.rank, false)
	tweak_data.infamy:fill_ranks(rank)
end

function ExperienceManager:set_current_rank(value)
	tweak_data.infamy:fill_ranks(value)
	managers.infamy:aquire_point()
	self._global.rank = Application:digest_value(value, true)
	self:_check_achievements()
	self:update_progress()
end

function ExperienceManager:rank_string(rank)
	local roman = ""
	
	while rank >= 1000 do
		roman = roman .. "M"
		rank = rank - 1000
	end

	if rank >= 900 then
		roman = roman .. "CM"
		rank = rank - 900
	end
	if rank >= 500 then
		roman = roman .. "D"
		rank = rank - 500
	end
	if rank >= 400 then
		roman = roman .. "CD"
		rank = rank - 400
	end

	while rank >= 100 do
		roman = roman .. "C"
		rank = rank - 100
	end
	if rank >= 90 then
		roman = roman .. "XC"
		rank = rank - 90
	end
	if rank >= 50 then
		roman = roman .. "L"
		rank = rank - 50
	end
	if rank >= 40 then
		roman = roman .. "XL"
		rank = rank - 40
	end

	while rank >= 10 do
		roman = roman .. "X"
		rank = rank - 10
	end
	if rank >= 9 then
		roman = roman .. "IX"
		rank = rank - 9
	end
	if rank >= 5 then
		roman = roman .. "V"
		rank = rank - 5
	end
	if rank >= 4 then
		roman = roman .. "IV"
		rank = rank - 4
	end

	while rank > 0 do
		roman = roman .. "I"
		rank = rank - 1
	end

	return roman
end