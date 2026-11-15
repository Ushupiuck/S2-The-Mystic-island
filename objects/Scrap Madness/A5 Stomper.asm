; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 6B - stomper and sliding door (SBZ)
;             and ancient lift at the start of SBZ3/LZ4
; ---------------------------------------------------------------------------

SMZ_ScrapStomp:
		move.w	obSubtype(a0),d0
		btst	#8,d0
		bne.w	MMZ_Crusher_Init
		cmpi.b	#id_MMZ,(v_zone).w
		beq.w	MMZ_Crusher_Init
		bra.w	SMZ_Sto_Main

SMZ_sto_origY:	equ objoff_30		; original y-axis position
SMZ_sto_origX:	equ objoff_34		; original x-axis position
SMZ_sto_delay:	equ objoff_36		; delay timer before moving again
SMZ_sto_active:	equ objoff_38		; flag set when a switch is pressed
SMZ_sto_offset_now:	equ objoff_3A		; current X/Y-offset from origin
SMZ_sto_offset_max:	equ objoff_3C		; maximum move distance from origin (third entry in SMZ_Sto_Var)
SMZ_sto_switch:	equ objoff_3E		; switch ID that triggers platform behavior
; ===========================================================================

SMZ_Sto_Var:	; width, height, max distance, action type
		dc.b  128/2,  24/2, 128, 1	; $8x - sliding platform extending on switch press
		dc.b   56/2,  64/2,  56, 3	; $1x - stomper (stomps down and slowly goes back up)
		dc.b   56/2,  64/2,  64, 4	; $2x - stomper (stomps up and down)
		dc.b   56/2,  64/2,  96, 4	; $3x - stomper (stomps up and down, larger distance)
		dc.b  256/2, 128/2,   0, 5	; $4x - ancient lift at the start of SBZ3/LZ4
; ===========================================================================

SMZ_Sto_Main:	; Constructor
		move.l	#SMZ_Sto_Action,code(a0)
		addq.b	#2,obRoutine(a0)			; advance to SMZ_Sto_Action

		moveq	#0,d0					; clear d0
		move.w	obSubtype(a0),d0			; get object subtype
		lsr.w	#2,d0					; read only upper digit, multiplied by 4 bytes per entry
		andi.w	#$1C,d0					; limit to upper digits 0-7
		lea	SMZ_Sto_Var(pc,d0.w),a3			; load setup array
		move.b	(a3)+,obActWid(a0)			; load sprite display width and solidity width
		move.b	(a3)+,obHeight(a0)			; set solidity width (and display height for SBZ3 platform)
		lsr.w	#2,d0					; move rest of upper subtype digit exactly into lower digit
		move.b	d0,obFrame(a0)				; use upper subtype digit for frame ID

		move.l	#Map_SMZ_Stomp,obMap(a0)
		move.b #Map_SMZ_Stomp_height,height_pixels(a0)			; set mappings
		move.w #ArtTile_SMZ_Atlas,obGfx(a0) ; set art tile (SBZ1/2)
.continueSetup:
		ori.b	#4,obRender(a0)		; set to playfield-positioned mode
		move.w #$200,obPriority(a0)			; set sprite priority
		move.w	obX(a0),SMZ_sto_origX(a0)			; remember initial X-position
		move.w	obY(a0),SMZ_sto_origY(a0)			; remember initial Y-position

		moveq	#0,d0					; clear d0
		move.b	(a3)+,d0				; get max move distance
		move.w	d0,SMZ_sto_offset_max(a0)			; store it

		moveq	#0,d0					; clear d0
		move.w	obSubtype(a0),d0			; get object subtype
		btst	#7,d0
		beq.s	SMZ_Sto_Action				; is subtype $80 or above (extending sliding platform)? if not, branch
		andi.w	#$F,d0					; read only lower digit
		move.b	d0,SMZ_sto_switch(a0)			; store switch ID that will trigger platform behavior
		moveq	#0,d0
		move.b	(a3),d0
		move.w	d0,obSubtype(a0)			; set action type number

