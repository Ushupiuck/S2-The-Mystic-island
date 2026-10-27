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
Plat_parent:	equ objoff_4C	; word: suspension owner; zero on ordinary placements
Plat_oldstatus:	equ obTimeFrame	; byte: previous riders for the ICZ physical rail
Plat_attached_bit = 4              ; private Plat_flags bit; parent drives one update

Plat_Init:
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.w	obSubtype(a0),d0
		lsr.w	#4,d0
		andi.w	#7,d0
		cmpi.w	#5,d0
		blo.s	.shape_ready
		moveq	#0,d0
.shape_ready:
		cmpi.w	#2,d0
		bhs.s	.body_art
		add.w	d0,d0
		lea	Obj18_Conf(pc),a2
		adda.w	d0,a2
		move.b	(a2)+,obActWid(a0)
		move.b	(a2)+,obFrame(a0)
		move.l	#Map_Obj18_GHZ,obMap(a0)
		move.b	#Map_Obj18_GHZ_height,height_pixels(a0)
		cmpi.b	#id_EHZ,(Current_Zone).w
		bne.s	.level_art
		move.l	#Map_Obj18_EHZ,obMap(a0)
		move.b	#Map_Obj18_EHZ_height,height_pixels(a0)
.level_art:
		move.w	#make_art_tile(ArtTile_Level,2,0),obGfx(a0)
		move.b	#8,obHeight(a0)
		bra.s	.art_ready
.body_art:
		bsr.w	Platform_SetBodyArt
.art_ready:
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
		move.l	#Plat_Top,code(a0)
		bsr.w	Platform_Profile
		lea	Platform_ProfileFlags(pc),a1
		btst	#0,(a1,d0.w)
		beq.s	.solidity_ready
		move.w	obSubtype(a0),d0
		andi.w	#$70,d0
		cmpi.w	#$20,d0
		blo.s	.terrain_full
		cmpi.w	#$50,d0
		blo.s	.full_body
.terrain_full:
		move.b	#$30,obHeight(a0)
.full_body:
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
		rts
; ---------------------------------------------------------------------------
Obj18_Conf:
		; Terrain-art shapes 0/1. Shapes 2/3/4 belong to Platform_SetBodyArt.
		dc.b $20,0, $20,1
Obj18_Conf_End:

Obj18:
		bsr.w	Plat_Init
Plat_Top:
Plat_Full:
		move.w	obX(a0),-(sp)
		bsr.w	Plat_Move
		move.w	(sp)+,d4
		btst	#1,Plat_flags(a0)
		bne.s	Plat_Display
		bsr.w	Platform_Interact

Plat_Display:
		bsr.w	PlatformMount_Update
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
		bsr.w	Platform_HangingOffset
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
		bsr.w	PlatformMount_Delete
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
		beq.s	Plat_ApplyY
		bsr.w	Plat_CheckFalling
Plat_ApplyY:
		move.w	Plat_rawY(a0),obY(a0)
		btst	#0,Plat_flags(a0)
		beq.s	.return
		move.b	obStatus(a0),d0
		or.b	PlatformMount_standing(a0),d0
		andi.b	#$18,d0
		bne.s	.occupied
		tst.b	Plat_sag(a0)
		beq.s	.return
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
		or.b	PlatformMount_standing(a0),d0
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
		or.b	PlatformMount_standing(a0),d0
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
		; Bits: 0 full solid, 1 harmful underside, 2 conveyor top.
		dc.b 0,1,3,4,5,7,0,1,4,5,0,1
		even

Platform_Interact:
		bsr.w	Platform_Profile
		cmpi.b	#platform_hurt,d0
		beq.w	Platform_HurtOverlap
		lea	Platform_ProfileFlags(pc),a1
		move.b	(a1,d0.w),d1
		move.w	d1,-(sp)		; collision/damage may clobber every data register
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
		move.w	(sp),d0
		btst	#0,d0
		beq.s	.top
		addi.w	#sonic_solid_width,d1
		addq.w	#1,d3
		jsr	(SolidObject).l
		move.w	(sp),d0
		btst	#1,d0
		beq.s	.belt
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
		move.w	(sp)+,d0
		btst	#2,d0
		beq.s	.return
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

