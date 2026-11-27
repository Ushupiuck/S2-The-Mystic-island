; ===========================================================================
; ---------------------------------------------------------------------------
; Solid object subroutines (includes spikes, blocks, rocks etc)
; These check collision of Sonic/Tails with objects on the screen
;
; input variables:
; d1 = object width
; d2 = object height / 2 (when jumping)
; d3 = object height / 2 (when walking)
; d4 = object x-axis position
;
; address registers:
; a0 = the object to check collision with
; a1 = sonic or tails (set inside these subroutines)
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


SolidObject:
		lea	(v_player).w,a1			; a1=character
		moveq	#3,d6
		movem.l	d1-d4,-(sp)			; store input registers
		bsr.s	.sub_F456			; first collision check with Sonic
		movem.l	(sp)+,d1-d4			; restore input registers
		lea	(v_player2).w,a1		; a1=character ; now check collision with Tails
		tst.b	obRender(a1)
		bpl.s	.return				; return if not Tails
		addq.b	#1,d6

.sub_F456:
		btst	d6,obStatus(a0)
		beq.w	SolidObject_OnScreenTest
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	+
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	+
		cmp.w	d2,d0		; has Sonic moved off the right?
		bls.s	SolidObject_Always_SingleCharacter.stand		; if not, branch
+
		bclr	#status.player.on_object,obStatus(a1)
		bset	#status.player.in_air,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
.return:	rts
; End of function SolidObject

; ===========================================================================
; alternate function to check for collision even if off-screen, unused
; in this build...
SolidObject_Always:
		lea	(v_player).w,a1			; a1=character
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.s	SolidObject_Always_SingleCharacter
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1		; a1=character
		addq.b	#1,d6
; loc_F4A8:
SolidObject_Always_SingleCharacter:
		btst	d6,obStatus(a0)
		beq.w	SolidObject_cont
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	+
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	+
		cmp.w	d2,d0
		bls.s	.stand
+
		bclr	#status.player.on_object,obStatus(a1)
		bset	#status.player.in_air,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------

.stand:
		move.w	d4,d2
		bsr.w	MvSonicOnPtfm
		moveq	#0,d4
		rts
; End of function SolidObject_Always

; ===========================================================================

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


SolidObject_MorphPlatform:
		lea	(v_player).w,a1			; a1=character
		moveq	#3,d6
		movem.l	d1-d4,-(sp)			; store input registers
		bsr.s	.do1player			; first collision check with Sonic
		movem.l	(sp)+,d1-d4			; restore input registers
		lea	(v_player2).w,a1		; a1=character ; now check collision with Tails
		tst.b	obRender(a1)
		bpl.s	.return				; return if not Tails
		addq.b	#1,d6

.do1player:
		btst	d6,obStatus(a0)
		beq.w	SolidObject_OnScreenTest
		moveq	#0,d5
		move.b	obActWid(a0),d5		; raw visible top/standing radius
		move.w	d5,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	+
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d5,d0
		bmi.s	+
		cmp.w	d2,d0
		bls.s	SolidObject_Always_SingleCharacter.stand
+
		bclr	#status.player.on_object,obStatus(a1)
		bset	#status.player.in_air,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
.return:	rts
; ---------------------------------------------------------------------------
; Subroutine to collide Sonic/Tails with the top of a sloped
; solid like diagonal springs; unused in this build...
;
; input variables:
; d1 = object width
; d2 = object height / 2 (when jumping)
; d3 = object height / 2 (when walking)
; d4 = object x-axis position
;
; address registers:
; a0 = the object to check collision with
; a1 = sonic or tails (set inside these subroutines)
; a2 = height data for slope
; ---------------------------------------------------------------------------
SolidObject_Sloped:
		lea	(v_player).w,a1			; a1=character
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.s	SlopedSolid_SingleCharacter
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1		; a1=character
		addq.b	#1,d6
; loc_F4FA:
SlopedSolid_SingleCharacter:
		btst	d6,obStatus(a0)
		beq.w	SlopedSolid_cont
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	loc_F51E
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	loc_F51E
		cmp.w	d2,d0
		bls.s	loc_F52C

