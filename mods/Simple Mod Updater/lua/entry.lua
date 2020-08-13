_G.SimpleModUpdater = _G.SimpleModUpdater or {}
SimpleModUpdater.path = ModPath
SimpleModUpdater.data_path = SavePath .. 'simple_mod_updater.txt'
SimpleModUpdater.fake_hash = 'nope'
SimpleModUpdater.my_zips = {}
SimpleModUpdater.settings = {
	enabled_updates = {},
	auto_install = true,
	notify_about_disabled_mods = true
}
local server = 'http://pd2mods.z77.fr/update/'
SimpleModUpdater.legacy_id_to_simple_url = {
	AM = server .. 'AlphasortMods',
	BC = server .. 'BagContour',
	BDB = server .. 'BuilDB',
	CAPP = server .. 'CrewAbilityPiedPiper',
	CMD = server .. 'CivilianMarkerForDropins',
	CTC = server .. 'ClearTextureCache',
	DDI = server .. 'DragDropInventory',
	ENH_HMRK = server .. 'EnhancedHitmarkers',
	FC = server .. 'FadingContour',
	FCB = server .. 'FilteredCameraBeeps',
	FCSCM = server .. 'FixCrimeSpreeConcealmentModifier',
	FS = server .. 'FullSpeedSwarm',
	FSS = server .. 'FlashingSwanSong',
	GCW = server .. 'GoonmodCustomWaypoints',
	ITR = server .. 'Iter',
	KIC = server .. 'KeepItClean',
	KPR = server .. 'Keepers',
	LIWL = server .. 'LessInaccurateWeaponLaser',
	LPI = server .. 'LobbyPlayerInfo',
	LS = server .. 'LobbySettings',
	MDF = server .. 'MrDrFantastic',
	MIC = server .. 'MoveableIntimidatedCop',
	MKP = server .. 'Monkeepers',
	MRK = server .. 'Marking',
	MTGA = server .. 'MakeTechnicianGreatAgain',
	MWS = server .. 'MoreWeaponStats',
	NDB = server .. 'NoDuplicatedBullets',
	NMA = server .. 'NoMutantsAllowed',
	PC = server .. 'PagerContour',
	PGT = server .. 'PleaseGoThere',
	QKI = server .. 'QuickKeyboardInput',
	RIP = server .. 'RenameInventoryPages',
	RTR = server .. 'ReloadThenRun',
	SAP = server .. 'SentryAutoAP',
	SAW = server .. 'SawHelper',
	SDJBL = server .. 'RestructuredMenus',
	SHD = server .. 'SentryHealthDisplay',
	SI = server .. 'SearchInventory',
	SUIS = server .. 'SwitchUnderbarrelInSteelsight',
	TP = server .. 'TPACK',
	YAF = server .. 'YetAnotherFlashlight'
}

function SimpleModUpdater:load()
	local configfile = io.open( self.data_path, 'r' )
	if configfile then
		for k, v in pairs( json.decode(configfile:read('*all')) or {} ) do
			self.settings[k] = v
		end
		configfile:close()
	end
end

function SimpleModUpdater:save()
	local configfile = io.open(self.data_path, 'w+')
	if configfile then
		configfile:write(json.encode(self.settings))
		configfile:close()
	end
end

SimpleModUpdater:load()

function SimpleModUpdater:make_text_readable( input ) -- or not
	if type(input) ~= 'string' then
		return ''
	end

	local a, b, c = input:byte(1, 3)
	if a == 239 and b == 187 and c == 191 then -- utf8
		return input:sub(4)
	elseif a == 254 and b == 255 then -- utf16be
		return '[utf16 is not supported]'
	elseif a == 255 and b == 254 then -- utf16le
		return '[utf16 is not supported]'
	end

	return input
end

