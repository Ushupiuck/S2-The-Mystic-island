; ---------------------------------------------------------------------------
; Object 0E - Blank
; ---------------------------------------------------------------------------

Obj0E:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj0E_Index(pc,d0.w),d1
		jmp	Obj0E_Index(pc,d1.w)
; ===========================================================================
Obj0E_Index:	dc.w Obj0E_Init-Obj0E_Index
		dc.w Obj0E_Delete-Obj0E_Index
; ===========================================================================

Obj0E_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj0E_Delete:
		bra.w	DeleteObject