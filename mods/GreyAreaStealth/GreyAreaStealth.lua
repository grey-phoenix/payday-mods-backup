-- Mod is effectively Silent Assassin with scope creep

-- Future Ideas: pager fail chance, finish stealth score, waypoints, no pager disconnect, 
-- Some references
-- -- https://www.unknowncheats.me/forum/payday-2-a/98503-collection-lua-script-snippets.html
-- -- https://www.unknowncheats.me/forum/payday-2-a/322033-lua-scripts-snippets-collection-create-requests-updated-28-03-2020-a.html

-- Bodybags isn't working and can be added into options:
-- {
	-- "type" : "toggle",
	-- "id"   : "sa_infinite_bodybags_enabled",
	-- "title": "sa_infinite_bodybags_enabled_title",
	-- "description" : "sa_infinite_bodybags_enabled_desc",
	-- "callback" : "GreyAreaStealth_enabledInfiniteBodyBagsToggle",
	-- "value" : "infinite_bodybags_enabled",
	-- "default_value" : false
-- },

if not GlobalScriptInitialized then
    GlobalScriptInitialized = true

	function inStealth()
		if not managers or not managers.groupai or managers.groupai:state():whisper_mode() then
			return true
		else
			return false
		end
	end

    -- IS PLAYING CHECK
    function isPlaying()
        if not BaseNetworkHandler or not game_state_machine then return false end
        return BaseNetworkHandler._gamestate_filter.any_ingame_playing[ game_state_machine:last_queued_state_name() ]
    end
   
    -- IS LOADING CHECK
    function isLoading()
        if not BaseNetworkHandler then return false end
        return BaseNetworkHandler._gamestate_filter.waiting_for_players[ game_state_machine:last_queued_state_name() ]
    end

    -- SERVER CHECK    
    function isServer()
        if not Network then return false end
        return Network:is_server()
    end

    -- CLIENT CHECK
    function isClient()
        if not Network then return false end
        return Network:is_client()
    end

    -- HOST CHECK
    function isHost()
        if not Network then return false end
        return not Network:is_client()
    end

    -- IS SINGLEPLAYER
    function isSinglePlayer()
        return Global.game_settings.single_player or false
    end

    -- IN CUSTODY
    function inCustody()
        local player = managers.player:local_player()
        local in_custody = false
        if managers and managers.trade and alive( player ) then
            in_custody = managers.trade:is_peer_in_custody(managers.network:session():local_peer():id())
        end
        return in_custody
    end

	-- INGAME CHECK
    function inGame()
        if not game_state_machine then return false end
        return string.find(game_state_machine:current_state_name(), "game")
    end
end

-------------------------------------------------
--  Lifecycle Logic
-------------------------------------------------
_G.GreyAreaStealth = _G.GreyAreaStealth or {}
GreyAreaStealth._path = ModPath
GreyAreaStealth._loc_path = ModPath .. "loc/"
GreyAreaStealth._data_path = SavePath .. "GreyAreaStealth.txt"
GreyAreaStealth.settings = {}
GreyAreaStealth.settingsLoaded = false
-- I can't get at the player unit at the end game screen. (or at least I don't
-- know how)  So store the local pagers used here.  It'll be easier if I end
-- up having to sync the pagers used to the clients anyway.
GreyAreaStealth.localPagersUsed = 0
 
--Loads the options from blt
function GreyAreaStealth:Load()
    --log(debug.traceback())
	self.settings["pacifier_enabled"] = true
	self.settings["eager_hostages_enabled"] = true
	self.settings["infinite_zips_enabled"] = false
	self.settings["stealth_drill_mult"] = 1
    self.settings["stealth_drill_max"] = 7
	self.settings["no_stealth_fall_damage_enabled"] = false
	self.settings["infinite_bodybags_enabled"] = false
    self.settings["pager_mods_enabled"] = false
    self.settings["num_pagers"] = 5
    self.settings["num_pagers_per_player"] = 5
    self.settings["stealth_kill_enabled"] = true
    self.settings["pager_bonus_enabled"] = false
    self.settings["pager_detection_threshold"] = 1
	self.settings["no_dom_cop_pager"] = true
    self.settings["matchmaking_filter"] = 1
    self.settings["no_drill_jams_enabled"] = false

	GreyAreaStealth.settingsLoaded = true

    local file = io.open(self._data_path, "r")
    if (file) then
        for k, v in pairs(json.decode(file:read("*all"))) do
            self.settings[k] = v
        end
    end

    -- log("In Load " .. json.encode(self.settings))
end

function GreyAreaStealth:LoadIfNeeded()
	if not GreyAreaStealth.settingsLoaded then
		GreyAreaStealth:Load()
	end
end

--Saves the options
function GreyAreaStealth:Save()
    --log("In save " .. json.encode(self.settings))
    local file = io.open(self._data_path, "w+")
    if file then
        file:write(json.encode(self.settings))
        file:close()
    end
end

--Loads the data table for the menuing system.  Menus are
--ones based
function GreyAreaStealth:getCompleteTable()
    local tbl = {}
    for i, v in pairs(GreyAreaStealth.settings) do
        if i == "pager_detection_threshold" then
            tbl[i] = v * 100
        else
            tbl[i] = v
        end
    end

    return tbl
end

-------------------------------------------------
-- Various setters
-------------------------------------------------
function setNumPagers(this, item)
    GreyAreaStealth.settings["num_pagers"] = item:value()
end

function setNumPagersPerPlayer(this, item)
    GreyAreaStealth.settings["num_pagers_per_player"] = item:value()
end

function setStealthDrillMult(this, item)
    GreyAreaStealth.settings["stealth_drill_mult"] = item:value()
end

function setStealthDrillMax(this, item)
	GreyAreaStealth.settings["stealth_drill_max"] = item:value()
end
	
function setNoDrillJamsEnabled(this, item)
    local value = item:value() == "on" and true or false
    GreyAreaStealth.settings["no_drill_jams_enabled"] = value
end

function setNoEagerHostageEnabled(this, item)
    local value = item:value() == "on" and true or false
    GreyAreaStealth.settings["eager_hostages_enabled"] = value
end

function setNoStealthFallDamageEnabled(this, item)
    local value = item:value() == "on" and true or false
    GreyAreaStealth.settings["no_stealth_fall_damage_enabled"] = value
end

function setNoDomCopPagerEnabled(this, item)
    local value = item:value() == "on" and true or false
    GreyAreaStealth.settings["no_dom_cop_pager"] = value
end

function setPagerModsEnabled(this, item)
    local value = item:value() == "on" and true or false
    GreyAreaStealth.settings["pager_mods_enabled"] = value
end

