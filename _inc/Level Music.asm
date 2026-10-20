; Per-act music IDs. Each row is one zone, with acts 1, 2, 3 and 4.
; Use any MusID_* / bgm_* entry; defaults preserve the existing zone music.
; The FZ row covers the separate zone after the sixteen four-act zones.
; Both level entry and drowning recovery use this lookup.
GetLevelMusic:
        move.w (Current_ZoneAndAct).w,d0
        ror.b #2,d0
        lsr.w #6,d0              ; index = Zone*4 + Act (Act is 0-3)
        lea MusicList(pc),a1
        move.b (a1,d0.w),d0      ; d0.w music ID; clobbers d0/a1/CCR
        rts

MusicList:
;               Act 1,       Act 2,       Act 3,       Act 4
        dc.b bgm_GHZ, bgm_GHZ, bgm_GHZ, bgm_GHZ ; GHZ
        dc.b bgm_LZ, bgm_LZ, bgm_LZ, bgm_LZ ; LZ
        dc.b bgm_MZ, bgm_MZ, bgm_MZ, bgm_MZ ; CPZ
        dc.b bgm_SLZ, bgm_SLZ, bgm_SLZ, bgm_SLZ ; EHZ
        dc.b bgm_SYZ, bgm_SYZ, bgm_SYZ, bgm_SYZ ; HPZ
        dc.b bgm_HTZ, bgm_HTZ, bgm_HTZ, bgm_HTZ ; HTZ
        dc.b MusID_MTZ, MusID_MTZ, MusID_MTZ, MusID_MTZ ; LV6
        dc.b bgm_GHZ, bgm_GHZ, bgm_GHZ, bgm_GHZ ; LV7
        dc.b bgm_SBZ, bgm_SBZ, bgm_SBZ, bgm_SBZ ; SMZ
        dc.b bgm_GHZ, bgm_GHZ, bgm_GHZ, bgm_GHZ ; LV9
        dc.b bgm_GHZ, bgm_GHZ, bgm_GHZ, bgm_GHZ ; LV0A
        dc.b bgm_GHZ, bgm_GHZ, bgm_GHZ, bgm_GHZ ; LV0B
        dc.b bgm_GHZ, bgm_GHZ, bgm_GHZ, bgm_GHZ ; LV0C
        dc.b bgm_GHZ, bgm_GHZ, bgm_GHZ, bgm_GHZ ; LV0D
        dc.b bgm_GHZ, bgm_GHZ, bgm_GHZ, bgm_GHZ ; LV0E
        dc.b bgm_GHZ, bgm_GHZ, bgm_GHZ, bgm_GHZ ; LV0F
        dc.b bgm_FZ, bgm_FZ, bgm_FZ, bgm_FZ ; FZ
MusicList_End:
        if MusicList_End-MusicList<>(LevelCount+1)*4
            fatal "MusicList must contain four entries for every zone, including FZ"
        endif
        even
