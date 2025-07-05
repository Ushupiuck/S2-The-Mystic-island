; ---------------------------------------------------------------------------
; Object 0F - Blank
; ---------------------------------------------------------------------------

Obj0F:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj0F_Index(pc,d0.w),d1
		jsr	Obj0F_Index(pc,d1.w)
		bra.w	DisplaySprite
; ===========================================================================
Obj0F_Index:	dc.w Obj0F_Init-Obj0F_Index
		dc.w Obj0F_Delete-Obj0F_Index
; ===========================================================================

Obj0F_Init:
		addq.b	#2,obRoutine(a0)
		rts

Obj0F_Delete:
		bra.w	DeleteObject