; Shapes 2/3/4: ordinary swing body, ICZ rail body, large spikeball.
; Body graphics belong here; the suspension only owns its anchor/link artwork.
Platform_SetBodyArt:
		move.w	d0,-(sp)
		move.l	#Map_Obj17,obMap(a0)
		move.b	#Map_Obj17_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_GHZ_MZ_Swing,0,0),obGfx(a0)
		move.w	#$180,obPriority(a0)
		move.b	#sprite_bound($18,Map_Obj17_width),obActWid(a0)
		move.b	#8,obHeight(a0)
		clr.b	obFrame(a0)
		cmpi.b	#id_SLZ,(Current_Zone).w
		bne.s	.smz
		move.l	#Map_Obj17_SLZ,obMap(a0)
		move.b	#Map_Obj17_SLZ_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_SLZ_Swing,2,0),obGfx(a0)
		move.b	#sprite_bound($20,Map_Obj17_SLZ_width),obActWid(a0)
		move.b	#$10,obHeight(a0)
.smz:
		cmpi.b	#id_SMZ,(Current_Zone).w
		bne.s	.kind
		move.l	#Map_SMZ_Swing,obMap(a0)
		move.b	#Map_SMZ_Swing_height,height_pixels(a0)
		move.w	#ArtTile_SMZ_Atlas,obGfx(a0)
.kind:
		move.w	(sp)+,d0
		cmpi.w	#4,d0
		beq.s	.ball
		cmpi.w	#3,d0
		bne.s	.return
		move.l	#Map_SwingRail,obMap(a0)
		move.b	#Map_SwingRail_height,height_pixels(a0)
		cmpi.b	#id_SLZ,(Current_Zone).w
		bne.s	.rail_smz
		move.l	#Map_SwingRail_SLZ,obMap(a0)
		move.b	#Map_SwingRail_SLZ_height,height_pixels(a0)
.rail_smz:
		cmpi.b	#id_SMZ,(Current_Zone).w
		bne.s	.rail_facing
		move.l	#Map_SwingRail_SMZ,obMap(a0)
		move.b	#Map_SwingRail_SMZ_height,height_pixels(a0)
.rail_facing:
		move.b	obStatus(a0),d0
		andi.b	#1,d0
		or.b	d0,obRender(a0)
.return:
		rts
.ball:
		cmpi.b	#id_SMZ,(Current_Zone).w
		beq.s	.ball_size
		move.l	#Map_GBall,obMap(a0)
		move.b	#Map_GBall_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_GHZ_Giant_Ball,2,0),obGfx(a0)
		move.b	#1,obFrame(a0)
.ball_size:
		move.b	#$18,obHeight(a0)
		move.b	#sprite_bound($18,Map_GBall_width),obActWid(a0)
		rts

Platform_HangingOffset:
		move.w	obSubtype(a0),d2
		andi.w	#$70,d2
		cmpi.w	#$20,d2
		blo.s	.terrain
		cmpi.w	#$50,d2
		bhs.s	.terrain
		cmpi.w	#$40,d2
		beq.s	.ball
		moveq	#8,d2
		cmpi.b	#id_SLZ,(Current_Zone).w
		bne.s	.grip_smz
		moveq	#32,d2
.grip_smz:
		cmpi.b	#id_SMZ,(Current_Zone).w
		bne.s	.height
.ball:
		moveq	#24,d2
		bra.s	.height
.terrain:
		moveq	#0,d3
		move.b	obFrame(a0),d3
		add.w	d3,d3
		lea	Plat_HangingBottoms(pc),a3
		cmpi.b	#id_EHZ,(Current_Zone).w
		bne.s	.bottom
		addq.w	#4,a3