loc_F51E:
		bclr	#status.player.on_object,obStatus(a1)
		bset	#status.player.in_air,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------

loc_F52C:
		move.w	d4,d2
		bsr.w	MvSonicOnSlope
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------
; loc_F536:
SlopedSolid_cont:
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.w	SolidObject_TestClearPush
		move.w	d1,d3
		add.w	d3,d3
		cmp.w	d3,d0
		bhi.w	SolidObject_TestClearPush
		move.w	d0,d5
		btst	#0,obRender(a0)
		beq.s	loc_F55C
		not.w	d5
		add.w	d3,d5

loc_F55C:
		lsr.w	#1,d5
		move.b	(a2,d5.w),d3
		sub.b	(a2),d3
		ext.w	d3
		move.w	obY(a0),d5
		sub.w	d3,d5
		move.b	obHeight(a1),d3
		ext.w	d3
		add.w	d3,d2
		move.w	obY(a1),d3
		sub.w	d5,d3
		addq.w	#4,d3
		add.w	d2,d3
		bmi.w	SolidObject_TestClearPush
		move.w	d2,d4
		add.w	d4,d4
		cmp.w	d4,d3
		bhs.w	SolidObject_TestClearPush
		bra.w	SolidObject_ChkBounds
; ===========================================================================
; loc_F590:
SolidObject_OnScreenTest:
		tst.b	obRender(a0)
		bpl.w	SolidObject_TestClearPush
; loc_F598:
SolidObject_cont:
		cmpi.b	#Player_MiniHeight,default_y_radius(a1)
		bne.s	.width_ready
		subq.w	#sonic_width-Player_MiniWidth,d1
.width_ready:
		; We now perform the x portion of a bounding box check.  To do this, we assume a
		; coordinate system where the x origin is at the object's left edge.
		move.w	obX(a1),d0			; load Sonic's x position...
		sub.w	obX(a0),d0			; ... and calculate his x position relative to the object
		add.w	d1,d0				; assume object's left edge is at (0,0).  This is also Sonic's distance to the object's left edge.
		bmi.w	SolidObject_TestClearPush	; branch, if Sonic is outside the object's left edge
		move.w	d1,d3
		add.w	d3,d3				; calculate object's width
		cmp.w	d3,d0
		bhi.w	SolidObject_TestClearPush	; branch, if Sonic is outside the object's right edge
		; We now perform the y portion of a bounding box check.  To do this, we assume a
		; coordinate system where the y origin is at the highest y position relative to the object
		; at which Sonic would still collide with it.  This point is
		;   y_pos(object) - width(object)/2 - y_radius(Sonic) - 4,
		; where object is stored in (a0), Sonic in (a1), and height(object)/2 in d2.  This way
		; of doing it causes the object's hitbox to be vertically off-center by -4 pixels.
		move.b	obHeight(a1),d3			; load Sonic's y radius
		ext.w	d3
		add.w	d3,d2				; calculate maximum distance for a top collision
		move.w	obY(a1),d3			; load Sonic's y position
		sub.w	obY(a0),d3			; ... and calculate his y position relative to the object
		addq.w	#4,d3				; assume a slightly lower position for Sonic
		add.w	d2,d3				; assume the highest position where Sonic would still be colliding with the object to be (0,0)
		bmi.w	SolidObject_TestClearPush	; branch, if Sonic is above this point
	andi.w	#$7FF,d3
		move.w	d2,d4
		add.w	d4,d4				; calculate minimum distance for a bottom collision
		cmp.w	d4,d3
		bhs.w	SolidObject_TestClearPush	; branch, if Sonic is below this point
