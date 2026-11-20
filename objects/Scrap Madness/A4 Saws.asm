; ===========================================================================
; $A4 saws. Choose the blade bank at construction. The placement settings
; select motion independently. SBZ defaults from sonicretro/s1disasm 2c51d46.
; ===========================================================================

; Subtype: free / movement / flags / speed or delay. A zero value stops any mode.
Saw_TimerBit		equ 4
Saw_FarEndBit		equ 7
Saw_MotionMask		equ $F
Saw_ValueMask		equ $F
Saw_DelayUnit		equ 10
Saw_MotionDiagonal	equ 2
Saw_MotionClockX	equ 3
Saw_MotionClockY	equ 4
Saw_MotionRushLeft	equ 5
Saw_MotionRushRight	equ 6
Saw_BladeStroke		equ 80
Saw_RailStages		equ 9
Saw_RailSpacing		equ 9
Saw_RailStroke		equ (Saw_RailStages-1)*Saw_RailSpacing+1
Saw_RailAnchor		equ 80
Saw_BareMetalFrame	equ Map_MMZ_Saw_frames-2

saw_distance:	equ objoff_2E	; 8.8 travel left before the next endpoint
saw_timer:	equ objoff_30	; endpoint wait
saw_step_x:	equ objoff_32	; paired 16.16 increments, set at construction
saw_step_y:	equ objoff_36
saw_origin_x:	equ objoff_3A
saw_handle:	equ objoff_3C	; reciprocal rail pointer, zero for a bare blade
saw_parent:	equ objoff_3E	; rail only
saw_rail_next:	equ objoff_3E	; blade only: 8.8 distance to the next rail pose
saw_sound:	equ objoff_40	; updates visible
saw_stage_step:	equ objoff_42	; +1 extending / -1 retracting
saw_spin_delay:	equ objoff_43	; frame-pair delay minus one
saw_speed:	equ objoff_44	; unsigned 8.8 distance per update
saw_hold:	equ objoff_46	; endpoint wait length, zero for continuous travel
saw_stroke:	equ objoff_48	; full 8.8 travel distance along each enabled axis
saw_bare_frame:	equ objoff_4A	; frame-pair base for an unmounted blade
saw_hitbox:	equ objoff_4B	; restored when a speeding saw starts moving

; Clock-synchronized cutters overlay the paired movement increments.
saw_osc_source:	equ saw_step_x
saw_osc_axis:	equ saw_step_x+2
saw_osc_base:	equ saw_step_y

SMZ_Saws:
		lea	Saw_ScrapBlade(pc),a2
		cmpi.b	#id_MMZ,(Current_Zone).w
		bne.s	.settings
		tst.b	(Current_Act).w		; only MMZ1 loads the metal saw bank
		bne.s	.settings
		lea	Saw_MetalBlade(pc),a2
.settings:
		move.w	obSubtype(a0),d6
		move.w	d6,d5
		lsr.w	#8,d5			; movement and reserved nibble
		andi.w	#Saw_MotionMask,d5
		move.w	d6,d2
		andi.w	#Saw_ValueMask,d2
		beq.w	Saw_InitStationary
		cmpi.w	#Saw_MotionRushRight,d5
		bhi.w	Saw_InitStationary
		cmpi.w	#Saw_MotionDiagonal,d5
		bhi.w	Saw_InitStockMotion

		addq.w	#1,d5			; turn motion 0/1/2 into axes 1/2/3
		moveq	#0,d4
		btst	#Saw_TimerBit,d6
		bne.s	.timed
		lsl.w	#6,d2			; speed field * quarter pixel in 8.8
		bra.s	.rail
.timed:
		move.w	d2,d4
		mulu.w	#Saw_DelayUnit,d4
		move.w	#$100,d2
.rail:
		cmpi.w	#3,d5
		bne.s	.bare
		cmpi.l	#Map_MMZ_Saw,(a2)
		beq.w	Saw_InitRail
.bare:
		bsr.s	Saw_InitBlade
		move.w	#Saw_BladeStroke<<8,saw_stroke(a0)
		bsr.w	Saw_InitVector
		btst	#Saw_FarEndBit,d6
		beq.w	Saw_BeginSweep
		bsr.w	Saw_Reverse
		bra.w	Saw_BeginSweep