.bottom:
		move.w	(a3,d3.w),d2
.height:
		moveq	#0,d3
		move.b	obHeight(a0),d3
		cmp.w	d3,d2
		bge.s	.offset
		move.w	d3,d2
.offset:
		subi.w	#10,d2
		rts

; Obj17 interaction seeds: independent Obj18 words, with artwork supplied by
; the suspension constructor ID. Multi-body arrangements remain deferred.
Platform_SwingPresets:
		dc.w $0000,$0100,$0200,$0300,$0400,$0500,$0600,$0700,$0800,$0900,$0A00,$0B00
Platform_SwingPresets_End:
Platform_SwingPresetCount = (Platform_SwingPresets_End-Platform_SwingPresets)/2

; a0 suspension -> a1 body. Carry set = no free SST, retry on a later update.
Platform_CreateSwingBody:
		jsr	(FindFreeObj).l
		bne.w	.full
		moveq	#0,d0
		move.b	swing_preset(a0),d0
		add.w	d0,d0
		lea	Platform_SwingPresets(pc),a2
		move.w	(a2,d0.w),d0
		moveq	#0,d1
		move.b	swing_body_shape(a0),d1
		lsl.w	#4,d1
		or.w	d1,d0
.settings:
		move.w	d0,obSubtype(a1)
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		andi.b	#3,obStatus(a1)
		move.l	a0,-(sp)
		movea.l	a1,a0
		bsr.w	Plat_Init
		movea.l	(sp),a2
		move.w	a2,Plat_parent(a0)
		move.b	PlatformMount_settings(a2),PlatformMount_settings(a0)
		bset	#Plat_attached_bit,Plat_flags(a0)
		move.b	#2,obRoutine(a0)
		clr.w	respawn_addr(a0)
		move.l	#Platform_SuspendedBody,code(a0)
		movea.l	a0,a1
		movea.l	(sp)+,a0
		move.w	a1,swing_body(a0)
		andi.b	#$FE,ccr
		rts
.full:
		ori.b	#1,ccr
		rts

; A suspended body has a stable code pointer across release. Its parent drives
; attached physics once after moving; its own slot only validates ownership.
Platform_SuspendedBody:
		bsr.w	Platform_SuspendedParent
		bne.w	Platform_DeleteBody
		btst	#Plat_attached_bit,Plat_flags(a0)
		beq.s	.released
		rts
.released:
		cmpi.b	#$C,obRoutine(a0)
		beq.w	Platform_FloatingBody
		bra.w	Platform_FreeBody

Platform_SuspendedParent:
		movea.w	Plat_parent(a0),a1
		cmpi.l	#SwingingPtfm,code(a1)
		bne.s	.return
		move.w	a0,d0
		cmp.w	swing_body(a1),d0
.return:
		rts

; Internal entry: SwingingPtfm_Interact has validated code and reciprocal ownership.
Platform_UpdateSuspended:
		movea.w	Plat_parent(a0),a1
		move.b	obStatus(a0),Plat_oldstatus(a0)
		move.w	obX(a0),Plat_position(a0)
		move.w	obY(a0),Plat_speed(a0)
		move.w	obX(a1),obX(a0)
		move.l	obY(a1),Plat_rawY(a0)
		bsr.w	Plat_ApplyY
		move.w	Plat_position(a0),d4
		bsr.w	Platform_Interact
		bsr.w	PlatformMount_Update
		bsr.w	Plat_UpdateHanging
		jmp	(DisplaySprite).l

; a0 physical body, d0/d1 launch X/Y. Reuse this SST and its grip/player refs.
Platform_ReleaseSuspended:
		bclr	#Plat_attached_bit,Plat_flags(a0)
		move.w	d0,obVelX(a0)
		move.w	d1,obVelY(a0)
		move.w	obX(a0),Plat_originX(a0)
		move.w	obY(a0),Plat_originY(a0)
		clr.b	Plat_state(a0)
		move.b	#$A,obRoutine(a0)
		rts

