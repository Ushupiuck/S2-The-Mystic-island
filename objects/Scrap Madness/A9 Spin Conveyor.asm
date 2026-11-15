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
		move.w	obSubtype(a0),d0
		btst	#8,d0	; subtype bit 8: MMZ curve/fixed variant
		bne.w	MMZ_SpinC_Init
		cmpi.b	#id_MMZ,(v_zone).w
		beq.w	MMZ_SpinC_Init
		move.w	obX(a0),SMZ_spinc_baseX(a0)
		move.w	obY(a0),SMZ_spinc_baseY(a0)
		out_of_range2	UnloadObject,SMZ_spinc_baseX(a0)
		moveq	#0,d6
		move.w	obSubtype(a0),d2
		btst	#7,d2
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

; ---------------------------------------------------------------------------
; MMZ's fixed flippers and five-member curved conveyor share the platform
; cohort service. The SBZ rectangle above retains its exact original motion.
MMZ_SpinC_Init:
		lea	MMZ_SpinC_FixedOne(pc),a2
		lea	MMZ_SpinC_Wait(pc),a4
		moveq	#0,d6
		move.w	obSubtype(a0),d0
		btst	#0,d0
		bne.s	.loop
		btst	#1,d0
		beq.s	.make
		lea	MMZ_SpinC_FixedTwo(pc),a2
		moveq	#1,d6
		bra.s	.make
.loop:
		lea	MMZ_SpinC_Loop(pc),a2
		lea	MMZ_SpinC_MoveSolid(pc),a4
		moveq	#4,d6
.make:
		lea	Map_MMZ_Spin(pc),a5
		moveq	#Map_MMZ_Spin_height,d5
		bsr.w	MMZ_Platform_CreateGroup
		bne.s	.return
		move.w	obSubtype(a0),d0
		btst	#0,d0
		beq.s	.draw
; Start each member at its own curve point, without a one-frame pile-up or
; a spurious birth velocity. Keep its phase for the first ordinary update.
		movea.l	a0,a5
		lea	MMZ_group_members(a0),a3
		moveq	#4,d5
.position:
		bsr.w	MMZ_SpinC_Move
		subq.w	#1,MMZ_group_phase(a0)
		clr.w	obVelX(a0)
		dbf	d5,.next
		movea.l	a5,a0
.draw:
		bra.w	MMZ_Platform_Draw
.next:
		movea.w	(a3)+,a0
		bra.s	.position
.return:
		rts

MMZ_SpinC_Wait:
		moveq	#16,d1
		moveq	#5,d3
		move.w	obX(a0),d4
		jsr	(PlatformObject).l
		subq.w	#1,MMZ_group_timer(a0)
		bne.s	.return
		move.l	#MMZ_SpinC_FixedSpin,MMZ_group_state(a0)
		move.l	#MMZ_SpinC_Frames,MMZ_group_script(a0)
		clr.b	MMZ_group_dwell(a0)
		jmp	(SMZ_ReleaseRiders).l
.return:
		rts

MMZ_SpinC_FixedSpin:
		bsr.w	MMZ_Platform_Animate
		bne.s	.return
		move.l	#MMZ_SpinC_Wait,MMZ_group_state(a0)
		move.w	#120,MMZ_group_timer(a0)
.return:
		rts

MMZ_SpinC_MoveSolid:
		bsr.s	MMZ_SpinC_Move
		moveq	#16,d1
		moveq	#5,d3
		jsr	(PlatformObject).l
		cmpi.w	#344,MMZ_group_phase(a0)
		bne.s	.return
		move.w	#216,MMZ_group_timer(a0)
		move.l	#MMZ_SpinC_MoveSpin,MMZ_group_state(a0)
		clr.w	MMZ_group_phase+2(a0) ; private accumulator, never a word over obFrame
		jmp	(SMZ_ReleaseRiders).l
.return:
		rts

MMZ_SpinC_MoveSpin:
		bsr.s	MMZ_SpinC_Move
		subq.w	#1,MMZ_group_timer(a0)
		bmi.s	.done
		move.w	MMZ_group_phase+2(a0),d0
		addi.w	#$80,d0
		cmpi.w	#$500,d0
		bls.s	.frame
		moveq	#0,d0
.frame:
		move.w	d0,MMZ_group_phase+2(a0)
		lsr.w	#8,d0
		move.b	d0,obFrame(a0)
		rts
.done:
		clr.b	obFrame(a0)
		move.l	#MMZ_SpinC_MoveSolid,MMZ_group_state(a0)
		rts

; The source curve is exactly antisymmetric. Store 223 signed XY byte pairs;
; its second half mirrors the first, saving 446 ROM bytes without division.
; d4 returns the previous X for PlatformObject's rider displacement.
MMZ_SpinC_Move:
		move.w	obX(a0),d4
		move.w	MMZ_group_phase(a0),d0
		moveq	#0,d3
		cmpi.w	#223,d0
		blo.s	.index
		subi.w	#223,d0
		moveq	#-1,d3
.index:
		add.w	d0,d0
		lea	MMZ_SpinC_Path(pc),a1
		move.b	(a1,d0.w),d1
		ext.w	d1
		move.b	1(a1,d0.w),d2
		ext.w	d2
		tst.w	d3
		beq.s	.position
		neg.w	d1
		neg.w	d2
.position:
		add.w	MMZ_group_x(a0),d1
		add.w	MMZ_group_y(a0),d2
		move.w	d1,obX(a0)
		move.w	d2,obY(a0)
		sub.w	d4,d1
		lsl.w	#8,d1
		move.w	d1,obVelX(a0)
		addq.w	#1,MMZ_group_phase(a0)
		cmpi.w	#446,MMZ_group_phase(a0)
		blo.s	.return
		clr.w	MMZ_group_phase(a0)