; loc_F5D2:
SolidObject_ChkBounds:
		tst.b	obControl(a1)
		bmi.w	SolidObject_NoCollision	; catch-up / carried characters do not collide
		tst.b	(f_playerctrl).w
		bmi.w	SolidObject_TestClearPush	; branch, if object collisions are disabled for Sonic
		cmpi.b	#6,obRoutine(a1)		; is Sonic dead?
		bhs.w	SolidObject_NoCollision			; if yes, branch
		tst.w	(Debug_placement_mode).w
		bne.w	SolidObject_NoCollision			; branch, if in Debug Mode

		; A grounded duck has the same clearance as rolling/spindashing.
		; Keep the feet, landing bounds and platform ride position unchanged.
		btst	#status.player.in_air,obStatus(a1)
		bne.s	.full_height
		cmpi.b	#AniIDSonAni_Duck,obAnim(a1)
		beq.s	.compact
		cmpi.b	#AniIDSonAni_Spindash,obAnim(a1)
		bne.s	.full_height
.compact:
		moveq	#0,d5
		move.b	obHeight(a1),d5
		subi.w	#sonic_roll_height,d5
		cmpi.b	#Player_MiniHeight,default_y_radius(a1)
		bne.s	.compare
		addq.w	#sonic_roll_height-Player_MiniRollHeight,d5
.compare:
		tst.w	d5
		ble.s	.full_height		; already using a compact radius
		sub.w	d5,d2			; use the same top/bottom midpoint as the compact body
		add.w	d5,d5			; standing diameter minus compact diameter
		sub.w	d5,d4
		cmp.w	d4,d3
		bhs.w	Solid_NotPushing		; clear this object's push flags, retaining Duck
.full_height:
		move.w	d0,d5
		cmp.w	d0,d1
		bhs.s	.isToTheLeft			; branch, if Sonic is to the object's left

;.isToTheRight:
		add.w	d1,d1
		sub.w	d1,d0
		move.w	d0,d5				; calculate Sonic's distance to the object's right edge...
		neg.w	d5				; ... and calculate the absolute value

.isToTheLeft:
		move.w	d3,d1
		cmp.w	d3,d2
		bhs.s	.isAbove

;.isBelow:
		subq.w	#4,d3
		sub.w	d4,d3
		move.w	d3,d1
		neg.w	d1

.isAbove:
	; Now...
	; 'd0' contains Sonic's distance to the nearest object horizontal edge.
	; 'd5' contains the absolute version of 'd0'.
	; 'd3' contains Sonic's distance to the nearest object vertical edge.
	; 'd1' contains the absolute version of 'd3'.
		cmp.w	d1,d5
		bhi.w	SolidObject_TopBottom			; branch, if horizontal distance is greater than vertical distance

SolidObject_LeftRight:
	; If Sonic is extremely close to the top or bottom, then branch.
	; I guess the point of this is to let Sonic walk over objects that
	; are barely poking out of the ground?
		cmpi.w	#4,d1
		bls.s	SolidObject_SideAir

		tst.w	d0
		beq.s	SolidObject_AtEdge
		bmi.s	SolidObject_InsideRight

;SolidObject_InsideLeft:
		tst.w	obVelX(a1)
		bmi.s	SolidObject_AtEdge
		bra.s	SolidObject_StopCharacter
; ===========================================================================

SolidObject_InsideRight:
		tst.w	obVelX(a1)
		bpl.s	SolidObject_AtEdge

SolidObject_StopCharacter:
		clr.w	obInertia(a1)
		clr.w	obVelX(a1)

SolidObject_AtEdge:
		sub.w	d0,obX(a1)
		btst	#1,obStatus(a1)
		bne.s	SolidObject_SideAir
		move.l	d6,d4
		addq.b	#2,d4				; Character is pushing, not standing
		bset	d4,obStatus(a0)
		bset	#5,obStatus(a1)
		move.w	d6,d4
		addi.b	#$D,d4
		bset	d4,d6				; This sets bits 0 (Sonic) or 1 (Tails) of high word of d6
		moveq	#1,d4
		rts
; ===========================================================================

SolidObject_SideAir:
		bsr.s	Solid_NotPushing
		move.w	d6,d4
		addi.b	#$D,d4
		bset	d4,d6				; This sets bits 0 (Sonic) or 1 (Tails) of high word of d6
		moveq	#1,d4
		rts
; ===========================================================================
; loc_F668:
SolidObject_IgnoreActor:
		bsr.w	ReleaseObjectRider
