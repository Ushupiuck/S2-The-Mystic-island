; ---------------------------------------------------------------------------
; Sprite mappings - "GAME OVER"	and "TIME OVER"
; ---------------------------------------------------------------------------
Map_Obj39:
		dc.w byte_CBAC-Map_Obj39
		dc.w byte_CBB7-Map_Obj39
		dc.w byte_CBC2-Map_Obj39
		dc.w byte_CBCD-Map_Obj39
byte_CBAC:	dc.w 2			; GAME
		dc.w $F80D,    0,    0,$FFB8
		dc.w $F80D,    8,    4,$FFD8
byte_CBB7:	dc.w 2			; OVER
		dc.w $F80D,  $14,   $A,	   8
		dc.w $F80D,   $C,    6,	 $28
byte_CBC2:	dc.w 2			; TIME
		dc.w $F809,  $1C,   $E,$FFC4
		dc.w $F80D,    8,    4,$FFDC
byte_CBCD:	dc.w 2			; OVER
		dc.w $F80D,  $14,   $A,	  $C
		dc.w $F80D,   $C,    6,	 $2C
		even