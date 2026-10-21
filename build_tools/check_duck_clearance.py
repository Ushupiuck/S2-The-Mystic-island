#!/usr/bin/env python3
"""Check assembled solid-object duck clearance with Sonic-only 68000 fixtures.

Uses the optional Unicorn dependency and Native harness already used by the
object checks. No companion AI or natural playthrough is run here.
"""
from pathlib import Path
import argparse
import json

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--rom', type=Path, required=True)
p.add_argument('--listing', type=Path, required=True)
p.add_argument('--output', type=Path)
args = p.parse_args()
import native_test_core as m68k
m = m68k.Native(args.rom, args.listing)
obj = m.s['v_lvlobjspace']


def setup(pose, x=4096, y=4096):
    m.start()
    m.put('v_player2', 'obRender', 0)  # no companion updates/collisions
    status, radius, animation = {
        'standing': (0, 19, 'AniIDSonAni_Wait'),
        'ducking': (0, 19, 'AniIDSonAni_Duck'),
        'airborne-duck': (2, 19, 'AniIDSonAni_Duck'),
        'rolling': (4, 14, 'AniIDSonAni_Roll'),
        'spindash': (4, 14, 'AniIDSonAni_Spindash'),
    }[pose]
    for field, value, size in [('obX', x, 2), ('obY', y, 2),
                              ('obHeight', radius, 1), ('obStatus', status, 1),
                              ('obAnim', m.s[animation], 1), ('obVelY', 0, 2)]:
        m.put('v_player', field, value, size)
    for field, value, size in [('code', m.s['SMZ_Girder'], 4),
                              ('obRender', 0x84, 1), ('obActWid', 96, 1),
                              ('obHeight', 24, 1), ('obX', x, 2)]:
        m.put(obj, field, value, size)
    return radius


def solid():
    m.act('SolidObject', obj, regs={m68k.UC_M68K_REG_D1:107,
                                  m68k.UC_M68K_REG_D2:24,
                                  m68k.UC_M68K_REG_D3:25,
                                  m68k.UC_M68K_REG_D4:m.get(obj,'obX',2)})


checks = []
for pose in ('standing', 'ducking', 'airborne-duck', 'rolling', 'spindash'):
    for gap in (10, 20, 21, 22, 23, 24, 26, 31, 32, 33, 34, 38, 48):
        radius = setup(pose)
        m.put(obj,'obY',4096+radius-gap-24,2)
        solid()
        dead = m.get('v_player','obRoutine') >= 6
        expected = False if pose=='airborne-duck' else gap < (
            2*m.s['sonic_roll_height']-4 if pose=='ducking' else 2*radius-4)
        assert dead == expected, (pose,gap,dead,expected)
        if not dead and pose!='airborne-duck':
            assert m.get('v_player','obY',2)==4096, (pose,gap,'feet moved')
            assert m.get('v_player','obHeight')==radius, (pose,gap,'radius changed')
        checks.append({'case':'overhead','pose':pose,'gap':gap,'dead':dead})

# Clearing an old side contact must not replace Duck with walking and expose
# the full-height hitbox to another object later in the same frame.
setup('ducking')
m.put('v_player','obStatus',1<<m.s['status.player.pushing'])
m.put(obj,'obStatus',1<<m.s['status.npc.p1_pushing'])
m.put(obj,'obY',4096+19-31-24,2)
solid()
assert m.get('v_player','obAnim')==m.s['AniIDSonAni_Duck']
assert not m.get('v_player','obStatus')&(1<<m.s['status.player.pushing'])
assert not m.get(obj,'obStatus')&(1<<m.s['status.npc.p1_pushing'])
checks.append({'case':'clear-side-contact-keeps-duck','passed':True})

# Compare the landing/support point with the standing case. Only the top of
# the player's collision envelope changes; the feet and ride offset do not.
landings = []
for pose in ('standing','ducking'):
    setup(pose,y=457)
    m.put(obj,'obY',500,2)
    solid()
    assert m.get('v_player','obStatus')&8
    landings.append(m.get('v_player','obY',2))
    m.put(obj,'obY',499,2)
    solid()
    assert m.get('v_player','obY',2)==landings[-1]-1
    assert m.get('v_player','obHeight')==19
assert landings[0]==landings[1]
checks.append({'case':'landing-and-riding-foot-position','passed':True})

# Compare whole contacts with a rolling Sonic at the same foot point, including
# deeper overlaps where the top/bottom choice matters as much as clearance.
for dx in (-99,-80,0,80,99):
    for dy in (-40,-30,-20,-10,-7,-5,0,4,5,7,8,9,10,20,30,40):
        contacts=[]
        for pose,radius in [('ducking',19),('rolling',14),('spindash',14)]:
            setup(pose,x=4096+dx,y=4115-radius)
            m.put(obj,'obX',4096,2)
            m.put(obj,'obY',4096+dy,2)
            m.put('v_player','obVelX',0x100 if dx<=0 else -0x100,2)
            solid()
            contacts.append((m.get('v_player','obX',2),
                m.get('v_player','obY',2)+m.get('v_player','obHeight'),
                m.get('v_player','obRoutine'),m.get('v_player','obStatus')&~4,
                m.get('v_player','obVelX',2),m.get('v_player','obVelY',2)))
        assert contacts[0]==contacts[1]==contacts[2],(dx,dy,contacts)
        checks.append({'case':'compact-contact-equivalence','dx':dx,'dy':dy,'passed':True})

report = {'passed':True,'checks':checks,'companion_ai_run':False}
if args.output:
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
print(f'{len(checks)} Sonic-only duck/stand/air/roll/spindash and support checks pass.')
