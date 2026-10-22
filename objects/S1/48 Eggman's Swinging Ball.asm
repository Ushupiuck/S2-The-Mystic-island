; ---------------------------------------------------------------------------
; Object 48 - GHZ boss's chain and wrecking ball
; S3&K-style staged drop and full-speed scattering on defeat; S1's weighted
; pendulum is retained. One sine calculation positions the whole live chain.
; ---------------------------------------------------------------------------
GBall_Children = objoff_2E	; root only: five word SST pointers, ending at $37
GBall_Root = objoff_2E		; children only: word pointer back to the root
GBall_Parent = objoff_38		; long: ship, independent of the other chain pieces
GBall_Distance = objoff_3C	; word: drop offset, then radius from the mount
GBall_TargetDistance = objoff_3E	; word: final drop offset from the ship
GBall_SwingDirection = objoff_40	; byte: angular acceleration direction
GBall_DebrisFlicker = objoff_41	; byte: draw phase, never a movement gate
GBall_SwingVelocity = objoff_42	; word: angular velocity
GBall_PieceIndex = objoff_44	; byte: index into the breakup velocity table
GBall_MountDistance = $20
GBall_DebrisRoutine = $A

Obj48:
		cmpi.b	#GBall_DebrisRoutine,obRoutine(a0)
		beq.w	GBall_Debris		; detached pieces no longer read their parent
		movea.l	GBall_Parent(a0),a1
		cmpi.l	#Obj3D,code(a1)
		bne.w	GBall_Delete
		cmpi.b	#2,obRoutine(a1)
		bne.w	GBall_Delete
		tst.b	obStatus(a1)
		bpl.s	.dispatch
		tst.b	obRoutine(a0)		; an uninitialized weapon has no visible pieces
		beq.w	GBall_Delete
		bra.w	GBall_BreakApart
.dispatch:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	GBall_Index(pc,d0.w),d1
		jmp	GBall_Index(pc,d1.w)
; ===========================================================================
GBall_Index:	dc.w GBall_Main-GBall_Index
		dc.w GBall_Deploy-GBall_Index
		dc.w GBall_Swing-GBall_Index
		dc.w GBall_Link-GBall_Index
		dc.w GBall_Ball-GBall_Index
; ===========================================================================

GBall_Main:	; Routine 0
		; All links and the ball are required. Do not repurpose a partial chain.
		lea	object_size(a0),a1
		moveq	#GBall_ChildCount-1,d1
.find_slot:
		cmpa.w	#v_lvlobjend,a1
		bhs.s	.return
		tst.l	code(a1)
		bne.s	.next_slot
		dbf	d1,.next_slot
		bra.s	.slots_ready
.next_slot:
		lea	object_size(a1),a1
		bra.s	.find_slot
.return:
		rts
.slots_ready:
		move.b	#2,obRoutine(a0)
		move.w	#$4080,obAngle(a0)
		move.w	#-$200,GBall_SwingVelocity(a0)
		move.l	#Map_BossItems,obMap(a0)
		move.b	#Map_BossItems_height,height_pixels(a0)
		move.b	#Map_BossItems_width,width_pixels(a0)
		move.w	#make_art_tile(ArtTile_Eggman_Weapons,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$300,obPriority(a0)
		move.w	#GBall_MountDistance,GBall_TargetDistance(a0)
		lea	GBall_DropOffsets(pc),a3
		lea	GBall_Children(a0),a2
		moveq	#GBall_ChildCount-1,d6
