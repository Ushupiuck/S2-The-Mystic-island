; ---------------------------------------------------------------------------
; Object 61 - Crabmeat enemy (GHZ, SYZ)
; ---------------------------------------------------------------------------

Crabmeat:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Crab_Index(pc,d0.w),d1
		jmp	Crab_Index(pc,d1.w)
; ===========================================================================
Crab_Index:
		dc.w Crab_Main-Crab_Index	; 0
		dc.w Crab_Action-Crab_Index	; 2
		dc.w Crab_Delete-Crab_Index	; 4
		dc.w Crab_BallMain-Crab_Index	; 6
		dc.w Crab_BallMove-Crab_Index	; 8

crab_timedelay	= objoff_30
crab_mode	= objoff_32
; ===========================================================================

Crab_Main:	; Routine 0
		move.b	#$10,obHeight(a0)
		move.b	#8,obWidth(a0)
		move.l	#Map_Crab,obMap(a0)
		move.w	#make_art_tile(ArtTile_Crabmeat,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$180,obPriority(a0)
		move.b	#6,obColType(a0)
		move.b	#$15,obActWid(a0)
		bsr.w	ObjectMoveAndFall
		jsr	(ObjHitFloor).l	; find floor
		tst.w	d1
		bpl.s	.floornotfound
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		clr.w	obVelY(a0)
		addq.b	#2,obRoutine(a0)

.floornotfound:
		rts
; ===========================================================================

Crab_Action:	; Routine 2
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	.index(pc,d0.w),d1
		jsr	.index(pc,d1.w)
		lea	Ani_obj61(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ===========================================================================
.index:		dc.w .waittofire-.index
		dc.w .walkonfloor-.index
; ===========================================================================

.waittofire:
		subq.w	#1,crab_timedelay(a0) ; subtract 1 from time delay
		bpl.s	.dontmove
		tst.b	obRender(a0)
		bpl.s	.movecrab
		bchg	#1,crab_mode(a0)
		bne.s	.fire

.movecrab:
		addq.b	#2,ob2ndRout(a0)
		move.w	#127,crab_timedelay(a0) ; set time delay to approx 2 seconds
		move.w	#$80,obVelX(a0)	; move Crabmeat	to the right
		bsr.w	Crab_SetAni
		addq.b	#3,d0
		move.b	d0,obAnim(a0)
		bchg	#0,obStatus(a0)
		bne.s	.noflip
		neg.w	obVelX(a0)	; change direction

.dontmove:
.noflip:
		rts
; ===========================================================================

.fire:
		move.w	#60-1,crab_timedelay(a0)
		move.b	#6,obAnim(a0)	; use firing animation
		bsr.w	FindFreeObj
		bne.s	.failleft
		_move.b	#id_Obj61,obID(a1) ; load left fireball
		move.b	#6,obRoutine(a1)
		move.w	obX(a0),obX(a1)
		subi.w	#$10,obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#-$100,obVelX(a1)

.failleft:
		bsr.w	FindFreeObj
		bne.s	.failright
		_move.b	#id_Obj61,obID(a1) ; load right fireball
		move.b	#6,obRoutine(a1)
		move.w	obX(a0),obX(a1)
		addi.w	#$10,obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#$100,obVelX(a1)

.failright:
		rts
; ===========================================================================

.walkonfloor:
		subq.w	#1,crab_timedelay(a0)
		bmi.s	loc_966E
		bsr.w	ObjectMove
		bchg	#0,crab_mode(a0)
		bne.s	loc_9654
		move.w	obX(a0),d3
		addi.w	#$10,d3
		btst	#0,obStatus(a0)
		beq.s	loc_9640
		subi.w	#$20,d3

loc_9640:
		jsr	(ObjHitFloor2).l
		cmpi.w	#-8,d1
		blt.s	loc_966E
		cmpi.w	#$C,d1
		bge.s	loc_966E
		rts
; ===========================================================================

loc_9654:
		jsr	(ObjHitFloor).l
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Crab_SetAni
		addq.b	#3,d0
		move.b	d0,obAnim(a0)
		rts
; ===========================================================================

loc_966E:
		subq.b	#2,ob2ndRout(a0)
		move.w	#59,crab_timedelay(a0)
		clr.w	obVelX(a0)
		bsr.w	Crab_SetAni
		move.b	d0,obAnim(a0)
		rts
; ---------------------------------------------------------------------------
; Subroutine to	set the	correct	animation for a	Crabmeat
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


Crab_SetAni:
		moveq	#0,d0
		move.b	obAngle(a0),d3
		bmi.s	loc_96A4
		cmpi.b	#6,d3
		blo.s	.return
		moveq	#1,d0
		btst	#0,obStatus(a0)
		bne.s	.return
		moveq	#2,d0
.return:	rts
; ===========================================================================

loc_96A4:
		cmpi.b	#-6,d3
		bhi.s	.return
		moveq	#2,d0
		btst	#0,obStatus(a0)
		bne.s	.return
		moveq	#1,d0
.return:	rts
; End of function Crab_SetAni

; ===========================================================================

Crab_Delete:	; Routine 4
		bra.w	DeleteObject
; ===========================================================================
; ---------------------------------------------------------------------------
; Sub-object - missile that the	Crabmeat throws
; ---------------------------------------------------------------------------

Crab_BallMain:	; Routine 6
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Crab,obMap(a0)
		move.w	#make_art_tile(ArtTile_Crabmeat,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$180,obPriority(a0)
		move.b	#$87,obColType(a0)
		move.b	#8,obActWid(a0)
		move.w	#-$400,obVelY(a0)
		move.b	#7,obAnim(a0)

Crab_BallMove:	; Routine 8
		lea	Ani_obj61(pc),a1
		bsr.w	AnimateSprite
		bsr.w	ObjectMoveAndFall
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		blo.w	DeleteObject
		bra.w	DisplaySprite
; ===========================================================================
; animation script
Ani_obj61:	dc.w byte_A30C-Ani_obj61
		dc.w byte_A30F-Ani_obj61
		dc.w byte_A312-Ani_obj61
		dc.w byte_A315-Ani_obj61
		dc.w byte_A31A-Ani_obj61
		dc.w byte_A31F-Ani_obj61
		dc.w byte_A324-Ani_obj61
		dc.w byte_A327-Ani_obj61
byte_A30C:	dc.b  $F,  0,afEnd
byte_A30F:	dc.b  $F,  2,afEnd
byte_A312:	dc.b  $F,$22,afEnd
byte_A315:	dc.b  $F,  1,$21,  0,afEnd
byte_A31A:	dc.b  $F,$21,  3,  2,afEnd
byte_A31F:	dc.b  $F,  1,$23,$22,afEnd
byte_A324:	dc.b  $F,  4,afEnd
byte_A327:	dc.b   1,  5,  6,afEnd
		even