SMZ_Sto_Action:	; Routine 2
		move.w	obX(a0),-(sp)				; backup previous X-position before executing behavior
		moveq	#0,d0					; clear d0
		move.w	obSubtype(a0),d0			; get action type (set from SMZ_Sto_Var)
		andi.w	#$F,d0					; only read lower digit
		add.w	d0,d0					; double for word-based indexing
		move.w	SMZ_Sto_TypeIndex(pc,d0.w),d1		; find entry in jump table
		jsr	SMZ_Sto_TypeIndex(pc,d1.w)			; execute behavior, then return here
		move.w	(sp)+,d4				; restore previous X-position as input for SolidObject

		tst.b	obRender(a0)				; is platform on screen?
		bpl.s	.chkdel					; if not, skip collision detection

		moveq	#0,d1					; clear d1
		move.b	obActWid(a0),d1				; use sprite display width as solidity width
		addi.w	#sonic_solid_width,d1			; add Sonic's own collision width
		moveq	#0,d2					; clear d2
		move.b	obHeight(a0),d2				; object collision height (initial)
		move.w	d2,d3					; object collision height (stood-on)
		addq.w	#1,d3					; +1px height when stood-on
		jsr (SolidObject).l				; make object solid and handle squash kills
; ---------------------------------------------------------------------------

	.chkdel:
		out_of_range2	.chkgone,SMZ_sto_origX(a0)		; has object gone out of range? if yes, branch
		jmp	(DisplaySprite).l			; display object

	.chkgone:
		jmp (UnloadObject).l

; ===========================================================================
SMZ_Sto_TypeIndex:	dc.w SMZ_Sto_Stationary-SMZ_Sto_TypeIndex		; 0
		dc.w SMZ_Sto_SlidingPlatform_Extend-SMZ_Sto_TypeIndex	; 1
		dc.w SMZ_Sto_SlidingPlatform_Retract-SMZ_Sto_TypeIndex	; 2
		dc.w SMZ_Sto_Stomper_DownAndRetract-SMZ_Sto_TypeIndex	; 3
		dc.w SMZ_Sto_Stomper_UpAndDown-SMZ_Sto_TypeIndex	; 4
		dc.w SMZ_Sto_AncientLift-SMZ_Sto_TypeIndex		; 5
; ===========================================================================

; Type 0 - stationary
SMZ_Sto_Stationary:
		rts						; do nothing
; ===========================================================================

; Type 1 - extending sliding platform
SMZ_Sto_SlidingPlatform_Extend:
		tst.b	SMZ_sto_active(a0)				; has sliding platform already been activated?
		bne.s	.extendPlatform				; if yes, branch

		lea	(f_switch).w,a2				; load switch states
		moveq	#0,d0					; clear d0
		move.b	SMZ_sto_switch(a0),d0			; get switch ID that will trigger platform
		btst	#0,(a2,d0.w)				; is respective switch button pressed?
		beq.s	.updatePosition				; if not, branch
		move.b	#1,SMZ_sto_active(a0)			; start extending platform

	.extendPlatform:
		move.w	SMZ_sto_offset_max(a0),d0			; get maximum distance platform should move (128px)
		cmp.w	SMZ_sto_offset_now(a0),d0			; has it reached the max distance?
		beq.s	.stopPlatform				; if yes, branch
		addq.w	#2,SMZ_sto_offset_now(a0)			; extend platform at 2px/frame to the left

	.updatePosition:
		move.w	SMZ_sto_offset_now(a0),d0			; get current extension length
		btst	#0,obStatus(a0)		; is platform X-flipped?
		beq.s	.setX					; if not, branch
		neg.w	d0					; extend platform to the right instead
		addi.w	#128,d0					; keep in same general X-range (platform width is 128px)
	.setX:	move.w	SMZ_sto_origX(a0),d1			; get initial platform X-position
		sub.w	d0,d1					; adjust by current movement offset
		move.w	d1,obX(a0)				; set new X-position
		rts						; return
; ---------------------------------------------------------------------------

; .loc_15DE0:
.stopPlatform:
		addq.w	#1,obSubtype(a0)			; change to SMZ_Sto_SlidingPlatform_Retract (delay and retract again)
		move.w	#3*60,SMZ_sto_delay(a0)			; set delay before retracting to 3 seconds
		clr.b	SMZ_sto_active(a0)				; clear activation flag

		bra.s .updatePosition
