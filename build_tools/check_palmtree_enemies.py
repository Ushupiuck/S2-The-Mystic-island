#!/usr/bin/env python3
"""Exercise the imported PP enemies against LV0A's ordinary stage terrain.

Fixtures initialize actor positions and enemies, then use the ROM's real
collision, animation, damage, allocation, rendering and unload routines.
This checks the badnik import, not a port or playthrough of Palmtree Panic.
"""
from pathlib import Path
import argparse, json, struct
from genesis_test_core import Genesis
from check_object_course import boot_level, snapshot
from check_companion_followup import place, reset_cpu, spawn, isolate

ROOT = Path(__file__).resolve().parents[1]
ENEMIES = ('Anton', 'Mosqui', 'PataBata', 'TagaTaga', 'Tamabboh')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--'+name, type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
    boot_level(g, zone=0xA)
    assert g.read('Current_ZoneAndAct', 2) == 0xA00
    stage = g.save()
    report = []

    def finish(case, **details):
        assert not g.read('v_errortype'), (case, 'ROM exception')
        report.append({'case': case, 'passed': True, **details})
        print(report[-1], flush=True)

    # Confirm actual VDP uploads, including the independent carrier bank.
    for name in ENEMIES:
        base = g.s['ArtTile_PP_'+name]*32
        filename = name.replace('PataBata', 'Pata-Bata').replace('TagaTaga', 'Taga-Taga')
        raw = (ROOT/f'art/uncompressed/PP {filename}.unc').read_bytes()
        assert raw == bytes(g.vram[(base+i)^1] for i in range(len(raw)))
    base = g.s['ArtTile_Wheel']*32
    raw = (ROOT/'art/uncompressed/Wheel carrier.unc').read_bytes()
    assert raw == bytes(g.vram[(base+i)^1] for i in range(len(raw)))
    finish('resident-PP-and-wheel-art')

    isolate(g)
    for actor, x in (('v_player', 700), ('v_player2', 720)):
        place(g, actor, x, 300)
        g.put(actor, 'obControl', 0x81)
    g.write('Camera_X_pos', 320, 2)
    g.write('Camera_Y_pos', 160, 2)
    unit = g.save()

    for name in ENEMIES:
        for variant in (0, 1):
            g.restore(unit)
            g.put('v_player2', 'code', 0)  # keep patrol fixtures free of CPU arrival
            y = {'Anton':365, 'Mosqui':320, 'PataBata':300,
                 'TagaTaga':384, 'Tamabboh':369}[name]
            obj = spawn(g, 'PP_'+name, 480, y, variant)
            rows = []
            for _ in range(400):
                g.run()
                assert g.get(obj, 'code') == g.s['PP_'+name], (name, variant, snapshot(g, obj))
                rows.append(snapshot(g, obj))
            xs = [r['obX'] for r in rows]
            ys = [r['obY'] for r in rows]
            frames = sorted({r['obFrame'] for r in rows})
            assert len(frames) >= 2, (name, variant, frames)
            if name == 'TagaTaga':
                assert min(ys) < y-40 and max(ys) <= y+4
                assert any(r['obColType'] == 0 for r in rows)
                assert any(r['obColType'] == 6 for r in rows)
            else:
                assert max(xs)-min(xs) > 60 and all(abs(x-480) <= 128 for x in xs)
            if name == 'PataBata':
                assert max(ys)-min(ys) >= (60 if variant == 0 else 30)
            finish(f'{name}-variant-{variant}-motion', x_range=[min(xs),max(xs)],
                   y_range=[min(ys),max(ys)], frames=frames)
            g.video.save(args.output/f'{name}-{variant}.png')

    # Each actor independently triggers a dive / a pair of missiles.
    for name in ('Mosqui', 'Tamabboh'):
        for actor in ('v_player', 'v_player2'):
            g.restore(unit)
            y = 320 if name == 'Mosqui' else 369
            obj = spawn(g, 'PP_'+name, 480, y)
            place(g, actor, 524, 357)
            g.put(actor, 'obControl', 1)
            g.buttons2 = {4}  # manual down keeps the companion at this fixture
            reset_cpu(g)
            routines, missile_peak, missile_directions = set(), 0, set()
            for _ in range(120):
                g.run()
                routines.add(g.get(obj, 'obRoutine'))
                children = [a for a in range(g.s['v_lvlobjspace']&65535,
                            g.s['v_lvlobjend']&65535,g.s['object_size'])
                            if g.get(a,'code',4)==g.s['PP_TamabbohMissile']]
                missile_peak = max(missile_peak, len(children))
                missile_directions.update(g.get(a,'objoff_30',4) for a in children
                                          if g.get(a,'obRoutine')==2)
            if name == 'Mosqui':
                assert {4,6,8} <= routines, (actor, routines)
            else:
                assert missile_peak == 2 and {0x20000,0xFFFE0000} <= missile_directions
            finish(f'{name}-trigger-{actor}', routines=sorted(routines), missiles=missile_peak)

    # The ordinary touch handler must let either rolling actor defeat all five.
    for name in ENEMIES:
        for actor in ('v_player', 'v_player2'):
            g.restore(unit)
            obj = spawn(g, 'PP_'+name, 480, 384 if name == 'TagaTaga' else 350)
            for _ in range(180):
                g.run()
                if g.get(obj, 'obColType') and (name != 'TagaTaga' or g.get(obj,'obY',2)<352):
                    break
            else:
                raise AssertionError((name, 'never vulnerable'))
            x, y = g.get(obj,'obX',2),g.get(obj,'obY',2)
            place(g, actor, x, y-4)
            for field,value,size in [('obAnim',2,1),('obStatus',6,1),('obHeight',9,1),
                                     ('obWidth',7,1),('jumping',1,1),('obVelY',0x100,2)]:
                g.put(actor,field,value,size)
            g.buttons2={4}; reset_cpu(g)
            for _ in range(10):
                g.run()
                if g.get(obj,'code',4)!=g.s['PP_'+name]:
                    break
            assert g.get(obj,'code',4)!=g.s['PP_'+name], (name,actor,snapshot(g,obj))
            finish(f'{name}-defeated-by-{actor}')

    for actor in ('v_player','v_player2'):
        g.restore(unit)
        obj=spawn(g,'PP_TamabbohMissile',480,350);g.run()
        place(g,actor,480,346);g.buttons2={4};reset_cpu(g)
        for _ in range(8):
            g.run()
            if g.get(actor,'obRoutine')==4:break
        assert g.get(actor,'obRoutine')==4,(actor,'missile did not hurt')
        finish(f'missile-hurts-{actor}')

    # Native S3&K placement ownership must unload and reload every imported row.
    records=(ROOT/'level/objects/LV0A_1.bin').read_bytes()
    for i in range(len(records)//8-1):
        x,y,oid,eras,sub=struct.unpack_from('>HHBBH',records,i*8)
        if oid<0xB1:continue
        g.restore(stage)
        tag=g.placement_handle(i)
        def visit(px):
            # Reopen the camera range after visits to the template's goal area.
            # This fixture tests backtracking ownership, not the signpost lock.
            g.write('Camera_Min_X_pos',0,2)
            g.write('Camera_Max_X_pos',1536,2)
            for actor in ('v_player','v_player2'):
                place(g,actor,px,300);g.put(actor,'obControl',0x81)
            g.write('Camera_X_pos',max(0,min(1536,px-160)),2)
            g.run(100)
        visit(x)
        assert any(g.get(a,'respawn_addr',2)==tag for a in range(g.s['v_lvlobjspace']&65535,
                   g.s['v_lvlobjend']&65535,g.s['object_size'])), (i,'not loaded')
        visit(1400 if x<900 else 80)
        assert not g.placement_read(i)&128, (i,'respawn flag not released',g.read('Camera_X_pos',2),g.get('v_player','obX',2),[(snapshot(g,a),g.get(a,'objoff_30',2)) for a in range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']) if g.get(a,'respawn_addr',2)==tag])
        visit(x)
        assert g.placement_read(i)&128, (i,'not reloaded')
        finish(f'placement-{oid:02X}-{sub}-reload')

    (args.output/'report.json').write_text(json.dumps({'region':'PAL' if args.pal else 'NTSC',
                                                    'cases':report},indent=2)+'\n')
    g.close()
    print('Palmtree enemy checks passed',flush=True)


if __name__=='__main__':
    main()