SolidObject_TestClearPush:
		move.l	d6,d4
		addq.b	#2,d4
		btst	d4,obStatus(a0)
		beq.s	SolidObject_NoCollision
		cmpi.b	#AniIDSonAni_Roll,obAnim(a1)
		beq.s	Solid_NotPushing
		cmpi.b	#AniIDSonAni_Spindash,obAnim(a1)
		beq.s	Solid_NotPushing
		cmpi.b	#AniIDSonAni_Death,obAnim(a1)
		beq.s	Solid_NotPushing
		cmpi.b	#AniIDSonAni_Drown,obAnim(a1)
		beq.s	Solid_NotPushing
		move.w	#(AniIDSonAni_Walk<<8)|(AniIDSonAni_Run<<0),obAnim(a1) ; use walking animation (and force it to restart)

Solid_NotPushing:
		move.l	d6,d4
		addq.b	#2,d4
		bclr	d4,obStatus(a0)	; clear pushing flag
		bclr	#status.player.pushing,obStatus(a1)	; clear Sonic's pushing flag

SolidObject_NoCollision:
		moveq	#0,d4
		rts
; ===========================================================================

SolidObject_TopBottom:
		tst.w	d3
		bmi.s	SolidObject_InsideBottom

;SolidObject_InsideTop:
		cmpi.w	#$10,d3
		blo.s	SolidObject_Landed
		cmpi.w	#$14,d3				; has Sonic landed on the object?
		blo.s	SolidObject_Landed		; if yes, branch
		bra.s	SolidObject_TestClearPush
; ===========================================================================

SolidObject_InsideBottom:
		tst.w	obVelY(a1)
		beq.s	SolidObject_Squash
		bpl.s	loc_F6A6
		tst.w	d3
		bpl.s	loc_F6A6
		clr.w	obVelY(a1)

loc_F6A6:
		sub.w	d3,obY(a1)
		move.w	d6,d4
		addi.b	#$F,d4
		bset	d4,d6				; This sets bits 2 (Sonic) or 3 (Tails) of high word of d6
		moveq	#-2,d4
		rts
; ===========================================================================

SolidObject_Squash:
		btst	#1,obStatus(a1)
		bne.s	loc_F6A6
		mvabs.w	d0,d4
		cmpi.w	#$10,d4
		blo.w	SolidObject_LeftRight
		move.l	a0,-(sp)
		movea.l	a0,a2
		movea.l	a1,a0
		jsr	(KillSonic).l
		movea.l	(sp)+,a0			; load obj address
		move.w	d6,d4
		addi.b	#$F,d4
		bset	d4,d6				; This sets bits 2 (Sonic) or 3 (Tails) of high word of d6
		moveq	#-2,d4
		rts
; ===========================================================================

SolidObject_Landed:
		cmpi.b	#3,obControl(a1)
		bne.s	.hanging_checked
		jsr	(Hanging_AllowLanding).l
		bcs.w	SolidObject_Miss
.hanging_checked:
		subq.w	#4,d3
		moveq	#0,d1
		move.b	obActWid(a0),d1
		move.w	d1,d2
		add.w	d2,d2
		add.w	obX(a1),d1
		sub.w	obX(a0),d1
		bmi.s	SolidObject_Miss
		cmp.w	d2,d1
		bhs.s	SolidObject_Miss
		tst.w	obVelY(a1)
		bmi.s	SolidObject_Miss
		sub.w	d3,obY(a1)
		subq.w	#1,obY(a1)
		bsr.w	RideObject_SetRide
		move.w	d6,d4
		addi.b	#$11,d4
		bset	d4,d6				; This sets bits 4 (Sonic) or 5 (Tails) of high word of d6
		moveq	#-1,d4
		rts
; ===========================================================================

SolidObject_Miss:
		moveq	#0,d4
		rts
; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to change Sonic's position with a platform
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_F70E:
MvSonicOnPtfm_Return:
		rts

