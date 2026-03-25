; ---------------------------------------------------------------------------
; Object 04 - Player in Bonus Stage
; ---------------------------------------------------------------------------

BonusPlayer:
		tst.w	(Debug_placement_mode).w	; is debug mode being used?
		beq.s	BonusPlayer_Normal			; if not, branch
		bsr.w	S1SS_FixCamera
		jmp	(DebugMode).l
; ===========================================================================

BonusPlayer_Normal:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	BonusPlayer_Index(pc,d0.w),d1
		jmp	BonusPlayer_Index(pc,d1.w)
; ===========================================================================
BonusPlayer_Index:
		dc.w BonusPlayer_Main-BonusPlayer_Index
		dc.w BonusPlayer_ChkDebug-BonusPlayer_Index
		dc.w BonusPlayer_ExitStage-BonusPlayer_Index
ost_ss_item		= objoff_34					; $34 ; item id Sonic is touching
ost_ss_ghost		= objoff_35					; $35 ; status of ghost blocks - 0 = ghost; 1 = passed; 2 = solid
ost_ss_item_address	= objoff_36					; $36 ; RAM address of item in layout Sonic is touching
ost_ss_updown_time	= objoff_3A					; $3A ; time until UP/DOWN can be triggered again
ost_ss_r_time		= objoff_3B					; $3B ; time until R can be triggered again
; ===========================================================================

BonusPlayer_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.l	#Map_Sonic,obMap(a0)
		move.w	#make_art_tile(ArtTile_Sonic,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$100,obPriority(a0)
		move.b	#2,obAnim(a0)
		bset	#2,obStatus(a0)
		bset	#1,obStatus(a0)

BonusPlayer_ChkDebug:	; Routine 2
		tst.b	(Debug_mode_flag).w		; is debug mode	cheat enabled?
		beq.s	.no_debug			; if not, branch
		btst	#bitB,(v_jpadpress1).w		; is button B pressed?
		beq.s	.no_debug			; if not, branch
		move.w	#1,(Debug_placement_mode).w	; change Sonic into a ring

.no_debug:
		sf.b	ost_ss_item(a0)
		moveq	#0,d0
		move.b	obStatus(a0),d0
		andi.w	#2,d0				; read air bit of status (d0 = 0 or 2)
		move.w	BonusPlayer_Modes(pc,d0.w),d1
		jsr	BonusPlayer_Modes(pc,d1.w)
		jsr	(LoadSonicDynPLC).l		; update Sonic's gfx
		jmp	(DisplaySprite).l
; ===========================================================================
BonusPlayer_Modes:
		dc.w BonusPlayer_OnWall-BonusPlayer_Modes
		dc.w BonusPlayer_InAir-BonusPlayer_Modes
; ===========================================================================

BonusPlayer_OnWall:
		bclr	#7,obStatus(a0)		; clear "Sonic has jumped" flag
		bsr.w	BonusPlayer_Jump
		bsr.s	BonusPlayer_Move
		bsr.w	BonusPlayer_Fall
		bra.s	BonusPlayer_Display
; ===========================================================================

BonusPlayer_InAir:
		bsr.w	BonusPlayer_JumpHeight
		bsr.s	BonusPlayer_Move
		bsr.w	BonusPlayer_Fall

BonusPlayer_Display:
		bsr.w	SSS_ChkItems
		bsr.w	SSS_ChkItems2
		jsr	(ObjectMove).l		; update position
		bsr.w	S1SS_FixCamera		; centre camera on Sonic
		move.w	(v_ssangle).l,d0
		add.w	(v_ssrotate).l,d0	; add rotation speed to angle
		move.w	d0,(v_ssangle).l	; update angle
		jmp	(Sonic_Animate).l

; ---------------------------------------------------------------------------
; Subroutine to move Sonic by pressing left/right
; ---------------------------------------------------------------------------

BonusPlayer_Move:
		btst	#bitL,(v_jpadholdlogical).w	; is left being pressed?
		beq.s	.not_left		; if not, branch
		bsr.w	BonusPlayer_MoveLeft