function setInfiniteZipsEnabled(this, item)
    local value = item:value() == "on" and true or false
    GreyAreaStealth.settings["infinite_zips_enabled"] = value
end

function setBodyBagsEnabled(this, item)
    local value = item:value() == "on" and true or false
    GreyAreaStealth.settings["infinite_bodybags_enabled"] = value
end

function setPacifierEnabled(this, item)
    local value = item:value() == "on" and true or false
    GreyAreaStealth.settings["pacifier_enabled"] = value
end

function setStealthKillEnabled(this, item)
    local value = item:value() == "on" and true or false
    GreyAreaStealth.settings["stealth_kill_enabled"] = value
end

function setMatchmakingFilter(this, item)
    --log ("setMatchmakingFilter" .. tostring(item:value()))
    GreyAreaStealth.settings["matchmaking_filter"] = item:value()
end

function setEnablePagerBonusToggle(this, item)
    local value = item:value() == "on" and true or false
    GreyAreaStealth.settings["pager_bonus_enabled"] = value
end

function setPagerDetectionThreshold(this, item)
    local value = item:value() / 100
    GreyAreaStealth.settings["pager_detection_threshold"] = value
end

-------------------------------------------------
-- Load locatization strings
-------------------------------------------------
Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_GreyAreaStealth", function(loc)
    --More or less cribbed from WolfHUD
    --Detect ChnMod to select chinese (simplified) locale
    local lang
    for _, mod in pairs(BLT and BLT.Mods:Mods() or {}) do
        if mod:GetName() == "ChnMod" and mod:IsEnabled() then
            lang = "zh-cn"
        end
    end

    if not lang then
        for _, filename in pairs(file.GetFiles(GreyAreaStealth._loc_path )) do
            local str = filename:match('^(.*).json$')
            if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
                lang = str
                break
            end
        end
    end

    if not lang then
        lang = "english"
    end

    --check to see if the locale file for the language exists.  If so, use it.
    --otherwise, default to English
    local path = GreyAreaStealth._loc_path .. lang .. ".json"
    --log("checking " .. path)
    if io.file_is_readable(path) then
        --log("loading " .. path)
        loc:load_localization_file(path)
    else
        --log("defaulting to english")
        loc:load_localization_file(GreyAreaStealth._loc_path.."english.json")
    end
end)

-------------------------------------------------
-- Set up the menu
-------------------------------------------------
Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_GreyAreaStealth", function(menu_manager)
    MenuCallbackHandler.GreyAreaStealth_setNumPagers = setNumPagers
    MenuCallbackHandler.GreyAreaStealth_setNumPagersPerPlayer = setNumPagersPerPlayer
    MenuCallbackHandler.GreyAreaStealth_enablePagerModsToggle = setPagerModsEnabled
	MenuCallbackHandler.GreyAreaStealth_setStealthDrillMult = setStealthDrillMult
    MenuCallbackHandler.GreyAreaStealth_enabledPacifierToggle = setPacifierEnabled
	MenuCallbackHandler.GreyAreaStealth_setStealthDrillMax = setStealthDrillMax
    MenuCallbackHandler.GreyAreaStealth_killPagerEnabledToggle = setStealthKillEnabled
    MenuCallbackHandler.GreyAreaStealth_enablePagerBonusToggle = setEnablePagerBonusToggle
    MenuCallbackHandler.GreyAreaStealth_setMatchmakingFilter = setMatchmakingFilter
    MenuCallbackHandler.GreyAreaStealth_setPagerDetectionThreshold = setPagerDetectionThreshold
    MenuCallbackHandler.GreyAreaStealth_enabledInfiniteZipsToggle = setInfiniteZipsEnabled
    MenuCallbackHandler.GreyAreaStealth_enabledInfiniteBodyBagsToggle = setBodyBagsEnabled
	MenuCallbackHandler.GreyAreaStealth_enabledNoDomCopPagerToggle = setNoDomCopPagerEnabled
	MenuCallbackHandler.GreyAreaStealth_enabledNoStealthFallDamageToggle = setNoStealthFallDamageEnabled
	MenuCallbackHandler.GreyAreaStealth_enabledEagerHostageToggle = setNoEagerHostageEnabled
	MenuCallbackHandler.GreyAreaStealth_enabledNoDrillJamsToggle = setNoDrillJamsEnabled

    MenuCallbackHandler.GreyAreaStealth_Close = function(this)
        GreyAreaStealth:Save()
    end

	GreyAreaStealth:LoadIfNeeded()
    MenuHelper:LoadFromJsonFile(GreyAreaStealth._path.."options.txt", GreyAreaStealth, GreyAreaStealth:getCompleteTable())
end)

-------------------------------------------------
-- Various getters
-------------------------------------------------
function isNoDrillJamsEnabled()
	GreyAreaStealth:LoadIfNeeded()
    return GreyAreaStealth.settings["no_drill_jams_enabled"]
end

function isNoDomCopPagerEnabled()
	GreyAreaStealth:LoadIfNeeded()
    return GreyAreaStealth.settings["no_dom_cop_pager"]
end

function isEagerHostageEnabled()
	GreyAreaStealth:LoadIfNeeded()
    return GreyAreaStealth.settings["eager_hostages_enabled"]
end

function isNoStealthFallDamageEnabled()
	GreyAreaStealth:LoadIfNeeded()
    return GreyAreaStealth.settings["no_stealth_fall_damage_enabled"]
end

function isInfiniteZipsEnabled()
	GreyAreaStealth:LoadIfNeeded()
    return GreyAreaStealth.settings["infinite_zips_enabled"]
end

function getNumPagersPerPlayer()
	GreyAreaStealth:LoadIfNeeded()

	-- This is brittle, but the menu returns the index of the option selected and you can't natively associate a value.
	local val = GreyAreaStealth.settings["num_pagers_per_player"]

	local res = 100
	if val == 1 then res = 0
	elseif val == 2 then res = 1
	elseif val == 3 then res = 2
	elseif val == 4 then res = 3
	elseif val == 5 then res = 4
	elseif val == 6 then res = 5
	elseif val == 7 then res = 6
	elseif val == 8 then res = 7
	elseif val == 9 then res = 8
	elseif val == 10 then res = 9
	elseif val == 11 then res = 10
	elseif val == 12 then res = 100
	end

	return res
end

function getNumPagers()
	GreyAreaStealth:LoadIfNeeded()

	-- This is brittle, but the menu returns the index of the option selected and you can't natively associate a value.
	local val = GreyAreaStealth.settings["num_pagers"]

	local res = 100
	if val == 1 then res = 0
	elseif val == 2 then res = 1
	elseif val == 3 then res = 2
	elseif val == 4 then res = 3
	elseif val == 5 then res = 4
	elseif val == 6 then res = 5
	elseif val == 7 then res = 6
	elseif val == 8 then res = 7
	elseif val == 9 then res = 8
	elseif val == 10 then res = 9
	elseif val == 11 then res = 10
	elseif val == 12 then res = 100
	end

	return res
