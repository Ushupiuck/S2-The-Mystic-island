; Ported from sonicretro/s1disasm 2c51d46 (REV01).
; Six-byte mappings, full code pointers, S3&K placement ownership.
; ===========================================================================
; ---------------------------------------------------------------------------
; Object 6A - pizza cutters and speeding saws (SBZ)
; ---------------------------------------------------------------------------

SMZ_Saws:
		move.w	obSubtype(a0),d0
		btst	#8,d0	; bit 8 selects MMZ outside its own zone
		bne.w	MMZ_Saw_Init
		cmpi.b	#id_MMZ,(v_zone).w
		beq.w	MMZ_Saw_Init

SMZ_saw_origY:	equ objoff_38		; original y-axis position
SMZ_saw_origX:	equ objoff_3A		; original x-axis position
SMZ_saw_shot:	equ objoff_3D		; flag set when the speeding saw appears
; ===========================================================================

SMZ_Saw_Main:	; Constructor; the live object skips initialization dispatch.
		move.l	#SMZ_Saw_Action,code(a0)
		addq.b	#2,obRoutine(a0)			; advance to SMZ_Saw_Action
		move.l	#Map_SMZ_Saw,obMap(a0)
		move.b #Map_SMZ_Saw_height,height_pixels(a0)			; set mappings
		move.w #ArtTile_SMZ_Atlas,obGfx(a0)	; set art tile and palette line
		move.b	#4,obRender(a0)		; set to playfield-positioned mode
		move.w #$200,obPriority(a0)			; set sprite priority
		move.b	#64/2,obActWid(a0)			; set sprite display width
		move.w	obX(a0),SMZ_saw_origX(a0)			; remember initial X-position
		move.w	obY(a0),SMZ_saw_origY(a0)			; remember initial Y-position

		cmpi.w	#3,obSubtype(a0)			; is object a pizza cutter? (subtype 0-2)
		bhs.s	SMZ_Saw_Action				; if not, branch (speeding saw, subtype 3-4)
		move.b	#$22|$80,obColType(a0)	; make pizza cutter harmful on touch
; ---------------------------------------------------------------------------

SMZ_Saw_Action:	; Routine 2
		moveq	#0,d0					; clear d0
		move.w	obSubtype(a0),d0			; get saw subtype (0-4)
		andi.w	#7,d0					; limit to sane values
		add.w	d0,d0					; double for word-based indexing
		move.w	SMZ_Saw_Types(pc,d0.w),d1			; find behavior type for current saw
		jsr	SMZ_Saw_Types(pc,d1.w)			; execute behavior, then return here

		out_of_range2	SMZ_Saw_Delete,SMZ_saw_origX(a0)	; has saw gone out of range? if yes, branch
		jmp	(DisplaySprite).l			; display saw sprite
; ---------------------------------------------------------------------------

SMZ_Saw_Delete:
		jmp	(UnloadObject).l			; delete saw

; ===========================================================================
SMZ_Saw_Types:
		dc.w SMZ_Saw_Type0_PizzaStationary-SMZ_Saw_Types	; 0 - pizza cutter (stationary)
		dc.w SMZ_Saw_Type1_PizzaLeftRight-SMZ_Saw_Types		; 1 - pizza cutter (moves left and right)
		dc.w SMZ_Saw_Type2_PizzaUpDown-SMZ_Saw_Types		; 2 - pizza cutter (moves up and down)
		dc.w SMZ_Saw_Type3_SpeedingFromLeft-SMZ_Saw_Types	; 3 - speeding saw (shot from the left)
		dc.w SMZ_Saw_Type4_SpeedingFromRight-SMZ_Saw_Types	; 4 - speeding saw (shot from the right)
; ===========================================================================

SMZ_Saw_Type0_PizzaStationary:
		rts						; doesn't move at all
; ===========================================================================

