; ---------------------------------------------------------------------------
; D9 - hanging surface (MD main CPU).
; S3&K LBZ fixed grip / FBZ hand-over-hand traversal, with SOZ floor release.
; Low 6 bits: span in 32px units (0 = classic 56px / traversable 32px).
; Bit 6: drop at the final grip (X flip selects the left end).
; Bit 7: traversable. Bit 8: disable support release. Bit 9: silent.
; Bit 10: hide the traversable handholds (use terrain / parent art instead).
; Other bits reserved. The complete authored subtype word is preserved.
;
; Standalone origin follows the original controllers: classic centre Y+36,
; traversable centre Y+18. Classic grips remain invisible; no solidity.
; Traversable art: load Nem_HangingSurface at ArtTile_HangingSurface in the act.
; Parent-driven children update once from their owner, regardless of slot order.
; ---------------------------------------------------------------------------
Hang_parent:		equ objoff_2E	; word: owner SST, 0 for standalone
Hang_halfwidth:		equ objoff_30	; word: physical span / 2
Hang_yoffset:		equ objoff_32	; signed word: origin relative to parent Y
Hang_oldX:		equ objoff_34	; word: last processed origin
Hang_oldY:		equ objoff_36	; word
Hang_parentcode:	equ objoff_38	; long: expected live owner controller
Hang_parentlink:	equ objoff_3C	; word: address of owner's child-pointer word
Hang_display:		equ obVelX	; word: unused velocity holds one display helper
Hang_snapX:		equ obVelY	; byte: parent requests a centred classic grab (pull chain)
Hang_p1:		equ objoff_3E	; eight bytes per player, ends at object_size
Hang_p2:		equ objoff_46
Hang_active:		equ 0
Hang_cooldown:		equ 1
Hang_steps:		equ 2
Hang_timer:		equ 3
Hang_direction:		equ 4		; 0 right, 1 left
Hang_phase:		equ 5		; 0/4: alternate hand
Hang_frame:		equ 6		; requested pose, 0-6
Hang_NoSupportBit:	equ 8
Hang_SilentBit:		equ 9
Hang_HideArtBit:	equ 10

HangingSurface:
		tst.b	obRoutine(a0)
		bne.s	.ready
		move.b	#2,obRoutine(a0)
		move.w	obSubtype(a0),d0
		move.w	d0,d3
		andi.w	#$3F,d0
		lsl.w	#4,d0
		bne.s	.width
		moveq	#28,d0
		btst	#7,d3
		beq.s	.width
		moveq	#16,d0
.width:
		move.w	d0,Hang_halfwidth(a0)
		move.w	obX(a0),Hang_oldX(a0)
		move.w	obY(a0),Hang_oldY(a0)
.ready:
		move.w	obX(a0),d0
		sub.w	Hang_halfwidth(a0),d0
		andi.w	#$FF80,d0
		sub.w	(Camera_X_pos_coarse_back).w,d0
		cmpi.w	#$280,d0
		bls.s	.update
		move.w	obX(a0),d0
		add.w	Hang_halfwidth(a0),d0
		andi.w	#$FF80,d0
		sub.w	(Camera_X_pos_coarse_back).w,d0
		cmpi.w	#$280,d0
		bls.s	.update
		; Also retain an array which completely surrounds the camera window.
		move.w	(Camera_X_pos).w,d0
		sub.w	obX(a0),d0
		bpl.s	.distance
		neg.w	d0
.distance:
		cmp.w	Hang_halfwidth(a0),d0
		bls.s	.update
		bsr.w	Hanging_ReleaseAll
		jmp	(UnloadObject).l
.update:
		bra.w	Hanging_Update

