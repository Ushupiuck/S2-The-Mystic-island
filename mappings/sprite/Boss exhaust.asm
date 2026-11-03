; Sonic 1 geometry; shared independently of the vehicle artwork.
Map_BossExhaust:
	dc.w Map_BossExhaust_Frame0-Map_BossExhaust
	dc.w Map_BossExhaust_Frame1-Map_BossExhaust
	dc.w Map_BossExhaust_Frame2-Map_BossExhaust
	dc.w Map_BossExhaust_Frame3-Map_BossExhaust
	dc.w Map_BossExhaust_Frame4-Map_BossExhaust
Map_BossExhaust_Frame0:	dc.w 1
	dc.b 4,$05
	dc.w $0000,0
Map_BossExhaust_Frame1:	dc.w 1
	dc.b 4,$05
	dc.w $0004,0
Map_BossExhaust_Frame2:	dc.w 2
	dc.b 0,$08
	dc.w $0008,0
	dc.b 8,$08
	dc.w $1008,0
Map_BossExhaust_Frame3:	dc.w 2
	dc.b -8,$0B
	dc.w $000B,0
	dc.b 0,$01
	dc.w $0017,24
Map_BossExhaust_Frame4:	dc.w 0
	even
