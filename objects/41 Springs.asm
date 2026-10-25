; Straight/diagonal springs: S3&K mappings, shared two-player contact dispatch.
; All zones use the shared sprite palette, including yellow caps.
; One contact dispatcher handles both characters in all five orientations.
; Launch strengths/subtype flips and collision paths follow S3&K's model.
; animation scripts - Spring & Spring wheel
Ani_obj41:	dc.w byte_E978-Ani_obj41
		dc.w byte_E97B-Ani_obj41
		dc.w byte_E987-Ani_obj41
		dc.w byte_E98A-Ani_obj41
		dc.w byte_E996-Ani_obj41
		dc.w byte_E999-Ani_obj41
byte_E978:	dc.b  $F,  0,afEnd
byte_E97B:	dc.b   0,  1,  0,  0,  2,  2,  2,  2
		dc.b   2,  2,afChange,  0
byte_E987:	dc.b  $F,  3,afEnd
byte_E98A:	dc.b   0,  4,  3,  3,  5,  5,  5,  5
		dc.b   5,  5,afChange,  2
byte_E996:	dc.b  $F,  7,afEnd
byte_E999:	dc.b   0,  8,  7,  7,  9,  9,  9,  9
		dc.b   9,  9,afChange,  4
		even

Ani_MovSpring:	dc.w	.frame1-Ani_MovSpring
.frame1:	dc.b	8,0,1,afEnd
		even
; ---------------------------------------------------------------------------
; Object 41 - springs
; ---------------------------------------------------------------------------

Obj41:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj41_Index(pc,d0.w),d1
		jsr	Obj41_Index(pc,d1.w)
		out_of_range.w	UnloadObject
		bra.w	DisplaySprite
; ===========================================================================
Obj41_Index:
		dc.w Obj41_Init-Obj41_Index		; 0
		dc.w Obj41_Up-Obj41_Index		; 2
		dc.w Obj41_Horizontal-Obj41_Index	; 4
		dc.w Obj41_Down-Obj41_Index		; 6
		dc.w Obj41_DiagonallyUp-Obj41_Index	; 8
		dc.w Obj41_DiagonallyDown-Obj41_Index	; $A
; ============================================================================
; loc_E204:
Obj41_Init:
		addq.b	#2,obRoutine(a0)	; goto Up
		move.l #Map_obj41,obMap(a0)
		move.b #Map_obj41_height,height_pixels(a0)
		move.w #make_art_tile(ArtTile_Spring_Vertical,0,0),obGfx(a0)

loc_E22A:
		ori.b	#4,obRender(a0)
		move.b	#sprite_bound($10,sprite_bound(Map_obj41_GHZ_width,sprite_bound(Map_obj41_width,Map_obj41a_width))),obActWid(a0)
		move.w	#$200,obPriority(a0)
		move.w	obSubtype(a0),d0
		lsr.w	#3,d0
		andi.w	#$E,d0
		move.w	Obj41_Init_Subtypes(pc,d0.w),d0
		jmp	Obj41_Init_Subtypes(pc,d0.w)
; ===========================================================================
Obj41_Init_Subtypes:
		dc.w Obj41_Init_Common-Obj41_Init_Subtypes	; 0
		dc.w Obj41_Init_Horizontal-Obj41_Init_Subtypes	; 2
		dc.w Obj41_Init_Down-Obj41_Init_Subtypes	; 4
		dc.w Obj41_Init_DiagUp-Obj41_Init_Subtypes	; 6
		dc.w Obj41_Init_DiagDown-Obj41_Init_Subtypes	; 8
; ===========================================================================
; loc_E258:
Obj41_Init_Horizontal:
		move.b	#4,obRoutine(a0)	; goto Horizontal
		move.b	#2,obAnim(a0)
		move.b	#3,obFrame(a0)
		move.w #make_art_tile(ArtTile_Spring_Horizontal,0,0),obGfx(a0)

loc_E27C:
		move.b	#sprite_bound(8,sprite_bound(Map_obj41_GHZ_width,sprite_bound(Map_obj41_width,Map_obj41a_width))),obActWid(a0)
		bra.s	Obj41_Init_Common
; ===========================================================================
; loc_E284:
Obj41_Init_Down:
		move.b	#6,obRoutine(a0)	; goto Down
		move.b	#6,obFrame(a0)
		bset	#1,obStatus(a0)
		bra.s	Obj41_Init_Common
