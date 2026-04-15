; ---------------------------------------------------------------------------
; Object 4F - Splats (Marble Zone badnik)
; ---------------------------------------------------------------------------

Splats:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Splats_Index(pc,d0.w),d1
		jmp	Splats_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Splats_Index:
		dc.w Splats_Init-Splats_Index		; 0 - object init
		dc.w Splats_Wait-Splats_Index		; 2 - wait for Sonic to enter a certain trigger zone (bounce in place until then)
		dc.w Splats_Bounce-Splats_Index		; 4 - trigger zone entered, apply movement and check for floor to bounce
	;	dc.w Splats_Fallthrough-Splats_Index	; 6 - special case after hitting lava: phase through floor and despawn on screen exit
; ---------------------------------------------------------------------------

Splats_Init:
		addq.b	#2,obRoutine(a0)		; set to WaitForSonic
		move.l	#Map_Splats,obMap(a0)		; set maps
		move.w	#make_art_tile(ArtTile_Splats,1,0),obGfx(a0) ; set art tile
		ori.b	#4,obRender(a0)			; set render flags
		move.w	#$200,obPriority(a0)		; set sprite priority
		move.b	#$C,obActWid(a0)		; set width
		move.b	#$14,obHeight(a0)		; set height
		move.b	#2,obColType(a0)		; set coltype to badnik
	;	tst.b	obSubtype(a0)			; is subtype anything but zero?
	;	beq.s	Splats_Wait			; if not, branch
		move.w	#$300,d2			; set trigger zone to start moving to be significantly larger
	;	bra.s	Splats_Wait.triggerzoneset	; skip
; ---------------------------------------------------------------------------

Splats_Wait:
	;	move.w	#$E0,d2				; set default (small) trigger zone

.triggerzoneset:
		move.w	#$100,d1			; prepare X velocity to be $100
		bset	#0,obRender(a0)			; make object face to the right
		move.w	(v_player+obX).w,d0		; get Sonic's X position
		sub.w	obX(a0),d0			; subtract object's X position
		bcc.s	.chktriggerzonehit		; if object is to the right of Sonic, branch
		neg.w	d0				; negate distance
		neg.w	d1				; negate prepared X velocity
		bclr	#0,obRender(a0)			; make object face to the left

.chktriggerzonehit:
		cmp.w	d2,d0				; is Sonic within the trigger zone?
		bcc.s	Splats_Bounce			; if not, bounce in place
		move.w	d1,obVelX(a0)			; begin moving horizontally
		addq.b	#2,obRoutine(a0)		; set to Splats_Bounce

Splats_Bounce:
	;	jsr	(ObjectMoveAndFall).l		; apply gravity
		movem.w	obVelX(a0),d0/d2		; load xy speed
		lsl.l	#8,d0				; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2				; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)			; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)			; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)			; increase vertical speed (apply gravity)
		move.b	#1,obFrame(a0)			; set frame to 1 (bouncy, flappy ears)
		tst.w	obVelY(a0)			; is object moving upwards?
		bmi.s	.chkwall			; if yes, branch
		clr.b	obFrame(a0)			; set frame to 0 (standard, long ears)
		bsr.w	ObjHitFloor			; get object distance to floor
		tst.w	d1				; is object above floor?
		bpl.s	.chkwall			; if yes, branch
		; The following codeis for the Special interaction in Marble zone
	;	move.w	(a1),d0				; get floor block object is standing on
	;	andi.w	#$3FF,d0			; ignore solid/orientation bits (i.e. only look at the actual block ID)
	;	cmpi.w	#$2D2,d0			; is the touched block ID a lava tile? (technically, this should be $2FB, but most of the tiles before are blank/background)
	;	bcs.s	.bounce				; if not, branch
	;	addq.b	#2,obRoutine(a0)		; set to Splats_Fallthrough (makes object fall into lava upon contact)
	;	bra.s	.chkwall			; skip
; ---------------------------------------------------------------------------

;.bounce:
		add.w	d1,obY(a0)			; fix to floor (add floor difference to Y pos)
		move.w	#-$400,obVelY(a0)		; bounce up

.chkwall:
		bsr.w	Obj_ChkWall			; check if object hit a wall to the left or right
		bpl.s	.display			; if not, branch
		neg.w	obVelX(a0)			; invert X movement direction
		bchg	#0,obRender(a0)			; invert sprite flip (render flags)
		bchg	#0,obStatus(a0)			; invert sprite flip (status flags)

.display:
		jmp	(MarkObjGone).l			; display
; ---------------------------------------------------------------------------

;Splats_Fallthrough:
	;	bsr.w	ObjectMoveAndFall		; apply gravity
	;	tst.b	obRender(a0)			; is object still on screen?
	;	bpl.w	DeleteObject			; if not, delete
	;	bra.w	DisplaySprite			; display
; ---------------------------------------------------------------------------
Obj_ChkWall:	; this routine is shared with Yadrin
		move.w	(v_framecount).w,d0	; get frame counter
		add.w	d7,d0			; add object object enumerator from RAM
		andi.w	#3,d0			; and by 3 (effectively makes it so it's only checked every 4 frames, presumably for performance reasons)
		bne.s	.nowallhit		; if outside a 4th frame, branch
		moveq	#0,d3
		move.b	obActWid(a0),d3		; load object width to d3 (input param for wall col detection subroutines)
		tst.w	obVelX(a0)		; is object moving to the left?
		bmi.s	.checkleftwall		; if so, branch
		bsr.w	ObjHitWallRight		; get distance to nearest right wall
		tst.w	d1			; did object hit wall?
		smi	d0			; d0=$FF if hit, 0 if not
		rts
; ===========================================================================
.checkleftwall:
		not.w	d3			; invert object width to make it work for left wall col
		bsr.w	ObjHitWallLeft		; get distance to nearest left wall
		tst.w	d1			; did object hit wall?
		smi	d0			; d0=$FF if hit, 0 if not
		rts

.nowallhit:
		moveq	#0,d0			; clear Z-flag (wall not touched)
		rts
; End of function Obj_ChkWall