end

function getStealthDrillMax()
	GreyAreaStealth:LoadIfNeeded()
	
	-- This is brittle, but the menu returns the index of the option selected and you can't natively associate a value.
	local val = GreyAreaStealth.settings["stealth_drill_max"]

	local res = 2000
	if val == 1 then res = 30
	elseif val == 2 then res = 60
	elseif val == 3 then res = 120
	elseif val == 4 then res = 180
	elseif val == 5 then res = 240
	elseif val == 6 then res = 300
	end

	return res
end

function getStealthDrillMult()
	GreyAreaStealth:LoadIfNeeded()
    return GreyAreaStealth.settings["stealth_drill_mult"] or 1
end

function getEffectiveNumPagersPerPlayer()
    local numPerPlayer = getNumPagersPerPlayer()
    local numPagers = getNumPagers()
    local numPlayers = managers.network:session():amount_of_players()

    --If we're set to 2 pagers total, 1 per player, but there is only one
    --player, then effectively we're set to 1 pager.  But it's a pain to
    --keep changing settings based on number of players.  So set this to be
    --the larger of
    --
    --  The number of pagers per player
    --  the number of pagers total / number of players, rounded up
    --
    --log("numPerPlayer " .. tostring(numPerPlayer))
    --log("numPagers " .. tostring(numPagers))
    --log("numPlayers " .. tostring(numPlayers))
    local effectivePerPlayer = math.max(numPerPlayer, math.ceil(numPagers / numPlayers))
    --log("Effective number per player is " .. tostring(effectivePerPlayer))
    return effectivePerPlayer
end

function arePagerModsEnabled()
	GreyAreaStealth:LoadIfNeeded()
    return GreyAreaStealth.settings["pager_mods_enabled"]
end

function isPacifierEnabled()
	GreyAreaStealth:LoadIfNeeded()
    return GreyAreaStealth.settings["pacifier_enabled"]
end

function isBodyBagsEnabled()
	GreyAreaStealth:LoadIfNeeded()
    return GreyAreaStealth.settings["infinite_bodybags_enabled"]
end

function isStealthKillEnabled()
	GreyAreaStealth:LoadIfNeeded()
    return GreyAreaStealth.settings["stealth_kill_enabled"]
end

function getPagerDetectionThreshold()
	GreyAreaStealth:LoadIfNeeded()
    return GreyAreaStealth.settings["pager_detection_threshold"]
end

function getMatchmakingFilter()
	GreyAreaStealth:LoadIfNeeded()
    --log ("getMatchmakingFilter " .. tostring(GreyAreaStealth.settings["matchmaking_filter"]))
    return GreyAreaStealth.settings["matchmaking_filter"]
end


function addLocalPagerAnswered()
    --log("Answered pager locally")
    GreyAreaStealth.localPagersUsed = GreyAreaStealth.localPagersUsed + 1
end

function getLocalPagersAnswered()
    return GreyAreaStealth.localPagersUsed
end



-------------------------------------------------------------------------------------------------------
-- Beginning of mod implementations
-------------------------------------------------------------------------------------------------------

-------------------------------------------------
--  Stealth kill and Hostage logic
-------------------------------------------------
if RequiredScript == "lib/units/enemies/cop/copbrain" then
	-- log("eager hostage state" .. tostring(isEagerHostageEnabled()))

	-- Infinite hostage follower distance and hostage followers -- Author: DvD
	if not old_set_objective then old_set_objective = CopBrain.set_objective end
	if not old_nr_following_hostages then old_nr_following_hostages = tweak_data.player.max_nr_following_hostages end

	if inStealth() and isEagerHostageEnabled() then
		function CopBrain:set_objective(new_objective, params)
			if new_objective and new_objective.lose_track_dis then new_objective.lose_track_dis = 5000000 end
			old_set_objective(self, new_objective, params)
		end

		tweak_data.player.max_nr_following_hostages = 1000
	else
		CopBrain.set_objective = old_set_objective
		tweak_data.player.max_nr_following_hostages = old_nr_following_hostages
	end
	-------------------------------------------------------------------------------------------------------------------------------


    if not _CopBrain_clbk_damage then
        _CopBrain_clbk_damage = CopBrain._clbk_damage
    end

    function CopBrain:clbk_damage(my_unit, damage_info)
        --log ("CopBrain:clbk_damage")
        if _CopBrain_clbk_damage then 
            --this seems to get called on damage but not on death
            --So if we take any non-fatal damage, the pager will go off
            --log ("non-fatal damage")
            self._cop_pager_ready = true
            _CopBrain_clbk_damage(self, my_unit, damage_info)
            --log ("made parent callback")
        end
    end

    if not _CopBrain_clbk_death then
        _CopBrain_clbk_death = CopBrain.clbk_death
    end
    function CopBrain:clbk_death(my_unit, damage_info)
        --log ("clbk_death")
        if inStealth() then 
            --for i, key in pairs(self._logic_data.detected_attention_objects) do
                --log("value is " .. tostring(i) .. ", " .. tostring(key))
                --for f, s in pairs(key) do
                    --log("inner is " .. tostring(f) .. ", " .. tostring(s))
                --end
            --end
            --log ("clbk_death2")
            if arePagerModsEnabled() and isStealthKillEnabled() then


                local head
            --log ("damage_info is " .. json.encode(damage_info))
                if damage_info.col_ray then 
                    --the idea was to require a headshot.  It turns out that col_ray is not
                    --set when the client takes the shot so I can only do OHKs on clients.
                    --I figure to make things fair it should be OHKs for everyone
                    --head = self._unit:character_damage()._head_body_name and damage_info.col_ray.body and damage_info.col_ray.body:name() == self._unit:character_damage()._ids_head_body_name
                    head = true
                else
                    --OHK keeps the pager from going ff
                    head = true
                end
                if not head then
                    --log ("enabling pager")
                    --not headshots will cause the pager to go off
                    self._cop_pager_ready = true
                end

                local notice_progress = 0;
                if self._logic_data.detected_attention_objects then
                    for key, obj in pairs(self._logic_data.detected_attention_objects) do
                        if obj.notice_progress then
                            notice_progress = math.max(notice_progress, obj.notice_progress)
                        end
                    end
                end
                --log("notice progress was " .. tostring(notice_progress))
                if notice_progress > getPagerDetectionThreshold() then
                    --log("notice was too high")
                    self._cop_pager_ready = true
                end
                --if self._cop_pager_ready then
                    --log("_cop_pager_ready is true")
                --end

                --log(tostring(self._unit:movement():stance_name()))
                --if self._unit:movement():cool() then
                    --log("unit is cool")
                --end

                --cool() doesn't work for the camera operator on First World Bank.  For
                --some reason he's in stance "cbt" (and therefore uncool) even if he's not
                --alerted.  I figure this is a bug in the map.
            --ignore the above comment.  They fixed that bug.  Hopefully it stays that way.
            --log("unit is " .. json.encode(self._logic_data))
                if not self._cop_pager_ready and self._unit:movement():cool() then
                --if not self._cop_pager_ready and self._unit:movement():stance_name() ~= "hos" then
                    --we're dead and the pager is not ready, so delete it
                    --log ("pager disabled")
                    self._unit:unit_data().has_alarm_pager = false
                end
            end
        end
        --log("clbk_death parent")
        _CopBrain_clbk_death(self, my_unit, damage_info)
    end



