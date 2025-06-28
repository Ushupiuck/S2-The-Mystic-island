; ---------------------------------------------------------------------------
; Sprite mappings - rings (S1 format)
; ---------------------------------------------------------------------------
SS_Ring_internal:
		dc.w .front-SS_Ring_internal
		dc.w .angle1-SS_Ring_internal
		dc.w .edge-SS_Ring_internal
		dc.w .angle2-SS_Ring_internal
		dc.w .sparkle1-SS_Ring_internal
		dc.w .sparkle2-SS_Ring_internal
		dc.w .sparkle3-SS_Ring_internal
		dc.w .sparkle4-SS_Ring_internal
		dc.w .blank-SS_Ring_internal
.front:		dc.b 1
		dc.b $F8, 5, 0,	0, $F8	; ring front
.angle1:	dc.b 1
		dc.b $F8, 5, 0,	4, $F8	; ring angle
.edge:		dc.b 1
		dc.b $F8, 1, 0,	8, $FC	; ring perpendicular
.angle2:	dc.b 1
		dc.b $F8, 5, 8,	4, $F8	; ring angle
.sparkle1:	dc.b 1
		dc.b $F8, 5, 0,	$A, $F8	; sparkle
.sparkle2:	dc.b 1
		dc.b $F8, 5, $18, $A, $F8 ; sparkle
.sparkle3:	dc.b 1
		dc.b $F8, 5, 8,	$A, $F8	;sparkle
.sparkle4:	dc.b 1
		dc.b $F8, 5, $10, $A, $F8 ; sparkle
.blank:		dc.b 0
		even