; ===========================================================================
; loc_E298:
Obj41_Init_DiagUp:
		move.b	#8,obRoutine(a0)	; goto DiagonallyUp
		move.b	#4,obAnim(a0)
		move.b	#7,obFrame(a0)
		move.w	#make_art_tile(ArtTile_Spring_Diagonal,0,0),obGfx(a0)
		bra.s	Obj41_Init_Common
; ===========================================================================
; loc_E2B2:
Obj41_Init_DiagDown:
		move.b	#$A,obRoutine(a0)	; goto DiagonallyDown
		move.b	#4,obAnim(a0)
		move.b	#$A,obFrame(a0)
		move.w	#make_art_tile(ArtTile_Spring_Diagonal,0,0),obGfx(a0)
		bset	#1,obStatus(a0)
; loc_E2D0:
Obj41_Init_Common:
		move.w	obSubtype(a0),d0
		andi.w	#2,d0
		move.w	Obj41_Strengths(pc,d0.w),objoff_34(a0)
		btst	#1,d0
		beq.s	.return
		move.l	#Map_obj41a,obMap(a0)
		move.b	#Map_obj41a_height,height_pixels(a0)

.return:
		rts
; ===========================================================================
; word_E2FE:
Obj41_Strengths:
		dc.w -$1000
		dc.w -$A00
; ===========================================================================
; loc_E302:
Obj41_Up:
        moveq #27,d1
        moveq #8,d2
        moveq #16,d3
        move.w obX(a0),d4
        lea .actor(pc),a5
        bsr.w Obj41_TestBoth
        lea Ani_obj41(pc),a1
        jmp (AnimateSprite).l
.actor:
        jsr (SolidObject_Always_SingleCharacter).l
        btst d6,obStatus(a0)
        beq.s .return
        jmp (sub_E34E).l
.return:
        rts

sub_E34E:
        clr.b jumping(a1)
        clr.b spindash_flag(a1)
        clr.b tails_flight_flag(a1)
        bclr #status.player.rolljumping,obStatus(a1)
		move.w	#$100,obAnim(a0)
		addq.w	#8,obY(a1)
		move.w	objoff_34(a0),obVelY(a1)
		bset	#1,obStatus(a1)
		bclr	#3,obStatus(a1)
		move.b	#$10,obAnim(a1)
		move.b	#2,obRoutine(a1)
		move.w	obSubtype(a0),d0
		btst	#7,d0
		beq.s	loc_E382
		move.w	#0,obVelX(a1)

loc_E382:
		btst	#0,d0
		beq.s	loc_E3C2
		move.w	#1,obInertia(a1)
		move.b	#1,flip_angle(a1)
		move.b	#0,obAnim(a1)
		move.b	#0,flips_remaining(a1)
		move.b	#4,flip_speed(a1)
		btst	#1,d0
		bne.s	loc_E3B2
		move.b	#1,flips_remaining(a1)

loc_E3B2:
		btst	#0,obStatus(a1)
		beq.s	loc_E3C2
		neg.b	flip_angle(a1)
		neg.w	obInertia(a1)

loc_E3C2:
		andi.b	#$C,d0
		cmpi.b	#4,d0
		bne.s	loc_E3D8
		move.b	#$C,obTopSolidBit(a1)
		move.b	#$D,obLRBSolidBit(a1)

loc_E3D8:
		cmpi.b	#8,d0
		bne.s	loc_E3EA
		move.b	#$E,obTopSolidBit(a1)
		move.b	#$F,obLRBSolidBit(a1)

loc_E3EA:
		move.w	#sfx_Spring,d0
		jmp	(PlaySound_Special).l
; End of function sub_E34E

; ===========================================================================
; loc_E3F4:
Obj41_Horizontal:
        moveq #19,d1
		moveq	#15,d2
		moveq	#16,d3
        move.w obX(a0),d4
        lea .actor(pc),a5
        bsr.w Obj41_TestBoth
        bsr.w sub_E54C
        lea Ani_obj41(pc),a1
        jmp (AnimateSprite).l
