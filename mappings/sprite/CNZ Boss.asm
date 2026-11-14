; Prepared CNZ weapon art; six-byte S3&K mappings, original frame IDs.
; Empty pilot frames use the existing shared pod/head children when code is ported.
CNZBoss_WeaponTiles = 117
; Future cycle destinations, byte offsets from v_palette.
CNZBoss_Cycle2PaletteOffset = $34
CNZBoss_Cycle3PaletteOffset = $2A
; Body frame 1 draws before the shared pod; topper draws behind it.
CNZBoss_TopperFrame = 21

Map_CNZBoss_Weapons:
	dc.w Map_CNZBoss_Weapons_Frame0-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame1-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame2-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame3-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame4-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame5-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame6-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame7-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame8-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame9-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame10-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame11-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame12-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame13-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame14-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame15-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame16-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame17-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame18-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame19-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame20-Map_CNZBoss_Weapons
	dc.w Map_CNZBoss_Weapons_Frame21-Map_CNZBoss_Weapons
Map_CNZBoss_Weapons_Frame0:	dc.w 0
Map_CNZBoss_Weapons_Frame1:	dc.w 4
	dc.b 0,$06
	dc.w $2000,-40
	dc.b 8,$06
	dc.w $2006,-24
	dc.b 8,$0E
	dc.w $2806,-8
	dc.b 0,$06
	dc.w $2012,24
Map_CNZBoss_Weapons_Frame2:	dc.w 1
	dc.b 24,$06
	dc.w $2018,-28
Map_CNZBoss_Weapons_Frame3:	dc.w 1
	dc.b 16,$06
	dc.w $201E,-37
Map_CNZBoss_Weapons_Frame4:	dc.w 1
	dc.b 16,$0B
	dc.w $2024,8
Map_CNZBoss_Weapons_Frame5:	dc.w 2
	dc.b 16,$09
	dc.w $2030,8
	dc.b 16,$06
	dc.w $2036,32
Map_CNZBoss_Weapons_Frame6 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame7 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame8 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame9 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame10 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame11 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame12:	dc.w 1
	dc.b 40,$0C
	dc.w $203C,-16
Map_CNZBoss_Weapons_Frame13:	dc.w 1
	dc.b 40,$0C
	dc.w $2040,-16
Map_CNZBoss_Weapons_Frame14:	dc.w 1
	dc.b 40,$0C
	dc.w $2044,-16
Map_CNZBoss_Weapons_Frame15:	dc.w 2
	dc.b 32,$0C
	dc.w $2048,-28
	dc.b 32,$0C
	dc.w $204C,4
Map_CNZBoss_Weapons_Frame16:	dc.w 2
	dc.b 32,$0C
	dc.w $2050,-28
	dc.b 32,$0C
	dc.w $2054,4
Map_CNZBoss_Weapons_Frame17:	dc.w 2
	dc.b 32,$0C
	dc.w $2058,-28
	dc.b 32,$0C
	dc.w $205C,4
Map_CNZBoss_Weapons_Frame18:	dc.w 1
	dc.b -12,$0A
	dc.w $0060,-12
Map_CNZBoss_Weapons_Frame19:	dc.w 1
	dc.b -4,$00
	dc.w $0069,-4
Map_CNZBoss_Weapons_Frame20:	dc.w 1
	dc.b -4,$00
	dc.w $006A,-4
Map_CNZBoss_Weapons_Frame21:	dc.w 2
	dc.b -40,$04
	dc.w $206B,-7
	dc.b -32,$0D
	dc.w $206D,-23
	even