; a0 owner, a2 address of its child-pointer word; d0 settings, d1 half-width,
; d2 signed origin Y offset. Carry set = full pool, owner should retry.
; The owner is the only placement owner; the child's respawn handle is zero.
Hanging_SpawnChild:
		movem.l	d0-d2/a2,-(sp)
		jsr	(FindFreeObj).l
		movem.l	(sp)+,d0-d2/a2
		bne.s	.full
		move.l	#Hanging_Child,code(a1)
		move.b	#2,obRoutine(a1)
		move.w	d0,obSubtype(a1)
		move.w	d1,Hang_halfwidth(a1)
		move.w	d2,Hang_yoffset(a1)
		move.w	a0,Hang_parent(a1)
		move.l	code(a0),Hang_parentcode(a1)
		move.w	a2,Hang_parentlink(a1)
		move.w	a1,(a2)
		move.w	obX(a0),obX(a1)
		move.w	obX(a0),Hang_oldX(a1)
		add.w	obY(a0),d2
		move.w	d2,obY(a1)
		move.w	d2,Hang_oldY(a1)
		move.b	obStatus(a0),obStatus(a1)
		andi.b	#1,obStatus(a1)
		andi.b	#$FE,ccr
		rts
.full:
		ori.b	#1,ccr
		rts

; The child executor only checks ownership. The parent calls Hanging_Update
; after moving/doing solidity, so earlier free slots cannot introduce lag.
Hanging_Child:
		bsr.s	Hanging_ValidateParent
		bne.s	Hanging_DeleteChild
		rts
Hanging_ValidateParent:
		movea.w	Hang_parent(a0),a1
		move.l	code(a1),d0
		cmp.l	Hang_parentcode(a0),d0
		bne.s	.return
		movea.w	Hang_parentlink(a0),a1
		move.w	a0,d0
		cmp.w	(a1),d0
.return:
		rts
Hanging_DeleteChild:
		bsr.w	Hanging_ReleaseAll
		jmp	(DeleteObject).l

Hanging_Update:
		move.w	obX(a0),d4
		sub.w	Hang_oldX(a0),d4
		move.w	obX(a0),Hang_oldX(a0)
		move.w	obY(a0),Hang_oldY(a0)
		lea	Hang_p1(a0),a2
		lea	(v_player).w,a1
		move.w	(v_jpadholdlogical).w,d0
		movem.l	d4/a0-a2,-(sp)
		bsr.s	Hanging_Player
		movem.l	(sp)+,d4/a0-a2
		lea	Hang_p2(a0),a2
		lea	(v_player2).w,a1
		move.w	(v_jpadholdlogical2).w,d0
		pea	Hanging_Display(pc)	; player 2 returns straight into the display pass

Hanging_Player:
		move.w	obSubtype(a0),d5
		tst.b	Hang_active(a2)
		beq.w	Hanging_TryGrab
		cmpi.b	#3,obControl(a1)
		bne.w	Hanging_LostControl
		move.w	d0,-(sp)
		bsr.w	Hanging_OwnedByThis
		movem.w	(sp)+,d0
		bne.w	Hanging_LostControl
		tst.w	(Debug_placement_mode).w
		bne.w	Hanging_Drop
		tst.b	obRender(a1)
		bpl.w	Hanging_Drop
		cmpi.b	#4,obRoutine(a1)
		bhs.w	Hanging_Drop
		add.w	d4,obX(a1)
		moveq	#36,d1
		btst	#7,d5
		beq.s	.pin
		moveq	#18,d1
.pin:
		add.w	obY(a0),d1
		move.w	d1,obY(a1)
		move.w	d0,-(sp)
		bsr.w	Hanging_TerrainContact
		move.w	(sp)+,d0
		tst.b	Hang_active(a2)
		beq.s	.return
		move.w	d0,d1
		andi.b	#btnABC,d1
		bne.w	Hanging_Jump
		btst	#7,d5
		bne.w	Hanging_Traverse
		bsr.w	Hanging_Facing
		move.b	#6,Hang_frame(a2)
		bra.w	Hanging_DrawPlayer
.return:
		rts

