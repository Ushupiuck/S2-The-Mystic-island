;----------------------------------------------------
; Object 4C - Bat badnik from HPZ
;----------------------------------------------------

Obj4C:
		moveq	#0,d0
		move.b	routine(a0),d0
		move.w	Obj4C_Index(pc,d0.w),d1
		jmp	Obj4C_Index(pc,d1.w)
; ===========================================================================
Obj4C_Index:	dc.w Obj4C_Init-Obj4C_Index
		dc.w loc_16DA2-Obj4C_Index
		dc.w loc_16E10-Obj4C_Index
; ===========================================================================

Obj4C_Init:
		move.l	#Map_Obj4C,mappings(a0)
		move.w	#$2530,art_tile(a0)
		ori.b	#4,render_flags(a0)
		move.b	#$A,collision_flags(a0)
		move.b	#4,priority(a0)
		move.b	#$10,width_pixels(a0)
		move.b	#$10,y_radius(a0)
		move.b	#8,x_radius(a0)
		addq.b	#2,routine(a0)
		move.w	y_pos(a0),objoff_2E(a0)
		rts
; ===========================================================================

loc_16DA2:
		moveq	#0,d0
		move.b	routine_secondary(a0),d0
		move.w	Obj4C_SubIndex(pc,d0.w),d1
		jsr	Obj4C_SubIndex(pc,d1.w)
;		bsr.w	sub_16DC8
		move.b	objoff_3F(a0),d0
		jsr	(CalcSine).l
		asr.w	#6,d0
		add.w	objoff_2E(a0),d0
		move.w	d0,y_pos(a0)
		addq.b	#4,objoff_3F(a0)
		lea	(Ani_Obj4C).l,a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ===========================================================================
Obj4C_SubIndex:	dc.w loc_16F2E-Obj4C_SubIndex
		dc.w loc_16F66-Obj4C_SubIndex
		dc.w loc_16F72-Obj4C_SubIndex
; ===========================================================================

loc_16E10:
;		bsr.w	sub_16F0E
		move.b	objoff_3F(a0),d0
		jsr	(CalcSine).l
		muls.w	inertia(a0),d1
		asr.l	#8,d1
		move.w	d1,x_vel(a0)
		muls.w	inertia(a0),d0
		asr.l	#8,d0
		move.w	d0,y_vel(a0)
		bsr.w	sub_16EB0
		bsr.w	sub_16E30
		jsr	ObjectMove
		lea	(Ani_Obj4C).l,a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ===========================================================================

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


sub_16E30:
		tst.b	interact(a0)
		beq.s	+
		bset	#0,render_flags(a0)
		bset	#0,status(a0)
+		rts
; End of function sub_16E30


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


sub_16E44:
		subi.w	#1,objoff_2C(a0)
		bpl.s	+
		move.w	x_pos(a0),d0
		sub.w	(v_player+x_pos).w,d0
		cmpi.w	#$60,d0
		bgt.s	loc_16E90
		cmpi.w	#$FFA0,d0
		blt.s	loc_16E90
		tst.w	d0
		bpl.s	loc_16E68
		st	interact(a0)

loc_16E68:
		move.b	#$40,objoff_3F(a0)
		move.w	#$400,inertia(a0)
		move.b	#4,routine(a0)
		move.b	#3,anim(a0)
		move.w	#$C,objoff_2A(a0)
		move.b	#1,objoff_3E(a0)
		moveq	#0,d0
/		rts
; ===========================================================================

loc_16E90:
		cmpi.w	#$80,d0
		bgt.s	loc_16E9C
		cmpi.w	#$FF80,d0
		bgt.s	-

loc_16E9C:
		move.b	#1,anim(a0)
		move.b	#0,routine_secondary(a0)
		move.w	#$18,objoff_2A(a0)
		rts
; End of function sub_16E44


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


