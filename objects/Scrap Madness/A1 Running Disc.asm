; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 67 - disc that Sonic runs around (SBZ act 2)
; 
; Note: This is just the invisible object that control Sonic,
; as well as the small circular spot that moves inside the gear.
; The gear graphics themselves are part of the level chunks.
; ---------------------------------------------------------------------------

SMZ_RunningDisc:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SMZ_Disc_Index(pc,d0.w),d1
		jmp	SMZ_Disc_Index(pc,d1.w)
; ===========================================================================
SMZ_Disc_Index:	dc.w SMZ_Disc_Main-SMZ_Disc_Index
		dc.w SMZ_Disc_Action-SMZ_Disc_Index

SMZ_disc_origY:		equ objoff_30		; original y-axis position
SMZ_disc_origX:		equ objoff_32		; original x-axis position
SMZ_disc_spot_distance:	equ objoff_34		; radius distance for the small moving spot inside gear
SMZ_disc_spot_speed:	equ objoff_36		; small spot rotation speed
SMZ_disc_triggersize:	equ objoff_38		; trigger distance for Sonic to latch onto gear
SMZ_disc_sonic_attached:	equ objoff_3A		; flag set while Sonic is attached to gear
SMZ_disc_radius_squared:	equ objoff_3C		; circular capture limit, after the quick square test
; ===========================================================================

SMZ_Disc_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)			; advance to SMZ_Disc_Action
		move.l	#Map_SMZ_Disc,obMap(a0)
		move.b #Map_SMZ_Disc_height,height_pixels(a0)			; set mappings
		move.w #ArtTile_SMZ_Atlas,obGfx(a0) ; set art tile, palette line, and high-priority flag
		move.b	#4,obRender(a0)		; set to playfield-positioned mode
		move.w #$200,obPriority(a0)			; set sprite priority
		move.b	#16/2,obActWid(a0)			; set sprite display width

		move.w	obX(a0),SMZ_disc_origX(a0)			; remember initial X-position
		move.w	obY(a0),SMZ_disc_origY(a0)			; remember initial Y-position
		move.b	#$18,SMZ_disc_spot_distance(a0)		; set radius distance for the small moving spot inside gear
		move.b	#$48,SMZ_disc_triggersize(a0)		; set trigger distance for Sonic to latch onto gear
		move.w	#$48*$48,SMZ_disc_radius_squared(a0)

		; This is a leftover from the prototype, where it was planned to also
		; have smaller sized gears. In the final game, only large gears exist.
		move.w	obSubtype(a0),d1			; get object subtype
		andi.w	#$0F,d1					; read only the lower digit
		beq.s	.setupSmallDot				; branch if 0 (it always is)
		move.b	#$10,SMZ_disc_spot_distance(a0)		; use smaller spot radius
		move.b	#$38,SMZ_disc_triggersize(a0)		; use shorter trigger distance
		move.w	#$38*$38,SMZ_disc_radius_squared(a0)

	.setupSmallDot:
		move.w	obSubtype(a0),d1			; get object subtype again
		andi.w	#$F0,d1					; read only the upper digit
		ext.w	d1					; extend to word
		asl.w	#3,d1					; multiply by 8
		move.w	d1,SMZ_disc_spot_speed(a0)			; set result as rotation speed for the small spot

		move.b	obStatus(a0),d0				; get status flags containing X/Y-flip flags
		ror.b	#2,d0					; move X/Y-flip flags in bits 0-1 to upper bits 6-7
		andi.b	#(1|2)<<6,d0	; limit to only bits 6-7 ($C0)
		move.b	d0,obAngle(a0)				; set initial angle for small spot
; ---------------------------------------------------------------------------

SMZ_Disc_Action:	; Routine 2
        lea (v_player).w,a1
        lea SMZ_disc_sonic_attached(a0),a3
        bsr.w SMZ_Disc_MoveSonic
        lea (v_player2).w,a1
        lea SMZ_disc_sonic_attached+1(a0),a3
        bsr.w SMZ_Disc_MoveSonic				; handle Sonic moving on gear
		bsr.w	SMZ_Disc_MoveSpot				; move the spot inside the gear circularly
		bra.w	SMZ_Disc_Display				; display spot, or delete whole object if offscreen

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to handle Sonic around the gear
; ---------------------------------------------------------------------------

SMZ_Disc_MoveSonic:
        tst.l code(a1)
        beq.w SMZ_Disc_DetachSonic
        cmpi.b #4,obRoutine(a1)
        bhs.w SMZ_Disc_DetachSonic

		moveq	#0,d2					; clear d2
		move.b	SMZ_disc_triggersize(a0),d2			; get trigger distance for Sonic to latch onto gear
		move.w	d2,d3					; copy trigger distance
		add.w	d3,d3					; double trigger distance to get diameter

		move.w	obX(a1),d0				; get Sonic's current X-position
		sub.w	SMZ_disc_origX(a0),d0			; calculate difference to gear's X-position
		add.w	d2,d0					; add trigger distance
		cmp.w	d3,d0					; is Sonic horizontally within trigger distance?
		bhs.s	SMZ_Disc_DetachSonic			; if not, branch

		move.w	obY(a1),d1				; get Sonic's current Y-position
		sub.w	SMZ_disc_origY(a0),d1			; calculate difference to gear's Y-position
		add.w	d2,d1					; add trigger distance
		cmp.w	d3,d1					; is Sonic vertically within trigger distance?
		bhs.s	SMZ_Disc_DetachSonic			; if not, branch

		; The square's corners extend beyond the circular gear. Falling
		; beside it must not acquire its minimum ground speed on contact.
		sub.w	d2,d0
		sub.w	d2,d1
		muls.w	d0,d0
		muls.w	d1,d1
		add.w	d1,d0			; bounded deltas keep the sum within a word
		cmp.w	SMZ_disc_radius_squared(a0),d0
		bhs.s	SMZ_Disc_DetachSonic

		btst	#status.player.in_air,obStatus(a1)		; is Sonic on the ground?
		beq.s	SMZ_Disc_AttachSonic			; if yes, attach Sonic to gear
		clr.b stick_to_convex(a1)
		clr.b	(a3)			; clear attached flag while Sonic is in air
		rts						; return