Hanging_TryGrab:
		tst.b	Hang_cooldown(a2)
		beq.s	.test
		subq.b	#1,Hang_cooldown(a2)
		bne.w	.return
.test:
		tst.w	(Debug_placement_mode).w
		bne.w	.return
		tst.b	obControl(a1)
		bne.w	.return
		cmpi.b	#2,obRoutine(a1)
		bne.w	.return
		tst.b	obRender(a1)
		bpl.w	.return
		btst	#status.player.in_air,obStatus(a1)
		beq.w	.return		; never steal a character standing above the grip
		move.w	obX(a1),d1
		sub.w	obX(a0),d1
		add.w	Hang_halfwidth(a0),d1
		bmi.w	.return
		move.w	Hang_halfwidth(a0),d2
		add.w	d2,d2
		cmp.w	d2,d1
		bhs.w	.return
		move.w	obY(a1),d2
		sub.w	obY(a0),d2
		btst	#7,d5
		bne.s	.y_test
		subi.w	#24,d2
.y_test:
		cmpi.w	#24,d2
		bhs.w	.return
		btst	#7,d5
		beq.s	.grab
		andi.w	#$FFE0,d1
		btst	#6,d5
		beq.s	.snap
		btst	#0,obStatus(a0)
		beq.s	.last_right
		tst.w	d1
		beq.w	.return		; the release end is not an initial grab point
		bra.s	.snap
.last_right:
		move.w	Hang_halfwidth(a0),d2
		add.w	d2,d2
		subi.w	#32,d2
		cmp.w	d2,d1
		beq.w	.return
.snap:
		addi.w	#16,d1
		sub.w	Hang_halfwidth(a0),d1
		add.w	obX(a0),d1
		move.w	d1,obX(a1)
.grab:
		tst.b	Hang_snapX(a0)
		beq.s	.keepX
		move.w	obX(a0),obX(a1)
.keepX:
		clr.w	obVelX(a1)
		clr.w	obVelY(a1)
		clr.w	obInertia(a1)
		clr.b	jumping(a1)
		clr.b	spindash_flag(a1)
		clr.b	tails_flight_flag(a1)
		clr.b	obAngle(a1)
		clr.b	flip_angle(a1)
		move.b	default_y_radius(a1),obHeight(a1)
		move.b	default_x_radius(a1),obWidth(a1)
		andi.b	#$C1,obStatus(a1)
		bset	#status.player.in_air,obStatus(a1)
		move.w	a0,d1
		subi.w	#v_objspace,d1
		andi.l	#$FFFF,d1
		divu.w	#object_size,d1
		move.b	d1,standonobject(a1)
		move.b	#3,obControl(a1)
		move.b	#AniIDSonAni_Hang2,obAnim(a1)
		clr.l	(a2)
		clr.l	4(a2)
		move.b	#1,Hang_active(a2)
		move.b	#6,Hang_frame(a2)
		cmpi.l	#Obj02,code(a1)
		beq.s	.tails
		move.b	#$FF,(Sonic_LastLoadedDPLC).w
		bra.s	.position
.tails:
		move.b	#$FF,(Tails_LastLoadedDPLC).w
.position:
		moveq	#36,d1
		btst	#7,d5
		beq.s	.pin
		moveq	#18,d1
.pin:
		add.w	obY(a0),d1
		move.w	d1,obY(a1)
		bsr.w	Hanging_Sound
		bra.w	Hanging_DrawPlayer
.return:
		rts

Hanging_Facing:
		btst	#button_left+8,d0
		beq.s	.right
		bset	#0,obStatus(a1)
.right:
		btst	#button_right+8,d0
		beq.s	.render
		bclr	#0,obStatus(a1)
.render:
		move.b	obStatus(a1),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a1)
		or.b	d1,obRender(a1)
		rts