.actor:
        jsr (SolidObject_Always_SingleCharacter).l
        cmpi.w #1,d4 ; S3&K side-contact result, including airborne actors
        bne.s .return
        move.b obStatus(a0),d1
        move.w obX(a0),d0
        sub.w obX(a1),d0
        bcs.s .facing
        eori.b #1,d1
.facing:
        andi.b #1,d1
        bne.s .return
        jmp (sub_E474).l
.return:
        rts

sub_E474:
        clr.b jumping(a1)
        clr.b spindash_flag(a1)
        clr.b tails_flight_flag(a1)
        bclr #status.player.rolljumping,obStatus(a1)
		move.w	#$300,obAnim(a0)
		move.w	objoff_34(a0),obVelX(a1)
		addq.w	#8,obX(a1)
		bset	#0,obStatus(a1)
		btst	#0,obStatus(a0)
		bne.s	loc_E4A2
		bclr	#0,obStatus(a1)
		subi.w	#$10,obX(a1)
		neg.w	obVelX(a1)

loc_E4A2:
		move.w	#$F,move_lock(a1)
		move.w	obVelX(a1),obInertia(a1)
		btst	#2,obStatus(a1)
		bne.s	loc_E4BC
		clr.b	obAnim(a1)

loc_E4BC:
		move.w	obSubtype(a0),d0
		btst	#7,d0
		beq.s	loc_E4C8
		clr.w	obVelY(a1)

loc_E4C8:
		btst	#0,d0
		beq.s	loc_E508
		move.w	#1,obInertia(a1)
		move.b	#1,flip_angle(a1)
		clr.b	obAnim(a1)
		move.b	#1,flips_remaining(a1)
		move.b	#8,flip_speed(a1)
		btst	#1,d0
		bne.s	loc_E4F8
		move.b	#3,flips_remaining(a1)

loc_E4F8:
		btst	#0,obStatus(a1)
		beq.s	loc_E508
		neg.b	flip_angle(a1)
		neg.w	obInertia(a1)

loc_E508:
		andi.b	#$C,d0
		cmpi.b	#4,d0
		bne.s	loc_E51E
		move.b	#$C,obTopSolidBit(a1)
		move.b	#$D,obLRBSolidBit(a1)

loc_E51E:
		cmpi.b	#8,d0
		bne.s	loc_E530
		move.b	#$E,obTopSolidBit(a1)
		move.b	#$F,obLRBSolidBit(a1)

loc_E530:
		bclr	#5,obStatus(a0)
		bclr	#6,obStatus(a0)
		bclr	#5,obStatus(a1)
		move.w	#sfx_Spring,d0
		jmp	(PlaySound_Special).l
; End of function sub_E474


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


sub_E54C:
		cmpi.b	#3,obAnim(a0)
		beq.w	.return
		move.w	obX(a0),d0
		move.w	d0,d1
		addi.w	#$28,d1
		btst	#0,obStatus(a0)
		beq.s	+
		move.w	d0,d1
		subi.w	#$28,d0
+
		move.w	obY(a0),d2
		move.w	d2,d3
		subi.w	#$18,d2
		addi.w	#$18,d3
		lea	(v_player).w,a1
		btst	#1,obStatus(a1)
		bne.s	.loc_E5C2
		move.w	obInertia(a1),d4
		btst	#0,obStatus(a0)
		beq.s	+
		neg.w	d4
+
		tst.w	d4
		bmi.s	.loc_E5C2
		move.w	obX(a1),d4
		cmp.w	d0,d4
		bcs.s	.loc_E5C2
		cmp.w	d1,d4
		bcc.s	.loc_E5C2
		move.w	obY(a1),d4
		cmp.w	d2,d4
		bcs.s	.loc_E5C2
		cmp.w	d3,d4
		bcc.s	.loc_E5C2
		move.w	d0,-(sp)
		bsr.w	sub_E474
		move.w	(sp)+,d0

.loc_E5C2:
		lea	(v_player2).w,a1
		btst	#1,obStatus(a1)
		bne.s	.return
		move.w	obInertia(a1),d4
		btst	#0,obStatus(a0)
		beq.s	+
		neg.w	d4
+
		tst.w	d4
		bmi.s	.return
		move.w	obX(a1),d4
		cmp.w	d0,d4
		bcs.w	.return
		cmp.w	d1,d4
		bcc.s	.return
		move.w	obY(a1),d4
		cmp.w	d2,d4
		bcs.s	.return
		cmp.w	d3,d4
		bcc.s	.return
		bra.w	sub_E474

