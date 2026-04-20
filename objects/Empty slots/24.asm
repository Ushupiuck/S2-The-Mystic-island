; ---------------------------------------------------------------------------
; Object 24 - Blank
; ---------------------------------------------------------------------------

Obj24:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj24_Index(pc,d0.w),d1
		jmp	Obj24_Index(pc,d1.w)
; ===========================================================================
Obj24_Index:	dc.w Obj24_Init-Obj24_Index
		dc.w Obj24_Delete-Obj24_Index
; ===========================================================================

Obj24_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj24_Delete:
		bra.w	DeleteObject