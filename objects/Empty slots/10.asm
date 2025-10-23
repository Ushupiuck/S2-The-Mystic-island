; ---------------------------------------------------------------------------
; Object 10 - Blank
; ---------------------------------------------------------------------------

Obj10:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj10_Index(pc,d0.w),d1
		jmp	Obj10_Index(pc,d1.w)
; ===========================================================================
Obj10_Index:	dc.w Obj10_Init-Obj10_Index
		dc.w Obj10_Delete-Obj10_Index
; ===========================================================================

Obj10_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj10_Delete:
		bra.w	DeleteObject