; ===========================================================================

; Type 2 (set from Type 1) - retract sliding platform again after a delay
SMZ_Sto_SlidingPlatform_Retract:
		tst.b	SMZ_sto_active(a0)				; is platform already set to retract?
		bne.s	.retractPlatform			; if yes, branch

		subq.w	#1,SMZ_sto_delay(a0)			; decrement delay before retracting
		bne.s	.updatePosition				; if time remains, branch
		move.b	#1,SMZ_sto_active(a0)			; start retracting platform

	.retractPlatform:
		tst.w	SMZ_sto_offset_now(a0)			; has current extension range gone back to 0?
		beq.s	.stopPlatform				; if yes, branch
		subq.w	#2,SMZ_sto_offset_now(a0)			; retract platform at 2px/frame to the right

	.updatePosition:
		move.w	SMZ_sto_offset_now(a0),d0			; get current extension length
		btst	#0,obStatus(a0)		; is platform X-flipped?
		beq.s	.setX					; if not, branch
		neg.w	d0					; retract platform to the left instead
		addi.w	#128,d0					; keep in same general X-range (platform width is 128px)
	.setX:	move.w	SMZ_sto_origX(a0),d1			; get initial platform X-position
		sub.w	d0,d1					; adjust by current movement offset
		move.w	d1,obX(a0)				; set new X-position
		rts						; return
; ---------------------------------------------------------------------------

; .loc_15E3C:
.stopPlatform:
		subq.w	#1,obSubtype(a0)			; change back to SMZ_Sto_SlidingPlatform_Extend (extend on switch press)
		clr.b	SMZ_sto_active(a0)				; clear activation flag

		bra.s .updatePosition
; ===========================================================================

; Type 3 - stomper (stomps down, immediately goes slowly back up, waits 1 second, stomps down again)
SMZ_Sto_Stomper_DownAndRetract:
		tst.b	SMZ_sto_active(a0)				; is stomper set stomp down?
		bne.s	.stompDown				; if yes, branch

	.retract:
		tst.w	SMZ_sto_offset_now(a0)			; has stomper gone fully back up again?
		beq.s	.delay					; if yes, branch
		subq.w	#1,SMZ_sto_offset_now(a0)			; move stomper back up at 1px/frame
		bra.s	.updatePosition				; update Y-position
; ---------------------------------------------------------------------------

	.delay:
		subq.w	#1,SMZ_sto_delay(a0)			; decrement delay before stomping down again
		bpl.s	.updatePosition				; if time remains, branch
		move.w	#1*60,SMZ_sto_delay(a0)			; reset next delay to 1 second
		move.b	#1,SMZ_sto_active(a0)			; start stomping down

	.stompDown:
		addq.w	#8,SMZ_sto_offset_now(a0)			; move stomper down at 8px/frame
		move.w	SMZ_sto_offset_now(a0),d0			; get current stomp distance
		cmp.w	SMZ_sto_offset_max(a0),d0			; has stomper reached max distance?
		bne.s	.updatePosition				; if not, branch
		clr.b	SMZ_sto_active(a0)				; start moving stomper back up again

	.updatePosition:
		move.w	SMZ_sto_offset_now(a0),d0			; get current stomp distance
		btst	#0,obStatus(a0)		; is stomper X-flipped?
		beq.s	.setY					; if not, branch
		neg.w	d0					; invert base stomp direction
		addi.w	#56,d0					; keep in same general Y-range (stomper height is 56px)
	.setY:	move.w	SMZ_sto_origY(a0),d1			; get initial stomper Y-position
		add.w	d0,d1					; adjust by current stomp distance
		move.w	d1,obY(a0)				; set new Y-position
		rts						; return
; ===========================================================================

; Type 4 - stomper (stomps up and down, waits 1 second between each stomp)
SMZ_Sto_Stomper_UpAndDown:
		tst.b	SMZ_sto_active(a0)				; is stomper set to stomp down?
		bne.s	.stompDown				; if yes, branch

	.stompUp:
		tst.w	SMZ_sto_offset_now(a0)			; has stomper gone fully back up again?
		beq.s	.delayStompDown				; if yes, branch
		subq.w	#8,SMZ_sto_offset_now(a0)			; move stomper back up at 8px/frame
		bra.s	.updatePosition				; update Y-position
