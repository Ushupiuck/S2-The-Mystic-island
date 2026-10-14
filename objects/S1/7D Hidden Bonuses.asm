; ---------------------------------------------------------------------------
; Object 7D - hidden points at the end of a level
; ---------------------------------------------------------------------------

Obj7D:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj7D_Index(pc,d0.w),d1
		jmp	Obj7D_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj7D_Index:	dc.w Obj7D_Main-Obj7D_Index
		dc.w Obj7D_DelayDelete-Obj7D_Index
; ---------------------------------------------------------------------------

Obj7D_Main:
		moveq	#$10,d2
		move.w	d2,d3
		add.w	d3,d3
		lea	(v_player).w,a1
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d2,d0
		cmp.w	d3,d0
		bhs.s	loc_13804
		move.w	obY(a1),d1
		sub.w	obY(a0),d1
		add.w	d2,d1
		cmp.w	d3,d1
		bhs.s	loc_13804
		tst.w	(Debug_placement_mode).w
		bne.s	loc_13804
		tst.b	(f_bigring).w
		bne.s	loc_13804
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj7D,obMap(a0)
		move.b	#Map_Obj7D_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_Hidden_Points,0,1),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#sprite_bound($10,Map_Obj7D_width),obActWid(a0)
		move.b	obSubtype(a0),obFrame(a0)
		move.w	#(60*2)-1,objoff_34(a0)
		move.w	#sfx_Bonus,d0
		jsr	(PlaySound_Special).l
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		add.w	d0,d0
		move.w	Obj7D_Points(pc,d0.w),d0
		jsr	(AddPoints).l

loc_13804:
		out_of_range2	UnloadObject
		rts
; ---------------------------------------------------------------------------
Obj7D_Points:	dc.w 0
		dc.w 1000
		dc.w 100
		dc.w 10
; ---------------------------------------------------------------------------

Obj7D_DelayDelete:
		subq.w	#1,objoff_34(a0)
		bmi.s	Obj7D_Delete
		out_of_range2	UnloadObject
		jmp	(DisplaySprite).l
Obj7D_Delete:
		jmp	(DeleteObject).l