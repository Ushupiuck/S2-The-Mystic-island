; ---------------------------------------------------------------------------
; Object 21 - Blank
; ---------------------------------------------------------------------------

Obj21:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj21_Index(pc,d0.w),d1
		jmp	Obj21_Index(pc,d1.w)
; ===========================================================================
Obj21_Index:	dc.w Obj21_Init-Obj21_Index
		dc.w Obj21_Delete-Obj21_Index
; ===========================================================================

Obj21_Init:
		addq.b	#2,obRoutine(a0)
		rts
; loc_1B0A2:
Obj21_Delete:
		bra.w	DeleteObject
