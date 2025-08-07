; ---------------------------------------------------------------------------
; Object 2B - Chopper enemy (GHZ)
; ---------------------------------------------------------------------------

Obj2B:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Chop_Index(pc,d0.w),d1
		jsr	Chop_Index(pc,d1.w)
		bra.w	MarkObjGone
; ===========================================================================
Chop_Index:	dc.w Chop_Main-Chop_Index
		dc.w Chop_ChgSpeed-Chop_Index
chop_origY = obYSub	; word - ground level
chop_velY = obVelX	; long - fixed vertical speed
chop_grav = objoff_2A	; long - self explanatory
chop_posY = objoff_2E	; long - current y position
; ===========================================================================

Chop_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.b	#4,obRender(a0)
		move.b	#4,obPriority(a0)
		move.b	#9,obColType(a0)
		move.b	#$10,obActWid(a0)
		move.l	#Map_Obj2B,obMap(a0)
		move.w	#make_art_tile(ArtTile_Chopper,0,0),obGfx(a0)
		tst.b	(Current_Zone).w
		beq.s	.notEHZ
		move.l	#Map_obj2B_1,obMap(a0)
		move.w	#make_art_tile(ArtTile_Masher,0,0),obGfx(a0)
.notEHZ:
		move.w	obY(a0),d0
		move.w	d0,chop_origY(a0)     ; Save ground level
		lsl.l	#8,d0                 ; Convert to fixed point
		move.l	d0,chop_posY(a0)      ; Set true position

		move.b	obSubtype(a0),d1	; get subtype (for vertical speed)
		lsl.w	#1,d1			; filter out which entry it is
		move.w	Chopper_JumpHeights(pc,d1.w),d0		; and store the vertical speed
		ext.l	d0
		move.l	d0,chop_velY(a0)
		move.l	#$0018,chop_grav(a0)
		rts

; ===========================================================================
Chopper_JumpHeights:
		dc.w	-$400, -$480	; 1, 2
		dc.w	-$500, -$580	; 3, 4
		dc.w	-$600, -$680	; 5, 6
		dc.w	-$700, -$780	; 7, 8
; ===========================================================================

Chop_ChgSpeed:	; Routine 2
		lea	(Ani_Obj2B).l,a1
		bsr.w	AnimateSprite
		; Update subpixel position
		move.l	chop_velY(a0),d0
		add.l	d0,chop_posY(a0)
		; Convert to visible pixel position
		move.l	chop_posY(a0),d0
		lsr.l	#8,d0
		move.w	d0,obY(a0)
		; Gravity effect
		move.l	chop_grav(a0),d1
		add.l	d1,chop_velY(a0)
		move.b	#1,obAnim(a0)	; we default to the fast animation
		move.w	chop_origY(a0),d2
		subi.w	#$C0,d2
		cmp.w	obY(a0),d2
		bcc.s	.CheckApex
		move.b	#0,obAnim(a0)	; use slow animation
		tst.l	chop_velY(a0)	; is Chopper at	its highest point?
		bmi.s	.CheckApex	; if not, branch
		move.b	#2,obAnim(a0)	; use stationary animation

.CheckApex:
		; If past ground level, reset position and jump
		move.w	obY(a0),d0
		cmp.w	chop_origY(a0),d0
		ble.s	.done
		; Clamp position
		move.w	chop_origY(a0),obY(a0)
		lsl.l	#8,d0
		move.l	d0,chop_posY(a0)
		; Reset jump velocity
		move.b	obSubtype(a0),d1
		lsl.w	#1,d1
		move.w	Chopper_JumpHeights(pc,d1.w),d0
		ext.l	d0
		move.l	d0,chop_velY(a0)

.done:
		rts