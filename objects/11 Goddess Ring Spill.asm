; ===========================================================================
; Object 11 - Wacky Workbench goddess ring spill (invisible placement trigger).
; Fifty successful allocations, eleven updates apart, using ordinary lost rings.
; The controller has no mappings; lifetime checks must never queue a sprite.
; ===========================================================================
goddess_timer	= objoff_2E
goddess_remaining = objoff_2F

GoddessRings:
		move.l	#GoddessRings_Wait,code(a0)
		move.b	#50,goddess_remaining(a0)
GoddessRings_Wait:
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		addi.w	#16,d0
		cmpi.w	#32,d0
		bhs.w	MarkObjGone2
		move.w	(v_player+obY).w,d0
		sub.w	obY(a0),d0
		addi.w	#32,d0
		cmpi.w	#64,d0
		bhs.w	MarkObjGone2
		move.l	#GoddessRings_Emit,code(a0)
		bra.w	MarkObjGone2

GoddessRings_Emit:
		subq.b	#1,goddess_timer(a0)
		bpl.w	MarkObjGone2
		move.b	#10,goddess_timer(a0)
		jsr	(FindFreeObj).l
		bne.w	MarkObjGone2
		bsr.w	LostRing_Init
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		addi.w	#24,obX(a1)
		subi.w	#16,obY(a1)
		move.w	#-$200,obVelY(a1)
		jsr	(RandomNumber).l
		andi.w	#7,d0
		add.w	d0,d0
		move.w	.velocities(pc,d0.w),obVelX(a1)
		jsr	(Touch_RegisterEarlierObject).l
		subq.b	#1,goddess_remaining(a0)
		bne.w	MarkObjGone2
		move.l	#MarkObjGone2,code(a0)
		bra.w	MarkObjGone2
.velocities:
		dc.w -$100,-$80,0,$80,$100,$180,$200,$280