Hanging_Traverse:
		bsr.s	Hanging_Facing
		tst.b	Hang_steps(a2)
		bne.s	.step
		move.w	obX(a1),d1
		sub.w	obX(a0),d1
		add.w	Hang_halfwidth(a0),d1
		subi.w	#16,d1
		btst	#button_left+8,d0
		beq.s	.right
		cmpi.w	#32,d1
		blo.w	.idle
		move.b	#1,Hang_direction(a2)
		bra.s	.start
.right:
		btst	#button_right+8,d0
		beq.w	.idle
		move.w	Hang_halfwidth(a0),d2
		add.w	d2,d2
		subi.w	#64,d2
		cmp.w	d2,d1
		bgt.w	.idle
		clr.b	Hang_direction(a2)
.start:
		move.b	#4,Hang_steps(a2)
		clr.b	Hang_timer(a2)
.step:
		subq.b	#1,Hang_timer(a2)
		bpl.w	Hanging_DrawPlayer
		move.b	#7,Hang_timer(a2)
		moveq	#0,d1
		move.b	Hang_steps(a2),d1
		cmpi.b	#2,d1
		bne.s	.pose
		bsr.w	Hanging_Sound
.pose:
		subq.w	#1,d1
		add.b	Hang_phase(a2),d1
		move.b	Hanging_Poses(pc,d1.w),Hang_frame(a2)
		move.b	Hanging_Steps(pc,d1.w),d2
		ext.w	d2
		tst.b	Hang_direction(a2)
		beq.s	.move
		neg.w	d2
.move:
		add.w	d2,obX(a1)
		subq.b	#1,Hang_steps(a2)
		bne.w	Hanging_DrawPlayer
		bchg	#2,Hang_phase(a2)
		btst	#6,d5
		beq.w	Hanging_DrawPlayer
		move.w	obX(a1),d1
		sub.w	obX(a0),d1
		btst	#0,obStatus(a0)
		beq.s	.end
		neg.w	d1
.end:
		addi.w	#16,d1
		cmp.w	Hang_halfwidth(a0),d1
		bge.w	Hanging_Drop
		bra.w	Hanging_DrawPlayer
.idle:
		move.b	#6,Hang_frame(a2)
		bra.w	Hanging_DrawPlayer

; FBZ's two alternating 32px steps, preserving its four-pose/8-update cadence.
Hanging_Poses:	dc.b 6,1,0,5,6,4,3,2
Hanging_Steps:	dc.b 4,12,10,6,4,12,12,4

Hanging_Jump:
		move.w	d0,-(sp)
		bsr.w	Hanging_ClearPlayer
		move.w	(sp)+,d0
		move.b	#18,Hang_cooldown(a2)
		move.w	d0,d1
		andi.w	#$F00,d1
		beq.s	.velocity
		move.b	#60,Hang_cooldown(a2)
.velocity:
		btst	#button_left+8,d0
		beq.s	.right
		move.w	#-$200,obVelX(a1)
.right:
		btst	#button_right+8,d0
		beq.s	.up
		move.w	#$200,obVelX(a1)
.up:
		move.w	#-$380,obVelY(a1)
		bset	#status.player.in_air,obStatus(a1)
		bset	#status.player.rolling,obStatus(a1)
		bclr	#status.player.rolljumping,obStatus(a1)
		move.b	#1,jumping(a1)
		move.b	#14,obHeight(a1)
		move.b	#7,obWidth(a1)
		move.b	#AniIDSonAni_Roll,obAnim(a1)
		moveq	#$3D,d0		; this project's Sonic rolling frame
		cmpi.l	#Obj02,code(a1)
		bne.s	.art
		move.w	#$96,d0		; S3&K Tails rolling frame
.art:
		move.b	d0,obFrame(a1)
		bra.w	Hanging_NormalArt

