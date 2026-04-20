; ---------------------------------------------------------------------------
; Object 3E - prison capsule
;----------------------------------------------------------------------------
pri_origY		= objoff_30	; original y-axis position
animal_release_signal	= objoff_32

PrisonCapsule:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Pri_Index(pc,d0.w),d1
		jsr	Pri_Index(pc,d1.w)
		out_of_range.w	Pri_EndAct.delete
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------
Pri_Index:	dc.w Pri_Init-Pri_Index
		dc.w Pri_BodyMain-Pri_Index
		dc.w Pri_Switched-Pri_Index
		dc.w Pri_Explosion-Pri_Index
		dc.w Pri_Explosion-Pri_Index
		dc.w Pri_Explosion-Pri_Index
		dc.w Pri_Animals-Pri_Index
		dc.w Pri_EndAct-Pri_Index
		; routine, width, priority, frame
Pri_Var:
		dc.b   2,$20,  4,  0
		dc.b   4, $C,  5,  1
		dc.b   6,$10,  4,  3
		dc.b   8,$10,  3,  5
; ---------------------------------------------------------------------------

Pri_Init:
		move.l	#Map_Obj3E,obMap(a0)
		move.w	#make_art_tile(ArtTile_Prison_Capsule,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	obY(a0),pri_origY(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		add.w	d0,d0
		add.w	d0,d0
		lea	Pri_Var(pc,d0.w),a1
		move.b	(a1)+,obRoutine(a0)
		move.b	(a1)+,obActWid(a0)
		move.b	(a1)+,obPriority(a0)
		move.w	obPriority(a0),d0
		lsr.w	#1,d0
		andi.w	#$380,d0
		move.w	d0,obPriority(a0)
		move.b	(a1)+,obFrame(a0)
		cmpi.w	#8,d0			; is object type number 02?
		bne.s	.return			; if not, quit
		move.b	#6,obColType(a0)
		move.b	#8,obColProp(a0)
.return:	rts
; ---------------------------------------------------------------------------

Pri_BodyMain:
		cmpi.b	#2,(Boss_defeated_flag).w
		beq.s	.chkopened
		moveq	#$2B,d1
		moveq	#$18,d2
		moveq	#$18,d3
		move.w	obX(a0),d4
		jmp	(SolidObject).l
; ---------------------------------------------------------------------------

.chkopened:
		tst.b	ob2ndRout(a0)	; has the prison been opened?
		beq.s	.open		; if so, branch
		clr.b	ob2ndRout(a0)
		bclr	#3,(v_player+obStatus).w
		bset	#1,(v_player+obStatus).w

.open:
		move.b	#2,obFrame(a0)	; use frame number 2 (destroyed prison)
		rts
; ---------------------------------------------------------------------------

Pri_Switched:
		moveq	#$17,d1
		moveq	#8,d2
		moveq	#8,d3
		move.w	obX(a0),d4
		jsr	(SolidObject).l
		lea	Ani_Obj3E(pc),a1
		jsr	(AnimateSprite).l
		move.w	pri_origY(a0),obY(a0)
		move.b	obStatus(a0),d0
		andi.b	#$18,d0		; has the prison already been opened?
		beq.s	.return		; quit if so
		addq.w	#8,obY(a0)
		move.b	#$A,obRoutine(a0)
		move.b	#60,obTimeFrame(a0)	; set time between animal spawns
		clr.b	(f_timecount).w		; stop time counter
		clr.b	(f_lockscreen).w	; lock screen position
		move.b	#1,(f_lockctrl).w	; lock controls
		move.w	#8<<btnR,(v_jpadholdlogical).w ; make Sonic run to the right
		clr.b	ob2ndRout(a0)
		bclr	#3,(v_objspace+obStatus).w
		bset	#1,(v_objspace+obStatus).w
.return:	rts
; ---------------------------------------------------------------------------

Pri_Explosion:
		moveq	#7,d0
		and.b	(Vint_runcount+3).w,d0
		bne.s	.noexplosion
		jsr	(FindFreeObj).l
		bne.s	.noexplosion
		_move.b	#id_Obj10,obID(a1)	; load fiery explosion
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		jsr	(RandomNumber).l
		moveq	#0,d1
		move.b	d0,d1
		lsr.b	#2,d1
		subi.w	#$20,d1
		add.w	d1,obX(a1)
		lsr.w	#8,d0
		lsr.b	#3,d0
		add.w	d0,obY(a1)

.noexplosion:
		subq.b	#1,obTimeFrame(a0)
		beq.s	.makeanimal
		rts
; ---------------------------------------------------------------------------

.makeanimal:
		move.b	#2,(Boss_defeated_flag).w
		move.b	#$C,obRoutine(a0)	; replace explosions with animals
		move.b	#6,obFrame(a0)
		move.b	#150,obTimeFrame(a0)
		addi.w	#$20,obY(a0)
		moveq	#7,d6
		move.w	#$9A,d5
		moveq	#-$1C,d4

-		jsr	(FindFreeObj).l
		bne.s	.return
		_move.b	#id_Obj0D,obID(a1)	; load animal object
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		add.w	d4,obX(a1)
		addq.w	#7,d4
		move.w	d5,animal_release_signal(a1)
		subq.w	#8,d5
		dbf	d6,-	; repeat 7 more times
.return:	rts
; ---------------------------------------------------------------------------

Pri_Animals:
		moveq	#7,d0
		and.b	(Vint_runcount+3).w,d0
		bne.s	.noanimal
		jsr	(FindFreeObj).l
		bne.s	.noanimal
		_move.b	#id_Obj0D,obID(a1)	; load animal object
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		jsr	(RandomNumber).l
		andi.w	#$1F,d0
		subq.w	#6,d0
		tst.w	d1
		bpl.s	.ispositive
		neg.w	d0

.ispositive:
		add.w	d0,obX(a1)
		move.w	#$C,animal_release_signal(a1)

.noanimal:
		subq.b	#1,obTimeFrame(a0)
		bne.s	.return
		addq.b	#2,obRoutine(a0)
		move.b	#60*3,obTimeFrame(a0)
.return:	rts
; ---------------------------------------------------------------------------

Pri_EndAct:
		moveq	#(v_lvlobjend-v_lvlobjspace)/object_size-1,d0
		moveq	#id_Obj0D,d1
		moveq	#object_size,d2
		lea	(v_lvlobjspace).w,a1
-		cmp.b	obID(a1),d1		; is object $28 (animal) loaded?
		beq.s	Pri_Animals.return	; if yes, branch
		adda.w	d2,a1			; next object RAM
		dbf	d0,-			; repeat $3E times

		jsr	(Load_EndOfAct).l
.delete:	jmp	(DeleteObject).l
; ---------------------------------------------------------------------------
Ani_Obj3E:	dc.w byte_19730-Ani_Obj3E
		dc.w byte_19730-Ani_Obj3E
byte_19730:	dc.b 2,  1,  3,afEnd
		even