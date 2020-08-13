--Original mod by 90e, uploaded by DarKobalt.
--Reverb fixed by Doctor Mister Cool, aka Didn'tMeltCables, aka DinoMegaCool
--New version uploaded and maintained by Offyerrocker.
--At this point all of my previous code is bad and obsolete yay


local afsf_blacklist = {
	["saw"] = true,
	["saw_secondary"] = true,
	["flamethrower_mk2"] = true,
	["m134"] = true,
	["mg42"] = true,
	["shuno"] = true
}
--This blacklist defines which weapons are prevented from playing their single-fire sound in AFSF.
	--Weapons not on this list will repeatedly play their single-fire sound rather than their auto-fire loop.
	--Weapons on this list will play their sound as normal
	-- either due to being an unconventional weapon (saw, flamethrower, other saw), or lacking a singlefire sound (minigun, mg42, other minigun).
--I could define this in the function but meh	
	

--Check for manual blacklist.
--If check passed, check for if the weapon has a singlefire sound to play
--This is both for future-proofing and for custom weapon support, I think. I'm actually not sure which part of AFSF fixes custom weapon sounds otherwise
function RaycastWeaponBase:_soundfix_should_play_normal()
	name_id = self:get_name_id() or "xX69dank420blazermachineXx" --if somehow get_name_id() returns nil, crashing won't be my fault. though i guess you'll have bigger problems in that case. also you'll look dank af B)
	if not self._setup.user_unit == managers.player:player_unit() then
		return true
	elseif afsf_blacklist[name_id] then
--		OffyLib:c_log("Weapon " .. name_id .. " is blacklisted")
		return true
	elseif not tweak_data.weapon[name_id].sounds.fire_single then
--		OffyLib:c_log("Weapon " .. name_id .. " has no singlefire sound")
	--doesn't seem to be necessary to check for underbarrel gadget override via self:gadget_overrides_weapon_functions() anymore
		return true
	end
--	OffyLib:c_log("Weapon " .. name_id .. " is not blacklisted")
end


--Prevent playing sounds except for blacklisted weapons
local orig_fire_sound = RaycastWeaponBase._fire_sound
function RaycastWeaponBase:_fire_sound()
	if self:_soundfix_should_play_normal() then --afsf_blacklist[self:get_name_id()] then
		orig_fire_sound(self)
	end
end

--Play sounds here for non-blacklisted weapons; or else if blacklisted, use original function
local orig_fire = RaycastWeaponBase.fire
function RaycastWeaponBase:fire(...)
	local result = orig_fire(self, ...)
	if self:_soundfix_should_play_normal() then --afsf_blacklist[name_id] then
		return result
	end

	if result and self._setup.user_unit == managers.player:player_unit() then
		self:play_tweak_data_sound("fire_single","fire")
		self:play_tweak_data_sound("stop_fire") --i don't know why this still caused reverb for me when i tried it initially
	end

	return result
end

local orig_stop_shooting = RaycastWeaponBase.stop_shooting
function RaycastWeaponBase:stop_shooting()
	if self:_soundfix_should_play_normal() then
		orig_stop_shooting(self)
	end
end

--previous conditions:
	--1.lacking a singlefire sound
	--2.currently in gadget override such as underbarrel mode
	--3.minigun and mg42 will have a silent fire sound if not blacklisted
	--4. is NPC. Not sure why this started crashing now though, since that was fixed in v1 of AFSF2
