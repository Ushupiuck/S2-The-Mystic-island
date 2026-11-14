; Prepared CPZ weapon art; six-byte S3&K mappings, original frame IDs.
; Empty pilot frames use the existing shared pod/head children when code is ported.
CPZBoss_WeaponTiles = 109

Map_CPZBoss_Weapons:
	dc.w Map_CPZBoss_Weapons_Frame0-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame1-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame2-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame3-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame4-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame5-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame6-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame7-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame8-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame9-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame10-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame11-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame12-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame13-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame14-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame15-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame16-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame17-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame18-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame19-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame20-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame21-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame22-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame23-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame24-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame25-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame26-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame27-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame28-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame29-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame30-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame31-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame32-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame33-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame34-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame35-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame36-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame37-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame38-Map_CPZBoss_Weapons
	dc.w Map_CPZBoss_Weapons_Frame39-Map_CPZBoss_Weapons
Map_CPZBoss_Weapons_Frame0:	dc.w 3
	dc.b -72,$0D
	dc.w $0000,-8
	dc.b -56,$0A
	dc.w $0008,8
	dc.b -32,$05
	dc.w $0011,16
Map_CPZBoss_Weapons_Frame1:	dc.w 1
	dc.b -4,$00
	dc.w $0015,-4
Map_CPZBoss_Weapons_Frame2:	dc.w 1
	dc.b -4,$04
	dc.w $0016,-11
Map_CPZBoss_Weapons_Frame3:	dc.w 1
	dc.b -4,$04
	dc.w $0018,-10
Map_CPZBoss_Weapons_Frame4:	dc.w 1
	dc.b -60,$00
	dc.w $001A,-5
Map_CPZBoss_Weapons_Frame5:	dc.w 1
	dc.b -60,$00
	dc.w $001B,-5
Map_CPZBoss_Weapons_Frame6:	dc.w 1
	dc.b -60,$00
	dc.w $001C,-5
Map_CPZBoss_Weapons_Frame7:	dc.w 1
	dc.b -60,$01
	dc.w $001D,-5
Map_CPZBoss_Weapons_Frame8:	dc.w 1
	dc.b -60,$01
	dc.w $001F,-5
Map_CPZBoss_Weapons_Frame9:	dc.w 1
	dc.b -4,$00
	dc.w $0021,-4
Map_CPZBoss_Weapons_Frame10:	dc.w 3
	dc.b 0,$0A
	dc.w $0022,0
	dc.b 8,$00
	dc.w $002B,24
	dc.b 8,$08
	dc.w $002C,24
Map_CPZBoss_Weapons_Frame11:	dc.w 1
	dc.b 24,$08
	dc.w $002F,0
Map_CPZBoss_Weapons_Frame12:	dc.w 1
	dc.b 24,$08
	dc.w $0032,0
Map_CPZBoss_Weapons_Frame13:	dc.w 1
	dc.b 24,$08
	dc.w $0035,8
Map_CPZBoss_Weapons_Frame14:	dc.w 1
	dc.b 24,$04
	dc.w $0038,-4
Map_CPZBoss_Weapons_Frame15:	dc.w 1
	dc.b 24,$04
	dc.w $003A,-4
Map_CPZBoss_Weapons_Frame16:	dc.w 1
	dc.b 16,$08
	dc.w $003C,0
Map_CPZBoss_Weapons_Frame17:	dc.w 1
	dc.b 16,$08
	dc.w $003F,0
Map_CPZBoss_Weapons_Frame18:	dc.w 1
	dc.b 16,$08
	dc.w $0042,0
Map_CPZBoss_Weapons_Frame19:	dc.w 1
	dc.b 16,$08
	dc.w $0045,0
Map_CPZBoss_Weapons_Frame20:	dc.w 2
	dc.b 16,$08
	dc.w $0045,0
	dc.b 8,$08
	dc.w $003C,0
Map_CPZBoss_Weapons_Frame21:	dc.w 2
	dc.b 16,$08
	dc.w $0045,0
	dc.b 8,$08
	dc.w $003F,0
