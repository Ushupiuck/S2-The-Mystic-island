; ---------------------------------------------------------------------------
; Object 38 - shield and invincibility stars
; ---------------------------------------------------------------------------

Obj38:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj38_Index(pc,d0.w),d1
		jmp	Obj38_Index(pc,d1.w)
; ===========================================================================
Obj38_Index:	dc.w Obj38_Init-Obj38_Index
		dc.w Obj38_Shield-Obj38_Index
		dc.w Obj38_Stars-Obj38_Index
; ===========================================================================

Obj38_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_obj38,obMap(a0)
		move.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		move.b	#$18,obActWid(a0)
		tst.b	obAnim(a0)			; is this the shield?
		bne.s	+				; if not, branch
		move.w	#make_art_tile(ArtTile_Shield,0,0),obGfx(a0)
		cmpi.b	#id_EHZ,(Current_Zone).w	; is this Emerald Hill Zone?
		bne.s	+				; if not, branch
		move.w	#make_art_tile(ArtTile_EHZ_Shield,0,0),obGfx(a0)
+
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Sonic,obMap(a0)		; apparently use Sonic's mappings?
		move.w	#make_art_tile(ArtTile_Invincibility,0,0),obGfx(a0)
		move.w	#$100,obPriority(a0)
.return:
		rts
; ===========================================================================

Obj38_Shield:
		tst.b	(v_invinc).w			; is Sonic invincible?
		bne.s	Obj38_Init.return		; if yes, branch
		tst.b	(v_shield).w			; does Sonic have a shield?
		beq.s	Obj38_Delete			; if not, branch
		move.w	(v_player+obX).w,obX(a0)
		move.w	(v_player+obY).w,obY(a0)
		move.b	(v_player+obStatus).w,obStatus(a0)
		lea	(Ani_obj38).l,a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l
; ===========================================================================
; loc_1245C:
Obj38_Delete:
		jmp	(DeleteObject).l
; ===========================================================================

Obj38_Stars:
		tst.b	(v_invinc).w			; is Sonic invincible?
		beq.s	Obj38_Delete			; if not, branch
		move.w	(Sonic_Pos_Record_Index).w,d0
		move.b	obAnim(a0),d1
		subq.b	#1,d1
		move.b	#$3F,d1
		lsl.b	#2,d1
		addi.b	#4,d1
		sub.b	d1,d0
		lea	(Sonic_Pos_Record_Buf).w,a1
		lea	(a1,d0.w),a1
		move.w	(a1)+,d0
		andi.w	#$3FFF,d0
		move.w	d0,obX(a0)
		move.w	(a1)+,d0
		andi.w	#$7FF,d0
		move.w	d0,obY(a0)
		move.b	(v_player+obStatus).w,obStatus(a0)
		move.b	(v_player+obFrame).w,obFrame(a0)
		move.b	(v_player+obRender).w,obRender(a0)
		jmp	(DisplaySprite).l
; ===========================================================================
Ani_obj38:	dc.w byte_125C2-Ani_obj38
		dc.w byte_125CE-Ani_obj38
		dc.w byte_125D4-Ani_obj38
		dc.w byte_125EE-Ani_obj38
		dc.w byte_12608-Ani_obj38
byte_125C2:	dc.b   0,  5,  0,  5,  1,  5,  2,  5,  3,  5,  4,afEnd
byte_125CE:	dc.b   5,  4,  5,  6,  7,afEnd
byte_125D4:	dc.b   0,  4,  4,  0,  4,  4,  0,  5,  5,  0,  5,  5,  0,  6,  6,  0
		dc.b   6,  6,  0,  7,  7,  0,  7,  7,  0,afEnd
byte_125EE:	dc.b   0,  4,  4,  0,  4,  0,  0,  5,  5,  0,  5,  0,  0,  6,  6,  0
		dc.b   6,  0,  0,  7,  7,  0,  7,  0,  0,afEnd
byte_12608:	dc.b   0,  4,  0,  0,  4,  0,  0,  5,  0,  0,  5,  0,  0,  6,  0,  0
		dc.b   6,  0,  0,  7,  0,  0,  7,  0,  0,afEnd
		even
