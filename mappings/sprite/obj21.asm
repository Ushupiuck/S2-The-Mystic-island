; DrawSprite_Loop adds ArtTile_HUD to these mappings. Derive the complete
; ring tile word before subtracting that base, preserving palette and flips.
Map_Obj21_RingTile = make_art_tile(ArtTile_Ring,1,1)-ArtTile_HUD
Map_Obj21_ScoreE = make_art_tile(ArtTile_HUD_E,1,1)-ArtTile_HUD
Map_Obj21_ScoreE2 = make_art_tile((ArtTile_HUD_E-ArtTile_HUD)/2,1,1)
Map_Obj21_ScoreDigits = make_art_tile(ArtTile_HUD_Numbers,1,1)-ArtTile_HUD
Map_Obj21_ScoreDigits2 = make_art_tile((ArtTile_HUD_Numbers-ArtTile_HUD)/2,1,1)
Map_Obj21_DebugDigits = make_art_tile(ArtTile_HUD_Debug_Numbers,1,1)-ArtTile_HUD
Map_Obj21_DebugDigits2 = make_art_tile((ArtTile_HUD_Debug_Numbers-ArtTile_HUD)/2,1,1)
Map_Obj21_TimeDigits = make_art_tile(ArtTile_HUD_Numbers+$E,1,1)-ArtTile_HUD
Map_Obj21_TimeDigits2 = make_art_tile((ArtTile_HUD_Numbers+$E-ArtTile_HUD)/2,1,1)
Map_Obj21_RingDigits = make_art_tile(ArtTile_HUD_Numbers+$16,1,1)-ArtTile_HUD
Map_Obj21_RingDigits2 = make_art_tile((ArtTile_HUD_Numbers+$16-ArtTile_HUD)/2,1,1)

Map_Obj21_internal:
		dc.w .normal-Map_Obj21_internal
		dc.w .timeBlink-Map_Obj21_internal
		dc.w .debug-Map_Obj21_internal
		dc.w .debugTimeBlink-Map_Obj21_internal
.normal:	dc.w 10
		dc.w $800D, $A000, $A000, 0
		dc.w $8001, Map_Obj21_ScoreE, Map_Obj21_ScoreE2, $20
		dc.w $8009, Map_Obj21_ScoreDigits, Map_Obj21_ScoreDigits2, $28
		dc.w $800D, Map_Obj21_ScoreDigits+6, Map_Obj21_ScoreDigits2+3, $40
		dc.w $900D, $A008, $A004, 0
		dc.w $900D, Map_Obj21_TimeDigits, Map_Obj21_TimeDigits2, $28
		dc.w $A005, Map_Obj21_RingTile, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, Map_Obj21_RingDigits2, $30
		dc.w $4005, $810A, $8085, 0
		dc.w $400D, $A10E, $A087, $10
.timeBlink:	dc.w 10
		dc.w $800D, $A000, $A000, 0
		dc.w $8001, Map_Obj21_ScoreE, Map_Obj21_ScoreE2, $20
		dc.w $8009, Map_Obj21_ScoreDigits, Map_Obj21_ScoreDigits2, $28
		dc.w $800D, Map_Obj21_ScoreDigits+6, Map_Obj21_ScoreDigits2+3, $40
		dc.w $900D, $8008, $8004, 0
		dc.w $900D, Map_Obj21_TimeDigits, Map_Obj21_TimeDigits2, $28
		dc.w $A005, Map_Obj21_RingTile, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, Map_Obj21_RingDigits2, $30
		dc.w $4005, $810A, $8085, 0
		dc.w $400D, $A10E, $A087, $10
.debug:	dc.w 9
		dc.w $800D, $A000, $A000, 0
		dc.w $800D, Map_Obj21_DebugDigits, Map_Obj21_DebugDigits2, $20
		dc.w $800D, Map_Obj21_DebugDigits+8, Map_Obj21_DebugDigits2+4, $40
		dc.w $900D, $A008, $A004, 0
		dc.w $900D, Map_Obj21_TimeDigits, Map_Obj21_TimeDigits2, $28
		dc.w $A005, Map_Obj21_RingTile, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, Map_Obj21_RingDigits2, $30
		dc.w $4005, $810A, $8085, 0
		dc.w $400D, $A10E, $A087, $10
.debugTimeBlink:	dc.w 9
		dc.w $800D, $A000, $A000, 0
		dc.w $800D, Map_Obj21_DebugDigits, Map_Obj21_DebugDigits2, $20
		dc.w $800D, Map_Obj21_DebugDigits+8, Map_Obj21_DebugDigits2+4, $40
		dc.w $900D, $8008, $8004, 0
		dc.w $900D, Map_Obj21_TimeDigits, Map_Obj21_TimeDigits2, $28
		dc.w $A005, Map_Obj21_RingTile, Map_Obj21_RingTile, 0
		dc.w $A009, Map_Obj21_RingDigits, Map_Obj21_RingDigits2, $30
		dc.w $4005, $810A, $8085, 0
		dc.w $400D, $A10E, $A087, $10
		even
