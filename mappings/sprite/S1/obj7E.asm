; ---------------------------------------------------------------------------
; Sprite mappings - special stage results screen
; ---------------------------------------------------------------------------
Map_Obj7E:
		dc.w M_SSR_Chaos-Map_Obj7E
		dc.w M_SSR_Score-Map_Obj7E
		dc.w byte_CD0D-Map_Obj7E
		dc.w M_Card_Oval-Map_Obj7E
		dc.w byte_CD31-Map_Obj7E
		dc.w byte_CD46-Map_Obj7E
		dc.w byte_CD5B-Map_Obj7E
		dc.w byte_CD6B-Map_Obj7E
		dc.w byte_CDA8-Map_Obj7E
M_SSR_Chaos:	dc.w $D			; "CHAOS EMERALDS"
		dc.w $F805, 8, 4, $FF90
		dc.w $F805, $1C, $E, $FFA0
		dc.w $F805, 0, 0, $FFB0
		dc.w $F805, $32, $19, $FFC0
		dc.w $F805, $3E, $1F, $FFD0
		dc.w $F805, $10, 8, $FFF0
		dc.w $F805, $2A, $15, 0
		dc.w $F805, $10, 8, $10
		dc.w $F805, $3A, $1D, $20
		dc.w $F805, 0, 0, $30
		dc.w $F805, $26, $13, $40
		dc.w $F805, $C, 6, $50
		dc.w $F805, $3E, $1F, $60
M_SSR_Score:	dc.w 6			; "SCORE"
		dc.w $F80D, $14A, $A5, $FFB0
		dc.w $F801, $162, $B1, $FFD0
		dc.w $F809, $164, $B2, $18
		dc.w $F80D, $16A, $B5, $30
		dc.w $F704, $6E, $37, $FFCD
		dc.w $FF04, $186E, $1837, $FFCD
byte_CD0D:	dc.w 7
		dc.w $F80D, $152, $A9, $FFB0
		dc.w $F80D, $66, $33, $FFD9
		dc.w $F801, $14A, $A5, $FFF9
		dc.w $F704, $6E, $37, $FFF6
		dc.w $FF04, $186E, $1837, $FFF6
		dc.w $F80D, $FFF8, $FBFC, $28
		dc.w $F801, $170, $B8, $48
byte_CD31:	dc.w 4
		dc.w $F80D, $FFD1, $7FC8, $FFB0
		dc.w $F80D, $FFD9, $7FD4, $FFD0
		dc.w $F801, $FFE1, $7FE0, $FFF0
		dc.w $F806, $1FE3, $2FE3, $40
byte_CD46:	dc.w 4
		dc.w $F80D, $FFD1, $7FC8, $FFB0
		dc.w $F80D, $FFD9, $7FD4, $FFD0
		dc.w $F801, $FFE1, $7FE0, $FFF0
		dc.w $F806, $1FE9, $2FEC, $40
byte_CD5B:	dc.w 3
		dc.w $F80D, $FFD1, $7FC8, $FFB0
		dc.w $F80D, $FFD9, $7FD4, $FFD0
		dc.w $F801, $FFE1, $7FE0, $FFF0
byte_CD6B:	dc.w $C			; "SPECIAL STAGE"
		dc.w $F805, $3E, $1F, $FF9C
		dc.w $F805, $36, $1B, $FFAC
		dc.w $F805, $10, 8, $FFBC
		dc.w $F805, 8, 4, $FFCC
		dc.w $F801, $20, $10, $FFDC
		dc.w $F805, 0, 0, $FFE4
		dc.w $F805, $26, $13, $FFF4
		dc.w $F805, $3E, $1F, $14
		dc.w $F805, $42, $21, $24
		dc.w $F805, 0, 0, $34
		dc.w $F805, $18, $C, $44
		dc.w $F805, $10, 8, $54
byte_CDA8:	dc.w $F			; "SONIC GOT THEM ALL"
		dc.w $F805, $3E, $1F, $FF88
		dc.w $F805, $32, $19, $FF98
		dc.w $F805, $2E, $17, $FFA8
		dc.w $F801, $20, $10, $FFB8
		dc.w $F805, 8, 4, $FFC0
		dc.w $F805, $18, $C, $FFD8
		dc.w $F805, $32, $19, $FFE8
		dc.w $F805, $42, $21, $FFF8
		dc.w $F805, $42, $21, $10
		dc.w $F805, $1C, $E, $20
		dc.w $F805, $10, 8, $30
		dc.w $F805, $2A, $15, $40
		dc.w $F805, 0, 0, $58
		dc.w $F805, $26, $13, $68
		dc.w $F805, $26, $13, $78
		even