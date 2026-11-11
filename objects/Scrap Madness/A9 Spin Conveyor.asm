; Sonic 1 spinning conveyor, with placement-relative paths and direct states.
; The eight initial phases and division remainders retain the original motion.
; Bit 7 creates the complete loop. Clear it for one platform; bits 0-2 select
; its initial phase. X/Y are the loop center, not an absolute group selector.
; ===========================================================================
SMZ_spinc_baseX:		equ objoff_30
SMZ_spinc_baseY:		equ objoff_32
SMZ_spinc_nextX:		equ objoff_34
SMZ_spinc_nextY:		equ objoff_36
SMZ_spinc_posindex:	equ objoff_38	; target corner offset: 0,4,8,12
SMZ_spinc_increment:	equ objoff_3A	; +4 or -4, wrapped modulo 16
SMZ_spinc_targetdata:	equ objoff_3C	; forward/reverse corner motion table

SMZ_SpinConvey:
		move.w	obX(a0),SMZ_spinc_baseX(a0)
		move.w	obY(a0),SMZ_spinc_baseY(a0)
		out_of_range2	UnloadObject,SMZ_spinc_baseX(a0)
		moveq	#0,d6
		btst	#7,obSubtype+1(a0)
		beq.s	.prepare
		moveq	#7,d6
		; Allocate the whole group or leave the placement intact for retry.
		move.w	d6,d1
		lea	(v_lvlobjspace).w,a1
		move.w	#(v_lvlobjend-v_lvlobjspace)/object_size-1,d0
.count_free:
		tst.l	code(a1)
		bne.s	.next
		subq.w	#1,d1
		beq.s	.prepare
.next:
		lea	object_size(a1),a1
		dbf	d0,.count_free
		rts
.prepare:
		lea	SMZ_SpinC_Placements(pc),a2
		lea	SMZ_SpinC_InitialMotion(pc),a4
		lea	SMZ_SpinC_CornerMotion(pc),a5
		moveq	#4,d5
		tst.b	(f_conveyrev).w
		beq.s	.phase
		lea	8*8(a4),a4
		lea	4*8(a5),a5
		neg.w	d5
.phase:
		tst.w	d6
		bne.s	.first
		move.w	obSubtype(a0),d0
		andi.w	#7,d0
		move.w	d0,d1
		lsl.w	#3,d0
		adda.w	d0,a4
		add.w	d1,d1
		sub.w	d1,d0		; phase*6 offset into the position table
		adda.w	d0,a2
.first:
		lea	(v_lvlobjspace).w,a3
		movea.l	a0,a1
.make_platform:
		move.w	SMZ_spinc_baseX(a0),d0
		move.w	d0,SMZ_spinc_baseX(a1)
		add.w	(a2)+,d0
		move.w	d0,obX(a1)
		move.w	SMZ_spinc_baseY(a0),d0
		move.w	d0,SMZ_spinc_baseY(a1)
		add.w	(a2)+,d0
		move.w	d0,obY(a1)
		move.w	(a2)+,d1
		move.w	d1,obSubtype(a1)
		lsl.w	#2,d1
		tst.w	d5
		bpl.s	.target
		subq.w	#4,d1
		andi.w	#$F,d1
.target:
		move.b	d1,SMZ_spinc_posindex(a1)
		move.b	d5,SMZ_spinc_increment(a1)
		move.l	a5,SMZ_spinc_targetdata(a1)
		lea	SMZ_SpinC_Corners(pc),a6
		move.w	SMZ_spinc_baseX(a1),d0
		add.w	(a6,d1.w),d0
		move.w	d0,SMZ_spinc_nextX(a1)
		move.w	SMZ_spinc_baseY(a1),d0
		add.w	2(a6,d1.w),d0
		move.w	d0,SMZ_spinc_nextY(a1)
		move.l	(a4)+,obVelX(a1)
		move.w	(a4)+,obX+2(a1)
		move.w	(a4)+,obY+2(a1)
		move.b	#1,obAnim(a1)
		cmpi.b	#8,d1
		blo.s	.art
		clr.b	obAnim(a1)
.art:
		move.l	#Map_SMZ_Spin,obMap(a1)
		move.b	#Map_SMZ_Spin_height,height_pixels(a1)
		move.w	#ArtTile_SMZ_Atlas,obGfx(a1)
		move.b	#16,obActWid(a1)
		ori.b	#4,obRender(a1)
		move.w	#$200,obPriority(a1)
		move.l	#SMZ_SpinC_Move,code(a1)
		dbf	d6,.allocate
		rts
.allocate:
		; One forward scan keeps FindFreeObj's lowest-slot order without
		; restarting from the beginning for every helper.
		movea.l	a3,a1
		lea	object_size(a3),a3
		tst.l	code(a1)
		bne.s	.allocate
		bra.w	.make_platform

