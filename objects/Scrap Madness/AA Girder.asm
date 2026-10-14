; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 70 - large girder block (SBZ)
; ---------------------------------------------------------------------------

SMZ_Girder:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SMZ_Gird_Index(pc,d0.w),d1
		jmp	SMZ_Gird_Index(pc,d1.w)
; ===========================================================================
SMZ_Gird_Index:	dc.w SMZ_Gird_Main-SMZ_Gird_Index
		dc.w SMZ_Gird_Action-SMZ_Gird_Index

SMZ_gird_origY:	equ objoff_30		; original y-axis position
SMZ_gird_origX:	equ objoff_32		; original x-axis position
SMZ_gird_time:	equ objoff_34		; duration for movement in a direction (in frames)
SMZ_gird_set:	equ objoff_38		; which movement settings to use (0/8/$10/$18)
SMZ_gird_delay:	equ objoff_3A		; delay before starting next movement
; ===========================================================================

SMZ_Gird_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)			; advance to SMZ_Gird_Action
		move.l	#Map_SMZ_Gird,obMap(a0)
		move.b #Map_SMZ_Gird_height,height_pixels(a0)			; set mappings
		move.w #ArtTile_SMZ_Atlas,obGfx(a0)	; set art tile and palette line
		ori.b	#4,obRender(a0)		; set to playfield-positioned mode
		move.w #$200,obPriority(a0)			; set sprite priority
		move.b	#192/2,obActWid(a0)			; set sprite display width and solidity width
		move.b	#48/2,obHeight(a0)			; set solidity height
		move.w	obX(a0),SMZ_gird_origX(a0)			; remember initial X-position
		move.w	obY(a0),SMZ_gird_origY(a0)			; remember initial Y-position
		bsr.w	SMZ_Gird_ChgMove				; initialize settings for first run
; ---------------------------------------------------------------------------

SMZ_Gird_Action:	; Routine 2
		move.w	obX(a0),-(sp)				; backup current X-position for SolidObject

		tst.w	SMZ_gird_delay(a0)				; is delay timer already expired?
		beq.s	.move					; if yes, branch
		subq.w	#1,SMZ_gird_delay(a0)			; decrement delay timer
		bne.s	.solid					; if time remains, don't move

	.move:
		jsr	(SpeedToPos).l				; update girder's position
		subq.w	#1,SMZ_gird_time(a0)			; decrement timer for movement
		bne.s	.solid					; if time remains, branch
		bsr.w	SMZ_Gird_ChgMove				; load next set of settings

	.solid:
		move.w	(sp)+,d4				; restore previous X-position for SolidObject

		tst.b	obRender(a0)				; is girder on screen?
		bpl.s	.chkdel					; if not, branch
		moveq	#0,d1					; clear d1 (SolidObject width input)
		move.b	obActWid(a0),d1				; use sprite display width as solidity width
		addi.w	#sonic_solid_width,d1			; add Sonic's own collision width
		moveq	#0,d2					; clear d2 (SolidObject height input)
		move.b	obHeight(a0),d2				; get object height as solidity height
		move.w	d2,d3					; d2 = initial, d3 = while stood-on
		addq.w	#1,d3					; +1px for stood-on height
		jsr (SolidObject).l				; make girder blocks solid
; ---------------------------------------------------------------------------

	.chkdel:
		out_of_range2	.delete,SMZ_gird_origX(a0)		; has object gone out of range (initial X-position)? if yes, branch
		jmp	(DisplaySprite).l			; display girder block

	.delete:
		jmp	(UnloadObject).l			; delete girder block
; ===========================================================================

SMZ_Gird_ChgMove:
		move.b	SMZ_gird_set(a0),d0				; get current set of settings to use
		andi.w	#$18,d0					; limit to 4 sets at 8 bytes each
		lea	(SMZ_Gird_Settings).l,a1			; load girder settings array
		lea	(a1,d0.w),a1				; advance to next girder set to use
		move.w	(a1)+,obVelX(a0)			; load X-speed
		move.w	(a1)+,obVelY(a0)			; load Y-speed
		move.w	(a1)+,SMZ_gird_time(a0)			; load duration for movement (in frames)
		addq.b	#8,SMZ_gird_set(a0)				; advance to next settings for next run
		move.w	#7,SMZ_gird_delay(a0)			; set a short delay to wait at a corner
		rts						; return
; End of function SMZ_Gird_ChgMove
; ---------------------------------------------------------------------------

SMZ_Gird_Settings:	; X-speed, Y-speed, duration, (unused)
		dc.w	 $100,	    0,	96,	0	; right
		dc.w	    0,	 $100,	48,	0	; down
		dc.w	-$100,	 -$40,	96,	0	; up/left
		dc.w	    0,	-$100,	24,	0	; up

; ===========================================================================

Map_SMZ_Gird: binclude "mappings/sprite/SMZ Gird.bin"
