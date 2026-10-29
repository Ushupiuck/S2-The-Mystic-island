#!/usr/bin/env python3
"""Execute water selection, initialization and dispatch for all 64 acts."""
import argparse
import json
from pathlib import Path

import native_test_core as m68k

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--rom', type=Path)
p.add_argument('--listing', type=Path)
p.add_argument('--output', type=Path)
args = p.parse_args()
m = m68k.Native(args.rom, args.listing)
assert m.s['ActsPerZone'] == 4
assert m.s['WaterFlags_End'] - m.s['WaterFlags'] == m.s['LevelActCount']
assert m.s['WaterHeight_End'] - m.s['WaterHeight'] == 2 * m.s['LevelActCount']
assert m.s['DynWater_Index_End'] - m.s['DynWater_Index'] == 2 * m.s['LevelActCount']
# Stop at the level-entry boundary and at palette loading; the tested code is
# the assembled selection/initialization, without entering VDP setup.
m.cpu.mem_write(m.s['Level_WaterFlagInit_End'], bytes.fromhex('4E75'))
m.cpu.mem_write(m.s['PalLoad3_Water'], bytes.fromhex('4E75'))
visited = []
targets = {m.s['DynWater_' + name]: name for name in ('Null', 'Debug', 'LZ2', 'LZ3', 'LZ4')}
m.cpu.hook_add(m68k.UC_HOOK_CODE, lambda cpu, address, size, unused:
               visited.append(targets[address]) if address in targets else None)
checks = []
for zone in range(m.s['LevelCount']):
    for act in range(m.s['ActsPerZone']):
        m.start()
        m.write('Current_ZoneAndAct', zone * 256 + act, 2)
        m.act('Level_WaterFlagInit')
        ghz4 = zone == 0 and act == 3
        wet = ghz4 or zone in (m.s['id_LZ'], m.s['id_HPZ'])
        assert bool(m.read('Water_flag')) == wet, (zone, act)
        m.write('v_waterpos1', 0x5A5A, 2)
        m.act('CheckLevelForWater')
        if wet:
            height = 0x600 if ghz4 else (0x600, 0x328, 0x900, 0x228)[act]
            assert [m.read('v_waterpos' + str(i), 2) for i in (1, 2, 3)] == [height] * 3
            palette = m.s['palid_GHZ4Water'] if ghz4 else m.s['palid_SBZ3Water'] if zone == m.s['id_LZ'] and act == 3 else m.s['palid_LZWater'] if zone == m.s['id_LZ'] else m.s['palid_HPZWater']
            assert m.cpu.reg_read(m68k.UC_M68K_REG_D0) == palette
        else:
            assert m.read('v_waterpos1', 2) == 0x5A5A
        visited.clear()
        m.act('DynamicWaterHeight')
        expected = ('Debug', 'LZ2', 'LZ3', 'LZ4')[act] if wet and not ghz4 else 'Null'
        assert visited == [expected], (zone, act, visited)
        checks.append([zone, act, wet, expected])

# Enable the final dry slot in the ROM fixture and give it a distinct height.
# This catches residual zone/act assumptions beyond merely checking defaults.
m.start()
index = m.s['LevelActCount'] - 1
m.cpu.mem_write(m.s['WaterFlags'] + index, b'\1')
m.cpu.mem_write(m.s['WaterHeight'] + 2 * index, bytes.fromhex('05A0'))
m.write('Current_ZoneAndAct', (m.s['LevelCount'] - 1) * 256 + 3, 2)
m.act('Level_WaterFlagInit')
m.act('CheckLevelForWater')
assert m.read('Water_flag') == 1 and m.read('v_waterpos1', 2) == 0x5A0
report = {'acts': checks, 'last_slot_enabled_at_runtime': True}
if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
print('All 64 water flag/height/routine selections and final-slot enable passed.')
