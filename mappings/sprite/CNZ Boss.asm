; Prepared CNZ weapon art; six-byte S3&K mappings, original frame IDs.
; Empty pilot frames use the existing shared pod/head children when code is ported.
CNZBoss_WeaponTiles = 119
; Future cycle destinations, byte offsets from v_palette.
CNZBoss_Cycle2PaletteOffset = $34
CNZBoss_Cycle3PaletteOffset = $2A
; Shell draws in front of the Eggmobile; topper is omitted.
CNZBoss_BodyOffsetY = -4

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
Map_CNZBoss_Weapons_Frame1:	dc.w 4
	dc.b -4,$06
	dc.w $2000,-40
	dc.b -4,$07
	dc.w $2006,-24
	dc.b -4,$0F
	dc.w $200E,-8
	dc.b -4,$06
	dc.w $201E,24
Map_CNZBoss_Weapons_Frame2:	dc.w 1
	dc.b 20,$06
	dc.w $2024,-28
Map_CNZBoss_Weapons_Frame3:	dc.w 1
	dc.b 12,$06
	dc.w $202A,-37
Map_CNZBoss_Weapons_Frame4:	dc.w 1
	dc.b 12,$0B
	dc.w $2030,8
Map_CNZBoss_Weapons_Frame5:	dc.w 2
	dc.b 12,$09
	dc.w $203C,8
	dc.b 12,$06
	dc.w $2042,32
Map_CNZBoss_Weapons_Frame6 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame7 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame8 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame9 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame10 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame11 equ Map_CNZBoss_Weapons_Frame0
Map_CNZBoss_Weapons_Frame12:	dc.w 1
	dc.b 36,$0C
	dc.w $2048,-16
Map_CNZBoss_Weapons_Frame13:	dc.w 1
	dc.b 36,$0C
	dc.w $204C,-16
Map_CNZBoss_Weapons_Frame14:	dc.w 1
	dc.b 36,$0C
	dc.w $2050,-16
Map_CNZBoss_Weapons_Frame15:	dc.w 2
	dc.b 28,$0C
	dc.w $2054,-28
	dc.b 28,$0C
	dc.w $2058,4
Map_CNZBoss_Weapons_Frame16:	dc.w 2
	dc.b 28,$0C
	dc.w $205C,-28
	dc.b 28,$0C
	dc.w $2060,4
Map_CNZBoss_Weapons_Frame17:	dc.w 2
	dc.b 28,$0C
	dc.w $2064,-28
	dc.b 28,$0C
	dc.w $2068,4
Map_CNZBoss_Weapons_Frame18:	dc.w 1
	dc.b -12,$0A
	dc.w $006C,-12
Map_CNZBoss_Weapons_Frame19:	dc.w 1
	dc.b -4,$00
	dc.w $0075,-4
Map_CNZBoss_Weapons_Frame20:	dc.w 1
	dc.b -4,$00
	dc.w $0076,-4
	even
