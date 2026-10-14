; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 6E - electrocution orbs (SBZ)
; ---------------------------------------------------------------------------

SMZ_Electro:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SMZ_Elec_Index(pc,d0.w),d1
		jmp	SMZ_Elec_Index(pc,d1.w)
; ===========================================================================
SMZ_Elec_Index:	dc.w SMZ_Elec_Main-SMZ_Elec_Index
		dc.w SMZ_Elec_Shock-SMZ_Elec_Index

SMZ_elec_freq:	equ objoff_34		; zapping frequency as andable value
; ===========================================================================

SMZ_Elec_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)			; advance to SMZ_Elec_Shock
		move.l	#Map_SMZ_Elec,obMap(a0)
		move.b #Map_SMZ_Elec_height,height_pixels(a0)			; set mappings
		move.w #ArtTile_SMZ_Atlas,obGfx(a0)	; set art tile
		ori.b	#4,obRender(a0)		; set to playfield-positioned mode
		move.b	#80/2,obActWid(a0)			; set sprite width

		; Zap intervals are defined through the subtype, which must always be a power of 2.
		; This value will get ANDed with the current level frame counter, and zap if it's 0.
		moveq	#0,d0					; clear d0, frequency is a word
		move.b	obSubtype(a0),d0			; read zapper subtype
		lsl.w	#4,d0					; multiply by $10
		subq.w	#1,d0					; sub 1 to get andable value (e.g. $1F, $3F, $7F)
		move.w	d0,SMZ_elec_freq(a0)			; set result as frequency
; ---------------------------------------------------------------------------

SMZ_Elec_Shock:	; Routine 2
		move.w	(v_framecount).w,d0			; get current frame counter value
		and.w	SMZ_elec_freq(a0),d0			; is it time to zap?
		bne.s	.animate				; if not, branch

		move.b	#1,obAnim(a0)				; run "zap" animation
		tst.b	obRender(a0)				; is zapper on screen?
		bpl.s	.animate				; if not, don't play sound
		move.w	#sfx_Electric,d0			; set electricity sound
		jsr	(PlaySound_Special).l				; play it

	.animate:
		lea	(SMZ_Ani_Elec).l,a1				; load animation script
		jsr	(AnimateSprite).l			; animate zapper

		move.b	#0,obColType(a0)			; make zapper harmless by default
		cmpi.b	#4,obFrame(a0)				; is 4th frame displayed?
		bne.s	.display				; if not, branch
		move.b	#$24|$80,obColType(a0)	; if yes, make object hurt Sonic this frame

	.display:
		jmp (RememberState).l				; display sprite or delete if offscreen

; ===========================================================================
; ---------------------------------------------------------------------------
; Animation script - electrocution orbs (SBZ)
; ---------------------------------------------------------------------------

SMZ_Ani_Elec:	dc.w SMZ_Ani_Elec_idle-SMZ_Ani_Elec
		dc.w SMZ_Ani_Elec_discharge-SMZ_Ani_Elec

SMZ_Ani_Elec_idle:		dc.b 7
		dc.b 0
		dc.b afEnd
		even

SMZ_Ani_Elec_discharge:	dc.b 0
		dc.b 1, 1, 1, 2, 3, 3, 4, 4, 4, 5, 5, 5, 0
		dc.b afChange, 0
		even

Map_SMZ_Elec: binclude "mappings/sprite/SMZ Elec.bin"