Platform_DeleteBody:
		bsr.w	PlatformMount_Delete
		bsr.w	Plat_RemoveHanging
		jsr	(SMZ_ReleaseRiders).l
		bsr.w	Platform_SuspendedParent
		bne.s	.delete
		clr.w	swing_body(a1)
.delete:
		jmp	(DeleteObject).l

Platform_SwingMomentumInput:
		tst.w	swing_body(a0)
		beq.s	.entry_return
		movea.w	swing_body(a0),a1
		cmpi.l	#Platform_SuspendedBody,code(a1)
		bne.s	.entry_return
		move.l	a0,-(sp)
		movea.l	a0,a2
		movea.l	a1,a0
		bsr.w	Platform_Profile
		cmpi.b	#platform_hurt,d0
		beq.s	.restore
		tst.w	(Debug_placement_mode).w
		bne.s	.restore
		lea	(v_player).w,a1
		moveq	#3,d6
		bsr.s	.player
		lea	(v_player2).w,a1
		moveq	#4,d6
		bsr.s	.player
.restore:
		movea.l	(sp)+,a0
.entry_return:
		rts
.player:
		cmpi.b	#4,obRoutine(a1)
		bhs.w	.return
		move.w	obVelX(a1),d3
		btst	#0,obStatus(a0)
		beq.s	.direction
		neg.w	d3
.direction:
		tst.w	d3
		ble.w	.return
		move.w	obY(a1),d0
		moveq	#0,d1
		move.b	obHeight(a1),d1
		add.w	d1,d0
		sub.w	obY(a0),d0
		moveq	#0,d1
		move.b	obHeight(a0),d1
		add.w	d1,d0
		addi.w	#12,d0
		cmpi.w	#24,d0
		bhi.w	.return
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		btst	#0,obStatus(a0)
		beq.s	.railSide
		neg.w	d0
.railSide:
		moveq	#0,d1
		move.b	obActWid(a0),d1
		subi.w	#12,d1
		cmp.w	d1,d0
		blt.s	.return
		addi.w	#28,d1
		cmp.w	d1,d0
		bgt.s	.return
		tst.b	swing_mode_started(a2)
		bne.s	.blockRail
		cmpi.w	#$200,d3
		blt.s	.blockRail
		btst	d6,Plat_oldstatus(a0)
		beq.s	.newRider
		asr.w	#1,d3
.newRider:
		asr.w	#1,d3
		cmpi.w	#$400,d3
		ble.s	.impulse
		move.w	#$400,d3
.impulse:
		move.w	d3,swing_ang_vel(a2)
		move.b	#1,swing_mode_started(a2)
.blockRail:
		moveq	#0,d0
		move.b	obActWid(a0),d0
		subi.w	#12,d0
		btst	#0,obStatus(a0)
		beq.s	.railPosition
		neg.w	d0
.railPosition:
		add.w	obX(a0),d0
		move.w	d0,obX(a1)
		clr.w	obVelX(a1)
		clr.w	obInertia(a1)
.return:
		rts


; Shared S2/ICZ free body: terrain first when above water, quarter-speed bounce,
; friction, directional wall stops, then enabled live-water floating and drift.
Platform_FreeBody:
		move.l	Plat_rawY(a0),obY(a0)
		move.w	obX(a0),Plat_position(a0)
		move.w	obY(a0),Plat_speed(a0)
		jsr	(ObjectMove).l
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#$100,d0
		cmp.w	obY(a0),d0
		blo.w	Platform_DeleteBody
		tst.b	Plat_state(a0)
		bne.w	.slide
		addi.w	#$18,obVelY(a0)
		tst.w	obVelY(a0)
		bmi.w	.collision
		jsr	(ObjHitFloor).l
		move.w	d1,d5
		tst.b	(Water_flag).w
		beq.s	.floor
		move.w	(v_waterpos2).w,d0
		cmp.w	Plat_speed(a0),d0
		blo.s	.floor
		cmp.w	obY(a0),d0
		bhi.s	.floor
		tst.w	d5
		bpl.s	.water
		move.w	obY(a0),d1
		add.w	d5,d1
		cmp.w	d0,d1
		blt.s	.floor