; a2 = mapping, art, priority, hitbox and animation profile.
Saw_InitBlade:
		move.l	(a2)+,obMap(a0)
		move.w	(a2)+,obGfx(a0)
		move.w	(a2)+,obPriority(a0)
		move.w	#32<<8|32,height_pixels(a0)
		move.b	(a2)+,obColType(a0)
		move.b	obColType(a0),saw_hitbox(a0)
		move.b	(a2)+,saw_spin_delay(a0)
		move.b	(a2),obFrame(a0)
		move.b	(a2),saw_bare_frame(a0)
		move.w	obX(a0),saw_origin_x(a0)
		move.b	obStatus(a0),obRender(a0)
		ori.b	#4,obRender(a0)
		rts

Saw_ScrapBlade:
		dc.l Map_SMZ_Saw
		dc.w ArtTile_SMZ_Atlas,$200
		dc.b $80|$22,2,2
		even
Saw_MetalBlade:
		dc.l Map_MMZ_Saw
		dc.w ArtTile_MMZ_Atlas,$180
		dc.b $80|Touch_Size_MMZSaw_ID,1,Saw_BareMetalFrame
		even

Saw_InitStationary:
		bsr.s	Saw_InitBlade
		bsr.s	Saw_StockDisplay
		move.l	#Saw_Draw,code(a0)
		bra.w	Saw_Draw

; The Scrap Madness stationary and stock cutters use their original holder.
Saw_StockDisplay:
		cmpi.l	#Map_SMZ_Saw,obMap(a0)
		bne.s	.return
		clr.b	obFrame(a0)
		move.b	#4,obRender(a0)
		move.b	#2,obRoutine(a0)
		move.b	#Map_SMZ_Saw_height,height_pixels(a0)
.return:
		rts

; Retain the two global oscillator channels and the original speeding triggers.
Saw_InitStockMotion:
		bsr.w	Saw_InitBlade
		bsr.s	Saw_StockDisplay
		cmpi.w	#Saw_MotionClockY,d5
		bls.s	.oscillating
		clr.b	obColType(a0)
		move.l	#Saw_WaitLeft,code(a0)
		cmpi.w	#Saw_MotionRushLeft,d5
		beq.w	Saw_WaitLeft
		move.l	#Saw_WaitRight,code(a0)
		bra.w	Saw_WaitRight
.oscillating:
		subi.w	#Saw_MotionClockX,d5
		mulu.w	#6,d5
		lea	Saw_Oscillators(pc,d5.w),a1
		move.w	(a1)+,saw_osc_source(a0)
		move.w	(a1)+,d2
		move.w	d2,saw_osc_axis(a0)
		move.w	(a0,d2.w),d1
		btst	#0,obStatus(a0)
		beq.s	.save
		sub.w	(a1),d1
.save:
		move.w	d1,saw_osc_base(a0)
		move.l	#Saw_ClockSweep,code(a0)
		bra.s	Saw_ClockSweep

; Oscillator byte, coordinate offset, flipped origin bias.
Saw_Oscillators:
		dc.w v_oscillate+$E,obX,$60
		dc.w v_oscillate+6,obY,$80

Saw_ClockSweep:
		movem.w	saw_osc_source(a0),d1-d3
		movea.w	d1,a1
		moveq	#0,d0
		move.b	(a1),d0
		btst	#0,obStatus(a0)
		beq.s	.position
		neg.w	d0
.position:
		sub.w	d0,d3
		move.w	d3,(a0,d2.w)
		move.b	saw_spin_delay(a0),d0
		bsr.w	Saw_AnimatePair
		tst.b	obRender(a0)
		bpl.w	Saw_Draw
		cmpi.w	#obY,d2
		beq.s	.vertical
		move.w	(v_framecount).w,d0
		andi.w	#$F,d0
		beq.w	Saw_BuzzDraw
		bra.w	Saw_Draw
.vertical:
		cmpi.b	#$18,(a1)
		beq.w	Saw_BuzzDraw
		bra.w	Saw_Draw

; The two directional triggers retain their original different X distances.
Saw_WaitLeft:
		move.w	(v_player+obX).w,d0
		subi.w	#192,d0
		bcs.w	Saw_Cull
		cmp.w	obX(a0),d0
		blo.w	Saw_Cull
		move.w	#$600,d1
		bra.s	Saw_Trigger

Saw_WaitRight:
		move.w	(v_player+obX).w,d0
		addi.w	#224,d0
		cmp.w	obX(a0),d0
		bhs.w	Saw_Cull
		move.w	#-$600,d1