Hanging_LostControl:
		clr.b	Hang_active(a2)	; another controller owns the character now
		clr.b	Hang_steps(a2)
		move.b	#60,Hang_cooldown(a2)
		cmpi.l	#Map_HangingSonic,obMap(a1)
		bne.s	.return
		move.l	#Map_Sonic,obMap(a1)
		move.b	#$FF,(Sonic_LastLoadedDPLC).w
		cmpi.b	#4,obRoutine(a1)
		bhs.w	Hanging_NormalArt
		move.b	#1,obFrame(a1)
		bra.w	Hanging_NormalArt
.return:
		rts
Hanging_Drop:
		bsr.s	Hanging_ClearPlayer
		bra.w	Hanging_NormalArt

; Clear only a still-owned character. Hurt/death retain their current pose.
Hanging_ClearPlayer:
		clr.b	Hang_active(a2)
		clr.b	Hang_steps(a2)
		move.b	#60,Hang_cooldown(a2)
		clr.b	obControl(a1)
		bclr	#status.player.on_object,obStatus(a1)
		clr.b	standonobject(a1)
		cmpi.l	#Obj02,code(a1)
		beq.s	.tails
		move.l	#Map_Sonic,obMap(a1)
		move.b	#$FF,(Sonic_LastLoadedDPLC).w
		bra.s	.pose
.tails:
		move.b	#$FF,(Tails_LastLoadedDPLC).w
.pose:
		cmpi.b	#4,obRoutine(a1)
		bhs.s	.return
		move.b	#AniIDSonAni_Walk,obAnim(a1)
		move.b	#$FF,obPrevAni(a1)
		move.b	#1,obFrame(a1)
.return:
		rts

Hanging_TerrainContact:
		btst	#Hang_NoSupportBit,d5
		bne.s	.return
		movem.l	d0-d7/a0-a6,-(sp)
		movea.l	a1,a0
		jsr	(loc_13146).l		; both feet, selected collision path, no physics
		move.w	d1,6(sp)		; return distance through saved d1, preserve all pointers
		movem.l	(sp)+,d0-d7/a0-a6
		tst.w	d1
		bgt.s	.return		; a positive probe distance is NOT contact
		cmpi.w	#-16,d1
		blt.s	.return
		add.w	d1,obY(a1)
		bsr.s	Hanging_ClearPlayer
		movem.l	a0-a2,-(sp)
		movea.l	a1,a0
		cmpi.l	#Obj02,code(a0)
		beq.s	.tails
		jsr	(Sonic_ResetOnFloor).l
		bra.s	.landed
.tails:
		jsr	(Tails_ResetOnFloor).l
.landed:
		clr.w	obVelY(a0)
		movem.l	(sp)+,a0-a2
		bra.w	Hanging_NormalArt
.return:
		rts

Hanging_DrawPlayer:
		movem.l	d0-d7/a0-a6,-(sp)
		moveq	#0,d0
		move.b	Hang_frame(a2),d0
		movea.l	a1,a0
		cmpi.l	#Obj02,code(a0)
		beq.s	.tails
		lea	(DPLC_HangingSonic).l,a2
		lea	(Sonic_LastLoadedDPLC).w,a3
		move.w	#ArtTile_Sonic*tile_size,d4
		move.l	#Art_HangingSonic,d6
		jsr	(Load_DynamicPLC).l
		bcs.s	.return		; keep previous mapping/pose if no complete DMA fits
		move.l	#Map_HangingSonic,obMap(a0)
		move.b	#sprite_bound(Map_Sonic_height,Map_HangingSonic_height),height_pixels(a0)
		move.b	d0,obFrame(a0)
		bra.s	.return
.tails:
		lea	Hanging_TailsFrames(pc),a2
		move.b	(a2,d0.w),d0
		move.w	d0,-(sp)
		jsr	(LoadTailsDynPLC_Frame).l
		movem.w	(sp)+,d0
		bcs.s	.return
		move.b	d0,obFrame(a0)
.return:
		movem.l	(sp)+,d0-d7/a0-a6
		rts
Hanging_TailsFrames:	dc.b $80,$81,$82,$83,$84,$85,$91,0

