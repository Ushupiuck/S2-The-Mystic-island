; ---------------------------------------------------------------------------
; Object 18 - ordinary platforms (MD main CPU)
; S3&K movement core, S1 vertical travel/fall/switch rise, S2 full solidity.
;
; Subtype word: CCCF IIII STTT MMMM
;   M = movement, T = shape, S = rider sag (ignored by the rising trap),
;   I = shared platform interaction (top/full/conveyor/hanging/harmful).
;   F = fall after arriving, once either standing rider arms it.
;   C = switch-channel low bits for E/F; otherwise bits 13-14 select phase/corner.
;   E/F select switch channels 8-F / 0-7 respectively.
; Placement X/Y flips XOR the phase/corner. Vertical paths are centred on Y;
; horizontal/diagonal paths use S3&K's endpoint origin. Squares use the centre.
; ---------------------------------------------------------------------------

Plat_movement:	equ objoff_2E	; long: cached movement routine
Plat_originX:	equ objoff_32	; word: horizontal origin
Plat_rawY:	equ objoff_34	; long: unsagged position, including fraction
Plat_originY:	equ objoff_38	; word: vertical origin
Plat_phase:	equ objoff_3A	; byte: phase/corner, combined with placement flips
Plat_sag:	equ objoff_3B	; byte: sine angle, 0-$40
Plat_timer:	equ objoff_3C	; word: fall/switch delay
Plat_state:	equ objoff_3E	; byte: rising/long-horizontal state
Plat_flags:	equ objoff_3F	; byte: bit 0 sag, 1 intangible, 2 fall enabled, 3 armed
Plat_position:	equ objoff_40	; word: long-horizontal 8.8 position
Plat_speed:	equ objoff_42	; word: long-horizontal 8.8 speed
Plat_loadwidth:	equ objoff_44	; word: horizontal retention interval
Plat_cullX:	equ objoff_46	; word: rightmost retained origin
Plat_hanger:	equ objoff_48	; word: spawned D9 child; 0 = retry allocation
Plat_fall_check:	equ objoff_4A	; byte: oscillator rate offset, or endpoint selector

Obj18:
		move.w	obSubtype(a0),d0
		lsr.w	#3,d0
		andi.w	#$E,d0		; shape is independent of full solidity
		cmpi.w	#min(Obj18_Conf_End-Obj18_Conf,2*min(Map_Obj18_GHZ_frames,Map_Obj18_EHZ_frames)),d0
		blo.s	.shape_ready
		moveq	#0,d0			; invalid shape uses the first configuration
.shape_ready:
		lea	Obj18_Conf(pc),a2
		adda.w	d0,a2
		move.b	(a2)+,obActWid(a0)
		move.b	(a2)+,obFrame(a0)
		move.l	#Map_Obj18_GHZ,obMap(a0)
		move.b	#Map_Obj18_GHZ_height,height_pixels(a0)
		cmpi.b	#id_EHZ,(Current_Zone).w
		bne.s	.art_ready
		move.l	#Map_Obj18_EHZ,obMap(a0)
		move.b	#Map_Obj18_EHZ_height,height_pixels(a0)
.art_ready:
		move.w	#make_art_tile(ArtTile_Level,2,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.w	obX(a0),Plat_originX(a0)
		move.l	obY(a0),Plat_rawY(a0)
		move.w	obY(a0),Plat_originY(a0)
		move.w	#$280,Plat_loadwidth(a0)
		move.w	obX(a0),Plat_cullX(a0)
		move.w	obSubtype(a0),d0
		moveq	#0,d1
		btst	#7,d0
		beq.s	.sag_ready
		moveq	#1,d1
.sag_ready:
		move.b	d1,Plat_flags(a0)
		btst	#12,d0
		beq.s	.fall_ready
		bset	#2,Plat_flags(a0)
