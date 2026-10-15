; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 69 - stationary spinning platforms and trapdoors (SBZ)
; ---------------------------------------------------------------------------

SMZ_SpinPlatform:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SMZ_Spin_Index(pc,d0.w),d1
		jmp	SMZ_Spin_Index(pc,d1.w)
; ===========================================================================
SMZ_Spin_Index:	dc.w SMZ_Spin_Main-SMZ_Spin_Index
		dc.w SMZ_Spin_Trapdoor-SMZ_Spin_Index
		dc.w SMZ_Spin_Spinner-SMZ_Spin_Index

SMZ_spin_timer:	equ objoff_30	; counter for time until event
SMZ_spin_timelen:	equ objoff_32	; time between changes (general)
SMZ_spin_spinning:	equ objoff_34	; flag set while platform is spinning
SMZ_spin_syncmask:	equ objoff_36	; level frame counter synchronization bit mask to check if platform should start spinning
; ===========================================================================

SMZ_Spin_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)			; advance to SMZ_Spin_Trapdoor
		move.l	#Map_SMZ_Trap,obMap(a0)
		move.b #Map_SMZ_Trap_height,height_pixels(a0)			; set mappings
		move.w #ArtTile_SMZ_Atlas,obGfx(a0) ; set art tile and palette line
		ori.b	#4,obRender(a0)		; set to playfield-positioned mode
		move.b	#128/2,obActWid(a0)			; set sprite display width (corrected)

		moveq	#0,d0					; clear d0
		move.b	obSubtype(a0),d0			; get object subtype
		andi.w	#$0F,d0					; read only the lower digit
		mulu.w	#60,d0					; multiply by 60 frames (1 second)
		move.w	d0,SMZ_spin_timelen(a0)			; set trapdoor open/close delay timer

	; Set up spinning platforms...
		tst.b	obSubtype(a0)				; is subtype at least $80? (spinning platforms)
		bpl.s	SMZ_Spin_Trapdoor				; if not, branch (object is a trapdoor)
		addq.b	#2,obRoutine(a0)			; advance to SMZ_Spin_Spinner
		move.l	#Map_SMZ_Spin,obMap(a0)
		move.b #Map_SMZ_Spin_height,height_pixels(a0)			; set alternate mappings
		move.w #ArtTile_SMZ_Atlas,obGfx(a0) ; set alternate art tile
		move.b	#32/2,obActWid(a0)			; set alternate sprite display width
		move.b	#2,obAnim(a0)				; use spinning platforms animations

		moveq	#0,d0					; clear d0
		move.b	obSubtype(a0),d0			; get object subtype
		move.w	d0,d1					; backup subtype for below
		andi.w	#$0F,d0					; read only the lower digit
		mulu.w	#6,d0					; multiply by 6 frames
		move.w	d0,SMZ_spin_timer(a0)			; set initial timer
		move.w	d0,SMZ_spin_timelen(a0)			; also store as base reset time

		andi.w	#$70,d1					; limit upper subtype nybble to 0-7
		addi.w	#$10,d1					; add 1 to upper digit
		lsl.w	#2,d1					; multiply by 4
		subq.w	#1,d1					; subtract 1 to turn into bitmask
		move.w	d1,SMZ_spin_syncmask(a0)			; set synchronization toggle bitmask

		bra.w	SMZ_Spin_Spinner				; go straight to spinning platform logic
; ===========================================================================

SMZ_Spin_Trapdoor:	; Routine 2
		subq.w	#1,SMZ_spin_timer(a0)			; decrement timer
		bpl.s	.animate				; if time remains, branch

		move.w	SMZ_spin_timelen(a0),SMZ_spin_timer(a0)		; reset trapdoor timer
		bchg	#0,obAnim(a0)				; toggle between open/close trapdoor animations
		tst.b	obRender(a0)				; was trapdoor on screen as it toggled?
		bpl.s	.animate				; if not, branch
		move.w	#sfx_Door,d0				; set flapping door sound
		jsr	(PlaySound_Special).l				; play it

	.animate:
		lea	(SMZ_Ani_Spin).l,a1				; load animation scripts
		jsr	(AnimateSprite).l			; (animations stay on last trapdoor frame indefinitely)

		tst.b	obFrame(a0)				; is frame number 0 displayed? (trapdoor fully closed)
		bne.s	.notSolid				; if not, branch
		move.w	#128/2+sonic_solid_width,d1		; collision width
		move.w	#24/2,d2				; collision height (initial)
		move.w	d2,d3					; collision height (stood-on)
		addq.w	#1,d3					; +1px for stood-on height
		move.w	obX(a0),d4				; collision X-position (stood-on)
		; On closure, feet near the top must land before the full solid
		; resolves a shallow edge overlap as a wall. Keep underside solidity.
		movem.l	d1-d4,-(sp)
		move.w	d2,d3				; initial top; the ride offset includes the extra pixel
		jsr	(PlatformObject).l
		movem.l	(sp)+,d1-d4
		jsr (SolidObject).l				; make trapdoor solid

		jmp (RememberState).l				; display trapdoor, or delete it if out of range
