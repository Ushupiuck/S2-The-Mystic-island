; ---------------------------------------------------------------------------
; Object 20 - Empty
; ---------------------------------------------------------------------------

Obj20:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj20_Index(pc,d0.w),d1
		jmp	Obj20_Index(pc,d1.w)
; ===========================================================================
Obj20_Index:	dc.w Obj20_Init-Obj20_Index
		dc.w Obj20_Delete-Obj20_Index
; ===========================================================================

Obj20_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj20_Delete:
		bra.w	DeleteObject