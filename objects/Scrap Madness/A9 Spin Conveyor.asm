; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 6F - spinning platforms that move around a conveyor belt (SBZ)
; 
; Note: this is pretty much an edited copy-paste of Object 63 (LZ conveyor)!
; ---------------------------------------------------------------------------

SMZ_SpinConvey:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SMZ_SpinC_Index(pc,d0.w),d1
		jsr	SMZ_SpinC_Index(pc,d1.w)

		out_of_range2	.outOfRange,SMZ_spinc_baseX(a0)	; has platform gone out of range? if yes, branch

	.display:
		jmp	(DisplaySprite).l			; display platform object
; ---------------------------------------------------------------------------

.outOfRange:
		jmp (UnloadObject).l
SMZ_SpinC_Index:	dc.w SMZ_SpinC_Main-SMZ_SpinC_Index
		dc.w SMZ_SpinC_Solid-SMZ_SpinC_Index

; Note: This entire object is pretty much a modified copy-paste job of
; the LZ conveyor belt (Object 63), even calling some of its subroutines.
; As such not only are all its SSTs reused, some of them also MUST stay
; the same to function properly!
SMZ_spinc_groupid:		equ objoff_2F	; copy of obSubtype from the initial group spawner
SMZ_spinc_baseX:		equ objoff_30	; initial X-position for entire group (roughly in the center)
SMZ_spinc_nextX:		equ objoff_34	; next target X-position (=objoff_34)
SMZ_spinc_nextY:		equ objoff_36	; next target Y-position (=objoff_36)
SMZ_spinc_posindex:		equ objoff_38	; index of next corner
SMZ_spinc_count:		equ objoff_39	; number of entries in group (multiplied by 4)
SMZ_spinc_increment:	equ objoff_3A	; value to increment to next entry in group (+4 or -4)
SMZ_spinc_reversed:		equ objoff_3B	; (unused in SBZ) flag set if conveyor direction is currently reversed
SMZ_spinc_targetdata:	equ objoff_3C	; pointer to corner data for group
; ===========================================================================

