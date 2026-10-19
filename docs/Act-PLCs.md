# Act-specific object art

Every act has independent primary and secondary Nemesis request lists in
`_inc/Act Pattern Load Cues.asm`, including the unused level slots. For example,
`PLC_SMZ1_Main` and `PLC_SMZ2_Main` are separate lists: only Act 2 imports
Kemusi. Each list has its own unsigned-byte ID in `_inc/Act PLC Index.asm`.
All four `LevelHeaders*.asm` timezone tables select the appropriate act IDs.

Add `plcm ArtLabel, ArtTile_Destination` to the desired act list. The existing
`PLC_*_Art` macros provide shared defaults; replace or extend the macro call
inside an act's list to customize that act. Changing a common recipe changes
all acts using that recipe. Art, mappings and VRAM destinations must agree.

Main loads during the title card. Extra loads after the terrain. Main reserves room for shared monitor/checkpoint and life-art requests,
leaving 11 entries with the current assets; Extra has all 16 entries. Assembly
rejects an overfull list. The loader processes the two stages separately.
Shared HUD, monitor, checkpoint, life-art and boss requests retain
their ordinary lifecycle. Empty lists have a count of -1.

The existing Kosinski module index is also per act. Previously shared empty
entries now point to separate named empty lists in `_inc/Pattern Load Cues.asm`,
so adding a badnik import to one act leaves the others unchanged. The existing
GHZ, LZ, CPZ and HPZ act lists retain their imports.
