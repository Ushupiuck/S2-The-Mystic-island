# Per-act music

Edit `_inc/Level Music.asm`. Each zone row contains four independent music
IDs, in act 1, 2, 3, 4 order. For example:

```asm
        dc.b MusID_GHZ, MusID_EHZ, MusID_GRGZ1, MusID_GRGZ2 ; GHZ
```

Use the existing `MusID_*` names or `bgm_*` aliases. The supplied defaults
preserve the old zone tracks in all four acts. The final FZ row uses `bgm_FZ`.
The assembler checks that every zone, including FZ, has all four entries.

Level entry and recovery from the drowning countdown share `GetLevelMusic`,
so recovery restores the selected act's song. Invincibility and boss music
retain their existing priority. One-up jingles still restore the driver's
saved song context.

`build_tools/check_act_music.py` tests all 68 slots through the lookup and
both callers using a disposable ROM with different act IDs. It also checks
recovery priorities and launches two acts with different songs. The source
ROM and playlist remain unchanged by the test.
