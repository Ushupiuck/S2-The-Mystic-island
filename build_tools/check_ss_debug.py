#!/usr/bin/env python3
"""Check authored-grid placement, fixed-point ties and bounded free-cell search."""
import json

from native_test_core import (Native, UC_M68K_REG_A2, UC_M68K_REG_D7)

m = Native()
base = m.s['v_ssblockbuffer']
stride = m.s['S1SS_LayoutStride']
width, height = m.s['S1SS_LayoutWidth'], m.s['S1SS_LayoutHeight']
layout_size = m.s['v_ssbuffer2'] - m.s['v_ssbuffer1']
start = m.s['v_ssbuffer1'] & 0xFFFFFF
entry = m.s['Debug_SS'] + 2


def position(col, row, dx=0, dy=0, fraction=0):
    m.put('v_player', 'obX', ((col + 32) * 24 - 20 + dx) * 65536 + fraction, 4)
    m.put('v_player', 'obY', ((row + 32) * 24 - 68 + dy) * 65536 + fraction, 4)


def reset(fill=0x25):
    m.start()
    m.write('v_gamemode', m.s['BonusStage'], 2)
    m.write('v_jpadpress1', m.s['btnC'])
    # Distinct padding lets us detect any write outside the authored cells.
    m.cpu.mem_write(start, bytes([0xA7]) * layout_size)
    for row in range(height):
        m.cpu.mem_write((base + row * stride) & 0xFFFFFF, bytes([fill]) * width)


def place():
    m.act('Debug_SpawnObject', 'v_player',
          {UC_M68K_REG_A2: entry, UC_M68K_REG_D7: 0x13579BDF}, limit=1000000)
    assert m.cpu.reg_read(UC_M68K_REG_D7) == 0x13579BDF
    assert not any(m.get(obj, 'code') for obj in range(
        m.s['v_lvlobjspace'], m.s['v_lvlobjend'], m.s['object_size']))


def cell(col, row):
    return int.from_bytes(m.cpu.mem_read((base + row * stride + col) & 0xFFFFFF, 1), 'big')


checks = 0
# Every boundary cell, with all other cells occupied, must remain reachable.
for col, row in [(0, 0), (63, 0), (0, 63), (63, 63), (31, 31), (32, 32)]:
    reset()
    m.cpu.mem_write((base + row * stride + col) & 0xFFFFFF, b'\0')
    position(col, row)
    before = bytes(m.cpu.mem_read(start, layout_size))
    place()
    expected = bytearray(before)
    expected[base - m.s['v_ssbuffer1'] + row * stride + col] = m.s['S1SS_RingItem']
    assert bytes(m.cpu.mem_read(start, layout_size)) == expected
    checks += 1

# At an exact horizontal halfway point, left wins; right is the next spiral cell.
reset(0)
position(30, 30, dx=12)
place()
assert cell(30, 30) == 0x3A and cell(31, 30) == 0
place()
assert cell(31, 30) == 0x3A
reset(0)
position(30, 30, dx=12, fraction=1)
place()
assert cell(31, 30) == 0x3A and cell(30, 30) == 0
checks += 3

reset(0)
position(30, 30, dy=12)
place()
assert cell(30, 30) == 0x3A and cell(30, 31) == 0
reset(0)
position(30, 30, dy=12, fraction=1)
place()
assert cell(30, 31) == 0x3A
checks += 2

# Placement is independent of the ordinary SST pool, even when it is full.
reset(0)
position(30, 30)
pool_start, pool_end = m.s['v_lvlobjspace'], m.s['v_lvlobjend']
for obj in range(pool_start, pool_end, m.s['object_size']):
    m.put(obj, 'code', m.s['ObjNull'], 4)
pool_before = bytes(m.cpu.mem_read(pool_start & 0xFFFFFF, pool_end - pool_start))
m.act('Debug_SpawnObject', 'v_player', {UC_M68K_REG_A2: entry})
assert cell(30, 30) == 0x3A
assert bytes(m.cpu.mem_read(pool_start & 0xFFFFFF, pool_end - pool_start)) == pool_before
checks += 1

# Repeated presses expand clockwise without touching existing cells or padding.
reset(0)
position(30, 30)
order = [(0, 0), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0),
         (-1, -1), (0, -1), (1, -1), (2, -1), (2, 0), (2, 1)]
for dx, dy in order:
    assert cell(30 + dx, 30 + dy) == 0
    place()
    assert cell(30 + dx, 30 + dy) == 0x3A
    checks += 1

# A sole free cell in the opposite corner exercises the entire bounded search.
for origin, target in [((0, 0), (63, 63)), ((63, 63), (0, 0))]:
    reset()
    col, row = target
    m.cpu.mem_write((base + row * stride + col) & 0xFFFFFF, b'\0')
    position(*origin)
    place()
    assert cell(col, row) == 0x3A
    before = bytes(m.cpu.mem_read(start, layout_size))
    place()  # Full authored grid: return with every byte unchanged.
    assert bytes(m.cpu.mem_read(start, layout_size)) == before
    checks += 2

# Cursors in the surrounding RAM/padding cannot place anything there.
for col, row in [(-1, 0), (64, 0), (0, -1), (0, 64), (-20, -20), (100, 100)]:
    reset(0)
    position(col, row)
    before = bytes(m.cpu.mem_read(start, layout_size))
    place()
    assert bytes(m.cpu.mem_read(start, layout_size)) == before
    checks += 1

# The inserted byte is collected through the real rotating-stage item handler.
reset(0)
position(30, 30)
place()
m.act('SSS_ChkItems', 'v_player')
assert m.read('v_rings', 2) == 1
m.act('SS_AniItems')
assert cell(30, 30) != 0x3A

print(json.dumps({'checks': checks + 1, 'real_grid_ring_collects': True,
                  'no_SST_allocation': True, 'padding_preserved': True,
                  'full_grid_terminates': True, 'D7_preserved': True}, indent=2))