.fall_ready:
		move.w	d0,d1
		rol.w	#3,d1
		andi.b	#3,d1
		move.b	obStatus(a0),d2
		eor.b	d2,d1
		move.b	d1,Plat_phase(a0)
		move.b	#8,obHeight(a0)
		move.l	#Plat_Top,code(a0)
		bsr.w	Platform_Profile
		lea	Platform_ProfileFlags(pc),a1
		btst	#0,(a1,d0.w)
		beq.s	.solidity_ready
		move.b	#$30,obHeight(a0)
		bset	#4,obRender(a0)
.solidity_ready:
		move.w	obSubtype(a0),d0
		andi.w	#$F,d0
		cmpi.w	#7,d0
		bne.s	.check_square
		bclr	#0,Plat_flags(a0)	; a crushing trap must not sag
.check_square:
		move.w	d0,d1
		subq.w	#8,d1
		cmpi.w	#4,d1
		bhs.s	.check_long
		lsl.w	#2,d1
		lea	(v_oscillate+$2C).w,a2
		tst.w	(a2,d1.w)		; match the oscillator's current square edge
		bpl.s	.movement_ready
		bchg	#0,Plat_phase(a0)
		bra.s	.movement_ready
.check_long:
		cmpi.w	#$C,d0
		bne.s	.movement_ready
		move.w	#$380,Plat_loadwidth(a0)
		move.w	#$100,d1
		btst	#0,Plat_phase(a0)
		beq.s	.long_range
		move.w	#$80,d1		; reversed path spans origin-128 to origin+127
.long_range:
		add.w	d1,Plat_cullX(a0)
.movement_ready:
		lea	Plat_FallChecks(pc),a1
		move.b	(a1,d0.w),Plat_fall_check(a0)
		add.w	d0,d0
		lea	Plat_Movements(pc),a1
		move.w	(a1,d0.w),d0
		adda.w	d0,a1
		move.l	a1,Plat_movement(a0)
		movea.l	code(a0),a1
		jmp	(a1)
; ---------------------------------------------------------------------------
Obj18_Conf:
		; Half-width, frame. Retain the additional S1/S2 configurations for art
		; expansion; the current two-frame mapping sets clamp missing shapes to 0.
		dc.b $20,0, $20,1, $20,2, $40,3, $30,4
Obj18_Conf_End:

Plat_Top:
Plat_Full:
		move.w	obX(a0),-(sp)
		bsr.w	Plat_Move
		move.w	(sp)+,d4
		btst	#1,Plat_flags(a0)
		bne.s	Plat_Display
		bsr.w	Platform_Interact

Plat_Display:
		bsr.w	Plat_UpdateHanging
		move.w	Plat_cullX(a0),d0
		andi.w	#$FF80,d0
		sub.w	(Camera_X_pos_coarse_back).w,d0
		cmp.w	Plat_loadwidth(a0),d0
		bhi.w	Plat_Unload
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
Plat_UpdateHanging:
		bsr.w	Platform_Profile
		subi.b	#platform_hang_top,d0
		cmpi.b	#3,d0
		bhi.w	.return
		btst	#1,Plat_flags(a0)
		bne.w	Plat_RemoveHanging
		tst.w	Plat_hanger(a0)
		bne.s	.existing
		lea	Plat_hanger(a0),a2
		moveq	#0,d0			; classic mode, support release and grab sound
		moveq	#0,d1
		move.b	obActWid(a0),d1
		subq.w	#4,d1			; keep the grip inside the platform ends
		moveq	#0,d2
		move.b	obHeight(a0),d2
		moveq	#0,d3
		move.b	obFrame(a0),d3
		add.w	d3,d3
		lea	Plat_HangingBottoms(pc),a3
		cmpi.b	#id_EHZ,(Current_Zone).w
		bne.s	.bottom
		addq.w	#4,a3
.bottom:
		cmp.w	(a3,d3.w),d2
		bge.s	.offset
		move.w	(a3,d3.w),d2
.offset:
		subi.w	#10,d2			; hands meet the deeper art/solid underside
		jsr	(Hanging_SpawnChild).l
		bcs.s	.return
