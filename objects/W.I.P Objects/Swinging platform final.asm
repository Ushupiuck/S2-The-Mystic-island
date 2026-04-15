;===============================================================================
; Object 0x15 - Swing Platforms - Dust Hill / Oil Ocean
; [ Begin ]
;===============================================================================
Obj_0x15_Swing_Platform: ; loc_85F8:
		btst	#6,obRender(a0)
		bne.w	loc_8610
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	loc_8618(pc,d0),d1
		jmp	loc_8618(pc,d1)
loc_8610:
		move.w	#$200,d0
		bra.w	DisplaySprite3	   ; loc_d3FE
loc_8618:
		dc.w	Swing_Main-loc_8618
		dc.w	Swing_SetSolid-loc_8618
		dc.w	Swing_Display-loc_8618
		dc.w	loc_892E-loc_8618
		dc.w	loc_89E8-loc_8618
		dc.w	loc_89F0-loc_8618
		dc.w	loc_8A56-loc_8618
Swing_Main:
		addq.b	#2,obRoutine(a0)
		move.l	#Obj15_MapUnc_8AD8,obMap(a0) ; loc_8AD8
		move.w	#$43E3,obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#3,obPriority(a0)
		move.b	#$20,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.w	obY(a0),$38(a0)
		move.w	obX(a0),$3A(a0)
		cmpi.b	#dust_hill_zone,(Current_Zone).w
		bne.s	loc_867E
		move.l	#Obj15_MapUnc_8B46,obMap(a0) ; loc_8B46
		move.w	#0,obGfx(a0)
		move.b	#$18,obActWid(a0)
		move.b	#8,obHeight(a0)
loc_867E:
		cmpi.b	#neo_green_hill_zone,(Current_Zone).w
		bne.s	loc_86A0
		move.l	#Obj15_MapUnc_8B0E,obMap(a0) ; loc_8B0E
		move.w	#0,obGfx(a0)
		move.b	#$20,obActWid(a0)
		move.b	#8,obHeight(a0)
loc_86A0:
		moveq	#0,d1
		move.b	$28(a0),d1
		bpl.s	loc_86B0
		addq.b	#4,routine(a0)
