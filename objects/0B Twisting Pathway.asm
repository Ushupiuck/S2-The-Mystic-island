;----------------------------------------------------
; Object 0B - EHZ spiral and FBZ/MTZ rotating wire cage
;----------------------------------------------------

; Subtype bit 7 selects the FBZ/MTZ cage; bits 0-6 give half-width / 8.
; Zero width selects the original MTZ 192 pixels. Clear bit 7 = EHZ spiral.
cage_phase_p1	= objoff_2E
cage_phase_p2	= objoff_2F
cage_cooldown_p1	= objoff_30
cage_cooldown_p2	= objoff_31
cage_half_width	= objoff_32

TwistingPathway:
		move.w	obSubtype(a0),d0
		btst	#7,d0
		bne.w	TwistingPathway_CageInit
		move.l	#TwistingPathway_Main,code(a0)
		move.b	#$D0,obActWid(a0)
		bra.s	TwistingPathway_Main
.return:	rts

TwistingPathway_Main:
		lea	(v_player).w,a1
		moveq	#3,d6
		bsr.w	sub_149BC
		lea	(v_player2).w,a1
		moveq	#4,d6
		bsr.w	sub_149BC
		bra.w	MarkObjGone2

; =============== S U B	R O U T	I N E =======================================


sub_149BC:
		btst	d6,obStatus(a0)
		bne.w	loc_14A56
		btst	#1,obStatus(a1)
		bne.w	locret_14A54
		btst	#3,obStatus(a1)
		bne.s	loc_14A16
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		tst.w	obVelX(a1)
		bmi.s	loc_149F2
		cmpi.w	#-$C0,d0
		bgt.s	TwistingPathway.return
		cmpi.w	#-$D0,d0
		blt.s	TwistingPathway.return
		move.w	obY(a1),d1
		sub.w	obY(a0),d1
		subi.w	#$10,d1
		cmpi.w	#$30,d1
		bcc.s	locret_14A54
		bra.w	RideObject_SetRide
; ---------------------------------------------------------------------------

loc_149F2:
		cmpi.w	#$C0,d0
		blt.s	locret_14A54
		cmpi.w	#$D0,d0
		bgt.s	locret_14A54
		move.w	obY(a1),d1
		sub.w	obY(a0),d1
		subi.w	#$10,d1
		cmpi.w	#$30,d1
		bcc.s	locret_14A54
		bra.w	RideObject_SetRide
; ---------------------------------------------------------------------------

loc_14A16:
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		tst.w	obVelX(a1)
		bmi.s	loc_14A32
		cmpi.w	#-$B0,d0
		bgt.s	locret_14A54
		cmpi.w	#-$C0,d0
		blt.s	locret_14A54
		move.w	obY(a1),d1
		sub.w	obY(a0),d1
		subi.w	#$10,d1
		cmpi.w	#$30,d1
		bcc.s	locret_14A54
		bra.w	RideObject_SetRide
; ---------------------------------------------------------------------------

loc_14A32:
		cmpi.w	#$B0,d0
		blt.s	locret_14A54
		cmpi.w	#$C0,d0
		bgt.s	locret_14A54
		move.w	obY(a1),d1
		sub.w	obY(a0),d1
		subi.w	#$10,d1
		cmpi.w	#$30,d1
		bcc.s	locret_14A54
		bra.w	RideObject_SetRide

locret_14A54:
		rts
; ---------------------------------------------------------------------------

loc_14A56:
		move.w	obInertia(a1),d0
		bpl.s	loc_14A5E
		neg.w	d0

loc_14A5E:
		cmpi.w	#$600,d0
		bcs.s	loc_14A80
		btst	#1,obStatus(a1)
		bne.s	loc_14A80
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		addi.w	#$D0,d0
		bmi.s	loc_14A80
		cmpi.w	#$1A0,d0
		bcs.s	loc_14A98

loc_14A80:
		bclr	#3,obStatus(a1)
		bclr	d6,obStatus(a0)
		clr.b	objoff_30(a1)
		move.b	#4,objoff_31(a1)
		rts
; ---------------------------------------------------------------------------

loc_14A98:
		btst	#3,obStatus(a1)
		beq.s	locret_14A54
		move.b	TwistingPathway_PlayerDeltaYArray(pc,d0.w),d1
		ext.w	d1
		move.w	obY(a0),d2
		add.w	d1,d2
		moveq	#0,d1
		move.b	obHeight(a1),d1
		subi.w	#$13,d1
		sub.w	d1,d2
		move.w	d2,obY(a1)
		lsr.w	#3,d0
		andi.w	#$3F,d0
		move.b	TwistingPathway_PlayerAngleArray(pc,d0.w),objoff_27(a1)
		rts