-------------------------------------------------
--  Setting number of pagers
-------------------------------------------------
-- This is called when a player interacts with a pager.  Swap in the
-- correct table before actually running the pager interaction
elseif RequiredScript == "lib/units/interactions/interactionext" and arePagerModsEnabled() then
    if not _IntimitateInteractionExt_at_interact_start then
        _IntimitateInteractionExt_at_interact_start = IntimitateInteractionExt._at_interact_start
    end
    function IntimitateInteractionExt:_at_interact_start(player, timer)
        --log("at_interact_start")
        if inStealth() then 
        --This is eventually going to call CopBrain.on_alarm_pager_interaction.
        --However, it doesn't pass in the player.  So, if we are going to do
        --that, set up the alarm_pager tables here
            if self.tweak_data == "corpse_alarm_pager" then
                --log("corpse_alarm_pager matches")
                if Network:is_server() then
                    --log("is server")
                    if not self._in_progress then 
                        --This is where the pager really runs
                        local bluffChance = {}
                        local numPagers;
                        numPagers = getNumPagers()

                        --Track the number of pagers a player has answered in the
                        --player object
                        if not player:base().num_answered then
                            player:base().num_answered = 0
                        end

                        --log("NumAnswered" .. tostring(player:base().num_answered))

                        --If this player can answer a pager, write up to
                        --getEffectiveNumPagersPerPlayer() 1's into the table,
                        --otherwise write all 0's.  This way the real
                        --on_alarm_pager_interaction will index into the table as
                        --normal
                        player:base().num_answered = player:base().num_answered + 1
                        local tableValue
                        if player:base().num_answered <= getEffectiveNumPagersPerPlayer() then
                            tableValue = 1
                        else
                            tableValue = 0
                        end
                        --log("tableValue is " .. tostring(tableValue))
                        for i = 0, ( numPagers - 1), 1 do
                            table.insert(bluffChance, tableValue)
                        end
                        table.insert(bluffChance, 0)

                        tweak_data.player.alarm_pager["bluff_success_chance"] = bluffChance
                        tweak_data.player.alarm_pager["bluff_success_chance_w_skill"] = bluffChance
                        if player:base().is_local_player then
                            addLocalPagerAnswered()
                        end
                    end
                end
            end
        end
        _IntimitateInteractionExt_at_interact_start(self, player, timer)
    end



-------------------------------------------------
-- Intimidated Civ Markers (Pacifier mod published by Ahab)
-------------------------------------------------
elseif RequiredScript == "lib/managers/group_ai_states/groupaistatebase" then
	local _upd_criminal_suspicion_progress_original = GroupAIStateBase._upd_criminal_suspicion_progress
	function GroupAIStateBase:_upd_criminal_suspicion_progress(...)
	
		if self._ai_enabled and isPacifierEnabled() then
			for obs_key, obs_susp_data in pairs(self._suspicion_hud_data or {}) do
				local unit = obs_susp_data.u_observer
			   
				if managers.enemy:is_civilian(unit) then
					local waypoint = managers.hud._hud.waypoints["susp1" .. tostring(obs_key)]
				   
					if waypoint then
						local color, arrow_color
					   
						if unit:anim_data().drop then
							if not obs_susp_data._subdued_civ then
								obs_susp_data._alerted_civ = nil
								obs_susp_data._subdued_civ = true
								color = Color(0, 0.71, 1)
								arrow_color = Color(0, 0.35, 0.5)
								waypoint.bitmap:set_image("guis/textures/menu_singletick")
							end
						elseif obs_susp_data.alerted then
							if not obs_susp_data._alerted_civ then 
								obs_susp_data._subdued_civ = nil
								obs_susp_data._alerted_civ = true
								color = Color.white
								arrow_color = tweak_data.hud.detected_color
								waypoint.bitmap:set_image("guis/textures/hud_icons")
								waypoint.bitmap:set_texture_rect(479,433,32,32,color)
							end
						end
						   
						if color then
							waypoint.bitmap:set_color(color)
							waypoint.arrow:set_color(arrow_color:with_alpha(0.75))
						end
					end
				end
			end
	    end

		return _upd_criminal_suspicion_progress_original(self, ...)
	end



-------------------------------------------------
-- Faster Stealth Drills (Inspired by a scripts posted by DvD and transcend)
-------------------------------------------------
elseif RequiredScript == "lib/units/props/timergui" then

	if isNoDrillJamsEnabled() then
		-- Don't let drill Jam
		function TimerGui:_set_jamming_values() return end
	end

	local old_start = TimerGui._start
	function TimerGui:_start(timer, current_timer)
		-- log("timer 0   " .. tostring(timer) .. " " .. type(timer))
		-- log("current_timer 0   " .. tostring(current_timer) .. " " .. type(current_timer))

		-- How much faster the drilling will be: 2 = twice as fast, 0.5 = twice as long
		local timer_multiplier = math.floor(getStealthDrillMult())
		
		-- Max possible duration
		local timer_max = math.floor(getStealthDrillMax())

		-- log("max" .. tostring(timer_max))

		-- If we are still in stealth mode, reduce timer.
		-- NOTE: if stealth fails after this, we unfortunately cannot revert this change on existing drills.
		local moddedTimer = tonumber(timer) -- is a string
		if inStealth() then
			moddedTimer = math.floor(moddedTimer / timer_multiplier)

			if moddedTimer > timer_max then
				moddedTimer = timer_max
			end
		end

		-- log("new timer" .. tostring(moddedTimer) .. "og timer" .. timer) 

		old_start(self, tostring(moddedTimer), current_timer)
	end