Hanging_NormalArt:
		movem.l	d0-d7/a0-a6,-(sp)
		moveq	#0,d0
		move.b	obFrame(a1),d0
		jsr	(Perform_Player_DPLC).l
		movem.l	(sp)+,d0-d7/a0-a6
		rts
Hanging_Sound:
		btst	#Hang_SilentBit,d5
		bne.s	.return
		movem.l	d0-d7/a0-a6,-(sp)
		move.w	#sfx_Grab,d0
		jsr	(PlaySound_Special).l
		movem.l	(sp)+,d0-d7/a0-a6
.return:
		rts

Hanging_OwnedByThis:
		moveq	#0,d1
		move.b	standonobject(a1),d1
		mulu.w	#object_size,d1
		addi.l	#v_objspace,d1
		cmpa.l	d1,a0
		rts

; Resolve a hanging owner without adding a universal player field. The old
; stood-on index names the hanger, but Status_OnObj stays clear while hanging.
; a1 player -> a3 hanger / a2 player record; carry set when genuinely owned.
Hanging_FindOwner:
		cmpi.b	#3,obControl(a1)
		bne.s	.miss
		moveq	#0,d0
		move.b	standonobject(a1),d0
		cmpi.w	#object_slot_count,d0
		bhs.s	.miss
		mulu.w	#object_size,d0
		addi.l	#v_objspace,d0
		movea.l	d0,a3
		cmpi.l	#HangingSurface,code(a3)
		beq.s	.record
		cmpi.l	#Hanging_Child,code(a3)
		bne.s	.miss
.record:
		lea	Hang_p1(a3),a2
		cmpa.w	#v_player,a1
		beq.s	.active
		cmpa.w	#v_player2,a1
		bne.s	.miss
		lea	Hang_p2(a3),a2
.active:
		tst.b	Hang_active(a2)
		beq.s	.miss
		ori.b	#1,ccr
		rts
.miss:
		andi.b	#$FE,ccr
		rts

; Called only at the ordinary engine's actual top-landing boundary, after its
; inline control==3 guard. No object-distance polling or ordinary-player JSR.
Hanging_AllowLanding:
		movem.l	d0/a2-a3,-(sp)
		bsr.w	Hanging_FindOwner
		bcc.s	.allowed
		move.w	obSubtype(a3),d0
		btst	#Hang_NoSupportBit,d0
		beq.s	.allowed
		movem.l	(sp)+,d0/a2-a3
		ori.b	#1,ccr
		rts
.allowed:
		movem.l	(sp)+,d0/a2-a3
		andi.b	#$FE,ccr
		rts
Hanging_ReleaseForLanding:
		movem.l	d0-d7/a0-a6,-(sp)
		bsr.w	Hanging_FindOwner
		bcc.s	.restore
		movea.l	a3,a0
		bsr.w	Hanging_ClearPlayer
		bsr.w	Hanging_NormalArt
.restore:
		movem.l	(sp)+,d0-d7/a0-a6
		rts

; Only the intersecting handholds reach the ordinary renderer. Eleven grips
; cover a 320px viewport, including the partial grip at either edge. Selecting
; a 1..11 mapping keeps byte-sized bounds and prevents 512px sprite wrap.
; The controller retains its physical origin and full word-width span.
Hanging_Display:
		move.w	obSubtype(a0),d0
		btst	#7,d0
		beq.w	Hanging_RemoveDisplay
		btst	#Hang_HideArtBit,d0
		bne.w	Hanging_RemoveDisplay
		move.w	Hang_halfwidth(a0),d2
		move.w	obX(a0),d4
		sub.w	d2,d4
		addi.w	#16,d4		; first grip centre
		lsr.w	#4,d2		; total grips, including zero's one-grip default
		move.w	(Camera_X_pos).w,d0
		subq.w	#7,d0
		sub.w	d4,d0
		bpl.s	.first
		moveq	#0,d0
