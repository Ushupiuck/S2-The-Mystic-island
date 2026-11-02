; ---------------------------------------------------------------------------
; Sprite mappings - special stage chaos	emeralds
; ---------------------------------------------------------------------------
Map_SS_Chaos1:
		dc.w byte_1B96C-Map_SS_Chaos1
		dc.w byte_1B97E-Map_SS_Chaos1
Map_SS_Chaos2:
		dc.w byte_1B972-Map_SS_Chaos2
		dc.w byte_1B97E-Map_SS_Chaos2
Map_SS_Chaos3:
		dc.w byte_1B978-Map_SS_Chaos3
		dc.w byte_1B97E-Map_SS_Chaos3
byte_1B96C:
		dc.b 1
		dc.b $F8, 5, 0,	0, $F8
byte_1B972:
		dc.b 1
		dc.b $F8, 5, 0,	4, $F8
byte_1B978:
		dc.b 1
		dc.b $F8, 5, 0,	8, $F8
byte_1B97E:
		dc.b 1
		dc.b $F8, 5, 0,	$C, $F8
		even
; Blue and cyan use private four-tile copies; the other emeralds keep their
; original shared art. Their flash frame reuses the old transparent tiles.
Map_SS_Blue:
		dc.w Map_SS_BlueFrame-Map_SS_Blue
		dc.w Map_SS_ExtraBlank-Map_SS_Blue
Map_SS_Cyan:
		dc.w Map_SS_CyanFrame-Map_SS_Cyan
		dc.w Map_SS_ExtraBlank-Map_SS_Cyan
Map_SS_BlueFrame:
		dc.b 1,$F8,5
		dc.w 0
		dc.b $F8
Map_SS_CyanFrame:
		dc.b 1,$F8,5
		dc.w 4
		dc.b $F8
Map_SS_ExtraBlank:
		dc.b 1,$F8,5
		dc.w ArtTile_SS_Emerald+12-ArtTile_SS_ExtraEmeralds
		dc.b $F8
		even