.return:
		rts
; End of function sub_E54C

; ===========================================================================
; loc_E606:
Obj41_Down:
        moveq #27,d1
        moveq #8,d2
        moveq #16,d3
        move.w obX(a0),d4
        lea .actor(pc),a5
        bsr.w Obj41_TestBoth
        lea Ani_obj41(pc),a1
        jmp (AnimateSprite).l
.actor:
        jsr (SolidObject_Always_SingleCharacter).l
        cmpi.w #-2,d4
        bne.s .return
        jmp (sub_E64E).l
.return:
        rts

sub_E64E:
        clr.b jumping(a1)
        clr.b spindash_flag(a1)
        clr.b tails_flight_flag(a1)
        bclr #status.player.rolljumping,obStatus(a1)
		move.w	#$100,obAnim(a0)
		subq.w	#8,obY(a1)
		move.w	objoff_34(a0),obVelY(a1)
		neg.w	obVelY(a1)
		move.w	obSubtype(a0),d0
		btst	#7,d0
		beq.s	loc_E66E
		clr.w	obVelX(a1)

loc_E66E:
		btst	#0,d0
		beq.s	loc_E6AE
		move.w	#1,obInertia(a1)
		move.b	#1,flip_angle(a1)
		clr.b	obAnim(a1)
		clr.b	flips_remaining(a1)
		move.b	#4,flip_speed(a1)
		btst	#1,d0
		bne.s	loc_E69E
		move.b	#1,flips_remaining(a1)

loc_E69E:
		btst	#0,obStatus(a1)
		beq.s	loc_E6AE
		neg.b	flip_angle(a1)
		neg.w	obInertia(a1)

loc_E6AE:
		andi.b	#$C,d0
		cmpi.b	#4,d0
		bne.s	loc_E6C4
		move.b	#$C,obTopSolidBit(a1)
		move.b	#$D,obLRBSolidBit(a1)

loc_E6C4:
		cmpi.b	#8,d0
		bne.s	loc_E6D6
		move.b	#$E,obTopSolidBit(a1)
		move.b	#$F,obLRBSolidBit(a1)

loc_E6D6:
		bset	#1,obStatus(a1)
		bclr	#3,obStatus(a1)
		move.b	#2,obRoutine(a1)
		move.w	#sfx_Spring,d0
		jmp	(PlaySound_Special).l
; End of function sub_E64E

; ===========================================================================
; loc_E6F2:
Obj41_DiagonallyUp:
        moveq #27,d1
        moveq #16,d2
        moveq #0,d3
        move.w obX(a0),d4
        lea .actor(pc),a5
        bsr.w Obj41_TestBoth
        lea Ani_obj41(pc),a1
        jmp (AnimateSprite).l
.actor:
        lea Obj41_SlopeData_DiagUp(pc),a2
        jsr (SlopedSolid_SingleCharacter).l
        btst d6,obStatus(a0)
        beq.s .return
        jmp (sub_E73E).l
.return:
        rts

sub_E73E:
		btst	#0,obStatus(a0)
		bne.s	loc_E754
		move.w	obX(a0),d0
		subq.w	#4,d0
		cmp.w	obX(a1),d0
		bcs.s	loc_E762
		rts
; ===========================================================================

loc_E754:
		move.w	obX(a0),d0
		addq.w	#4,d0
		cmp.w	obX(a1),d0
		bcc.s	loc_E762
		rts
; ===========================================================================

loc_E762:
        clr.b jumping(a1)
        clr.b spindash_flag(a1)
        clr.b tails_flight_flag(a1)
        bclr #status.player.rolljumping,obStatus(a1)
		move.w	#$500,obAnim(a0)
		move.w	objoff_34(a0),obVelY(a1)
		move.w	objoff_34(a0),obVelX(a1)
		addq.w	#6,obY(a1)
		addq.w	#6,obX(a1)
		bset	#0,obStatus(a1)
		btst	#0,obStatus(a0)
		bne.s	loc_E79A
		bclr	#0,obStatus(a1)
		subi.w	#$C,obX(a1)
		neg.w	obVelX(a1)

