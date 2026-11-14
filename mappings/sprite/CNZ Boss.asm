; Prepared CNZ weapon art; six-byte S3&K mappings, original frame IDs.
; Empty pilot frames use the existing shared pod/head children when code is ported.
CNZBoss_WeaponTiles = 129

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
Map_CNZBoss_Weapons_Frame0:	dc.w 0
Map_CNZBoss_Weapons_Frame1:	dc.w 6
	dc.b -40,$04
	dc.w $2000,9
	dc.b -32,$0D
	dc.w $2002,-7
	dc.b 0,$06
	dc.w $200A,-40
	dc.b 0,$07
	dc.w $2010,-24
	dc.b 0,$0F
	dc.w $2018,-8
	dc.b 0,$06
	dc.w $2028,24
Map_CNZBoss_Weapons_Frame2:	dc.w 1
	dc.b 24,$06
	dc.w $202E,-28
Map_CNZBoss_Weapons_Frame3:	dc.w 1
	dc.b 16,$06
	dc.w $2034,-37
Map_CNZBoss_Weapons_Frame4:	dc.w 1
	dc.b 16,$0B
	dc.w $203A,8
Map_CNZBoss_Weapons_Frame5:	dc.w 2
	dc.b 16,$09
	dc.w $2046,8
	dc.b 16,$06
	dc.w $204C,32
Map_CNZBoss_Weapons_Frame6 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame7 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame8 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame9 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame10 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame11 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame12:	dc.w 1
	dc.b 40,$0C
	dc.w $2052,-16
Map_CNZBoss_Weapons_Frame13:	dc.w 1
	dc.b 40,$0C
	dc.w $2056,-16
Map_CNZBoss_Weapons_Frame14:	dc.w 1
	dc.b 40,$0C
	dc.w $205A,-16
Map_CNZBoss_Weapons_Frame15:	dc.w 2
	dc.b 32,$0C
	dc.w $205E,-28
	dc.b 32,$0C
	dc.w $2062,4
Map_CNZBoss_Weapons_Frame16:	dc.w 2
	dc.b 32,$0C
	dc.w $2066,-28
	dc.b 32,$0C
	dc.w $206A,4
Map_CNZBoss_Weapons_Frame17:	dc.w 2
	dc.b 32,$0C
	dc.w $206E,-28
	dc.b 32,$0C
	dc.w $2072,4
Map_CNZBoss_Weapons_Frame18:	dc.w 1
	dc.b -12,$0A
	dc.w $0076,-12
Map_CNZBoss_Weapons_Frame19:	dc.w 1
	dc.b -4,$00
	dc.w $007F,-4
Map_CNZBoss_Weapons_Frame20:	dc.w 1
	dc.b -4,$00
	dc.w $0080,-4
	even