-------------------------------------------------
-- No fall damage in stealth
-------------------------------------------------
elseif RequiredScript == "lib/units/beings/player/playerdamage" then
	-- log("no fall damage" .. tostring(isNoStealthFallDamageEnabled()))

	if isNoStealthFallDamageEnabled() and inStealth() and PlayerDamage then
		function PlayerDamage:damage_fall( data ) 
			-- no fall damage
		end
	end


-------------------------------------------------
-- Infinite cable ties
-------------------------------------------------
-- Credit to Naviaux
elseif RequiredScript == "lib/tweak_data/upgradestweakdata" then
	local tweaker = UpgradesTweakData.init
	function UpgradesTweakData:init(tweak_data)
		tweaker(self, tweak_data)
		self.values.cable_tie.quantity_1 = {97}
	end
-- Has a bug where it gives infinite all special items
-- elseif RequiredScript == "lib/managers/playermanager" then
	-- -- log("inf zips" .. tostring(isInfiniteZipsEnabled()))

	-- if isInfiniteZipsEnabled() and inStealth() and PlayerManager then
		-- function PlayerManager:remove_special(name)
			-- --- do nothing
		-- end
	-- end


-------------------------------------------------
-- No Pagers on cuffed cops
-------------------------------------------------
elseif RequiredScript == "lib/units/enemies/cop/logics/coplogicintimidated" and CopLogicIntimidated then
	if not oldCopPagerFn then 
		oldCopPagerFn = CopLogicIntimidated._chk_begin_alarm_pager 
	end
	
	function CopLogicIntimidated._chk_begin_alarm_pager(data)	
		if arePagerModsEnabled() and isNoDomCopPagerEnabled() then
			-- Do nothing - normally the pager would be started here
		else
			return oldCopPagerFn(data)
		end
	end



-------------------------------------------------
-- Networking Logic
-------------------------------------------------
elseif RequiredScript == "lib/managers/crimespreemanager" then
    -- This is the last function that is called by NetworkMatchMakingSTEAM:set_attributes before calling
    -- self.lobby_handler:set_lobby_data, which is what ultimately gets sent to Steam when creating a
    -- lobby.  I can hide anything I want in this table and I'll see it in the client in
    -- NetworkMatchMakingSTEAM:_lobby_to_numbers.
    if not _CrimeSpreeManager_apply_matchmake_attributes then 
        _CrimeSpreeManager_apply_matchmake_attributes = CrimeSpreeManager.apply_matchmake_attributes
    end
    function CrimeSpreeManager.apply_matchmake_attributes(self, lobby_attributes)
        _CrimeSpreeManager_apply_matchmake_attributes(self, lobby_attributes)
        if arePagerModsEnabled() then
            lobby_attributes.silent_assassin = 1
        end
        --log("apply_matchmake_attributes returns " .. json.encode(lobby_attributes))
    end
elseif RequiredScript == "lib/network/matchmaking/networkmatchmakingsteam" then
    if not _NetworkMatchMakingSTEAM_search_lobby then
        _NetworkMatchMakingSTEAM_search_lobby = NetworkMatchMakingSTEAM.search_lobby
    end

--This is a clone of the search_lobby function from the real code.  Current as
--of U154
    function NetworkMatchMakingSTEAM.search_lobby(self, friends_only, no_filters)
        -- *****************************************************************
        -- Attention Idiot.  Next time you update this code, make sure to grab
        -- all three of the Start SA segments and transfer them to the new
        -- version.
        -- *****************************************************************

        --Start SA
        --This mod is incompatible with Snh20's Crime Spree Rank Spread Filter
        --Fix because they both override search_lobby without delegating to
        --the real search_filter.  If you set the filter to "any" then we'll
        --delegate to the "real" search_lobby.  This will also serve as a
        --workaround if Overkill changes the body of this function
        --Also, SA needs a higher priority than CSRSF.
        local saMMFilter = getMatchmakingFilter();
        if saMMFilter == 1 then
            --log ("delegating to real search_lobby")
            _NetworkMatchMakingSTEAM_search_lobby(self, friends_only, no_filters)
            return
        end
        --End SA

        --log ("Running SA version of search_lobby")
	self._search_friends_only = friends_only

	if not self:_has_callback("search_lobby") then
		return
	end


	-- Lines: 425 to 426
	local function is_key_valid(key)
		return key ~= "value_missing" and key ~= "value_pending"
	end

	if friends_only then
		self:get_friends_lobbies()
	else

		-- Lines: 434 to 481
		local function refresh_lobby()
			if not self.browser then
				return
			end

			local lobbies = self.browser:lobbies()
			local info = {
				room_list = {},
				attribute_list = {}
			}

			if lobbies then
				for _, lobby in ipairs(lobbies) do
					if self._difficulty_filter == 0 or self._difficulty_filter == tonumber(lobby:key_value("difficulty")) then
						table.insert(info.room_list, {
							owner_id = lobby:key_value("owner_id"),
							owner_name = lobby:key_value("owner_name"),
							room_id = lobby:id(),
							owner_level = lobby:key_value("owner_level")
						})

						local attributes_data = {
							numbers = self:_lobby_to_numbers(lobby),
							mutators = self:_get_mutators_from_lobby(lobby)
						}
						local crime_spree_key = lobby:key_value("crime_spree")

						if is_key_valid(crime_spree_key) then
							attributes_data.crime_spree = tonumber(crime_spree_key)
							attributes_data.crime_spree_mission = lobby:key_value("crime_spree_mission")
						end

						local mods_key = lobby:key_value("mods")

						if is_key_valid(mods_key) then
							attributes_data.mods = mods_key
						end

						table.insert(info.attribute_list, attributes_data)
					end
				end
			end

			self:_call_callback("search_lobby", info)
		end

		self.browser = LobbyBrowser(refresh_lobby, function ()
		end)
		local interest_keys = {
			"owner_id",
			"owner_name",
			"level",
			"difficulty",
			"permission",
			"state",
			"num_players",
			"drop_in",
			"min_level",
			"kick_option",
			"job_class_min",
			"job_class_max",
			"allow_mods"
		}

		if self._BUILD_SEARCH_INTEREST_KEY then
			table.insert(interest_keys, self._BUILD_SEARCH_INTEREST_KEY)
		end

        --Start SA
        --For some reason I can't add the interest key for avoid
        --My guess is that it requires this to have some value or
        --Steam's browser won't return it.
        if saMMFilter == 2 then
            --log("Adding silent_assassin key")
            table.insert(interest_keys, "silent_assassin")
        end
        --End SA

		self.browser:set_interest_keys(interest_keys)
		self.browser:set_distance_filter(self._distance_filter)

		local use_filters = not no_filters

		if Global.game_settings.gamemode_filter == GamemodeCrimeSpree.id then
			use_filters = false
		end

		self.browser:set_lobby_filter(self._BUILD_SEARCH_INTEREST_KEY, "true", "equal")

		local filter_value, filter_type = self:get_modded_lobby_filter()

		self.browser:set_lobby_filter("mods", filter_value, filter_type)

		local filter_value, filter_type = self:get_allow_mods_filter()

		self.browser:set_lobby_filter("allow_mods", filter_value, filter_type)

		if use_filters then
			self.browser:set_lobby_filter("min_level", managers.experience:current_level(), "equalto_less_than")

			if Global.game_settings.search_appropriate_jobs then
				local min_ply_jc = managers.job:get_min_jc_for_player()
				local max_ply_jc = managers.job:get_max_jc_for_player()

				self.browser:set_lobby_filter("job_class_min", min_ply_jc, "equalto_or_greater_than")
				self.browser:set_lobby_filter("job_class_max", max_ply_jc, "equalto_less_than")
			end
		end

		if not no_filters then
			if Global.game_settings.gamemode_filter == GamemodeCrimeSpree.id then
				local min_level = 0

				if Global.game_settings.crime_spree_max_lobby_diff >= 0 then
					min_level = managers.crime_spree:spree_level() - (Global.game_settings.crime_spree_max_lobby_diff or 0)
					min_level = math.max(min_level, 0)
				end

				self.browser:set_lobby_filter("crime_spree", min_level, "equalto_or_greater_than")
			elseif Global.game_settings.gamemode_filter == GamemodeStandard.id then
				self.browser:set_lobby_filter("crime_spree", -1, "equalto_less_than")
			end
		end

		if use_filters then
			for key, data in pairs(self._lobby_filters) do
				if data.value and data.value ~= -1 then
					self.browser:set_lobby_filter(data.key, data.value, data.comparision_type)
					print(data.key, data.value, data.comparision_type)
				end
			end
		end

		self.browser:set_max_lobby_return_count(self._lobby_return_count)

        --Start SA
        --log("Adding search_lobby SA filter")
        local filter = getMatchmakingFilter();
        -- 1 -> any (no filter)
        -- 2 -> require
        -- 3 -> avoid
        if filter == 2 then
            self.browser:set_lobby_filter("silent_assassin", 1, "equal")
            --log("Adding search_lobby SA filter (require)")
        elseif filter == 3 then
            self.browser:set_lobby_filter("silent_assassin", 1, "not_equal")
            --log("Adding search_lobby SA filter (avoid)")
        else
            --log("Adding search_lobby SA filter (any)")
        end
        --End SA

		if Global.game_settings.playing_lan then
			self.browser:refresh_lan()
		else
			self.browser:refresh()
		end
	end
	
    end


    if not _NetworkMatchMakingSTEAM__lobby_to_numbers then
        _NetworkMatchMakingSTEAM__lobby_to_numbers = NetworkMatchMakingSTEAM._lobby_to_numbers
    end
    function NetworkMatchMakingSTEAM._lobby_to_numbers(self, lobby)
        local numbers = _NetworkMatchMakingSTEAM__lobby_to_numbers(self, lobby)
        local version = lobby:key_value("silent_assassin")
        --log("_lobby_to_numbers silent_assassin = " .. tostring(version))
        return numbers
    end
