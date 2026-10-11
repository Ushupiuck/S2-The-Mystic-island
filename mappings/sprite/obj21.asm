; DrawSprite_Loop adds ArtTile_HUD to these mappings. Derive the complete
; ring tile word before subtracting that base, preserving palette and flips.
Map_Obj21_RingTile = make_art_tile(ArtTile_Ring,1,1)-ArtTile_HUD

Map_Obj21_internal:
		dc.w .normal-Map_Obj21_internal
		dc.w .timeBlink-Map_Obj21_internal
.normal:	dc.w 9
		dc.w $800D, $A000, $A000, 0
		dc.w $800D, $A010, $A008, $20
		dc.w $800D, $A018, $A00C, $40
		dc.w $900D, $A008, $A004, 0
		dc.w $900D, $A020, $A010, $28
		dc.w $A005, Map_Obj21_RingTile, Map_Obj21_RingTile, 0
		dc.w $A009, $A028, $A014, $30
		dc.w $4005, $810A, $8085, 0
		dc.w $400D, $A10E, $A087, $10
.timeBlink:	dc.w 9
		dc.w $800D, $A000, $A000, 0
		dc.w $800D, $A010, $A008, $20
		dc.w $800D, $A018, $A00C, $40
		dc.w $900D, $8008, $8004, 0
		dc.w $900D, $A020, $A010, $28
		dc.w $A005, Map_Obj21_RingTile, Map_Obj21_RingTile, 0
		dc.w $A009, $A028, $A014, $30
		dc.w $4005, $810A, $8085, 0
		dc.w $400D, $A10E, $A087, $10
		even
