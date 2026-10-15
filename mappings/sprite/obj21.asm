; Render_Sprites adds ArtTile_HUD to these mappings. Derive the complete
; ring tile word before subtracting that base, preserving palette and flips.
Map_Obj21_RingTile = make_art_tile(ArtTile_Ring,1,1)-ArtTile_HUD
Map_Obj21_ScoreE = make_art_tile(ArtTile_HUD_E,1,1)-ArtTile_HUD
Map_Obj21_ScoreDigits = make_art_tile(ArtTile_HUD_Numbers,1,1)-ArtTile_HUD
Map_Obj21_DebugDigits = make_art_tile(ArtTile_HUD_Debug_Numbers,1,1)-ArtTile_HUD
Map_Obj21_TimeDigits = make_art_tile(ArtTile_HUD_Numbers+$E,1,1)-ArtTile_HUD
Map_Obj21_RingDigits = make_art_tile(ArtTile_HUD_Numbers+$16,1,1)-ArtTile_HUD
Map_Obj21_LivesIcon = make_art_tile(ArtTile_Lives_Counter,0,1)-ArtTile_HUD
Map_Obj21_TailsIcon = make_art_tile(ArtTile_Tails_Life,0,1)-ArtTile_HUD
Map_Obj21_LivesLetters = make_art_tile(ArtTile_Lives_Counter+4,1,1)-ArtTile_HUD

Map_Obj21_internal:
		dc.w .normal-Map_Obj21_internal
		dc.w .timeBlink-Map_Obj21_internal
		dc.w .debug-Map_Obj21_internal
		dc.w .debugTimeBlink-Map_Obj21_internal
		dc.w .tailsNormal-Map_Obj21_internal
		dc.w .tailsTimeBlink-Map_Obj21_internal
		dc.w .tailsDebug-Map_Obj21_internal
		dc.w .tailsDebugTimeBlink-Map_Obj21_internal
.normal:	dc.w 10
		dc.w $800D, $A000, 0
		dc.w $8001, Map_Obj21_ScoreE, $20
		dc.w $8009, Map_Obj21_ScoreDigits, $28
		dc.w $800D, Map_Obj21_ScoreDigits+6, $40
		dc.w $900D, $A008, 0
		dc.w $900D, Map_Obj21_TimeDigits, $28
		dc.w $A005, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, $30
		dc.w $4005, Map_Obj21_LivesIcon, 0
		dc.w $400D, Map_Obj21_LivesLetters, $10
.timeBlink:	dc.w 10
		dc.w $800D, $A000, 0
		dc.w $8001, Map_Obj21_ScoreE, $20
		dc.w $8009, Map_Obj21_ScoreDigits, $28
		dc.w $800D, Map_Obj21_ScoreDigits+6, $40
		dc.w $900D, $8008, 0
		dc.w $900D, Map_Obj21_TimeDigits, $28
		dc.w $A005, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, $30
		dc.w $4005, Map_Obj21_LivesIcon, 0
		dc.w $400D, Map_Obj21_LivesLetters, $10
.debug:	dc.w 9
		dc.w $800D, $A000, 0
		dc.w $800D, Map_Obj21_DebugDigits, $20
		dc.w $800D, Map_Obj21_DebugDigits+8, $40
		dc.w $900D, $A008, 0
		dc.w $900D, Map_Obj21_TimeDigits, $28
		dc.w $A005, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, $30
		dc.w $4005, Map_Obj21_LivesIcon, 0
		dc.w $400D, Map_Obj21_LivesLetters, $10
.debugTimeBlink:	dc.w 9
		dc.w $800D, $A000, 0
		dc.w $800D, Map_Obj21_DebugDigits, $20
		dc.w $800D, Map_Obj21_DebugDigits+8, $40
		dc.w $900D, $8008, 0
		dc.w $900D, Map_Obj21_TimeDigits, $28
		dc.w $A005, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, $30
		dc.w $4005, Map_Obj21_LivesIcon, 0
		dc.w $400D, Map_Obj21_LivesLetters, $10
		even

; Tails uses the portrait retained at the end of the monitor bank.
.tailsNormal:	dc.w 10
		dc.w $800D, $A000, 0
		dc.w $8001, Map_Obj21_ScoreE, $20
		dc.w $8009, Map_Obj21_ScoreDigits, $28
		dc.w $800D, Map_Obj21_ScoreDigits+6, $40
		dc.w $900D, $A008, 0
		dc.w $900D, Map_Obj21_TimeDigits, $28
		dc.w $A005, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, $30
		dc.w $4005, Map_Obj21_TailsIcon, 0
		dc.w $400D, Map_Obj21_LivesLetters, $10
.tailsTimeBlink:	dc.w 10
		dc.w $800D, $A000, 0
		dc.w $8001, Map_Obj21_ScoreE, $20
		dc.w $8009, Map_Obj21_ScoreDigits, $28
		dc.w $800D, Map_Obj21_ScoreDigits+6, $40
		dc.w $900D, $8008, 0
		dc.w $900D, Map_Obj21_TimeDigits, $28
		dc.w $A005, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, $30
		dc.w $4005, Map_Obj21_TailsIcon, 0
		dc.w $400D, Map_Obj21_LivesLetters, $10
.tailsDebug:	dc.w 9
		dc.w $800D, $A000, 0
		dc.w $800D, Map_Obj21_DebugDigits, $20
		dc.w $800D, Map_Obj21_DebugDigits+8, $40
		dc.w $900D, $A008, 0
		dc.w $900D, Map_Obj21_TimeDigits, $28
		dc.w $A005, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, $30
		dc.w $4005, Map_Obj21_TailsIcon, 0
		dc.w $400D, Map_Obj21_LivesLetters, $10
.tailsDebugTimeBlink:	dc.w 9
		dc.w $800D, $A000, 0
		dc.w $800D, Map_Obj21_DebugDigits, $20
		dc.w $800D, Map_Obj21_DebugDigits+8, $40
		dc.w $900D, $8008, 0
		dc.w $900D, Map_Obj21_TimeDigits, $28
		dc.w $A005, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, $30
		dc.w $4005, Map_Obj21_TailsIcon, 0
		dc.w $400D, Map_Obj21_LivesLetters, $10
		even