SMZ_Saw_Type1_PizzaLeftRight:
		move.w	#$60,d1					; adjustment offset for X-flipped saws (oscillation range * 2)
		moveq	#0,d0					; clear d0
		move.b	(v_oscillate+$E).w,d0			; get oscillatory value (frequency 2, middle value $30)
		btst	#0,obStatus(a0)		; is saw X-flipped?
		beq.s	.setX					; if not, branch
		neg.w	d0					; reverse oscillated offset direction
		add.w	d1,d0					; keep flipped saws in the same $60px range
	.setX:
		move.w	SMZ_saw_origX(a0),d1			; get initial X-position of saw
		sub.w	d0,d1					; adjust by oscillated offset
		move.w	d1,obX(a0)				; move saw horizontally

	.animate:
		subq.b	#1,obTimeFrame(a0)			; decrement timer until frame change
		bpl.s	.sound					; if time remains, branch
		move.b	#3-1,obTimeFrame(a0)			; reset time between frame changes
		bchg	#0,obFrame(a0)				; alternate saw frames

	.sound:
		tst.b	obRender(a0)				; is saw on screen?
		bpl.s	.return					; if not, don't play sound
		move.w	(v_framecount).w,d0			; get current level frame counter
		andi.w	#$F,d0					; only play sound every 16 frames
		bne.s	.return					; branch otherwise
		move.w	#sfx_Saw,d0				; play saw buzzing sound
		jsr	(PlaySound_Special).l				; (this sound is programmed to not be interruptible by itself)

	.return:
		rts						; return
; ===========================================================================

SMZ_Saw_Type2_PizzaUpDown:
		move.w	#$30,d1					; (unused, probably a leftover from copying subtype 1)
		moveq	#0,d0					; clear d0
		move.b	(v_oscillate+6).w,d0			; get oscillatory value (frequency 2, middle value $18)
		btst	#0,obStatus(a0)		; is saw X-flipped?
		beq.s	.setY					; if not, branch
		neg.w	d0					; reverse oscillated offset direction
		addi.w	#$60+$20,d0				; keep flipped saws in the same $60px range... plus an extra $20px
	.setY:
		move.w	SMZ_saw_origY(a0),d1			; get initial Y-position of saw
		sub.w	d0,d1					; adjust by oscillated offset
		move.w	d1,obY(a0)				; move saw vertically

	.animate:
		subq.b	#1,obTimeFrame(a0)			; decrement timer until frame change
		bpl.s	.sound					; if time remains, branch
		move.b	#3-1,obTimeFrame(a0)			; reset time between frame changes
		bchg	#0,obFrame(a0)				; alternate saw frames

	.sound:
		tst.b	obRender(a0)				; is saw on screen?
		bpl.s	.return					; if not, don't play sound
		move.b	(v_oscillate+6).w,d0			; get current oscillation value for saw type
		cmpi.b	#$18,d0					; is oscillation value at middle?
		bne.s	.return					; if not, branch
		move.w	#sfx_Saw,d0				; play saw buzzing sound
		jsr	(PlaySound_Special).l				; (this sound is programmed to not be interruptible by itself)

	.return:
		rts						; return
; ===========================================================================

