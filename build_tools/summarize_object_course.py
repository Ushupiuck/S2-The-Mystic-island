#!/usr/bin/env python3
"""Inventory object sources against supplied emulator coverage reports."""
from pathlib import Path
import argparse
import json
import os
import re

ROOT=Path(__file__).resolve().parent.parent


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for kind in ('run','boss','demo'):
        p.add_argument('--'+kind,action='append',default=[],help='name=report.json')
    p.add_argument('--output', type=Path, required=True,
                   help='Directory for report.json and coverage.md (outside docs)')
    args=p.parse_args()
    output=args.output.resolve()
    docs=(ROOT/'docs').resolve()
    if output == docs or docs in output.parents:
        p.error('Generated reports must be written outside docs')
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
        elif rel.endswith(('sub ChkObjectVisible.asm', 'sub SmashObject.asm')):
            status='helper; coverage not inferred from object IDs'
        else:
            assert object_ids and set(object_ids).issubset(ids),('uncovered live implementation',rel,object_ids)
            status='runtime checked'
        rows.append({'file':rel,'ids':object_ids,'status':status})
    inactive=sum(r['status']=='inactive source' for r in rows)
    placeholders=sum(r['status']=='empty placeholder' for r in rows)
    result={'runs':runs,'bosses':bosses,'demos':demos,'files':rows,
            'executed_ids':sorted(ids),'limitations':[
                'Inventory reflects current source; supplied reports must come from its matching ROM/listing. This tool does not verify that provenance.',
                'Representative subtypes/contacts with scripted positioning, not exhaustive combinations or a controller-only playthrough.',
                'Gator lifecycle/rendering is checked; its known broken gameplay is not certified.',
                f'{inactive} source files are not assembled; {placeholders} included empty sources have no implementation.',
                'Object-ID reports do not establish helper coverage; retain separate native/helper evidence.',
                'The compiled title palette handler lacks completed data setup and an update entry, and is not instantiated.',
                'Test-only S1 art supplies the small door and shared floor arrangement; water effects use the restored gameplay assets.',
                'Course bank relocations, extra art and LZ2 replacement exist only in the copied test ROM.']}
    output.mkdir(parents=True, exist_ok=True)
    (output/'report.json').write_text(json.dumps(result,indent=2)+'\n', encoding='utf-8')
    try:
        procedure=os.path.relpath(docs/'Testing.md', output).replace(os.sep, '/')
    except ValueError:  # Windows output on a different drive cannot be relative.
        procedure='https://github.com/Ushupiuck/S2-The-Mystic-island/blob/Mystic-Island/docs/Testing.md'
    lines=['# Object-folder coverage','',
           'Generated from emulator reports by `build_tools/summarize_object_course.py`.',
           'Inventory uses current source; input reports require matching ROM/listing provenance.',
           f'See [the procedure and limits]({procedure}#disposable-object-course) and [recorded results](report.json).','',
           '| Source file | Object IDs | Coverage |','| --- | --- | --- |']
    lines.extend(f'| `{r["file"]}` | {", ".join(r["ids"]) or "—"} | {r["status"]} |' for r in rows)
    (output/'coverage.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    print(f'Inventoried {len(rows)} files; {sum(r["status"]=="runtime checked" for r in rows)} live source files covered by supplied IDs. Reports: {output}')


if __name__=='__main__':main()
