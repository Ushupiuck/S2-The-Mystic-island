; ---------------------------------------------------------------------------
; Object 1D - Empty
; ---------------------------------------------------------------------------

Obj1D:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj1D_Index(pc,d0.w),d1
		jmp	Obj1D_Index(pc,d1.w)
; ===========================================================================
Obj1D_Index:	dc.w Obj1D_Init-Obj1D_Index
		dc.w Obj1D_Delete-Obj1D_Index
; ===========================================================================

Obj1D_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj1D_Delete:
		bra.w	DeleteObject