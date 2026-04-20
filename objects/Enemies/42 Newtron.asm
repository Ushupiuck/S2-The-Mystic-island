; ---------------------------------------------------------------------------
; Object 42 - GHZ Newtron badnik
; ---------------------------------------------------------------------------
newtron_shoot	= objoff_2C	; flag set after shooting, so we don't shoot indefinitely
Newtron:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Newtron_Index(pc,d0.w),d1
		jmp	Newtron_Index(pc,d1.w)
; ===========================================================================
Newtron_Index:
		dc.w Newtron_Init-Newtron_Index		; 0
		dc.w Newtron_Main-Newtron_Index		; 2
		dc.w Newtron_Vanish-Newtron_Index	; 4
; ===========================================================================

Newtron_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Newtron,obMap(a0)
		move.w	#make_art_tile(ArtTile_Newtron,0,0),obGfx(a0)
	;	cmpi.b	#id_MZ,(v_zone).w
	;	bne.s	.skip
	;	move.w	#make_art_tile(ArtTile_MZ_Newtron,0,0),obGfx(a0)
;.skip		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$14,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#8,obWidth(a0)

Newtron_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	.secondary_index(pc,d0.w),d1
		jsr	.secondary_index(pc,d1.w)
		lea	Ani_Newtron(pc),a1
		bsr.w	AnimateSprite	; If green, go to Vanish next time (animation flag afRoutine ensures this)
		bra.w	MarkObjGone
; ===========================================================================
.secondary_index:
		dc.w Newtron_ChkDistance-.secondary_index	; 0
		dc.w Newtron_Type00-.secondary_index		; 2
		dc.w Newtron_ChkFloor-.secondary_index		; 4
		dc.w Newtron_Type02-.secondary_index		; 6
		dc.w Newtron_Type03-.secondary_index		; 8
; ===========================================================================

Newtron_ChkDistance:
		bset	#0,obStatus(a0)
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		bhs.s	+
		neg.w	d0
		bclr	#0,obStatus(a0)
+
		cmpi.w	#$80,d0
		bhs.s	.return
		addq.b	#2,ob2ndRout(a0)
		move.b	#1,obAnim(a0)
		tst.b	obSubtype(a0)
		beq.s	Newtron_Type00
		move.w	#make_art_tile(ArtTile_Newtron,1,0),obGfx(a0)
	;	cmpi.b	#id_MZ,(v_zone).w
	;	bne.s	.skip
	;	move.w	#make_art_tile(ArtTile_MZ_Newtron,1,0),obGfx(a0)
.skip:		cmpi.b	#2,obSubtype(a0)
		beq.s	.hybrid
		move.b	#6,ob2ndRout(a0)
		move.b	#3,obAnim(a0)
		rts

.hybrid:
		move.b	#8,ob2ndRout(a0)
		move.b	#4,obAnim(a0)
.return:	rts
; ===========================================================================
; Blue Newtron that appears before chasing Sonic/Tails
Newtron_Type00:
		cmpi.b	#4,obFrame(a0)
		bhs.s	Newtron_Fall
		bset	#0,obStatus(a0)
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		bhs.s	.return
		bclr	#0,obStatus(a0)
.return:	rts
; ---------------------------------------------------------------------------

Newtron_Fall:
		cmpi.b	#1,obFrame(a0)
		bne.s	+
		move.b	#$C,obColType(a0)
+
		bsr.w	ObjectMoveAndFall
		bsr.w	ObjHitFloor
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,ob2ndRout(a0)
		move.b	#2,obAnim(a0)
		move.b	#$D,obColType(a0)
		move.w	#$200,obVelX(a0)
		btst	#0,obStatus(a0)
		bne.s	.return
		neg.w	obVelX(a0)
.return:	rts
; ===========================================================================

Newtron_ChkFloor:
		bsr.w	ObjectMove
		bsr.w	ObjHitFloor
		cmpi.w	#-8,d1
		blt.s	.return	; Change to ObjectMove and it'll speed up
		cmpi.w	#$C,d1
		bge.s	.return	; Change to ObjectMove and it'll speed up
		add.w	d1,obY(a0)
.return:	rts
; ===========================================================================
; Green Newtron that fires a missile
Newtron_Type02:
		cmpi.b	#1,obFrame(a0)
		bne.s	Newtron_FireMissile
		move.b	#$C,obColType(a0)
; loc_ED14:
Newtron_FireMissile:
		cmpi.b	#2,obFrame(a0)		; is animation on firing frame?
		bne.s	.return			; if so, quit
		tst.b	newtron_shoot(a0)	; has newtron already fired?
		bne.s	.return			; if so, quit
		move.b	#1,newtron_shoot(a0)	; set fired flag
		bsr.w	FindFreeObj
		bne.s	.return
		_move.b	#id_Obj23,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		subq.w	#8,obY(a1)
		move.w	#$200,obVelX(a1)	; by default, missile goes right
		move.w	#20,d0
		btst	#0,obStatus(a0)		; are we facing right?
		bne.s	+			; carry on, then
		neg.w	d0			; otherwise negate
		neg.w	obVelX(a1)
+
		add.w	d0,obX(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	#1,obSubtype(a1)
.return:	rts
; ===========================================================================
; loc_ED6E:
Newtron_Vanish:
		clr.b	obColType(a0)	; Set as intangible
		bra.w	MarkObjGone
; ===========================================================================
; Green Newtron that fires a missile, then gives chase
Newtron_Type03:
		cmpi.b	#1,obFrame(a0)
		bne.s	Newtron_FireMissile2
		move.b	#$C,obColType(a0)
; loc_ED14:
Newtron_FireMissile2:
		cmpi.b	#2,obFrame(a0)		; is animation on firing frame?
		bne.s	.return			; if so, quit
		tst.b	newtron_shoot(a0)	; has newtron already fired?
		bne.s	.return			; if so, quit
		move.b	#1,newtron_shoot(a0)	; set fired flag
		bsr.w	FindFreeObj
		bne.s	.return
		move.b	#2,ob2ndRout(a0)
		_move.b	#id_Obj23,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		subq.w	#8,obY(a1)
		move.w	#$200,obVelX(a1)	; by default, missile goes right
		move.w	#20,d0
		btst	#0,obStatus(a0)		; are we facing right?
		bne.s	+			; carry on, then
		neg.w	d0			; otherwise negate
		neg.w	obVelX(a1)
+
		add.w	d0,obX(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	#1,obSubtype(a1)
.return:	rts
; ===========================================================================
Ani_Newtron:	dc.w ani_newt_blank-Ani_Newtron
		dc.w ani_newt_drop-Ani_Newtron
		dc.w ani_newt_fly-Ani_Newtron
		dc.w ani_newt_fire-Ani_Newtron
		dc.w ani_newt_fire2-Ani_Newtron
ani_newt_blank:	dc.b  $F,  8,afEnd
ani_newt_drop:	dc.b $13,  0,  1,  3,  4,  5,afBack,  1
ani_newt_fly:	dc.b   2,  6,  7,afEnd
ani_newt_fire:	dc.b $13,  0,  1,  1,  2,  1,  1,  0,  8,afRoutine
ani_newt_fire2:	dc.b $13,  0,  1,  1,  2,  1,  1,  4,  5,afBack,  1
		even