; End of function sub_149BC
; ---------------------------------------------------------------------------
TwistingPathway_PlayerAngleArray:dc.b   0,  0,  1,  1		; 0
		dc.b $16,$16,$16,$16			; 4
		dc.b $2C,$2C,$2C,$2C			; 8
		dc.b $42,$42,$42,$42			; 12
		dc.b $58,$58,$58,$58			; 16
		dc.b $6E,$6E,$6E,$6E			; 20
		dc.b $84,$84,$84,$84			; 24
		dc.b $9A,$9A,$9A,$9A			; 28
		dc.b $B0,$B0,$B0,$B0			; 32
		dc.b $C6,$C6,$C6,$C6			; 36
		dc.b $DC,$DC,$DC,$DC			; 40
		dc.b $F2,$F2,$F2,$F2			; 44
		dc.b   1,  1,  0,  0			; 48
		even

TwistingPathway_PlayerDeltaYArray:dc.b  $20, $20,	$20, $20, $20, $20, $20, $20, $20, $20,	$20, $20, $20, $20, $20, $20
		dc.b  $20, $20,	$20, $20, $20, $20, $20, $20, $20, $20,	$20, $20, $20, $20, $1F, $1F ; 16
		dc.b  $1F, $1F,	$1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F,	$1F, $1F, $1F, $1E, $1E, $1E ; 32
		dc.b  $1E, $1E,	$1E, $1E, $1E, $1E, $1D, $1D, $1D, $1D,	$1D, $1C, $1C, $1C, $1C, $1B ; 48
		dc.b  $1B, $1B,	$1B, $1A, $1A, $1A, $19, $19, $19, $18,	$18, $18, $17, $17, $16, $16 ; 64
		dc.b  $15, $15,	$14, $14, $13, $12, $12, $11, $10, $10,	 $F,  $E,  $E,	$D,  $C,  $C ; 80
		dc.b   $B,  $A,	 $A,   9,   8,	 8,   7,   6,	6,   5,	  4,   4,   3,	 2,   2,   1 ; 96
		dc.b	0,  -1,	 -2,  -2,  -3,	-4,  -4,  -5,  -6,  -7,	 -7,  -8,  -9,	-9, -$A, -$A ; 112
		dc.b  -$B, -$B,	-$C, -$C, -$D, -$E, -$E, -$F, -$F,-$10,-$10,-$11,-$11,-$12,-$12,-$13 ; 128
		dc.b -$13,-$13,-$14,-$15,-$15,-$16,-$16,-$17,-$17,-$18,-$18,-$19,-$19,-$1A,-$1A,-$1B ; 144
		dc.b -$1B,-$1C,-$1C,-$1C,-$1D,-$1D,-$1E,-$1E,-$1E,-$1F,-$1F,-$1F,-$20,-$20,-$20,-$21 ; 160
		dc.b -$21,-$21,-$21,-$22,-$22,-$22,-$23,-$23,-$23,-$23,-$23,-$23,-$23,-$23,-$24,-$24 ; 176
		dc.b -$24,-$24,-$24,-$24,-$24,-$24,-$24,-$25,-$25,-$25,-$25,-$25,-$25,-$25,-$25,-$25 ; 192
		dc.b -$25,-$25,-$25,-$25,-$25,-$25,-$25,-$25,-$25,-$25,-$25,-$25,-$25,-$25,-$25,-$25 ; 208
		dc.b -$25,-$25,-$25,-$25,-$24,-$24,-$24,-$24,-$24,-$24,-$24,-$23,-$23,-$23,-$23,-$23 ; 224
		dc.b -$23,-$23,-$23,-$22,-$22,-$22,-$21,-$21,-$21,-$21,-$20,-$20,-$20,-$1F,-$1F,-$1F ; 240
		dc.b -$1E,-$1E,-$1E,-$1D,-$1D,-$1C,-$1C,-$1C,-$1B,-$1B,-$1A,-$1A,-$19,-$19,-$18,-$18 ; 256
		dc.b -$17,-$17,-$16,-$16,-$15,-$15,-$14,-$13,-$13,-$12,-$12,-$11,-$10,-$10, -$F, -$E ; 272
		dc.b  -$E, -$D,	-$C, -$B, -$B, -$A,  -9,  -8,  -7,  -7,	 -6,  -5,  -4,	-3,  -2,  -1 ; 288
		dc.b	0,   1,	  2,   3,   4,	 5,   6,   7,	8,   8,	  9,  $A,  $A,	$B,  $C,  $D ; 304
		dc.b   $D,  $E,	 $E,  $F,  $F, $10, $10, $11, $11, $12,	$12, $13, $13, $14, $14, $15 ; 320
		dc.b  $15, $16,	$16, $17, $17, $18, $18, $18, $19, $19,	$19, $19, $1A, $1A, $1A, $1A ; 336
		dc.b  $1B, $1B,	$1B, $1B, $1C, $1C, $1C, $1C, $1C, $1C,	$1D, $1D, $1D, $1D, $1D, $1D ; 352
		dc.b  $1D, $1E,	$1E, $1E, $1E, $1E, $1E, $1E, $1F, $1F,	$1F, $1F, $1F, $1F, $1F, $1F ; 368
		dc.b  $1F, $1F,	$20, $20, $20, $20, $20, $20, $20, $20,	$20, $20, $20, $20, $20, $20 ; 384
		dc.b  $20, $20,	$20, $20, $20, $20, $20, $20, $20, $20,	$20, $20, $20, $20, $20, $20 ; 400
		even
