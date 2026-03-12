; ---------------------------------------------------------------------------
; Object 18 - platforms (GHZ, SYZ, SLZ)
; ---------------------------------------------------------------------------

Obj18:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj18_Index(pc,d0.w),d1
		jmp	Obj18_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj18_Index:	dc.w Plat_Main-Obj18_Index	; 0
		dc.w Plat_Solid-Obj18_Index	; 2
		dc.w Plat_Delete-Obj18_Index	; 4
		dc.w Plat_Action-Obj18_Index	; 6
		dc.w Plat_Solid2-Obj18_Index	; 8	; From Sonic 2
; ---------------------------------------------------------------------------
Obj18_Conf:
		;    width_pixels
		;	  frame
		dc.b $20, 0
		dc.b $20, 1
		dc.b $20, 2
		dc.b $40, 3
		dc.b $30, 4
; ---------------------------------------------------------------------------

Plat_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		lsr.w	#3,d0
		andi.w	#$1E,d0
		lea	Obj18_Conf(pc,d0.w),a2
		move.b	(a2)+,obActWid(a0)
		move.b	(a2)+,obFrame(a0)
		move.l	#Map_Obj18_GHZ,obMap(a0)	; we default to GHZ's platform mappings
		move.w	#make_art_tile(ArtTile_Level,2,0),obGfx(a0)
		cmpi.b	#id_EHZ,(Current_Zone).w
		bne.s	.notEHZ			; for any level that's not GHZ
		move.l	#Map_obj18_EHZ,obMap(a0)	; load EHZ specific platform mappings
		move.w	#make_art_tile(ArtTile_Level,2,0),obGfx(a0)
.notEHZ:
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.w	obY(a0),objoff_2C(a0)
		move.w	obY(a0),objoff_34(a0)
		move.w	obX(a0),objoff_32(a0)
		move.w	#$80,obAngle(a0)
		tst.b	obSubtype(a0)	; From Sonic 2
		bpl.s	++
		addq.b	#6,obRoutine(a0)
		andi.b	#$F,obSubtype(a0)
		move.b	#$30,obHeight(a0)
	nop;	cmpi.b	#aquatic_ruin_zone,(Current_Zone).w	; is this aquatic ruin?
	nop;	bne.s	+					; if not, skip
	nop;	move.b	#$28,obHeight(a0)			; aquatic ruin specific height
+
		bset	#4,obRender(a0)
		bra.w	Plat_Solid2
; ===========================================================================
+
		andi.b	#$F,obSubtype(a0)

Plat_Solid:	; Routine 2
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		bne.s	Plat_Action2
		tst.b	objoff_38(a0)
		beq.s	+
		subq.b	#4,objoff_38(a0)
		bra.s	+
; ---------------------------------------------------------------------------

Plat_Action2:
		cmpi.b	#$40,objoff_38(a0)
		beq.s	+
		addq.b	#4,objoff_38(a0)
