; ---------------------------------------------------------------------------
; Object 2A - Blank
; ---------------------------------------------------------------------------

Obj2A:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj2A_Index(pc,d0.w),d1
		jmp	Obj2A_Index(pc,d1.w)
; ===========================================================================
Obj2A_Index:	dc.w Obj2A_Init-Obj2A_Index
		dc.w Obj2A_Delete-Obj2A_Index
; ===========================================================================

Obj2A_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj2A_Delete:
		bra.w	DeleteObject