Hooks:Add('LocalizationManagerPostInit', 'LocalizationManagerPostInit_SMU', function(loc)
	local language_filename

	if not language_filename then
		for _, filename in pairs( file.GetFiles(SimpleModUpdater.path .. 'loc/') ) do
			local str = filename:match( '^(.*).txt$' )
			if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
				language_filename = filename
				break
			end
		end
	end

	if language_filename then
		loc:load_localization_file( SimpleModUpdater.path .. 'loc/' .. language_filename )
	end
	loc:load_localization_file( SimpleModUpdater.path .. 'loc/english.txt', false )
end)

Hooks:Add('MenuManagerInitialize', 'MenuManagerInitialize_SimpleModUpdater', function( menu_manager )
	MenuCallbackHandler.SimpleModUpdater_MenuCheckboxClbk = function( this, item )
		SimpleModUpdater.settings[ item:name() ] = item:value() == 'on'
	end

	MenuCallbackHandler.SimpleModUpdater_MenuSave = function( this, item )
		SimpleModUpdater:save()
	end

	MenuHelper:LoadFromJsonFile( SimpleModUpdater.path .. 'menu/options.txt', SimpleModUpdater, SimpleModUpdater.settings )
end)

-- ----------------------------------------------------------------------------

local smu_original_unzip = unzip
function unzip( file_path, dest_dir )
	smu_original_unzip( file_path, dest_dir )

	if SimpleModUpdater.my_zips[ file_path ] then
		local update = SimpleModUpdater.my_zips[ file_path ]
		local notification = update.notification and BLT.Notifications:_get_notification( update.notification )
		if notification then
			local mod_dir = dest_dir:match( '[^/\\]+$' )
			local filename = dest_dir .. '/' .. mod_dir .. '/changelog.txt'
			local f = io.open( filename, 'r' )
			if f then
				local changes = SimpleModUpdater:make_text_readable( f:read( '*all' ) )
				io.close( f )

				BLT.Notifications:remove_notification( update.notification )
				notification.text = changes:match( '^(.-)\r?\n\r?\n' ) or managers.localization:text( 'smu_autoinstall_mod_no_changelog' )
				update.notification = BLT.Notifications:add_notification( notification )
			end
		end

		SimpleModUpdater.my_zips[ file_path ] = nil
		SystemFS:delete_file( file_path )
	end
end

local smu_original_bltviewmodgui_setupmodinfo = BLTViewModGui._setup_mod_info
function BLTViewModGui:_setup_mod_info( mod )
	smu_original_bltviewmodgui_setupmodinfo( self, mod )

	local changes = io.open( mod.path .. 'changelog.txt', 'r' )
	if changes then
		local text = SimpleModUpdater:make_text_readable( changes:read( '*all' ) )
		changes:close()

		local function make_fine_text( text )
			local x,y,w,h = text:text_rect()
			text:set_size( w, h )
			text:set_position( math.round( text:x() ), math.round( text:y() ) )
		end

		local padding = 10
		local info_canvas = self._info_scroll:canvas()
		local changelog = info_canvas:text({
			name = 'changelog',
			x = padding,
			y = padding,
			w = info_canvas:w() - padding * 2,
			font_size = tweak_data.menu.pd2_small_font,
			font = tweak_data.menu.pd2_small_font,
			layer = 10,
			blend_mode = 'add',
			color = Color(0.231373, 0.682353, 0.996078),
			text = text,
			align = 'left',
			vertical = 'top',
			wrap = true,
			word_wrap = true,
		})
		make_fine_text( changelog )
		changelog:set_top( padding * 2 + info_canvas:child('contact'):bottom() )

		self._info_scroll:update_canvas_size()
	end
end

local smu_original_bltviewmodgui_setupbuttons = BLTViewModGui._setup_buttons
function BLTViewModGui:_setup_buttons( mod )
	smu_original_bltviewmodgui_setupbuttons( self, mod )

	if self._mod.updates and self._mod.updates[1] and self._mod.updates[1].is_simple then
		for i, btn in ipairs(self._buttons) do
			if btn == self._check_update_button then
				btn:panel():set_visible(false)
				table.remove(self._buttons, i)
				break
			end
		end
		self._check_update_button = nil
	end