SMZ_SpinC_Move:
		lea	(SMZ_Ani_SpinConvey).l,a1
		jsr	(AnimateSprite).l
		tst.b	obFrame(a0)
		bne.s	.spinning
		move.w	obX(a0),-(sp)
		bsr.s	SMZ_SpinC_Platform_Update
		move.w	#16+sonic_solid_width,d1
		moveq	#7,d2
		moveq	#8,d3
		move.w	(sp)+,d4
		jsr	(SolidObject).l
		bra.s	.display
.spinning:
		jsr	(SMZ_ReleaseRiders).l
		bsr.s	SMZ_SpinC_Platform_Update
.display:
		out_of_range2	UnloadObject,SMZ_spinc_baseX(a0)
		jmp	(DisplaySprite).l

SMZ_SpinC_Platform_Update:
		move.w	obX(a0),d0
		cmp.w	SMZ_spinc_nextX(a0),d0
		bne.s	.updatePos
		move.w	obY(a0),d0
		cmp.w	SMZ_spinc_nextY(a0),d0
		bne.s	.updatePos
		moveq	#0,d1
		move.b	SMZ_spinc_posindex(a0),d1
		add.b	SMZ_spinc_increment(a0),d1
		andi.w	#$F,d1
		move.b	d1,SMZ_spinc_posindex(a0)
		lea	SMZ_SpinC_Corners(pc),a1
		move.w	SMZ_spinc_baseX(a0),d0
		add.w	(a1,d1.w),d0
		move.w	d0,SMZ_spinc_nextX(a0)
		move.w	SMZ_spinc_baseY(a0),d0
		add.w	2(a1,d1.w),d0
		move.w	d0,SMZ_spinc_nextY(a0)
		tst.w	d1
		bne.s	.checkSpinning
		move.b	#1,obAnim(a0)
.checkSpinning:
		cmpi.w	#8,d1
		bne.s	.motion
		clr.b	obAnim(a0)
.motion:
		movea.l	SMZ_spinc_targetdata(a0),a1
		add.w	d1,d1
		move.l	(a1,d1.w),obVelX(a0)
		move.w	4(a1,d1.w),obX+2(a0)
		move.w	6(a1,d1.w),obY+2(a0)
.updatePos:
		jmp	(SpeedToPos).l

SMZ_Ani_SpinConvey:
		dc.w	SMZ_Ani_SpinConvey_spin-SMZ_Ani_SpinConvey
		dc.w	SMZ_Ani_SpinConvey_still-SMZ_Ani_SpinConvey
SMZ_Ani_SpinConvey_spin:
		dc.b	0
		dc.b	0,1,2,3,4
		dc.b	3|$40,2|$40,1|$40,0|$40
		dc.b	1|$20|$40,2|$20|$40,3|$20|$40,4|$20|$40
		dc.b	3|$20,2|$20,1|$20,0,afEnd
		even
SMZ_Ani_SpinConvey_still:
		dc.b	15,0,afEnd
		even

; One set of offsets serves all six original loops and arbitrary placements.
; Relative X, relative Y, initial target corner. Also read by SonLVL.
SMZ_SpinC_Placements:
		dc.w	-108,24,0
		dc.w	-38,-11,1
		dc.w	32,-46,1
		dc.w	103,-81,1
		dc.w	111,-24,2
		dc.w	41,11,3
		dc.w	-29,46,3
		dc.w	-100,81,3
SMZ_SpinC_Corners:
		dc.w	-108,24,111,-86,111,-24,-108,86

; X/Y velocity, X/Y fractional position. Exact original DIVS results, including
; signed remainders; zeroing the remainders changes the loop's motion/timing.
SMZ_SpinC_InitialMotion:
		dc.w	$0000,$FF00,$0000,$0000
		dc.w	$0100,$FF80,$0000,$0080
		dc.w	$0100,$FF7F,$0000,$0031
		dc.w	$0100,$FF60,$0000,$0000
		dc.w	$0000,$FF00,$0000,$0000
		dc.w	$FF00,$0080,$0000,$FF80
		dc.w	$FF00,$0081,$0000,$FFCF
		dc.w	$FF00,$00A0,$0000,$0000
		dc.w	$0000,$0100,$0000,$0000
		dc.w	$FF00,$0080,$0000,$0000
		dc.w	$FF00,$0080,$0000,$0000
		dc.w	$FF00,$007F,$0000,$FFAD
		dc.w	$0000,$FF00,$0000,$0000
		dc.w	$0100,$FF80,$0000,$0000
		dc.w	$0100,$FF80,$0000,$0000
		dc.w	$0100,$FF81,$0000,$0053
SMZ_SpinC_CornerMotion:
		dc.w	$0000,$FF00,$0000,$0000
		dc.w	$0100,$FF80,$0000,$0080
		dc.w	$0000,$0100,$0000,$0000
		dc.w	$FF00,$0080,$0000,$FF80
		dc.w	$FF00,$0080,$0000,$FF80
		dc.w	$0000,$FF00,$0000,$0000
		dc.w	$0100,$FF80,$0000,$0080
		dc.w	$0000,$0100,$0000,$0000
