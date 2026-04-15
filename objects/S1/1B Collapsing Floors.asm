; ---------------------------------------------------------------------------

Obj1B:		; leftover object from Sonic 1
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj1B_Index(pc,d0.w),d1
		jmp	Obj1B_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj1B_Index:
		dc.w loc_8D6A-Obj1B_Index
		dc.w loc_8DB4-Obj1B_Index
		dc.w loc_8DEA-Obj1B_Index
; ---------------------------------------------------------------------------

loc_8D6A:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj1B,obMap(a0)
		move.w	#make_art_tile($2B8,2,0),obGfx(a0)	; we default to marble zone
		cmpi.b	#id_SLZ,(Current_Zone).w
		bne.s	loc_8D8E
		move.w	#make_art_tile($4E0,2,0),obGfx(a0)	; unless we're in Star light
		addq.b	#2,obFrame(a0)

loc_8D8E:
		cmpi.b	#id_SBZ,(Current_Zone).w
		bne.s	loc_8D9C
		move.w	#make_art_tile($3F5,2,0),obGfx(a0)	; or scrap brain

loc_8D9C:
		ori.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#7,objoff_38(a0)
		move.b	#$44,obActWid(a0)

loc_8DB4:
		tst.b	objoff_3A(a0)
		beq.s	loc_8DC6
		tst.b	objoff_38(a0)
		beq.w	loc_8E3E
		subq.b	#1,objoff_38(a0)

loc_8DC6:
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		beq.s	sub_8DD6
		move.b	#1,objoff_3A(a0)

; =============== S U B	R O U T	I N E =======================================


sub_8DD6:
		move.w	#$20,d1
		move.w	#8,d3
		move.w	obX(a0),d4
		bsr.w	PlatformObject
		bra.w	MarkObjGone
; End of function sub_8DD6

; ---------------------------------------------------------------------------

loc_8DEA:
		tst.b	objoff_38(a0)
		beq.s	loc_8E2E
		tst.b	objoff_3A(a0)
		bne.s	loc_8DFE
		subq.b	#1,objoff_38(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

loc_8DFE:
		bsr.w	sub_8DD6
		subq.b	#1,objoff_38(a0)
		bne.s	sub_8E12.return
		lea	(v_player).w,a1
		bsr.s	sub_8E12
		lea	(v_player2).w,a1

; =============== S U B	R O U T	I N E =======================================


sub_8E12:
		btst	#3,obStatus(a1)
		beq.s	.return
		bclr	#3,obStatus(a1)
		bclr	#5,obStatus(a1)
		move.b	#1,obPrevAni(a1)
.return:	rts
; End of function sub_8E12

; ---------------------------------------------------------------------------

loc_8E2E:
		bsr.w	ObjectMoveAndFall
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

loc_8E3E:
		lea	byte_8F17(pc),a4
		btst	#0,obSubtype(a0)
		beq.s	loc_8E52
		lea	byte_8F1F(pc),a4

loc_8E52:
		addq.b	#1,obFrame(a0)
		bra.w	loc_8E70