; ---------------------------------------------------------------------------
; ObjXX - Conveyor belts (WZ, MZ, SBZ, DEZ)
; ---------------------------------------------------------------------------

Conveyor:
	moveq	#0,d0
	move.b	obRoutine(a0),d0
	move.w	Conv_Index(pc,d0.w),d1
	jmp	Conv_Index(pc,d1.w)
; ===========================================================================
Conv_Index:	dc.w Conv_Main-Conv_Index
		dc.w Conv_Action-Conv_Index
; ===========================================================================
conv_height = objoff_3C; Note: add $80 to subtype to get height
conv_speed = objoff_36
conv_width = objoff_38
; ===========================================================================

Conv_Main:	; Routine 0
	addq.b	#2,obRoutine(a0)
	move.w	#48,conv_height(a0) ; Default conveyor belt height ($30)
	move.b	obSubtype(a0),d0 ; get object type
	move.b	obSubtype(a0),d1 ; ...twice, we'll reuse this later
	bpl.s	+
	move.w	#112,conv_height(a0) ; if negative, apply a height of $70
+	; Width: lower 4 bits × 16
	andi.b	#$F,d0		; Mask out lower 4 bits (0–F)
	lsl.b	#4,d0		; Multiply by 16 to get height
	move.b	d0,conv_width(a0)
	; Speed: bits 4–6 >> 4
	andi.b	#$70,d1		; Extract speed bits (bit 4–6)
	ext.w	d1		; Sign-extend
	asr.w	#4,d1		; Divide by 16 to get speed
	btst	#0,obStatus(a0) ; If the object is flipped, skip this next part
	beq.s	+
	neg.w	d1
+	move.w	d1,conv_speed(a0) ; set belt speed

Conv_Action:
	bsr.s	Obj68_Action
	out_of_range.s	.delete
	rts

.delete:
	jmp	(DeleteObject).l
; ===========================================================================

Obj68_Action:
	moveq	#0,d2
	move.b	conv_width(a0),d2
	move.w	d2,d3
	add.w	d3,d3
	lea	(v_player).w,a1 ; a1=character
	move.w	obX(a1),d0
	sub.w	obX(a0),d0
	add.w	d2,d0
	cmp.w	d3,d0
	bhs.s	+
	move.w	obY(a1),d1
	sub.w	obY(a0),d1
	move.w	conv_height(a0),d0 ; load the height
	add.w	d0,d1		; in sonic 1,
	cmp.w	d0,d1		; these two lines would be hardcoded to '$30,d1'
	bhs.s	+
	btst	#1,obStatus(a1)
	bne.s	+
	move.w	conv_speed(a0),d0
	add.w	d0,obX(a1)
+
	rts