sub_16EB0:
		tst.b	interact(a0)
		bne.s	loc_16ECA
		moveq	#0,d0
		move.b	objoff_3F(a0),d0
		cmpi.w	#$C0,d0
		bge.s	loc_16EDE
		addq.b	#2,d0
		move.b	d0,objoff_3F(a0)
		rts
; ===========================================================================

loc_16ECA:
		moveq	#0,d0
		move.b	objoff_3F(a0),d0
		cmpi.w	#$C0,d0
		beq.s	loc_16EDE
		subq.b	#2,d0
		move.b	d0,objoff_3F(a0)
		rts
; ===========================================================================

loc_16EDE:
		sf	interact(a0)
		move.b	#0,anim(a0)
		move.b	#2,routine(a0)
		move.b	#0,routine_secondary(a0)
		move.w	#$18,objoff_2A(a0)
		move.b	#1,anim(a0)
		bclr	#0,render_flags(a0)
		bclr	#0,status(a0)
		rts
; End of function sub_16EB0


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

loc_16F2E:
		subi.w	#1,objoff_2A(a0)
		bpl.s	+
;		bsr.w	sub_16DE2
		move.w	x_pos(a0),d0
		sub.w	(v_player+x_pos).w,d0
		cmpi.w	#$80,d0
		bgt.s	+
		cmpi.w	#$FF80,d0
		blt.s	+
		move.b	#4,routine_secondary(a0)
		move.b	#2,anim(a0)
		move.w	#8,objoff_2A(a0)
		move.b	#0,objoff_3E(a0)
		beq.s	+
		jsr	(PseudoRandomNumber).l
		andi.b	#$FF,d0
		bne.s	+
		move.w	#$18,objoff_2A(a0)
		move.w	#$1E,objoff_2C(a0)
		addq.b	#2,routine_secondary(a0)
		move.b	#1,anim(a0)
		move.b	#0,objoff_3E(a0)
+		rts
; ===========================================================================

loc_16F66:
		subq.b	#1,objoff_2A(a0)
		bpl.s	+
		subq.b	#2,routine_secondary(a0)
/		rts
; ===========================================================================

loc_16F72:
		bsr.w	sub_16E44
		beq.s	-
		subi.w	#1,objoff_2A(a0)
		bne.s	-
		move.b	objoff_3E(a0),d0
		beq.s	loc_16FA0
		move.b	#0,objoff_3E(a0)
		move.w	#8,objoff_2A(a0)
		bset	#0,render_flags(a0)
		bset	#0,status(a0)
		rts
; ===========================================================================

loc_16FA0:
		move.b	#1,objoff_3E(a0)
		move.w	#$C,objoff_2A(a0)
		bclr	#0,render_flags(a0)
		bclr	#0,status(a0)
		rts
; ===========================================================================
Ani_Obj4C:	dc.w byte_16FC2-Ani_Obj4C
		dc.w byte_16FC6-Ani_Obj4C
		dc.w byte_16FD5-Ani_Obj4C
		dc.w byte_16FE6-Ani_Obj4C
byte_16FC2:	dc.b   1,  0,  5,$FF	; 0
byte_16FC6:	dc.b   1,  1,  6,  1,  6,  2,  7,  2,  7,  1,  6,  1,  6,$FD,  0; 0
byte_16FD5:	dc.b   1,  1,  6,  1,  6,  2,  7,  3,  8,  4,  9,  4,  9,  3,  8,$FE; 0
		dc.b  $A		; 16
byte_16FE6:	dc.b   3, $A, $B, $C, $D, $E,$FF,  0; 0
Map_Obj4C:	dc.w word_1700C-Map_Obj4C
		dc.w word_1702E-Map_Obj4C
		dc.w word_17050-Map_Obj4C
		dc.w word_17072-Map_Obj4C
		dc.w word_17094-Map_Obj4C
		dc.w word_170AE-Map_Obj4C
		dc.w word_170D0-Map_Obj4C
		dc.w word_170F2-Map_Obj4C
		dc.w word_17114-Map_Obj4C
		dc.w word_17136-Map_Obj4C
		dc.w word_17150-Map_Obj4C
		dc.w word_1716A-Map_Obj4C
		dc.w word_17184-Map_Obj4C
		dc.w word_17196-Map_Obj4C
		dc.w word_171A8-Map_Obj4C