end

_G.BLTSimpleUpdate = _G.BLTSimpleUpdate or blt_class( BLTUpdate )

function BLTSimpleUpdate:init( parent_mod, url )
	BLTSimpleUpdate.super.init( self, parent_mod, { host = 'crap' } )
	self.url = url
	self.is_simple = true
	self:SetEnabled( SimpleModUpdater.settings.enabled_updates[ url ] ~= false, true )
end

function BLTSimpleUpdate:SetEnabled( enabled, no_save )
	BLTSimpleUpdate.super.SetEnabled( self, enabled )
	if not no_save then
		SimpleModUpdater.settings.enabled_updates[ self.url ] = enabled
		SimpleModUpdater:save()
	end
end

function BLTSimpleUpdate:GetId()
	return type( self.url ) == 'string' and self.url:match( '([^/]+)$' )
end

function BLTSimpleUpdate:GetDownloadURL()
	return ( '%s_%i.zip' ):format( self.url, self.parent_mod.version )
end

function BLTSimpleUpdate:CheckForUpdates( clbk )
	if SimpleModUpdater.download_enabled then
		BLT.Downloads:start_download( self )
	end
end

function BLTSimpleUpdate:ShowChangelog()
	local changes = io.open( self.parent_mod.path .. 'changelog.txt', 'r' )
	if changes then
		local text = SimpleModUpdater:make_text_readable( changes:read( '*all' ) )
		changes:close()
		if text then
			local title = managers.localization:text( 'smu_changelog_title', { mod_name = self.parent_mod:GetName() } )
			local message = text
			local menu_options = {
				{
					text = managers.localization:text( 'smu_changelog_close' ),
					is_cancel_button = true
				}
			}
			local help_menu = QuickMenu:new( title, message, menu_options, true )
		end
	end
end

function BLTSimpleUpdate:ViewPatchNotes()
	local changelog_url = self.parent_mod and self.parent_mod.json_data.simple_changelog_url
	if changelog_url then
		if Steam:overlay_enabled() then
			Steam:overlay_activate( 'url', changelog_url )
		else
			os.execute( 'cmd /c start ' .. changelog_url )
		end
		return
	end

	if not self.postponed_download then -- is during/after installation
		self:ShowChangelog()
	end
end

local smu_original_file_directoryhash = file.DirectoryHash
file.DirectoryHash = function( path )
	local delim = path:sub(-1)
	local id = path:match( delim .. '([^' .. delim .. ']+)' .. delim .. '$' )
	for _, download in ipairs(BLT.Downloads._downloads) do
		local update = download.update
		if update.is_simple or update.is_simple_dependency then
			if id == update:GetInstallFolder() then
				return SimpleModUpdater.fake_hash
			end
		end
	end

	return smu_original_file_directoryhash( path )
end

function BLTSimpleUpdate:GetServerHash()
	return SimpleModUpdater.fake_hash
end

local smu_original_bltmoddependency_getserverhash = BLTModDependency.GetServerHash
function BLTModDependency:GetServerHash()
	if self.is_simple_dependency then
		return SimpleModUpdater.fake_hash
	end
	return smu_original_bltmoddependency_getserverhash( self )
end

function BLTModDependency:ViewPatchNotes()
	if self.is_simple_dependency then
		return -- changelog url can't be known for dependencies
	else
		BLTUpdate.ViewPatchNotes( self )
	end
end

