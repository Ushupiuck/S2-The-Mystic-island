#!/usr/bin/env python3
"""Exercise contacts and effects in the disposable LZ2 course.

Player positions are scripted; collisions, pickups, damage, spawning,
animations, PLC/DMA uploads, respawn persistence and deletion run in the ROM.
No health, object hit/pressed routines or respawn outcome flags are injected.
"""
from pathlib import Path
import argparse
import json
import re
from genesis_test_core import Genesis
from check_object_course import boot_level,position,objects,owner,snapshot


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build',type=Path,required=True)
    p.add_argument('--core',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--pal',action='store_true')
    p.add_argument('--player',type=int,default=0,choices=(0,2))
    p.add_argument('--filter',help='Only check names matching this regular expression')
    args=p.parse_args()
    g=Genesis(args.core,args.build/'object-course.bin',args.build/'object-course.lst',args.output,args.pal)
    boot_level(g,player=args.player)
    initial=g.save()
    cases={o['name']:o for b in json.loads((args.build/'course.json').read_text())['banks'] for o in b['objects']}
    executed=set();report={'region':'PAL' if args.pal else 'NTSC','primary':'Tails' if args.player==2 else 'Sonic','checks':[]}

    def prepare(name,behind=112):
        g.restore(initial);g.put('v_player2','layout_id',0)
        obj=cases[name];position(g,obj['world_x']-behind)
        g.run(90)
        actors=owner(g,obj)
        assert actors,('missing before contact',name)
        g.put('v_player','obStatusSecondary',0);g.put('v_player','invtime',0,2)
        return obj,actors[0]

    def player(x,y,vx=0,vy=0x100,rolling=False):
        radius=14 if rolling else (15 if args.player==2 else 19)
        for f,v,z in [('obX',x,2),('obY',y,2),('obVelX',vx,2),('obVelY',vy,2),
                      ('obInertia',vx,2),('obStatus',6 if rolling else 2,1),
                      ('obControl',0,1),('obAnim',2 if rolling else 0,1),
                      ('obRoutine',2,1),('obHeight',radius,1),('obWidth',7 if rolling else 9,1),
                      ('flashtime',0,2),('obAngle',0,1)]:g.put('v_player',f,v,z)

    def run_check(name,fn):
        if args.filter and not re.search(args.filter,name):
            return
        try:
            detail=fn() or {}
            row={'name':name,'passed':True,**detail}
        except AssertionError as e:
            row={'name':name,'passed':False,'failure':str(e)}
        executed.update(i for i in range(1,256) if g.read(g.s['ObjectTest_Executed']+i))
        report['checks'].append(row)
        report['executed_ids']=[f'{i:02X}' for i in sorted(executed)]
        g.video.save(args.output/(name.replace(' ','-').replace('/','-')+'.png'))
        (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(name, 'PASS' if row['passed'] else row['failure'],flush=True)

    def pickup_ring():
        obj,a=prepare('Rings');before=g.read('v_rings',2)
        player(g.get(a,'obX',2),g.get(a,'obY',2),rolling=True)
        g.run(3)
        assert g.read('v_rings',2)>before,(before,g.read('v_rings',2))
        g.run(40)
        assert not owner(g,obj), 'collected ring retained SST'
        position(g,obj['world_x']+0x700);g.run(90)
        position(g,obj['world_x']-64);g.run(90)
        assert not owner(g,obj),'collected ring respawned'
        return {'rings_added':g.read('v_rings',2)-before,'consumed':True}
    run_check('Ring pickup and consumption',pickup_ring)

    def monitor(name,bit):
        obj,a=prepare(name)
        player(g.get(a,'obX',2),g.get(a,'obY',2)-28,rolling=True)
        g.run(100)
        assert g.get('v_player','obStatusSecondary')&(1<<bit),(name,g.get('v_player','obStatusSecondary'),snapshot(g,a))
        assert g.placement_read(obj['index'])&1,'monitor state not recorded'
        position(g,obj['world_x']+0x700);g.run(90)
        position(g,obj['world_x']-64);g.run(90)
        actors=owner(g,obj);assert len(actors)==1,'monitor duplicate or absent'
        assert g.get(actors[0],'obColType')==0,'broken monitor became breakable again'
        return {'pickup':True,'broken_state_survives_revisit':True}
    for name,bit in [('Shield monitor',0),('Invincibility monitor',1),('Speed monitor',2)]:
        run_check(name+' pickup and persistence',lambda n=name,b=bit:monitor(n,b))

    def checkpoint():
        obj,a=prepare('Checkpoint')
        player(g.get(a,'obX',2),g.get(a,'obY',2)-16,vy=0)
        g.run(5)
        assert g.read('v_lastlamp')==1,g.read('v_lastlamp')
        assert g.placement_read(obj['index'])&1
        position(g,obj['world_x']+0x700);g.run(90)
        position(g,obj['world_x']-64);g.run(90)
        assert len(owner(g,obj))==1
        assert g.get(owner(g,obj)[0],'obRoutine')==4
        return {'activated':True,'state_survives_revisit':True}
    run_check('Checkpoint activation and persistence',checkpoint)

    def spring(name):
        obj,a=prepare(name)
        x,y=g.get(a,'obX',2),g.get(a,'obY',2)
        if name=='Side spring':player(x+32,y,vx=-0x400,vy=0)
        elif name=='Diagonal spring':player(x+16,y-40)
        else:player(x,y-48)
        velocities=[]
        for _ in range(50):
            g.run();velocities.append((g.get('v_player','obVelX',2),g.get('v_player','obVelY',2)))
        signed=lambda v:v-65536 if v&32768 else v
        maximum_x=max(abs(signed(x)) for x,y in velocities)
        minimum_y=min(signed(y) for x,y in velocities)
        assert maximum_x>=0x800 or minimum_y<=-0x800,(name,maximum_x,minimum_y,snapshot(g,a))
        return {'maximum_x_velocity':maximum_x,'minimum_y_velocity':minimum_y}
    for name in ('Up spring','Side spring','Diagonal spring'):
        run_check(name+' launches player',lambda n=name:spring(n))

    def spikes(name):
        obj,a=prepare(name)
        x,y=g.get(a,'obX',2),g.get(a,'obY',2)
        player(x,y+36 if name=='Ceiling spikes' else y-48,vy=-0x400 if name=='Ceiling spikes' else 0x100)
        damaged=False
        for _ in range(60):
            g.run();damaged|=g.get('v_player','obRoutine')>=4
        assert damaged,(name,snapshot(g,a))
        rings=g.read('v_rings',2)
        if args.player==2:assert rings==0,'solo Tails must lose rings'
        else:assert rings==0,'Sonic must lose rings'
        return {'damaged':True,'rings_after_hit':rings}
    for name in ('Floor spikes','Ceiling spikes'):
        run_check(name+' damage',lambda n=name:spikes(n))

    def ride(name):
        obj,a=prepare(name)
        x,y=g.get(a,'obX',2),g.get(a,'obY',2)
        if name=='Hanging platform':
            # The solid platform is the last pendulum link, not its placement origin.
            y=g.get(a,'obY',2)
        player(x,y-88)
        stood=False;released=False;ys=[]
        for _ in range(160):
            # Follow the moving target horizontally until the downward contact;
            # after landing the game's own rider transport is responsible.
            if not stood:
                g.put('v_player','obX',g.get(a,'obX',2),2)
            g.run();standing=bool(g.get('v_player','obStatus')&8)
            stood|=standing;released|=stood and not standing
            ys.append(g.get('v_player','obY',2))
        assert stood,(name,snapshot(g,a),g.get('v_player','obY',2))
        if name in ('Collapsing platform','Collapsing floor'):
            assert released,'collapse did not release rider'
        # Leaving must remove its owned children too; the course has one of each.
        position(g,obj['world_x']+0x700);g.run(120)
        if name in ('Bridge','Hanging platform','Tall waterfall'):
            assert not objects(g,int(obj['id'],16)),('orphan child',name,objects(g,int(obj['id'],16)))
        return {'stood':stood,'released':released,'travel_pixels':max(ys)-min(ys)}
    for name in ('Bridge','Hanging platform','Descending lift','Moving platform','CPZ platform',
                 'Collapsing platform','Collapsing floor','Tilting platform','Morphing platform','Purple rock'):
        run_check(name+' riding and cleanup',lambda n=name:ride(n))

    def bumper():
        obj,a=prepare('Bumper');player(g.get(a,'obX',2)-16,g.get(a,'obY',2),vx=0x200,vy=0)
        g.run(4)
        assert g.get('v_player','obVelX',2) or g.get('v_player','obVelY',2)
        assert g.get(a,'obAnim')==1,(snapshot(g,a),g.get('v_player','obRoutine'))
        return {'bounced':True}
    run_check('Bumper bounce',bumper)

    def destruction(name):
        obj,a=prepare(name,behind=224)
        player(g.get(a,'obX',2),g.get(a,'obY',2)-16,rolling=True)
        original=int(obj['id'],16);destroyed=False
        for _ in range(10):
            g.run();destroyed|=g.get(a,'layout_id')!=original
        assert destroyed,(name,snapshot(g,a))
        g.run(120)
        position(g,obj['world_x']+0x700);g.run(90)
        position(g,obj['world_x']-224);g.run(60)
        assert not owner(g,obj),(name,'defeated enemy respawned')
        return {'destroyed_by_rolling_collision':True,'consumed':True}
    for name in ('Moto Bug','Crabmeat','Ball Hog horizontal','Buzz Bomber','Caterkiller','Basaran',
                 'Buzzer','Snailbot','Splats','BBat','Rhinobot','Jaws','Piranha','Aquis','Octus','Skyhorse'):
        run_check(name+' attack and consumption',lambda n=name:destruction(n))

    def wall():
        obj,a=prepare('Smashable wall')
        player(g.get(a,'obX',2)-42,0x500-14,vx=0x600,vy=0,rolling=True)
        g.put('v_player','obStatus',4)
        fragments=False
        for _ in range(10):
            g.run();fragments|=len(objects(g,0x3C))>1
        assert fragments,('wall did not shatter',snapshot(g,a))
        g.run(150)
        assert not objects(g,0x3C),'wall fragments did not clear'
        return {'shattered':True,'fragments_cleared':True}
    run_check('Wall shatter and fragment cleanup',wall)

    def door():
        obj,a=prepare('Small door')
        assert g.get(a,'obFrame')==0
        position(g,g.get(a,'obX',2)-24)
        g.run(20);assert g.get(a,'obFrame')==8,snapshot(g,a)
        position(g,g.get(a,'obX',2)+100)
        g.run(20);assert g.get(a,'obFrame')==0,snapshot(g,a)
        assert g.read('v_gamemode',2)==g.s['Level']
        return {'opened':True,'closed':True}
    run_check('Small door opening and closing',door)

    def path_switch():
        obj,a=prepare('Vertical path switch')
        position(g,g.get(a,'obX',2),g.get(a,'obY',2));g.run(2)
        position(g,g.get(a,'obX',2)+16,g.get(a,'obY',2));g.run(2)
        assert g.get('v_player','obTopSolidBit')==0xE,g.get('v_player','obTopSolidBit')
        return {'collision_path_changed':True}
    run_check('Path switch changes collision layer',path_switch)

    def waterfall_cleanup():
        obj,a=prepare('Tall waterfall')
        assert len(objects(g,0x1E))==3
        position(g,obj['world_x']+0x700);g.run(90)
        assert not objects(g,0x1E)
        return {'three_parts_created':True,'all_parts_unloaded':True}
    run_check('Tall waterfall child ownership',waterfall_cleanup)

    def seesaw():
        obj,a=prepare('Seesaw')
        parts=objects(g,0x5E);assert len(parts)==2
        player(g.get(a,'obX',2)-40,g.get(a,'obY',2)-64)
        ball=next(b for b in parts if b!=a)
        stood=False;launched=False
        for _ in range(180):
            g.run();stood|=bool(g.get('v_player','obStatus')&8)
            launched|=bool(g.get(ball,'obVelY',2)&0x8000)
        assert stood and launched,(stood,launched,snapshot(g,a),snapshot(g,ball))
        position(g,obj['world_x']-0x700);g.run(120)
        assert not objects(g,0x5E),'seesaw child survived parent unload'
        return {'rode':True,'ball_launched':True,'parts_unloaded':True}
    run_check('Seesaw ball and cleanup',seesaw)

    def big_rings():
        obj,a=prepare('Giant ring 1')
        player(obj['world_x'],obj['world_y'],vy=0,rolling=True);g.run(2)
        second=cases['Giant ring 2']
        player(second['world_x'],second['world_y'],vy=0,rolling=True);g.run(2)
        maximum=0;queued=False
        for _ in range(90):
            g.run();queued|=bool(g.read('f_bigring'))
            maximum=max(maximum,sum(bool(g.get(a,'ob2ndRout')&1) for a in objects(g,0x7C)))
        assert queued, 'entry not queued'
        assert maximum<=1,('duplicate art owner',maximum)
        assert g.read('v_gamemode',2)==g.s['Level']
        return {'two_entries_crossed':True,'entry_queued':True,'maximum_flash_owners':maximum}
    run_check('Successive giant rings share one flash',big_rings)

    def spindash():
        g.restore(initial);g.put('v_player2','layout_id',0)
        position(g,192,frozen=False);g.run(5)
        g.put('v_player','obStatusSecondary',0)
        g.buttons={5};g.run(3)
        g.buttons={5,0};g.run(2)
        g.buttons={5};g.run(15)
        assert g.get('v_player','obAnim')==g.s['AniIDSonAni_Spindash'],g.get('v_player','obAnim')
        dust=g.get('v_player','player_dust_ptr',2)
        assert g.get(dust,'layout_id')==0x0E
        g.buttons=set();g.run(2)
        speed=g.get('v_player','obInertia',2)
        assert speed>=0x700,speed
        return {'dust':True,'release_speed':speed}
    run_check('Spindash dust and release',spindash)

    def death_gameover():
        obj,a=prepare('Floor spikes');g.write('v_rings',0,2);g.write('v_lives',1)
        player(g.get(a,'obX',2),g.get(a,'obY',2)-48)
        saw_dead=False;saw_text=False
        for _ in range(500):
            g.run();saw_dead|=g.get('v_player','obRoutine')>=6
            saw_text|=bool(g.read(g.s['ObjectTest_Executed']+0x98))
        assert saw_dead and saw_text,(saw_dead,saw_text,g.read('v_lives'))
        return {'player_died':True,'game_over_executed':True}
    run_check('Death reaches Game Over object',death_gameover)

    def empty_slot():
        prepare('Rings')
        a=next(a for a in range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']) if not g.get(a,'layout_id'))
        g.put(a,'layout_id',0x53);g.run(2)
        assert not g.get(a,'layout_id')
        return {'empty_53_deletes':True}
    run_check('Empty object placeholder deletes',empty_slot)

    g.close()
    failures=[c for c in report['checks'] if not c['passed']]
    print(f'{len(report["checks"])-len(failures)}/{len(report["checks"])} interactions passed')
    if failures:raise SystemExit(1)


if __name__=='__main__':main()
