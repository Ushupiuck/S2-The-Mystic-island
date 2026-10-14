; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 68 - conveyor belts (SBZ)
; 
; Note: This is just the invisible object that moves Sonic horizontally.
; The conveyor belt graphics themselves are part of the level chunks.
; ---------------------------------------------------------------------------

SMZ_Conveyor:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SMZ_Conv_Index(pc,d0.w),d1
		jmp	SMZ_Conv_Index(pc,d1.w)
; ===========================================================================
SMZ_Conv_Index:	dc.w SMZ_Conv_Main-SMZ_Conv_Index
		dc.w SMZ_Conv_Action-SMZ_Conv_Index

SMZ_conv_speed:	equ objoff_36	; speed to push Sonic at in pixels per frame (can be positive or negative)
SMZ_conv_width:	equ objoff_38	; half-width of conveyor belt (128px or 56px)
; ===========================================================================

SMZ_Conv_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)			; advance to SMZ_Conv_Action

		move.b	#256/2,SMZ_conv_width(a0)			; set conveyor belt width to 256 pixels
		move.b	obSubtype(a0),d1			; get subtype
		andi.b	#$0F,d1					; read only the lower digit
		beq.s	.setSpeed				; if zero, branch
		move.b	#112/2,SMZ_conv_width(a0)			; set conveyor belt width to just 112 pixels

	.setSpeed:
		move.b	obSubtype(a0),d1			; get subtype again
		andi.b	#$F0,d1					; read only the upper digit
		ext.w	d1					; extend to word
		asr.w	#4,d1					; move upper subtype digit to lower digit
		move.w	d1,SMZ_conv_speed(a0)			; set belt speed
; ---------------------------------------------------------------------------

SMZ_Conv_Action:	; Routine 2
		lea (v_player).w,a1
		bsr.w SMZ_Conveyor_MoveSonic
		lea (v_player2).w,a1
		bsr.w SMZ_Conveyor_MoveSonic			; handle Sonic getting pushed along the conveyor belt

		out_of_range2	.delete				; has object gone out of range? if yes, branch
		rts						; keep object alive (no display)

	.delete:
		jmp	(UnloadObject).l			; delete conveyor belt
; ===========================================================================

SMZ_Conveyor_MoveSonic:
        tst.l code(a1)
        beq.w .return
        cmpi.b #4,obRoutine(a1)
        bhs.w .return

		moveq	#0,d2					; clear d2
		move.b	SMZ_conv_width(a0),d2			; get half-width of conveyor belt
		move.w	d2,d3					; copy half-width
		add.w	d3,d3					; make the copy full-width

		move.w	obX(a1),d0				; get Sonic's current X-position
		sub.w	obX(a0),d0				; get conveyor belt's Y-position
		add.w	d2,d0					; add conveyor belt's half-width
		cmp.w	d3,d0					; is Sonic horizontally within range?
		bhs.s	.return					; if not, ignore conveyor belt

		move.w	obY(a1),d1				; get Sonic's current Y-position
		sub.w	obY(a0),d1				; get conveyor belt's Y-position
		addi.w	#48,d1					; add conveyor belt's height (hardcoded to 48px)
		cmpi.w	#48,d1					; is Sonic vertically within range?
		bhs.s	.return					; if not, ignore conveyor belt

		btst	#status.player.in_air,obStatus(a1)		; is Sonic in air?
		bne.s	.return					; if yes, ignore conveyor belt

		move.w	SMZ_conv_speed(a0),d0			; get speed set from subtype
		add.w	d0,obX(a1)				; push Sonic on conveyor belt

	.return:
		rts						; return
; End of function SMZ_Conveyor_MoveSonic
