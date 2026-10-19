local sound = {}

function sound.build()
	local os_name = require("build_tools.lua.get_os_name").get_os_name()
	local runner = os_name == "Windows" and "" or "mono "
	for _, tool in ipairs({"KEHmusic.exe", "KEHsfx.exe"}) do
		local success, _, code = os.execute(runner .. '"./' .. tool .. '"')
		if success ~= true and success ~= 0 then
			io.stderr:write(tool .. " failed (exit " .. tostring(code) .. "). ROM assembly was stopped.\n")
			return false
		end
	end
	return true
end

return sound
