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
; ===========================================================================
Pri_Index:	dc.w Pri_Init-Pri_Index		; 0
		dc.w Pri_BodyMain-Pri_Index	; 2
		dc.w Pri_Switched-Pri_Index	; 4
		dc.w Pri_Explosion-Pri_Index	; 6
		dc.w Pri_Animals-Pri_Index	; 8
		dc.w Pri_EndAct-Pri_Index	; $A
; ===========================================================================
Pri_Var:	; routine, width, priority, frame
		dc.b   2,$20,  4,  0	; capsule body
		dc.b   4, $C,  5,  1	; capsule button
; ===========================================================================

Pri_Init:	; Routine 0
		move.l	#Map_Pri,obMap(a0)
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
		move.w	obPriority(a0),d1
		lsr.w	#1,d1
		andi.w	#$380,d1
		move.w	d1,obPriority(a0)
		move.b	(a1)+,obFrame(a0)
		rts
; ===========================================================================

Pri_BodyMain:	; Routine 2
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
		bclr	#3,(v_player2+obStatus).w
		bset	#1,(v_player+obStatus).w
		bset	#1,(v_player2+obStatus).w
.open:		move.b	#2,obFrame(a0)	; use frame number 2 (destroyed prison)
		rts
; ---------------------------------------------------------------------------

Pri_Switched:	; Routine 4
		moveq	#$17,d1
		moveq	#8,d2
		moveq	#8,d3
		move.w	obX(a0),d4
		jsr	(SolidObject).l
		lea	Ani_Pri(pc),a1
		jsr	(AnimateSprite).l
		move.w	pri_origY(a0),obY(a0)
		move.b	obStatus(a0),d0
		andi.b	#$18,d0		; is the character touching/pressing the switch?
		beq.s	.open2		; if not, quit
		addq.w	#8,obY(a0)
		move.b	#6,obRoutine(a0)
		move.b	#60,obTimeFrame(a0)	; set delay between animal spawns
		clr.b	(f_timecount).w		; stop time counter
		clr.b	(f_lockscreen).w	; lock screen position
		clr.b	ob2ndRout(a0)
		bclr	#3,(v_player+obStatus).w
		bclr	#3,(v_player2+obStatus).w
		bset	#1,(v_player+obStatus).w
		bset	#1,(v_player2+obStatus).w
.open2:		rts
; ---------------------------------------------------------------------------

Pri_Explosion:	; Routine 6
		moveq	#7,d0
		and.b	(Vint_runcount+3).w,d0
		bne.s	.makeanimal
		jsr	(FindFreeObj).l
		bne.s	.makeanimal
		_move.b	#id_ObjFD,obID(a1)	; load fiery explosion
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

.makeanimal:
		subq.b	#1,obTimeFrame(a0)
		bne.s	.fail
		move.b	#2,(Boss_defeated_flag).w
		move.b	#8,obRoutine(a0)	; replace explosions with animals
		move.b	#4,obFrame(a0)
		move.b	#150,obTimeFrame(a0)
		addi.w	#$20,obY(a0)
		moveq	#7,d6
		move.w	#$9A,d5
		moveq	#-$1C,d4

-		jsr	(FindFreeObj).l
		bne.s	.fail
		_move.b	#id_Obj0D,obID(a1)	; load animal object
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		add.w	d4,obX(a1)
		addq.w	#7,d4
		move.w	d5,animal_release_signal(a1)
		subq.w	#8,d5
		dbf	d6,-	; repeat 7 more times
.fail:		rts
; ---------------------------------------------------------------------------

Pri_Animals:	; Routine 8
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
		bne.s	.wait
		addq.b	#2,obRoutine(a0)
.wait:		rts
; ---------------------------------------------------------------------------

Pri_EndAct:	; Routine $A
		moveq	#(v_lvlobjend-v_lvlobjspace)/object_size-1,d0
		moveq	#id_Obj0D,d1
		moveq	#object_size,d2
		lea	(v_lvlobjspace).w,a1
-		cmp.b	obID(a1),d1		; is object $28 (animal) loaded?
		beq.s	Pri_Animals.wait	; if yes, branch
		adda.w	d2,a1			; next object RAM
		dbf	d0,-			; repeat $3E times

		jsr	(Load_EndOfAct).l
.delete:	jmp	(DeleteObject).l
; ---------------------------------------------------------------------------
Ani_Pri:	dc.w byte_19730-Ani_Pri
		dc.w byte_19730-Ani_Pri
byte_19730:	dc.b 2,  1,  3,afEnd
		even