.return:
		rts

MMZ_SpinC_FixedOne:	dc.w 120,0,0,0
MMZ_SpinC_FixedTwo:	dc.w 120,0,0,0,120,32,0,0
MMZ_SpinC_Loop:
		dc.w 0,0,0,0,0,0,0,89,0,0,0,178,0,0,0,267,0,0,0,356
MMZ_SpinC_Frames:
		dc.b 1,1,1,2,1,3,1,4,1,5,1,6,1,1,1,2,1,3,1,4,1,5,1,0
MMZ_SpinC_Path:
		dc.b $00,$1A,$FF,$19,$FE,$19,$FD,$18,$FC,$18,$FB,$17,$FA,$17,$F9,$16
		dc.b $F8,$16,$F7,$15,$F6,$15,$F5,$14,$F4,$14,$F3,$13,$F2,$13,$F1,$12
		dc.b $F0,$12,$EF,$11,$EE,$11,$ED,$10,$EC,$10,$EB,$0F,$EA,$0F,$E9,$0E
		dc.b $E8,$0E,$E7,$0D,$E6,$0D,$E5,$0C,$E4,$0C,$E3,$0B,$E2,$0B,$E1,$0A
		dc.b $E0,$0A,$DF,$09,$DE,$09,$DD,$08,$DC,$08,$DB,$07,$DA,$07,$D9,$06
		dc.b $D8,$06,$D7,$05,$D6,$05,$D5,$04,$D4,$04,$D3,$03,$D2,$03,$D1,$02
		dc.b $D0,$02,$CF,$01,$CE,$01,$CD,$00,$CC,$00,$CB,$FF,$CA,$FF,$C9,$FE
		dc.b $C8,$FE,$C7,$FD,$C6,$FD,$C5,$FC,$C4,$FC,$C3,$FB,$C2,$FB,$C1,$FA
		dc.b $C0,$FA,$BF,$F9,$BE,$F9,$BD,$F8,$BC,$F8,$BB,$F7,$BA,$F7,$B9,$F6
		dc.b $B8,$F6,$B7,$F5,$B6,$F5,$B5,$F4,$B4,$F4,$B3,$F3,$B2,$F3,$B1,$F2
		dc.b $B0,$F2,$AF,$F1,$AE,$F1,$AD,$F0,$AC,$F0,$AB,$EF,$AA,$EF,$A9,$EE
		dc.b $A8,$EE,$A7,$ED,$A6,$ED,$A5,$EC,$A4,$EB,$A3,$EA,$A2,$E9,$A1,$E8
		dc.b $A0,$E7,$9F,$E6,$9E,$E5,$9D,$E4,$9D,$E3,$9C,$E2,$9C,$E1,$9C,$E0
		dc.b $9B,$DF,$9B,$DE,$9B,$DD,$9A,$DC,$9A,$DB,$9A,$DA,$9A,$D9,$9A,$D8
		dc.b $9A,$D7,$9A,$D6,$9A,$D5,$9A,$D4,$9A,$D3,$9B,$D2,$9B,$D1,$9B,$D0
		dc.b $9C,$CF,$9C,$CE,$9C,$CD,$9D,$CC,$9E,$CB,$9E,$CA,$9F,$C9,$A0,$C8
		dc.b $A1,$C7,$A2,$C6,$A3,$C5,$A4,$C4,$A5,$C4,$A6,$C3,$A7,$C3,$A8,$C3
		dc.b $A9,$C2,$AA,$C2,$AB,$C2,$AC,$C1,$AD,$C1,$AE,$C1,$AF,$C1,$B0,$C1
		dc.b $B1,$C1,$B2,$C1,$B3,$C1,$B4,$C1,$B5,$C1,$B6,$C1,$B7,$C1,$B8,$C2
		dc.b $B9,$C2,$BA,$C2,$BB,$C3,$BC,$C3,$BD,$C4,$BE,$C4,$BF,$C5,$C0,$C5
		dc.b $C1,$C6,$C2,$C6,$C3,$C7,$C4,$C7,$C5,$C8,$C6,$C8,$C7,$C9,$C8,$C9
		dc.b $C9,$CA,$CA,$CA,$CB,$CB,$CC,$CB,$CD,$CC,$CE,$CC,$CF,$CD,$D0,$CD
		dc.b $D1,$CE,$D2,$CE,$D3,$CF,$D4,$CF,$D5,$D0,$D6,$D0,$D7,$D1,$D8,$D1
		dc.b $D9,$D2,$DA,$D2,$DB,$D3,$DC,$D3,$DD,$D4,$DE,$D4,$DF,$D5,$E0,$D5
		dc.b $E1,$D6,$E2,$D6,$E3,$D7,$E4,$D7,$E5,$D8,$E6,$D8,$E7,$D9,$E8,$D9
		dc.b $E9,$DA,$EA,$DA,$EB,$DB,$EC,$DB,$ED,$DC,$EE,$DC,$EF,$DD,$F0,$DD
		dc.b $F1,$DE,$F2,$DE,$F3,$DF,$F4,$DF,$F5,$E0,$F6,$E0,$F7,$E1,$F8,$E1
		dc.b $F9,$E2,$FA,$E2,$FB,$E3,$FC,$E3,$FD,$E4,$FE,$E4,$FF,$E5
		even
Map_MMZ_Spin:	binclude "mappings/sprite/MMZ Spin.bin"
		even
