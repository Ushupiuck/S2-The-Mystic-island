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
		dc.w M_Card_MI0-Map_Cards
		dc.w M_Card_MI1-Map_Cards
		dc.w M_Card_MI2-Map_Cards
		dc.w M_Card_MI3-Map_Cards
		dc.w M_Card_MI4-Map_Cards
		dc.w M_Card_MI5-Map_Cards
		dc.w M_Card_MI6-Map_Cards
		dc.w M_Card_MI7-Map_Cards
		dc.w M_Card_MI8-Map_Cards
		dc.w M_Card_MI9-Map_Cards
		dc.w M_Card_MI10-Map_Cards
		dc.w M_Card_MI11-Map_Cards
		dc.w M_Card_MI12-Map_Cards
		dc.w M_Card_MI13-Map_Cards
		dc.w M_Card_MI14-Map_Cards
		dc.w M_Card_MI15-Map_Cards
		dc.w M_Card_Act4-Map_Cards
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

M_Card_MI0: dc.w 12 ; TWILIGHT HILL
		dc.w $F805, $42, $FFA6
		dc.w $F805, $84, $FFB6
		dc.w $F801, $20, $FFC6
		dc.w $F805, $26, $FFCE
		dc.w $F801, $20, $FFDE
		dc.w $F805, $18, $FFE6
		dc.w $F805, $1C, $FFF6
		dc.w $F805, $42, $0006
		dc.w $F805, $1C, $0022
		dc.w $F801, $20, $0032
		dc.w $F805, $26, $003A
		dc.w $F805, $26, $004A

M_Card_MI1: dc.w 11 ; RUSTIC RUINS
		dc.w $F805, $3A, $FFAA
		dc.w $F805, $46, $FFBA
		dc.w $F805, $3E, $FFCA
		dc.w $F805, $42, $FFDA
		dc.w $F801, $20, $FFEA
		dc.w $F805, $8, $FFF2
		dc.w $F805, $3A, $000E
		dc.w $F805, $46, $001E
		dc.w $F801, $20, $002E
		dc.w $F805, $2E, $0036
		dc.w $F805, $3E, $0046

M_Card_MI2: dc.w 16 ; ANCIENT WORKBENCH
		dc.w $F805, $0, $FF7E
		dc.w $F805, $2E, $FF8E
		dc.w $F805, $8, $FF9E
		dc.w $F801, $20, $FFAE
		dc.w $F805, $10, $FFB6
		dc.w $F805, $2E, $FFC6
		dc.w $F805, $42, $FFD6
		dc.w $F805, $84, $FFF2
		dc.w $F805, $32, $0002
		dc.w $F805, $3A, $0012
		dc.w $F805, $22, $0022
		dc.w $F805, $4, $0032
		dc.w $F805, $10, $0042
		dc.w $F805, $2E, $0052
		dc.w $F805, $8, $0062
		dc.w $F805, $1C, $0072

M_Card_MI3: dc.w 11 ; EMERALD HILL
		dc.w $F805, $10, $FFA6
		dc.w $F805, $2A, $FFB6
		dc.w $F805, $10, $FFC6
		dc.w $F805, $3A, $FFD6
		dc.w $F805, $0, $FFE6
		dc.w $F805, $26, $FFF6
		dc.w $F805, $C, $0006
		dc.w $F805, $1C, $0022
		dc.w $F801, $20, $0032
		dc.w $F805, $26, $003A
		dc.w $F805, $26, $004A

M_Card_MI4: dc.w 13 ; CRYSTAL VALLEY
		dc.w $F805, $8, $FF92
		dc.w $F805, $3A, $FFA2
		dc.w $F805, $4A, $FFB2
		dc.w $F805, $3E, $FFC2
		dc.w $F805, $42, $FFD2
		dc.w $F805, $0, $FFE2
		dc.w $F805, $26, $FFF2
		dc.w $F805, $80, $000E
		dc.w $F805, $0, $001E
		dc.w $F805, $26, $002E
		dc.w $F805, $26, $003E
		dc.w $F805, $10, $004E
		dc.w $F805, $4A, $005E

M_Card_MI5: dc.w 11 ; EGG MOUNTAIN
		dc.w $F805, $10, $FFA6
		dc.w $F805, $18, $FFB6
		dc.w $F805, $18, $FFC6
		dc.w $F805, $2A, $FFE2
		dc.w $F805, $32, $FFF2
		dc.w $F805, $46, $0002
		dc.w $F805, $2E, $0012
		dc.w $F805, $42, $0022
		dc.w $F805, $0, $0032
		dc.w $F801, $20, $0042
		dc.w $F805, $2E, $004A

M_Card_MI6: dc.w 10 ; METROPOLIS
		dc.w $F805, $2A, $FFB4
		dc.w $F805, $10, $FFC4
		dc.w $F805, $42, $FFD4
		dc.w $F805, $3A, $FFE4
		dc.w $F805, $32, $FFF4
		dc.w $F805, $36, $0004
		dc.w $F805, $32, $0014
		dc.w $F805, $26, $0024
		dc.w $F801, $20, $0034
		dc.w $F805, $3E, $003C

