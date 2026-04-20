; ---------------------------------------------------------------------------
; Object 1D - Bridge
; ---------------------------------------------------------------------------
Bridge_child1		= objoff_30	; pointer to first set of bridge segments
Bridge_child2		= objoff_34	; pointer to second set of bridge segments, if applicable

Bridge:
		btst	#6,obRender(a0)
		bne.s	Bridge_Display
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Bridge_Index(pc,d0.w),d1
		jmp	Bridge_Index(pc,d1.w)
; ---------------------------------------------------------------------------

Bridge_Display:
		move.w	#$200,d0
		bra.w	DisplaySprite3
; ---------------------------------------------------------------------------
Bridge_Index:	dc.w Bridge_Init-Bridge_Index	; 0
		dc.w Bridge_EHZ-Bridge_Index	; 2
		dc.w Bridge_HPZ-Bridge_Index	; 4
; ---------------------------------------------------------------------------

Bridge_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_GHZ_Bridge,obMap(a0)
		move.w	#make_art_tile(ArtTile_GHZ_Bridge,2,0),obGfx(a0)
		cmpi.b	#3,(Current_Zone).w
		bne.s	.notGHZ
		move.l	#Map_EHZ_Bridge,obMap(a0)
		move.w	#make_art_tile(ArtTile_EHZ_Bridge,2,0),obGfx(a0)

.notGHZ:
		cmpi.b	#4,(Current_Zone).w
		bne.s	.notEHZ
		addq.b	#2,obRoutine(a0)
		move.l	#Map_HPZ_Bridge,obMap(a0)
		move.w	#make_art_tile(ArtTile_HPZ_Bridge,3,0),obGfx(a0)

.notEHZ:
		move.b	#4,obRender(a0)
		move.b	#$80,obActWid(a0)
		move.w	obY(a0),d2
		move.w	d2,objoff_3C(a0)
		move.w	obX(a0),d3
		lea	obSubtype(a0),a2
		moveq	#0,d1
		move.b	(a2),d1
		move.w	d1,d0
		lsl.w	#3,d0
		sub.w	d0,d3
		swap	d1
		move.w	#8,d1
		bsr.s	sub_7C76
		move.w	sub6_x_pos(a1),d0
		subq.w	#8,d0
		move.w	d0,obX(a1)
		move.l	a1,Bridge_child1(a0)
		swap	d1
		subq.w	#8,d1
		bls.s	+

		move.w	d1,d4
		bsr.s	sub_7C76
		move.l	a1,Bridge_child2(a0)
		move.w	d4,d0
		add.w	d0,d0
		add.w	d4,d0
		move.w	sub2_x_pos(a1,d0.w),d0
		subq.w	#8,d0
		move.w	d0,obX(a1)
+
		bra.s	Bridge_EHZ

; =============== S U B	R O U T	I N E =======================================


