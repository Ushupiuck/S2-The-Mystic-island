; Prepared MCZ weapon art; six-byte S3&K mappings, original frame IDs.
; Empty pilot frames use the existing shared pod/head children when code is ported.
MCZBoss_WeaponTiles = 105

Map_MCZBoss_Weapons:
	dc.w Map_MCZBoss_Weapons_Frame0-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame1-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame2-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame3-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame4-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame5-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame6-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame7-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame8-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame9-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame10-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame11-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame12-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame13-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame14-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame15-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame16-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame17-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame18-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame19-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame20-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame21-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame22-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame23-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame24-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame25-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame26-Map_MCZBoss_Weapons
	dc.w Map_MCZBoss_Weapons_Frame27-Map_MCZBoss_Weapons
Map_MCZBoss_Weapons_Frame0:	dc.w 2
	dc.b -8,$0A
	dc.w $2000,-40
	dc.b -40,$09
	dc.w $0009,-8
Map_MCZBoss_Weapons_Frame1:	dc.w 2
	dc.b -8,$0A
	dc.w $200F,-40
	dc.b -40,$09
	dc.w $0009,-8
Map_MCZBoss_Weapons_Frame2:	dc.w 2
	dc.b -48,$07
	dc.w $202F,12
	dc.b -16,$0B
	dc.w $2037,8
Map_MCZBoss_Weapons_Frame3 equ Map_MCZBoss_Weapons_Frame2
Map_MCZBoss_Weapons_Frame4 equ Map_MCZBoss_Weapons_Frame2
Map_MCZBoss_Weapons_Frame5:	dc.w 2
	dc.b 18,$08
	dc.w $0018,-8
	dc.b 26,$08
	dc.w $001B,-8
Map_MCZBoss_Weapons_Frame6:	dc.w 2
	dc.b 18,$08
	dc.w $0018,-8
	dc.b 26,$0A
	dc.w $001E,-8
Map_MCZBoss_Weapons_Frame7:	dc.w 1
	dc.b 18,$08
	dc.w $0018,-8
Map_MCZBoss_Weapons_Frame8:	dc.w 5
	dc.b -32,$09
	dc.w $202F,-8
	dc.b -16,$01
	dc.w $2035,0
	dc.b -16,$0F
	dc.w $2037,8
	dc.b -8,$02
	dc.w $2047,40
	dc.b 16,$04
	dc.w $204A,24
Map_MCZBoss_Weapons_Frame9:	dc.w 2
	dc.b -4,$0D
	dc.w $202F,-16
	dc.b -8,$0E
	dc.w $2037,16
Map_MCZBoss_Weapons_Frame10 equ Map_MCZBoss_Weapons_Frame9
Map_MCZBoss_Weapons_Frame11 equ Map_MCZBoss_Weapons_Frame9
Map_MCZBoss_Weapons_Frame12:	dc.w 2
	dc.b -16,$07
	dc.w $4027,-16
	dc.b -16,$07
	dc.w $4827,0
Map_MCZBoss_Weapons_Frame13:	dc.w 0
Map_MCZBoss_Weapons_Frame14 equ Map_MCZBoss_Weapons_Frame13
Map_MCZBoss_Weapons_Frame15 equ Map_MCZBoss_Weapons_Frame13
Map_MCZBoss_Weapons_Frame16 equ Map_MCZBoss_Weapons_Frame13
Map_MCZBoss_Weapons_Frame17 equ Map_MCZBoss_Weapons_Frame13
Map_MCZBoss_Weapons_Frame18 equ Map_MCZBoss_Weapons_Frame13
Map_MCZBoss_Weapons_Frame19 equ Map_MCZBoss_Weapons_Frame13
Map_MCZBoss_Weapons_Frame20 equ Map_MCZBoss_Weapons_Frame13
Map_MCZBoss_Weapons_Frame21:	dc.w 2
	dc.b -48,$07
	dc.w $204C,12
	dc.b -16,$0B
	dc.w $2054,8
Map_MCZBoss_Weapons_Frame22 equ Map_MCZBoss_Weapons_Frame21
Map_MCZBoss_Weapons_Frame23 equ Map_MCZBoss_Weapons_Frame21
Map_MCZBoss_Weapons_Frame24:	dc.w 5
	dc.b -32,$09
	dc.w $204C,-8
	dc.b -16,$01
	dc.w $2052,0
	dc.b -16,$0F
	dc.w $2054,8
	dc.b -8,$02
	dc.w $2064,40
	dc.b 16,$04
	dc.w $2067,24
Map_MCZBoss_Weapons_Frame25:	dc.w 2
	dc.b -4,$0D
	dc.w $204C,-16
	dc.b -8,$0E
	dc.w $2054,16
Map_MCZBoss_Weapons_Frame26 equ Map_MCZBoss_Weapons_Frame25
Map_MCZBoss_Weapons_Frame27 equ Map_MCZBoss_Weapons_Frame25

Map_MCZBoss_Debris:
	dc.w Map_MCZBoss_Debris_Frame0-Map_MCZBoss_Debris
	dc.w Map_MCZBoss_Debris_Frame1-Map_MCZBoss_Debris
Map_MCZBoss_Debris_Frame0:	dc.w 1
	dc.b -8,$05
	dc.w $4000,-8
Map_MCZBoss_Debris_Frame1:	dc.w 1
	dc.b -16,$03
	dc.w $4004,-4
	even
MCZBoss_StaticTiles = 47
MCZBoss_DrillSlotTiles = 29
MCZBoss_DrillSourceTiles = 130
MCZBoss_DrillFramesA:	dc.b 2,3,4,8,9,10,11
MCZBoss_DrillFramesB:	dc.b 21,22,23,24,25,26,27
	even