if not BLTSuperMod then
	function BLTModDependency:init( parent_mod, id, download_data )
		self._id = id
		self._parent_mod = parent_mod
		self._download_data = download_data
	end

	function BLTModDependency:GetDownloadURL()
		return self._download_data and self._download_data.download_url
	end

	function BLTDownloadManager:start_download( update )

		-- Check if the download already going
		if self:get_download( update ) then
			log(string.format( '[Downloads] Download already exists for %s (%s)', update:GetName(), update:GetParentMod():GetName() ))
			return false
		end

		-- Check if this update is allowed to be updated by the download manager
		if update:DisallowsUpdate() then
			MenuCallbackHandler[ update:GetDisallowCallback() ]( MenuCallbackHandler )
			return false
		end

		local url = update:GetDownloadURL()
		if not url then
			return false
		end

		-- Start the download
		local http_id = dohttpreq( url, callback(self, self, 'clbk_download_finished'), callback(self, self, 'clbk_download_progress') )

		-- Cache the download for access
		local download = {
			update = update,
			http_id = http_id,
			state = 'waiting'
		}
		table.insert( self._downloads, download )

		return true
	end
end

function BLTModManager:_RunAutoCheckForUpdates() -- overwritten just to add a call to IsCheckingForUpdates()

	-- Place a notification that we're checking for autoupdates
	if BLT.Notifications then 
		local icon, rect = tweak_data.hud_icons:get_icon_data("csb_pagers")
		self._updates_notification = BLT.Notifications:add_notification( {
			title = managers.localization:text("blt_checking_updates"),
			text = managers.localization:text("blt_checking_updates_help"),
			icon = icon,
			icon_texture_rect = rect,
			color = Color.white,
			priority = 1000,
		} )
	end

	-- Start checking all enabled mods for updates
	local count = 0
	for _, mod in ipairs( self:Mods() ) do
		for _, update in ipairs( mod:GetUpdates() ) do
			if update:IsEnabled() then
				update:CheckForUpdates( callback(self, self, "clbk_got_update") )
				if update:IsCheckingForUpdates() then
					count = count + 1
				end
			end
		end
	end

	-- -- Remove notification if not getting updates
	if count < 1 and self._updates_notification then
		BLT.Notifications:remove_notification( self._updates_notification )
		self._updates_notification = nil
	end

end

function BLTDownloadControl:smu_update_patchnotes()
	local update = self:parameters().update
	if update.is_simple then
		if update.parent_mod.json_data.simple_changelog_url then
			-- qued
		elseif update.postponed_download then
			self._patch_background:set_color( tweak_data.menu.default_disabled_text_color )
		else
			self._patch_background:set_color( self._highlight_patch and tweak_data.screen_colors.button_stage_2 or (self:parameters().color or tweak_data.screen_colors.button_stage_3) )
		end
	elseif update.is_simple_dependency then
		self._patch_background:set_color( tweak_data.menu.default_disabled_text_color )
	end
end

local smu_original_bltdownloadcontrol_init = BLTDownloadControl.init
function BLTDownloadControl:init( panel, parameters )
	smu_original_bltdownloadcontrol_init( self, panel, parameters )

	local update = parameters and parameters.update
	if update and update.is_simple then
		if update.postponed_download then
			self._download_state:set_text( managers.localization:text('smu_already_downloaded_ready_to_install') )
		end
		self:smu_update_patchnotes()
	end
end

local smu_original_bltdownloadcontrol_mousemoved = BLTDownloadControl.mouse_moved
function BLTDownloadControl:mouse_moved( button, x, y )
	smu_original_bltdownloadcontrol_mousemoved( self, x, y )
	self:smu_update_patchnotes()
end

local smu_original_bltdownloadmanager_startdownload = BLTDownloadManager.start_download
function BLTDownloadManager:start_download( update )
	local download = update.postponed_download
	if download then
		table.insert( self._downloads, download )
		self:clbk_download_finished( download.data, download.http_id )
		return true
	end

	return smu_original_bltdownloadmanager_startdownload( self, update )
end