loc_E79A:
		bset	#1,obStatus(a1)
		bclr	#3,obStatus(a1)
		move.b	#$10,obAnim(a1)
		move.b	#2,obRoutine(a1)
		move.w	obSubtype(a0),d0
		btst	#0,d0
		beq.s	loc_E7F6
		move.w	#1,obInertia(a1)
		move.b	#1,flip_angle(a1)
		clr.b	obAnim(a1)
		move.b	#1,flips_remaining(a1)
		move.b	#8,flip_speed(a1)
		btst	#1,d0
		bne.s	loc_E7E6
		move.b	#3,flips_remaining(a1)

loc_E7E6:
		btst	#0,obStatus(a1)
		beq.s	loc_E7F6
		neg.b	flip_angle(a1)
		neg.w	obInertia(a1)

loc_E7F6:
		andi.b	#$C,d0
		cmpi.b	#4,d0
		bne.s	loc_E80C
		move.b	#$C,obTopSolidBit(a1)
		move.b	#$D,obLRBSolidBit(a1)

loc_E80C:
		cmpi.b	#8,d0
		bne.s	loc_E81E
		move.b	#$E,obTopSolidBit(a1)
		move.b	#$F,obLRBSolidBit(a1)

loc_E81E:
		move.w	#sfx_Spring,d0
		jmp	(PlaySound_Special).l
; End of function sub_E73E

; ===========================================================================
; loc_E828:
Obj41_DiagonallyDown:
        moveq #27,d1
        moveq #16,d2
        moveq #0,d3
        move.w obX(a0),d4
        lea .actor(pc),a5
        bsr.w Obj41_TestBoth
        lea Ani_obj41(pc),a1
        jmp (AnimateSprite).l
.actor:
        lea Obj41_SlopeData_DiagDown(pc),a2
        jsr (SlopedSolid_SingleCharacter).l
        cmpi.w #-2,d4
        bne.s .return
        jmp (sub_E870).l
.return:
        rts

sub_E870:
        clr.b jumping(a1)
        clr.b spindash_flag(a1)
        clr.b tails_flight_flag(a1)
        bclr #status.player.rolljumping,obStatus(a1)
		move.w	#$500,obAnim(a0)
		move.w	objoff_34(a0),obVelY(a1)
		neg.w	obVelY(a1)
		move.w	objoff_34(a0),obVelX(a1)
		subq.w	#6,obY(a1)
		addq.w	#6,obX(a1)
		bset	#0,obStatus(a1)
		btst	#0,obStatus(a0)
		bne.s	loc_E8AC
		bclr	#0,obStatus(a1)
		subi.w	#$C,obX(a1)
		neg.w	obVelX(a1)

loc_E8AC:
		bset	#1,obStatus(a1)
		bclr	#3,obStatus(a1)
		move.b	#2,obRoutine(a1)
		move.w	obSubtype(a0),d0
		btst	#0,d0
		beq.s	loc_E902
		move.w	#1,obInertia(a1)
		move.b	#1,flip_angle(a1)
		clr.b	obAnim(a1)
		move.b	#1,flips_remaining(a1)
		move.b	#8,flip_speed(a1)
		btst	#1,d0
		bne.s	loc_E8F2
		move.b	#3,flips_remaining(a1)

loc_E8F2:
		btst	#0,obStatus(a1)
		beq.s	loc_E902
		neg.b	flip_angle(a1)
		neg.w	obInertia(a1)

loc_E902:
		andi.b	#$C,d0
		cmpi.b	#4,d0
		bne.s	loc_E918
		move.b	#$C,obTopSolidBit(a1)
		move.b	#$D,obLRBSolidBit(a1)

loc_E918:
		cmpi.b	#8,d0
		bne.s	loc_E92A
		move.b	#$E,obTopSolidBit(a1)
		move.b	#$F,obLRBSolidBit(a1)

loc_E92A:
		move.w	#sfx_Spring,d0
		jmp	(PlaySound_Special).l
; End of function sub_E870

; Input d1-d4 is shared; a5 names one direction's actor callback.
Obj41_TestBoth:
        lea (v_player).w,a1
        moveq #3,d6
        movem.l d1-d4/a5,-(sp)
        jsr (a5)
        movem.l (sp)+,d1-d4/a5
        lea (v_player2).w,a1
        tst.l code(a1)
        beq.s .return
        moveq #4,d6
        jmp (a5)
.return:
        rts
