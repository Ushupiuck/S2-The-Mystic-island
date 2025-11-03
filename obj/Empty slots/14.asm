; ---------------------------------------------------------------------------
; Object 14 - Blank
; ---------------------------------------------------------------------------

Obj14:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj14_Index(pc,d0.w),d1
		jmp	Obj14_Index(pc,d1.w)
; ===========================================================================
Obj14_Index:	dc.w Obj14_Init-Obj14_Index
		dc.w Obj14_Delete-Obj14_Index
; ===========================================================================

Obj14_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj14_Delete:
		bra.w	DeleteObject