loc_86B0:
		andi.w	#$F,d1
		move.w	d1,d2
		lsl.w	#4,d2
		addi.b	#8,d2
		move.b	d2,$3C(a0)
		move.w	obX(a0),d2
		move.w	obY(a0),d3
		bsr.w	SingleObjLoad2		; loc_E788
		bne.s	loc_8738
		_move.b	id(a0),id(a1)
		move.l	obMap(a0),obMap(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.b	#4,obRender(a1)
		bset	#6,obRender(a1)
		move.b	#$48,$E(a1)
		move.b	d1,$F(a1)
		subq.b	#$1,d1
		lea	$10(a1),a2
loc_86FC:
		move.w	d2,(a2)+
		move.w	d3,(a2)+
		move.w	#1,(a2)+
		addi.w	#$10,d3
		dbf	d1,loc_86FC
		move.b	#2,$15(a1)
		move.w	d2,obX(a1)
		move.w	d3,obY(a1)
		move.b	#1,$B(a1)
		move.l	a1,$30(a0)
		addi.w	#8,d3
		move.w	d3,obY(a0)
		move.b	#$50,$14(a1)
		bset	#4,obRender(a1)
loc_8738:
		move.w	#$8000,$26(a0)
		move.w	#0,$3E(a0)
		move.b	$28(a0),d1
		andi.w	#$70,d1
		move.b	d1,$28(a0)
		cmpi.b	#$40,d1
		bne.s	Swing_SetSolid
		move.l	#Obj15_MapUnc_8B7A,obMap(a0) ; loc_8B7A
		move.b	#$A7,$20(a0)
Swing_SetSolid:
		move.w	obX(a0),-(sp)
		bsr.w	loc_8784
		moveq	#0,d1
		move.b	obActWid(a0),d1
		moveq	#0,d3
		move.b	obHeight(a0),d3
		addq.b	#1,d3
		move.w	(sp)+,d4
		bsr.w	loc_FA28
		bra.w	loc_88FC
loc_8784:
		move.b	(Oscillating_Data+$18).w,d0
		move.b	$28(a0),d1
		beq.s	loc_87C4
		cmpi.b	#$10,d1
		bne.s	loc_879E
		cmpi.b	#$40,d0
		bhs.s	loc_87C4
		moveq	#$40,d0
		bra.s	loc_87C4
loc_879E:
		cmpi.b	#$20,d1
		bne.s	loc_87AA
		moveq	#$40,d0
		bra.w	loc_885C
loc_87AA:
		cmpi.b	#$30,d1
		bne.s	loc_87BA
		cmpi.b	#$40,d0
		blo.s	loc_87C4
		moveq	#$40,d0
		bra.s	loc_87C4
loc_87BA:
		cmpi.b	#$40,d1
		bne.s	loc_87C4
		bsr.w	loc_885E
loc_87C4:
		move.w	#$80,d1
		btst	#0,$22(a0)
		beq.s	loc_87d4
		neg.w	d0
		add.w	d1,d0
loc_87d4:
		bsr.w	CalcSine		; loc_320A
		move.w	$38(a0),d2
		move.w	$3A(a0),d3
		moveq	#0,d4
		move.b	$3C(a0),d4
		move.l	d4,d5
		muls.w	d0,d4
		asr.l	#8,d4
		muls.w	d1,d5
		asr.l	#8,d5
		add.w	d2,d4
		add.w	d3,d5
		move.w	d4,y_pos(a0)
		move.w	d5,obX(a0)
		moveq	#0,d6
		move.l	$30(a0),a1
		move.b	$F(a1),d6
		subq.w	#1,d6
		blo.s	loc_885C
		asl.w	#4,d0
		ext.l	d0
		asl.l	#8,d0
		asl.w	#4,d1
		ext.l	d1
		asl.l	#8,d1
		moveq	#0,d4
		moveq	#0,d5
		lea	$10(a1),a2
loc_881E:
		movem.l d4-d5,-(sp)
		swap	d4
		swap	d5
		add.w	d2,d4
		add.w	d3,d5
		move.w	d5,(a2)+
		move.w	d4,(a2)+
		movem.l (sp)+,d4-d5
		add.l	d0,d4
		add.l	d1,d5
		addq.w	#2,a2
		dbf	d6,loc_881E
		swap	d4
		swap	d5
		add.w	d2,d4
		add.w	d3,d5
		move.w	$28(a1),d0
		move.w	$2A(a1),d1
		move.w	d5,$28(a1)
		move.w	d4,$2A(a1)
		move.w	d0,obX(a1)
		move.w	d1,obY(a1)
loc_885C:
		rts
loc_885E:
		tst.w	$36(a0)
		beq.s	loc_886C
		subq.w	#1,$36(a0)
		bra.w	loc_88F6
loc_886C:
		tst.b	$34(a0)
		bne.s	loc_8892
		move.w	(MainCharacter+8).w,d0
		sub.w	$3A(a0),d0
		addi.w	#$20,d0
		cmpi.w	#$40,d0
		bhs.s	loc_88F6
		tst.w	(Debug_placement_mode).w
		bne.w	loc_88F6
		move.b	#1,$34(a0)
loc_8892:
		tst.b	$3D(a0)
		beq.s	loc_88C8
		move.w	$3E(a0),d0
		addi.w	#8,d0
		move.w	d0,$3E(a0)
		add.w	d0,$26(a0)
		cmpi.w	#$200,d0
		bne.s	loc_88F6
		clr.w	$3E(a0)
		move.w	#$8000,$26(a0)
		clr.b	$3D(a0)
		move.w	#$3C,$36(a0)
		bra.s	loc_88F6
loc_88C8:
		move.w	$3E(a0),d0
		subi.w	#8,d0
		move.w	d0,$3E(a0)
		add.w	d0,$26(a0)
		cmpi.w	#-$200,d0
		bne.s	loc_88F6
		move.w	#0,$3E(a0)
		move.w	#$4000,$26(a0)
		move.b	#1,$3D(a0)
		move.w	#$3C,$36(a0)
loc_88F6:
		move.b	$26(a0),d0
		rts
loc_88FC:
		move.w	$3A(a0),d0
		andi.w	#$FF80,d0
		sub.w	(Camera_X_pos_coarse).w,d0
		cmpi.w	#$280,d0
		bhi.w	loc_891E
		bra.w	DisplaySprite			; loc_d3C2
loc_891E:
		move.l	$30(a0),a1
		bsr.w	DeleteObject2
		bra.w	DeleteObject			; loc_d3B4
Swing_Display:
		bra.w	DisplaySprite			; loc_d3C2
loc_892E:
		move.w	obX(a0),-(sp)
		bsr.w	loc_8784
		moveq	#0,d1
		move.b	obActWid(a0),d1
		moveq	#0,d3
		move.b	obHeight(a0),d3
		addq.b	#1,d3
		move.w	(sp)+,d4
		bsr.w	loc_FA28
		move.b	$22(a0),d0
		andi.b	#$18,d0
		beq.w	loc_89E4
		tst.b	(Oscillating_Data+$18).w
		bne.w	loc_89E4
		bsr.w	SingleObjLoad2		; loc_E788
		bne.s	loc_89d4
		moveq	#0,d0
		move.w	#$F,d1
loc_896A:
		move.l	(a0,d0),(a1,d0)
		addq.w	#4,d0
		dbf	d1,loc_896A
		move.b	#$A,obRoutine(a1)
		cmpi.b	#neo_green_hill_zone,(Current_Zone).w
		bne.s	loc_8988
		addq.b	#2,obRoutine(a1)
loc_8988:
		move.w	#$200,$10(a1)
		btst	#0,$22(a0)
		beq.s	loc_899A
		neg.w	$10(a1)
loc_899A:
		bset	#1,$22(a1)
		move.w	a0,d0
		subi.w	#MainCharacter,d0
		lsr.w	#6,d0
		andi.w	#$7F,d0
		move.w	a1,d1
		subi.w	#MainCharacter,d1
		lsr.w	#6,d1
		andi.w	#$7F,d1
		lea	(MainCharacter).w,a1
		cmp.b	$3D(a1),d0
		bne.s	loc_89C6
		move.b	d1,$3D(a1)
loc_89C6:
		lea	(Sidekick).w,a1
		cmp.b	$3D(a1),d0
		bne.s	loc_89d4
		move.b	d1,$3D(a1)
loc_89d4:
		move.b	#3,$1A(a0)
		addq.b	#2,obRoutine(a0)
		andi.b	#$E7,$22(a0)
loc_89E4:
		bra.w	loc_88FC
loc_89E8:
		bsr.w	loc_8784
		bra.w	loc_88FC
loc_89F0:
		move.w	obX(a0),-(sp)
		btst	#1,$22(a0)
		beq.s	loc_8A2E
		bsr.w	ObjectMove				; loc_d27A
		addi.w	#$18,$12(a0)
		cmpi.w	#$720,obY(a0)
		blo.s	loc_8A3E
		move.w	#$720,obY(a0)
		bclr	#1,$22(a0)
		clr.w	$10(a0)
		clr.w	$12(a0)
		move.w	obY(a0),$38(a0)
		bra.s	loc_8A3E
loc_8A2E:
		moveq	#0,d0
		move.b	(Oscillating_Data+$14).w,d0
		lsr.w	#1,d0
		add.w	$38(a0),d0
		move.w	d0,obY(a0)
loc_8A3E:
		moveq	#0,d1
		move.b	obActWid(a0),d1
		moveq	#0,d3
		move.b	obHeight(a0),d3
		addq.b	#1,d3
		move.w	(sp)+,d4
		bsr.w	loc_FA28
		bra.w	MarkObjGone				; loc_d2A0
loc_8A56:
		move.w	8(a0),-(sp)
		bsr.w	ObjectMove				; loc_d27A
		btst	#1,$22(a0)
		beq.s	loc_8A92
		addi.w	#$18,$12(a0)
		move.w	(Water_Level_2).w,d0
		cmp.w	obY(a0),d0
		bhi.s	loc_8AC0
		move.w	d0,obY(a0)
		move.w	d0,$38(a0)
		bclr	#1,$22(a0)
		move.w	#$100,$10(a0)
		clr.w	$12(a0)
		bra.s	loc_8AC0
loc_8A92:
		moveq	#0,d0
		move.b	(Oscillating_Data+$14).w,d0
		lsr.w	#1,d0
		add.w	$38(a0),d0
		move.w	d0,obY(a0)
		tst.w	$10(a0)
		beq.s	loc_8AC0
		moveq	#0,d3
		move.b	obActWid(a0),d3
		bsr.w	ObjHitWallRight
		tst.w	d1
		bpl.s	loc_8AC0
		add.w	d1,obX(a0)
		clr.w	$10(a0)
loc_8AC0:
		moveq	#0,d1
		move.b	obActWid(a0),d1
		moveq	#0,d3
		move.b	obHeight(a0),d3
		addq.b	#1,d3
		move.w	(sp)+,d4
		bsr.w	loc_FA28
		bra.w	MarkObjGone				; loc_d2A0
