if not _G.InfamyUp then
	_G.InfamyUp = _G.InfamyUp or {}
	InfamyUp.HIGHEST_INF = 25
	InfamyUp._path = ModPath
end

function InfamyTweakData:fill_ranks(rank)
	for i = #self.ranks + 1, rank + 1, 1 do
		table.insert(self.ranks, self:calcInfamyCosts(i))
	end
end

function InfamyTweakData:calcInfamyCosts(rank)
	if rank > InfamyUp.HIGHEST_INF then
		return Application:digest_value(200000000 + math.ceil(math.log(rank - InfamyUp.HIGHEST_INF + 1) * 30000) * 1000, true)
	end
	return Application:digest_value(0, true)
end

local old_init = InfamyTweakData.init

function InfamyTweakData:init()
	old_init(self)
	if Global and Global.experience_manager then
		local rank = Application:digest_value(Global.experience_manager.rank,false)
		self:fill_ranks(rank)
	end
end