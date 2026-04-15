; ===========================================================================
; ---------------------------------------------------------------------------
; Object 15 - swinging platforms (ported toward S2 final behavior model)
;   high nibble = behavior family
;   low  nibble = chain length
;
;   0X = normal swing
;   1X = bounce left
;   2X = static
;   3X = bounce right
;   4X = trap
;   5X = swinging giant ball
;   6X = detach
; ---------------------------------------------------------------------------

; local object scratch aliases
swing_helper_ptr	= objoff_2C	; 4 bytes
swing_last_angle	= obAniFrame	; 1 byte; SST 1B
swing_mode_started	= obAnim	; 1 byte; SST 1C
swing_mode_timer	= objoff_30	; 2 bytes
swing_ang_vel		= objoff_32	; 2 bytes
swing_orig_y		= objoff_34	; 2 bytes
swing_orig_x		= objoff_36	; 2 bytes
swing_radius		= objoff_38	; 2 bytes
swing_dir_flag		= obPrevAni	; 1 byte; SST 1D

; local status helpers (keep them local and honest)
status_p1_standing_bit	= 3
status_p2_standing_bit	= 4
status_standing_mask	= $18
status_in_air_bit	= 1
; ---------------------------------------------------------------------------

Obj15:
		btst	#obRender.multi_sprite,obRender(a0)
		bne.w	Obj15_HelperDisplay
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj15_Index(pc,d0.w),d1
		jmp	Obj15_Index(pc,d1.w)
; ---------------------------------------------------------------------------

Obj15_HelperDisplay:
		move.w	#$200,d0
		bra.w	DisplaySprite3
; ---------------------------------------------------------------------------
Obj15_Index:
		dc.w	Obj15_Init-Obj15_Index		; 00
		dc.w	Obj15_SetSolid-Obj15_Index	; 02
		dc.w	Obj15_Display-Obj15_Index	; 04
		dc.w	Obj15_DetachCheck-Obj15_Index	; 06
		dc.w	Obj15_PostDetach-Obj15_Index	; 08
		dc.w	Obj15_Falling-Obj15_Index	; 0A
		dc.w	Obj15_Floating-Obj15_Index	; 0C
; ---------------------------------------------------------------------------

Obj15_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj15,obMap(a0)
		move.w	#make_art_tile(ArtTile_GHZ_MZ_Swing,0,0),obGfx(a0)
		move.b	#1<<obRender.level_fg,obRender(a0)
		move.w	#$180,obPriority(a0)
		move.b	#$18,obActWid(a0)
		move.b	#8,obHeight(a0)
		move.w	obY(a0),swing_orig_y(a0)
		move.w	obX(a0),swing_orig_x(a0)

		cmpi.b	#id_SLZ,(Current_Zone).w
		bne.s	.parseSubtype
		move.l	#Map_Obj15_SLZ,obMap(a0)
		move.w	#make_art_tile(ArtTile_SLZ_Swing,2,0),obGfx(a0)
		move.b	#$20,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#$99,obColType(a0)

.parseSubtype:
		moveq	#0,d1
		move.b	obSubtype(a0),d1

.family:
		move.b	d1,d4
		andi.b	#$F0,d4				; keep behavior family
		cmpi.b	#$60,d4
		bne.s	.notDetach
		addq.b	#4,obRoutine(a0)		; 6X starts at detach watcher
