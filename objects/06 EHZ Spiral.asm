;----------------------------------------------------
; Object 06 - spiral loop in EHZ
;----------------------------------------------------

Obj06:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj06_Index(pc,d0.w),d1
		jsr	Obj06_Index(pc,d1.w)
		out_of_range.w	DeleteObject
		rts
; ---------------------------------------------------------------------------
Obj06_Index:	dc.w Obj06_Init-Obj06_Index
		dc.w Obj06_Main-Obj06_Index
; ---------------------------------------------------------------------------

Obj06_Init:
		addq.b	#2,obRoutine(a0)
		move.b	#$D0,obActWid(a0)

Obj06_Main:
		lea	(v_player).w,a1
		moveq	#3,d6
		bsr.s	sub_149BC
		lea	(v_player2).w,a1
		addq.b	#1,d6

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
		bgt.s	locret_14A54
		cmpi.w	#-$D0,d0
		blt.s	locret_14A54
		bra.s	loc_149FE
; ---------------------------------------------------------------------------

loc_149F2:
		cmpi.w	#$C0,d0
		blt.s	locret_14A54
		cmpi.w	#$D0,d0
		bgt.s	locret_14A54

loc_149FE:
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
		bra.s	loc_14A3E
; ---------------------------------------------------------------------------

loc_14A32:
		cmpi.w	#$B0,d0
		blt.s	locret_14A54
		cmpi.w	#$C0,d0
		bgt.s	locret_14A54

loc_14A3E:
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
		move.b	#0,objoff_2C(a1)
		move.b	#4,objoff_2D(a1)
		rts
; ---------------------------------------------------------------------------

loc_14A98:
		btst	#3,obStatus(a1)
		beq.s	locret_14A54
		move.b	Obj06_PlayerDeltaYArray(pc,d0.w),d1
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
		move.b	Obj06_PlayerAngleArray(pc,d0.w),objoff_27(a1)
		rts
; End of function sub_149BC
; ---------------------------------------------------------------------------
Obj06_PlayerAngleArray:dc.b   0,  0,  1,  1		; 0
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

Obj06_PlayerDeltaYArray:dc.b  $20, $20,	$20, $20, $20, $20, $20, $20, $20, $20,	$20, $20, $20, $20, $20, $20
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