; ---------------------------------------------------------------------------

	.delayStompDown:
		subq.w	#1,SMZ_sto_delay(a0)			; decrement delay before stomping down
		bpl.s	.updatePosition				; if time remains, branch
		move.w	#1*60,SMZ_sto_delay(a0)			; set delay before stomping back up to 1 second
		move.b	#1,SMZ_sto_active(a0)			; start stomping down

	.stompDown:
		move.w	SMZ_sto_offset_now(a0),d0			; get current stomp distance
		cmp.w	SMZ_sto_offset_max(a0),d0			; has stomper reached max distance?
		beq.s	.delayStompUp				; if yes, branch
		addq.w	#8,SMZ_sto_offset_now(a0)			; move stomper down at 8px/frame
		bra.s	.updatePosition				; update Y-position
; ---------------------------------------------------------------------------

	.delayStompUp:
		subq.w	#1,SMZ_sto_delay(a0)			; decrement delay before stomping up
		bpl.s	.updatePosition				; fi time remains, branch
		move.w	#1*60,SMZ_sto_delay(a0)			; set delay before stomping back down to 1 second
		clr.b	SMZ_sto_active(a0)				; start stomping up

	.updatePosition:
		move.w	SMZ_sto_offset_now(a0),d0			; get current stomp distance
		btst	#0,obStatus(a0)		; is stomper X-flipped?
		beq.s	.setY					; if not, branch
		neg.w	d0					; invert base stomp direction
		addi.w	#56,d0					; keep in same general Y-range (stomper height is 56px)
	.setY:	move.w	SMZ_sto_origY(a0),d1			; get initial stomper Y-position
		add.w	d0,d1					; adjust by current stomp distance
		move.w	d1,obY(a0)				; set new Y-position
		rts						; return
; ===========================================================================

; Type 5 - ancient lift at the start of SBZ3/LZ4
; .type05:
SMZ_Sto_AncientLift:
		rts
Map_SMZ_Stomp: binclude "mappings/sprite/SMZ Stomp.bin"

; ---------------------------------------------------------------------------
; MMZ crushers share the stomper's placement ID. Two signed-byte height tables
; replace CD's per-update sine/cosine call and multiplication, including the
; source's asymmetric sine entries and negative-product rounding.
MMZ_crush_y:		equ objoff_2E
MMZ_crush_x:		equ objoff_30
MMZ_crush_phase:		equ objoff_32
MMZ_crush_step:		equ objoff_34
MMZ_crush_heights:	equ objoff_36 ; long table pointer
MMZ_crush_hold:		equ objoff_3A ; byte, selected pause duration
MMZ_crush_timer:		equ objoff_3B ; byte, current pause
MMZ_crush_paused:	equ objoff_3C ; byte
MMZ_crush_tall:		equ objoff_3D ; byte
MMZ_crush_launch:	equ objoff_3E ; word, launch velocity

MMZ_Crusher_Init:
		move.l	#MMZ_Crusher_Run,code(a0)
		move.l	#Map_MMZ_Crusher,obMap(a0)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		move.w	#$180,obPriority(a0)
		ori.b	#4,obRender(a0)
		move.b	#32,width_pixels(a0)
		move.b	#Map_MMZ_Crusher_height,height_pixels(a0)
		move.b	#32,obHeight(a0)
		move.w	obY(a0),MMZ_crush_y(a0)
		move.w	obX(a0),MMZ_crush_x(a0)
		move.w	obSubtype(a0),d0
		move.w	d0,d1
		andi.w	#$30,d1
		lsl.w	#4,d1
		move.w	d1,MMZ_crush_phase(a0)
		lea	MMZ_Crusher_Height32(pc),a1
		btst	#6,d0
		beq.s	.heights
		lea	MMZ_Crusher_Height48(pc),a1