.notDetach:
		andi.w	#$F,d1				; keep chain length

		move.w	d1,d2
		lsl.w	#4,d2
		addq.w	#8,d2
		move.w	d2,swing_radius(a0)

		moveq	#0,d0
		move.l	d0,swing_helper_ptr(a0)
		move.w	d0,swing_last_angle(a0)		; With a single SST re-arrange,
		move.l	d0,swing_mode_timer(a0)		; We get a double Two-for-one clean
		move.b	d0,swing_dir_flag(a0)
		move.w	#$8000,obAngle(a0)

		; spawn a helper multi-sprite object for the chain
		bsr.w	FindNextFreeObj
		bne.w	.noHelper
		_move.b	obID(a0),obID(a1)
		move.l	obMap(a0),obMap(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.b	#1<<obRender.level_fg,obRender(a1)
		bset	#obRender.multi_sprite,obRender(a1)
		bset	#obRender.explicit_height,obRender(a1)
		move.b	#$48,mainspr_width(a1)
		move.b	#$50,mainspr_height(a1)
		move.b	d1,mainspr_childsprites(a1)
		move.w	swing_orig_x(a0),d2
		move.w	swing_orig_y(a0),d3
		lea	subspr_data(a1),a2
		moveq	#0,d0
		move.b	mainspr_childsprites(a1),d0
		beq.s	.helperNoChain
		subq.w	#1,d0

.fillChain:
		move.w	d2,(a2)+
		move.w	d3,(a2)+
		move.w	#1,(a2)+			; chain link frame
		addi.w	#$10,d3
		dbf	d0,.fillChain

		moveq	#0,d0
		move.b	#2,sub2_mapframe(a1)
		move.b	#1,mainspr_mapframe(a1)
		move.b	mainspr_childsprites(a1),d0
		cmpi.w	#5,d0
		blo.s	.helperShortInit

		move.w	sub6_x_pos(a1),obX(a1)
		move.w	sub6_y_pos(a1),obY(a1)
		move.w	d2,sub6_x_pos(a1)
		move.w	d3,sub6_y_pos(a1)
		addq.w	#8,d3
		move.w	d3,obY(a0)
		bra.s	.helperDone


.helperShortInit:
		move.w	-6(a2),obX(a1)
		move.w	-4(a2),obY(a1)
		move.w	d2,-6(a2)
		move.w	d3,-4(a2)
		addq.w	#8,d3
		move.w	d3,obY(a0)
		bra.s	.helperDone

.helperNoChain:
		move.b	#2,mainspr_mapframe(a1)
		move.w	d2,obX(a1)
		move.w	d3,obY(a1)
		addq.w	#8,d3
		move.w	d3,obY(a0)

.helperDone:
		move.l	a1,swing_helper_ptr(a0)

.noHelper:
		move.b	d4,obSubtype(a0)

		; normal initial resting position: straight down from the anchor
		move.w	swing_orig_x(a0),obX(a0)
		move.w	swing_orig_y(a0),d0
		add.w	swing_radius(a0),d0
		move.w	d0,obY(a0)

		; family-specific parent art/collision overrides
		cmpi.b	#$40,d4
		beq.s	.makeBall
		cmpi.b	#$50,d4
		bne.s	.done

.makeBall:
		move.l	#Map_GBall,obMap(a0)
		move.w	#make_art_tile(ArtTile_GHZ_Giant_Ball,2,0),obGfx(a0)
		move.b	#1,obFrame(a0)
		move.w	#$100,obPriority(a0)
		move.b	#$18,obActWid(a0)
		move.b	#$18,obHeight(a0)
		move.b	#$99,obColType(a0)
.done:		rts
; ---------------------------------------------------------------------------

Obj15_SetSolid:
		move.w	obX(a0),-(sp)
		bsr.w	Obj15_UpdateMotion
		moveq	#0,d1
		moveq	#0,d3
		move.b	obActWid(a0),d1
		move.b	obHeight(a0),d3
		addq.b	#1,d3
		move.w	(sp)+,d4
		bsr.w	sub_F82E
		bra.w	Obj15_ChkDel
; ---------------------------------------------------------------------------

Obj15_DetachCheck:
		move.w	obX(a0),-(sp)
		bsr.w	Obj15_UpdateMotion
		moveq	#0,d1
		moveq	#0,d3
		move.b	obActWid(a0),d1
		move.b	obHeight(a0),d3
		addq.b	#1,d3
		move.w	(sp)+,d4
		bsr.w	sub_F82E
		move.b	obStatus(a0),d0
		andi.b	#status_standing_mask,d0
		beq.w	Obj15_ChkDel
		tst.b	(v_oscillate+$1A).w
		bne.w	Obj15_ChkDel
		bsr.w	FindNextFreeObj
		bne.s	.noSpawn
		moveq	#0,d0
		move.w	#bytesToLcnt(object_size),d1
.copy:
		move.l	(a0,d0.w),(a1,d0.w)
		addq.w	#4,d0
		dbf	d1,.copy

		move.b	#$A,obRoutine(a1)		; falling state
		clr.l	swing_helper_ptr(a1)		; detached copy has no helper
		move.w	#$200,obVelX(a1)
		btst	#0,obStatus(a0)
		beq.s	.velDone
		neg.w	obVelX(a1)

.velDone:
		bset	#status_in_air_bit,obStatus(a1)

		move.w	a0,d0
		subi.w	#v_objspace,d0
		lsr.w	#object_size_bits,d0
		andi.w	#$7F,d0

		move.w	a1,d1
		subi.w	#v_objspace,d1
		lsr.w	#object_size_bits,d1
		andi.w	#$7F,d1

		cmp.b	(v_player+standonobject).w,d0
		bne.s	.chkTails
		move.b	d1,(v_player+standonobject).w

.chkTails:
		cmp.b	(v_player2+standonobject).w,d0
		bne.s	.noSpawn
		move.b	d1,(v_player2+standonobject).w

.noSpawn:
		move.b	#3,obFrame(a0)
		addq.b	#2,obRoutine(a0)		; keep the hanging chain/anchor alive
		andi.b	#$E7,obStatus(a0)
		bra.w	Obj15_ChkDel
; ---------------------------------------------------------------------------

Obj15_PostDetach:
		bsr.w	Obj15_UpdateMotion
		bra.w	Obj15_ChkDel
; ---------------------------------------------------------------------------

Obj15_Falling:
		move.w	obX(a0),-(sp)
		btst	#status_in_air_bit,obStatus(a0)
		beq.s	.bob
		bsr.w	ObjectMove
		addi.w	#$18,obVelY(a0)
		cmpi.w	#$720,obY(a0)
		blo.s	.solid
		move.w	#$720,obY(a0)
		bclr	#status_in_air_bit,obStatus(a0)
		clr.l	obVelX(a0)	; and obVelY
		move.w	obY(a0),swing_orig_y(a0)
		moveq	#0,d1
		moveq	#0,d3
		move.b	obActWid(a0),d1
		move.b	obHeight(a0),d3
		addq.b	#1,d3
		move.w	(sp)+,d4
		bsr.w	sub_F82E
		bra.w	MarkObjGone

.bob:
		moveq	#0,d0
		move.b	(v_oscillate+$14).w,d0
		lsr.w	#1,d0
		add.w	swing_orig_y(a0),d0
		move.w	d0,obY(a0)

.solid:
		moveq	#0,d1
		moveq	#0,d3
		move.b	obActWid(a0),d1
		move.b	obHeight(a0),d3
		addq.b	#1,d3
		move.w	(sp)+,d4
		bsr.w	sub_F82E
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------

Obj15_Floating:
		move.w	obX(a0),-(sp)
		bsr.w	ObjectMove
		btst	#status_in_air_bit,obStatus(a0)
		beq.s	.bob
		addi.w	#$18,obVelY(a0)
		move.w	(v_waterpos2).w,d0
		cmp.w	obY(a0),d0
		bhi.s	.solid
		move.w	d0,obY(a0)
		move.w	d0,swing_orig_y(a0)
		bclr	#status_in_air_bit,obStatus(a0)
		move.w	#$100,obVelX(a0)
		clr.w	obVelY(a0)
		moveq	#0,d1
		moveq	#0,d3
		move.b	obActWid(a0),d1
		move.b	obHeight(a0),d3
		addq.b	#1,d3
		move.w	(sp)+,d4
		bsr.w	sub_F82E
		bra.w	MarkObjGone

.bob:
		moveq	#0,d0
		move.b	(v_oscillate+$14).w,d0
		lsr.w	#1,d0
		add.w	swing_orig_y(a0),d0
		move.w	d0,obY(a0)
		tst.w	obVelX(a0)
		beq.s	.solid
		moveq	#0,d3
		move.b	obActWid(a0),d3
		jsr	(ObjHitWallRight).l
		tst.w	d1
		bpl.s	.solid
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)

