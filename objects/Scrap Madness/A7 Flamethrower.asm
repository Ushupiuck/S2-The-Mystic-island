; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 6D - flame thrower (SBZ)
; ---------------------------------------------------------------------------

SMZ_Flamethrower:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SMZ_Flame_Index(pc,d0.w),d1
		jmp	SMZ_Flame_Index(pc,d1.w)
; ===========================================================================
SMZ_Flame_Index:	dc.w SMZ_Flame_Main-SMZ_Flame_Index
		dc.w SMZ_Flame_Action-SMZ_Flame_Index

SMZ_flame_timer:		equ objoff_30	; current timer value
SMZ_flame_firetime:		equ objoff_32	; base time for flamethrower to fire
SMZ_flame_pausetime:	equ objoff_34	; base time for flamethrower to idle
SMZ_flame_hurtframe:	equ objoff_36	; frame ID that is harmful to Sonic
; ===========================================================================

SMZ_Flame_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)			; advance to SMZ_Flame_Action
		move.l	#Map_SMZ_Flame,obMap(a0)
		move.b #Map_SMZ_Flame_height,height_pixels(a0)			; set mappings
		move.w #ArtTile_SMZ_Atlas,obGfx(a0) ; set art tile and high-priority flag
		ori.b	#4,obRender(a0)		; set to playfield-positioned mode
		move.w #$80,obPriority(a0)			; set sprite priority (above Sonic)
		move.w	obY(a0),SMZ_flame_timer(a0)			; store obY (pointless, gets overwritten below)
		move.b	#24/2,obActWid(a0)			; set sprite display width

		move.b	obSubtype(a0),d0			; get object subtype
		andi.w	#$F0,d0					; read upper digit of object subtype
		add.w	d0,d0					; multiply by 2 frames
		move.w	d0,SMZ_flame_timer(a0)			; set as initial timer value
		move.w	d0,SMZ_flame_firetime(a0)			; store base flaming time

		move.b	obSubtype(a0),d0			; get object subtype again
		andi.w	#$0F,d0					; read lower digit of object subtype
		lsl.w	#5,d0					; multiply by 32 frames
		move.w	d0,SMZ_flame_pausetime(a0)			; store base pause time

		move.b	#$A,SMZ_flame_hurtframe(a0)			; set harmful frame ID to $A (broken pipe flamethrower)
		btst	#1,obStatus(a0)		; is flamethrower flipped vertically?
		beq.s	SMZ_Flame_Action				; if not, branch
		move.b	#2,obAnim(a0)				; use "valve" animations
		move.b	#$15,SMZ_flame_hurtframe(a0)		; set harmful frame ID to $15 (valve flamethrower)
; ---------------------------------------------------------------------------

SMZ_Flame_Action:	; Routine 2
		subq.w	#1,SMZ_flame_timer(a0)			; decrement current timer
		bpl.s	SMZ_Flame_Animate				; if time remains, branch

		move.w	SMZ_flame_pausetime(a0),SMZ_flame_timer(a0)	; begin pause time
		bchg	#0,obAnim(a0)				; toggle between expanding/retracting animations
		beq.s	SMZ_Flame_Animate				; if on retracting animation now, branch (to pause)

		move.w	SMZ_flame_firetime(a0),SMZ_flame_timer(a0)	; flamethrower is expanding again, begin flaming time
		move.w	#sfx_Fireball,d0			; set flamethrower sound
		jsr	(PlaySound_Special).l				; play it

SMZ_Flame_Animate:
		lea	(SMZ_Ani_Flame).l,a1			; load animation scripts
		jsr (AnimateSprite).l				; (stays on last 1/2 frames per animation indefinitely)

		move.b	#0,obColType(a0)			; make flamethrower harmless by default
		move.b	SMZ_flame_hurtframe(a0),d0			; get specified harmful frame ID
		cmp.b	obFrame(a0),d0				; is current frame in the animation script a harmful one?
		bne.s	.display				; if not, branch
		move.b	#$23|$80,obColType(a0)	; make flamethrower harmless

	.display:
		out_of_range2	UnloadObject			; has object gone out of range? if yes, delete it
		jmp (DisplaySprite).l				; display flamethrower sprite

; ===========================================================================
; ---------------------------------------------------------------------------
; Animation script - flamethrower (SBZ)
; ---------------------------------------------------------------------------

SMZ_Ani_Flame:	dc.w SMZ_Ani_Flame_pipe1-SMZ_Ani_Flame
		dc.w SMZ_Ani_Flame_pipe2-SMZ_Ani_Flame
		dc.w SMZ_Ani_Flame_valve1-SMZ_Ani_Flame
		dc.w SMZ_Ani_Flame_valve2-SMZ_Ani_Flame

SMZ_Ani_Flame_pipe1:		dc.b 3
		dc.b 0, 1, 2, 3, 4, 5, 6, 7, 8
		dc.b 9, $A
		dc.b afBack, 2
		even

SMZ_Ani_Flame_pipe2:		dc.b 0
		dc.b 9, 7, 5, 3, 1
		dc.b 0
		dc.b afBack, 1
		even

SMZ_Ani_Flame_valve1:	dc.b 3
		dc.b $B, $C, $D, $E, $F, $10, $11, $12, $13
		dc.b $14, $15
		dc.b afBack, 2
		even

SMZ_Ani_Flame_valve2:	dc.b 0
		dc.b $14, $12, $11, $F, $D
		dc.b $B
		dc.b afBack, 1
		even

Map_SMZ_Flame: binclude "mappings/sprite/SMZ Flame.bin"
