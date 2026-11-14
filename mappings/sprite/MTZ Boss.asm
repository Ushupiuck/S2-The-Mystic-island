; Prepared MTZ weapon art; six-byte S3&K mappings, original frame IDs.
; Empty pilot frames use the existing shared pod/head children when code is ported.
MTZBoss_WeaponTiles = 108

Map_MTZBoss_Weapons:
	dc.w Map_MTZBoss_Weapons_Frame0-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame1-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame2-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame3-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame4-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame5-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame6-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame7-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame8-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame9-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame10-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame11-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame12-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame13-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame14-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame15-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame16-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame17-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame18-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame19-Map_MTZBoss_Weapons
	dc.w Map_MTZBoss_Weapons_Frame20-Map_MTZBoss_Weapons
Map_MTZBoss_Weapons_Frame0:	dc.w 0
Map_MTZBoss_Weapons_Frame1 equ Map_MTZBoss_Weapons_Frame0
Map_MTZBoss_Weapons_Frame2:	dc.w 1
	dc.b -8,$02
	dc.w $2066,-24
Map_MTZBoss_Weapons_Frame3:	dc.w 2
	dc.b -12,$02
	dc.w $2040,-12
	dc.b -12,$06
	dc.w $2840,-4
Map_MTZBoss_Weapons_Frame4:	dc.w 2
	dc.b -12,$02
	dc.w $2046,-12
	dc.b -12,$06
	dc.w $2846,-4
Map_MTZBoss_Weapons_Frame5:	dc.w 1
	dc.b -8,$05
	dc.w $2062,-8
Map_MTZBoss_Weapons_Frame6:	dc.w 1
	dc.b -12,$06
	dc.w $2055,-8
Map_MTZBoss_Weapons_Frame7:	dc.w 2
	dc.b -8,$01
	dc.w $205B,-12
	dc.b -8,$05
	dc.w $285B,-4
Map_MTZBoss_Weapons_Frame8:	dc.w 2
	dc.b -12,$02
	dc.w $205F,-8
	dc.b -12,$02
	dc.w $285F,0
Map_MTZBoss_Weapons_Frame9:	dc.w 1
	dc.b -12,$0A
	dc.w $004C,-12
Map_MTZBoss_Weapons_Frame10:	dc.w 1
	dc.b -16,$0F
	dc.w $002C,-16
Map_MTZBoss_Weapons_Frame11:	dc.w 4
	dc.b -24,$0A
	dc.w $0000,-24
	dc.b -24,$0A
	dc.w $0009,0
	dc.b 0,$0A
	dc.w $0012,-24
	dc.b 0,$0A
	dc.w $001B,0
Map_MTZBoss_Weapons_Frame12 equ Map_MTZBoss_Weapons_Frame0
Map_MTZBoss_Weapons_Frame13 equ Map_MTZBoss_Weapons_Frame0
Map_MTZBoss_Weapons_Frame14 equ Map_MTZBoss_Weapons_Frame0
Map_MTZBoss_Weapons_Frame15 equ Map_MTZBoss_Weapons_Frame0
Map_MTZBoss_Weapons_Frame16 equ Map_MTZBoss_Weapons_Frame0
Map_MTZBoss_Weapons_Frame17 equ Map_MTZBoss_Weapons_Frame0
Map_MTZBoss_Weapons_Frame18:	dc.w 4
	dc.b -8,$0C
	dc.w $203C,-32
	dc.b 0,$0C
	dc.w $303C,-32
	dc.b -8,$0C
	dc.w $283C,0
	dc.b 0,$0C
	dc.w $383C,0
Map_MTZBoss_Weapons_Frame19:	dc.w 1
	dc.b -8,$02
	dc.w $2069,-32
Map_MTZBoss_Weapons_Frame20:	dc.w 4
	dc.b -24,$0A
	dc.w $1823,-24
	dc.b -24,$0A
	dc.w $1023,0
	dc.b 0,$0A
	dc.w $0823,-24
	dc.b 0,$0A
	dc.w $0023,0
	even