.water:
		move.w	d0,obY(a0)
		move.b	#$C,obRoutine(a0)
		clr.w	obVelY(a0)
		move.w	#$100,d0
		tst.w	obVelX(a0)
		bpl.s	.drift
		neg.w	d0
.drift:
		move.w	d0,obVelX(a0)
		bra.w	.collision
.floor:
		tst.w	d5
		bpl.w	.collision
		add.w	d5,obY(a0)
		move.w	obVelY(a0),d0
		cmpi.w	#$100,d0
		blo.s	.land
		asr.w	#2,d0
		neg.w	d0
		move.w	d0,obVelY(a0)
		bra.s	.wall
.land:
		clr.w	obVelY(a0)
		move.b	#1,Plat_state(a0)
.slide:
		jsr	(ObjHitFloor).l
		cmpi.w	#12,d1
		bgt.s	.edge
		add.w	d1,obY(a0)
.friction:
		move.w	obVelX(a0),d0
		beq.s	.wall
		move.w	#$10,d1
		tst.w	d0
		bpl.s	.slow
		neg.w	d1
.slow:
		move.w	d0,d2
		sub.w	d1,d0
		eor.w	d0,d2
		bpl.s	.speed
		moveq	#0,d0
.speed:
		move.w	d0,obVelX(a0)
		bra.s	.wall
.edge:
		clr.b	Plat_state(a0)
.wall:
		move.w	obVelX(a0),d0
		beq.s	.collision
		bsr.w	Platform_BodyWall
		tst.w	d1
		bpl.s	.collision
		tst.w	obVelX(a0)
		bpl.s	.right
		sub.w	d1,obX(a0)
		bra.s	.stopped
.right:
		add.w	d1,obX(a0)
.stopped:
		clr.w	obVelX(a0)
.collision:
		bra.s	Platform_BodyInteract

Platform_FloatingBody:
		tst.b	(Water_flag).w
		bne.s	.water
		move.b	#$A,obRoutine(a0)
		clr.b	Plat_state(a0)
		bra.w	Platform_FreeBody
.water:
		move.l	Plat_rawY(a0),obY(a0)
		move.w	obX(a0),Plat_position(a0)
		move.w	obY(a0),Plat_speed(a0)
		jsr	(ObjectMove).l
		moveq	#0,d0
		move.b	(v_oscillate+$12).w,d0	; 0-63 position, not the following signed rate
		lsr.w	#3,d0
		subq.w	#4,d0
		add.w	(v_waterpos2).w,d0
		move.w	d0,obY(a0)
		move.w	obVelX(a0),d0
		beq.s	.solid
		bsr.s	Platform_BodyWall
		tst.w	d1
		bpl.s	.solid
		move.w	Plat_position(a0),obX(a0)
		clr.w	obVelX(a0)
.solid:
Platform_BodyInteract:
		move.l	obY(a0),Plat_rawY(a0)
		bsr.w	Plat_ApplyY
		move.w	Plat_position(a0),d4
		bsr.w	Platform_Interact
		bsr.w	PlatformMount_Update
		bsr.w	Plat_UpdateHanging
Platform_BodyDisplay:
		out_of_range.w	Platform_DeleteBody
		jmp	(DisplaySprite).l

; Input d0 sign is the direction to probe. Returned d1 is signed distance.
Platform_BodyWall:
		moveq	#0,d3
		move.b	obActWid(a0),d3
		tst.w	d0
		bmi.s	.left
		jmp	ObjHitWallRight
.left:
		not.w	d3
		jmp	ObjHitWallLeft
