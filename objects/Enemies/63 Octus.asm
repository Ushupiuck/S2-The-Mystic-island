; ===========================================================================
; ---------------------------------------------------------------------------
; Object 63 - Octus badnik
; ---------------------------------------------------------------------------
octus_startpos	= objoff_2E
octus_timer	= objoff_30
; ---------------------------------------------------------------------------

Octus:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Octus_Index(pc,d0.w),d1
		jmp	Octus_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Octus_Index:	dc.w Octus_Init-Octus_Index	; 0
		dc.w Octus_Main-Octus_Index	; 2
		dc.w Octus_Bullet-Octus_Index	; 4
; ---------------------------------------------------------------------------

Octus_Init:
		move.l	#Map_Octus,obMap(a0)
		move.w	#make_art_tile(ArtTile_Octus,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$B,obHeight(a0)
		move.b	#8,obWidth(a0)
		jsr	(ObjectMoveAndFall).l
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	+
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,obRoutine(a0)
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		bpl.s	+
		bchg	#0,obStatus(a0)
+
		move.w	obY(a0),octus_startpos(a0)
		rts
; ---------------------------------------------------------------------------

Octus_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Octus_SubIndex(pc,d0.w),d1
		jsr	Octus_SubIndex(pc,d1.w)
		lea	Ani_Octus(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Octus_SubIndex:	dc.w Octus_WaitForCharacter-Octus_SubIndex
		dc.w Octus_DelayBeforeMoveUp-Octus_SubIndex
		dc.w Octus_MoveUpAndFire-Octus_SubIndex
		dc.w Octus_Hover-Octus_SubIndex
		dc.w Octus_MoveDown-Octus_SubIndex
; ---------------------------------------------------------------------------

Octus_WaitForCharacter:
		lea	(v_player).w,a1
		bsr.s	Octus_CheckCharacterRange
		blo.s	.activate
		lea	(v_player2).w,a1
		bsr.s	Octus_CheckCharacterRange
		bhs.s	.return

.activate:
		addq.b	#2,ob2ndRout(a0)
		move.b	#3,obAnim(a0)
		move.b	#$20,octus_timer(a0)
.return:	rts
; ---------------------------------------------------------------------------

Octus_CheckCharacterRange:
		move.w	obX(a0),d0
		sub.w	obX(a1),d0
		addi.w	#$80,d0
		cmpi.w	#$101,d0
		rts
; ---------------------------------------------------------------------------

Octus_DelayBeforeMoveUp:
		subq.b	#1,octus_timer(a0)
		bpl.s	Octus_WaitForCharacter.return
		addq.b	#2,ob2ndRout(a0)
		move.b	#4,obAnim(a0)
		move.w	#-$200,obVelY(a0)
.move:		jmp	(ObjectMove).l
; ---------------------------------------------------------------------------
Octus_MoveUpAndFire:
		addi.w	#$10,obVelY(a0)
		bmi.s	Octus_DelayBeforeMoveUp.move
		addq.b	#2,ob2ndRout(a0)
		move.b	#60,octus_timer(a0)
		jsr	(FindFreeObj).l
		bne.s	.return
		_move.b	#id_Obj63,obID(a1)
		move.b	#4,obRoutine(a1)
		move.l	#Map_Octus,obMap(a1)
		move.w	#make_art_tile(ArtTile_Octus,1,0),obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	#$F,octus_timer(a1)
		move.b	obRender(a0),obRender(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	#2,obAnim(a1)
		move.b	#$98,obColType(a1)
		move.w	#-$200,obVelX(a1)
		btst	#0,obRender(a1)
		beq.s	.return
		neg.w	obVelX(a1)
.return:	rts
; ===========================================================================

Octus_Hover:
		subq.b	#1,octus_timer(a0)
		bpl.s	.return
		addq.b	#2,ob2ndRout(a0)
.return:	rts
; ===========================================================================

Octus_MoveDown:
		addi.w	#$10,obVelY(a0)
		move.w	obY(a0),d0
		cmp.w	octus_startpos(a0),d0
		blo.s	.move
		clr.b	ob2ndRout(a0)
		clr.b	obAnim(a0)
		clr.w	obVelY(a0)
		move.b	#1,obFrame(a0)
.move:		jmp	(ObjectMove).l
; ---------------------------------------------------------------------------

Octus_Bullet:
		subq.b	#1,octus_timer(a0)
		bpl.s	Octus_Hover.return
		jsr	(ObjectMove).l
		lea	Ani_Octus(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Ani_Octus:	offsetTable
		offsetTableEntry.w byte_2CBE6	; 0
		offsetTableEntry.w byte_2CBEA	; 1
		offsetTableEntry.w byte_2CBEF	; 2
		offsetTableEntry.w byte_2CBF4	; 3
		offsetTableEntry.w byte_2CBF8	; 4
byte_2CBE6:	dc.b  $F,  1,  0,afEnd
byte_2CBEA:	dc.b   3,  1,  2,  3,afEnd
		even
byte_2CBEF:	dc.b   2,  5,  6,afEnd
byte_2CBF4:	dc.b  $F,  4,afEnd
		even
byte_2CBF8:	dc.b   7,  0,  1,afChange,  1
		even