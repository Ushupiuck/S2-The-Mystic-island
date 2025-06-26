; ---------------------------------------------------------------------------
; Sprite mappings - "SONIC HAS PASSED" title card
; ---------------------------------------------------------------------------
Map_Obj3A:
		dc.w M_Got_SonicHas-Map_Obj3A
		dc.w M_Got_Passed-Map_Obj3A
		dc.w M_Got_Score-Map_Obj3A
		dc.w M_Got_TBonus-Map_Obj3A
		dc.w M_Got_RBonus-Map_Obj3A
		dc.w M_Card_Oval-Map_Obj3A
		dc.w M_Card_Act1-Map_Obj3A
		dc.w M_Card_Act2-Map_Obj3A
		dc.w M_Card_Act3-Map_Obj3A
M_Got_SonicHas:	dc.w 8			; SONIC HAS
		dc.w $F805,  $3E,  $1F,$FFB8
		dc.w $F805,  $32,  $19,$FFC8
		dc.w $F805,  $2E,  $17,$FFD8
		dc.w $F801,  $20,  $10,$FFE8
		dc.w $F805,    8,    4,$FFF0
		dc.w $F805,  $1C,   $E,	 $10
		dc.w $F805,    0,    0,	 $20
		dc.w $F805,  $3E,  $1F,	 $30
M_Got_Passed:	dc.w 6			; PASSED
		dc.w $F805,  $36,  $1B,$FFD0
		dc.w $F805,    0,    0,$FFE0
		dc.w $F805,  $3E,  $1F,$FFF0
		dc.w $F805,  $3E,  $1F,	   0
		dc.w $F805,  $10,    8,	 $10
		dc.w $F805,   $C,    6,	 $20
M_Got_Score:	dc.w 6			; SCORE
		dc.w $F80D, $14A,  $A5,$FFB0
		dc.w $F801, $162,  $B1,$FFD0
		dc.w $F809, $164,  $B2,	 $18
		dc.w $F80D, $16A,  $B5,	 $30
		dc.w $F704,  $6E,  $37,$FFCD
		dc.w $FF04,$186E,$1837,$FFCD
M_Got_TBonus:	dc.w 7			; TIME BONUS
		dc.w $F80D, $15A,  $AD,$FFB0
		dc.w $F80D,  $66,  $33,$FFD9
		dc.w $F801, $14A,  $A5,$FFF9
		dc.w $F704,  $6E,  $37,$FFF6
		dc.w $FF04,$186E,$1837,$FFF6
		dc.w $F80D,$FFF0,$FBF8,	 $28
		dc.w $F801, $170,  $B8,	 $48
M_Got_RBonus:	dc.w 7			; RING BONUS
		dc.w $F80D, $152,  $A9,$FFB0
		dc.w $F80D,  $66,  $33,$FFD9
		dc.w $F801, $14A,  $A5,$FFF9
		dc.w $F704,  $6E,  $37,$FFF6
		dc.w $FF04,$186E,$1837,$FFF6
		dc.w $F80D,$FFF8,$FBFC,	 $28
		dc.w $F801, $170,  $B8,	 $48
		even