SMZ_Saw_Type3_SpeedingFromLeft:
		tst.b	SMZ_saw_shot(a0)				; has speeding saw already been shot?
		bne.s	SMZ_Saw_Type3_SpeedingFromLeft_Shot		; if yes, branch

		move.w	(v_player+obX).w,d0			; get Sonic's current X-position
		subi.w	#192,d0					; spawn saw if Sonic is 192px to the right of it
		bcs.s	.hide					; if Sonic is close to left level edge, branch
		sub.w	obX(a0),d0				; subtract saw's X-position
		bcs.s	.hide					; if Sonic isn't in horizontal range, branch
		move.w	(v_player+obY).w,d0			; get Sonic's current Y-position
		subi.w	#128,d0					; check 128px above
		cmp.w	obY(a0),d0				; is Sonic within upper trigger zone?
		bhs.s	.return					; if not, branch
		addi.w	#128*2,d0				; check 128px below
		cmp.w	obY(a0),d0				; is Sonic within lower trigger zone?
		blo.s	.return					; if not, branch

		move.b	#1,SMZ_saw_shot(a0)				; set flag to shoot speeding saw
		move.w	#$600,obVelX(a0)			; move speeding saw to the right (fast)
		move.b	#$22|$80,obColType(a0)	; make saw harmful on touch
		move.b	#2,obFrame(a0)				; use speeding saw frames
		move.w	#sfx_Saw,d0				; set saw buzzing sound
		jsr	(PlaySound_Special).l				; play it

	.hide:
		addq.l	#4,sp					; skip returning to SMZ_Saw_Action to avoid rendering sprite
		; The above line will properly avoid drawing the sprite, but it will
		; also prevent despawning the object, which can lead to memory leaks.
		out_of_range2	SMZ_Saw_Delete,SMZ_saw_origX(a0)	; has saw gone out of range? if yes, delete it

	.return:
		rts						; return
; ---------------------------------------------------------------------------

SMZ_Saw_Type3_SpeedingFromLeft_Shot:
		jsr	(SpeedToPos).l				; update speeding saw's position
		move.w	obX(a0),SMZ_saw_origX(a0)			; update original X-position for offscreen check

		subq.b	#1,obTimeFrame(a0)			; decrement timer until frame change
		bpl.s	.return					; if time remains, branch
		move.b	#3-1,obTimeFrame(a0)			; reset time between frame changes
		bchg	#0,obFrame(a0)				; alternate saw frames

	.return:
		rts						; return
; ===========================================================================

SMZ_Saw_Type4_SpeedingFromRight:
		tst.b	SMZ_saw_shot(a0)				; has speeding saw already been shot?
		bne.s	SMZ_Saw_Type4_SpeedingFromRight_Shot	; if yes, branch

		move.w	(v_player+obX).w,d0			; get Sonic's current X-position
		addi.w	#224,d0					; spawn saw if Sonic is 224px to the left of it
		sub.w	obX(a0),d0				; subtract saw's X-position
		bcc.s	.hide					; if Sonic isn't in horizontal range, branch
		move.w	(v_player+obY).w,d0			; get Sonic's current Y-position
		subi.w	#128,d0					; check 128px above
		cmp.w	obY(a0),d0				; is Sonic within upper trigger zone?
		bhs.s	.return					; if not, branch
		addi.w	#128*2,d0				; check 128px below
		cmp.w	obY(a0),d0				; is Sonic within lower trigger zone?
		blo.s	.return					; if not, branch

		move.b	#1,SMZ_saw_shot(a0)				; set flag to shoot speeding saw
		move.w	#-$600,obVelX(a0)			; move speeding saw to the left (fast)
		move.b	#$22|$80,obColType(a0)	; make saw harmful on touch
		move.b	#2,obFrame(a0)				; use speeding saw frames
		move.w	#sfx_Saw,d0				; set saw buzzing sound
		jsr	(PlaySound_Special).l				; play it

	.hide:
		addq.l	#4,sp					; skip returning to SMZ_Saw_Action to avoid rendering sprite
		; See above.
		out_of_range2	SMZ_Saw_Delete,SMZ_saw_origX(a0)	; has saw gone out of range? if yes, delete it

	.return:
		rts						; return
; ---------------------------------------------------------------------------

SMZ_Saw_Type4_SpeedingFromRight_Shot:
		jsr	(SpeedToPos).l				; update speeding saw's position
		move.w	obX(a0),SMZ_saw_origX(a0)			; update original X-position for offscreen check

		subq.b	#1,obTimeFrame(a0)			; decrement timer until frame change
		bpl.s	.return					; if time remains, branch
		move.b	#3-1,obTimeFrame(a0)			; reset time between frame changes
		bchg	#0,obFrame(a0)				; alternate saw frames

	.return:
		rts						; return