.solid:
		moveq	#0,d1
		moveq	#0,d3
		move.b	obActWid(a0),d1
		move.b	obHeight(a0),d3
		addq.b	#1,d3
		move.w	(sp)+,d4
		bsr.w	sub_F82E
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
; motion core
; ---------------------------------------------------------------------------

Obj15_UpdateMotion:
		moveq	#0,d1
		move.b	obSubtype(a0),d1
		lsr.b	#4,d1				; family 0-6
		add.w	d1,d1				; word index
		move.w	Obj15_MotionIndex(pc,d1.w),d1
		jmp	Obj15_MotionIndex(pc,d1.w)
; ---------------------------------------------------------------------------
Obj15_MotionIndex:
		dc.w	Obj15_Motion_Normal-Obj15_MotionIndex		; 0X
		dc.w	Obj15_Motion_BounceLeft-Obj15_MotionIndex	; 1X
		dc.w	Obj15_Motion_Static-Obj15_MotionIndex		; 2X
		dc.w	Obj15_Motion_BounceRight-Obj15_MotionIndex	; 3X
		dc.w	Obj15_Motion_Trap-Obj15_MotionIndex		; 4X
		dc.w	Obj15_Motion_Normal-Obj15_MotionIndex		; 5X
		dc.w	Obj15_Motion_Normal-Obj15_MotionIndex		; 6X
