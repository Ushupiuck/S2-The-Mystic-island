#!/usr/bin/env lua

--------------
-- Settings --
--------------

-- Set this to true to use a better compression algorithm for the DAC driver.
-- Having this set to false will use an inferior compression algorithm that
-- results in an accurate ROM being produced.
local improved_dac_driver_compression = true
local advanced_error_handler = false

---------------------
-- End of settings --
---------------------

-------------------------------------
-- Actual build script begins here --
-------------------------------------

local common = require "build_tools.lua.common"

-- Keep the HUD's hexadecimal digits in sync with the shared menu/error font.
-- Pack only 0-F and adapt its foreground to the HUD's white palette slot.
do
	local source = assert(io.open("art/uncompressed/Level select and Debug Mode text.bin", "rb"))
	local font = source:read("*a"); source:close()
	assert(#font >= 23 * 32, "Shared font is missing hexadecimal glyphs")
	local digits = font:sub(1, 10 * 32) .. font:sub(17 * 32 + 1, 23 * 32)
	digits = digits:gsub(".", function(byte)
		local value = byte:byte()
		local high, low = value >> 4, value & 0xF
		assert((high == 0 or high == 0xF) and (low == 0 or low == 0xF),
			"Shared font must use transparent $0 and foreground $F")
		return string.char(value & 0x66)
	end)
	local path = "art/uncompressed/Debug Digits.bin"
	local previous = io.open(path, "rb")
	local old = previous and previous:read("*a")
	if previous then previous:close() end
	if old ~= digits then
		local output = assert(io.open(path, "wb"))
		output:write(digits); output:close()
	end
end

if not require("build_tools.lua.sound").build() then
	os.exit(false, true)
end

-- Produce PCM and DPCM data.
--common.convert_pcm_files_in_directory("sound/dac/pcm")
--common.convert_dpcm_files_in_directory("sound/dac/dpcm")

require("build_tools.lua.compressed_assets").generate()

-- Build the ROM.
local compression = improved_dac_driver_compression and "kosinskiplus" or "kosinski"
local p2bin_arguments = "-p=FF -z=0," .. compression .. ",Size_of_DAC_driver_guess,after"
local repository = "https://github.com/sonicretro/s1disasm"
local sprite_bounds = require "build_tools.lua.sprite_bounds"
if not sprite_bounds.generate(common, "", p2bin_arguments, repository) then
	os.exit(false, true)
end
local message, abort = common.build_rom("md-main", "s2built", "", p2bin_arguments, false, repository)

if message then
	exit_code = false
end

if abort then
	os.exit(exit_code, true)
end

if advanced_error_handler then   
   -- Buld DEBUG ROM
   compression = improved_dac_driver_compression and "kosinskiplus" or "kosinski"
   message, abort = common.build_rom("md-main", "s2built.debug", "-D __DEBUG__ -OLIST md-main.debug.lst", "-p=FF -z=0," .. compression .. ",Size_of_DAC_driver_guess,after", false, "https://github.com/sonicretro/s1disasm")
   
   if message then
       exit_code = false
   end
   
   if abort then
       os.exit(exit_code, true)
   end
   
   -- Append symbol table to the ROM.
   local extra_tools = common.find_tools("debug symbol generator", "https://github.com/vladikcomper/md-modules", "https://github.com/sonicretro/s1disasm", "convsym")
   if not extra_tools then
       os.exit(false)
   end
   os.execute(extra_tools.convsym .. " md-main.lst s2built.bin -input as_lst -range 0 FFFFFF -exclude -filter \"z[A-Z].+\" -a")
   os.execute(extra_tools.convsym .. " md-main.debug.lst s2built.debug.bin -input as_lst -range 0 FFFFFF -exclude -filter \"z[A-Z].+\" -a")
end   

-- Correct the ROM's header with a proper checksum and end-of-ROM value.
common.fix_header("s2built.bin")
if advanced_error_handler then
	common.fix_header("s2built.debug.bin")
end

os.exit(exit_code, false)