Map_CPZBoss_Weapons_Frame22:	dc.w 2
	dc.b 16,$08
	dc.w $0045,0
	dc.b 8,$08
	dc.w $0042,0
Map_CPZBoss_Weapons_Frame23:	dc.w 2
	dc.b 16,$08
	dc.w $0045,0
	dc.b 8,$08
	dc.w $0045,0
Map_CPZBoss_Weapons_Frame24:	dc.w 3
	dc.b 16,$08
	dc.w $0045,0
	dc.b 8,$08
	dc.w $0045,0
	dc.b 0,$08
	dc.w $003C,0
Map_CPZBoss_Weapons_Frame25:	dc.w 3
	dc.b 16,$08
	dc.w $0045,0
	dc.b 8,$08
	dc.w $0045,0
	dc.b 0,$08
	dc.w $003F,0
Map_CPZBoss_Weapons_Frame26:	dc.w 3
	dc.b 16,$08
	dc.w $0045,0
	dc.b 8,$08
	dc.w $0045,0
	dc.b 0,$08
	dc.w $0042,0
Map_CPZBoss_Weapons_Frame27:	dc.w 3
	dc.b 16,$08
	dc.w $0045,0
	dc.b 8,$08
	dc.w $0045,0
	dc.b 0,$08
	dc.w $0045,0
Map_CPZBoss_Weapons_Frame28:	dc.w 4
	dc.b 0,$0A
	dc.w $0022,0
	dc.b 8,$00
	dc.w $002B,24
	dc.b 8,$08
	dc.w $002C,24
	dc.b 8,$08
	dc.w $002C,48
Map_CPZBoss_Weapons_Frame29:	dc.w 1
	dc.b 0,$0B
	dc.w $0048,0
Map_CPZBoss_Weapons_Frame30:	dc.w 5
	dc.b 0,$0A
	dc.w $0022,0
	dc.b 8,$00
	dc.w $002B,24
	dc.b 8,$08
	dc.w $002C,24
	dc.b 8,$08
	dc.w $002C,48
	dc.b 8,$08
	dc.w $002C,72
Map_CPZBoss_Weapons_Frame31:	dc.w 1
	dc.b 0,$0B
	dc.w $0848,0
Map_CPZBoss_Weapons_Frame32:	dc.w 2
	dc.b 0,$0A
	dc.w $0022,0
	dc.b 8,$00
	dc.w $002B,24
Map_CPZBoss_Weapons_Frame33:	dc.w 1
	dc.b 0,$08
	dc.w $002C,0
Map_CPZBoss_Weapons_Frame34:	dc.w 1
	dc.b -72,$0D
	dc.w $0000,-8
Map_CPZBoss_Weapons_Frame35:	dc.w 1
	dc.b -56,$0A
	dc.w $0008,8
Map_CPZBoss_Weapons_Frame36:	dc.w 1
	dc.b -32,$05
	dc.w $0011,16
Map_CPZBoss_Weapons_Frame37:	dc.w 1
	dc.b -32,$0A
	dc.w $0054,-16
Map_CPZBoss_Weapons_Frame38:	dc.w 1
	dc.b -24,$0D
	dc.w $005D,-16
Map_CPZBoss_Weapons_Frame39:	dc.w 1
	dc.b -24,$0D
	dc.w $0065,-16

Map_CPZBoss_Smoke:
	dc.w Map_CPZBoss_Smoke_Frame0-Map_CPZBoss_Smoke
	dc.w Map_CPZBoss_Smoke_Frame1-Map_CPZBoss_Smoke
	dc.w Map_CPZBoss_Smoke_Frame2-Map_CPZBoss_Smoke
	dc.w Map_CPZBoss_Smoke_Frame3-Map_CPZBoss_Smoke
Map_CPZBoss_Smoke_Frame0:	dc.w 1
	dc.b -8,$05
	dc.w $0000,-8
Map_CPZBoss_Smoke_Frame1:	dc.w 1
	dc.b -8,$05
	dc.w $0004,-8
Map_CPZBoss_Smoke_Frame2:	dc.w 1
	dc.b -8,$05
	dc.w $0008,-8
Map_CPZBoss_Smoke_Frame3:	dc.w 1
	dc.b -8,$05
	dc.w $000C,-8
	even