end



-------------------------------------------------
-- More networking
-------------------------------------------------
function CreateSALobbyMessage()
	local message = managers.localization:text("sa_lobby_notice_1")
	if isStealthKillEnabled() then
		message = message .. managers.localization:text("sa_lobby_notice_2")
	end
		
	local params = {
		num_pagers = getNumPagers(),
		num_per_player = getNumPagersPerPlayer(),
		pager_detection_threshold_pct = getPagerDetectionThreshold() * 100
	}
	message = message .. managers.localization:text("sa_lobby_notice_3", params)
	return message
end

Hooks:Add("NetworkManagerOnPeerAdded", "NetworkManagerOnPeerAdded_SA", function(peer, peer_id)
    if Network:is_server() and arePagerModsEnabled() then

        DelayedCalls:Add("DelayedSAAnnounce" .. tostring(peer_id), 2, function()

            local message = CreateSALobbyMessage()
            local peer2 = managers.network:session() and managers.network:session():peer(peer_id)
            if peer2 then
                peer2:send("send_chat_message", ChatManager.GAME, message)
            end
        end)
    end
end)


-- -- Infinite and longer camera loops
-- -- Author: DvD
-- -- Note: Duration multiplier only works AS HOST!!
-- local infinite_concurrent_camera_loops = true	-- Set to true if you want infinite camera loops, false otherwise
-- local camera_loop_duration_multiplier = 10		-- Set to a multiplier higher than 1 if you want longer camera loop duration
 
-- local old_start = old_start or SecurityCamera._start_tape_loop
-- function SecurityCamera:_start_tape_loop(tape_loop_t)
	-- old_start(self, tape_loop_t * camera_loop_duration_multiplier)
	-- if infinite_concurrent_camera_loops then SecurityCamera.active_tape_loop_unit = nil end
-- end
---------------------------------------------------------------------------------------------------------------------------------