word_1700C:	dc.w 4
		dc.w $F005,    0,    0,$FFF8; 0
		dc.w	 5,    4,    2,$FFF8; 4
		dc.w $F00B,    8,    4,	   5; 8
		dc.w $F00B, $808, $804,$FFE3; 12
word_1702E:	dc.w 4
		dc.w $F005,    0,    0,$FFF8; 0
		dc.w	 5,    4,    2,$FFF8; 4
		dc.w $F60D,  $14,   $A,	   5; 8
		dc.w $F60D, $814, $80A,$FFDB; 12
word_17050:	dc.w 4
		dc.w $F005,    0,    0,$FFF8; 0
		dc.w	 5,    4,    2,$FFF8; 4
		dc.w $F80D,  $1C,   $E,	   4; 8
		dc.w $F80D, $81C, $80E,$FFDC; 12
word_17072:	dc.w 4
		dc.w $F005,    0,    0,$FFF8; 0
		dc.w	 5,    4,    2,$FFF8; 4
		dc.w $F805,  $24,  $12,$FFEC; 8
		dc.w $F805,  $28,  $14,	   4; 12
word_17094:	dc.w 3
		dc.w $F801,  $2C,  $16,	   0; 0
		dc.w $F005,    0,    0,$FFF8; 4
		dc.w	 5,    4,    2,$FFF8; 8
word_170AE:	dc.w 4
		dc.w $F005,    0,    0,$FFF8; 0
		dc.w	 5,  $2E,  $17,$FFF8; 4
		dc.w $F00B,    8,    4,	   5; 8
		dc.w $F00B, $808, $804,$FFE3; 12
word_170D0:	dc.w 4
		dc.w $F005,    0,    0,$FFF8; 0
		dc.w	 5,  $2E,  $17,$FFF8; 4
		dc.w $F60D,  $14,   $A,	   5; 8
		dc.w $F60D, $814, $80A,$FFDB; 12
word_170F2:	dc.w 4
		dc.w $F005,    0,    0,$FFF8; 0
		dc.w	 5,  $2E,  $17,$FFF8; 4
		dc.w $F80D,  $1C,   $E,	   4; 8
		dc.w $F80D, $81C, $80E,$FFDC; 12
word_17114:	dc.w 4
		dc.w $F005,    0,    0,$FFF8; 0
		dc.w	 5,  $2E,  $17,$FFF8; 4
		dc.w $F805,  $28,  $14,	   4; 8
		dc.w $F805,  $24,  $12,$FFEC; 12
word_17136:	dc.w 3
		dc.w $F801,  $2C,  $16,	   0; 0
		dc.w $F005,    0,    0,$FFF8; 4
		dc.w	 5,  $2E,  $17,$FFF8; 8
word_17150:	dc.w 3
		dc.w $F007,  $32,  $19,$FFF8; 0
		dc.w $F80D,  $1C,   $E,	   4; 4
		dc.w $F80D, $81C, $80E,$FFDC; 8
word_1716A:	dc.w 3
		dc.w $F007,  $32,  $19,$FFF8; 0
		dc.w $F805,  $28,  $14,	   4; 4
		dc.w $F805,  $24,  $12,$FFEC; 8
word_17184:	dc.w 2
		dc.w $F801,  $2C,  $16,	   0; 0
		dc.w $F007,  $32,  $19,$FFF8; 4
word_17196:	dc.w 2
		dc.w $F801, $82C, $816,$FFF8; 0
		dc.w $F007,  $32,  $19,$FFF8; 4
word_171A8:	dc.w 3
		dc.w $F007,  $32,  $19,$FFF8; 0
		dc.w $F805, $828, $814,$FFEC; 4
		dc.w $F805, $824, $812,	   4; 8
		even