.existing:
		movea.w	Plat_hanger(a0),a1
		cmpi.l	#Hanging_Child,code(a1)
		bne.s	.lost
		move.w	a0,d0
		cmp.w	Hang_parent(a1),d0
		bne.s	.lost
		move.w	obX(a0),obX(a1)
		move.w	Hang_yoffset(a1),d0
		add.w	obY(a0),d0
		move.w	d0,obY(a1)
		move.l	a0,-(sp)
		movea.l	a1,a0
		jsr	(Hanging_Update).l
		movea.l	(sp)+,a0
.return:
		rts
.lost:
		clr.w	Plat_hanger(a0)		; don't touch a consumed/reused slot
		rts
Plat_RemoveHanging:
		lea	Plat_hanger(a0),a2
Platform_RemoveHanging:
		tst.w	(a2)
		beq.s	.return
		movea.w	(a2),a1
		clr.w	(a2)
		cmpi.l	#Hanging_Child,code(a1)
		bne.s	.return
		move.w	a0,d0
		cmp.w	Hang_parent(a1),d0
		bne.s	.return
		move.l	a0,-(sp)
		movea.l	a1,a0
		jsr	(Hanging_DeleteChild).l
		movea.l	(sp)+,a0
.return:
		rts
Plat_Unload:
		bsr.s	Plat_RemoveHanging
		jsr	(SMZ_ReleaseRiders).l
		jmp	(UnloadObject).l
; Mapping frame bottoms, checked against actual GHZ/EHZ mapping pieces.
; Keep these editable alongside the shapes; the solid body can extend farther.
Plat_HangingBottoms:
		dc.w 20,132			; GHZ frames 0/1
		dc.w 20,84			; EHZ frames 0/1
; ---------------------------------------------------------------------------
; The object manager calls Plat_Top/Plat_Full directly after construction.
; The selected movement is cached once, rather than redispatched from subtype.
Plat_Move:
		movea.l	Plat_movement(a0),a1
		jsr	(a1)
		btst	#2,Plat_flags(a0)
		beq.s	.render_y
		bsr.w	Plat_CheckFalling
.render_y:
		move.w	Plat_rawY(a0),obY(a0)
		btst	#0,Plat_flags(a0)
		beq.s	.return
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		bne.s	.occupied
		tst.b	Plat_sag(a0)
		beq.s	.apply
		subq.b	#4,Plat_sag(a0)
		bra.s	.apply
.occupied:
		cmpi.b	#$40,Plat_sag(a0)
		beq.s	.apply
		addq.b	#4,Plat_sag(a0)
.apply:
		move.b	Plat_sag(a0),d0
		jsr	(CalcSine).l
		asr.w	#6,d0
		add.w	d0,obY(a0)
.return:
		rts
; ---------------------------------------------------------------------------
Plat_Movements:
		dc.w Plat_Stationary-Plat_Movements	; 0
		dc.w Plat_Horizontal64-Plat_Movements	; 1
		dc.w Plat_Horizontal128-Plat_Movements	; 2
		dc.w Plat_Vertical64-Plat_Movements	; 3
		dc.w Plat_Vertical128-Plat_Movements	; 4
		dc.w Plat_DiagonalUp-Plat_Movements	; 5
		dc.w Plat_DiagonalDown-Plat_Movements	; 6
		dc.w Plat_RisingTrap-Plat_Movements	; 7
		dc.w Plat_Square32-Plat_Movements	; 8
		dc.w Plat_Square96-Plat_Movements	; 9
		dc.w Plat_Square160-Plat_Movements	; A
		dc.w Plat_Square224-Plat_Movements	; B
		dc.w Plat_Horizontal256-Plat_Movements	; C
		dc.w Plat_Vertical96-Plat_Movements	; D (S1/S2 additional distance)
		dc.w Plat_SwitchWait-Plat_Movements	; E (switch channels 8-F)
		dc.w Plat_SwitchWait-Plat_Movements	; F (switch channels 0-7)
; ---------------------------------------------------------------------------
Plat_Stationary:
		rts
; ---------------------------------------------------------------------------
Plat_Horizontal64:
		moveq	#64,d1
		moveq	#0,d0
		move.b	(v_oscillate+$A).w,d0
		bra.s	Plat_Horizontal