-- --No invisible walls
-- --Author: Harfatus
-- --Updated: DvD
-- local net_session = managers.network:session()
-- if net_session then
	-- local CollisionData = {	-- Not sure if these IDs are outdated or simply wrong, I cannot find them anymore
		-- --["29d0139549a54de7"] = true,
		-- --["53a9a98f72835230"] = true,	--regular collisions
		-- --["63be2c801283f573"] = true,
		-- --["673cff4d49da2368"] = true,	--vehicle collisions(blocks players too)
		-- --["86efb80bf784046f"] = true,
		-- --["e8fe662bb4d262d3"] = true,

		-- ["276de19dc5541f30"] = true, --units/dev_tools/level_tools/dev_collision_1m_2
		-- ["e379cc9592197cd8"] = true, --units/dev_tools/level_tools/dev_collision_1m_2_bag
		-- ["8f3cb89b79b42ec4"] = true, --units/dev_tools/level_tools/dev_collision_4m
		-- ["6cdb4f6f58ec4fa8"] = true, --units/dev_tools/level_tools/dev_collision_4m_bag
		-- ["7ae8fcbfe6a00f7b"] = true, --units/dev_tools/level_tools/dev_collision_5m
		-- ["85462a64da94ee78"] = true, --units/dev_tools/level_tools/dev_collision_5m_bag
		-- ["7a4c85917d8d8323"] = true, --units/dev_tools/level_tools/dev_collision_10m
		-- ["b37a4188fde4c161"] = true, --units/dev_tools/level_tools/dev_collision_10m_bag
		-- ["7b91ae618eadbe49"] = true, --units/dev_tools/level_tools/dev_nav_blocker_vehicle_sedan
		-- ["01c78e4ef0340674"] = true, --units/dev_tools/level_tools/navigation_blocker
		-- ["adea0368e2fee02b"] = true, --units/dev_tools/level_tools/navigation_blocker_1
		-- ["42370b3a7b92f537"] = true, --units/dev_tools/level_tools/navigation_blocker_10
		-- ["39d0838c190f1540"] = true, --units/dev_tools/level_tools/navigation_blocker_20
		-- ["cacb76e8e1d7e2f3"] = true, --units/dev_tools/level_tools/navigation_blocker_50
		-- ["c746af9ae100c837"] = true, --units/dev_tools/level_tools/navigation_blocker_hlf
		-- ["75baea8dccabc8d5"] = true, --units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_1x1m
		-- ["4027cbad1f8d5b37"] = true, --units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_1x3m
		-- ["9b2fcf39f23e2344"] = true, --units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_4x3m
		-- ["d678a2a41e3f1bfb"] = true, --units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_4x32m
		-- ["0fe54fe3af59d86c"] = true, --units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_8x3m
		-- ["2854ee0748613f72"] = true, --units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_8x32m
		-- ["16dde5dd77259b35"] = true, --units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_16x32m
		-- ["8969155cb42a67cc"] = true, --units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_64x32m
		-- ["c5c4442c5e147cb0"] = true, --units/dev_tools/level_tools/collision/dev_collision_1m/dev_collision_1m
		-- ["9eda9e73ac0ef710"] = true, --units/dev_tools/level_tools/collision/dev_collision_1m/dev_collision_1m_bag
		-- ["673ea142d68175df"] = true, --units/dev_tools/level_tools/collision/dev_collision_20m/dev_collision_20m
		-- ["260a42b4809c08dc"] = true, --units/dev_tools/level_tools/collision/dev_collision_20m/dev_collision_20m_bag
		-- ["9d8b22836aa015ed"] = true, --units/dev_tools/level_tools/collision/dev_collision_50m/dev_collision_50m
		-- ["78f4407343b48f6d"] = true, --units/dev_tools/level_tools/collision/dev_collision_50m/dev_collision_50m_bag
		-- ["96eba158d67240f6"] = true, --units/dev_tools/level_tools/dev_collision/dev_collision_1x1m
		-- ["a3649015ec10f0fa"] = true, --units/dev_tools/level_tools/dev_collision/dev_collision_1x3m
		-- ["6cb6040856588734"] = true, --units/dev_tools/level_tools/dev_collision/dev_collision_4x3m
		-- ["97e8d510fc7f6b4b"] = true, --units/dev_tools/level_tools/dev_collision/dev_collision_4x32m
		-- ["99792495ba726698"] = true, --units/dev_tools/level_tools/dev_collision/dev_collision_8x3m
		-- ["e765f9d63549a5c5"] = true, --units/dev_tools/level_tools/dev_collision/dev_collision_8x32m
		-- ["093021865a2c35af"] = true, --units/dev_tools/level_tools/dev_collision/dev_collision_16x32m
		-- ["a5bab566e1733d44"] = true, --units/dev_tools/level_tools/dev_collision/dev_collision_64x32m
		-- ["3345b74c3081f3f9"] = true, --units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_1x1m
		-- ["f9639a083eb4eb0c"] = true, --units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_1x1x3m
		-- ["8f0bd5d3ce8adf20"] = true, --units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_1x3m
		-- ["120d0ca08375e85e"] = true, --units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_2x3m
		-- ["d6ab68fdfb25156e"] = true, --units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_4x3m
		-- ["77175ed91c87d38a"] = true, --units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_8x3m
		-- ["89a7dbeb98bb47fb"] = true, --units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_16x3m
		-- ["67e5497920d65b45"] = true, --units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_64x3m
		-- ["4385cb1d46044948"] = true, --units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_1x1m
		-- ["75d60c30cfc752d5"] = true, --units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_1x3m
		-- ["6e94e532295a1c4c"] = true, --units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_4x3m
		-- ["b7dd69c3082ad494"] = true, --units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_4x32m
		-- ["03996689587afc9c"] = true, --units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_8x3m
		-- ["fe7682409496395c"] = true, --units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_8x32m
		-- ["20a34b41ca06015c"] = true, --units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_16x32m
		-- ["70fbfdaf5e1c50a1"] = true, --units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_64x32m
		-- ["cbeb471aa32636ea"] = true, --units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_1x1m
		-- ["7c6a421c90a8709a"] = true, --units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_1x3m
		-- ["fe13549df62eab40"] = true, --units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_4x3m
		-- ["df37c0dd7a9e1392"] = true, --units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_4x32m
		-- ["887ceed0e322a202"] = true, --units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_8x3m
		-- ["b1f9779228aff5cf"] = true, --units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_8x32m
		-- ["ea53e01e72a77431"] = true, --units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_16x32m
		-- ["31245608e2096b2a"] = true, --units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_64x32m
	-- }
						
	-- for _,unit in pairs(World:find_units_quick("all", 1)) do
		-- if CollisionData[unit:name():key()] then
			-- --net_session:send_to_peers(net_session, 'remove_unit', unit)    -- This crashes if you're host for some reason, have to look into it
			-- unit:set_slot(0)
		-- end
	-- end  
-- end
----------------------------------------------------------------------------------------------------------------------------------



-- --Highlight mission equipment
-- --Author: DvD
-- local function in_game()
	-- return BaseNetworkHandler and BaseNetworkHandler._gamestate_filter.any_ingame_playing[game_state_machine:last_queued_state_name()] or false
-- end
-- local sequences = {
	-- "enable_outline",
	-- "state_outline_enabled",
	-- "switch_to_glow_mtr" }
	-- --"show" }
-- local exclusions = { ["58cb6c4c6221c415"] = true	-- Car shop keyboard
				-- }
-- local do_once = do_once or true
-- local counter = counter or 0
-- local items = items or {}
-- function do_glow(unit)	
	-- if not unit or not unit:damage() or exclusions[unit:name():key()] then return end
	
	-- local dam = unit:damage()
	-- local hasglow = false
	
	-- for _,seq in pairs(sequences) do
		-- if dam:has_sequence(seq) then 
			-- dam:run_sequence_simple(seq)
			-- hasglow = true
		-- end
	-- end
	
	-- if hasglow and dam:has_sequence("show") then dam:run_sequence_simple("show") end
-- end
-- local old_add = ObjectInteractionManager.add_unit
-- function ObjectInteractionManager:add_unit(unit)
	-- old_add(self, unit)
	-- if not do_once then
		-- table.insert(items, unit)
		-- counter = 0
	-- end
