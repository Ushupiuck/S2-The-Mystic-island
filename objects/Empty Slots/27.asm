; ---------------------------------------------------------------------------
; Object 27 - Blank
; ---------------------------------------------------------------------------

Obj27:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj27_Index(pc,d0.w),d1
		jmp	Obj27_Index(pc,d1.w)
; ===========================================================================
Obj27_Index:	dc.w Obj27_Init-Obj27_Index
		dc.w Obj27_Delete-Obj27_Index
; ===========================================================================

Obj27_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj27_Delete:
		bra.w	DeleteObject