Plat_Horizontal128:
		move.w	#128,d1
		moveq	#0,d0
		move.b	(v_oscillate+$1E).w,d0
Plat_Horizontal:
		btst	#0,Plat_phase(a0)
		beq.s	.normal
		neg.w	d0
		add.w	d1,d0
.normal:
		add.w	Plat_originX(a0),d0
		move.w	d0,obX(a0)
		rts
; ---------------------------------------------------------------------------
; Retain S1's centred 64/96/128-pixel vertical paths, using S3&K profiles.
Plat_Vertical64:
		moveq	#32,d1
		moveq	#0,d0
		move.b	(v_oscillate+$A).w,d0
		bra.s	Plat_Vertical
Plat_Vertical96:
		moveq	#48,d1
		moveq	#0,d0
		move.b	(v_oscillate+$E).w,d0
		bra.s	Plat_Vertical
Plat_Vertical128:
		moveq	#64,d1
		moveq	#0,d0
		move.b	(v_oscillate+$1E).w,d0
Plat_Vertical:
		sub.w	d1,d0
		btst	#0,Plat_phase(a0)
		beq.s	.normal
		neg.w	d0
.normal:
		add.w	Plat_originY(a0),d0
		move.w	d0,Plat_rawY(a0)
		rts
; ---------------------------------------------------------------------------
Plat_DiagonalUp:
		move.w	#128,d1
		moveq	#0,d0
		move.b	(v_oscillate+$1E).w,d0
		bsr.w	Plat_Horizontal
		bra.s	Plat_DiagonalY
Plat_DiagonalDown:
		move.w	#128,d1
		moveq	#0,d0
		move.b	(v_oscillate+$1E).w,d0
		neg.w	d0
		add.w	d1,d0
		bsr.w	Plat_Horizontal
Plat_DiagonalY:
		moveq	#64,d1
		moveq	#0,d0
		move.b	(v_oscillate+$1E).w,d0
		lsr.w	#1,d0
		btst	#0,Plat_phase(a0)
		beq.s	.normal
		neg.w	d0
		add.w	d1,d0
.normal:
		move.w	Plat_originY(a0),d1
		sub.w	d0,d1
		move.w	d1,Plat_rawY(a0)
		rts
; ---------------------------------------------------------------------------
Plat_Square32:
		moveq	#16,d1
		moveq	#0,d0
		move.b	(v_oscillate+$2A).w,d0
		lsr.w	#1,d0
		move.w	(v_oscillate+$2C).w,d3
		bra.s	Plat_Square
Plat_Square96:
		moveq	#48,d1
		moveq	#0,d0
		move.b	(v_oscillate+$2E).w,d0
		move.w	(v_oscillate+$30).w,d3
		bra.s	Plat_Square
Plat_Square160:
		moveq	#80,d1
		moveq	#0,d0
		move.b	(v_oscillate+$32).w,d0
		move.w	(v_oscillate+$34).w,d3
		bra.s	Plat_Square
Plat_Square224:
		moveq	#112,d1
		moveq	#0,d0
		move.b	(v_oscillate+$36).w,d0
		move.w	(v_oscillate+$38).w,d3
Plat_Square:
		tst.w	d3
		bne.s	.corner_ready
		addq.b	#1,Plat_phase(a0)
		andi.b	#3,Plat_phase(a0)
.corner_ready:
		move.b	Plat_phase(a0),d2
		andi.b	#3,d2
		bne.s	.right
		sub.w	d1,d0
		add.w	Plat_originX(a0),d0
		move.w	d0,obX(a0)
		neg.w	d1
		add.w	Plat_originY(a0),d1
		move.w	d1,Plat_rawY(a0)
		rts
.right:
		subq.b	#1,d2
		bne.s	.bottom
		subq.w	#1,d1
		sub.w	d1,d0
		neg.w	d0
		add.w	Plat_originY(a0),d0
		move.w	d0,Plat_rawY(a0)
		addq.w	#1,d1
		add.w	Plat_originX(a0),d1
		move.w	d1,obX(a0)
		rts
