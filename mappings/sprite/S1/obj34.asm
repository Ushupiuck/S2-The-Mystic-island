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
		dc.w $F805,  $18,   $C,$FFB4
		dc.w $F805,  $3A,  $1D,$FFC4
		dc.w $F805,  $10,    8,$FFD4
		dc.w $F805,  $10,    8,$FFE4
		dc.w $F805,  $2E,  $17,$FFF4
		dc.w $F805,  $1C,   $E,	 $14
		dc.w $F801,  $20,  $10,	 $24
		dc.w $F805,  $26,  $13,	 $2C
		dc.w $F805,  $26,  $13,	 $3C
M_Card_LZ:	dc.w 9			; LABYRINTH
		dc.w $F805,  $26,  $13,$FFBC
		dc.w $F805,    0,    0,$FFCC
		dc.w $F805,    4,    2,$FFDC
		dc.w $F805,  $4A,  $25,$FFEC
		dc.w $F805,  $3A,  $1D,$FFFC
		dc.w $F801,  $20,  $10,	  $C
		dc.w $F805,  $2E,  $17,	 $14
		dc.w $F805,  $42,  $21,	 $24
		dc.w $F805,  $1C,   $E,	 $34
M_Card_MZ:	dc.w 6			; MARBLE
		dc.w $F805,  $2A,  $15,$FFCF
		dc.w $F805,    0,    0,$FFE0
		dc.w $F805,  $3A,  $1D,$FFF0
		dc.w $F805,    4,    2,	   0
		dc.w $F805,  $26,  $13,	 $10
		dc.w $F805,  $10,    8,	 $20
M_Card_SLZ:	dc.w 9			; STAR LIGHT
		dc.w $F805,  $3E,  $1F,$FFB4
		dc.w $F805,  $42,  $21,$FFC4
		dc.w $F805,    0,    0,$FFD4
		dc.w $F805,  $3A,  $1D,$FFE4
		dc.w $F805,  $26,  $13,	   4
		dc.w $F801,  $20,  $10,	 $14
		dc.w $F805,  $18,   $C,	 $1C
		dc.w $F805,  $1C,   $E,	 $2C
		dc.w $F805,  $42,  $21,	 $3C
M_Card_SYZ:	dc.w $A			; SPRING YARD
		dc.w $F805,  $3E,  $1F,$FFAC
		dc.w $F805,  $36,  $1B,$FFBC
		dc.w $F805,  $3A,  $1D,$FFCC
		dc.w $F801,  $20,  $10,$FFDC
		dc.w $F805,  $2E,  $17,$FFE4
		dc.w $F805,  $18,   $C,$FFF4
		dc.w $F805,  $4A,  $25,	 $14
		dc.w $F805,    0,    0,	 $24
		dc.w $F805,  $3A,  $1D,	 $34
		dc.w $F805,   $C,    6,	 $44
M_Card_SBZ:	dc.w $A			; SCRAP BRAIN
		dc.w $F805,  $3E,  $1F,$FFAC
		dc.w $F805,    8,    4,$FFBC
		dc.w $F805,  $3A,  $1D,$FFCC
		dc.w $F805,    0,    0,$FFDC
		dc.w $F805,  $36,  $1B,$FFEC
		dc.w $F805,    4,    2,	  $C
		dc.w $F805,  $3A,  $1D,	 $1C
		dc.w $F805,    0,    0,	 $2C
		dc.w $F801,  $20,  $10,	 $3C
		dc.w $F805,  $2E,  $17,	 $44
M_Card_Zone:	dc.w 4			; ZONE
		dc.w $F805,  $4E,  $27,$FFE0
		dc.w $F805,  $32,  $19,$FFF0
		dc.w $F805,  $2E,  $17,	   0
		dc.w $F805,  $10,    8,	 $10
M_Card_Act1:	dc.w 2			; ACT 1
		dc.w  $40C,  $53,  $29,$FFEC
		dc.w $F402,  $57,  $2B,	  $C
M_Card_Act2:	dc.w 2			; ACT 2
		dc.w  $40C,  $53,  $29,$FFEC
		dc.w $F406,  $5A,  $2D,	   8
M_Card_Act3:	dc.w 2			; ACT 3
		dc.w  $40C,  $53,  $29,$FFEC
		dc.w $F406,  $60,  $30,	   8
M_Card_Oval:	dc.w $D			; Oval
		dc.w $E40C,  $70,  $38,$FFF4
		dc.w $E402,  $74,  $3A,	 $14
		dc.w $EC04,  $77,  $3B,$FFEC
		dc.w $F405,  $79,  $3C,$FFE4
		dc.w $140C,$1870,$1838,$FFEC
		dc.w  $402,$1874,$183A,$FFE4
		dc.w  $C04,$1877,$183B,	   4
		dc.w $FC05,$1879,$183C,	  $C
		dc.w $EC08,  $7D,  $3E,$FFFC
		dc.w $F40C,  $7C,  $3E,$FFF4
		dc.w $FC08,  $7C,  $3E,$FFF4
		dc.w  $40C,  $7C,  $3E,$FFEC
		dc.w  $C08,  $7C,  $3E,$FFEC
M_Card_FZ:	dc.w 5			; FINAL
		dc.w $F805,  $14,   $A,$FFDC
		dc.w $F801,  $20,  $10,$FFEC
		dc.w $F805,  $2E,  $17,$FFF4
		dc.w $F805,    0,    0,	   4
		dc.w $F805,  $26,  $13,	 $14
		even