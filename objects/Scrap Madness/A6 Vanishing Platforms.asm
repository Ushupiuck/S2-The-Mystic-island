; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 6C - vanishing platforms (SBZ)
; ---------------------------------------------------------------------------

SMZ_VanishPlatform:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SMZ_VanP_Index(pc,d0.w),d1
		jmp	SMZ_VanP_Index(pc,d1.w)
; ===========================================================================
SMZ_VanP_Index:	dc.w SMZ_VanP_Main-SMZ_VanP_Index
		dc.w SMZ_VanP_Detect-SMZ_VanP_Index
		dc.w SMZ_VanP_StoodOn-SMZ_VanP_Index
		dc.w SMZ_VanP_Sync-SMZ_VanP_Index

SMZ_vanp_timer:	equ objoff_30	; counter for time until event
SMZ_vanp_timelen:	equ objoff_32	; time between events (general)
SMZ_vanp_syncoffset:equ objoff_36	; offset to synchronize multiple platforms to level frame counter (multiples of $80)
SMZ_vanp_syncmask:	equ objoff_38	; level frame counter synchronization bit mask to check if platform should toggle
; ===========================================================================

SMZ_VanP_Main:	; Routine 0
		addq.b	#6,obRoutine(a0)			; advance to SMZ_VanP_Sync
		move.l	#Map_SMZ_VanP,obMap(a0)
		move.b #Map_SMZ_VanP_height,height_pixels(a0)			; set mappings
		move.w #ArtTile_SMZ_Atlas,obGfx(a0) ; set art tile and palette line
		ori.b	#4,obRender(a0)		; set to playfield-positioned mode
		move.b	#32/2,obActWid(a0)			; set sprite display width and solidity width
		move.w #$200,obPriority(a0)			; set sprite priority

		moveq	#0,d0					; clear d0
		move.b	obSubtype(a0),d0			; get object subtype
		andi.w	#$0F,d0					; read only the lower digit
		addq.w	#1,d0					; make value 1-based
		lsl.w	#7,d0					; multiply by $80
		move.w	d0,d1					; copy for below
		subq.w	#1,d0					; make value 0-based again
		move.w	d0,SMZ_vanp_timer(a0)			; set initial timer
		move.w	d0,SMZ_vanp_timelen(a0)			; also store as base reset time

		moveq	#0,d0					; clear d0
		move.b	obSubtype(a0),d0			; get object subtype again
		andi.w	#$F0,d0					; read only the upper digit
		addi.w	#$80,d1					; add a static $80 to earlier result
		mulu.w	d1,d0					; multiply upper subtype digit by lower one (multiples of $80)
		lsr.l	#8,d0					; divide by $100
		move.w	d0,SMZ_vanp_syncoffset(a0)			; set level timer offset for this platform
		subq.w	#1,d1					; subtract 1 for bitmask check
		move.w	d1,SMZ_vanp_syncmask(a0)			; set synchronization toggle bitmask
; ---------------------------------------------------------------------------

; loc_16068:
SMZ_VanP_Sync:	; Routine 6
		move.w	(v_framecount).w,d0			; get current level frame counter
		sub.w	SMZ_vanp_syncoffset(a0),d0			; subtract level timer offset for this platform
		and.w	SMZ_vanp_syncmask(a0),d0			; check against bitmask
		bne.s	.animate				; if it's not 0, don't toggle platform

		subq.b	#4,obRoutine(a0)			; goto SMZ_VanP_Detect next
		bra.s	SMZ_VanP_Detect				; go there immediately
; ===========================================================================

	.animate:
		lea	(SMZ_Ani_Van).l,a1				; load animation script
		jsr	(AnimateSprite).l			; (stays on final animation frame indefinitely)
		jmp (RememberState).l				; display sprite, or delete if offscreen
; ===========================================================================

; VanP_Vanish: VanP_Appear:
SMZ_VanP_Detect:	; Routine 2
SMZ_VanP_StoodOn:	; Routine 4
		subq.w	#1,SMZ_vanp_timer(a0)			; decrement timer
		bpl.s	.animate				; if time remains, branch
		move.w	#$80-1,SMZ_vanp_timer(a0)			; reset timer (while vanishing)

		tst.b	obAnim(a0)				; is platform vanishing? (animation ID 0)
		beq.s	.toggleAnimation			; if yes, branch
		move.w	SMZ_vanp_timelen(a0),SMZ_vanp_timer(a0)		; reset timer (while visible)

	.toggleAnimation:
		bchg	#0,obAnim(a0)				; alternate between animation 0 and 1
; ---------------------------------------------------------------------------

.animate:
		lea	(SMZ_Ani_Van).l,a1				; load animation script
		jsr	(AnimateSprite).l			; (stays on final animation frame indefinitely)

		btst	#1,obFrame(a0)				; is platform visible? (frame IDs 1 and 3)
		bne.s	.notSolid				; if not, don't make solid

        moveq #27,d1
        moveq #8,d2
        moveq #9,d3
        move.w obX(a0),d4
        jsr (SolidObject).l
        jmp (RememberState).l
.notSolid:
        jsr (SMZ_ReleaseRiders).l
        jmp (RememberState).l

SMZ_Ani_Van:	dc.w SMZ_Ani_Van_vanish-SMZ_Ani_Van
		dc.w SMZ_Ani_Van_appear-SMZ_Ani_Van

SMZ_Ani_Van_vanish:	dc.b 7
		dc.b 0, 1, 2
		dc.b 3
		dc.b afBack, 1
		even

SMZ_Ani_Van_appear:	dc.b 7
		dc.b 3, 2, 1
		dc.b 0
		dc.b afBack, 1
		even

Map_SMZ_VanP: binclude "mappings/sprite/SMZ VanP.bin"
