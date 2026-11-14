; Prepared ARZ weapon art; six-byte S3&K mappings, original frame IDs.
; Empty pilot frames use the existing shared pod/head children when code is ported.
ARZBoss_WeaponTiles = 147

Map_ARZBoss_Weapons:
	dc.w Map_ARZBoss_Weapons_Frame0-Map_ARZBoss_Weapons
	dc.w Map_ARZBoss_Weapons_Frame1-Map_ARZBoss_Weapons
	dc.w Map_ARZBoss_Weapons_Frame2-Map_ARZBoss_Weapons
	dc.w Map_ARZBoss_Weapons_Frame3-Map_ARZBoss_Weapons
	dc.w Map_ARZBoss_Weapons_Frame4-Map_ARZBoss_Weapons
	dc.w Map_ARZBoss_Weapons_Frame5-Map_ARZBoss_Weapons
	dc.w Map_ARZBoss_Weapons_Frame6-Map_ARZBoss_Weapons
	dc.w Map_ARZBoss_Weapons_Frame7-Map_ARZBoss_Weapons
	dc.w Map_ARZBoss_Weapons_Frame8-Map_ARZBoss_Weapons
	dc.w Map_ARZBoss_Weapons_Frame9-Map_ARZBoss_Weapons
	dc.w Map_ARZBoss_Weapons_Frame10-Map_ARZBoss_Weapons
	dc.w Map_ARZBoss_Weapons_Frame11-Map_ARZBoss_Weapons
Map_ARZBoss_Weapons_Frame0:	dc.w 0
Map_ARZBoss_Weapons_Frame1 equ Map_ARZBoss_Weapons_Frame0
Map_ARZBoss_Weapons_Frame2 equ Map_ARZBoss_Weapons_Frame0
Map_ARZBoss_Weapons_Frame3 equ Map_ARZBoss_Weapons_Frame0
Map_ARZBoss_Weapons_Frame4 equ Map_ARZBoss_Weapons_Frame0
Map_ARZBoss_Weapons_Frame5 equ Map_ARZBoss_Weapons_Frame0
Map_ARZBoss_Weapons_Frame6:	dc.w 2
	dc.b 24,$05
	dc.w $0000,-24
	dc.b 24,$05
	dc.w $0000,8
Map_ARZBoss_Weapons_Frame7:	dc.w 2
	dc.b 24,$04
	dc.w $0004,-24
	dc.b 24,$04
	dc.w $0004,8
Map_ARZBoss_Weapons_Frame8:	dc.w 4
	dc.b 0,$00
	dc.w $2006,-48
	dc.b -8,$06
	dc.w $2007,-40
	dc.b -8,$07
	dc.w $200D,-24
	dc.b -8,$07
	dc.w $200D,8
Map_ARZBoss_Weapons_Frame9:	dc.w 6
	dc.b -22,$0F
	dc.w $2015,-100
	dc.b -46,$00
	dc.w $2025,-76
	dc.b -38,$09
	dc.w $2026,-92
	dc.b -46,$0B
	dc.w $202C,-68
	dc.b -14,$05
	dc.w $2038,-68
	dc.b -8,$05
	dc.w $303B,-64
Map_ARZBoss_Weapons_Frame10:	dc.w 5
	dc.b -15,$0F
	dc.w $203F,-99
	dc.b -39,$0A
	dc.w $204F,-91
	dc.b -39,$07
	dc.w $2058,-67
	dc.b -7,$02
	dc.w $2060,-67
	dc.b -8,$05
	dc.w $2063,-64
Map_ARZBoss_Weapons_Frame11:	dc.w 5
	dc.b -20,$0D
	dc.w $2067,-96
	dc.b -4,$0C
	dc.w $206F,-96
	dc.b 4,$0C
	dc.w $306F,-96
	dc.b 12,$0D
	dc.w $3067,-96
	dc.b 0,$04
	dc.w $2073,-64

Map_ARZBoss_Pillars:
	dc.w Map_ARZBoss_Pillars_Frame0-Map_ARZBoss_Pillars
	dc.w Map_ARZBoss_Pillars_Frame1-Map_ARZBoss_Pillars
	dc.w Map_ARZBoss_Pillars_Frame2-Map_ARZBoss_Pillars
	dc.w Map_ARZBoss_Pillars_Frame3-Map_ARZBoss_Pillars
	dc.w Map_ARZBoss_Pillars_Frame4-Map_ARZBoss_Pillars
	dc.w Map_ARZBoss_Pillars_Frame5-Map_ARZBoss_Pillars
	dc.w Map_ARZBoss_Pillars_Frame6-Map_ARZBoss_Pillars
Map_ARZBoss_Pillars_Frame0:	dc.w 5
	dc.b 40,$0F
	dc.w $2075,0
	dc.b 8,$0F
	dc.w $2075,0
	dc.b -24,$0F
	dc.w $2075,0
	dc.b -56,$0F
	dc.w $2075,0
	dc.b -64,$0C
	dc.w $2085,0
Map_ARZBoss_Pillars_Frame1:	dc.w 1
	dc.b -4,$04
	dc.w $2089,-8
Map_ARZBoss_Pillars_Frame2 equ Map_ARZBoss_Pillars_Frame1
Map_ARZBoss_Pillars_Frame3:	dc.w 1
	dc.b -4,$0C
	dc.w $208B,-16
Map_ARZBoss_Pillars_Frame4 equ Map_ARZBoss_Pillars_Frame3
Map_ARZBoss_Pillars_Frame5:	dc.w 2
	dc.b -4,$04
	dc.w $208F,-16
	dc.b -4,$04
	dc.w $208D,0
Map_ARZBoss_Pillars_Frame6:	dc.w 2
	dc.b -4,$04
	dc.w $2091,-16
	dc.b -4,$04
	dc.w $208D,0
	even