MvSonicOnPtfm:
		tst.b	(f_playerctrl).w
		bmi.s	MvSonicOnPtfm_Return
		cmpi.b	#6,obRoutine(a1)
		bhs.s	MvSonicOnPtfm_Return
		tst.w	(Debug_placement_mode).w
		bne.s	MvSonicOnPtfm_Return
		move.w	obY(a0),d0
		sub.w	d3,d0
		moveq	#0,d1
		move.b	obHeight(a1),d1
		sub.w	d1,d0
		sub.w	obX(a0),d2
		sub.w	d2,obX(a1)

; d0.w = new rider center Y. The same-height/downward path falls through.
Object_MoveRiderY:
		cmp.w	obY(a1),d0
		blt.s	Object_RaiseRider
Object_PositionRider:
		move.w	d0,obY(a1)
		move.w	obX(a1),player_support_x(a1)
		rts

; The slope and bridge paths already proved the body's upward motion.
Object_RaiseRider:
		move.w	d0,obY(a1)
		move.w	obX(a1),player_support_x(a1)
		tst.b	(MCD_TerrainReady).l
		beq.s	.return
		tst.w	(Debug_placement_mode).w
		bne.s	.return
		tst.b	(f_playerctrl).w
		bne.s	.return
		tst.b	obControl(a1)
		bne.s	.return
		tst.l	code(a1)
		beq.s	.return
		cmpi.b	#6,obRoutine(a1)
		bhs.s	.return
		btst	#status.player.in_air,obStatus(a1)
		bne.s	.return
		bsr.w	ObjectOwnsRider
		beq.s	.check
.return:
		rts
.check:
		; The CD query only uses d0-d3. Extra registers are saved only
		; when we need to change the actor's pose or run the death path.
		movem.l	d1-d3,-(sp)
		exg	a0,a1
		cmpi.b	#AniIDSonAni_Duck,obAnim(a0)
		beq.s	.compact
		cmpi.b	#AniIDSonAni_Spindash,obAnim(a0)
		bne.s	.current
.compact:
		jsr	(Player_RollSize).l
		move.w	d0,d1
		lsr.w	#8,d1
		cmp.b	obHeight(a0),d1
		bhs.s	.current
		clr.b	player_unfolding(a0)
		jsr	(Player_ResizeRoomReady).l
		bra.s	.result
.current:
		move.w	obHeight(a0),d0
		move.w	obY(a0),d2
		jsr	(Player_ProbeHeadroom).l
.result:
		bpl.s	.restore
		tst.b	player_unfolding(a0)
		beq.s	.crush
		jsr	(Player_RollSize).l
		move.w	d0,d1
		lsr.w	#8,d1
		cmp.b	obHeight(a0),d1
		bhs.s	.crush
		jsr	(Player_ResizeRoomReady).l
		bmi.s	.crush

		; The rising surface used the last standing room on the release
		; frame. Keep the feet planted and update the already queued sprite.
		movem.l	d4-d7/a0-a6,-(sp)
		move.b	#AniIDSonAni_Duck,obAnim(a0)
		clr.b	player_unfolding(a0)
		jsr	(Player_StopForDuck).l
		pea	.restore_pose(pc)
		cmpi.b	#CharacterID_Tails,character_id(a0)
		beq.s	.tails
		jsr	(Sonic_Animate).l
		jmp	(LoadSonicDynPLC).l
.tails:
		jsr	(Tails_Animate).l
		jmp	(LoadTailsDynPLC).l
.crush:
		movem.l	d4-d7/a0-a6,-(sp)
		movea.l	a1,a2
		bclr	d6,obStatus(a2)
		bclr	#status.player.on_object,obStatus(a0)
		clr.b	standonobject(a0)
		jsr	(KillCharacter).l
.restore_pose:
		movem.l	(sp)+,d4-d7/a0-a6
.restore:
		exg	a0,a1
		movem.l	(sp)+,d1-d3
		rts

; =============== S U B R O U T I N E =======================================