; ---------------------------------------------------------------------------

.notSolid:
        jsr (SMZ_ReleaseRiders).l
        jmp (RememberState).l

SMZ_Spin_Spinner:	; Routine 4
		move.w	(v_framecount).w,d0			; get current level frame counter
		and.w	SMZ_spin_syncmask(a0),d0			; check against bitmask
		bne.s	.checkSpinStart				; if it's not 0, don't spin platform
		move.b	#1,SMZ_spin_spinning(a0)			; set flag to start spinning platform

	.checkSpinStart:
		tst.b	SMZ_spin_spinning(a0)			; is platform set to spin?
		beq.s	.animate				; if not, branch
		subq.w	#1,SMZ_spin_timer(a0)			; decrement timer to spin
		bpl.s	.animate				; if time remains, branch
		move.w	SMZ_spin_timelen(a0),SMZ_spin_timer(a0)		; reset spinning timer
		clr.b	SMZ_spin_spinning(a0)			; clear spinning flag
		bchg	#0,obAnim(a0)				; toggle between animation 1 and 2 to start spinning (they are otherwise identical)

	.animate:
		lea	(SMZ_Ani_Spin).l,a1				; load animation scripts
		jsr	(AnimateSprite).l			; (animations stay on last frame (ID 0) indefinitely)

		tst.b	obFrame(a0)				; is frame number 0 displayed? (platform not spinning)
		bne.s	.notSolid				; if not, branch
		move.w	#32/2+sonic_solid_width,d1		; collision width
		move.w	#14/2,d2				; collision height (initial)
		move.w	d2,d3					; collision height (stood-on)
		addq.w	#1,d3					; +1px for stood-on height
		move.w	obX(a0),d4				; collision X-position (stood-on)
		jsr (SolidObject).l				; make platform solid

		jmp (RememberState).l				; display platform, or delete it if out of range
; ---------------------------------------------------------------------------

.notSolid:
        jsr (SMZ_ReleaseRiders).l
        jmp (RememberState).l

SMZ_Ani_Spin:	dc.w SMZ_Ani_Spin_trapopen-SMZ_Ani_Spin
		dc.w SMZ_Ani_Spin_trapclose-SMZ_Ani_Spin
		dc.w SMZ_Ani_Spin_spin1-SMZ_Ani_Spin
		dc.w SMZ_Ani_Spin_spin2-SMZ_Ani_Spin

SMZ_Ani_Spin_trapopen:	dc.b 3
		dc.b 0, 1
		dc.b 2
		dc.b afBack, 1
		even

SMZ_Ani_Spin_trapclose:	dc.b 3
		dc.b 2, 1
		dc.b 0
		dc.b afBack, 1
		even

SMZ_Ani_Spin_spin1:		dc.b 1
		dc.b 0, 1, 2, 3, 4
		dc.b 3|$40, 2|$40, 1|$40, 0|$40
		dc.b 1|$20|$40, 2|$20|$40, 3|$20|$40, 4|$20|$40
		dc.b 3|$20, 2|$20, 1|$20
		dc.b 0
		dc.b afBack, 1
		even

SMZ_Ani_Spin_spin2:		dc.b 1
		dc.b 0, 1, 2, 3, 4
		dc.b 3|$40, 2|$40, 1|$40, 0|$40
		dc.b 1|$20|$40, 2|$20|$40, 3|$20|$40, 4|$20|$40
		dc.b 3|$20, 2|$20, 1|$20
		dc.b 0
		dc.b afBack, 1
		even

Map_SMZ_Trap: binclude "mappings/sprite/SMZ Trap.bin"
Map_SMZ_Spin: binclude "mappings/sprite/SMZ Spin.bin"