.bottom:
		subq.b	#1,d2
		bne.s	.left
		subq.w	#1,d1
		sub.w	d1,d0
		neg.w	d0
		add.w	Plat_originX(a0),d0
		move.w	d0,obX(a0)
		addq.w	#1,d1
		add.w	Plat_originY(a0),d1
		move.w	d1,Plat_rawY(a0)
		rts
.left:
		sub.w	d1,d0
		add.w	Plat_originY(a0),d0
		move.w	d0,Plat_rawY(a0)
		neg.w	d1
		add.w	Plat_originX(a0),d1
		move.w	d1,obX(a0)
		rts
; ---------------------------------------------------------------------------
Plat_Horizontal256:
		moveq	#$7F,d2
		tst.b	Plat_state(a0)
		bne.s	.brake
		move.w	Plat_speed(a0),d1
		addq.w	#4,d1
		move.w	d1,Plat_speed(a0)
		add.w	d1,Plat_position(a0)
		cmp.b	Plat_position(a0),d2
		bhi.s	.position
		move.b	#1,Plat_state(a0)
		bra.s	.position
.brake:
		move.w	Plat_speed(a0),d1
		subq.w	#4,d1
		move.w	d1,Plat_speed(a0)
		add.w	d1,Plat_position(a0)
		cmp.b	Plat_position(a0),d2
		bls.s	.position
		clr.b	Plat_state(a0)
.position:
		moveq	#0,d0
		move.b	Plat_position(a0),d0
		btst	#0,Plat_phase(a0)
		beq.s	.normal
		neg.w	d0
		add.w	d2,d0
.normal:
		add.w	Plat_originX(a0),d0
		move.w	d0,obX(a0)
		rts
; ---------------------------------------------------------------------------
Plat_FallChecks:
		; 0 stationary delay; positive = shared oscillator's rate word.
		; -1 ceiling stop, -2 long-path turnaround, -3 completed switch rise.
		dc.b 0,$0C,$20,$0C,$20,$20,$20,-1,$2C,$30,$34,$38,-2,$10,-3,-3
		even

Plat_CheckFalling:
		btst	#3,Plat_flags(a0)
		bne.s	.armed
		move.b	obStatus(a0),d0
		andi.b	#$18,d0		; either standing rider latches the request
		beq.s	.return
		bset	#3,Plat_flags(a0)
.armed:
		moveq	#0,d0
		move.b	Plat_fall_check(a0),d0
		beq.s	.stationary
		bmi.s	.special
		lea	(v_oscillate).w,a1
		tst.w	(a1,d0.w)		; zero rate marks the current leg's destination
		beq.s	Plat_StartFalling
.return:
		rts
.stationary:
		bclr	#2,Plat_flags(a0)
		move.w	#30,Plat_timer(a0)
		move.l	#Plat_FallingDelayed,Plat_movement(a0)
		rts
.special:
		addq.b	#1,d0
		beq.s	.trap
		addq.b	#1,d0
		beq.s	.long
		cmpi.l	#Plat_Stationary,Plat_movement(a0)
		beq.s	Plat_StartFalling
		rts
.trap:
		tst.b	Plat_state(a0)
		beq.s	Plat_StartFalling
		rts
.long:
		tst.w	Plat_speed(a0)
		beq.s	Plat_StartFalling
		rts
; ---------------------------------------------------------------------------
Plat_FallingDelayed:
		subq.w	#1,Plat_timer(a0)
		beq.s	Plat_StartFalling
		rts
Plat_StartFalling:
		andi.b	#$F3,Plat_flags(a0)
		move.w	#32,Plat_timer(a0)
		clr.w	obVelY(a0)
		move.l	#Plat_Falling,Plat_movement(a0)
		rts
; ---------------------------------------------------------------------------
Plat_Falling:
		subq.w	#1,Plat_timer(a0)
		bne.s	Plat_FallStep
		bclr	#3,obStatus(a0)
		beq.s	.partner
		lea	(v_player).w,a1
		bsr.s	Plat_DropRider
.partner:
		bclr	#4,obStatus(a0)
		beq.s	.intangible
		lea	(v_player2).w,a1
		bsr.s	Plat_DropRider