Saw_Trigger:
		move.w	(v_player+obY).w,d0
		subi.w	#128,d0
		cmp.w	obY(a0),d0
		bhs.w	Saw_Draw
		addi.w	#256,d0
		cmp.w	obY(a0),d0
		blo.w	Saw_Draw
		move.l	#Saw_Projectile,code(a0)
		move.w	d1,obVelX(a0)
		move.b	saw_hitbox(a0),obColType(a0)
		move.b	saw_bare_frame(a0),obFrame(a0)
		move.w	#SndID_LaserBeam,d0
		jsr	(PlaySound_Special).l
		bra.w	Saw_Cull			; first visible on the next moving update

Saw_Projectile:
		jsr	(ObjectMove).l
		move.w	obX(a0),saw_origin_x(a0)
		move.b	saw_spin_delay(a0),d0
		bsr.w	Saw_AnimatePair
		bra.w	Saw_Draw


; Reserve the fixed rail before touching the blade. A full pool can retry.
; d2 = 8.8 speed, d4 = pause length, d5 = axes, d6 = placement settings.
Saw_InitRail:
		jsr	(FindFreeObj).l
		beq.s	.allocate
		rts
.allocate:
		bsr.w	Saw_InitBlade
		move.w	a1,saw_handle(a0)
		move.w	a0,saw_parent(a1)
		move.l	#Saw_Handle,code(a1)
		move.l	#Map_MMZ_SawHandle,obMap(a1)
		move.w	#Map_MMZ_SawHandle_height<<8|Map_MMZ_SawHandle_width,height_pixels(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.w	#Map_MMZ_Saw_height<<8|Map_MMZ_Saw_width,height_pixels(a0)
		move.w	#Saw_RailStroke<<8,saw_stroke(a0)
		move.b	#1,saw_stage_step(a0)
		move.b	#-1,obPrevAni(a0)
		bsr.w	Saw_InitVector

		; The rail preset starts one pixel past the authored endpoint.
		moveq	#1,d0
		moveq	#1,d1
		btst	#0,obStatus(a0)
		beq.s	.y
		neg.w	d0
.y:
		btst	#1,obStatus(a0)
		beq.s	.place
		neg.w	d1
.place:
		add.w	d0,obX(a0)
		add.w	d1,obY(a0)
		btst	#Saw_FarEndBit,d6
		beq.s	Saw_BeginSweep
		move.b	#Saw_RailStages,obAnim(a0)
		muls.w	#Saw_RailAnchor,d0
		muls.w	#Saw_RailAnchor,d1
		sub.w	d0,obX(a1)
		sub.w	d1,obY(a1)
		bsr.s	Saw_Reverse

; A waiting blade holds the previous leg's direction until the next leg starts.
Saw_BeginSweep:
		move.w	d4,saw_hold(a0)
		beq.s	.continuous
		subq.w	#1,d4				; count the constructor's update
		move.w	d4,saw_timer(a0)
		bsr.s	Saw_Reverse
		move.l	#Saw_Hold,code(a0)
		bra.w	Saw_BoundedAnimate
.continuous:
		bsr.s	Saw_StartLeg
		bra.w	Saw_BoundedAnimate

Saw_Reverse:
		neg.w	obVelX(a0)
		neg.w	obVelY(a0)
		neg.l	saw_step_x(a0)
		neg.l	saw_step_y(a0)
		neg.b	saw_stage_step(a0)
		rts

Saw_StartLeg:
		move.l	#Saw_Travel,code(a0)
		move.w	saw_stroke(a0),saw_distance(a0)
		move.w	#$100,saw_rail_next(a0)
		rts

Saw_Hold:
		subq.w	#1,saw_timer(a0)
		bne.w	Saw_BoundedAnimate
		bsr.s	Saw_Reverse
		bsr.s	Saw_StartLeg
		bra.w	Saw_BoundedAnimate

; Apply cached 16.16 deltas. A short final step lets any speed stop exactly
; on the endpoint, with no accumulated rounding on either coordinate.
Saw_Travel:
		move.w	saw_speed(a0),d0
		sub.w	d0,saw_distance(a0)
		bcs.s	.short_step
		movem.l	saw_step_x(a0),d1-d2
.move:
		add.l	d1,obX(a0)
		add.l	d2,obY(a0)
		tst.w	saw_handle(a0)
		beq.s	.endpoint
		sub.w	d0,saw_rail_next(a0)
		bgt.s	.endpoint
		addi.w	#Saw_RailSpacing<<8,saw_rail_next(a0)
		move.b	saw_stage_step(a0),d1
		add.b	d1,obAnim(a0)
.endpoint:
		tst.w	saw_distance(a0)
		bne.w	Saw_BoundedAnimate
		move.w	saw_hold(a0),saw_timer(a0)
		beq.s	.reverse
		move.l	#Saw_Hold,code(a0)
		bra.w	Saw_BoundedAnimate