; ---------------------------------------------------------------------------

Obj15_Motion_Normal:
		moveq	#0,d0
		move.b	(v_oscillate+$1A).w,d0
		bra.w	Obj15_ApplyAngle
; ---------------------------------------------------------------------------

Obj15_Motion_BounceLeft:
		moveq	#0,d0
		move.b	(v_oscillate+$1A).w,d0
		cmpi.b	#$40,d0
		bhs.s	+
		moveq	#$40,d0
+		bra.w	Obj15_ApplyAngle
; ---------------------------------------------------------------------------

Obj15_Motion_Static:
		moveq	#$40,d0
		bra.w	Obj15_ApplyAngle
; ---------------------------------------------------------------------------

Obj15_Motion_BounceRight:
		moveq	#0,d0
		move.b	(v_oscillate+$1A).w,d0
		cmpi.b	#$40,d0
		blo.s	+
		moveq	#$40,d0
+		bra.w	Obj15_ApplyAngle
; ---------------------------------------------------------------------------
; trap family ($40)
; ---------------------------------------------------------------------------

Obj15_Motion_Trap:
		tst.w	swing_mode_timer(a0)
		beq.s	.chkTrigger
		subq.w	#1,swing_mode_timer(a0)
		rts

.chkTrigger:
		tst.b	swing_mode_started(a0)
		bne.s	.run
		move.w	(v_player+obX).w,d0
		sub.w	swing_orig_x(a0),d0
		addi.w	#$20,d0
		cmpi.w	#$40,d0
		bhs.s	.done
		tst.w	(Debug_placement_mode).w
		bne.s	.done
		move.b	#1,swing_mode_started(a0)

.run:
		tst.b	swing_dir_flag(a0)
		beq.s	.negative

.positive:
		move.w	swing_ang_vel(a0),d0
		addq.w	#8,d0
		move.w	d0,swing_ang_vel(a0)
		add.w	d0,obAngle(a0)
		cmpi.w	#$200,d0
		bne.s	.done
		clr.w	swing_ang_vel(a0)
		move.w	#$8000,obAngle(a0)
		clr.b	swing_dir_flag(a0)
		move.w	#60,swing_mode_timer(a0)
		rts

.negative:
		move.w	swing_ang_vel(a0),d0
		subi.w	#8,d0
		move.w	d0,swing_ang_vel(a0)
		add.w	d0,obAngle(a0)
		cmpi.w	#-$200,d0
		bne.s	.done
		clr.w	swing_ang_vel(a0)
		move.w	#$4000,obAngle(a0)
		move.b	#1,swing_dir_flag(a0)
		move.w	#60,swing_mode_timer(a0)
.done:		moveq	#0,d0
		move.b	obAngle(a0),d0
		; we're the last entry, so fall through!
	;	bra.s	Obj15_ApplyAngle uncomment me if further entries are added
; ---------------------------------------------------------------------------

Obj15_ApplyAngle:
		cmp.b	swing_last_angle(a0),d0
		beq.w	.return
		move.b	d0,swing_last_angle(a0)

		move.w	#$80,d1
		btst	#0,obStatus(a0)
		beq.s	.calc
		neg.w	d0
		add.w	d1,d0