.heights:
		move.l	a1,MMZ_crush_heights(a0)
		move.w	d0,d1
		andi.w	#3,d1
		cmpi.w	#1,d1
		bne.s	.small
		move.b	#1,MMZ_crush_tall(a0)
		move.b	#1,obFrame(a0)
		move.b	#96,obHeight(a0)
		move.b	#60,MMZ_crush_hold(a0)
		btst	#3,d0
		beq.s	.power
		; CD indexes a two-byte table with 0/2, reading its following
		; TST opcode as the long pause. Select the declared 90 instead.
		move.b	#90,MMZ_crush_hold(a0)
.power:
		move.w	#-$1000,MMZ_crush_launch(a0)
		btst	#7,d0
		beq.s	.tall_speed
		move.w	#-$A00,MMZ_crush_launch(a0)
.tall_speed:
		andi.w	#4,d0
.small:
		andi.w	#$C,d0
		lsr.w	#1,d0
		move.w	.speeds(pc,d0.w),MMZ_crush_step(a0)
		bsr.w	MMZ_Crusher_Position
		move.w	d0,obY(a0)
		bra.w	MMZ_Crusher_Display
.speeds:	dc.w 4,8,16,32

MMZ_Crusher_Run:
		tst.w	obVelY(a0)
		bpl.s	.move
		bsr.w	MMZ_Crusher_Solid
.move:
		move.w	obY(a0),-(sp)
		tst.b	MMZ_crush_tall(a0)
		beq.s	.advance
		tst.b	MMZ_crush_paused(a0)
		beq.s	.extremum
		subq.b	#1,MMZ_crush_timer(a0)
		bcc.s	.stationary
		clr.b	MMZ_crush_paused(a0)
		bra.s	.advance
.extremum:
		move.w	MMZ_crush_phase(a0),d0
		cmpi.w	#$100,d0
		beq.s	.pause
		cmpi.w	#$300,d0
		bne.s	.advance
.pause:
		st	MMZ_crush_paused(a0)
		move.b	MMZ_crush_hold(a0),MMZ_crush_timer(a0)
.stationary:
		move.w	obY(a0),d0
		bra.s	.velocity
.advance:
		move.w	MMZ_crush_step(a0),d0
		add.w	d0,MMZ_crush_phase(a0)
		andi.w	#$3FF,MMZ_crush_phase(a0)
		bsr.s	MMZ_Crusher_Position
.velocity:
		move.w	d0,obY(a0)
		sub.w	(sp)+,d0
		lsl.w	#8,d0
		move.w	d0,obVelY(a0)
		tst.b	MMZ_crush_tall(a0)
		beq.s	.solid
		cmpi.w	#$210,MMZ_crush_phase(a0)
		bne.s	.solid
		bsr.s	MMZ_Crusher_Solid
		lea	(v_player).w,a1
		moveq	#3,d6
		bsr.s	MMZ_Crusher_Launch
		lea	(v_player2).w,a1
		moveq	#4,d6
		bsr.s	MMZ_Crusher_Launch
		bra.s	MMZ_Crusher_Display
.solid:
		tst.w	obVelY(a0)
		bmi.s	MMZ_Crusher_Display
		bsr.s	MMZ_Crusher_Solid
MMZ_Crusher_Display:
		out_of_range2	MMZ_Crusher_Unload,MMZ_crush_x(a0)
		jmp	(DisplaySprite).l

MMZ_Crusher_Position:
		move.w	MMZ_crush_phase(a0),d0
		lsr.w	#2,d0
		movea.l	MMZ_crush_heights(a0),a1
		move.b	(a1,d0.w),d0
		ext.w	d0
		add.w	MMZ_crush_y(a0),d0
		rts

MMZ_Crusher_Solid:
		moveq	#32+sonic_solid_width,d1
		moveq	#0,d2
		move.b	obHeight(a0),d2
		move.w	d2,d3
		addq.w	#1,d3
		move.w	obX(a0),d4
		jmp	(SolidObject).l

MMZ_Crusher_Launch:
		btst	d6,obStatus(a0)
		beq.s	.return
		bclr	d6,obStatus(a0)
		move.w	MMZ_crush_launch(a0),obVelY(a1)
		bset	#status.player.in_air,obStatus(a1)
		bclr	#status.player.on_object,obStatus(a1)
		bclr	#status.player.rolljumping,obStatus(a1)
		clr.b	jumping(a1)
		clr.b	spindash_flag(a1)
		clr.b	tails_flight_flag(a1)
		move.b	#$10,obAnim(a1)
