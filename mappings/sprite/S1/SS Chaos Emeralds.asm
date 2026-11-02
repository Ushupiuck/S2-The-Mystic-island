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
Map_SS_Chaos4:
		dc.w Map_SS_ChaosBlue-Map_SS_Chaos4
		dc.w byte_1B97E-Map_SS_Chaos4
Map_SS_Chaos5:
		dc.w Map_SS_ChaosCyan-Map_SS_Chaos5
		dc.w byte_1B97E-Map_SS_Chaos5
byte_1B96C:
		dc.b 1
		dc.b $F8, 5, 0,	0, $F8
byte_1B972:
		dc.b 1
		dc.b $F8, 5, 0,	4, $F8
byte_1B978:
		dc.b 1
		dc.b $F8, 5, 0,	8, $F8
Map_SS_ChaosBlue:
		dc.b 1
		dc.b $F8, 5, 0, $10, $F8
Map_SS_ChaosCyan:
		dc.b 1
		dc.b $F8, 5, 0, $14, $F8
byte_1B97E:
		dc.b 1
		dc.b $F8, 5, 0,	$C, $F8
		even