.intangible:
		bset	#1,Plat_flags(a0)
		move.l	#Plat_FallStep,Plat_movement(a0)
		move.l	#Plat_FallingIntangible,code(a0)
Plat_FallStep:
		move.w	obVelY(a0),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,Plat_rawY(a0)
		addi.w	#$38,obVelY(a0)
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#$120,d0
		cmp.w	Plat_rawY(a0),d0
		bhs.s	.return
		move.w	#$7F00,Plat_cullX(a0)
.return:
		rts
Plat_DropRider:
		bset	#1,obStatus(a1)
		bclr	#3,obStatus(a1)
		move.b	#2,obRoutine(a1)
		move.w	obVelY(a0),obVelY(a1)
		rts
Plat_FallingIntangible:
		bsr.w	Plat_Move		; release sag smoothly after the riders detach
		bra.w	Plat_Display
; ---------------------------------------------------------------------------
Plat_SwitchWait:
		tst.w	Plat_timer(a0)
		bne.s	.wait
		move.w	obSubtype(a0),d0
		rol.w	#3,d0
		andi.w	#7,d0		; low channel bits in 13-15
		move.w	obSubtype(a0),d1
		andi.w	#$F,d1
		cmpi.w	#$E,d1
		bne.s	.channel_ready
		addq.w	#8,d0
.channel_ready:
		lea	(f_switch).w,a1
		tst.b	(a1,d0.w)
		beq.s	.return
		move.w	#60,Plat_timer(a0)
.return:
		rts
.wait:
		subq.w	#1,Plat_timer(a0)
		bne.s	.return
		move.l	#Plat_SwitchRise,Plat_movement(a0)
		rts
Plat_SwitchRise:
		subq.w	#2,Plat_rawY(a0)
		move.w	Plat_originY(a0),d0
		subi.w	#$200,d0
		cmp.w	Plat_rawY(a0),d0
		bne.s	.return
		move.l	#Plat_Stationary,Plat_movement(a0)
.return:
		rts
; ---------------------------------------------------------------------------
Plat_RisingTrap:
		tst.b	Plat_state(a0)
		bne.s	.rise
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		beq.s	.return
		move.b	#1,Plat_state(a0)
.return:
		rts
.rise:
		move.l	Plat_rawY(a0),obY(a0)
		jsr	(SpeedToPos).l
		move.w	Plat_originY(a0),d0
		subi.w	#$80,d0
		cmp.w	obY(a0),d0
		bhs.s	.check_ceiling
		subq.w	#8,obVelY(a0)
.check_ceiling:
		move.w	obHeight(a0),-(sp)
		move.b	#$C,obHeight(a0)	; S3&K's trap ceiling sensor
		move.l	(v_colladdr1).w,(Collision_addr).w
		jsr	(ObjHitCeiling).l
		move.w	(sp)+,obHeight(a0)
		tst.w	d1
		bpl.s	.check_riders
		sub.w	d1,obY(a0)
		clr.b	Plat_state(a0)
		clr.w	obVelY(a0)
		move.l	obY(a0),Plat_rawY(a0)
		rts
.check_riders:
		move.l	obY(a0),Plat_rawY(a0)
		btst	#3,obStatus(a0)
		beq.s	.partner
		lea	(v_player).w,a1
		bsr.s	Plat_CheckCrush
.partner:
		btst	#4,obStatus(a0)
		beq.w	.return
		lea	(v_player2).w,a1
; The S3&K entrapment probe samples terrain inside each rider's body, using
; their L/R/B collision path. It is not the platform's own ceiling sensor.
Plat_CheckCrush:
		movem.l	a0/a2,-(sp)
		movea.l	a1,a0
		move.w	obX(a0),d3
		move.w	obY(a0),d2
		subq.w	#4,d2
		move.l	(v_colladdr1).w,(Collision_addr).w
		cmpi.b	#$D,obLRBSolidBit(a0)
		beq.s	.path_ready
		move.l	(v_colladdr2).w,(Collision_addr).w