SMZ_SpinC_Main:	; Routine 0
		move.b	obSubtype(a0),d0			; is this the initial spawner object?
		andi.b	#$7F,d0			; if yes, branch

		; Object is a platform (from custom objpos data)
		addq.b	#2,obRoutine(a0)			; advance to SMZ_SpinC_Solid
		move.l	#Map_SMZ_Spin,obMap(a0)
		move.b #Map_SMZ_Spin_height,height_pixels(a0)			; set mappings
		move.w #ArtTile_SMZ_Atlas,obGfx(a0) ; set art tile
		move.b	#32/2,obActWid(a0)			; set sprite display width
		ori.b	#4,obRender(a0)		; set to playfield-positioned mode
		move.w #$200,obPriority(a0)			; set sprite priority

		moveq	#0,d0					; clear d0
		move.b	obSubtype(a0),d0			; get subtype of platform (stored in custom objpos data)
		move.w	d0,d1					; backup for later
		lsr.w	#3,d0					; read only upper digit, multiplied by 2
		andi.w	#$1E,d0					; limit to sane values
		lea	SMZ_SpinC_Data(pc),a2			; load platform target coordinate data
		adda.w	(a2,d0.w),a2				; advance to data set for current group
		move.w	(a2)+,SMZ_spinc_posindex(a0)		; set SMZ_spinc_posindex to zero ($38) and write group entry count to SMZ_spinc_count ($39)
		move.w	(a2)+,SMZ_spinc_baseX(a0)			; retrieve base X-position
		move.l	a2,SMZ_spinc_targetdata(a0)			; store address pointing to first actual entry in group

		andi.w	#$F,d1					; read only lower digit of platform subtype
		lsl.w	#2,d1					; multiply by 4 bytes per entry
		move.b	d1,SMZ_spinc_posindex(a0)			; set initial index in target positioning data specified by subtype
		move.b	#4,SMZ_spinc_increment(a0)			; set increment value forwards (4 bytes per entry)

		tst.b	(f_conveyrev).w				; is conveyor direction currently (globally) reversed?
		beq.s	.finishPlatform				; if not, branch
		move.b	#1,SMZ_spinc_reversed(a0)			; set movement-reversed flag
		neg.b	SMZ_spinc_increment(a0)			; set increment value backwards (-4)
		moveq	#0,d1					; clear d1
		move.b	SMZ_spinc_posindex(a0),d1			; get initial index for target positioning data
		add.b	SMZ_spinc_increment(a0),d1			; go to previous entry (-4 since it's reversed)
		cmp.b	SMZ_spinc_count(a0),d1			; has new index exceeded group size?
		bcs.s	.setTargetIndex				; if not, branch

		; This was probably copy-pasted from spinc_Platform_Update, seeing how it
		; still checks for non-reversed movement despite not being possible here.
		move.b	d1,d0					; backup for reversal check
		moveq	#0,d1					; reset corner index to 0 (not reversed)
		tst.b	d0					; is movement currently reversed? (...it always is at this point)
		bpl.s	.setTargetIndex				; if not, branch
		move.b	SMZ_spinc_count(a0),d1			; reset corner entry to last entry (reversed)
		subq.b	#4,d1					; indices are 0-based
	.setTargetIndex:
		move.b	d1,SMZ_spinc_posindex(a0)			; remember new index in target data

	.finishPlatform:
		move.w	(a2,d1.w),SMZ_spinc_nextX(a0)		; retrieve first target X-position for platform
		move.w	2(a2,d1.w),SMZ_spinc_nextY(a0)		; retrieve first target Y-position for platform

		; Ensure platforms on the upper path never start in the spinning state.
		move.b	#1,obAnim(a0)				; set "still" animation
		cmpi.w	#4*2,d1					; is platform at or past third corner?
		blo.s	.initMovement				; if not, branch
		move.b	#0,obAnim(a0)				; set "spinning" animation

	.initMovement:
		bsr.w	SMZ_LCon_ChangeDir				; initialize platform's speeds for first target (calling Object 63)
		bra.w	SMZ_SpinC_Solid				; go to main platform logic
; ===========================================================================

SMZ_SpinC_Solid:	; Routine 2
		lea	(SMZ_Ani_SpinConvey).l,a1			; load animation scripts for spinning SBZ platforms
		jsr	(AnimateSprite).l			; advance animation
		tst.b	obFrame(a0)				; is new frame = 0? (platform upright)
		bne.s	.spinning				; if not, make platform non-solid

		move.w	obX(a0),-(sp)				; backup previous X-position before calling SMZ_SpinC_Platform_Update
		bsr.w	SMZ_SpinC_Platform_Update			; update platform target movement, if necessary
		move.w	#32/2+sonic_solid_width,d1		; set platform collision width plus Sonic's own collision width
		move.w	#14/2,d2				; set platform collision height (initial)
		move.w	d2,d3					; set platform collision height (stood-on)
		addq.w	#1,d3					; +1px while stood-on
		move.w	(sp)+,d4				; restore previous X-position as input for SolidObject
		jmp (SolidObject).l				; make platform solid
; ---------------------------------------------------------------------------

.spinning:
        jsr (SMZ_ReleaseRiders).l
        bra.w SMZ_SpinC_Platform_Update
SMZ_SpinC_Platform_Update:
		move.w	obX(a0),d0				; get platform's current X-position
		cmp.w	SMZ_spinc_nextX(a0),d0			; is platform at corner? (X-axis)
		bne.s	.updatePos				; if not, branch
		move.w	obY(a0),d0				; get platform's current Y-position
		cmp.w	SMZ_spinc_nextY(a0),d0			; is platform at corner? (Y-axis)
		bne.s	.updatePos				; if not, branch

		moveq	#0,d1					; clear d1
		move.b	SMZ_spinc_posindex(a0),d1			; get current index for target positioning data
		add.b	SMZ_spinc_increment(a0),d1			; go to next entry (+4, or -4 if reversed)
		cmp.b	SMZ_spinc_count(a0),d1			; has new index exceeded group size?
		bcs.s	.getNextTarget				; if not, branch
		move.b	d1,d0					; backup for reversal check
		moveq	#0,d1					; reset corner index to 0 (not reversed)
		tst.b	d0					; is movement currently reversed?
		bpl.s	.getNextTarget				; if not, branch
		move.b	SMZ_spinc_count(a0),d1			; reset corner entry to last entry (reversed)
		subq.b	#4,d1					; indices are 0-based

	.getNextTarget:
		move.b	d1,SMZ_spinc_posindex(a0)			; remember new index in target data

		movea.l	SMZ_spinc_targetdata(a0),a1			; get address pointing to target positions for group
		move.w	(a1,d1.w),SMZ_spinc_nextX(a0)		; retrieve next target X-position for platform
		move.w	2(a1,d1.w),SMZ_spinc_nextY(a0)		; retrieve next target Y-position for platform

		tst.w	d1					; is platform at first corner?
		bne.s	.checkSpinning				; if not, branch
		move.b	#1,obAnim(a0)				; set "still" animation
	.checkSpinning:
		cmpi.w	#4*2,d1					; is platform at third corner?
		bne.s	.changeDir				; if not, branch
		move.b	#0,obAnim(a0)				; set "spinning" animation

	.changeDir:
		bsr.w	SMZ_LCon_ChangeDir				; update platform's speeds for next target

	.updatePos:
		jmp	(SpeedToPos).l				; update platform's current position
; End of function SMZ_SpinC_Platform_Update


; ===========================================================================
; We need to include animations from here to keep the corner data in this file...
; ---------------------------------------------------------------------------
; Animation script - platform on conveyor belt (SBZ)
; ---------------------------------------------------------------------------

SMZ_Ani_SpinConvey:	dc.w SMZ_Ani_SpinConvey_spin-SMZ_Ani_SpinConvey
		dc.w SMZ_Ani_SpinConvey_still-SMZ_Ani_SpinConvey

SMZ_Ani_SpinConvey_spin:		dc.b 0
		dc.b 0, 1, 2, 3, 4
		dc.b 3|$40, 2|$40, 1|$40, 0|$40
		dc.b 1|$20|$40, 2|$20|$40, 3|$20|$40, 4|$20|$40
		dc.b 3|$20, 2|$20, 1|$20, 0
		dc.b afEnd
		even

SMZ_Ani_SpinConvey_still:		dc.b 15
		dc.b 0
		dc.b afEnd
		even



; ===========================================================================
; SMZ_Conveyor belt corner target coordinate definitions.
; Each group corresponds to the lower nybble of the given subtype.
; Format:
; 	dc.w number of entries, times 4
; 	dc.w base X position (used for out_of_range check)
; 	dc.w entries...
; Entries consist of a target X position and target Y position.

SMZ_SpinC_Data:	dc.w .group0-SMZ_SpinC_Data
		dc.w .group1-SMZ_SpinC_Data
		dc.w .group2-SMZ_SpinC_Data
		dc.w .group3-SMZ_SpinC_Data
		dc.w .group4-SMZ_SpinC_Data
		dc.w .group5-SMZ_SpinC_Data

.group0:
		.baseX_0: = $E80
		.baseY_0: = $358
		dc.w 4*4
		dc.w .baseX_0
		dc.w .baseX_0-$6C, .baseY_0+$18
		dc.w .baseX_0+$6F, .baseY_0-$56
		dc.w .baseX_0+$6F, .baseY_0-$18
		dc.w .baseX_0-$6C, .baseY_0+$56

.group1:
		.baseX_1: = $F80
		.baseY_1: = $2C8
		dc.w 4*4
		dc.w .baseX_1
		dc.w .baseX_1-$6C, .baseY_1+$18
		dc.w .baseX_1+$6F, .baseY_1-$56
		dc.w .baseX_1+$6F, .baseY_1-$18
		dc.w .baseX_1-$6C, .baseY_1+$56

.group2:
		.baseX_2: = $1080
		.baseY_2: = $228
		dc.w 4*4
		dc.w .baseX_2
		dc.w .baseX_2-$6C, .baseY_2+$48
		dc.w .baseX_2+$6F, .baseY_2-$26
		dc.w .baseX_2+$6F, .baseY_2+$18
		dc.w .baseX_2-$6C, .baseY_2+$86

.group3:
		.baseX_3: = $F80
		.baseY_3: = $558
		dc.w 4*4
		dc.w .baseX_3
		dc.w .baseX_3-$6C, .baseY_3+$18
		dc.w .baseX_3+$6F, .baseY_3-$56
		dc.w .baseX_3+$6F, .baseY_3-$18
		dc.w .baseX_3-$6C, .baseY_3+$56

.group4:
		.baseX_4: = $1B80
		.baseY_4: = $658
		dc.w 4*4
		dc.w .baseX_4
		dc.w .baseX_4-$6C, .baseY_4+$18
		dc.w .baseX_4+$6F, .baseY_4-$56
		dc.w .baseX_4+$6F, .baseY_4-$18
		dc.w .baseX_4-$6C, .baseY_4+$56

.group5:
		.baseX_5: = $1C80
		.baseY_5: = $5C8
		dc.w 4*4
		dc.w .baseX_5
		dc.w .baseX_5-$6C, .baseY_5+$18
		dc.w .baseX_5+$6F, .baseY_5-$56
		dc.w .baseX_5+$6F, .baseY_5-$18
		dc.w .baseX_5-$6C, .baseY_5+$56

SMZ_LCon_ChangeDir:
		moveq	#0,d0					; clear d0
		move.w	#-$100,d2				; move platforms horizontally at 1px/frame left
		move.w	obX(a0),d0				; get platform's current X-position
		sub.w	SMZ_spinc_nextX(a0),d0			; calculate difference to target X-position
		bcc.s	.calcYDirection				; if platform is right of target, branch
		neg.w	d0					; keep X-position difference positive
		neg.w	d2					; move platforms right instead

	.calcYDirection:
		moveq	#0,d1					; clear d1
		move.w	#-$100,d3				; move platforms vertically at 1px/frame upwards
		move.w	obY(a0),d1				; get platform's current Y-position
		sub.w	SMZ_spinc_nextY(a0),d1			; calculate difference to target Y-position
		bcc.s	.checkGreaterDistance			; if platform is below target, branch
		neg.w	d1					; keep Y-position difference positive
		neg.w	d3					; move platforms down instead

	.checkGreaterDistance:
		cmp.w	d0,d1					; is Y-position difference larger than X-position difference?
		bcs.s	.moveVertical				; if yes, branch

		move.w	obX(a0),d0				; get platform's current X-position
		sub.w	SMZ_spinc_nextX(a0),d0			; calculate signed difference to target X-position
		beq.s	.setSpeedsHorizontal			; if no horizontal movement is needed, branch
		ext.l	d0					; sign-extend difference to long
		asl.l	#8,d0					; shift up a byte (16.16 fixed)
		divs.w	d1,d0					; X-speed = signed X-difference / unsigned Y-difference
		neg.w	d0					; negate result to move towards target position
	.setSpeedsHorizontal:
		move.w	d0,obVelX(a0)				; set platform's horizontal speed (division result)
		move.w	d3,obVelY(a0)				; set platform's vertical speed (1px/frame up or down)
		swap	d0					; move division remainder into lower word (0 if skipped)
		move.w	d0,obX+2(a0)			; use division remainder as initial X-subpixel position
		clr.w	obY+2(a0)				; force initial Y-subpixel position to 0
		rts						; return
; ---------------------------------------------------------------------------

.moveVertical:
		move.w	obY(a0),d1				; get platform's current Y-position
		sub.w	SMZ_spinc_nextY(a0),d1			; calculate signed difference to target Y-position
		beq.s	.setSpeedsVertical			; if no vertical movement is needed, branch
		ext.l	d1					; sign-extend difference to long
		asl.l	#8,d1					; shift up a byte (16.16 fixed)
		divs.w	d0,d1					; Y-speed = signed Y-difference / unsigned X-difference
		neg.w	d1					; negate result to move towards target position
	.setSpeedsVertical:
		move.w	d1,obVelY(a0)				; set platform's vertical speed (division result)
		move.w	d2,obVelX(a0)				; set platform's horizontal speed (1px/frame left or right)
		swap	d1					; move division remainder into lower word (0 if skipped)
		move.w	d1,obY+2(a0)			; use division remainder as initial Y-subpixel position
		clr.w	obX+2(a0)				; force initial X-subpixel position to 0
		rts						; return