; ===========================================================================

Map_SMZ_Saw: binclude "mappings/sprite/SMZ Saw.bin"

; ---------------------------------------------------------------------------
; MMZ diagonal buzzsaw. One placement ID, direction from X/Y flip, bit 7 of
; the low subtype byte selects the initially extended phase. Direct state
; entries replace CD's parent/child and five-routine dispatch tables.
MMZ_saw_timer:		equ objoff_2E
MMZ_saw_xstep:		equ objoff_30 ; signed 16.16
MMZ_saw_ystep:		equ objoff_34 ; signed 16.16
MMZ_saw_steps:		equ objoff_38
MMZ_saw_home:		equ objoff_3A
MMZ_saw_handle:		equ objoff_3C ; reciprocal word pointer
MMZ_saw_parent:		equ objoff_3E ; handle's parent pointer
MMZ_saw_sound:		equ objoff_40 ; visible-update counter

MMZ_Saw_Init:
		jsr	(FindFreeObj).l
		bne.w	.return	; retry the intact placement without leaking a handle
		move.w	a1,MMZ_saw_handle(a0)
		move.w	a0,MMZ_saw_parent(a1)
		move.l	#MMZ_Saw_Handle,code(a1)
		move.l	#Map_MMZ_SawHandle,obMap(a1)
		move.b	#Map_MMZ_SawHandle_width,width_pixels(a1)
		move.b	#Map_MMZ_SawHandle_height,height_pixels(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obStatus(a0),obRender(a1)
		ori.b	#4,obRender(a1)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.l	#Map_MMZ_Saw,obMap(a0)
		move.b	#Map_MMZ_Saw_width,width_pixels(a0)
		move.b	#Map_MMZ_Saw_height,height_pixels(a0)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		move.w	#$180,obPriority(a0)
		move.b	obStatus(a0),obRender(a0)
		ori.b	#4,obRender(a0)
		move.b	#$80|Touch_Size_MMZSaw_ID,obColType(a0)
		move.w	obX(a0),MMZ_saw_home(a0)
		move.l	#$10000,MMZ_saw_xstep(a0)
		move.l	#$10000,MMZ_saw_ystep(a0)
		moveq	#80,d0
		moveq	#80,d1
		btst	#0,obStatus(a0)
		beq.s	.y_direction
		neg.l	MMZ_saw_xstep(a0)
		neg.w	d0
.y_direction:
		btst	#1,obStatus(a0)
		beq.s	.phase
		neg.l	MMZ_saw_ystep(a0)
		neg.w	d1
.phase:
		move.l	#MMZ_Saw_HoldIn,code(a0)
		move.w	obSubtype(a0),d2
		btst	#7,d2
		beq.s	.start
		move.l	#MMZ_Saw_HoldOut,code(a0)
		move.b	#9,obAnim(a0)
		sub.w	d0,obX(a1)
		sub.w	d1,obY(a1)
.start:
		move.b	#-1,obPrevAni(a0)
		move.w	#59,MMZ_saw_timer(a0)
		; CD's constructor executes the outward movement once, including
		; this one-pixel birth offset, before entering its selected hold.
		bra.s	MMZ_Saw_MoveOut
.return:
		rts

MMZ_Saw_HoldIn:
		subq.w	#1,MMZ_saw_timer(a0)
		bne.w	MMZ_Saw_Finish
		move.l	#MMZ_Saw_Extend,code(a0)
		move.w	#9,MMZ_saw_steps(a0)
		move.w	#1,MMZ_saw_timer(a0)
		bra.w	MMZ_Saw_Finish

