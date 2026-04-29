; ---------------------------------------------------------------------------
; Object 21 - Vertical Ball Hog enemy
; ---------------------------------------------------------------------------
hog_launchflag	= objoff_2C	; byte; 0 to launch a cannonball
hog_wait	= objoff_2D	; byte; time between shots
hog_backup	= objoff_2E	; word; backup of hog_wait
hog_walk	= objoff_30	; word; time to idle around from left to right
hog_timer	= objoff_32
hog_cooldown	= objoff_34

Ballhog:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Ballhog_Index(pc,d0.w),d0
		jmp	Ballhog_Index(pc,d0.w)
; ===========================================================================
Ballhog_Index:	dc.w Ballhog_Main-Ballhog_Index		; 0
		dc.w Ballhog_Action-Ballhog_Index	; 2
		dc.w Ballhog_Action2-Ballhog_Index	; 4
		dc.w Ballhog_NormalBomb-Ballhog_Index	; 6
		dc.w Ballhog_ProtoBomb-Ballhog_Index	; 8
; ===========================================================================

Ballhog_Main:
		move.l	#Map_BallHogH,obMap(a0)
		move.w	#make_art_tile(ArtTile_Ball_HogH,1,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#5,obColType(a0)
		move.b	#$C,obActWid(a0)
		move.b	#$13,obHeight(a0)
		move.b	#8,obWidth(a0)
		bsr.w	ObjectMoveAndFall
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.w	#0,obVelY(a0)

		moveq	#0,d0
		move.b	obSubtype(a0),d0	; move subtype to d0
		subi.b	#$10,d0			; substract $0F. If more, means timed mode (yay, high byte recycling)
		beq.s	.timed
		bls.s	.normalmode		; subtypes $00-$0F are horizontal

		move.w	#256-1,hog_backup(a0)
		sf	hog_launchflag(a0)	; set to launch	cannonball
		move.w	#$40,hog_walk(a0)
		move.l	#Map_BallHogV,obMap(a0) ; set proto-hog mappings
		move.w	#make_art_tile(ArtTile_Ball_HogV,1,0),obGfx(a0) ; and art pointer
		move.b	#4,ob2ndRout(a0)	; set to timed mode

		cmpi.b	#$F,d0
		bpl.s	.stationary_proto
		sf	ob2ndRout(a0)		; Normal mode
		add.w	d0,d0			; multiply by 60 frames (1 second)
		add.w	d0,d0
		move.w	d0,d1
		lsl.w	#4,d0
		sub.w	d1,d0
		move.w	d0,hog_backup(a0)
		addq.b	#2,obRoutine(a0)	; adds 2, so the next add branches to Action2

.normalmode:
		addq.b	#2,obRoutine(a0)
.return:
		rts
; ---------------------------------------------------------------------------

.stationary_proto
		subi.b	#$10,d0
		add.w	d0,d0			; multiply by 60 frames (1 second)
		add.w	d0,d0
		move.w	d0,d1
		lsl.w	#4,d0
		sub.w	d1,d0
		move.w	d0,hog_backup(a0)
		move.b	#8,ob2ndRout(a0)	; set to timed mode
		move.b	#4,obRoutine(a0)
		rts
; ---------------------------------------------------------------------------

.timed:
		move.w	#256-1,hog_backup(a0)
		sf	hog_launchflag(a0)	; set to launch	cannonball
		move.w	#$40,hog_walk(a0)
		move.l	#Map_BallHogV,obMap(a0) ; set proto-hog mappings
		move.w	#make_art_tile(ArtTile_Ball_HogV,1,0),obGfx(a0) ; and art pointer
		move.b	#4,obRoutine(a0)
		move.b	#4,ob2ndRout(a0)	; set to timed mode
		rts
; ===========================================================================

Ballhog_Action:
		lea	Ani_HogHoriz(pc),a1
		bsr.w	AnimateSprite
		cmpi.b	#1,obFrame(a0)	; is final frame (01) displayed?
		bne.s	Ballhog_SetBall	; if not, branch
		tst.b	hog_wait(a0)		; is it	set to launch cannonball?
		beq.s	Ballhog_MakeBall	; if yes, branch
		bra.w	MarkObjGone
; ===========================================================================

Ballhog_SetBall:
		sf	hog_wait(a0)		; set to launch	cannonball
		bra.w	MarkObjGone
; ===========================================================================