MvSonicOnSlope:
		btst	#status.player.on_object,obStatus(a1)
		beq.s	.return
		movem.l	d3-d4,-(sp)
		move.w	d1,d3			; half-width
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d3,d0
		bsr.s	.sample
		move.w	d0,d4			; new centre Y at the player's current X
		cmp.w	obY(a1),d0
		bge.s	.walk
		; Check the old local contact against the new surface. The player's
		; own walk up a stationary slope can change Y without a lift.
		move.w	player_support_x(a1),d0
		sub.w	d2,d0			; d2 is the support's previous X
		add.w	d3,d0
		move.w	d3,d1
		add.w	d1,d1
		cmp.w	d1,d0
		bhs.s	.walk
		bsr.s	.sample
		move.w	d0,d1
		bra.s	.place
.walk:
		move.w	obY(a1),d1
.place:
		sub.w	obX(a0),d2
		sub.w	d2,obX(a1)
		move.w	d4,d0
		movem.l	(sp)+,d3-d4
		cmp.w	obY(a1),d1
		bge.w	Object_PositionRider
		bra.w	Object_RaiseRider
.return:
		rts
.sample:
		lsr.w	#1,d0
		btst	#0,obRender(a0)
		beq.s	.normal
		not.w	d0
		add.w	d3,d0
.normal:
		move.b	(a2,d0.w),d0
		ext.w	d0
		neg.w	d0
		add.w	obY(a0),d0
		moveq	#0,d1
		move.b	obHeight(a1),d1
		sub.w	d1,d0
		rts

; =============== S U B R O U T I N E =======================================


PlatformObject:
		lea	(v_player).w,a1
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.s	PlatformObject_SingleCharacter
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1
		addq.b	#1,d6

PlatformObject_SingleCharacter:
		btst	d6,obStatus(a0)
		beq.w	PlatformObject_cont
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	+
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	+
		cmp.w	d2,d0
		blo.s	loc_F7D2
+
		bclr	#status.player.on_object,obStatus(a1)
		bset	#status.player.in_air,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------
loc_F7D2:
		move.w	d4,d2
		bsr.w	MvSonicOnPtfm
		moveq	#0,d4
		rts
; End of function PlatformObject_SingleCharacter


; =============== S U B R O U T I N E =======================================


SlopedPlatform:
		lea	(v_player).w,a1
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.s	SlopedPlatform_SingleCharacter
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1
		addq.b	#1,d6

SlopedPlatform_SingleCharacter:
		btst	d6,obStatus(a0)
		beq.w	SlopedPlatform_cont
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	loc_F816
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	loc_F816
		cmp.w	d2,d0
		blo.s	loc_F824

loc_F816:
		bclr	#status.player.on_object,obStatus(a1)
		bset	#status.player.in_air,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------
loc_F824:
		move.w	d4,d2
		bsr.w	MvSonicOnSlope
		moveq	#0,d4
		rts


; =============== S U B R O U T I N E =======================================


PlatformObject2:
		lea	(v_player).w,a1
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.s	sub_F844
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1
		addq.b	#1,d6

sub_F844:
		btst	d6,obStatus(a0)
		beq.w	PlatformObject2_cont
		move.w	d1,d2
		add.w	d2,d2
		btst	#1,obStatus(a1)
		bne.s	loc_F868
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	loc_F868
		cmp.w	d2,d0
		blo.s	loc_F876

loc_F868:
		bclr	#status.player.on_object,obStatus(a1)
		bset	#status.player.in_air,obStatus(a1)
		bclr	d6,obStatus(a0)
		moveq	#0,d4
		rts
; ---------------------------------------------------------------------------

loc_F876:
		move.w	d4,d2
		bsr.w	MvSonicOnPtfm
		moveq	#0,d4
		rts
; End of function sub_F844
; ===========================================================================
; Used only by EHZ/HPZ log bridges. Very similar to PlatformObject_cont, but
; d2 already has the full width of the log.
PlatformObject11_cont:
		tst.w	obVelY(a1)
		bmi.w	loc_F916.return
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.w	loc_F916.return
		cmp.w	d2,d0
		bhs.w	loc_F916.return
		bra.s	loc_F8BC
; ---------------------------------------------------------------------------

PlatformObject_cont:
		tst.w	obVelY(a1)
		bmi.w	loc_F916.return
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.w	loc_F916.return
		add.w	d1,d1
		cmp.w	d1,d0
		bhs.w	loc_F916.return