; ===========================================================================
; FBZ wire cage's horizontal form, adapted from skdisasm 73de97c6.
; Its width and each rider's phase/cooldown belong to this SST, not global RAM.
; Existing S2 tumble poses handle both characters without new art/DPLC frames.
TwistingPathway_CageInit:
		andi.w	#$7F,d0
		lsl.w	#3,d0
		bne.s	.width
		move.w	#192,d0
.width:
		move.w	d0,cage_half_width(a0)
		move.l	#TwistingPathway_Cage,code(a0)
TwistingPathway_Cage:
		move.w	cage_half_width(a0),d4
		move.w	d4,d5
		add.w	d5,d5
		lea	(v_player).w,a1
		lea	cage_phase_p1(a0),a2
		moveq	#3,d6
		bsr.s	TwistingPathway_CagePlayer
		lea	(v_player2).w,a1
		lea	cage_phase_p2(a0),a2
		moveq	#4,d6
		bsr.s	TwistingPathway_CagePlayer
		bra.w	MarkObjGone2

TwistingPathway_CagePlayer:
		btst	d6,obStatus(a0)
		bne.w	.riding
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d4,d0
		cmp.w	d5,d0
		bhs.w	.return
		; A player crossing the upper side cannot snap to the lower surface.
		move.w	obY(a1),d0
		sub.w	obY(a0),d0
		addi.w	#$50,d0
		cmpi.w	#$18,d0
		bhs.s	.cooldown
		move.b	#$28,2(a2)
.cooldown:
		tst.b	2(a2)
		beq.s	.contact
		subq.b	#1,2(a2)
		rts
.contact:
		cmpi.b	#6,obRoutine(a1)
		bhs.w	.return
		tst.b	obControl(a1)
		bmi.w	.return
		tst.w	(Debug_placement_mode).w
		bne.w	.return
		move.w	obY(a0),d0
		addi.w	#60,d0
		move.w	obY(a1),d2
		moveq	#0,d1
		move.b	obHeight(a1),d1
		add.w	d2,d1
		addq.w	#4,d1
		sub.w	d1,d0
		bhi.w	.return
		cmpi.w	#-$10,d0
		blo.w	.return
		add.w	d0,d2
		addq.w	#3,d2
		move.w	d2,obY(a1)
		jsr	(RideObject_SetRide).l
		move.b	#1,flip_turned(a1)
		move.w	#1,obAnim(a1)
		clr.b	(a2)
		clr.b	2(a2)
		tst.w	obInertia(a1)
		bne.w	.return
		move.w	#1,obInertia(a1)
.return:	rts
.riding:
		btst	#status.player.in_air,obStatus(a1)
		bne.s	.jumped
		btst	#status.player.on_object,obStatus(a1)
		beq.s	.release
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d4,d0
		cmp.w	d5,d0
		blo.s	.orbit
.release:
		bclr	#status.player.on_object,obStatus(a1)
		bclr	d6,obStatus(a0)
		clr.b	flips_remaining(a1)
		move.b	#4,flip_speed(a1)
		bset	#status.player.in_air,obStatus(a1)
		clr.b	flip_turned(a1)
		rts
.jumped:
		move.b	(a2),d0
		addi.b	#$20,d0
		cmpi.b	#$40,d0
		bhs.s	.cancel_jump
		asr.w	obVelY(a1)
		bra.s	.release
.cancel_jump:
		clr.w	obVelY(a1)
		bra.s	.release
.orbit:
		moveq	#0,d0
		move.b	(a2),d0
		lsr.w	#2,d0
		move.b	TwistingPathway_CageY(pc,d0.w),d1
		ext.w	d1
		add.w	obY(a0),d1
		moveq	#0,d2
		move.b	obHeight(a1),d2
		subi.w	#$13,d2
		sub.w	d2,d1
		move.w	d1,obY(a1)
		move.b	(a2),flip_angle(a1)
		addq.b	#4,(a2)
		tst.w	obInertia(a1)
		bne.w	.return
		move.w	#1,obInertia(a1)
		rts

; Exact FBZ cos(angle) * $2800 >> 16 at the 64 reachable phases.
TwistingPathway_CageY:
		dc.b	40,39,39,38,36,35,33,30,28,25,22,18,15,11,7,3
		dc.b	0,-4,-8,-12,-16,-19,-23,-26,-29,-31,-34,-36,-37,-39,-40,-40
		dc.b	-40,-40,-40,-39,-37,-36,-34,-31,-29,-26,-23,-19,-16,-12,-8,-4
		dc.b	0,3,7,11,15,18,22,25,28,30,33,35,36,38,39,39
		even