Ballhog_MakeBall:
		move.b	#1,hog_wait(a0)
		bsr.w	FindNextFreeObj
		bne.w	.no_free_ram
		_move.b	#id_Obj21,obID(a1)	; load bomb
		move.b	#6,obRoutine(a1)	; set normal bomb
		move.b	#4,obFrame(a1)		; set bomb frame
		move.l	#Map_BallHogH,obMap(a1)
		move.b	#6,obHeight(a1)
		move.w	#make_art_tile(ArtTile_Ball_HogH,1,0),obGfx(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#-$100,d2		; cannonball bounces to	the left
		clr.w	obVelY(a1)
		move.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$87,obColType(a1)
		move.b	#8,obActWid(a1)
		moveq	#0,d0
		move.b	obSubtype(a0),d0	; move subtype to d0
		add.w	d0,d0			; multiply by 60 frames (1 second)
		add.w	d0,d0
		move.w	d0,d1
		lsl.w	#4,d0
		sub.w	d1,d0
		move.w	d0,hog_launchflag(a1)

		moveq	#-4,d0
		btst	#0,obStatus(a0)		; is Ball Hog facing right?
		beq.s	.dont_change_dir	; if not, branch
		neg.w	d0
		neg.w	d2			; cannonball bounces to	the right

.dont_change_dir:
		move.w	d2,obVelX(a1)
		add.w	d0,obX(a1)
		addi.w	#$C,obY(a1)
		move.b	obSubtype(a0),obSubtype(a1)	; copy object type from Ball Hog

.no_free_ram:
		bra.w	MarkObjGone
; ===========================================================================