sub_7C76:
		bsr.w	FindNextFreeObj
		bne.s	.return
		_move.b	obID(a0),obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.l	obMap(a0),obMap(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.b	obRender(a0),obRender(a1)
		bset	#6,obRender(a1)
		move.b	#$40,mainspr_width(a1)
		move.b	d1,mainspr_childsprites(a1)
		subq.b	#1,d1
		lea	subspr_data(a1),a2

.loop:		move.w	d3,(a2)+
		move.w	d2,(a2)+
		clr.w	(a2)+
		addi.w	#$10,d3
		dbf	d1,.loop
.return:	rts
; End of function sub_7C76

; ---------------------------------------------------------------------------

Bridge_EHZ:
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		bne.s	+
		tst.b	objoff_3E(a0)
		beq.s	loc_7D0A
		subq.b	#4,objoff_3E(a0)
		bra.s	loc_7D06
+
		andi.b	#$10,d0
		beq.s	++
		move.b	objoff_3F(a0),d0
		sub.b	objoff_3B(a0),d0
		beq.s	++
		bhs.s	+
		addq.b	#1,objoff_3F(a0)
		bra.s	++
; ---------------------------------------------------------------------------
+
		subq.b	#1,objoff_3F(a0)
+
		cmpi.b	#$40,objoff_3E(a0)
		beq.s	loc_7D06
		addq.b	#4,objoff_3E(a0)

loc_7D06:
		bsr.w	Bridge_Depress

loc_7D0A:
		moveq	#0,d1
		move.b	obSubtype(a0),d1
		lsl.w	#3,d1
		move.w	d1,d2
		addq.w	#8,d1
		add.w	d2,d2
		moveq	#8,d3
		move.w	obX(a0),d4
		bsr.w	sub_7DC0

loc_7D22:
		out_of_range.s	loc_7D3E
		rts
; ---------------------------------------------------------------------------

loc_7D3E:
		movea.l	Bridge_child1(a0),a1
		bsr.w	DeleteObject2
		cmpi.b	#8,obSubtype(a0)
		bls.s	+
		movea.l	Bridge_child2(a0),a1
		bsr.w	DeleteObject2
+
		bra.w	DeleteObject
; ---------------------------------------------------------------------------

Bridge_HPZ:
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		bne.s	+
		tst.b	objoff_3E(a0)
		beq.s	loc_7DA0
		subq.b	#4,objoff_3E(a0)
		bra.s	loc_7D9C
; ---------------------------------------------------------------------------
+
		andi.b	#$10,d0
		beq.s	++
		move.b	objoff_3F(a0),d0
		sub.b	objoff_3B(a0),d0
		beq.s	++
		bhs.s	+
		addq.b	#1,objoff_3F(a0)
		bra.s	++
; ---------------------------------------------------------------------------
+
		subq.b	#1,objoff_3F(a0)
+
		cmpi.b	#$40,objoff_3E(a0)
		beq.s	loc_7D9C
		addq.b	#4,objoff_3E(a0)

loc_7D9C:
		bsr.w	Bridge_Depress

loc_7DA0:
		moveq	#0,d1
		move.b	obSubtype(a0),d1
		lsl.w	#3,d1
		move.w	d1,d2
		addq.w	#8,d1
		add.w	d2,d2
		moveq	#8,d3
		move.w	obX(a0),d4
		bsr.w	sub_7DC0
		bsr.w	sub_7E60
		bra.w	loc_7D22

; =============== S U B	R O U T	I N E =======================================


sub_7DC0:
		lea	(v_player2).w,a1
		moveq	#4,d6
		moveq	#$3B,d5
		movem.l	d1-d4,-(sp)
		bsr.s	+
		movem.l	(sp)+,d1-d4
		lea	(v_player).w,a1
		subq.b	#1,d6
		moveq	#$3F,d5
+
		btst	d6,obStatus(a0)
		beq.s	loc_7E3E
		btst	#1,obStatus(a1)
		bne.s	+
		moveq	#0,d0
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	+
		cmp.w	d2,d0
		blo.s	++
+
		bclr	#3,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------
+
		lsr.w	#4,d0
		move.b	d0,(a0,d5.w)
		movea.l	Bridge_child1(a0),a2
		cmpi.w	#8,d0
		blo.s	+
		movea.l	Bridge_child2(a0),a2
		subi.w	#8,d0
+
		add.w	d0,d0
		move.w	d0,d1
		add.w	d0,d0
		add.w	d1,d0
		move.w	sub2_y_pos(a2,d0.w),d0
		subq.w	#8,d0
		moveq	#0,d1
		move.b	obHeight(a1),d1
		sub.w	d1,d0
		move.w	d0,obY(a1)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------

loc_7E3E:
		move.w	d1,-(sp)
		bsr.w	sub_F880
		move.w	(sp)+,d1
		btst	d6,obStatus(a0)
		beq.s	.return
		moveq	#0,d0
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		lsr.w	#4,d0
		move.b	d0,(a0,d5.w)
.return:	rts
; End of function sub_7DDA


; =============== S U B	R O U T	I N E =======================================


sub_7E60:
		moveq	#0,d0
		tst.w	(v_player+obVelX).w
		bne.s	+
		move.b	(Vint_runcount+3).w,d0
		andi.w	#$1C,d0
		lsr.w	#1,d0
+
		moveq	#0,d2
		move.b	byte_7E9E+1(pc,d0.w),d2
		swap	d2
		move.b	byte_7E9E(pc,d0.w),d2
		moveq	#0,d0
		tst.w	(v_player2+obVelX).w
		bne.s	+
		move.b	(Vint_runcount+3).w,d0
		andi.w	#$1C,d0
		lsr.w	#1,d0
+
		moveq	#0,d6
		move.b	byte_7E9E+1(pc,d0.w),d6
		swap	d6
		move.b	byte_7E9E(pc,d0.w),d6
		bra.s	loc_7EAE
; ---------------------------------------------------------------------------
byte_7E9E:
		dc.b   1,  2
		dc.b   1,  2	; 2
		dc.b   1,  2	; 4
		dc.b   1,  2	; 6
		dc.b   0,  1	; 8
		dc.b   0,  0	; 10
		dc.b   0,  0	; 12
		dc.b   0,  1	; 14
; ---------------------------------------------------------------------------

loc_7EAE:
		moveq	#-2,d3
		moveq	#-2,d4
		move.b	obStatus(a0),d0
		andi.b	#8,d0
		beq.s	+
		move.b	objoff_3F(a0),d3
+
		move.b	obStatus(a0),d0
		andi.b	#$10,d0
		beq.s	+
		move.b	objoff_3B(a0),d4
+
		movea.l	Bridge_child1(a0),a1
		lea	sub9_mapframe+next_subspr(a1),a2
		lea	sub2_mapframe(a1),a1
		moveq	#0,d1
		move.b	obSubtype(a0),d1
		subq.b	#1,d1
		moveq	#0,d5

-		moveq	#0,d0
		subq.w	#1,d3
		cmp.b	d3,d5
		bne.s	+
		move.w	d2,d0
+
		addq.w	#2,d3
		cmp.b	d3,d5
		bne.s	+
		move.w	d2,d0
+
		subq.w	#1,d3
		subq.w	#1,d4
		cmp.b	d4,d5
		bne.s	+
		move.w	d6,d0
+
		addq.w	#2,d4
		cmp.b	d4,d5
		bne.s	+
		move.w	d6,d0
+
		subq.w	#1,d4
		cmp.b	d3,d5
		bne.s	+
		swap	d2
		move.w	d2,d0
		swap	d2
+
		cmp.b	d4,d5
		bne.s	+
		swap	d6
		move.w	d6,d0
		swap	d6
+
		move.b	d0,(a1)
		addq.w	#1,d5
		addq.w	#6,a1
		cmpa.w	a2,a1
		bne.s	+
		movea.l	Bridge_child2(a0),a1
		lea	sub2_mapframe(a1),a1
+		dbf	d1,-

		rts
; End of function sub_7E60
; ===========================================================================

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||
; subroutine to make the bridge push down where Sonic or Tails walks over
; sub_7F36:
Bridge_Depress:
		move.b	objoff_3E(a0),d0
		bsr.w	CalcSine
		move.w	d0,d4
		lea	(Bridge_BendData2).l,a4
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		lsl.w	#4,d0
		moveq	#0,d3
		move.b	objoff_3F(a0),d3
		move.w	d3,d2
		add.w	d0,d3
		moveq	#0,d5
		lea	(Bridge_BendData).l,a5
		move.b	(a5,d3.w),d5
		andi.w	#$F,d3
		lsl.w	#4,d3
		lea	(a4,d3.w),a3
		movea.l	Bridge_child1(a0),a1
		lea	sub9_y_pos+next_subspr(a1),a2
		lea	sub2_y_pos(a1),a1

-		moveq	#0,d0
		move.b	(a3)+,d0
		addq.w	#1,d0
		mulu.w	d5,d0
		mulu.w	d4,d0
		swap	d0
		add.w	objoff_3C(a0),d0
		move.w	d0,(a1)
		addq.w	#6,a1
		cmpa.w	a2,a1
		bne.s	+
		movea.l	Bridge_child2(a0),a1
		lea	sub2_y_pos(a1),a1
+		dbf	d2,-

		moveq	#0,d0
		move.b	obSubtype(a0),d0
		moveq	#0,d3
		move.b	objoff_3F(a0),d3
		addq.b	#1,d3
		sub.b	d0,d3
		neg.b	d3
		bmi.s	.return
		move.w	d3,d2
		lsl.w	#4,d3
		lea	(a4,d3.w),a3
		adda.w	d2,a3
		subq.w	#1,d2
		bcs.s	.return

-		moveq	#0,d0
		move.b	-(a3),d0
		addq.w	#1,d0
		mulu.w	d5,d0
		mulu.w	d4,d0
		swap	d0
		add.w	objoff_3C(a0),d0
		move.w	d0,(a1)
		addq.w	#6,a1
		cmpa.w	a2,a1
		bne.s	+
		movea.l	Bridge_child2(a0),a1
		lea	sub2_y_pos(a1),a1
+		dbf	d2,-
.return:	rts
; End of function Bridge_Depress

; ---------------------------------------------------------------------------
; seems to be bridge piece vertical position offset data
Bridge_BendData:
		dc.b   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 0 logs
		dc.b   2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 1 log
		dc.b   2,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 2 logs
		dc.b   2,  4,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 3 logs
		dc.b   2,  4,  4,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 4 logs
		dc.b   2,  4,  6,  4,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 5 logs
		dc.b   2,  4,  6,  6,  4,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 6 logs
		dc.b   2,  4,  6,  8,  6,  4,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0; 7 logs
		dc.b   2,  4,  6,  8,  8,  6,  4,  2,  0,  0,  0,  0,  0,  0,  0,  0; 8 logs
		dc.b   2,  4,  6,  8, $A,  8,  6,  4,  2,  0,  0,  0,  0,  0,  0,  0; 9 logs
		dc.b   2,  4,  6,  8, $A, $A,  8,  6,  4,  2,  0,  0,  0,  0,  0,  0; 10 logs
		dc.b   2,  4,  6,  8, $A, $C, $A,  8,  6,  4,  2,  0,  0,  0,  0,  0; 11 logs
		dc.b   2,  4,  6,  8, $A, $C, $C, $A,  8,  6,  4,  2,  0,  0,  0,  0; 12 logs
		dc.b   2,  4,  6,  8, $A, $C, $E, $C, $A,  8,  6,  4,  2,  0,  0,  0; 13 logs
		dc.b   2,  4,  6,  8, $A, $C, $E, $E, $C, $A,  8,  6,  4,  2,  0,  0; 14 logs
		dc.b   2,  4,  6,  8, $A, $C, $E,$10, $E, $C, $A,  8,  6,  4,  2,  0; 15 logs
		dc.b   2,  4,  6,  8, $A, $C, $E,$10,$10, $E, $C, $A,  8,  6,  4,  2; 16 logs
; something else important for bridge depression to work (phase? bridge size adjustment?)
Bridge_BendData2:
		dc.b $FF,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 16
		dc.b $B5,$FF,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 32
		dc.b $7E,$DB,$FF,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 48
		dc.b $61,$B5,$EC,$FF,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 64
		dc.b $4A,$93,$CD,$F3,$FF,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 80
		dc.b $3E,$7E,$B0,$DB,$F6,$FF,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0; 96
		dc.b $38,$6D,$9D,$C5,$E4,$F8,$FF,  0,  0,  0,  0,  0,  0,  0,  0,  0; 112
		dc.b $31,$61,$8E,$B5,$D4,$EC,$FB,$FF,  0,  0,  0,  0,  0,  0,  0,  0; 128
		dc.b $2B,$56,$7E,$A2,$C1,$DB,$EE,$FB,$FF,  0,  0,  0,  0,  0,  0,  0; 144
		dc.b $25,$4A,$73,$93,$B0,$CD,$E1,$F3,$FC,$FF,  0,  0,  0,  0,  0,  0; 160
		dc.b $1F,$44,$67,$88,$A7,$BD,$D4,$E7,$F4,$FD,$FF,  0,  0,  0,  0,  0; 176
		dc.b $1F,$3E,$5C,$7E,$98,$B0,$C9,$DB,$EA,$F6,$FD,$FF,  0,  0,  0,  0; 192
		dc.b $19,$38,$56,$73,$8E,$A7,$BD,$D1,$E1,$EE,$F8,$FE,$FF,  0,  0,  0; 208
		dc.b $19,$38,$50,$6D,$83,$9D,$B0,$C5,$D8,$E4,$F1,$F8,$FE,$FF,  0,  0; 224
		dc.b $19,$31,$4A,$67,$7E,$93,$A7,$BD,$CD,$DB,$E7,$F3,$F9,$FE,$FF,  0; 240
		dc.b $19,$31,$4A,$61,$78,$8E,$A2,$B5,$C5,$D4,$E1,$EC,$F4,$FB,$FE,$FF; 256
		even