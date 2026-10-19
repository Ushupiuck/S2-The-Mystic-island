#!/usr/bin/env python3
"""Rebuild the distributed KeH tools with a C# compiler and .NET 4 references."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--compiler', default=os.environ.get('CSC'))
p.add_argument('--mono', default=os.environ.get('MONO') or shutil.which('mono'))
p.add_argument('--framework', type=Path, help='Optional directory of .NET 4 reference assemblies')
p.add_argument('--check', action='store_true', help='Also run compressor and sound tool regression checks')
args = p.parse_args()
compiler = args.compiler or shutil.which('csc') or shutil.which('mcs')
if not compiler and os.name == 'nt':
	compiler = str(Path(os.environ['WINDIR']) / 'Microsoft.NET/Framework/v4.0.30319/csc.exe')
if not compiler or not Path(compiler).is_file():
	p.error('Install a C# compiler, or supply --compiler /path/to/csc.exe (or mcs).')
command = [compiler]
if os.name != 'nt' and compiler.lower().endswith('.exe'):
	if not args.mono:
		p.error('Running csc.exe on this platform requires --mono /path/to/mono.')
	command.insert(0, args.mono)
mcs = Path(compiler).name in ('mcs', 'dmcs', 'mcs.exe')
help_text = subprocess.run(command + ['/help'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout.lower()
deterministic = 'deterministic' in help_text
debug = 'portable' if 'portable' in help_text else 'pdbonly'
# /noconfig disables csc.rsp, so supply the framework references explicitly.
if args.framework:
	framework_flags = ['/nostdlib+'] + ['/reference:' + str(args.framework / f)
		for f in ('mscorlib.dll', 'System.dll', 'System.Core.dll')]
else:
	framework_flags = ['/reference:System.dll', '/reference:System.Core.dll']

for name, source_name, target in (('SonicRetro.KensSharp.Saxman', 'KensSharp.Saxman', 'library'),
	('KEHmusic', 'KEHmusic', 'exe'), ('KEHsfx', 'KEHsfx', 'exe')):
	flags = ['/nologo', '/noconfig', '/target:' + target, '/optimize+', '/define:TRACE',
		'/out:' + str(ROOT / (name + ('.dll' if target == 'library' else '.exe')))]
	if mcs or target == 'library':
		flags.append('/debug-')
	else:
		flags.append('/debug:' + debug)
	if deterministic:
		flags += ['/deterministic+', '/pathmap:' + str(ROOT) + '=.']
	flags += framework_flags
	if target == 'library':
		flags.append('/reference:' + str(ROOT / 'SonicRetro.KensSharp.Common.dll'))
	else:
		flags.append('/reference:' + str(ROOT / 'IniFile.dll'))
	if name == 'KEHmusic':
		flags.append('/reference:' + str(ROOT / 'SonicRetro.KensSharp.Saxman.dll'))
	source = Path(__file__).resolve().parent / source_name
	print('Building', name, flush=True)
	# Regenerate symbols rather than reuse a different compiler's PDB format.
	(ROOT / (name + '.pdb')).unlink(missing_ok=True)
	subprocess.run(command + flags + [str(f) for f in sorted(source.glob('*.cs'))],
		cwd=ROOT, check=True)

if args.check:
	temporary = ROOT / '.sound-build/checks'
	temporary.mkdir(parents=True, exist_ok=True)
	flags = ['/nologo', '/noconfig', '/target:exe', '/debug-', '/out:' + str(temporary / 'SaxmanCheck.exe'),
		'/reference:' + str(ROOT / 'SonicRetro.KensSharp.Saxman.dll')]
	flags += framework_flags
	subprocess.run(command + flags + [str(Path(__file__).resolve().parent / 'tests/SaxmanCheck.cs')], check=True)
	for name in ('Saxman', 'Common'):
		shutil.copyfile(ROOT / ('SonicRetro.KensSharp.' + name + '.dll'), temporary / ('SonicRetro.KensSharp.' + name + '.dll'))
	subprocess.run(([args.mono] if os.name != 'nt' else []) + [str(temporary / 'SaxmanCheck.exe')], check=True)
	subprocess.run([os.sys.executable, str(ROOT / 'build_tools/check_sound_tools.py')] +
		(['--mono', args.mono] if args.mono else []), check=True)