.path_ready:
		lea	(Primary_Angle).w,a4
		clr.b	(a4)
		movea.w	#$10,a3
		moveq	#0,d6
		move.b	obLRBSolidBit(a0),d5
		jsr	(FindFloor).l
		tst.w	d1
		bpl.s	.return
		movea.l	(sp),a2		; the hazard SST is required by KillCharacter
		jsr	(KillCharacter).l
.return:
		movem.l	(sp)+,a0/a2
		rts

; Shared MD collision/surface implementation for Obj17 and Obj18.
; a0 body; d4 previous X. Settings, dimensions and player state stay per object.
Platform_Profile:
		move.w	obSubtype(a0),d0
		lsr.w	#8,d0
		andi.w	#$F,d0
		cmpi.w	#platform_profile_count,d0
		blo.s	.return
		moveq	#platform_top,d0
.return:
		rts
Platform_ProfileFlags:
		dc.b 0,1,1,0,1,1,0,1,0,1,0,1
		even

Platform_Interact:
		bsr.w	Platform_Profile
		cmpi.b	#platform_hurt,d0
		bne.s	.solid
		bra.w	Platform_HurtOverlap
.solid:
		cmpi.b	#platform_hurt_full,d0
		bne.s	.dimensions
		bsr.w	Platform_HurtOverlap
.dimensions:
		moveq	#0,d1
		moveq	#0,d2
		moveq	#0,d3
		move.b	obActWid(a0),d1
		move.b	obHeight(a0),d2
		move.w	d2,d3
		bsr.w	Platform_Profile
		tst.w	d0
		beq.s	.top
		cmpi.b	#platform_conveyor_top,d0
		beq.s	.top
		cmpi.b	#platform_hang_top,d0
		beq.s	.top
		cmpi.b	#platform_conveyor_hang_top,d0
		beq.s	.top
		addi.w	#sonic_solid_width,d1
		addq.w	#1,d3
		jsr	(SolidObject).l
		bsr.w	Platform_Profile
		cmpi.b	#platform_hurt_bottom,d0
		beq.s	.underside
		cmpi.b	#platform_conveyor_hurt_bottom,d0
		bne.s	.belt
.underside:
		swap	d6
		btst	#2,d6
		beq.s	.partnerHurt
		lea	(v_player).w,a1
		jsr	(Spike_HurtCharacter).l
.partnerHurt:
		btst	#3,d6
		beq.s	.belt
		lea	(v_player2).w,a1
		jsr	(Spike_HurtCharacter).l
		bra.s	.belt
.top:
		jsr	(PlatformObject).l
.belt:
		bsr.w	Platform_Profile
		subq.b	#platform_conveyor_top,d0
		cmpi.b	#2,d0
		bls.s	.belt_ready
		subq.b	#5,d0
		cmpi.b	#1,d0
		bhi.s	.return
.belt_ready:
		lea	(v_player).w,a1
		moveq	#3,d6
		bsr.s	.conveyor
		lea	(v_player2).w,a1
		moveq	#4,d6
.conveyor:
		btst	d6,obStatus(a0)
		beq.s	.return
		tst.b	conveyor_applied(a1)
		bne.s	.return
		moveq	#2,d0
		btst	#0,obStatus(a0)
		beq.s	.move
		neg.w	d0
.move:
		add.w	d0,obX(a1)
		move.b	#1,conveyor_applied(a1)
.return:
		rts

Platform_HurtOverlap:
		lea	(v_player).w,a1
		bsr.s	.player
		lea	(v_player2).w,a1
.player:
		tst.l	code(a1)
		beq.s	.return
		moveq	#0,d1
		move.b	obActWid(a0),d1
		addq.w	#8,d1
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		bpl.s	.xAbs
		neg.w	d0
.xAbs:
		cmp.w	d1,d0
		bhi.s	.return
		moveq	#0,d1
		move.b	obHeight(a0),d1
		add.b	obHeight(a1),d1
		move.w	obY(a1),d0
		sub.w	obY(a0),d0
		bpl.s	.yAbs
		neg.w	d0
.yAbs:
		cmp.w	d1,d0
		bhi.s	.return
		jmp	Spike_HurtCharacter
.return:
		rts
