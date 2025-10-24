; ---------------------------------------------------------------------------
; Object 1E - Vertical Ball Hog enemy
; ---------------------------------------------------------------------------

hog_launchflagV	= objoff_30	; byte; 0 to launch a cannonball
hog_mode	= objoff_31	; byte; 1 = fire on a timer
hog_wait	= objoff_32	; word; time between shots
hog_backup	= objoff_34	; word; backup of hog_wait
hog_walk	= objoff_36	; word; time to idle around from left to right
hog_timer:	= objoff_32
hog_launchflag  = objoff_30
ObjVBallhog:
Obj1E:					; XREF: Obj_Index
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj1E_Index(pc,d0.w),d0
		jmp	Obj1E_Index(pc,d0.w)
; ===========================================================================
Obj1E_Index:	dc.w Obj1E_Main-Obj1E_Index
		dc.w Obj1E_Action-Obj1E_Index

		dc.w Obj1E_Action2-Obj1E_Index

		dc.w Obj1E_NormalBomb-Obj1E_Index
		dc.w Obj1E_ProtoBomb-Obj1E_Index
; ===========================================================================

Obj1E_Main:				; XREF: Obj1E_Index
		move.l	#Map_BallHogH,obMap(a0)
		move.w	#make_art_tile(ArtTile_Ball_HogH,1,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#5,obColType(a0)
		move.b	#$C,obActWid(a0)
		move.b	#$13,obHeight(a0)
		move.b	#8,obWidth(a0)
		bsr.w	ObjectMoveAndFall
		jsr	ObjHitFloor
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
		sf	hog_launchflagV(a0)	; set to launch	cannonball
		move.w	#$40,hog_walk(a0)
		move.l	#Map_BallHogV,obMap(a0) ; set proto-hog mappings
		move.w	#make_art_tile(ArtTile_Ball_HogV,1,0),obGfx(a0) ; and art pointer
		move.b	#4,ob2ndRout(a0)	; set to timed mode

		cmpi.b	#$0F,d0
		bpl.s	.stationary_proto

		move.b	#0,ob2ndRout(a0)	; Normal mode
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
.timed:
		move.w	#256-1,hog_backup(a0)
		sf	hog_launchflagV(a0)	; set to launch	cannonball
		move.w	#$40,hog_walk(a0)
		move.l	#Map_BallHogV,obMap(a0) ; set proto-hog mappings
		move.w	#make_art_tile(ArtTile_Ball_HogV,1,0),obGfx(a0) ; and art pointer
		move.b	#4,obRoutine(a0)
		move.b	#4,ob2ndRout(a0)	; set to timed mode
		rts

Obj1E_NormalBomb:
		jsr	(ObjectMoveAndFall).l
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
		bra.s	.moving_up
; ---------------------------------------------------------------------------

.check_Xvel:
		tst.w	obVelX(a0)
		bmi.s	.moving_up
		neg.w	obVelX(a0)

.moving_up:
		subq.w	#1,objoff_30(a0)
		bpl.s	.time_remaining
		move.b	#id_Obj3F,(a0)
		move.b	#0,obRoutine(a0)
		rts
;		bra.w	FindFreeObj			; explosion object
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

Obj1E_ProtoBomb:
		btst	#7,obStatus(a0)
		bne.s	.change_explosion
		tst.w	objoff_30(a0)
		bne.s	.dont_react_floor
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	.not_in_floor
		add.w	d1,obY(a0)

.change_explosion:
		move.b	#id_Obj24,(a0)
		move.b	#0,obRoutine(a0)
		rts	

.dont_react_floor:
		subq.w	#1,objoff_30(a0)

.not_in_floor:
		jsr	(ObjectMoveAndFall).l
		move.w	(v_limitbtm2).w,d0
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		bcs.w	DeleteObject
		bra.w	DisplaySprite

; ===========================================================================

Obj1E_Action:				; XREF: Obj1E_Index
		lea	Ani_HogHoriz(pc),a1
		bsr.w	AnimateSprite
		cmpi.b	#1,obFrame(a0)	; is final frame (01) displayed?
		bne.s	Obj1E_SetBall	; if not, branch
		tst.b	hog_wait(a0)		; is it	set to launch cannonball?
		beq.s	Obj1E_MakeBall	; if yes, branch
		bra.w	MarkObjGone
; ===========================================================================

Obj1E_SetBall:				; XREF: Obj1E_Action
		clr.b	hog_wait(a0)		; set to launch	cannonball
		bra.w	MarkObjGone
; ===========================================================================

Obj1E_MakeBall:				; XREF: Obj1E_Action
		move.b	#1,hog_wait(a0)
		bsr.w	FindFreeObj
		bne.w	.no_free_ram
		move.b	#id_Obj1E,(a1)	; load bomb
		move.b	#6,obRoutine(a1); set normal bomb
		move.b	#4,obFrame(a1)  ; set bomb frame
		move.l	#Map_BallHogH,obMap(a1)
		move.b	#6,obHeight(a1)
		move.w	#make_art_tile(ArtTile_Ball_HogH,1,0),obGfx(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#-$100,obVelX(a1)	; cannonball bounces to	the left
		move.w	#0,obVelY(a1)
		move.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$87,obColType(a1)
		move.b	#8,obActWid(a1)
		moveq	#0,d0
		move.b	obSubtype(a0),d0						; move subtype to d0
		add.w	d0,d0								; multiply by 60 frames (1 second)
		add.w	d0,d0
		move.w	d0,d1
		lsl.w	#4,d0
		sub.w	d1,d0
		move.w	d0,objoff_30(a1)

		moveq	#-4,d0
		btst	#0,obStatus(a0)	; is Ball Hog facing right?
		beq.s	.dont_change_dir	; if not, branch
		neg.w	d0
		neg.w	obVelX(a1)		; cannonball bounces to	the right