.make_child:
		jsr	(FindNextFreeObj).l
		move.w	a1,(a2)+
		move.l	#Obj48,code(a1)
		move.b	#6,obRoutine(a1)
		move.l	#Map_Obj17,obMap(a1)
		move.b	#Map_Obj17_height,height_pixels(a1)
		move.b	#sprite_bound(8,Map_Obj17_width),width_pixels(a1)
		move.w	#make_art_tile(ArtTile_GHZ_MZ_Swing,0,0),obGfx(a1)
		move.b	#1,obFrame(a1)
		move.b	#4,obRender(a1)
		move.w	#$300,obPriority(a1)
		move.w	a0,GBall_Root(a1)
		move.l	GBall_Parent(a0),GBall_Parent(a1)
		moveq	#0,d0
		move.b	(a3)+,d0
		move.w	d0,GBall_TargetDistance(a1)
		moveq	#GBall_ChildCount,d0
		sub.w	d6,d0
		move.b	d0,GBall_PieceIndex(a1)
		dbf	d6,.make_child
		move.b	#8,obRoutine(a1)
		move.l	#Map_GBall,obMap(a1)
		move.b	#Map_GBall_height,height_pixels(a1)
		move.b	#Map_GBall_width,width_pixels(a1)
		move.w	#make_art_tile(ArtTile_GHZ_Giant_Ball,2,0),obGfx(a1)
		move.w	#$280,obPriority(a1)
		move.b	#$81,obColType(a1)
		bra.s	GBall_Deploy
; ---------------------------------------------------------------------------

; Each piece drops two pixels/frame from the ship, stopping in sequence.
; These offsets preserve the original 32-pixel mount and 96-pixel pendulum.
GBall_DropOffsets:	dc.b $30,$40,$50,$60,$80
GBall_DropOffsets_End:
GBall_ChildCount = GBall_DropOffsets_End-GBall_DropOffsets
		even
; ===========================================================================

GBall_Deploy:	; Routine 2
		movea.l	a0,a1
		bsr.w	GBall_DropPiece
		lea	GBall_Children(a0),a2
		moveq	#GBall_ChildCount-1,d6
.drop_child:
		movea.w	(a2)+,a1
		bsr.w	GBall_CheckChild
		bne.s	.next_child
		bsr.w	GBall_DropPiece
.next_child:
		dbf	d6,.drop_child
		bsr.w	GBall_CheckChild
		bne.s	GBall_PositionDrop
		move.w	GBall_Distance(a1),d0
		cmp.w	GBall_TargetDistance(a1),d0	; last piece is also the longest drop
		bne.s	GBall_PositionDrop
		lea	GBall_Children(a0),a2
		moveq	#GBall_ChildCount-1,d6
.set_radius:
		movea.w	(a2)+,a1
		bsr.w	GBall_CheckChild
		bne.s	.next_radius
		subi.w	#GBall_MountDistance,GBall_Distance(a1)
.next_radius:
		dbf	d6,.set_radius
		move.b	#4,obRoutine(a0)
		movea.l	GBall_Parent(a0),a1
		move.b	#1,BGHZ_WeaponReady(a1)
		bra.w	GBall_PositionSwing
; ---------------------------------------------------------------------------

GBall_DropPiece:
		move.w	GBall_Distance(a1),d0
		cmp.w	GBall_TargetDistance(a1),d0
		bhs.s	.return
		addq.w	#2,GBall_Distance(a1)
.return:
		rts
; ---------------------------------------------------------------------------

GBall_PositionDrop:
		bsr.w	GBall_FollowShip
		movea.l	GBall_Parent(a0),a3
		lea	GBall_Children(a0),a2
		moveq	#GBall_ChildCount-1,d6
.position_child:
		movea.w	(a2)+,a1
		bsr.w	GBall_CheckChild
		bne.s	.next_child
		move.w	obX(a3),obX(a1)
		move.w	obY(a3),d0
		add.w	GBall_Distance(a1),d0
		move.w	d0,obY(a1)
.next_child:
		dbf	d6,.position_child
		jmp	(DisplaySprite).l
; ===========================================================================

GBall_Swing:	; Routine 4
		move.w	GBall_SwingVelocity(a0),d0
		tst.b	GBall_SwingDirection(a0)
		bne.s	.accelerate_left
		addq.w	#8,d0
		cmpi.w	#$200,d0
		bne.s	.update_angle
		move.b	#1,GBall_SwingDirection(a0)
		bra.s	.update_angle
