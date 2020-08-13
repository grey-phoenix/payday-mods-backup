
--Damn I wrote this like two years ago
--Basically gonna quickly improve shit and change the stuff wilko pointlessly changed
ReconnectTS = ReconnectTS or {}
ReconnectTS.SavePath = SavePath .. "ReconnectTSLastRoomID.txt"
local bind = BLT.Keybinds:get_keybind("ReconnectTSKeybind")
if not bind:HasKey() then
	bind:SetKey("insert")
end

function ReconnectTS:SetLastRoomID(room_id)
	local file = io.open(self.SavePath, "w")
	if file then
		file:write(room_id)
		file:close()
	end
end

function ReconnectTS:ConnectToLast()
	local room_id
	local file = io.open(ReconnectTS.SavePath, "r")
	if file then
		room_id = file:read("*all")
		file:close()
	end
	if room_id then
		managers.network.matchmake:join_server(room_id)
	else
		QuickMenu:new("Oops", "Seems like there's no server to connect to :(", {}, true)
	end
end

if RequiredScript == "lib/managers/crimenetmanager" then
	Hooks:PostHook(CrimeNetGui, "init", "ReconnectInitGUI", function(self, ws, fullscreeen_ws, node)
		local key = BLT.Keybinds:get_keybind("ReconnectTSKeybind"):Key() or "insert"
		local reconnect_button = self._panel:text({
			name = "reconnect_button",
			text = string.upper("["..key.."]".." Reconnect"),
			font_size = tweak_data.menu.pd2_small_font_size,
			font = tweak_data.menu.pd2_small_font,
			color = tweak_data.screen_colors.button_stage_3,
			layer = 40,
			y = 40,
			blend_mode = "add"
		})
		self:make_fine_text(reconnect_button)
		reconnect_button:set_right(self._panel:w() - 10)
		self._fullscreen_ws:connect_keyboard(Input:keyboard())  
		self._fullscreen_panel:key_press(callback(self, self, "KeyPressed"))    
	end)

	function CrimeNetGui:KeyPressed(o, k)
		local key = BLT.Keybinds:get_keybind("ReconnectTSKeybind"):Key() or "insert"
		if k == Idstring(key) and alive(self._panel:child("reconnect_button")) then
			ReconnectTS:ConnectToLast()
		end
	end

	local orig_mouse_pressed = CrimeNetGui.mouse_pressed
	function CrimeNetGui:mouse_pressed(o, button, x, y)
		if not self._crimenet_enabled or self._getting_hacked then
			return
		end
		local reconnect_button = self._panel:child("reconnect_button")
		if alive(reconnect_button) and reconnect_button:inside(x, y) then
			ReconnectTS:ConnectToLast()  
			return true
		end
		return orig_mouse_pressed(self, o, button, x, y)
	end

	Hooks:PostHook(CrimeNetGui, "mouse_moved", "ReconnectTSMouseMoved", function(self, o, x, y)
		if not self._crimenet_enabled or self._getting_hacked then
			return
		end
		local reconnect_button = self._panel:child("reconnect_button")
		if alive(reconnect_button) then
			if reconnect_button:inside(x, y) then
				if not self._reconnect_highlighted then
					self._reconnect_highlighted = true
					reconnect_button:set_color(tweak_data.screen_colors.button_stage_2)
					managers.menu_component:post_event("highlight")
				end
			elseif self._reconnect_highlighted then
				self._reconnect_highlighted = false
				reconnect_button:set_color(tweak_data.screen_colors.button_stage_3)
			end
		end
	end)
elseif RequiredScript == "lib/network/matchmaking/networkmatchmakingsteam" then
	Hooks:PostHook(NetworkMatchMakingSTEAM, "join_server", "SaveRoomIDReconnectTS", function(self, room_id)
		ReconnectTS:SetLastRoomID(room_id)
		log("[Reconnect to server] Saving room ID "..room_id)
	end)
end