.dont_change_dir:
		add.w	d0,obX(a1)
		addi.w	#$C,obY(a1)
		move.b	obSubtype(a0),obSubtype(a1) ; copy object type from Ball Hog

.no_free_ram:
		bra.w	MarkObjGone
Ani_HogHoriz:	dc.w .frame1-Ani_HogHoriz
.frame1:	dc.b   9,  0,  0,  2,  2,  3,  2,  0
		dc.b   0,  2,  2,  3,  2,  0,  0,  2
		dc.b   2,  3,  2,  0,  0,  1, afEnd
		even

Obj1E_Action2:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	.action_index(pc,d0.w),d1
		jsr	.action_index(pc,d1.w)
		lea	(Ani_HogVert).l,a1
		bsr.w	AnimateSprite
		jmp	MarkObjGone
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
		bpl.s	.fire
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
; ---------------------------------------------------------------------------

.fire:
		cmpi.b	#2,obFrame(a0)
		bne.s	.abort
		tst.b	hog_launchflag(a0)
		bne.s	.abort
		st	hog_launchflag(a0)

.load_bomb:
		bsr.w	FindFreeObj
		bne.s	.abort			; if ObjectRam is full, we bail!
		move.b	#id_Obj1E,(a1)	; load bomb
		move.b	#8,obRoutine(a1); set proto bomb
		move.b	#4,obFrame(a1)  ; set bomb frame
		move.l	#Map_BallHogH,obMap(a1)
		move.w	#make_art_tile(ArtTile_Ball_HogH,1,0),obGfx(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$87,obColType(a1)
		move.b	#8,obActWid(a1)
		move.w	#$18,objoff_30(a1)
		addi.w	#$10,obY(a1)
.abort:			;.fail in the final
		rts
; ===========================================================================
; ---------------------------------------------------------------------------

Hog_Move:
		subq.w	#1,hog_timer(a0)
		bmi.s	.finished_timer
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
		clr.b	obAnim(a0)
		tst.b	obRender(a0)
		bpl.s	.return
		move.b	#2,obAnim(a0)

.return:
		rts

Hog_Idle2:
		subq.w	#1,hog_timer(a0)
		bpl.s	.fire
		addq.b	#2,ob2ndRout(a0)
		move.w	hog_backup(a0),hog_timer(a0)
		move.w	hog_walk(a0),obVelX(a0)
		move.b	#1,obAnim(a0)
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
		bsr.w	FindFreeObj
		bne.s	.abort			; if ObjectRam is full, we bail!
		move.b	#id_Obj1E,(a1)	; load bomb
		move.b	#8,obRoutine(a1); set proto bomb
		move.b	#4,obFrame(a1)  ; set bomb frame
		move.l	#Map_BallHogH,obMap(a1)
		move.w	#make_art_tile(ArtTile_Ball_HogH,1,0),obGfx(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$87,obColType(a1)
		move.b	#8,obActWid(a1)
		move.w	#$18,objoff_30(a1)
		addi.w	#$10,obY(a1)
.abort:			;.fail in the final
		rts
; ===========================================================================
; ---------------------------------------------------------------------------

Hog_Move2:
		subq.w	#1,hog_timer(a0)
		bmi.s	.finished_timer
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
.finished_timer:
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

Hog_Idle3:
		subq.w	#1,hog_timer(a0)
		bpl.s	.fire
		addq.b	#2,ob2ndRout(a0)
		move.w	hog_backup(a0),hog_timer(a0)
		move.b	#0,obAnim(a0)
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
		bsr.w	FindFreeObj
		bne.s	.abort			; if ObjectRam is full, we bail!
		move.b	#id_Obj1E,(a1)	; load bomb
		move.b	#8,obRoutine(a1); set proto bomb
		move.b	#4,obFrame(a1)  ; set bomb frame
		move.l	#Map_BallHogH,obMap(a1)
		move.w	#make_art_tile(ArtTile_Ball_HogH,1,0),obGfx(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$87,obColType(a1)
		move.b	#8,obActWid(a1)
		move.w	#$18,objoff_30(a1)
		addi.w	#$10,obY(a1)
.abort:			;.fail in the final
		rts
; ===========================================================================
; ---------------------------------------------------------------------------

Hog_Move3:
		subq.w	#1,hog_timer(a0)
		bpl.s	.return
		subq.b	#2,ob2ndRout(a0)
		move.w	hog_backup(a0),hog_timer(a0)
		move.b	#2,obAnim(a0)
.return:
		rts



Ani_HogVert:		dc.w Ani_HogVert.frame1-Ani_HogVert
			dc.w Ani_HogVert.frame2-Ani_HogVert
			dc.w Ani_HogVert.frame3-Ani_HogVert

Ani_HogVert.frame1:	dc.b $F, 0, afEnd
			even
Ani_HogVert.frame2:	dc.b $B, 1, 0, $21, 0, afEnd
			even
Ani_HogVert.frame3:	dc.b $14, 0, 2, 0, afBack, 1
			even