Ballhog_Action2:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	.action_index(pc,d0.w),d1
		jsr	.action_index(pc,d1.w)
		lea	Ani_HogVert(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ===========================================================================
.action_index:
		dc.w Hog_Idle-.action_index
		dc.w Hog_Move-.action_index
; timed
		dc.w Hog_Idle2-.action_index
		dc.w Hog_Move2-.action_index
; Stationary
		dc.w Hog_Idle3-.action_index
		dc.w Hog_Move3-.action_index
; ===========================================================================

Hog_Idle:
		subq.w	#1,hog_timer(a0)
		bpl.w	Hog_Idle3.fire
		addq.b	#2,ob2ndRout(a0)
		move.w	hog_backup(a0),hog_timer(a0)
		move.w	#$40,obVelX(a0)
		move.b	#1,obAnim(a0)
		bchg	#0,obStatus(a0)
		bne.s	.noflip
		neg.w	obVelX(a0)
.noflip:
		sf	hog_launchflag(a0)
		rts
; ===========================================================================

Hog_Move:
		tst.w   hog_cooldown(a0)	; set_cooldown
		beq.s	.dochecks
		subq.w	#1,hog_cooldown(a0)
		bra.s	.keepmoving
.dochecks:
		lea	(v_player2).w,a1
		move.w	obX(a1),d0	; Load Tails's X position
		sub.w	obX(a0),d0
		bpl.s	+
		neg.w	d0
+
		cmpi.w	#$10,d0		; is Proto Hog within $10 pixels of sonic?
		bcs.s	.checkY

		lea	(v_player).w,a1
		move.w	obX(a1),d0	; Load Sonic's X position
		sub.w	obX(a0),d0
		bpl.s	+
		neg.w	d0
+
		cmpi.w	#$10,d0		; is Proto Hog within $10 pixels of sonic?
		bcc.s	.not_below

.checkY:
		move.w	obY(a1),d0	; Load Character's Y position
		sub.w	obY(a0),d0
		cmpi.w	#$80,d0
		bcc.s	.not_below

		move.w	#120,hog_cooldown(a0)	; set_cooldown
		subq.b	#2,ob2ndRout(a0)
		move.w	#60-1,hog_timer(a0)
		clr.w	obVelX(a0)
		sf	obAnim(a0)
		tst.b	obRender(a0)
		bpl.s	.return
		move.b	#2,obAnim(a0)

.return:
		rts
; ---------------------------------------------------------------------------

.not_below:
		subq.w	#1,hog_timer(a0)
		bmi.s	.finished_timer
.keepmoving:
		bsr.w	ObjectMove
		move.w	obX(a0),d3
		addi.w	#$10,d3
		btst	#0,obStatus(a0)
		beq.s	.probe
		subi.w	#$20,d3
.probe:
		jsr	(ObjHitFloor2).l
		cmpi.w	#-8,d1
		blt.s	.finished_timer
		cmpi.w	#$C,d1
		bge.s	.finished_timer
		add.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------

.finished_timer:
		subq.b	#2,ob2ndRout(a0)
		move.w	#60-1,hog_timer(a0)
		clr.w	obVelX(a0)
		sf	obAnim(a0)
		tst.b	obRender(a0)
		bpl.s	.return
		move.b	#2,obAnim(a0)
		rts
; ===========================================================================

Hog_Idle2:
		subq.w	#1,hog_timer(a0)
		bpl.w	Hog_Idle3.fire
		addq.b	#2,ob2ndRout(a0)
		move.w	hog_backup(a0),hog_timer(a0)
		move.w	hog_walk(a0),obVelX(a0)
		move.b	#1,obAnim(a0)
		sf	hog_launchflag(a0)
		rts
; ===========================================================================

Hog_Move2:
		tst.w   hog_cooldown(a0)	; set_cooldown
		beq.s	.dochecks
		subq.w	#1,hog_cooldown(a0)
		bra.s	.keepmoving
.dochecks:
		lea	(v_player2).w,a1
		move.w	obX(a1),d0	; Load Tails's X position
		sub.w	obX(a0),d0
		bpl.s	+
		neg.w	d0
+
		cmpi.w	#$10,d0		; is Proto Hog within $10 pixels of sonic?
		bcs.s	.checkY

		lea	(v_player).w,a1
		move.w	obX(a1),d0	; Load Sonic's X position
		sub.w	obX(a0),d0
		bpl.s	+
		neg.w	d0
+
		cmpi.w	#$10,d0		; is Proto Hog within $10 pixels of sonic?
		bcc.s	.not_below

.checkY:
		move.w	obY(a1),d0	; Load Character's Y position
		sub.w	obY(a0),d0
		cmpi.w	#$80,d0
		bcc.s	.not_below
		move.w	#120,hog_cooldown(a0)	; set_cooldown
		subq.b	#2,ob2ndRout(a0)
		move.w	#60-1,hog_timer(a0)
		move.w	obVelX(a0),hog_walk(a0)
		clr.w	obVelX(a0)
		sf	obAnim(a0)
		tst.b	obRender(a0)
		bpl.s	.return
		move.b	#2,obAnim(a0)

.return:
		rts
; ---------------------------------------------------------------------------

.not_below:
		subq.w	#1,hog_timer(a0)
		bmi.s	.finished_timer
.keepmoving:
		bsr.w	ObjectMove
		move.w	obX(a0),d3
		addi.w	#$10,d3
		btst	#0,obStatus(a0)
		beq.s	+
		subi.w	#$20,d3
+
		jsr	(ObjHitFloor2).l
		cmpi.w	#-8,d1
		blt.s	.just_turn
		cmpi.w	#$C,d1
		bge.s	.just_turn
		rts
; ---------------------------------------------------------------------------

.just_turn:
		bchg	#0,obStatus(a0)
		neg.w	obVelX(a0)
		rts
; ---------------------------------------------------------------------------

.finished_timer:
		subq.b	#2,ob2ndRout(a0)
		move.w	#60-1,hog_timer(a0)
		move.w	obVelX(a0),hog_walk(a0)
		clr.w	obVelX(a0)
		sf	obAnim(a0)
		tst.b	obRender(a0)
		bpl.s	.return
		move.b	#2,obAnim(a0)
		rts
; ===========================================================================

Hog_Idle3:
		subq.w	#1,hog_timer(a0)
		bpl.s	.fire
		addq.b	#2,ob2ndRout(a0)
		move.w	hog_backup(a0),hog_timer(a0)
		sf	obAnim(a0)
		sf	hog_launchflag(a0)
		rts
; ---------------------------------------------------------------------------

.fire:
		cmpi.b	#2,obFrame(a0)
		bne.s	.abort
		tst.b	hog_launchflag(a0)
		bne.s	.abort
		st	hog_launchflag(a0)

.load_bomb:
		bsr.w	FindNextFreeObj
		bne.s	.abort			; if ObjectRam is full, we bail!
		_move.b	#id_Obj21,obID(a1)	; load bomb
		move.b	#8,obRoutine(a1)	; set proto bomb
		move.b	#4,obFrame(a1)		; set bomb frame
		move.l	#Map_BallHogH,obMap(a1)
		move.w	#make_art_tile(ArtTile_Ball_HogH,1,0),obGfx(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$87,obColType(a1)
		move.b	#8,obActWid(a1)
		move.w	#$18,hog_launchflag(a1)
		addi.w	#$10,obY(a1)
.abort:		rts
; ===========================================================================

Hog_Move3:
		tst.w   hog_cooldown(a0)	; set_cooldown
		beq.s	.dochecks
		subq.w	#1,hog_cooldown(a0)
		rts
; ---------------------------------------------------------------------------

.dochecks:
		lea	(v_player2).w,a1
		move.w	obX(a1),d0 	; Load Tails's X position
		sub.w	obX(a0),d0
		bpl.s	+
		neg.w	d0
+
		cmpi.w	#$10,d0		; is Proto Hog within $10 pixels of sonic?
		bcs.s	.checkY

		lea	(v_player).w,a1
		move.w	obX(a1),d0 	; Load Sonic's X position
		sub.w	obX(a0),d0
		bpl.s	+
		neg.w	d0
+
		cmpi.w	#$10,d0		; is Proto Hog within $10 pixels of sonic?
		bcc.s	.not_below

.checkY
		move.w	obY(a1),d0 	; Load Character's Y position
		sub.w	obY(a0),d0
		cmpi.w	#$80,d0
		bcc.s	.not_below
		move.w	#120,hog_cooldown(a0)	; set_cooldown
		subq.b	#2,ob2ndRout(a0)
		move.w	hog_backup(a0),hog_timer(a0)
		move.b	#2,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

.not_below
		subq.w	#1,hog_timer(a0)
		bpl.s	.return
.throw_ball
		subq.b	#2,ob2ndRout(a0)
		move.w	hog_backup(a0),hog_timer(a0)
		move.b	#2,obAnim(a0)
.return:	rts
; ===========================================================================

Ballhog_NormalBomb:
		bsr.w	ObjectMoveAndFall
		moveq	#$6,d3
		jsr	(ObjHitWallRight).l
		tst.w	d1
		bpl.s	+
		neg.w	obVelX(a0)
+
		moveq	#-$6,d3
		jsr	(ObjHitWallLeft).l
		tst.w	d1
		bpl.s	+		; delete if the	fireball hits a	wall
		neg.w	obVelX(a0)
+
		tst.w	obVelY(a0)
		bmi.s	.moving_up
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	.moving_up
		add.w	d1,obY(a0)
		move.w	#-$300,obVelY(a0)
		tst.b	d3
		beq.s	.moving_up
		bmi.s	.check_Xvel
		tst.w	obVelX(a0)
		bpl.s	.moving_up
		neg.w	obVelX(a0)
		subq.w	#1,hog_launchflag(a0)
		bpl.s	.time_remaining
		_move.b	#id_ObjFD,obID(a0)
		sf	obRoutine(a0)
		rts
; ---------------------------------------------------------------------------

.check_Xvel:
		tst.w	obVelX(a0)
		bmi.s	.moving_up
		neg.w	obVelX(a0)

.moving_up:
		subq.w	#1,hog_launchflag(a0)
		bpl.s	.time_remaining
		_move.b	#id_ObjFD,obID(a0)
		sf	obRoutine(a0)
		rts
; ---------------------------------------------------------------------------

.time_remaining:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	.wait_frames
		move.b	#5,obTimeFrame(a0)
		bchg	#0,obFrame(a0)

.wait_frames:
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#$E0,d0
		cmp.w	obY(a0),d0
		bcs.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Ballhog_ProtoBomb:
		btst	#7,obStatus(a0)
		bne.s	.change_explosion
		tst.w	hog_launchflag(a0)
		bne.s	.dont_react_floor
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	.not_in_floor
		add.w	d1,obY(a0)

.change_explosion:
		_move.b	#id_ObjFE,obID(a0)
		sf	obRoutine(a0)
		rts
; ---------------------------------------------------------------------------

.dont_react_floor:
		subq.w	#1,hog_launchflag(a0)

.not_in_floor:
		moveq	#$22,d1
		bsr.w	ObjectMoveAndFall_CustomGravity
		move.w	(v_limitbtm2).w,d0
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		bcs.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
Ani_HogVert:
		dc.w Ani_HogVert.frame1-Ani_HogVert
		dc.w Ani_HogVert.frame2-Ani_HogVert
		dc.w Ani_HogVert.frame3-Ani_HogVert
Ani_HogVert.frame1:
		dc.b $F, 0, afEnd
		even
Ani_HogVert.frame2:
		dc.b $B, 1, 0, $21, 0, afEnd
		even
Ani_HogVert.frame3:
		dc.b $14, 0, 2, 0, afBack, 1
		even
; ---------------------------------------------------------------------------
Ani_HogHoriz:
		dc.w .frame1-Ani_HogHoriz
.frame1:
		dc.b   9,  0,  0,  2,  2,  3,  2,  0
		dc.b   0,  2,  2,  3,  2,  0,  0,  2
		dc.b   2,  3,  2,  0,  0,  1, afEnd
		even
; ---------------------------------------------------------------------------