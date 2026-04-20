; ---------------------------------------------------------------------------
; Object 28 - Empty
; ---------------------------------------------------------------------------

Obj28:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj28_Index(pc,d0.w),d1
		jmp	Obj28_Index(pc,d1.w)
; ===========================================================================
Obj28_Index:	dc.w Obj28_Init-Obj28_Index
		dc.w Obj28_Delete-Obj28_Index
; ===========================================================================

Obj28_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj28_Delete:
		bra.w	DeleteObject