; ---------------------------------------------------------------------------
; Object 7C - Flash from the Giant Ring object
; ---------------------------------------------------------------------------

GiantRingFlash:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	GiantRingFlash_Index(pc,d0.w),d1
		jmp	GiantRingFlash_Index(pc,d1.w)
; ---------------------------------------------------------------------------
GiantRingFlash_Index:
		dc.w loc_AB50-GiantRingFlash_Index
		dc.w loc_AB7E-GiantRingFlash_Index
		dc.w loc_ABE6-GiantRingFlash_Index
; ---------------------------------------------------------------------------

loc_AB50:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_S1Obj7C,obMap(a0)
		move.w	#make_art_tile(ArtTile_Giant_Ring_Flash,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#0,obPriority(a0)
		move.b	#$20,obActWid(a0)
		move.b	#$FF,obFrame(a0)

loc_AB7E:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	+
		move.b	#1,obTimeFrame(a0)
		addq.b	#1,obFrame(a0)
		cmpi.b	#8,obFrame(a0)
		bcc.s	loc_ABD8
		cmpi.b	#3,obFrame(a0)
		bne.s	+
		movea.l	objoff_3C(a0),a1
		move.b	#6,obRoutine(a1)
		move.b	#$1C,(v_player+obAnim).w
		move.b	#1,(f_bigring).w
		clr.b	(v_invinc).w
		clr.b	(v_shield).w
+
		out_of_range.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

loc_ABD8:
		addq.b	#2,obRoutine(a0)
		move.w	#0,(v_player).w
		addq.l	#4,sp
		rts
; End of function sub_AB98

; ---------------------------------------------------------------------------

loc_ABE6:
		bra.w	DeleteObject