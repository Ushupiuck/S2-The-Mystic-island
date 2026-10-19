local sound = {}

function sound.build()
	local os_name = require("build_tools.lua.get_os_name").get_os_name()
	for _, tool in ipairs({"KEHmusic.exe", "KEHsfx.exe"}) do
		-- Use CMD's current-directory lookup for these fixed executable names.
		-- The quoted ./ prefix below is for Mono on Unix.
		local command = os_name == "Windows" and tool or ('mono "./' .. tool .. '"')
		local success, _, code = os.execute(command)
		if success ~= true and success ~= 0 then
			io.stderr:write(tool .. " failed (exit " .. tostring(code) .. "). ROM assembly was stopped.\n")
			return false
		end
	end
	return true
end

return sound