MMZ_Saw_Extend:
		subq.w	#1,MMZ_saw_timer(a0)
		bne.s	MMZ_Saw_MoveOut
		addq.b	#1,obAnim(a0)
		move.w	#9,MMZ_saw_timer(a0)
		subq.w	#1,MMZ_saw_steps(a0)
		bne.s	MMZ_Saw_MoveOut
		move.l	#MMZ_Saw_HoldOut,code(a0)
		move.w	#60,MMZ_saw_timer(a0)
MMZ_Saw_MoveOut:
		move.l	MMZ_saw_xstep(a0),d0
		add.l	d0,obX(a0)
		move.l	MMZ_saw_ystep(a0),d0
		add.l	d0,obY(a0)
		bra.s	MMZ_Saw_Finish

MMZ_Saw_HoldOut:
		subq.w	#1,MMZ_saw_timer(a0)
		bne.s	MMZ_Saw_Finish
		move.l	#MMZ_Saw_Retract,code(a0)
		move.w	#9,MMZ_saw_steps(a0)
		move.w	#1,MMZ_saw_timer(a0)
		bra.s	MMZ_Saw_Finish

MMZ_Saw_Retract:
		subq.w	#1,MMZ_saw_timer(a0)
		bne.s	.move
		subq.b	#1,obAnim(a0)
		move.w	#9,MMZ_saw_timer(a0)
		subq.w	#1,MMZ_saw_steps(a0)
		bne.s	.move
		move.l	#MMZ_Saw_HoldIn,code(a0)
		move.w	#60,MMZ_saw_timer(a0)
.move:
		move.l	MMZ_saw_xstep(a0),d0
		sub.l	d0,obX(a0)
		move.l	MMZ_saw_ystep(a0),d0
		sub.l	d0,obY(a0)

MMZ_Saw_Finish:
		; Each extension stage has exactly two poses, two updates apiece.
		; Anim 9 is the original alias of 8. No animation interpreter needed.
		move.b	obAnim(a0),d0
		cmp.b	obPrevAni(a0),d0
		beq.s	.animate
		move.b	d0,obPrevAni(a0)
		cmpi.b	#8,d0
		bls.s	.pair
		moveq	#8,d0
.pair:
		add.b	d0,d0
		move.b	d0,obFrame(a0)
		move.b	#1,obTimeFrame(a0)
		bra.s	.sound
.animate:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	.sound
		move.b	#1,obTimeFrame(a0)
		bchg	#0,obFrame(a0)
.sound:
		tst.b	obRender(a0)
		bpl.s	.display
		addq.w	#1,MMZ_saw_sound(a0)
		move.w	MMZ_saw_sound(a0),d0
		andi.w	#31,d0
		bne.s	.display
		move.w	#sfx_Saw,d0
		jsr	(PlaySound_Special).l
.display:
		out_of_range2	MMZ_Saw_Unload,MMZ_saw_home(a0)
		jmp	(DisplaySprite).l

MMZ_Saw_Handle:
		movea.w	MMZ_saw_parent(a0),a1
		tst.l	code(a1)
		beq.s	.delete
		cmpi.l	#Map_MMZ_Saw,obMap(a1)
		bne.s	.delete
		move.w	a0,d0
		cmp.w	MMZ_saw_handle(a1),d0
		bne.s	.delete
		jmp	(DisplaySprite).l
.delete:
		jmp	(DeleteObject).l

MMZ_Saw_Unload:
		movea.w	MMZ_saw_handle(a0),a1
		cmpi.l	#MMZ_Saw_Handle,code(a1)
		bne.s	.delete
		move.w	a0,d0
		cmp.w	MMZ_saw_parent(a1),d0
		bne.s	.delete
		jsr	(DeleteObject2).l
.delete:
		jmp	(UnloadObject).l

Map_MMZ_Saw:		binclude "mappings/sprite/MMZ Saw.bin"
		even
Map_MMZ_SawHandle:	binclude "mappings/sprite/MMZ Saw Handle.bin"
		even