loc_F8BC:
		move.w	obY(a0),d0
		sub.w	d3,d0

PlatformObject_ChkYRange:
		cmpi.b	#3,obControl(a1)
		bne.s	.hanging_checked
		jsr	(Hanging_AllowLanding).l
		bcs.w	loc_F916.return
.hanging_checked:
		tst.b	obControl(a1)
		bmi.w	loc_F916.return
		move.w	obY(a1),d2
		move.b	obHeight(a1),d1
		ext.w	d1
		add.w	d2,d1
		addq.w	#4,d1
		sub.w	d1,d0
		bhi.w	loc_F916.return
		cmpi.w	#-$10,d0
		blo.w	loc_F916.return
		tst.b	(f_playerctrl).w
		bmi.w	loc_F916.return
		cmpi.b	#6,obRoutine(a1)
		bhs.w	loc_F916.return
		add.w	d0,d2
		addq.w	#4,d2		; match MvSonicOnPtfm's standing surface exactly
		move.w	d2,obY(a1)
; sub_F8F8:
RideObject_SetRide:
		cmpi.b	#3,obControl(a1)
		bne.s	.hanging_checked
		jsr	(Hanging_ReleaseForLanding).l
.hanging_checked:
		btst	#3,obStatus(a1)
		beq.s	loc_F916
		moveq	#0,d0
		move.b	standonobject(a1),d0
		mulu.w	#object_size,d0
		addi.l	#v_objspace,d0
		movea.l	d0,a3
		bclr	d6,obStatus(a3)

loc_F916:
		moveq	#0,d0
		move.w	a0,d0
		subi.w	#v_objspace,d0
		andi.l	#$FFFF,d0	; DIVU reads a long dividend; ignore the old high word
		divu.w	#object_size,d0
		andi.w	#$7F,d0
		move.b	d0,standonobject(a1)
		move.w	obX(a1),player_support_x(a1)
		clr.b	obAngle(a1)
		clr.w	obVelY(a1)
		move.w	obVelX(a1),obInertia(a1)
		btst	#1,obStatus(a1)
		beq.s	+
		move.l	a0,-(sp)
		movea.l	a1,a0
		move.w	a0,d1
		subi.w	#v_objspace,d1
		bne.s	loc_F954
		cmpi.w	#PlayerMode_Tails,(Player_mode).w	; TODO
		beq.s	loc_F954		; TODO
		bsr.w	Sonic_ResetOnFloor
		movea.l	(sp)+,a0
+		bset	#status.player.on_object,obStatus(a1)
		bclr	#status.player.in_air,obStatus(a1)
		bset	d6,obStatus(a0)
.return:	rts
; ===========================================================================

loc_F954:
		bsr.w	Tails_ResetOnFloor
		movea.l	(sp)+,a0
		bset	#status.player.on_object,obStatus(a1)
		bclr	#status.player.in_air,obStatus(a1)
		bset	d6,obStatus(a0)
		rts
; ===========================================================================
; loc_F968:
SlopedPlatform_cont:
		tst.w	obVelY(a1)
		bmi.s	loc_F916.return
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	loc_F916.return
		add.w	d1,d1
		cmp.w	d1,d0
		bhs.s	loc_F916.return
		btst	#0,obRender(a0)
		beq.s	loc_F98E
		not.w	d0
		add.w	d1,d0

loc_F98E:
		lsr.w	#1,d0
		move.b	(a2,d0.w),d3
		ext.w	d3
		move.w	obY(a0),d0
		sub.w	d3,d0
		bra.w	PlatformObject_ChkYRange
; ---------------------------------------------------------------------------

PlatformObject2_cont:
		tst.w	obVelY(a1)
		bmi.s	ExitPlatform.return
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	ExitPlatform.return
		add.w	d1,d1
		cmp.w	d1,d0
		bhs.s	ExitPlatform.return
		move.w	obY(a0),d0
		sub.w	d3,d0
		bra.w	PlatformObject_ChkYRange

; =============== S U B R O U T I N E =======================================