; ===========================================================================

SMZ_Disc_DetachSonic:
		tst.b	(a3)			; was Sonic attached to gear?
		beq.s	.return					; if not, branch
		clr.b	stick_to_convex(a1)			; clear Sonic's stick-to-convex state flag
		clr.b	(a3)			; clear attached flag for gear

	.return:
		rts						; return
; ===========================================================================

SMZ_Disc_AttachSonic:
		tst.b	(a3)			; was Sonic already attached to gear?
		bne.s	.moveSonic				; if yes, branch

		move.b	#1,(a3)		; set attached flag for gear
		btst	#status.player.rolling,obStatus(a1)	; is Sonic rolling?
		bne.s	.stickToConvex				; if yes, branch
		clr.b	obAnim(a1)				; set Sonic's animation back to walking (ID 0)
	.stickToConvex:
		bclr	#status.player.pushing,obStatus(a1)	; clear Sonic's pushing flag
		move.b	#1,obPrevAni(a1)			; restart Sonic's animation
		move.b	#1,stick_to_convex(a1)			; set Sonic's stick-to-convex state flag for the gear
; ---------------------------------------------------------------------------

.moveSonic:
		move.w	obInertia(a1),d0			; get Sonic's current ground speed
		tst.w	SMZ_disc_spot_speed(a0)			; is gear moving clockwise? (it always is)
		bpl.s	.clockwiseMinSpeed			; if yes, branch

	.counterclockwiseMinSpeed:
		cmpi.w	#-$400,d0				; is Sonic's speed at least $400? (to the left)
		ble.s	.counterclockwiseMaxSpeed		; if yes, branch
		move.w	#-$400,obInertia(a1)			; force Sonic's minimum speed on gear
		rts						; return
; ---------------------------------------------------------------------------

	.counterclockwiseMaxSpeed:
		cmpi.w	#-$F00,d0				; is Sonic's speed greater than $F00? (to the left)
		bge.s	.return					; if not, branch
		move.w	#-$F00,obInertia(a1)			; limit Sonic's maximum speed on gear
	.return:
		rts						; return
; ===========================================================================

	.clockwiseMinSpeed:
		cmpi.w	#$400,d0				; is Sonic's speed at least $400? (to the right)
		bge.s	.clockwiseMaxSpeed			; if yes, branch
		move.w	#$400,obInertia(a1)			; force Sonic's minimum speed on gear
		rts						; return
; ---------------------------------------------------------------------------

	.clockwiseMaxSpeed:
		cmpi.w	#$F00,d0				; is Sonic's speed greater than $F00? (to the right)
		ble.s	.return2				; if not, branch
		move.w	#$F00,obInertia(a1)			; limit Sonic's maximum speed on gear
	.return2:
		rts						; return
; End of function SMZ_Disc_MoveSonic

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to move the small spot inside the gear circularly
; ---------------------------------------------------------------------------

SMZ_Disc_MoveSpot:
		move.w	SMZ_disc_spot_speed(a0),d0			; get object circling speed (can be positive or negative)
		add.w	d0,obAngle(a0)				; add speed to current angle

		move.b	obAngle(a0),d0				; get current angle
		jsr	(CalcSine).l				; calculate sine and cosine for current angle
		move.w	SMZ_disc_origY(a0),d2			; get initial X-position
		move.w	SMZ_disc_origX(a0),d3			; get initial Y-position

		moveq	#0,d4					; clear d4
		move.b	SMZ_disc_spot_distance(a0),d4		; get radius distance for spot
		lsl.w	#8,d4					; shift radius into upper byte
		move.l	d4,d5					; copy radius
		muls.w	d0,d4					; multiply radius by angle sine
		swap	d4					; use upper word from result
		muls.w	d1,d5					; multiply radius by angle cosine
		swap	d5					; use upper word from result
		add.w	d2,d4					; add initial Y-position to sine
		add.w	d3,d5					; add initial X-position to cosine
		move.w	d4,obY(a0)				; set new X/Y-positions...
		move.w	d5,obX(a0)				; ...to move spot circularly
		rts						; return
; End of function SMZ_Disc_MoveSpot

; ===========================================================================

SMZ_Disc_Display:
		out_of_range2	.delete,SMZ_disc_origX(a0)		; is object out of range? if yes, branch
		jmp	(DisplaySprite).l			; display small spot

	.delete:
        lea (v_player).w,a1
        lea SMZ_disc_sonic_attached(a0),a3
        bsr.w SMZ_Disc_DetachSonic
        lea (v_player2).w,a1
        lea SMZ_disc_sonic_attached+1(a0),a3
        bsr.w SMZ_Disc_DetachSonic
        jmp (UnloadObject).l

; ===========================================================================

Map_SMZ_Disc: binclude "mappings/sprite/SMZ Disc.bin"