.accelerate_left:
		subq.w	#8,d0
		cmpi.w	#-$200,d0
		bne.s	.update_angle
		clr.b	GBall_SwingDirection(a0)
.update_angle:
		move.w	d0,GBall_SwingVelocity(a0)
		add.w	d0,obAngle(a0)

GBall_PositionSwing:
		bsr.w	GBall_FollowShip
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		move.w	obX(a0),d2
		move.w	obY(a0),d3
		lea	GBall_Children(a0),a2
		moveq	#GBall_ChildCount-1,d6
.position_child:
		movea.w	(a2)+,a1
		bsr.s	GBall_CheckChild
		bne.s	.next_child
		move.w	GBall_Distance(a1),d4
		move.w	d4,d5
		muls.w	d1,d4
		asr.l	#8,d4
		muls.w	d0,d5
		asr.l	#8,d5
		add.w	d2,d4
		add.w	d3,d5
		move.w	d4,obX(a1)
		move.w	d5,obY(a1)
.next_child:
		dbf	d6,.position_child
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

GBall_CheckChild:
		cmpi.l	#Obj48,code(a1)
		bne.s	.return
		cmpa.w	GBall_Root(a1),a0
.return:
		rts
; ---------------------------------------------------------------------------

GBall_FollowShip:
		addi.b	#$20,obAniFrame(a0)
		bcc.s	.position
		bchg	#0,obFrame(a0)
.position:
		movea.l	GBall_Parent(a0),a1
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),d0
		add.w	GBall_Distance(a0),d0
		move.w	d0,obY(a0)
		rts
; ===========================================================================

GBall_Link:	; Routine 6
		jmp	(DisplaySprite).l

GBall_Ball:	; Routine 8
		bchg	#0,obFrame(a0)
		jmp	(DisplaySprite).l
; ===========================================================================

GBall_BreakApart:
		clr.b	obColType(a0)
		move.b	#GBall_DebrisRoutine,obRoutine(a0)
		moveq	#0,d0
		move.b	GBall_PieceIndex(a0),d0
		lsl.w	#2,d0
		lea	GBall_BreakVelocity(pc,d0.w),a2
		move.w	(a2)+,obVelX(a0)
		move.w	(a2)+,obVelY(a0)
		btst	#0,obStatus(a1)
		beq.s	GBall_Debris
		neg.w	obVelX(a0)

GBall_Debris:	; Routine A - detached, harmless pieces
		jsr	(ObjectFall).l		; physics runs even on the invisible flicker frames
		move.w	obX(a0),d0
		sub.w	(Camera_X_pos).w,d0
		addi.w	#$80,d0
		cmpi.w	#320+$100,d0
		bhi.s	GBall_Delete
		move.w	obY(a0),d0
		sub.w	(Camera_Y_pos).w,d0
		addi.w	#$80,d0
		cmpi.w	#224+$100,d0
		bhi.s	GBall_Delete
		bchg	#0,GBall_DebrisFlicker(a0)
		beq.s	.return
		jmp	(DisplaySprite).l
.return:
		rts
; ---------------------------------------------------------------------------

GBall_Delete:
		jmp	(DeleteObject).l
; ---------------------------------------------------------------------------

; S3&K's indexed launch velocities for its six GHZ weapon pieces.
GBall_BreakVelocity:
		dc.w -$100,-$100		; mount
		dc.w -$200,-$200		; links
		dc.w -$300,-$200
		dc.w -$200,-$200
		dc.w -$400,-$300
		dc.w  $300,-$300		; ball
GBall_BreakVelocity_End:
		if (GBall_BreakVelocity_End-GBall_BreakVelocity)/4<>GBall_ChildCount+1
		fatal "GHZ weapon needs one breakup velocity per piece"
		endif