.calc:
		bsr.w	CalcSine
		move.w	swing_orig_y(a0),d2
		move.w	swing_orig_x(a0),d3
		movea.l	swing_helper_ptr(a0),a1
		beq.w	.fallbackSingle
		; convert sine/cosine to 16px fixed-point step
		asl.w	#4,d0
		ext.l	d0
		asl.l	#8,d0
		asl.w	#4,d1
		ext.l	d1
		asl.l	#8,d1

		moveq	#0,d6
		moveq	#0,d4
		moveq	#0,d5
		lea	subspr_data(a1),a2
		move.b	mainspr_childsprites(a1),d6
		tst.w	d6
		beq.w	.helperNoChain
		subq.w	#1,d6

.linkLoop:
		movem.l	d4-d5,-(sp)
		swap	d4
		swap	d5
		add.w	d2,d4
		add.w	d3,d5
		move.w	d5,(a2)+			; child x
		move.w	d4,(a2)+			; child y
		movem.l	(sp)+,d4-d5
		add.l	d0,d4
		add.l	d1,d5
		addq.w	#2,a2				; skip frame word
		dbf	d6,.linkLoop

		moveq	#0,d6
		move.b	mainspr_childsprites(a1),d6
		cmpi.w	#5,d6
		blo.s	.helperShortMove

		movem.l	d4-d5,-(sp)
		swap	d4
		swap	d5
		add.w	swing_orig_y(a0),d4
		add.w	swing_orig_x(a0),d5
		move.w	sub6_x_pos(a1),d2
		move.w	sub6_y_pos(a1),d3
		move.w	d5,sub6_x_pos(a1)
		move.w	d4,sub6_y_pos(a1)
		move.w	d2,obX(a1)
		move.w	d3,obY(a1)
		movem.l	(sp)+,d4-d5
		asr.l	#1,d0
		asr.l	#1,d1
		add.l	d0,d4
		add.l	d1,d5
		swap	d4
		swap	d5
		add.w	swing_orig_y(a0),d4
		add.w	swing_orig_x(a0),d5
		move.w	d4,obY(a0)
		move.w	d5,obX(a0)
		rts

.helperShortMove:
		movem.l	d4-d5,-(sp)
		swap	d4
		swap	d5
		add.w	swing_orig_y(a0),d4
		add.w	swing_orig_x(a0),d5
		move.w	-6(a2),d2
		move.w	-4(a2),d3
		move.w	d5,-6(a2)
		move.w	d4,-4(a2)
		move.w	d2,obX(a1)
		move.w	d3,obY(a1)
		movem.l	(sp)+,d4-d5
		asr.l	#1,d0
		asr.l	#1,d1
		add.l	d0,d4
		add.l	d1,d5
		swap	d4
		swap	d5
		add.w	swing_orig_y(a0),d4
		add.w	swing_orig_x(a0),d5
		move.w	d4,obY(a0)
		move.w	d5,obX(a0)
		rts

.helperNoChain:
		move.w	swing_orig_x(a0),obX(a1)
		move.w	swing_orig_y(a0),obY(a1)
		asr.l	#1,d0
		asr.l	#1,d1
		add.l	d0,d4
		add.l	d1,d5
		swap	d4
		swap	d5
		add.w	swing_orig_y(a0),d4
		add.w	swing_orig_x(a0),d5
		move.w	d4,obY(a0)
		move.w	d5,obX(a0)
		rts

.fallbackSingle:
		moveq	#0,d4
		move.w	swing_radius(a0),d4
		move.l	d4,d5
		muls.w	d0,d4
		asr.l	#8,d4
		muls.w	d1,d5
		asr.l	#8,d5
		add.w	d2,d4
		add.w	d3,d5
		move.w	d4,obY(a0)
		move.w	d5,obX(a0)
.return:	rts
; ---------------------------------------------------------------------------

Obj15_ChkDel:
		out_of_range.s	Obj15_DelAll,swing_orig_x(a0)
Obj15_Display:	bra.w	DisplaySprite
; ---------------------------------------------------------------------------

Obj15_DelAll:
		movea.l	swing_helper_ptr(a0),a1
		beq.s	.noHelper
		bsr.w	DeleteObject2
.noHelper:	bra.w	DeleteObject
; ===========================================================================