.return:
		rts

MMZ_Crusher_Unload:
		jsr	(SMZ_ReleaseRiders).l
		jmp	(UnloadObject).l

MMZ_Crusher_Height32:
		dc.b 0,0,1,2,3,3,4,5,6,7,7,8,9,10,10,11
		dc.b 12,12,13,14,15,15,16,17,17,18,19,19,20,20,21,22
		dc.b 22,23,23,24,24,25,25,26,26,27,27,27,28,28,28,29
		dc.b 29,29,30,30,30,30,31,31,31,31,31,31,31,31,31,31
		dc.b 32,31,31,31,31,31,31,31,31,31,31,30,30,30,30,29
		dc.b 29,29,28,28,28,27,27,27,26,26,25,25,24,24,23,23
		dc.b 22,22,21,20,20,19,19,18,17,17,16,15,15,14,13,12
		dc.b 12,11,10,10,9,8,7,7,6,5,4,3,3,2,1,0
		dc.b 0,-1,-2,-3,-4,-4,-5,-6,-7,-7,-8,-9,-10,-10,-11,-12
		dc.b -13,-13,-14,-15,-15,-16,-17,-17,-18,-19,-19,-20,-21,-21,-22,-22
		dc.b -23,-24,-24,-25,-25,-26,-26,-27,-27,-27,-28,-28,-29,-29,-29,-30
		dc.b -30,-30,-31,-31,-31,-31,-31,-32,-32,-32,-32,-32,-32,-32,-32,-32
		dc.b -32,-32,-32,-32,-32,-32,-32,-32,-32,-32,-31,-31,-31,-31,-31,-30
		dc.b -30,-30,-29,-29,-29,-28,-28,-27,-27,-27,-26,-26,-25,-25,-24,-24
		dc.b -23,-22,-22,-21,-21,-20,-19,-19,-18,-17,-17,-16,-15,-15,-14,-13
		dc.b -13,-12,-11,-10,-10,-9,-8,-7,-7,-6,-5,-4,-4,-3,-2,-1
MMZ_Crusher_Height48:
		dc.b 0,1,2,3,4,5,6,8,9,10,11,12,13,15,16,17
		dc.b 18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33
		dc.b 33,34,35,36,36,37,38,39,39,40,41,41,42,42,43,43
		dc.b 44,44,45,45,45,46,46,46,47,47,47,47,47,47,47,47
		dc.b 48,47,47,47,47,47,47,47,47,46,46,46,45,45,45,44
		dc.b 44,43,43,42,42,41,41,40,39,39,38,37,36,36,35,34
		dc.b 33,33,32,31,30,29,28,27,26,25,24,23,22,21,20,19
		dc.b 18,17,16,15,13,12,11,10,9,8,6,5,4,3,2,1
		dc.b 0,-2,-3,-4,-5,-6,-7,-9,-10,-11,-12,-13,-14,-15,-17,-18
		dc.b -19,-20,-21,-22,-23,-24,-25,-26,-27,-28,-29,-30,-31,-32,-33,-33
		dc.b -34,-35,-36,-37,-37,-38,-39,-40,-40,-41,-42,-42,-43,-43,-44,-44
		dc.b -45,-45,-46,-46,-46,-47,-47,-47,-48,-48,-48,-48,-48,-48,-48,-48
		dc.b -48,-48,-48,-48,-48,-48,-48,-48,-48,-47,-47,-47,-46,-46,-46,-45
		dc.b -45,-44,-44,-43,-43,-42,-42,-41,-40,-40,-39,-38,-37,-37,-36,-35
		dc.b -34,-33,-33,-32,-31,-30,-29,-28,-27,-26,-25,-24,-23,-22,-21,-20
		dc.b -19,-18,-17,-15,-14,-13,-12,-11,-10,-9,-7,-6,-5,-4,-3,-2
		even
Map_MMZ_Crusher:	binclude "mappings/sprite/MMZ Crusher.bin"
		even