.not_left:
		btst	#bitR,(v_jpadholdlogical).w	; is right being pressed?
		beq.s	.not_right		; if not, branch
		bsr.w	BonusPlayer_MoveRight

.not_right:
		move.b	(v_jpadholdlogical).w,d0
		andi.b	#btnL+btnR,d0		; is left or right being pressed?
		bne.s	SSS_UpdatePos		; if yes, branch
		move.w	obInertia(a0),d0	; get inertia
		beq.s	SSS_UpdatePos		; branch if 0
		bmi.s	.inertia_neg		; branch if negative
		subi.w	#12,d0			; subtract 12
		bcc.s	.update_inertia		; branch if positive (after subtraction)
		clr.w	d0			; set to 0 if negative (after subtraction)

.update_inertia:
		move.w	d0,obInertia(a0)	; set new inertia
		bra.s	SSS_UpdatePos
; ===========================================================================

.inertia_neg:
		addi.w	#12,d0			; add 12 to inertia
		bcc.s	.update_inertia2	; branch if negative
		clr.w	d0			; set to 0 if positive (after addition)

.update_inertia2:
		move.w	d0,obInertia(a0)	; set new inertia

SSS_UpdatePos:
		move.b	(v_ssangle).l,d0	; get stage angle
		addi.b	#$20,d0			; rotate angle 45 degrees (for wall/floor/ceiling detection)
		andi.b	#$C0,d0			; read only bits 7 and 6
		neg.b	d0
		jsr	(CalcSine).l		; convert to sine/cosine
		muls.w	obInertia(a0),d1
		add.l	d1,obX(a0)		; add (inertia*cosine) to x pos
		muls.w	obInertia(a0),d0
		add.l	d0,obY(a0)		; add (inertia*sine) to y pos
		movem.l	d0-d1,-(sp)		; save values to stack
		move.l	obY(a0),d2
		move.l	obX(a0),d3
		bsr.w	SSS_FindWall		; detect nearby walls
		beq.s	.no_collide		; branch if none found
		movem.l	(sp)+,d0-d1		; restore values from stack
		sub.l	d1,obX(a0)		; cancel position updates
		sub.l	d0,obY(a0)
		clr.w	obInertia(a0)		; stop sonic
		rts
; ===========================================================================

.no_collide:
		movem.l	(sp)+,d0-d1		; restore values from stack
		rts
; End of function BonusPlayer_Move


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


BonusPlayer_MoveLeft:
		bset	#0,obStatus(a0)
		move.w	obInertia(a0),d0	; get inertia
		beq.s	.inertia_0		; branch if 0
		bpl.s	.inertia_positive	; branch if positive (moving right)

.inertia_0:
		subi.w	#12,d0			; subtract 12 from inertia
		cmpi.w	#-$800,d0
		bgt.s	.update_inertia
		move.w	#-$800,d0		; set minimum inertia

.update_inertia:
		move.w	d0,obInertia(a0)
		rts
; ===========================================================================

.inertia_positive:
		subi.w	#$40,d0
		move.w	d0,obInertia(a0)
		rts
; End of function BonusPlayer_MoveLeft

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


BonusPlayer_MoveRight:
		bclr	#0,obStatus(a0)
		move.w	obInertia(a0),d0	; get inertia
		bmi.s	.inertia_neg		; branch if negative (moving left)
		addi.w	#12,d0			; add 12 to inertia
		cmpi.w	#$800,d0
		blt.s	.update_inertia
		move.w	#$800,d0		; set maximum inertia

.update_inertia:
		move.w	d0,obInertia(a0)
		rts
; ===========================================================================

.inertia_neg:
		addi.w	#$40,d0
		move.w	d0,obInertia(a0)
.return:	rts
; End of function BonusPlayer_MoveRight

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