.first:
		addi.w	#31,d0
		lsr.w	#5,d0		; first cell whose right edge reaches the viewport
		sub.w	d0,d2
		ble.w	.return
		lsl.w	#5,d0
		add.w	d0,d4
		move.w	(Camera_X_pos).w,d0
		addi.w	#327,d0
		sub.w	d4,d0
		bmi.w	.return
		lsr.w	#5,d0
		addq.w	#1,d0
		cmp.w	d0,d2
		bls.s	.count
		move.w	d0,d2
.count:
		; d2 visible grip count; d4 first centre. No state is stored per grip.
		move.w	Hang_display(a0),d0
		beq.s	.allocate
		movea.w	d0,a1
		cmpi.l	#Hanging_DisplayHelper,code(a1)
		bne.s	.allocate
		move.w	a0,d0
		cmp.w	Hang_parent(a1),d0
		beq.s	.draw
.allocate:
		clr.w	Hang_display(a0)
		movem.l	d2/d4,-(sp)
		jsr	(FindFreeObj).l
		movem.l	(sp)+,d2/d4
		bne.s	.return		; retain interaction and retry the display later
		move.l	#Hanging_DisplayHelper,code(a1)
		move.w	a0,Hang_parent(a1)
		move.w	a1,Hang_display(a0)
		move.l	#Map_HangingSurface,obMap(a1)
		move.w	#make_art_tile(ArtTile_HangingSurface,0,0),obGfx(a1)
		move.w	#$80,obPriority(a1)
		move.b	#Map_HangingSurface_height,height_pixels(a1)
		move.b	#4,obRender(a1)
.draw:
		move.w	d2,d0
		subq.w	#1,d0
		move.b	d0,obFrame(a1)
		lsl.w	#4,d0
		add.w	d4,d0
		move.w	d0,obX(a1)
		lsl.w	#4,d2
		subq.w	#8,d2
		move.b	d2,width_pixels(a1)
		move.w	obY(a0),d0
		subi.w	#20,d0
		move.w	d0,obY(a1)
		jmp	(DisplaySprite2).l	; parent queues it after positioning, irrespective of slot order
.return:
		rts

Hanging_DisplayHelper:
		movea.w	Hang_parent(a0),a1
		cmpi.l	#HangingSurface,code(a1)
		beq.s	.owner
		cmpi.l	#Hanging_Child,code(a1)
		bne.w	DeleteObject
.owner:
		move.w	a0,d0
		cmp.w	Hang_display(a1),d0
		bne.w	DeleteObject
		rts

Hanging_RemoveDisplay:
		move.w	Hang_display(a0),d0
		beq.s	.return
		clr.w	Hang_display(a0)
		movea.w	d0,a1
		cmpi.l	#Hanging_DisplayHelper,code(a1)
		bne.s	.return
		move.w	a0,d0
		cmp.w	Hang_parent(a1),d0
		bne.s	.return
		jmp	(DeleteObject2).l
.return:
		rts

Hanging_ReleaseAll:
		movem.l	d0-d7/a0-a6,-(sp)
		bsr.s	Hanging_RemoveDisplay
		lea	Hang_p1(a0),a2
		lea	(v_player).w,a1
		bsr.s	.player
		lea	Hang_p2(a0),a2
		lea	(v_player2).w,a1
		bsr.s	.player
		movem.l	(sp)+,d0-d7/a0-a6
		rts
.player:
		tst.b	Hang_active(a2)
		beq.s	.return
		bsr.w	Hanging_OwnedByThis
		bne.s	.return
		cmpi.b	#3,obControl(a1)
		beq.w	Hanging_Drop
.return:
		rts

		include "mappings/sprite/Sonic hanging.asm"

Map_HangingSurface:
		binclude "mappings/sprite/Hanging surface.bin"
		include "mappings/spriteDPLC/Sonic hanging.asm"
