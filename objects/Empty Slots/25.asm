; ---------------------------------------------------------------------------
; Object 25 - Blank
; ---------------------------------------------------------------------------

Obj25:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj25_Index(pc,d0.w),d1
		jmp	Obj25_Index(pc,d1.w)
; ===========================================================================
Obj25_Index:	dc.w Obj25_Init-Obj25_Index
		dc.w Obj25_Delete-Obj25_Index
; ===========================================================================

Obj25_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj25_Delete:
		bra.w	DeleteObject