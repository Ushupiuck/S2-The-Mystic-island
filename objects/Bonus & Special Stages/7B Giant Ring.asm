; ---------------------------------------------------------------------------
; Object 7B - Special Stage Entry
; ---------------------------------------------------------------------------

GiantRing:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	GiantRing_Index(pc,d0.w),d1
		jmp	GiantRing_Index(pc,d1.w)
; ---------------------------------------------------------------------------
GiantRing_Index:
		dc.w GRing_Main-GiantRing_Index
		dc.w GRing_Animate-GiantRing_Index
		dc.w GRing_Collect-GiantRing_Index
		dc.w GRing_Delete-GiantRing_Index
; ---------------------------------------------------------------------------

GRing_Main:
		move.l	#Map_GiantRing,obMap(a0)
		move.w	#make_art_tile(ArtTile_Giant_Ring,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$40,obActWid(a0)
		tst.b	obRender(a0)
		bpl.s	GRing_Animate
		cmpi.b	#6,(v_emeralds).w
		beq.w	GRing_Delete
		cmpi.w	#50,(v_rings).w
		bcc.s	GRing_Okay
		rts
; ---------------------------------------------------------------------------

GRing_Okay:
		addq.b	#2,obRoutine(a0)
		move.w	#$100,obPriority(a0)
		move.b	#$52,obColType(a0)
		move.b	#1,(v_gfxbigring).w	; Start loading giant ring graphics

GRing_Animate:
		out_of_range.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

GRing_Collect:
		subq.b	#2,obRoutine(a0)
		move.b	#0,obColType(a0)
		bsr.w	FindFreeObj
		bne.w	loc_AB2C
		_move.b	#id_Obj7C,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.l	a0,objoff_3C(a1)
		move.w	(v_player+obX).w,d0
		cmp.w	obX(a0),d0
		bcs.s	loc_AB2C
		bset	#0,obRender(a1)

loc_AB2C:
		move.w	#sfx_GiantRing,d0
		jsr	(PlaySound_Special).l
		move.b	(v_ani1_frame).w,obFrame(a0)
		out_of_range.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

GRing_Delete:
		bra.w	DeleteObject