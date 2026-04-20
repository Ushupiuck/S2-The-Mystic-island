; ---------------------------------------------------------------------------
; Object 15 - Blank
; ---------------------------------------------------------------------------

Obj15:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj15_Index(pc,d0.w),d1
		jmp	Obj15_Index(pc,d1.w)
; ===========================================================================
Obj15_Index:	dc.w Obj15_Init-Obj15_Index
		dc.w Obj15_Delete-Obj15_Index
; ===========================================================================

Obj15_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj15_Delete:
		bra.w	DeleteObject