M_Card_MI7: dc.w 16 ; SHOCKING BLIZZARD
		dc.w $F805, $3E, $FF82
		dc.w $F805, $1C, $FF92
		dc.w $F805, $32, $FFA2
		dc.w $F805, $8, $FFB2
		dc.w $F805, $22, $FFC2
		dc.w $F801, $20, $FFD2
		dc.w $F805, $2E, $FFDA
		dc.w $F805, $18, $FFEA
		dc.w $F805, $4, $0006
		dc.w $F805, $26, $0016
		dc.w $F801, $20, $0026
		dc.w $F805, $4E, $002E
		dc.w $F805, $4E, $003E
		dc.w $F805, $0, $004E
		dc.w $F805, $3A, $005E
		dc.w $F805, $C, $006E

M_Card_MI8: dc.w 12 ; SCRAP MADNESS
		dc.w $F805, $3E, $FF9A
		dc.w $F805, $8, $FFAA
		dc.w $F805, $3A, $FFBA
		dc.w $F805, $0, $FFCA
		dc.w $F805, $36, $FFDA
		dc.w $F805, $2A, $FFF6
		dc.w $F805, $0, $0006
		dc.w $F805, $C, $0016
		dc.w $F805, $2E, $0026
		dc.w $F805, $10, $0036
		dc.w $F805, $3E, $0046
		dc.w $F805, $3E, $0056

M_Card_MI9: dc.w 8 ; DEATH EGG
		dc.w $F805, $C, $FFBA
		dc.w $F805, $10, $FFCA
		dc.w $F805, $0, $FFDA
		dc.w $F805, $42, $FFEA
		dc.w $F805, $1C, $FFFA
		dc.w $F805, $10, $0016
		dc.w $F805, $18, $0026
		dc.w $F805, $18, $0036

M_Card_MI10: dc.w 7 ; LEVEL 0A
		dc.w $F805, $26, $FFC2
		dc.w $F805, $10, $FFD2
		dc.w $F805, $80, $FFE2
		dc.w $F805, $10, $FFF2
		dc.w $F805, $26, $0002
		dc.w $F805, $88, $001E
		dc.w $F805, $0, $002E

M_Card_MI11: dc.w 7 ; LEVEL 0B
		dc.w $F805, $26, $FFC2
		dc.w $F805, $10, $FFD2
		dc.w $F805, $80, $FFE2
		dc.w $F805, $10, $FFF2
		dc.w $F805, $26, $0002
		dc.w $F805, $88, $001E
		dc.w $F805, $4, $002E

M_Card_MI12: dc.w 7 ; LEVEL 0C
		dc.w $F805, $26, $FFC2
		dc.w $F805, $10, $FFD2
		dc.w $F805, $80, $FFE2
		dc.w $F805, $10, $FFF2
		dc.w $F805, $26, $0002
		dc.w $F805, $88, $001E
		dc.w $F805, $8, $002E

M_Card_MI13: dc.w 7 ; LEVEL 0D
		dc.w $F805, $26, $FFC2
		dc.w $F805, $10, $FFD2
		dc.w $F805, $80, $FFE2
		dc.w $F805, $10, $FFF2
		dc.w $F805, $26, $0002
		dc.w $F805, $88, $001E
		dc.w $F805, $C, $002E

M_Card_MI14: dc.w 7 ; LEVEL 0E
		dc.w $F805, $26, $FFC2
		dc.w $F805, $10, $FFD2
		dc.w $F805, $80, $FFE2
		dc.w $F805, $10, $FFF2
		dc.w $F805, $26, $0002
		dc.w $F805, $88, $001E
		dc.w $F805, $10, $002E

M_Card_MI15: dc.w 7 ; LEVEL 0F
		dc.w $F805, $26, $FFC2
		dc.w $F805, $10, $FFD2
		dc.w $F805, $80, $FFE2
		dc.w $F805, $10, $FFF2
		dc.w $F805, $26, $0002
		dc.w $F805, $88, $001E
		dc.w $F805, $14, $002E

M_Card_Act4: dc.w 2
		dc.w $040C,$53,$FFEC
		dc.w $F805,$8C,8
		even

M_Result_Oval: dc.w 13
		dc.w $E40C, $6F, $FFF4
		dc.w $E402, $73, $0014
		dc.w $EC04, $76, $FFEC
		dc.w $F405, $78, $FFE4
		dc.w $140C, $186F, $FFEC
		dc.w $0402, $1873, $FFE4
		dc.w $0C04, $1876, $0004
		dc.w $FC05, $1878, $000C
		dc.w $EC08, $7C, $FFFC
		dc.w $F40C, $7B, $FFF4
		dc.w $FC08, $7B, $FFF4
		dc.w $040C, $7B, $FFEC
		dc.w $0C08, $7B, $FFEC

M_Result_Act1: dc.w 2
		dc.w $040C, $52, $FFEC
		dc.w $F402, $56, $000C

M_Result_Act2: dc.w 2
		dc.w $040C, $52, $FFEC
		dc.w $F406, $59, $0008

M_Result_Act3: dc.w 2
		dc.w $040C, $52, $FFEC
		dc.w $F406, $5F, $0008

M_Result_Act4: dc.w 2
		dc.w $040C, $52, $FFEC
		dc.w $F805, $22, $0008
		even
