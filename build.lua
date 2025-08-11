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

-- Produce PCM and DPCM data.
common.convert_pcm_files_in_directory("sound/dac/pcm")
common.convert_dpcm_files_in_directory("sound/dac/dpcm")

-- Build the ROM.
local compression = improved_dac_driver_compression and "kosinskiplus" or "kosinski"
local message, abort = common.build_rom("main", "s2built", "", "-p=FF -z=0," .. compression .. ",Size_of_DAC_driver_guess,after", false, "https://github.com/sonicretro/s1disasm")

if message then
	exit_code = false
end

if abort then
	os.exit(exit_code, true)
end

if advanced_error_handler then   
   -- Buld DEBUG ROM
   compression = improved_dac_driver_compression and "kosinskiplus" or "kosinski"
   message, abort = common.build_rom("main", "s2built.debug", "-D __DEBUG__ -OLIST main.debug.lst", "-p=FF -z=0," .. compression .. ",Size_of_DAC_driver_guess,after", false, "https://github.com/sonicretro/s1disasm")
   
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
   os.execute(extra_tools.convsym .. " main.lst s2built.bin -input as_lst -range 0 FFFFFF -exclude -filter \"z[A-Z].+\" -a")
   os.execute(extra_tools.convsym .. " main.debug.lst s2built.debug.bin -input as_lst -range 0 FFFFFF -exclude -filter \"z[A-Z].+\" -a")
end   

-- Correct the ROM's header with a proper checksum and end-of-ROM value.
common.fix_header("s2built.bin")
if advanced_error_handler then
	common.fix_header("s2built.debug.bin")
end

os.exit(exit_code, false)