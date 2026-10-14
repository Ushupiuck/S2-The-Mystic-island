; ---------------------------------------------------------------------------
; Sprite mappings - special stage results screen
; ---------------------------------------------------------------------------
Map_Obj7E:
		dc.w M_SSR_Chaos-Map_Obj7E
		dc.w M_SSR_Score-Map_Obj7E
		dc.w byte_CD0D-Map_Obj7E
		dc.w M_Result_Oval-Map_Obj7E
		dc.w byte_CD31-Map_Obj7E
		dc.w byte_CD46-Map_Obj7E
		dc.w byte_CD5B-Map_Obj7E
		dc.w byte_CD6B-Map_Obj7E
		dc.w byte_CDA8-Map_Obj7E
M_SSR_Chaos:	dc.w $D			; "CHAOS EMERALDS"
		dc.w $F805, 8, $FF90
		dc.w $F805, $1C, $FFA0
		dc.w $F805, 0, $FFB0
		dc.w $F805, $32, $FFC0
		dc.w $F805, $3E, $FFD0
		dc.w $F805, $10, $FFF0
		dc.w $F805, $2A, 0
		dc.w $F805, $10, $10
		dc.w $F805, $3A, $20
		dc.w $F805, 0, $30
		dc.w $F805, $26, $40
		dc.w $F805, $C, $50
		dc.w $F805, $3E, $60
M_SSR_Score:	dc.w 6			; "SCORE"
		dc.w $F80D, Map_Results_ScoreLetters, $FFB0
		dc.w $F801, Map_Results_ScoreE, $FFD0
		dc.w $F809, Map_Results_ScoreDigits, $18
		dc.w $F80D, Map_Results_ScoreDigits+6, $30
		dc.w $F704, $6D, $FFCD
		dc.w $FF04, $186D, $FFCD
byte_CD0D:	dc.w 7			; Palette-0 animated ring + BONUS
		dc.w $F805, Map_SSResults_RingTile, $FFC0
		dc.w $F80D, $65, $FFD9
		dc.w $F801, Map_Results_ScoreLetters, $FFF9
		dc.w $F704, $6D, $FFF6
		dc.w $FF04, $186D, $FFF6
		dc.w $F80D, $FFF8, $28
		dc.w $F801, Map_Results_Zero, $48
byte_CD31:	dc.w 4
		dc.w $F80D, $FFD1, $FFB0
		dc.w $F80D, $FFD9, $FFD0
		dc.w $F801, $FFE1, $FFF0
		dc.w $F806, $1FE3, $40
byte_CD46:	dc.w 4
		dc.w $F80D, $FFD1, $FFB0
		dc.w $F80D, $FFD9, $FFD0
		dc.w $F801, $FFE1, $FFF0
		dc.w $F806, $1FE9, $40
byte_CD5B:	dc.w 3
		dc.w $F80D, $FFD1, $FFB0
		dc.w $F80D, $FFD9, $FFD0
		dc.w $F801, $FFE1, $FFF0
byte_CD6B:	dc.w $C			; "SPECIAL STAGE"
		dc.w $F805, $3E, $FF9C
		dc.w $F805, $36, $FFAC
		dc.w $F805, $10, $FFBC
		dc.w $F805, 8, $FFCC
		dc.w $F801, $20, $FFDC
		dc.w $F805, 0, $FFE4
		dc.w $F805, $26, $FFF4
		dc.w $F805, $3E, $14
		dc.w $F805, $42, $24
		dc.w $F805, 0, $34
		dc.w $F805, $18, $44
		dc.w $F805, $10, $54
byte_CDA8:	dc.w $F			; "SONIC GOT THEM ALL"
		dc.w $F805, $3E, $FF88
		dc.w $F805, $32, $FF98
		dc.w $F805, $2E, $FFA8
		dc.w $F801, $20, $FFB8
		dc.w $F805, 8, $FFC0
		dc.w $F805, $18, $FFD8
		dc.w $F805, $32, $FFE8
		dc.w $F805, $42, $FFF8
		dc.w $F805, $42, $10
		dc.w $F805, $1C, $20
		dc.w $F805, $10, $30
		dc.w $F805, $2A, $40
		dc.w $F805, 0, $58
		dc.w $F805, $26, $68
		dc.w $F805, $26, $78
		even
