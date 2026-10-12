; ---------------------------------------------------------------------------
; Sprite mappings - zone title cards
; ---------------------------------------------------------------------------
Map_Cards:
		dc.w M_Card_GHZ-Map_Cards
		dc.w M_Card_LZ-Map_Cards
		dc.w M_Card_MZ-Map_Cards
		dc.w M_Card_SLZ-Map_Cards
		dc.w M_Card_SYZ-Map_Cards
		dc.w M_Card_SBZ-Map_Cards
		dc.w M_Card_Zone-Map_Cards
		dc.w M_Card_Act1-Map_Cards
		dc.w M_Card_Act2-Map_Cards
		dc.w M_Card_Act3-Map_Cards
		dc.w M_Card_Oval-Map_Cards
		dc.w M_Card_FZ-Map_Cards
M_Card_GHZ:	dc.w 9			; GREEN HILL
		dc.w $F805, $18, $FFB4
		dc.w $F805, $3A, $FFC4
		dc.w $F805, $10, $FFD4
		dc.w $F805, $10, $FFE4
		dc.w $F805, $2E, $FFF4
		dc.w $F805, $1C, $14
		dc.w $F801, $20, $24
		dc.w $F805, $26, $2C
		dc.w $F805, $26, $3C
M_Card_LZ:	dc.w 9			; LABYRINTH
		dc.w $F805, $26, $FFBC
		dc.w $F805, 0, $FFCC
		dc.w $F805, 4, $FFDC
		dc.w $F805, $4A, $FFEC
		dc.w $F805, $3A, $FFFC
		dc.w $F801, $20, $C
		dc.w $F805, $2E, $14
		dc.w $F805, $42, $24
		dc.w $F805, $1C, $34
M_Card_MZ:	dc.w 6			; MARBLE
		dc.w $F805, $2A, $FFCF
		dc.w $F805, 0, $FFE0
		dc.w $F805, $3A, $FFF0
		dc.w $F805, 4, 0
		dc.w $F805, $26, $10
		dc.w $F805, $10, $20
M_Card_SLZ:	dc.w 9			; STAR LIGHT
		dc.w $F805, $3E, $FFB4
		dc.w $F805, $42, $FFC4
		dc.w $F805, 0, $FFD4
		dc.w $F805, $3A, $FFE4
		dc.w $F805, $26, 4
		dc.w $F801, $20, $14
		dc.w $F805, $18, $1C
		dc.w $F805, $1C, $2C
		dc.w $F805, $42, $3C
M_Card_SYZ:	dc.w $A			; SPRING YARD
		dc.w $F805, $3E, $FFAC
		dc.w $F805, $36, $FFBC
		dc.w $F805, $3A, $FFCC
		dc.w $F801, $20, $FFDC
		dc.w $F805, $2E, $FFE4
		dc.w $F805, $18, $FFF4
		dc.w $F805, $4A, $14
		dc.w $F805, 0, $24
		dc.w $F805, $3A, $34
		dc.w $F805, $C, $44
M_Card_SBZ:	dc.w $A			; SCRAP BRAIN
		dc.w $F805, $3E, $FFAC
		dc.w $F805, 8, $FFBC
		dc.w $F805, $3A, $FFCC
		dc.w $F805, 0, $FFDC
		dc.w $F805, $36, $FFEC
		dc.w $F805, 4, $C
		dc.w $F805, $3A, $1C
		dc.w $F805, 0, $2C
		dc.w $F801, $20, $3C
		dc.w $F805, $2E, $44
M_Card_Zone:	dc.w 4			; ZONE
		dc.w $F805, $4E, $FFE0
		dc.w $F805, $32, $FFF0
		dc.w $F805, $2E, 0
		dc.w $F805, $10, $10
M_Card_Act1:	dc.w 2			; ACT 1
		dc.w  $40C, $53, $FFEC
		dc.w $F402, $57, $C
M_Card_Act2:	dc.w 2			; ACT 2
		dc.w  $40C, $53, $FFEC
		dc.w $F406, $5A, 8
M_Card_Act3:	dc.w 2			; ACT 3
		dc.w  $40C, $53, $FFEC
		dc.w $F406, $60, 8
M_Card_Oval:	dc.w $D			; Oval
		dc.w $E40C, $70, $FFF4
		dc.w $E402, $74, $14
		dc.w $EC04, $77, $FFEC
		dc.w $F405, $79, $FFE4
		dc.w $140C, $1870, $FFEC
		dc.w  $402, $1874, $FFE4
		dc.w  $C04, $1877, 4
		dc.w $FC05, $1879, $C
		dc.w $EC08, $7D, $FFFC
		dc.w $F40C, $7C, $FFF4
		dc.w $FC08, $7C, $FFF4
		dc.w  $40C, $7C, $FFEC
		dc.w  $C08, $7C, $FFEC
M_Card_FZ:	dc.w 5			; FINAL
		dc.w $F805, $14, $FFDC
		dc.w $F801, $20, $FFEC
		dc.w $F805, $2E, $FFF4
		dc.w $F805, 0, 4
		dc.w $F805, $26, $14
		even