+
		move.w	obX(a0),-(sp)
		bsr.w	Plat_Move
		bsr.w	Plat_Nudge
		moveq	#0,d1
		move.b	obActWid(a0),d1
		moveq	#8,d3
		move.w	(sp)+,d4
		bsr.w	PlatformObject
	;	bra.s	Plat_ChkDel
		out_of_range.w	DeleteObject,objoff_32(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
Plat_Solid2:	; Routine 8
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		bne.s	+
		tst.b	objoff_38(a0)
		beq.s	++
		subq.b	#4,objoff_38(a0)
		bra.s	++
; ---------------------------------------------------------------------------
+
		cmpi.b	#$40,objoff_38(a0)
		beq.s	+
		addq.b	#4,objoff_38(a0)
+
		move.w	obX(a0),-(sp)
		bsr.w	Plat_Move
		bsr.w	Plat_Nudge
		moveq	#0,d1
		move.b	obActWid(a0),d1
		addi.w	#$B,d1
		moveq	#0,d2
		move.b	obHeight(a0),d2
		move.w	d2,d3
		addq.w	#1,d3
		move.w	(sp)+,d4
		bsr.w	PlatformObject
		out_of_range.w	DeleteObject,objoff_32(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Plat_Action:	; Routine 6
		bsr.w	Plat_Move
		bsr.w	Plat_Nudge
; Plat_ChkDel:
		out_of_range.w	DeleteObject,objoff_32(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Plat_Delete:	; Routine 4
		bra.w	DeleteObject

; ---------------------------------------------------------------------------
; Subroutine to move platform slightly when you stand on it
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Plat_Nudge:
		move.b	objoff_38(a0),d0
		bsr.w	CalcSine
		move.w	#$400,d1
		muls.w	d1,d0
		swap	d0
		add.w	objoff_2C(a0),d0
		move.w	d0,obY(a0)
		rts
; End of function Plat_Nudge

; ---------------------------------------------------------------------------
; Subroutine to move platforms
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Plat_Move:
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		andi.w	#$F,d0
		add.w	d0,d0
		move.w	.index(pc,d0.w),d1
		jmp	.index(pc,d1.w)
; End of function Plat_Move

; ---------------------------------------------------------------------------
.index:		dc.w .type00-.index, .type01-.index
		dc.w .type02-.index, .type03-.index
		dc.w .type04-.index, .type05-.index
		dc.w .type06-.index, .type07-.index
		dc.w .type08-.index, .type00-.index
		dc.w .type0A-.index, .type0D-.index
		dc.w .type0B-.index, .type0C-.index
; ---------------------------------------------------------------------------

.type00:
		rts		; platform 00 doesn't move
; ---------------------------------------------------------------------------

.type05:
		move.w	objoff_32(a0),d0
		move.b	obAngle(a0),d1	; load platform-motion variable
		neg.b	d1		; reverse platform-motion
		addi.b	#$40,d1
		ext.w	d1
		add.w	d1,d0
		move.w	d0,obX(a0)	; change position on x-axis
		move.b	(v_oscillate+$1A).w,obAngle(a0)
		rts
; ---------------------------------------------------------------------------

.type01:
		move.w	objoff_32(a0),d0
		move.b	obAngle(a0),d1
		subi.b	#$40,d1

; .type01_move:
		ext.w	d1
		add.w	d1,d0
		move.w	d0,obX(a0)	; change position on x-axis
		move.b	(v_oscillate+$1A).w,obAngle(a0)
		rts
; ---------------------------------------------------------------------------

.type0C:
		move.w	objoff_34(a0),d0
		move.b	(v_oscillate+$E).w,d1 ; load platform-motion variable
		neg.b	d1		; reverse platform-motion
		addi.b	#$30,d1
		ext.w	d1
		add.w	d1,d0
		move.w	d0,objoff_2C(a0)
		move.b	(v_oscillate+$1A).w,obAngle(a0)
		rts
; ---------------------------------------------------------------------------

.type0B:
		move.w	objoff_34(a0),d0
		move.b	(v_oscillate+$E).w,d1 ; load platform-motion variable
		subi.b	#$30,d1
		ext.w	d1
		add.w	d1,d0
		move.w	d0,objoff_2C(a0)
		move.b	(v_oscillate+$1A).w,obAngle(a0)
		rts
; ---------------------------------------------------------------------------

.type06:
		move.w	objoff_34(a0),d0
		move.b	obAngle(a0),d1	; load platform-motion variable
		neg.b	d1		; reverse platform-motion
		addi.b	#$40,d1
		ext.w	d1
		add.w	d1,d0
		move.w	d0,objoff_2C(a0)
		move.b	(v_oscillate+$1A).w,obAngle(a0)
		rts
; ---------------------------------------------------------------------------

.type02:
		move.w	objoff_34(a0),d0
		move.b	obAngle(a0),d1	; load platform-motion variable
		subi.b	#$40,d1
		ext.w	d1
		add.w	d1,d0
		move.w	d0,objoff_2C(a0)	; change position on y-axis
		move.b	(v_oscillate+$1A).w,obAngle(a0)
		rts
; ---------------------------------------------------------------------------

.type03:
		tst.w	objoff_3A(a0)		; is time delay set?
		bne.s	.type03_wait		; if it is, branch
		btst	#3,obStatus(a0)		; is Sonic standing on the platform?
		beq.s	+			; if not, return
		move.w	#30,objoff_3A(a0)	; set time delay to 0.5 seconds
		rts
; ---------------------------------------------------------------------------

.type03_wait:
		subq.w	#1,objoff_3A(a0)	; subtract 1 from time delay
		bne.s	+			; keep waiting until we hit 0
		move.w	#$20,objoff_3A(a0)
		addq.b	#1,obSubtype(a0)	; change to type 04 (falling)
+		rts
; ---------------------------------------------------------------------------

.type04:
		tst.w	objoff_3A(a0)
		beq.s	.loc_8A2E
		subq.w	#1,objoff_3A(a0)
		bne.s	.loc_8A2E
		bclr	#3,obStatus(a0)	; p1_standing_bit
		beq.s	+
		lea	(v_player).w,a1
		bsr.s	.both_characters
+
		bclr	#4,obStatus(a0)	; p2_standing_bit
		beq.s	+
		lea	(v_player2).w,a1
		bsr.s	.both_characters
+
		move.b	#6,obRoutine(a0)

.loc_8A2E:
		move.l	objoff_2C(a0),d3
		move.w	obVelY(a0),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,d3
		move.l	d3,objoff_2C(a0)
		addi.w	#$38,obVelY(a0)
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#224,d0
		cmp.w	objoff_2C(a0),d0
		bcc.s	+
		move.b	#4,obRoutine(a0)	; this was 6 in Sonic 1
		rts
; ---------------------------------------------------------------------------
.both_characters:
		bset	#1,obStatus(a1)
		bclr	#3,obStatus(a1)
		move.b	#2,obRoutine(a1)
		move.w	obVelY(a0),obVelY(a1)
; ---------------------------------------------------------------------------

.type07:
		tst.w	objoff_3A(a0)		; is time delay set?
		bne.s	.type07_wait		; if yes, branch
		lea	(f_switch).w,a2		; load switch statuses
		moveq	#0,d0
		move.b	obSubtype(a0),d0	; move object type ($x7) to d0
		lsr.w	#4,d0			; divide d0 by 8, round down
		tst.b	(a2,d0.w)		; has switch no. d0 been pressed?
		beq.s	+			; if not, branch
		move.w	#60,objoff_3A(a0)	; set time delay to 1 second
		rts
; ---------------------------------------------------------------------------

.type07_wait:
		subq.w	#1,objoff_3A(a0)	; subtract 1 from time delay
		bne.s	+			; keep waiting until we hit 0
		addq.b	#1,obSubtype(a0)	; change type to 08
		rts
; ---------------------------------------------------------------------------

.type08:
		subq.w	#2,objoff_2C(a0)	; move platform up
		move.w	objoff_34(a0),d0
		subi.w	#$200,d0
		cmp.w	objoff_2C(a0),d0	; has the platform moved $200 pixels?
		bne.s	+			; keep going until it has
		clr.b	obSubtype(a0)		; then change to type 00 (stop moving)
+		rts
; ---------------------------------------------------------------------------

.type0A:
		move.w	objoff_34(a0),d0
		move.b	obAngle(a0),d1		; load platform-motion variable
		subi.b	#$40,d1
		ext.w	d1
		asr.w	#1,d1
		add.w	d1,d0
		move.w	d0,objoff_2C(a0)	; change position on y-axis
		move.b	(v_oscillate+$1A).w,obAngle(a0)	; update platform-movement variable
		rts
; ---------------------------------------------------------------------------

.type0D:
		move.w	objoff_34(a0),d0
		move.b	obAngle(a0),d1		; load platform-motion variable
		neg.b	d1
		addi.b	#$40,d1
		ext.w	d1
		asr.w	#1,d1
		add.w	d1,d0
		move.w	d0,objoff_2C(a0)	; change position on y-axis
		move.b	(v_oscillate+$1A).w,obAngle(a0)	; update platform-movement variable
		rts