BonusPlayer_Jump:
		move.b	(v_jpadpresslogical).w,d0
		andi.b	#btnABC,d0		; is A, B or C pressed?
		beq.s	BonusPlayer_MoveRight.return	; if not, branch
		move.b	(v_ssangle).l,d0
		neg.b	d0
		subi.b	#$40,d0
		jsr	(CalcSine).l
		muls.w	#$680,d1
		asr.l	#8,d1
		move.w	d1,obVelX(a0)
		muls.w	#$680,d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)
		bset	#1,obStatus(a0)
		bset	#7,obStatus(a0)		; set "Sonic has jumped" flag
		move.w	#sfx_Jump,d0
		jmp	(PlaySound_Special).l	; play jumping sound
; End of function BonusPlayer_Jump

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to limit Sonic's upward vertical speed
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

BonusPlayer_JumpHeight:
		move.b	(v_jpadholdlogical).w,d0	; is the jump button up?
		andi.b	#btnABC,d0
		bne.s	.return			; if not, branch to return
		btst	#7,obStatus(a0)		; did Sonic jump or is he just falling or hit by a bumper?
		beq.s	.return			; if not, branch to return
		move.b	(v_ssangle).l,d0	; get SS angle
		neg.b	d0
		subi.b	#$40,d0
		jsr	(CalcSine).l
		move.w	obVelY(a0),d2		; get Y speed
		muls.w	d2,d0			; multiply Y speed by sin
		asr.l	#8,d0			; find the new Y speed
		move.w	obVelX(a0),d2		; get X speed
		muls.w	d2,d1			; multiply X speed by cos
		asr.l	#8,d1			; find the new X speed
		add.w	d0,d1			; combine the two speeds
		cmpi.w	#$400,d1		; compare the combined speed with the jump release speed
		ble.s	.return			; if it's less, branch to return
		move.b	(v_ssangle).l,d0
		neg.b	d0
		subi.b	#$40,d0
		jsr	(CalcSine).l
		muls.w	#$400,d1
		asr.l	#8,d1
		move.w	d1,obVelX(a0)
		muls.w	#$400,d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)		; set the speed to the jump release speed
		bclr	#7,obStatus(a0)		; clear "Sonic has jumped" flag

.return:
		rts
; ---------------------------------------------------------------------------
; Subroutine to	fix the	camera on Sonic's position (special stage)
; ---------------------------------------------------------------------------

S1SS_FixCamera:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		move.w	(Camera_X_pos).w,d0
		subi.w	#160,d3
		bcs.s	.ignore_x		; branch if Sonic is within 160px of left edge
		sub.w	d3,d0
		sub.w	d0,(Camera_X_pos).w	; fix camera 160px (half screen) left of Sonic

.ignore_x:
		move.w	(Camera_Y_pos).w,d0
		subi.w	#112,d2
		bcs.s	.ignore_y		; branch if Sonic is within 112px of top edge
		sub.w	d2,d0
		sub.w	d0,(Camera_Y_pos).w	; fix camera 112px (half screen) above Sonic

.ignore_y:
		move.w	(Camera_X_pos).w,(Camera_X_pos_copy).w
		move.w	(Camera_Y_pos).w,(Camera_Y_pos_copy).w
		rts
; End of function S1SS_FixCamera

; ===========================================================================

BonusPlayer_ExitStage:
		addi.w	#$40,(v_ssrotate).l		; increase stage rotation
		cmpi.w	#$1800,(v_ssrotate).l		; check if it's up to $1800
		blt.s	.not1800			; if not, branch
		move.w	#Level,(v_gamemode).w

.not1800:
		move.w	(v_ssangle).l,d0
		add.w	(v_ssrotate).l,d0
		move.w	d0,(v_ssangle).l
		jsr	(Sonic_Animate).l
		jsr	(LoadSonicDynPLC).l
		bsr.s	S1SS_FixCamera
		jmp	(DisplaySprite).l
; ===========================================================================