.reverse:
		bsr.w	Saw_Reverse
		bsr.s	Saw_StartLeg
		bra.w	Saw_BoundedAnimate
.short_step:
		add.w	saw_distance(a0),d0
		clr.w	saw_distance(a0)
		moveq	#0,d3
		move.w	d0,d3
		lsl.l	#8,d3
		bsr.w	Saw_SignedVector
		bra.s	.move

; Set the two components once. Both axes use the same configurable speed.
Saw_InitVector:
		move.w	d2,saw_speed(a0)
		clr.l	obVelX(a0)
		btst	#0,d5
		beq.s	.vertical
		move.w	d2,obVelX(a0)
		btst	#0,obStatus(a0)
		beq.s	.vertical
		neg.w	obVelX(a0)
.vertical:
		btst	#1,d5
		beq.s	.cache
		move.w	d2,obVelY(a0)
		btst	#1,obStatus(a0)
		beq.s	.cache
		neg.w	obVelY(a0)
.cache:
		moveq	#0,d3
		move.w	d2,d3
		lsl.l	#8,d3
		bsr.s	Saw_SignedVector
		movem.l	d1-d2,saw_step_x(a0)
		rts

; d3 = unsigned 16.16 distance. Return components along the enabled axes.
Saw_SignedVector:
		moveq	#0,d1
		moveq	#0,d2
		tst.w	obVelX(a0)
		beq.s	.vertical
		bmi.s	.left
		move.l	d3,d1
		bra.s	.vertical
.left:
		move.l	d3,d1
		neg.l	d1
.vertical:
		tst.w	obVelY(a0)
		beq.s	.return
		bmi.s	.up
		move.l	d3,d2
		rts
.up:
		move.l	d3,d2
		neg.l	d2
.return:
		rts

Saw_BoundedAnimate:
		tst.w	saw_handle(a0)
		beq.s	.pair
		move.b	obAnim(a0),d0
		cmp.b	obPrevAni(a0),d0
		beq.s	.pair
		move.b	d0,obPrevAni(a0)
		cmpi.b	#Saw_RailStages-1,d0
		bls.s	.frame
		moveq	#Saw_RailStages-1,d0
.frame:
		add.b	d0,d0
		move.b	d0,obFrame(a0)
		move.b	saw_spin_delay(a0),obTimeFrame(a0)
		bra.s	.sound
.pair:
		move.b	saw_spin_delay(a0),d0
		bsr.s	Saw_AnimatePair
.sound:
		tst.b	obRender(a0)
		bpl.s	Saw_Draw
		addq.w	#1,saw_sound(a0)
		move.w	saw_sound(a0),d0
		andi.w	#31,d0
		bne.s	Saw_Draw

Saw_BuzzDraw:
		; The laser-loop effect is marked non-interruptible by itself.
		move.w	#SndID_LaserBeam,d0
		jsr	(PlaySound_Special).l
Saw_Draw:
		out_of_range2	Saw_Unload,saw_origin_x(a0)
		jmp	(DisplaySprite).l

Saw_Cull:
		out_of_range2	Saw_Unload,saw_origin_x(a0)
		rts

; d0.b: delay minus one (two updates for the rail, three for the other blades).
Saw_AnimatePair:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	.return
		move.b	d0,obTimeFrame(a0)
		bchg	#0,obFrame(a0)
.return:
		rts

; =============== S U B R O U T I N E =======================================

; The rail lives only while its blade still owns this slot.
Saw_Handle:
		movea.w	saw_parent(a0),a1
		tst.l	code(a1)
		beq.s	.delete
		cmpi.l	#Map_MMZ_Saw,obMap(a1)
		bne.s	.delete
		move.w	a0,d0
		cmp.w	saw_handle(a1),d0
		bne.s	.delete
		jmp	(DisplaySprite).l
.delete:
		jmp	(DeleteObject).l

Saw_Unload:
		move.w	saw_handle(a0),d0
		beq.s	.delete
		movea.w	d0,a1
		cmpi.l	#Saw_Handle,code(a1)
		bne.s	.delete
		move.w	a0,d0
		cmp.w	saw_parent(a1),d0
		bne.s	.delete
		jsr	(DeleteObject2).l
.delete:
		jmp	(UnloadObject).l

Map_SMZ_Saw:		binclude "mappings/sprite/SMZ Saw.bin"
		even
Map_MMZ_Saw:		binclude "mappings/sprite/MMZ Saw.bin"
		even
Map_MMZ_SawHandle:	binclude "mappings/sprite/MMZ Saw Handle.bin"
		even