local smu_original_bltdownloadmanager_clbkdownloadfinished = BLTDownloadManager.clbk_download_finished
function BLTDownloadManager:clbk_download_finished( data, http_id, ... )
	local download = self:get_download_from_http_id( http_id )
	if not download then
		return
	elseif type( data ) == 'string' and data:sub( 1, 2 ) == 'PK' then
		local update = download.update
		if update and update.is_simple then
			if SimpleModUpdater.settings.auto_install then
				update.notification = BLT.Notifications:add_notification( {
					title = update:GetParentMod():GetName(),
					text = managers.localization:text( 'smu_autoinstall_mod_update' ),
					priority = 1001,
				} )
			end
			if SimpleModUpdater.settings.auto_install or update.postponed_download then
				local file_path = Application:nice_path( BLTModManager.Constants:DownloadsDirectory() .. tostring(update:GetId()) .. '.zip' )
				SimpleModUpdater.my_zips[ file_path ] = update
				update.postponed_download = nil
			else
				download.data = data
				download.state = 'already_downloaded'
				update.postponed_download = download
				for i, dl in ipairs( self._downloads ) do
					if download == dl then
						table.remove( self._downloads, i )
						break
					end
				end
				BLT.Downloads:add_pending_download( update )
				return
			end
		end
	else
		download.state = 'failed'
		return
	end

	smu_original_bltdownloadmanager_clbkdownloadfinished( self, data, http_id, ... )
end

function BLTMod:AreSimpleDependenciesInstalled() -- operates like BLTMod:AreDependenciesInstalled()
	local id2mod = {}
	for _, mod in ipairs( BLT.Mods:Mods() ) do
		if mod.json_data.simple_update_url then
			id2mod[ mod.json_data.simple_update_url ] = mod
		end
	end

	local is_ok = true

	for id, url in pairs( self.json_data.simple_dependencies or {} ) do
		local mod = id2mod[ url ]
		if not mod then
			is_ok = false
			local download_data = {
				download_url = url .. '_0.zip',
				is_simple = true
			}
			local dependency = BLTModDependency:new( self, id, download_data )
			dependency.is_simple_dependency = true
			dependency._server_data = { name = id, hash = '123' }
			table.insert( self.missing_dependencies, dependency )

		elseif not mod:IsEnabled() then
			is_ok = false
			table.insert( self.disabled_dependencies, mod )
			table.insert( self._errors, 'blt_mod_dependency_disabled' )
		end
	end

	return is_ok
end

function SimpleModUpdater:start()
	local game_state = game_state_machine:last_queued_state_name()
	if game_state == 'bootup' or game_state == 'menu_titlescreen' then
		self.download_enabled = true
	elseif game_state == 'menu_main' then
		self.download_enabled = false
	else
		self.download_enabled = false
		return
	end

	local disabled_mods = {}
	for _, mod in pairs( BLT.Mods:Mods() ) do
		if mod.json_data.simple_update_url then
			local new_update = BLTSimpleUpdate:new( mod, mod.json_data.simple_update_url )
			table.insert( mod.updates, new_update )
		elseif mod.updates and mod.updates[1] and mod.updates[1].id then
			local url = SimpleModUpdater.legacy_id_to_simple_url[mod.updates[1].id]
			if url then
				local new_update = BLTSimpleUpdate:new( mod, url )
				table.insert( mod.updates, new_update )
			end
		end

		if not mod:AreSimpleDependenciesInstalled() then
			for _, dependency in ipairs( mod:GetMissingDependencies() ) do
				BLT.Downloads:add_pending_download( dependency )
			end
		end

		if #mod:GetDisabledDependencies() > 0 then
			mod:SetEnabled( false )
		end

		if not mod:IsEnabled() then
			table.insert( disabled_mods, mod:GetName() )
		end
	end

	if SimpleModUpdater.settings.notify_about_disabled_mods then
		if BLT.Notifications and #disabled_mods > 0 then
			table.sort( disabled_mods )
			BLT.Notifications:add_notification( {
				title = managers.localization:text( 'smu_x_mods_disabled', { x = #disabled_mods } ),
				text = table.concat( disabled_mods, ', ' ) .. '.',
				priority = 1000,
			} )
		end
	end
end

DelayedCalls:Add('DelayedModUpdaterStart', 0, function()
	SimpleModUpdater:start()
end)

if not BLTSuperMod then
	dofile(ModPath .. 'lua/BLTMenuNodes.lua')
end
