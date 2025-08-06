; ---------------------------------------------------------------------------
; Object 53 - Empty
; ---------------------------------------------------------------------------

Obj53:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj53_Index(pc,d0.w),d1
		jmp	Obj53_Index(pc,d1.w)
; ===========================================================================
Obj53_Index:	dc.w Obj53_Init-Obj53_Index
		dc.w Obj53_Delete-Obj53_Index
; ===========================================================================

Obj53_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj53_Delete:
		jmp	(DeleteObject).l