; ---------------------------------------------------------------------------
; Object 3C - smashable wall (GHZ, SLZ)
; ---------------------------------------------------------------------------

Obj3C:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Smash_Index(pc,d0.w),d1
		jsr	Smash_Index(pc,d1.w)
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
Smash_Index:	dc.w Smash_Main-Smash_Index
		dc.w Smash_Solid-Smash_Index
		dc.w Smash_FragMove-Smash_Index

smash_speed	= objoff_30		; Sonic's horizontal speed
smash_speed2	= objoff_32		; Tails's horizontal speed (I believe this is how Sonic 3 works)
; ---------------------------------------------------------------------------

Smash_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj3C,obMap(a0)
		move.w	#make_art_tile($590,2,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#$10,obActWid(a0)
		move.w	#$200,obPriority(a0)
		move.b	obSubtype(a0),obFrame(a0)

Smash_Solid:	; Routine 2
		move.w	(v_player+obVelX).w,smash_speed(a0) ; load Sonic's horizontal speed
		moveq	#$1B,d1
		moveq	#$20,d2
		moveq	#$20,d3
		move.w	obX(a0),d4
		bsr.w	SolidObject
		btst	#5,obStatus(a0)	; is Sonic pushing against the wall?
		bne.s	.bothcharacters	; if yes, branch

.donothing:
		rts
; ---------------------------------------------------------------------------

.bothcharacters:
		lea	(v_player).w,a1
		bsr.s	.chkroll
		lea	(v_player2).w,a1

.chkroll:
		cmpi.b	#2,obAnim(a1)	; is Sonic rolling?
		bne.s	.donothing	; if not, branch
		move.w	smash_speed(a0),d0
		bpl.s	.chkspeed
		neg.w	d0

.chkspeed:
		cmpi.w	#$480,d0	; is Sonic's speed $480 or higher?
		bcs.s	.donothing	; if not, branch
		move.w	smash_speed(a0),obVelX(a1)
		addq.w	#4,obX(a1)
		lea	Obj3C_FragSpdRight(pc),a4 ; use fragments that move right
		move.w	obX(a0),d0
		cmp.w	obX(a1),d0	; is Sonic to the right of the block?
		bcs.s	.smash		; if yes, branch
		subq.w	#8,obX(a1)
		lea	Obj3C_FragSpdLeft(pc),a4 ; use fragments that move left

.smash:
		move.w	obVelX(a1),obInertia(a1)
		bclr	#5,obStatus(a0)
		bclr	#5,obStatus(a1)
		moveq	#7,d1		; load 8 fragments
		move.w	#$70,d2
		bsr.s	SmashObject

Smash_FragMove:	; Routine 4
		addq.l	#4,sp
		bsr.w	ObjectMove
		addi.w	#$70,obVelY(a0) ; make fragment fall faster
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bra.w	DisplaySprite