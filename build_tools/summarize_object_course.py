#!/usr/bin/env python3
"""Collect every object source's inventory and actual emulator coverage."""
from pathlib import Path
import argparse
import json
import re

ROOT=Path(__file__).resolve().parent.parent


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for kind in ('run','boss','demo'):
        p.add_argument('--'+kind,action='append',default=[],help='name=report.json')
    args=p.parse_args()
    ids=set();runs=[];bosses=[];demos=[]
    for item in args.run:
        name,path=item.split('=',1);j=json.loads(Path(path).read_text())
        assert not j.get('failures'),(name,j.get('failures'))
        assert all(c['passed'] for c in j.get('checks',[])),name
        assert all(c['seen'] for c in j.get('placements',[])),name
        ids.update(j.get('executed_ids',[]))
        runs.append({'name':name,**{k:v for k,v in j.items() if k not in ('placements','checks','failures')},
                     'placements':len(j.get('placements',[])),'contacts':len(j.get('checks',[]))})
    for item in args.boss:
        name,path=item.split('=',1);j=json.loads(Path(path).read_text())
        assert j['actual_hits']==8 and j['capsule']['animals'] and j['capsule']['flag']==2,name
        bosses.append({'name':name,**j})
        if name.startswith('GHZ-'):ids.update(['3D','3E','48','95'])
        elif name.startswith('EHZ-'):ids.update(['3E','55','58','95'])
        else:raise ValueError('Boss report name must identify GHZ or EHZ')
    for item in args.demo:
        name,path=item.split('=',1);j=json.loads(Path(path).read_text())
        assert len(j['demos'])==4 and all(not d['ended_on_death'] for d in j['demos']),name
        demos.append({'name':name,**j})
    source=(ROOT/'main.asm').read_text()
    includes=set(re.findall(r'include\s+"([^"]+)"',source,re.I))
    pointers=dict(re.findall(r'ptr_Obj([0-9A-F]{2}):\s+dc.l\s+(\w+)',source))
    rows=[]
    for path in sorted((ROOT/'objects').rglob('*.asm')):
        rel=path.relative_to(ROOT).as_posix();text=path.read_text(encoding='latin1')
        labels=set(re.findall(r'^(\w+):',text,re.M))
        object_ids=[i for i,label in pointers.items() if label in labels]
        if rel not in includes:status='inactive source'
        elif rel.endswith('1F LZ Conveyor.asm'):status='excluded by request'
        elif rel.endswith('92 Title screen palette handler.asm'):status='unfinished, not spawned'
        elif '/Empty Slots/' in rel and not object_ids:status='empty placeholder'
        elif rel.endswith('sub ChkObjectVisible.asm'):status='native helper boundaries checked'
        elif rel.endswith('sub SmashObject.asm'):status='wall fragment helper exercised'
        else:
            assert object_ids and set(object_ids).issubset(ids),('uncovered live implementation',rel,object_ids)
            status='runtime checked'
        rows.append({'file':rel,'ids':object_ids,'status':status})
    result={'runs':runs,'bosses':bosses,'demos':demos,'files':rows,
            'executed_ids':sorted(ids),'limitations':[
                'Representative subtypes/contacts with scripted positioning, not exhaustive combinations or a controller-only playthrough.',
                'Gator lifecycle/rendering is checked; its known broken gameplay is not certified.',
                'Nine W.I.P/Unused files are not assembled; seven empty sources have no implementation.',
                'The compiled title palette handler lacks completed data setup and an update entry, and is not instantiated.',
                'Test-only S1 art supplies the small door and shared floor arrangement; water effects use the restored gameplay assets.',
                'Course bank relocations, extra art and LZ2 replacement exist only in the copied test ROM.']}
    (ROOT/'docs/Object-course-results.json').write_text(json.dumps(result,indent=2)+'\n')
    lines=['# Object-folder coverage','',
           'Generated from emulator reports by `build_tools/summarize_object_course.py`.',
           'See [the procedure and limits](Object-test-course.md) and [recorded results](Object-course-results.json).','',
           '| Source file | Object IDs | Coverage |','| --- | --- | --- |']
    lines.extend(f'| `{r["file"]}` | {", ".join(r["ids"]) or "—"} | {r["status"]} |' for r in rows)
    (ROOT/'docs/Object-course-coverage.md').write_text('\n'.join(lines)+'\n')
    print(f'Inventoried {len(rows)} files; {sum(r["status"]=="runtime checked" for r in rows)} live source files checked, plus two helpers.')


if __name__=='__main__':main()
