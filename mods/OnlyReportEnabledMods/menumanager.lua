function MenuCallbackHandler:build_mods_list()
    -- self:is_modded_client() literally just checks for the BLT var anyway
    local BLT  = rawget(_G, "BLT") 
    if not BLT or not BLT.Mods then return {} end
    
	local mods = {}

    for _, mod in ipairs(BLT.Mods:Mods()) do
        if mod:IsEnabled() then
            table.insert(mods, {mod:GetName(), mod:GetId()})
        end
    end
    
	return mods
end