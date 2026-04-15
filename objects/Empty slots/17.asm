; ---------------------------------------------------------------------------
; Object 17 - Blank
; ---------------------------------------------------------------------------

Obj17:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj17_Index(pc,d0.w),d1
		jmp	Obj17_Index(pc,d1.w)
; ===========================================================================
Obj17_Index:	dc.w Obj17_Init-Obj0E_Index
		dc.w Obj17_Delete-Obj0E_Index
; ===========================================================================

Obj17_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj17_Delete:
		bra.w	DeleteObject