BonusPlayer_Fall:
		move.l	obY(a0),d2
		move.l	obX(a0),d3
		move.b	(v_ssangle).l,d0
		jsr	(CalcSine).l
		move.w	obVelX(a0),d4
		ext.l	d4
		asl.l	#8,d4
		muls.w	#$2A,d0
		add.l	d4,d0
		move.w	obVelY(a0),d4
		ext.l	d4
		asl.l	#8,d4
		muls.w	#$2A,d1
		add.l	d4,d1
		add.l	d0,d3
		bsr.w	SSS_FindWall
		beq.s	SSS_Fall_NoWall
		sub.l	d0,d3
		moveq	#0,d0
		move.w	d0,obVelX(a0)
		bclr	#1,obStatus(a0)
		add.l	d1,d2
		bsr.w	SSS_FindWall
		beq.s	SSS_Fall_NoFloor
		sub.l	d1,d2
		moveq	#0,d1
		move.w	d1,obVelY(a0)
		rts
; ===========================================================================

SSS_Fall_NoWall:
		add.l	d1,d2
		bsr.w	SSS_FindWall
		beq.s	SSS_Fall_Air
		sub.l	d1,d2
		moveq	#0,d1
		move.w	d1,obVelY(a0)
		bclr	#1,obStatus(a0)

SSS_Fall_NoFloor:
		asr.l	#8,d0
		asr.l	#8,d1
		move.w	d0,obVelX(a0)
		move.w	d1,obVelY(a0)
		rts
; ===========================================================================

SSS_Fall_Air:
		asr.l	#8,d0
		asr.l	#8,d1
		move.w	d0,obVelX(a0)
		move.w	d1,obVelY(a0)
		bset	#1,obStatus(a0)
		rts
; End of function BonusPlayer_Fall

; ---------------------------------------------------------------------------
; Subroutine to detect a wall at a given position

; input:
;	d2 = y position (including subpixel)
;	d3 = x position (including subpixel)

; output:
;	d4 = id of wall or item
;	d5 = flag: 0 = no collision (e.g. rings); -1 = collision with solid wall
; ---------------------------------------------------------------------------

SSS_FindWall:
		lea	(v_ssbuffer1).l,a1
		moveq	#0,d4
		swap	d2
		move.w	d2,d4
		swap	d2
		addi.w	#$44,d4
		divu.w	#$18,d4
		lsl.w	#7,d4				; multiply by width of level ($80)
		ext.l	d4
	;	mulu.w	#$80,d4
		adda.l	d4,a1
		moveq	#0,d4
		swap	d3
		move.w	d3,d4
		swap	d3
		addi.w	#$14,d4
		divu.w	#$18,d4
		adda.w	d4,a1
		moveq	#0,d5
		move.b	(a1)+,d4
		bsr.s	SSS_FindWall_Chk
		move.b	(a1)+,d4
		bsr.s	SSS_FindWall_Chk
		adda.w	#$7E,a1
		move.b	(a1)+,d4
		bsr.s	SSS_FindWall_Chk
		move.b	(a1)+,d4
		bsr.s	SSS_FindWall_Chk
		tst.b	d5
		rts
; End of function SSS_FindWall


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


SSS_FindWall_Chk:
		beq.s	.no_collide		; branch if 0
		cmpi.b	#$28,d4			; is the item an extra life?
		beq.s	.no_collide		; if yes, branch
		cmpi.b	#$3A,d4			; is the item an emerald or ghost block ($3B+)?
		bcs.s	.collide		; if yes, branch
		cmpi.b	#$4B,d4			; is the item a flashing glass block ($4B+)?
		bcc.s	.collide		; if not, branch

.no_collide:
		rts
; ===========================================================================

.collide:
		move.b	d4,ost_ss_item(a0)
		move.l	a1,ost_ss_item_address(a0)
		moveq	#-1,d5
		rts

; ---------------------------------------------------------------------------
; Subroutine to check for collision with rings/1UPs/emerald/ghost blocks

; output:
;	d4 = -1 if item is a ghost block; 0 otherwise
; ---------------------------------------------------------------------------

