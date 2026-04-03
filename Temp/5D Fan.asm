; ---------------------------------------------------------------------------
; Object 5D - Fan (SLZ)
; Enhanced with S2 wind-up acceleration and S3 velocity/SFX improvements
; ---------------------------------------------------------------------------
; Subtype:
;   bit 0 = reverse direction
;   bit 1 = always on (no on/off cycling)
; ---------------------------------------------------------------------------

Fan:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Fan_Index(pc,d0.w),d1
		jmp	Fan_Index(pc,d1.w)
; ===========================================================================
Fan_Index:	dc.w Fan_Main-Fan_Index
		dc.w Fan_Delay-Fan_Index

fan_time    = objoff_30		; time between switching on/off
fan_switch  = objoff_32		; on/off flag (0 = on, nonzero = off)
fan_windup  = objoff_34		; S2-style wind-up accumulator ($0-$400)
fan_sfxtmr  = objoff_36		; S3-style SFX cooldown timer
; ===========================================================================

Fan_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Fan,obMap(a0)
		move.w	#make_art_tile(ArtTile_SLZ_Fan,2,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$10,obActWid(a0)
		move.b	#4,obPriority(a0)

Fan_Delay:	; Routine 2
		btst	#1,obSubtype(a0)	; is object type 02/03 (always on)?
		bne.s	.blow			; if yes, branch
		subq.w	#1,fan_time(a0)		; subtract 1 from time delay
		bpl.s	.blow			; if time remains, branch
		move.w	#120,fan_time(a0)	; set delay to 2 seconds
		bchg	#0,fan_switch(a0)	; switch fan on/off
		beq.s	.blow			; if fan is off, branch
		move.w	#180,fan_time(a0)	; set delay to 3 seconds

.blow:
		tst.b	fan_switch(a0)		; is fan switched on?
		bne.s	.spindown		; if not, branch

		lea	(v_player).w,a1
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		btst	#0,obStatus(a0)		; is fan facing right?
		bne.s	.chksonic		; if yes, branch
		neg.w	d0

.chksonic:
		addi.w	#$50,d0
		cmpi.w	#$A0,d0			; is Sonic within $A0 pixels?
		bhs.s	.animate		; if not, branch
		move.w	obY(a1),d1
		addi.w	#$60,d1
		sub.w	obY(a0),d1
		bcs.s	.animate		; branch if Sonic is too low
		cmpi.w	#$70,d1
		bhs.s	.animate		; branch if Sonic is too high

		subi.w	#$50,d0			; is Sonic in the near zone?
		bcc.s	.faraway		; if not, branch

		; Near zone — S3 style: slam velocity directly
		not.w	d0
		move.w	#$1000,obVelX(a1)	; full speed boost
		btst	#0,obStatus(a0)		; fan facing right?
		bne.s	.sfx			; if yes, branch
		neg.w	obVelX(a1)		; flip for left-facing
		bra.s	.sfx

.faraway:
		; Far zone — S3 style: doubled force before bias
		add.w	d0,d0			; double the distance factor
		addi.w	#$60,d0
		btst	#0,obStatus(a0)		; is fan facing right?
		bne.s	.push			; if yes, branch
		neg.w	d0

.push:
		neg.b	d0
		asr.w	#4,d0
		btst	#0,obSubtype(a0)	; reverse direction subtype?
		beq.s	.movesonic
		neg.w	d0

.movesonic:
		add.w	d0,obX(a1)		; push Sonic

.sfx:
		; S3-style SFX on push, every 32 frames
		tst.w	fan_sfxtmr(a0)
		bne.s	.sfxtick
		move.w	#sfx_Fan,d0		; replace with appropriate SFX constant
		jsr	(PlaySound).l

.sfxtick:
		addq.w	#1,fan_sfxtmr(a0)
		andi.w	#$1F,fan_sfxtmr(a0)

		; S2-style wind-up: ramp animation speed
.animate:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	.chkdel
		cmpi.w	#$400,fan_windup(a0)	; wind-up cap reached?
		bhs.s	.cycleframe		; if yes, skip increment
		addi.w	#$2A,fan_windup(a0)	; ramp up
		move.b	fan_windup(a0),obTimeFrame(a0) ; slower anim at low wind-up
		bra.s	.cycleframe

.spindown:
		clr.w	fan_windup(a0)		; reset wind-up when fan off
		clr.w	fan_sfxtmr(a0)		; reset SFX timer
		bra.s	.animate

.cycleframe:
		move.b	#0,obTimeFrame(a0)
		addq.b	#1,obAniFrame(a0)
		cmpi.b	#4,obAniFrame(a0)	; reset after 4 frames
		blo.s	.noreset
		move.b	#0,obAniFrame(a0)

.noreset:
		moveq	#0,d0
		btst	#0,obSubtype(a0)	; reverse direction subtype?
		beq.s	.noflip
		moveq	#2,d0

.noflip:
		add.b	obAniFrame(a0),d0
		move.b	d0,obFrame(a0)

.chkdel:
		bsr.w	DisplaySprite
		out_of_range.w DeleteObject
		rts