ExitPlatform:
		move.w	d1,d2
		add.w	d2,d2
		lea	(v_player).w,a1
		btst	#1,obStatus(a1)
		bne.s	+
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		bmi.s	+
		cmp.w	d2,d0
		blo.s	.return
+
		bclr	#3,obStatus(a1)
		move.b	#2,obRoutine(a0)
		bclr	#3,obStatus(a0)
.return:	rts
; End of function ExitPlatform

; ===========================================================================

; =============== S U B R O U T I N E =======================================

; Release only riders still owned by this surface. Adjacent/overlapping solids
; can retain an old stood-on bit after the actor moves onto another SST.
ReleaseObjectRiders:
		lea	(v_player).w,a1
		moveq	#3,d6
		bsr.s	ReleaseObjectRider
		lea	(v_player2).w,a1
		moveq	#4,d6
; a0: surface, a1: actor, d6: the surface's rider bit. Z on release.
ReleaseObjectRider:
		btst	d6,obStatus(a0)
		beq.s	.not_owned
		bclr	d6,obStatus(a0)
		bsr.s	ObjectOwnsRider
		bne.s	.not_owned
		bclr	#status.player.on_object,obStatus(a1)
		bset	#status.player.in_air,obStatus(a1)
		moveq	#0,d0
		rts
.not_owned:
		moveq	#-1,d0
		rts

; a0: actor with on_object set. Return the indexed support in a3.
Player_GetStandingObject:
		moveq	#0,d0
		move.b	standonobject(a0),d0
		mulu.w	#object_size,d0
		lea	(v_objspace).w,a3
		adda.w	d0,a3
		rts

; a0: object, a1: actor. Z if this object accepts the actor's path.
Object_MatchesPath:
		move.b	obSubtype(a0),d0
		btst	#4,d0
		beq.s	.any
		andi.b	#8,d0
		lsr.b	#2,d0
		ori.b	#$C,d0
		cmp.b	obTopSolidBit(a1),d0
		rts
.any:
		moveq	#0,d0
		rts

; Give primary-path objects priority over the cover that conceals path 2.
Object_PathPriority:
		move.b	obSubtype(a0),d0
		andi.b	#(Object_FilterPath|Object_SecondaryPath)>>8,d0
		cmpi.b	#Object_FilterPath>>8,d0
		bne.s	.return
		bset	#7,obGfx(a0)
.return:
		rts

; a0: surface, a1: actor. Z if the actor's current support is this SST.
ObjectOwnsRider:
		btst	#status.player.on_object,obStatus(a1)
		beq.s	.not_owned
		moveq	#0,d0
		move.b	standonobject(a1),d0
		mulu.w	#object_size,d0
		addi.l	#v_objspace,d0
		cmp.l	a0,d0
		rts
.not_owned:
		moveq	#-1,d0
		rts
; ===========================================================================

; =============== S U B R O U T I N E =======================================

; Static geometry scoped to the placement's collision path. Keep both
; players independent when one crosses a path switch under a rider.
SolidObject_OnPath:
		btst	#4,obSubtype(a0)		; Object_FilterPath, high byte
		beq.w	SolidObject
		lea	(v_player).w,a1
		moveq	#3,d6
		movem.l	d1-d4,-(sp)
		bsr.s	.actor
		movem.l	(sp)+,d1-d4
		lea	(v_player2).w,a1
		addq.b	#1,d6
.actor:
		tst.l	code(a1)
		beq.s	.return
		bsr.s	Object_MatchesPath
		beq.w	SolidObject.sub_F456
		bra.w	SolidObject_IgnoreActor
.return:
		rts

; A range trigger may use either live actor. Empty slots, death routines and
; scripted transport/respawn locks are not attack targets. Return C = valid.
Player_CanInteract:
		tst.l	code(a1)
		beq.s	.inactive
		cmpi.b	#6,obRoutine(a1)
		bhs.s	.inactive
		btst	#7,obControl(a1)
		bne.s	.inactive
		ori	#1,ccr
		rts
.inactive:
		andi	#$FE,ccr
		rts
; ===========================================================================