SSS_ChkItems:
		lea	(v_ssbuffer1).l,a1		; get layout address
		moveq	#0,d4
		move.w	obY(a0),d4			; d4 = Sonic's y pos
		addi.w	#$50,d4
		divu.w	#$18,d4				; divide by height of SS blocks (24 pixels)
		lsl.w	#7,d4				; multiply by width of level ($80)
		ext.l	d4
	;	mulu.w	#$80,d4				; multiply by bytes per SS row ($80)
		adda.l	d4,a1				; jump to row in layout
		moveq	#0,d4
		move.w	obX(a0),d4			; d4 = Sonic's x pos
		addi.w	#$20,d4
		divu.w	#$18,d4				; divide by width of SS blocks (24 pixels)
		adda.w	d4,a1				; jump to exact position in layout
		move.b	(a1),d4				; get id of wall/item
		bne.s	SSS_ChkRing			; branch if not 0
		tst.b	ost_ss_ghost(a0)		; check ghost block status
		bne.w	SSS_MakeGhostSolid		; branch if passed/solid
		moveq	#0,d4
		rts
; ===========================================================================

SSS_ChkRing:
		cmpi.b	#$3A,d4			; is the item a	ring?
		bne.s	SSS_Chk1Up		; if not, branch
		bsr.w	SS_RemoveCollectedItem	; find free item update slot
		bne.s	.noslot
		move.b	#1,(a2)			; item sparkles and vanishes
		move.l	a1,4(a2)		; address within layout to be updated

.noslot:
		jsr	(CollectRing).l		; get a ring
		cmpi.w	#50,(v_rings).w		; check if you have 50 rings
		bcs.s	.nocontinue		; if not, branch
		bset	#0,(v_lifecount).w	; set flag
		bne.s	.nocontinue		; branch if flag was already set
		addq.b	#1,(v_continues).w	; add 1 to the number of continues
		move.w	#sfx_Continue,d0
		jsr	(PlaySound).l		; play extra continue sound

.nocontinue:
		moveq	#0,d4
		rts
; ===========================================================================

SSS_Chk1Up:
		cmpi.b	#$28,d4			; is the item an extra life?
		bne.s	SSS_ChkEmerald
		bsr.w	SS_RemoveCollectedItem
		bne.s	.noslot
		move.b	#3,(a2)
		move.l	a1,4(a2)

.noslot:
		addq.b	#1,(v_lives).w		; add 1 to number of lives
		addq.b	#1,(f_lifecount).w	; update the lives counter
		moveq	#0,d4
		move.w	#bgm_ExtraLife,d0
		jmp	(PlaySound).l		; play extra life music
; ===========================================================================

SSS_ChkEmerald:
		cmpi.b	#$3B,d4			; is the item an emerald? (Emerald 1)
		bcs.s	SSS_ChkGhost
		cmpi.b	#$40,d4			; is the item an emerald? (Emerald 6)
		bhi.s	SSS_ChkGhost
		bsr.w	SS_RemoveCollectedItem
		bne.s	.noslot
		move.b	#5,(a2)
		move.l	a1,4(a2)

.noslot:
		cmpi.b	#6,(v_emeralds).w	; do you have all the emeralds?
		beq.s	.noemerald		; if yes, branch
		subi.b	#$3B,d4			; Emerald 1
		moveq	#0,d0
		move.b	(v_emeralds).w,d0
		lea	(v_emldlist).w,a2
		move.b	d4,(a2,d0.w)
		addq.b	#1,(v_emeralds).w	; add 1 to number of emeralds

.noemerald:
		moveq	#0,d4
		move.w	#bgm_Emerald,d0
		jmp	(PlaySound_Special).l	; play emerald music
; ===========================================================================

SSS_ChkGhost:
		cmpi.b	#$41,d4			; is the item a ghost block?
		bne.s	SSS_ChkGhostTag		; if not, branch
		move.b	#1,ost_ss_ghost(a0)	; mark the ghost block as "passed"