-- end
-- local old_remove = ObjectInteractionManager.remove_unit
-- function ObjectInteractionManager:remove_unit(unit)
	-- for id, un in pairs(items) do
		-- if un == unit then table.remove(items, id) end
	-- end
	-- counter = 0 -- All glow gets reset on pickup for some reason
	-- do_once = true
	-- old_remove(self, unit)
-- end
-- local old_update = ObjectInteractionManager.update
-- function ObjectInteractionManager:update(t, dt)
	-- old_update(self, t, dt)
	
	-- -- Highlight new items
	-- if in_game() and counter < self.FRAMES_TO_COMPLETE and (#items > 0 or do_once) then
		-- if do_once then
			-- for _,unit in pairs(self._interactive_units) do do_glow(unit) end	-- Has to be done manually first
		-- else
			-- for id,unit in pairs(items) do
				-- do_glow(unit)
				-- if counter == (self.FRAMES_TO_COMPLETE - 1) then table.remove(items, id) end
			-- end
		-- end
		-- counter = counter + 1
	-- elseif counter == self.FRAMES_TO_COMPLETE and do_once then 
		-- do_once = false 
		-- items = {}
	-- elseif not in_game() then
		-- do_once = true
		-- counter = 0
		-- items = {}
	-- end
-- end
---------------------------------------------------------------------------------------------------------------------------------



-- -- Unlimited [500 actually, but who cares] dominations
-- if not _upgradeValueIntimidate then _upgradeValueIntimidate = PlayerManager.upgrade_value end 
-- function PlayerManager:upgrade_value( category, upgrade, default ) 
	-- if category == "player" and upgrade == "convert_enemies" then
		-- return true
	-- elseif category == "player" and upgrade == "convert_enemies_max_minions" then
		-- return 500
	-- else
		-- return _upgradeValueIntimidate(self, category, upgrade, default)
	-- end
-- end
---------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------
-- Stealth bonus
---------------------------------------------------------------------------------------------------------------------------------
-- --this only gives you the bonus for not using your pager
-- function calculateStageStealthBonus()
    -- --and if you personally didn't use a pager at all, you get a 2% bonus
    -- local playerBonus
    -- if getLocalPagersAnswered() == 0 then
        -- playerBonus = .02
    -- else
        -- playerBonus = 0
    -- end

    -- return playerBonus
-- end

-- --bonus for difficulty too
-- function calculateLevelStealthBonus()
    -- --calculate an adjusted stealth bonus for the level/stage
    -- -- adding or removing pagers (from the default of 2) changes the bonus
    -- -- each pager used by the party decreases the bonus
    -- -- reducing pagers per player increases the bonus
    -- -- not using your pager increases it
    -- local numPagers = getNumPagers()
    -- --don't penalize the player for having 2 total pagers but 4 per player
    -- local numPagersPerPlayer = math.min(numPagers, getNumPagersPerPlayer())
    -- local difficultyBonus = 0;
    -- local parPagers

    -- --par for pagers is 2 when stealth kills are enabled, otherwise 
    -- --it is the default of 4.
    -- if isStealthKillEnabled() then
        -- parPagers = 2
    -- else
        -- parPagers = 4
    -- end
    -- -- 2% bonus for each pager below 2
    -- difficultyBonus = difficultyBonus + ((parPagers - numPagers) * .02)
    -- -- 1% bonus for each pager per player below the number of total pagers
    -- difficultyBonus = difficultyBonus + ((numPagers - numPagersPerPlayer) * .01)
    -- --log ("difficulty bonus is " .. tostring(difficultyBonus))

    -- --you also get a 1% bonus for each pager you had but didn't use
    -- local missionBonus
    -- --it seems like this gets called when someone joins a stealth lobby  In
    -- --that case groupai is undefined.  So try this hack.
    -- if managers.groupai and managers.groupai:state() then
        -- missionBonus = (numPagers - managers.groupai:state():get_nr_successful_alarm_pager_bluffs()) * .01
    -- else
        -- missionBonus = numPagers
    -- end
    -- --log ("mission bonus is " .. tostring(missionBonus))

    -- --and if you personally didn't use a pager at all, you get a 2% bonus
    -- local playerBonus
    -- if getLocalPagersAnswered() == 0 then
        -- playerBonus = .02
    -- else
        -- playerBonus = 0
    -- end

    -- --log("Player bonus is " .. tostring(playerBonus))

    -- local bonus = difficultyBonus + missionBonus + playerBonus
    -- --log("Level bonus is " .. tostring(bonus))
    -- return bonus
-- end



-- function isPagerBonusEnabled()
    -- return false
    -- --local Net = _G.LuaNetworking
    -- --if Net:IsClient() then
        -- --return false
    -- --end
    -- --if nil == GreyAreaStealth.settings["pager_bonus_enabled"] then
        -- --GreyAreaStealth:Load()
    -- --end
    -- --return GreyAreaStealth.settings["pager_bonus_enabled"]

-- end
 
-- elseif RequiredScript == "lib/managers/jobmanager" then
    -- if not _JobManager_current_stage_data then
        -- _JobManager_current_stage_data = JobManager.current_stage_data
    -- end
    -- function JobManager.current_stage_data(self)
        -- if arePagerModsEnabled() and isPagerBonusEnabled() then 
            -- return modifyGhostBonus(self, _JobManager_current_stage_data(self))
        -- else
            -- return _JobManager_current_stage_data(self)
        -- end
    -- end

    -- if not _JobManager_current_level_data then
        -- _JobManager_current_level_data = JobManager.current_level_data
    -- end

    -- function JobManager.current_level_data(self)
        -- if arePagerModsEnabled() and isPagerBonusEnabled() then
            -- return modifyGhostBonus(self, _JobManager_current_level_data(self))
        -- else
            -- return _JobManager_current_level_data(self)
        -- end
    -- end

    -- function modifyGhostBonus(self, level_data)
        -- --when the level is completed, modify the ghost_bonus of the stage.
        -- --This is called from JobManager.accumulate_ghost_bonus, which sets the
        -- --stealth bonus
        -- if level_data and level_data.ghost_bonus then
            -- local new_data = {}
            -- for k, v in pairs(level_data) do
                -- if k == "ghost_bonus" then
                    -- local bonus
                    -- if JobManager.on_last_stage(self) then
                        -- bonus = calculateLevelStealthBonus()
                    -- else
                        -- bonus = calculateStageStealthBonus()
                    -- end
                    -- --make sure the total stealth bonus is never negative
                    -- new_data[k] = math.clamp(v + bonus, 0, 1)
                -- else
                    -- new_data[k] = v
                -- end
            -- end

            -- return new_data
        -- end
        -- return level_data
    -- end