SSS_ChkGhostTag:
		cmpi.b	#$4A,d4			; is the item a switch for ghost blocks?
		bne.s	.noghost		; if not, branch
		cmpi.b	#1,ost_ss_ghost(a0)	; have the ghost blocks been passed?
		bne.s	.noghost		; if not, branch
		move.b	#2,ost_ss_ghost(a0)	; mark the ghost blocks as "solid"

.noghost:
		moveq	#-1,d4
		rts
; ===========================================================================

SSS_MakeGhostSolid:
		cmpi.b	#2,ost_ss_ghost(a0)	; is the ghost marked as "solid"?
		bne.s	.notsolid		; if not, branch
		lea	(v_ssblockbuffer).l,a1	; get layout address (blocks before $1020 are blank)
		moveq	#(v_ssblockbuffer_end-v_ssblockbuffer)/$80-1,d1	; $40

.looprow:
		moveq	#(v_ssblockbuffer_end-v_ssblockbuffer)/$80-1,d2	; $40

.loopitem:
		cmpi.b	#$41,(a1)		; is the item a ghost block?
		bne.s	.noreplace		; if not, branch
		move.b	#$2C,(a1)		; replace ghost block with a solid block

.noreplace:
		addq.w	#1,a1			; next block
		dbf	d2,.loopitem
		lea	$40(a1),a1		; jump to next row (i.e. skip $40 bytes of padding)
		dbf	d1,.looprow

.notsolid:
		clr.b	ost_ss_ghost(a0)
		moveq	#0,d4
		rts

; ---------------------------------------------------------------------------
; Subroutine to check for collision with bumper/GOAL/UP/DOWN/R/glass blocks
; ---------------------------------------------------------------------------

SSS_ChkItems2:
		move.b	ost_ss_item(a0),d0		; get item id
		bne.s	SSS_ChkBumper			; branch if not 0
		subq.b	#1,ost_ss_updown_time(a0)	; decrement UP/DOWN cooldown timer
		bpl.s	.updown_off			; branch if positive
		sf.b	ost_ss_updown_time(a0)		; set to 0

.updown_off:
		subq.b	#1,ost_ss_r_time(a0)		; decrement R cooldown timer
		bpl.s	.r_off				; branch if positive
		sf.b	ost_ss_r_time(a0)		; set to 0

.r_off:
		rts
; ===========================================================================

SSS_ChkBumper:
		cmpi.b	#$25,d0			; is the item a bumper?
		bne.s	SSS_GOAL	; if not, branch
		move.l	ost_ss_item_address(a0),d1	; get address of bumper within layout
		subi.l	#v_ssbuffer1+1,d1
		move.w	d1,d2
		andi.w	#$7F,d1
		mulu.w	#$18,d1
		subi.w	#$14,d1			; d1 = x position of bumper
		lsr.w	#7,d2
		andi.w	#$7F,d2
		mulu.w	#$18,d2
		subi.w	#$44,d2			; d2 = y position of bumper
		sub.w	obX(a0),d1
		sub.w	obY(a0),d2
		jsr	(CalcAngle).l
		jsr	(CalcSine).l
		muls.w	#-$700,d1
		asr.l	#8,d1
		move.w	d1,obVelX(a0)		; bounce Sonic away from bumper
		muls.w	#-$700,d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)
		bset	#1,obStatus(a0)		; set Sonic's air flag
		bclr	#7,obStatus(a0)		; clear "Sonic has jumped" flag
		bsr.w	SS_RemoveCollectedItem
		bne.s	.noslot
		move.b	#2,(a2)			; set update type
		move.l	ost_ss_item_address(a0),d0
		subq.l	#1,d0
		move.l	d0,4(a2)		; set address within layout to update

.noslot:
		move.w	#sfx_Bumper,d0
		jmp	(PlaySound_Special).l	; play bumper sound
; ===========================================================================

SSS_GOAL:
		cmpi.b	#$27,d0			; is the item a "GOAL"?
		bne.s	SSS_UPblock		; if not, branch
		addq.b	#2,obRoutine(a0)	; run routine "BonusPlayer_ExitStage"
		move.w	#sfx_SSGoal,d0
		jmp	(PlaySound_Special).l	; play "GOAL" sound
; ===========================================================================

SSS_UPblock:
		cmpi.b	#$29,d0			; is the item an "UP" block?
		bne.s	SSS_DOWNblock		; if not, branch
		tst.b	ost_ss_updown_time(a0)	; check UP/DOWN cooldown
		bne.w	SSS_ChkItems_End	; branch if time remains
		move.b	#30,ost_ss_updown_time(a0)	; set cooldown to half a second
		btst	#6,(v_ssrotate+1).l	; is SS rotation speed $40? (minimum)
		beq.s	.keepspeed		; if not, branch
		asl	(v_ssrotate).l		; increase stage rotation speed
		movea.l	ost_ss_item_address(a0),a1
		subq.l	#1,a1
		move.b	#$2A,(a1)		; change item to a "DOWN" block

.keepspeed:
		move.w	#sfx_SSItem,d0
		jmp	(PlaySound_Special).l	; play up/down sound
; ===========================================================================

SSS_DOWNblock:
		cmpi.b	#$2A,d0			; is the item a "DOWN" block?
		bne.s	SSS_Rblock		; if not, branch
		tst.b	ost_ss_updown_time(a0)	; check UP/DOWN cooldown
		bne.w	SSS_ChkItems_End
		move.b	#30,ost_ss_updown_time(a0)
		btst	#6,(v_ssrotate+1).l	; is SS rotation speed $40? (minimum)
		bne.s	.keepspeed		; if so, branch
		asr	(v_ssrotate).l		; reduce stage rotation speed
		movea.l	ost_ss_item_address(a0),a1
		subq.l	#1,a1
		move.b	#$29,(a1)		; change item to an "UP" block

.keepspeed:
		move.w	#sfx_SSItem,d0
		jmp	(PlaySound_Special).l	; play up/down sound
; ===========================================================================

SSS_Rblock:
		cmpi.b	#$2B,d0			; is the item an "R" block?
		bne.s	SSS_ChkGlass		; if not, branch
		tst.b	ost_ss_r_time(a0)	; check R cooldown
		bne.w	SSS_ChkItems_End
		move.b	#30,ost_ss_r_time(a0)
		bsr.w	SS_RemoveCollectedItem	; find free item update slot
		bne.s	.noslot			; branch if not found
		move.b	#4,(a2)
		move.l	ost_ss_item_address(a0),d0
		subq.l	#1,d0
		move.l	d0,4(a2)

.noslot:
		neg.w	(v_ssrotate).l		; reverse stage rotation
		move.w	#sfx_SSItem,d0
		jmp	(PlaySound_Special).l	; play sound
; ===========================================================================

SSS_ChkGlass:
		cmpi.b	#$2D,d0			; is the item a glass block?
		beq.s	.glass			; if yes, branch
		cmpi.b	#$2E,d0
		beq.s	.glass
		cmpi.b	#$2F,d0
		beq.s	.glass
		cmpi.b	#$30,d0
		bne.s	SSS_ChkItems_End	; if not, branch

.glass:
		bsr.w	SS_RemoveCollectedItem
		bne.s	.noslot
		move.b	#6,(a2)
		movea.l	ost_ss_item_address(a0),a1
		subq.l	#1,a1
		move.l	a1,4(a2)
		move.b	(a1),d0
		addq.b	#1,d0			; change glass type when touched
		cmpi.b	#$30,d0
		bls.s	.update			; if glass is still there, branch
		clr.b	d0			; remove the glass block when it's destroyed

.update:
		move.b	d0,4(a2)		; update the stage layout

.noslot:
		move.w	#sfx_SSGlass,d0
		jmp	(PlaySound_Special).l	; play glass block sound
; ===========================================================================

SSS_ChkItems_End:
		rts
; End of function SSS_ChkItems2