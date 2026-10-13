; ===========================================================================
; ---------------------------------------------------------------------------
; Object 01 - Sonic
; Normal-player behavior follows S3&K, adapted to this engine's SST and art.
; Keep the custom homing hook and unrestricted rolling-jump air control.
; ---------------------------------------------------------------------------

Obj01:
		tst.w	(Debug_placement_mode).w	; is debug mode being used?
		beq.s	Obj01_Normal			; if not, branch
		jmp	(DebugMode).l
; ===========================================================================

Obj01_Normal:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj01_Index(pc,d0.w),d1
		jmp	Obj01_Index(pc,d1.w)
; ===========================================================================
Obj01_Index:
		dc.w Obj01_Init-Obj01_Index		; 0
		dc.w Obj01_Control-Obj01_Index		; 2
		dc.w Obj01_Hurt-Obj01_Index		; 4
		dc.w Obj01_Dead-Obj01_Index		; 6
		dc.w Obj01_ResetLevel-Obj01_Index	; 8
; ===========================================================================
; Obj01_Main:
Obj01_Init:
		addq.b	#2,obRoutine(a0)		; => Obj01_Control
		move.b	#sonic_height,obHeight(a0)
		move.b	#sonic_width,obWidth(a0)
		move.b	#sonic_height,default_y_radius(a0)
		move.b	#sonic_width,default_x_radius(a0)
		move.l	#Map_Sonic,obMap(a0)
		move.b	#Map_Sonic_height,height_pixels(a0)
		move.w	#$100,obPriority(a0)
		move.b	#sprite_bound($18,Map_Sonic_width),obActWid(a0)
		move.b	#4,obRender(a0)
		move.w	#Player_DefaultTopSpeed,(Sonic_top_speed).w
		move.w	#Player_DefaultAcceleration,(Sonic_acceleration).w
		move.w	#Player_DefaultDeceleration,(Sonic_deceleration).w
		tst.b	(v_lastlamp).w
		bne.s	Obj01_Init_Continued
		; only happens when not starting at a checkpoint:
		move.w	#make_art_tile(ArtTile_Sonic,0,0),obGfx(a0)
		move.b	#$C,obTopSolidBit(a0)
		move.b	#$D,obLRBSolidBit(a0)
		move.w	obX(a0),(v_lamp_xpos).w
		move.w	obY(a0),(v_lamp_ypos).w
		move.w	obGfx(a0),(v_lamp_mainchar).w
		move.w	obTopSolidBit(a0),(v_lamp_solid).w

Obj01_Init_Continued:
		clr.b	character_id(a0)
		bsr.w	CreatePlayerDust
		clr.b	flips_remaining(a0)
		move.b	#4,flip_speed(a0)		; flip_speed
		clr.b	(Super_Sonic_flag).w
		move.w	#30,(v_air).w			; v_air(a0)
		subi.w	#$20,obX(a0)
		addq.w	#4,obY(a0)
		bsr.w	Sonic_ResetPositionHistory
		addi.w	#$20,obX(a0)
		subq.w	#4,obY(a0)

; ---------------------------------------------------------------------------
; Normal state for Sonic
; ---------------------------------------------------------------------------

Obj01_Control:
		tst.b	(Debug_mode_flag).w		; is debug cheat enabled?
		beq.s	loc_FAB0			; if not, branch
		btst	#bitB,(v_jpadpress1).w		; is button B pressed?
		beq.s	loc_FAB0			; if not, branch
		jmp	(Debug_Begin).l		; C held selects S3&K frame cycling
; -----------------------------------------------------------------------
loc_FAB0:
		tst.b	(f_lockctrl).w			; are controls locked?
		bne.s	loc_FABC			; if yes, branch
		move.w	(v_jpadhold1).w,(v_jpadholdlogical).w	; copy new held buttons, to enable joypad

loc_FABC:
		btst	#0,obControl(a0)
		bne.s	Obj01_ControlsLock
		btst	#0,(f_playerctrl).w		; is Sonic interacting with another object that holds him in place or controls his movement somehow?
		bne.s	Obj01_ControlsLock		; if yes, branch to skip Sonic's control
		moveq	#0,d0
		move.b	obStatus(a0),d0
		andi.w	#6,d0
		move.w	Obj01_Modes(pc,d0.w),d1
		jsr	Obj01_Modes(pc,d1.w)		; run Sonic's movement control code

Obj01_ControlsLock:
		tst.w	(Camera_Min_Y_pos).w
		bpl.s	.no_wrap
		andi.w	#Level_YWrapMask,obY(a0)
.no_wrap:
		bsr.s	Sonic_Display
		bsr.w	Sonic_RecordPos
		bsr.w	Sonic_Water
		move.b	(Primary_Angle).w,next_tilt(a0)
		move.b	(Secondary_Angle).w,tilt(a0)
		tst.b	(f_wtunnelmode).w
		beq.s	loc_FAFE
		tst.b	obAnim(a0)
		bne.s	loc_FAFE
		move.b	obPrevAni(a0),obAnim(a0)

loc_FAFE:
		btst	#1,obControl(a0)
		bne.s	.carried
		bsr.w	Sonic_Animate
		tst.b	(f_playerctrl).w
		bmi.w	LoadSonicDynPLC
		jsr	(TouchResponse).l
		bra.w	LoadSonicDynPLC
.carried:
		jmp	(TouchResponse).l

; ===========================================================================
; secondary states under state Obj01_Control
Obj01_Modes:	dc.w Obj01_MdNormal_Checks-Obj01_Modes
		dc.w Obj01_MdAir-Obj01_Modes
		dc.w Obj01_MdRoll-Obj01_Modes
		dc.w Obj01_MdJump-Obj01_Modes
; ===========================================================================
; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Sonic_Display:
		move.w	flashtime(a0),d0
		beq.s	Obj01_Display
		subq.w	#1,flashtime(a0)
		lsr.w	#3,d0
		bhs.s	Obj01_Display.effects
; loc_FB2E:
Obj01_Display:
		jsr	(DisplaySprite).l
.effects:				; flashing skips drawing, but both timers still tick
		bsr.s	Player_ChkInvincibility
		bra.w	Player_ChkSpeedShoes
; ---------------------------------------------------------------------------
; End of function Sonic_Display


; ---------------------------------------------------------------------------
; Shared per-player invincibility timer. Keep the music while either player
; remains invincible. Each player owns their status bits and timers.
; ---------------------------------------------------------------------------
Player_ChkInvincibility:
		btst	#obStatusSecondary_isInvincible,obStatusSecondary(a0)
		beq.w	Player_ChkSpeedShoes.return
		tst.w	invtime(a0)
		beq.w	Player_ChkSpeedShoes.return
		subq.w	#1,invtime(a0)
		bne.w	Player_ChkSpeedShoes.return
		bclr	#obStatusSecondary_isInvincible,obStatusSecondary(a0)
		move.b	(v_player+obStatusSecondary).w,d0
		or.b	(v_player2+obStatusSecondary).w,d0
		btst	#obStatusSecondary_isInvincible,d0
		bne.s	Player_ChkSpeedShoes.return
		tst.b	(Super_Sonic_flag).w
		bne.s	Player_ChkSpeedShoes.return
		tst.b	(f_lockscreen).w
		bne.s	Player_ChkSpeedShoes.return
		cmpi.w	#12,(v_air).w
		bls.s	Player_ChkSpeedShoes.return
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		lea	(MusicList).l,a1
		move.b	(a1,d0.w),d0
		jmp	(PlayMusic).l

; ---------------------------------------------------------------------------
; Per-player speed-shoe timer. Restore this player's movement stats first;
; slow the shared music only after neither player has speed shoes left.
; ---------------------------------------------------------------------------
Player_ChkSpeedShoes:
		btst	#obStatusSecondary_hasSpeedShoes,obStatusSecondary(a0)
		beq.s	.return
		tst.w	shoetime(a0)
		beq.s	.return
		subq.w	#1,shoetime(a0)
		bne.s	.return
		bclr	#obStatusSecondary_hasSpeedShoes,obStatusSecondary(a0)
		beq.s	.return
		clr.w	shoetime(a0)
		movem.l	a2-a3,-(sp)
		movea.l	a0,a2
		bsr.w	Player_UpdateSpeed
		movem.l	(sp)+,a2-a3
		move.b	(v_player+obStatusSecondary).w,d0
		or.b	(v_player2+obStatusSecondary).w,d0
		btst	#obStatusSecondary_hasSpeedShoes,d0
		bne.s	.return
		moveq	#0,d0
		jmp	(ChangeMusicTempo).l
.return:
		rts

; ---------------------------------------------------------------------------
; Clear only this player's effects on death or when leaving the level.
; Clear the adjacent invtime/shoetime words, then end speed shoes below.
; ---------------------------------------------------------------------------
Player_ClearPowerUps:
		bclr	#obStatusSecondary_hasShield,obStatusSecondary(a0)
		bclr	#obStatusSecondary_isInvincible,obStatusSecondary(a0)
		clr.l	invtime(a0)
; ---------------------------------------------------------------------------
; End this player's speed shoes and restore their movement stats. Retain
; the faster shared music while their partner still has speed shoes.
; ---------------------------------------------------------------------------
		bclr	#obStatusSecondary_hasSpeedShoes,obStatusSecondary(a0)
		beq.s	Player_ChkSpeedShoes.return
		clr.w	shoetime(a0)
		movem.l	a2-a3,-(sp)
		movea.l	a0,a2
		bsr.w	Player_UpdateSpeed
		movem.l	(sp)+,a2-a3
		move.b	(v_player+obStatusSecondary).w,d0
		or.b	(v_player2+obStatusSecondary).w,d0
		btst	#obStatusSecondary_hasSpeedShoes,d0
		bne.s	Player_ChkSpeedShoes.return
		moveq	#0,d0
		jmp	(ChangeMusicTempo).l

; ---------------------------------------------------------------------------
; a2 is the player. Select the movement bank actually used by that
; character, including Tails in the main slot, and respect water status.
; ---------------------------------------------------------------------------
Player_UpdateSpeed:
		lea	(Sonic_top_speed).w,a3
		cmpa.w	#v_player,a2
		bne.s	.tails
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.stats_ready
.tails:
		lea	(Tails_top_speed).w,a3
.stats_ready:
		move.w	#Player_DefaultTopSpeed,(a3)
		move.w	#Player_DefaultAcceleration,PlayerSpeed_AccelerationOffset(a3)
		move.w	#Player_DefaultDeceleration,PlayerSpeed_DecelerationOffset(a3)
		btst	#obStatusSecondary_hasSpeedShoes,obStatusSecondary(a2)
		beq.s	.water
		move.w	#Player_ShoesTopSpeed,(a3)
		move.w	#Player_ShoesAcceleration,PlayerSpeed_AccelerationOffset(a3)
.water:
		btst	#status.player.underwater,obStatus(a2)
		beq.s	.return
		lsr.w	(a3)
		lsr.w	PlayerSpeed_AccelerationOffset(a3)
		lsr.w	PlayerSpeed_DecelerationOffset(a3)
.return:
		rts

; ---------------------------------------------------------------------------
; Subroutine to record Sonic's previous positions for invincibility stars
; and input/status flags for Tails' AI to follow
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_FBB2: CopySonicMovesForTails:
; S3&K initializes the complete position and input history directly.
; Keep writes inside the two buffers; RecordPos advances a1 and the index.
Sonic_ResetPositionHistory:
		lea	(Sonic_Pos_Record_Buf).w,a1
		lea	(Sonic_Stat_Record_Buf).w,a2
		move.w	#bytesToLcnt(Sonic_Pos_Record_Buf_End-Sonic_Pos_Record_Buf),d0
.loop:
		move.w	obX(a0),(a1)+
		move.w	obY(a0),(a1)+
		clr.l	(a2)+
		dbf	d0,.loop
		clr.w	(Sonic_Pos_Record_Index).w
		rts

Sonic_RecordPos:
		cmpa.w	#v_player,a0
		bne.s	.return
		move.w	(Sonic_Pos_Record_Index).w,d0
		lea	(Sonic_Pos_Record_Buf).w,a1
		lea	(a1,d0.w),a1
		move.w	obX(a0),(a1)+
		move.w	obY(a0),(a1)+
		addq.b	#4,(Sonic_Pos_Record_Index+1).w
		lea	(Sonic_Stat_Record_Buf).w,a1
		lea	(a1,d0.w),a1
		move.w	(v_jpadholdlogical).w,(a1)+
		move.b	obStatus(a0),(a1)+
		move.b	obGfx(a0),(a1)+
.return:	rts
; End of function Sonic_RecordPos

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine for Sonic when he's underwater
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_FC06:
Sonic_Water:
		tst.b	(Water_flag).w
		beq.s	Sonic_RecordPos.return
		move.w	(v_waterpos1).w,d0
		cmp.w	obY(a0),d0			; is Sonic above water?
		bge.s	Obj01_OutWater			; if yes, branch

		bset	#status.player.underwater,obStatus(a0)
		bne.s	Sonic_RecordPos.return		; if already underwater, branch

		bsr.w	ResumeMusic
		move.b	#id_Obj0A,(v_sonicbubbles).w		; load Sonic's breathing bubbles
		move.b	#$81,(v_sonicbubbles+obSubtype).w
		movea.l	a0,a2
		bsr.w	Player_UpdateSpeed
		tst.b	obControl(a0)
		bne.s	Sonic_RecordPos.return
		tst.b	(f_playerctrl).w		; leave externally controlled velocity alone
		bne.s	Sonic_RecordPos.return
		asr	obVelX(a0)
		asr	obVelY(a0)			; memory oprands can only be shifted one at a time
		asr	obVelY(a0)
		beq.s	Sonic_RecordPos.return
		jsr	(SpawnPlayerSplash).l		; separate splash owned by this player
		move.w	#sfx_Splash,d0			; splash sound
		jmp	(PlaySound_Special).l
; ---------------------------------------------------------------------------
; Obj01_NotInWater:
Obj01_OutWater:
		bclr	#status.player.underwater,obStatus(a0)
		beq.s	Sonic_RecordPos.return		; if already unset, branch

		bsr.w	ResumeMusic
		movea.l	a0,a2
		bsr.w	Player_UpdateSpeed
		cmpi.b	#4,obRoutine(a0)		; hurt recoil does not receive the exit boost
		beq.s	.checksplash
		tst.b	obControl(a0)
		bne.s	.checksplash
		tst.b	(f_playerctrl).w
		bne.s	.checksplash
		cmpi.w	#-Sonic_JumpReleaseSpeed,obVelY(a0)
		blt.s	.checksplash		; preserve faster springs and launches
		asl	obVelY(a0)
.checksplash:
		cmpi.b	#AniIDSonAni_Blank,obAnim(a0)
		beq.w	Sonic_RecordPos.return
		tst.w	obVelY(a0)
		beq.w	Sonic_RecordPos.return
		jsr	(SpawnPlayerSplash).l		; separate splash owned by this player
		cmpi.w	#-Sonic_WaterExitSpeedLimit,obVelY(a0)
		bgt.s	loc_FC98
		move.w	#-Sonic_WaterExitSpeedLimit,obVelY(a0)

loc_FC98:
		move.w	#sfx_Splash,d0			; splash sound
		jmp	(PlaySound_Special).l
; End of function Sonic_Water

; ===========================================================================
; ---------------------------------------------------------------------------
; Start of subroutine Obj01_MdNormal
; Called if Sonic is neither airborne nor rolling this frame
; ---------------------------------------------------------------------------
; loc_1A26E:
Obj01_MdNormal_Checks:
		; If Sonic has been waiting for a while, and is tapping his foot
		; impatiently, then make him blink once the player starts moving
		; again. Likewise, if he's been waiting for so long that he's laying
		; down, then make him play an animation of standing up.
		move.b	(v_jpadpresslogical).w,d0
		andi.b	#button_B_mask|button_C_mask|button_A_mask,d0
		bne.s	Obj01_MdNormal
		cmpi.b	#AniIDSonAni_Blink,obAnim(a0)
		beq.s	Obj01_MdNormal_Skip
		cmpi.b	#AniIDSonAni_GetUp,obAnim(a0)
		beq.s	Obj01_MdNormal_Skip
		cmpi.b	#AniIDSonAni_Wait,obAnim(a0)
		bne.s	Obj01_MdNormal
		cmpi.b	#$1E,obAniFrame(a0)
		blo.s	Obj01_MdNormal
		move.b	(v_jpadholdlogical).w,d0
		andi.b	#button_up_mask|button_down_mask|button_left_mask|button_right_mask|button_B_mask|button_C_mask|button_A_mask,d0
		beq.s	Obj01_MdNormal_Skip
		move.b	#AniIDSonAni_Blink,obAnim(a0)
		cmpi.b	#$AC,obAniFrame(a0)
		blo.s	Obj01_MdNormal_Skip
		move.b	#AniIDSonAni_GetUp,obAnim(a0)
		bsr.w	Sonic_LevelBound
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		bsr.w	AnglePos
		bra.w	Sonic_SlopeRepel
; ---------------------------------------------------------------------------
; loc_1A2B8:
Obj01_MdNormal:
		bsr.w	Sonic_CheckSpindash
		bsr.w	Sonic_Jump
		bsr.w	Sonic_SlopeResist
		bsr.w	Sonic_Move
		bsr.w	Sonic_Roll
Obj01_MdNormal_Skip:
		bsr.w	Sonic_LevelBound
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		bsr.w	AnglePos
		bra.w	Sonic_SlopeRepel
; End of subroutine Obj01_MdNormal

; ===========================================================================
; Start of subroutine Obj01_MdAir
; Called if Sonic is airborne, but not in a ball (thus, probably not jumping)
; Obj01_MdJump:
Obj01_MdAir:
		bsr.w	Sonic_JumpHeight
		bsr.w	Sonic_JumpDirection
		bsr.w	Sonic_LevelBound
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		btst	#6,obStatus(a0)			; is Sonic underwater?
		beq.s	loc_FCEA			; if not, branch
		subi.w	#$28,obVelY(a0)			; reduce gravity by $28 ($38-$28=$10)

loc_FCEA:
		bsr.w	Sonic_JumpAngle
		bra.w	Sonic_DoLevelCollision
; End of subroutine Obj01_MdAir

; ===========================================================================
; Start of subroutine Obj01_MdRoll
; Called if Sonic is in a ball, but not airborne (thus, probably rolling)

Obj01_MdRoll:
		tst.b	spindash_flag(a0)		; forced rolls stay under their controller
		bne.s	.forcedroll
		bsr.w	Sonic_Jump
.forcedroll:
		bsr.w	Sonic_RollRepel
		bsr.w	Sonic_RollSpeed
		bsr.w	Sonic_LevelBound
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		bsr.w	AnglePos
		bra.w	Sonic_SlopeRepel
; End of subroutine Obj01_MdRoll

; ===========================================================================
; Start of subroutine Obj01_MdJump
; Called if Sonic is in a ball and airborne (he could be jumping but not necessarily)
; Notes: This is identical to Obj01_MdAir, at least at this outer level.
;        Why they gave it a separate copy of the code, I don't know.
; Obj01_MdJump2:
Obj01_MdJump:
		bsr.w	Sonic_HomingAttack
		bsr.w	Sonic_JumpHeight
		bsr.w	Sonic_JumpDirection
		bsr.w	Sonic_LevelBound
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		btst	#6,obStatus(a0)			; is Sonic underwater?
		beq.s	loc_FD34			; if not, branch
		subi.w	#$28,obVelY(a0)			; reduce gravity by $28 ($38-$28=$10)

loc_FD34:
		bsr.w	Sonic_JumpAngle
		bra.w	Sonic_DoLevelCollision
; End of subroutine Obj01_MdJump


; ---------------------------------------------------------------------------
; Subroutine to make Sonic walk/run
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Sonic_Move:
		move.w	(Sonic_top_speed).w,d6
		move.w	(Sonic_acceleration).w,d5
		move.w	(Sonic_deceleration).w,d4
		tst.b	(f_slidemode).w
		bne.w	Sonic_ResetScr_Traction
		btst	#status_secondary.sliding,obStatusSecondary(a0)
		bne.w	Sonic_ResetScr_Traction
		tst.w	move_lock(a0)
		bne.w	Sonic_ResetScr
		btst	#button_left,(v_jpadholdlogical).w
		beq.s	.notleft
		bsr.w	Sonic_MoveLeft
.notleft:
		btst	#button_right,(v_jpadholdlogical).w
		beq.s	.notright
		bsr.w	Sonic_MoveRight
.notright:
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0
		bne.w	Sonic_ResetScr
		tst.w	obInertia(a0)
		bne.w	Sonic_ResetScr
		bclr	#status.player.pushing,obStatus(a0)
		move.b	#AniIDSonAni_Wait,obAnim(a0)
		btst	#status.player.on_object,obStatus(a0)
		beq.w	Sonic_Balance
		moveq	#0,d0
		move.b	standonobject(a0),d0
		mulu.w	#object_size,d0
		lea	(v_player).w,a1
		lea	(a1,d0.w),a1
		tst.b	obStatus(a1)
		bmi.w	Sonic_LookUp
		moveq	#0,d1
		move.b	obActWid(a1),d1
		move.w	d1,d2
		add.w	d2,d2
		subq.w	#2,d2			; S3&K's two-pixel edge margin
		add.w	obX(a0),d1
		sub.w	obX(a1),d1
		cmpi.w	#2,d1
		blt.s	Sonic_BalanceOnObjLeft
		cmp.w	d2,d1
		bge.s	Sonic_BalanceOnObjRight
		bra.w	Sonic_LookUp

; Face the edge; use the second balance animation farther out.
Sonic_BalanceOnObjRight:
		bclr	#status.player.x_flip,obStatus(a0)
		move.b	#AniIDSonAni_Balance,obAnim(a0)
		addq.w	#6,d2
		cmp.w	d2,d1
		blt.w	Sonic_ResetScr
		move.b	#AniIDSonAni_Balance2,obAnim(a0)
		bra.w	Sonic_ResetScr
Sonic_BalanceOnObjLeft:
		bset	#status.player.x_flip,obStatus(a0)
		move.b	#AniIDSonAni_Balance,obAnim(a0)
		cmpi.w	#-4,d1
		bge.w	Sonic_ResetScr
		move.b	#AniIDSonAni_Balance2,obAnim(a0)
		bra.w	Sonic_ResetScr

Sonic_Balance:
		jsr	(ChkFloorEdge).l
		cmpi.w	#$C,d1
		blt.w	Sonic_LookUp
		cmpi.b	#3,next_tilt(a0)
		bne.s	.leftedge
		bclr	#status.player.x_flip,obStatus(a0)
		move.b	#AniIDSonAni_Balance,obAnim(a0)
		move.w	obX(a0),d3
		subq.w	#6,d3
		bra.s	.probe
.leftedge:
		cmpi.b	#3,tilt(a0)
		bne.s	Sonic_LookUp
		bset	#status.player.x_flip,obStatus(a0)
		move.b	#AniIDSonAni_Balance,obAnim(a0)
		move.w	obX(a0),d3
		addq.w	#6,d3
.probe:
		jsr	(ChkFloorEdge_Part2).l
		cmpi.w	#$C,d1
		blt.w	Sonic_ResetScr
		move.b	#AniIDSonAni_Balance2,obAnim(a0)
		bra.w	Sonic_ResetScr

; S3&K checks Down before Up when both buttons are held.
Sonic_LookUp:
Sonic_Duck:
		btst	#button_down,(v_jpadholdlogical).w
		beq.s	.lookup
		move.b	#AniIDSonAni_Duck,obAnim(a0)
		cmpa.w	#v_player,a0
		bne.w	Obj01_UpdateSpeedOnGround
		addq.b	#1,scroll_delay_counter(a0)
		cmpi.b	#Camera_LookDelay,scroll_delay_counter(a0)
		blo.w	Sonic_ResetScr_Part2
		move.b	#Camera_LookDelay,scroll_delay_counter(a0)
		cmpi.w	#Camera_LookDownLimit,(Camera_Y_pos_bias).w
		beq.w	Obj01_UpdateSpeedOnGround
		subq.w	#Camera_LookPanSpeed,(Camera_Y_pos_bias).w
		bra.w	Obj01_UpdateSpeedOnGround
.lookup:
		btst	#button_up,(v_jpadholdlogical).w
		beq.s	Sonic_ResetScr
		move.b	#AniIDSonAni_LookUp,obAnim(a0)
		cmpa.w	#v_player,a0
		bne.s	Obj01_UpdateSpeedOnGround
		addq.b	#1,scroll_delay_counter(a0)
		cmpi.b	#Camera_LookDelay,scroll_delay_counter(a0)
		blo.s	Sonic_ResetScr_Part2
		move.b	#Camera_LookDelay,scroll_delay_counter(a0)
		cmpi.w	#Camera_LookUpLimit,(Camera_Y_pos_bias).w
		beq.s	Obj01_UpdateSpeedOnGround
		addq.w	#Camera_LookPanSpeed,(Camera_Y_pos_bias).w
		bra.s	Obj01_UpdateSpeedOnGround

; Move the screen back to its normal position after looking up or down.
Sonic_ResetScr_Traction:
		bsr.s	Player_ResetScr
		bra.s	Player_Traction
Sonic_ResetScr:
		bsr.s	Player_ResetScr
		bra.s	Obj01_UpdateSpeedOnGround
Sonic_ResetScr_Part2:
		bsr.s	Player_ResetScr_Part2
		bra.s	Obj01_UpdateSpeedOnGround

; Shared by both characters; keep the delay while waiting to start looking.
; No data/address registers are changed. Secondary players cannot change the camera.
Player_ResetScr:
		clr.b	scroll_delay_counter(a0)
; loc_1A5E6:
Player_ResetScr_Part2:
		cmpa.w	#v_player,a0
		bne.s	.return
		cmpi.w	#Camera_LookCenter,(Camera_Y_pos_bias).w
		beq.s	.return					; if yes, branch
		bhs.s	+
		addq.w	#Camera_LookReturnSpeed*2,(Camera_Y_pos_bias).w
+		subq.w	#Camera_LookReturnSpeed,(Camera_Y_pos_bias).w	; net step toward the default
.return:	rts

; ---------------------------------------------------------------------------
; updates Sonic's speed on the ground
; ---------------------------------------------------------------------------
; loc_FE2C:
Obj01_UpdateSpeedOnGround:
		move.b	(v_jpadholdlogical).w,d0
		andi.b	#btnL|btnR,d0	; is left/right being pressed?
		bne.s	Player_Traction			; if yes, branch
		move.w	obInertia(a0),d0
		beq.s	Player_Traction
		bmi.s	Player_SettleLeft

; slow down when facing right and not pressing a direction
; Obj01_SettleRight:
		sub.w	d5,d0
		bhs.s	loc_FE46
		clr.w	d0

loc_FE46:
		move.w	d0,obInertia(a0)
		bra.s	Player_Traction
; ---------------------------------------------------------------------------
; slow down when facing left and not pressing a direction
; loc_FE4C:
Player_SettleLeft:
		add.w	d5,d0
		bhs.s	+
		clr.w	d0
+
		move.w	d0,obInertia(a0)

; increase or decrease speed on the ground
; loc_FE58:
Player_Traction:
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		move.w	d1,obVelX(a0)
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)

; stops Sonic from running through walls that meet the ground
; loc_FE76:
Player_CheckWallsOnGround:
		btst	#PlayerControl_SkipWallCollision,obControl(a0)
		bne.s	.return
		btst	#PlayerControl_SkipWallCollision,(f_playerctrl).w
		bne.s	.return
		move.b	obAngle(a0),d0
		andi.b	#$3F,d0
		beq.s	.probe			; S3&K also checks the four cardinal surfaces
		move.b	obAngle(a0),d0
		addi.b	#$40,d0
		bmi.s	.return
.probe:
		move.b	#$40,d1				; rotate 90 degress clockwise
		tst.w	obInertia(a0)			; check if Sonic's moving
		beq.s	.return			; If not moving, don't do anything
		bmi.s	+			; if negative, branch
		neg.w	d1				; rotate counterclockwise
+
		move.b	obAngle(a0),d0
		add.b	d1,d0
		move.w	d0,-(sp)
		bsr.w	CalcRoomInFront
		move.w	(sp)+,d0
		tst.w	d1
		bpl.s	.return
		asl.w	#8,d1
		addi.b	#$20,d0
		andi.b	#$C0,d0
		beq.s	loc_FEF2
		cmpi.b	#$40,d0
		beq.s	loc_FED8
		cmpi.b	#$80,d0
		beq.s	loc_FED2
		add.w	d1,obVelX(a0)
		bset	#status.player.pushing,obStatus(a0)
		clr.w	obInertia(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_FED2:
		sub.w	d1,obVelY(a0)
		rts
; ---------------------------------------------------------------------------

loc_FED8:
		sub.w	d1,obVelX(a0)
		bset	#status.player.pushing,obStatus(a0)
		clr.w	obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_FEF2:
		add.w	d1,obVelY(a0)
		rts
; End of function Sonic_Move


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Sonic_MoveLeft:
		move.w	obInertia(a0),d0
		beq.s	+
		bpl.s	Sonic_TurnLeft ; if Sonic is already moving to the right, branch
+
		bset	#0,obStatus(a0)
		bne.s	+
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)	; force walking animation to restart if it's already in-progress
+
		sub.w	d5,d0	; add acceleration to the left
		move.w	d6,d1
		neg.w	d1
		cmp.w	d1,d0	; compare new speed with top speed
		bgt.s	+	; if new speed is less than the maximum, branch
		add.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d1,d0	; compare speed with top speed
		ble.s	+	; if speed was already greater than the maximum, branch
		move.w	d1,d0	; limit speed on ground going left
+
		move.w	d0,obInertia(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
.return:	rts
; ---------------------------------------------------------------------------
; loc_FF70:
Sonic_TurnLeft:
		sub.w	d4,d0
		bhs.s	+
		move.w	#-$80,d0
+
		move.w	d0,obInertia(a0)
		move.b	obAngle(a0),d1
		addi.b	#$20,d1
		andi.b	#$C0,d1
		bne.s	Sonic_MoveLeft.return
		cmpi.w	#$400,d0
		blt.s	Sonic_MoveLeft.return
		move.b	#AniIDSonAni_Stop,obAnim(a0)
		bclr	#0,obStatus(a0)
		move.w	#sfx_Skid,d0
		jmp	(PlaySound_Special).l
		; TODO: Uncomment and implement these lines. When that time comes, the jmp will change, too.
	;	cmpi.b	#12,air_left(a0)
	;	blo.s	Sonic_MoveLeft.return	; if he's drowning, branch to not make dust
	;	move.b	#6,(Sonic_Dust+routine).w
	;	move.b	#$15,(Sonic_Dust+mapping_frame).w
; End of function Sonic_MoveLeft


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Sonic_MoveRight:
		move.w	obInertia(a0),d0
		bmi.s	Sonic_TurnRight
		bclr	#0,obStatus(a0)
		beq.s	+
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
+
		add.w	d5,d0	; add acceleration to the right
		cmp.w	d6,d0	; compare new speed with top speed
		blt.s	+	; if new speed is less than the maximum, branch
		sub.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d6,d0	; compare speed with top speed
		bge.s	+	; if speed was already greater than the maximum, branch
		move.w	d6,d0	; limit speed on ground going right
+
		move.w	d0,obInertia(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
.return:	rts
; ---------------------------------------------------------------------------
; loc_FFD6:
Sonic_TurnRight:
		add.w	d4,d0
		bhs.s	loc_FFDE
		move.w	#$80,d0

loc_FFDE:
		move.w	d0,obInertia(a0)
		move.b	obAngle(a0),d1
		addi.b	#$20,d1
		andi.b	#$C0,d1
		bne.s	Sonic_MoveRight.return
		cmpi.w	#-$400,d0
		bgt.s	Sonic_MoveRight.return
		move.b	#AniIDSonAni_Stop,obAnim(a0)
		bset	#0,obStatus(a0)
		move.w	#sfx_Skid,d0
		jmp	(PlaySound_Special).l
		; TODO: Uncomment and implement these lines. When that time comes, the jmp will change, too.
	;	cmpi.b	#12,air_left(a0)
	;	blo.s	Sonic_MoveLeft.return	; if he's drowning, branch to not make dust
	;	move.b	#6,(Sonic_Dust+routine).w
	;	move.b	#$15,(Sonic_Dust+mapping_frame).w
; End of function Sonic_MoveRight


; =============== S U B R O U T I N E =======================================


Sonic_RollSpeed:
		bsr.w	Player_ResetScr
		move.w	(Sonic_acceleration).w,d5
		asr.w	#1,d5
		move.w	#Sonic_RollBraking,d4
		tst.b	spindash_flag(a0)
		bmi.w	.velocity
		tst.b	(f_slidemode).w
		bne.w	.velocity
		btst	#status_secondary.sliding,obStatusSecondary(a0)
		bne.w	.velocity
		tst.w	move_lock(a0)
		bne.s	.friction
		btst	#button_left,(v_jpadholdlogical).w
		beq.s	.notleft
		bsr.w	Sonic_RollLeft
.notleft:
		btst	#button_right,(v_jpadholdlogical).w
		beq.s	.friction
		bsr.w	Sonic_RollRight
.friction:
		move.w	obInertia(a0),d0
		beq.s	.checkstop
		bmi.s	.left
		sub.w	d5,d0
		bhs.s	.setspeed
		clr.w	d0
.setspeed:
		move.w	d0,obInertia(a0)
		bra.s	.checkstop
.left:
		add.w	d5,d0
		bhs.s	.setleft
		clr.w	d0
.setleft:
		move.w	d0,obInertia(a0)
.checkstop:
		mvabs.w	obInertia(a0),d0
		cmpi.w	#Sonic_RollStopSpeed,d0
		bhs.s	.velocity
		tst.b	spindash_flag(a0)
		bne.s	.keeprolling
		bclr	#status.player.rolling,obStatus(a0)
		move.b	obHeight(a0),d0
		move.b	default_y_radius(a0),obHeight(a0)
		move.b	default_x_radius(a0),obWidth(a0)
		move.b	#AniIDSonAni_Wait,obAnim(a0)
		sub.b	default_y_radius(a0),d0
		ext.w	d0
		add.w	d0,obY(a0)
		bra.s	.velocity
.keeprolling:
		move.w	#Sonic_ForcedRollSpeed,obInertia(a0)
		btst	#status.player.x_flip,obStatus(a0)
		beq.s	.velocity
		neg.w	obInertia(a0)
.velocity:
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		cmpi.w	#Sonic_RollMaxXSpeed,d1
		ble.s	.checkleftcap
		move.w	#Sonic_RollMaxXSpeed,d1
.checkleftcap:
		cmpi.w	#-Sonic_RollMaxXSpeed,d1
		bge.s	.setx
		move.w	#-Sonic_RollMaxXSpeed,d1
.setx:
		move.w	d1,obVelX(a0)
		bra.w	Player_CheckWallsOnGround


Sonic_RollLeft:
		move.w	obInertia(a0),d0
		beq.s	loc_100C8
		bpl.s	loc_100D6

loc_100C8:
		bset	#0,obStatus(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_100D6:
		sub.w	d4,d0
		bhs.s	loc_100DE
		move.w	#-$80,d0

loc_100DE:
		move.w	d0,obInertia(a0)
		rts
; End of function Sonic_RollLeft


; =============== S U B R O U T I N E =======================================


Sonic_RollRight:
		move.w	obInertia(a0),d0
		bmi.s	loc_100F8
		bclr	#0,obStatus(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_100F8:
		add.w	d4,d0
		bhs.s	loc_10100
		move.w	#$80,d0

loc_10100:
		move.w	d0,obInertia(a0)
		rts
; End of function Sonic_RollRight


; =============== S U B R O U T I N E =======================================


Sonic_JumpDirection:
		move.w	(Sonic_top_speed).w,d6
		move.w	(Sonic_acceleration).w,d5
		asl.w	#1,d5
	;	btst	#4,obStatus(a0)
	;	bne.s	loc_10150
		move.w	obVelX(a0),d0
		btst	#bitL,(v_jpadholdlogical).w
		beq.s	+
		bset	#0,obStatus(a0)
		sub.w	d5,d0	; add acceleration to the left
		move.w	d6,d1
		neg.w	d1
		cmp.w	d1,d0	; compare new speed with top speed
		bgt.s	+	; if new speed is less than the maximum, branch
		add.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d1,d0	; compare speed with top speed
		ble.s	+	; if speed was already greater than the maximum, branch
		move.w	d1,d0	; limit speed on ground going left
+
		btst	#bitR,(v_jpadholdlogical).w
		beq.s	+
		bclr	#0,obStatus(a0)
		add.w	d5,d0	; add acceleration to the right
		cmp.w	d6,d0	; compare new speed with top speed
		blt.s	+	; if new speed is less than the maximum, branch
		sub.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d6,d0	; compare speed with top speed
		bge.s	+	; if speed was already greater than the maximum, branch
		move.w	d6,d0	; limit speed on ground going right
+
		move.w	d0,obVelX(a0)

; loc_10150:
		bsr.w	Player_ResetScr

loc_10162:
		cmpi.w	#-$400,obVelY(a0)
		blo.s	locret_10190
		move.w	obVelX(a0),d0
		move.w	d0,d1
		asr.w	#5,d1
		beq.s	locret_10190
		bmi.s	loc_10184
		sub.w	d1,d0
		bhs.s	loc_1017E
		clr.w	d0

loc_1017E:
		move.w	d0,obVelX(a0)
		rts
; ---------------------------------------------------------------------------

loc_10184:
		sub.w	d1,d0
		blo.s	loc_1018C
		clr.w	d0

loc_1018C:
		move.w	d0,obVelX(a0)

locret_10190:
		rts
; End of function Sonic_JumpDirection


; =============== S U B R O U T I N E =======================================

; Sonic_LevelBoundaries:
Sonic_LevelBound:
		move.l	obX(a0),d1
		move.w	obVelX(a0),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,d1
		swap	d1
		move.w	(Camera_Min_X_pos).w,d0
		addi.w	#$10,d0
		cmp.w	d1,d0
		bhi.s	loc_101FA
		move.w	(Camera_Max_X_pos).w,d0
		addi.w	#$128,d0
		tst.b	(f_lockscreen).w
		bne.s	loc_101C0
		addi.w	#$40,d0

loc_101C0:
		cmp.w	d1,d0
		bls.s	loc_101FA
; loc_101C4:
		move.w	(Camera_Max_Y_pos).w,d0
		; The original code does not consider that the camera boundary
		; may be in the middle of lowering itself, which is why going
		; down the S-tunnel in Green Hill Zone Act 1 fast enough can
		; kill Sonic.
		move.w	(Camera_Max_Y_pos_target).w,d1
		cmp.w	d0,d1
		blo.s	.skip
		move.w	d1,d0
.skip:
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		blt.s	loc_101D4
		rts
; ---------------------------------------------------------------------------

loc_101D4:
		; a2 needs to be set here, otherwise KillCharacter
		; will access a dangling pointer!
		movea.l	a0,a2
		cmpi.w	#(id_SBZ<<8)+1,(Current_ZoneAndAct).w
		bne.w	KillCharacter
		cmpi.w	#$2000,(v_player+obX).w
		blo.w	KillCharacter
		clr.b	(v_lastlamp).w
		move.w	#1,(Level_Inactive_flag).w
		move.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w
		rts
; ---------------------------------------------------------------------------

loc_101FA:
		move.w	d0,obX(a0)
		clr.w	obXSub(a0)
		clr.w	obVelX(a0)
		clr.w	obInertia(a0)
		move.w	(Camera_Max_Y_pos).w,d0
		; The original code does not consider that the camera boundary
		; may be in the middle of lowering itself, which is why going
		; down the S-tunnel in Green Hill Zone Act 1 fast enough can
		; kill Sonic.
		move.w	(Camera_Max_Y_pos_target).w,d1
		cmp.w	d0,d1
		blo.s	.skip
		move.w	d1,d0
.skip:
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		blt.s	loc_101D4
		rts

; End of function Sonic_LevelBound


; =============== S U B R O U T I N E =======================================


Sonic_Roll:
		tst.b	(f_slidemode).w
		bne.s	Obj01_NoRoll
		btst	#status_secondary.sliding,obStatusSecondary(a0)
		bne.s	Obj01_NoRoll
		move.b	(v_jpadholdlogical).w,d0
		andi.b	#button_left_mask|button_right_mask,d0
		bne.s	Obj01_NoRoll
		btst	#button_down,(v_jpadholdlogical).w
		beq.s	.checkwalk
		mvabs.w	obInertia(a0),d0
		cmpi.w	#Sonic_RollStartSpeed,d0
		bhs.s	.doroll
		btst	#status.player.on_object,obStatus(a0)
		bne.s	Obj01_NoRoll
		move.b	#AniIDSonAni_Duck,obAnim(a0)
		rts
.checkwalk:
		cmpi.b	#AniIDSonAni_Duck,obAnim(a0)
		bne.s	Obj01_NoRoll
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		rts
.doroll:
		btst	#status.player.rolling,obStatus(a0)
		bne.s	Obj01_NoRoll
		bset	#status.player.rolling,obStatus(a0)
		move.b	#sonic_roll_height,obHeight(a0)
		move.b	#sonic_roll_width,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		addq.w	#sonic_height-sonic_roll_height,obY(a0)
		move.w	#sfx_Roll,d0
		jmp	(PlaySound_Special).l
Obj01_NoRoll:
		rts


Sonic_Jump:
		move.b	(v_jpadpresslogical).w,d0
		andi.b	#btnABC,d0
		beq.s	Obj01_NoRoll
		moveq	#0,d0
		move.b	obAngle(a0),d0
		addi.b	#$80,d0
		bsr.w	sub_13102
		cmpi.w	#6,d1
		blt.s	Obj01_NoRoll
		move.w	#Sonic_JumpSpeed,d2
		btst	#status.player.underwater,obStatus(a0)
		beq.s	+
		move.w	#Sonic_WaterJumpSpeed,d2
+
		moveq	#0,d0
		move.b	obAngle(a0),d0
		subi.b	#$40,d0
		jsr	(CalcSine).l
		muls.w	d2,d1
		asr.l	#8,d1
		add.w	d1,obVelX(a0)
		muls.w	d2,d0
		asr.l	#8,d0
		add.w	d0,obVelY(a0)
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		addq.l	#4,sp
		move.b	#1,jumping(a0)
		clr.b	stick_to_convex(a0)
		move.w	#sfx_Jump,d0
		jsr	(PlaySound_Special).l
		btst	#2,obStatus(a0)
		bne.s	.return
		move.b	#sonic_roll_height,obHeight(a0)
		move.b	#sonic_roll_width,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		bset	#2,obStatus(a0)
		addq.w	#5,obY(a0)
.return:	rts
; ---------------------------------------------------------------------------

;loc_1031E:
	;	bset	#4,obStatus(a0)
	;	rts
; End of function Sonic_Jump


; =============== S U B R O U T I N E =======================================


Sonic_JumpHeight:
		tst.b	jumping(a0)
		beq.s	loc_10352
		move.w	#-Sonic_JumpReleaseSpeed,d1
		btst	#status.player.underwater,obStatus(a0)
		beq.s	loc_1033C
		move.w	#-Sonic_WaterJumpReleaseSpeed,d1

loc_1033C:
		cmp.w	obVelY(a0),d1
		ble.s	.return
		move.b	(v_jpadholdlogical).w,d0
		andi.b	#btnABC,d0
		bne.s	.return
		move.w	d1,obVelY(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_10352:
		tst.b	spindash_flag(a0)		; forced rolls retain their launch velocity
		bne.s	.return
		cmpi.w	#-Sonic_UpwardSpeedLimit,obVelY(a0)
		bge.s	.return
		move.w	#-Sonic_UpwardSpeedLimit,obVelY(a0)
.return:	rts
; End of function Sonic_JumpHeight

; ---------------------------------------------------------------------------
; Subroutine to launch a homing attack -- TODO
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

Sonic_HomingAttack:
		moveq	#btnABC,d0		; is any of the buttons ABC...
		and.b	(v_jpadpresslogical).w,d0	; ...pressed?
		beq.s	.homeend		; if not, branch

		move.w	#sfx_Teleport,d0	; play dash sound as a test
		jmp	(PlaySound_Special).l

.homeend:
		rts
; End of function Sonic_HomingAttack

; ---------------------------------------------------------------------------
; Subroutine to check for starting to charge a spindash
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; Sonic_Spindash:
Sonic_CheckSpindash:
		tst.b	spindash_flag(a0)
		bne.s	Sonic_UpdateSpindash
		cmpi.b	#AniIDSonAni_Duck,obAnim(a0)
		bne.s	.return
		move.b	(v_jpadpresslogical).w,d0
		andi.b	#btnABC,d0
		beq.s	.return
		move.b	#AniIDSonAni_Spindash,obAnim(a0)
		move.w	#sfx_Spindash,d0
		jsr	(PlaySound_Special).l
		move.b	#1,spindash_flag(a0)
		clr.w	spindash_counter(a0)
		bra.w	Sonic_SpindashGround
.return:
		rts

Sonic_UpdateSpindash:
		btst	#button_down,(v_jpadholdlogical).w
		bne.w	Sonic_ChargingSpindash
		move.b	#sonic_roll_height,obHeight(a0)
		move.b	#sonic_roll_width,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		addq.w	#sonic_height-sonic_roll_height,obY(a0)
		clr.b	spindash_flag(a0)
		moveq	#0,d0
		move.b	spindash_counter(a0),d0	; integer part of the 8.8 charge
		add.w	d0,d0
		move.w	Sonic_SpindashSpeeds(pc,d0.w),obInertia(a0)
		move.w	obInertia(a0),d0
		subi.w	#Sonic_SpindashMinSpeed,d0
		add.w	d0,d0
		neg.w	d0
		addi.w	#Sonic_SpindashCameraDelayMax<<8,d0
	if FixBugs
		lsr.w	#8,d0
		move.b	d0,(Horiz_scroll_delay_val).w
		move.b	(Sonic_Pos_Record_Index+1).w,(Horiz_scroll_delay_val+1).w
	else
		move.w	d0,(Horiz_scroll_delay_val).w
	endif
		btst	#status.player.x_flip,obStatus(a0)
		beq.s	.right
		neg.w	obInertia(a0)
.right:
		bset	#status.player.rolling,obStatus(a0)
		move.w	#sfx_Dash,d0
		jsr	(PlaySound_Special).l
		bra.s	Sonic_SpindashGround

Sonic_SpindashSpeeds:
		dc.w Sonic_SpindashMinSpeed
		dc.w Sonic_SpindashMinSpeed+Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+2*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+3*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+4*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+5*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+6*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+7*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+8*Sonic_SpindashSpeedStep

Sonic_ChargingSpindash:
		tst.w	spindash_counter(a0)
		beq.s	.press
		move.w	spindash_counter(a0),d0
		lsr.w	#Sonic_SpindashDecayShift,d0
		sub.w	d0,spindash_counter(a0)
		bhs.s	.press
		clr.w	spindash_counter(a0)
.press:
		move.b	(v_jpadpresslogical).w,d0
		andi.b	#btnABC,d0
		beq.s	Sonic_SpindashGround
		move.w	#AniIDSonAni_Spindash<<8,obAnim(a0)
		move.w	#sfx_Spindash,d0
		jsr	(PlaySound_Special).l
		addi.w	#Sonic_SpindashChargeStep,spindash_counter(a0)
		cmpi.w	#Sonic_SpindashMaxCharge,spindash_counter(a0)
		blo.s	Sonic_SpindashGround
		move.w	#Sonic_SpindashMaxCharge,spindash_counter(a0)

Sonic_SpindashGround:
		addq.l	#4,sp			; skip the rest of MdNormal on start, charge and release
		bsr.w	Player_ResetScr
		bsr.w	Sonic_LevelBound
		bra.w	AnglePos			; follow the ground while charging


Sonic_SlopeResist:
		move.b	obAngle(a0),d0
		addi.b	#$60,d0
		cmpi.b	#$C0,d0
		bhs.s	.return
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	#$20,d0
		asr.l	#8,d0
		tst.w	obInertia(a0)
		beq.s	.standing
		bmi.s	.add
		tst.w	d0
		beq.s	.return
.add:
		add.w	d0,obInertia(a0)
.return:
		rts
.standing:
		mvabs.w	d0,d1
		cmpi.w	#Sonic_SlopeStandingThreshold,d1
		blo.s	.return
		add.w	d0,obInertia(a0)
		rts


Sonic_RollRepel:
		move.b	obAngle(a0),d0
		addi.b	#$60,d0
		cmpi.b	#$C0,d0
		bhs.s	locret_1045E
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	#$50,d0
		asr.l	#8,d0
		tst.w	obInertia(a0)
		bmi.s	loc_10454
		tst.w	d0
		bpl.s	loc_1044E
		asr.l	#2,d0

loc_1044E:
		add.w	d0,obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_10454:
		tst.w	d0
		bmi.s	loc_1045A
		asr.l	#2,d0

loc_1045A:
		add.w	d0,obInertia(a0)

locret_1045E:
		rts
; End of function Sonic_RollRepel


; =============== S U B R O U T I N E =======================================


Sonic_SlopeRepel:
		tst.b	stick_to_convex(a0)
		bne.s	.return
		tst.w	move_lock(a0)
		bne.s	.locked
		move.b	obAngle(a0),d0
		addi.b	#$18,d0
		cmpi.b	#$30,d0
		blo.s	.return
		mvabs.w	obInertia(a0),d0
		cmpi.w	#Sonic_SlopeDetachSpeed,d0
		bhs.s	.return
		move.w	#Sonic_SlopeLockTime,move_lock(a0)
		move.b	obAngle(a0),d0
		addi.b	#$30,d0
		cmpi.b	#$60,d0
		blo.s	.slide
		bset	#status.player.in_air,obStatus(a0)
.return:
		rts
.slide:
		cmpi.b	#$30,d0
		blo.s	.left
		addi.w	#Sonic_SlopeSlipStep,obInertia(a0)
		rts
.left:
		subi.w	#Sonic_SlopeSlipStep,obInertia(a0)
		rts
.locked:
		subq.w	#1,move_lock(a0)
		rts


Sonic_JumpAngle:
		move.b	obAngle(a0),d0	; get Sonic's angle
		beq.s	loc_104BC	; if already 0, branch
		bpl.s	loc_104B2	; if higher than 0, branch
		addq.b	#2,d0		; increase angle
		bhs.s	loc_104B8
		moveq	#0,d0
		bra.s	loc_104B8
; ---------------------------------------------------------------------------

loc_104B2:
		subq.b	#2,d0		; decrease angle
		bhs.s	loc_104B8
		moveq	#0,d0

loc_104B8:
		move.b	d0,obAngle(a0)

loc_104BC:
		move.b	flip_angle(a0),d0
		beq.s	.return
		tst.w	obInertia(a0)
		bmi.s	loc_104E0
		move.b	flip_speed(a0),d1
		add.b	d1,d0
		bhs.s	+
		subq.b	#1,flips_remaining(a0)
		bhs.s	+
		moveq	#0,d0
		move.b	d0,flips_remaining(a0)
+
		move.b	d0,flip_angle(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_104E0:
		move.b	flip_speed(a0),d1
		sub.b	d1,d0
		bhs.s	loc_104F6
		subq.b	#1,flips_remaining(a0)
		bhs.s	loc_104F6
		moveq	#0,d0
		move.b	d0,flips_remaining(a0)

loc_104F6:
		move.b	d0,flip_angle(a0)
		rts
; End of function Sonic_JumpAngle


; =============== S U B R O U T I N E =======================================

; Sonic_Floor:
Sonic_DoLevelCollision:
		move.l	(v_colladdr1).w,(Collision_addr).w
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	+
		move.l	(v_colladdr2).w,(Collision_addr).w
+
		move.b	obLRBSolidBit(a0),d5
		move.w	obVelX(a0),d0				; get X speed
		move.w	obVelY(a0),d1				; get Y speed
		bpl.s	SonAirCol_PosY				; if it's positive, branch
		cmp.w	d0,d1					; are we moving towards the left?
		bgt.w	Sonic_FloorLeft				; if so, branch
		neg.w	d0					; negate for right cheeck
		cmp.w	d0,d1					; are we moving towards the right?
		bge.w	Sonic_FloorRight			; if so, branch
		bra.w	Sonic_FloorUp				; we are moving upwards
; ===========================================================================

SonAirCol_PosY:
		cmp.w	d0,d1					; are we moving towards the right?
		blt.w	Sonic_FloorRight			; if so, branch
		neg.w	d0					; negate for left check
		cmp.w	d0,d1					; are we moving towards the left?
		ble.w	Sonic_FloorLeft				; if so, branch
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	+
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
+
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	+
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
+
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		move.b	obVelY(a0),d2
		addq.b	#8,d2
		neg.b	d2
		cmp.b	d2,d1
		bge.s	+
		cmp.b	d2,d0
		blt.s	.return
+
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Sonic_ResetOnFloor
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	loc_105C0
		move.b	d3,d0
		addi.b	#$10,d0
		andi.b	#$20,d0
		beq.s	loc_105B2
		asr	obVelY(a0)
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_105B2:
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_105C0:
		clr.w	obVelX(a0)
		cmpi.w	#$FC0,obVelY(a0)
		ble.s	loc_105D4
		move.w	#$FC0,obVelY(a0)

loc_105D4:
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Sonic_FloorLeft:
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	loc_105FE
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_105FE:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	loc_10618
		neg.w	d1
		cmpi.w	#Sonic_CeilingPenetrationLimit,d1
		bhs.s	Sonic_FloorLeft_OppositeWall
		add.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Sonic_FloorLeft_OppositeWall:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	.return
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
.return:
		rts

loc_10618:
		tst.b	(f_wtunnelmode).w
		bne.s	.checkfloor
		tst.w	obVelY(a0)
		bmi.s	.return
.checkfloor:
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Sonic_ResetOnFloor
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Sonic_FloorUp:
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	loc_10658
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)

loc_10658:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	loc_1066A
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)

loc_1066A:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	.return
		sub.w	d1,obY(a0)
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	loc_1068A
		clr.w	obVelY(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_1068A:
		move.b	d3,obAngle(a0)
		bsr.w	Sonic_ResetOnFloor
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Sonic_FloorRight:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	loc_106BC
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_106BC:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	loc_106D6
		sub.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_106D6:
		tst.b	(f_wtunnelmode).w
		bne.s	.checkfloor
		tst.w	obVelY(a0)
		bmi.s	.return
.checkfloor:
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Sonic_ResetOnFloor
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; End of function Sonic_DoLevelCollision


; =============== S U B R O U T I N E =======================================


Sonic_ResetOnFloor:
		cmpi.b	#id_Obj02,obID(a0)
		bne.s	+
		clr.b	tails_flight_flag(a0)
+
		tst.b	spindash_flag(a0)
		bne.s	.reset			; forced rolls retain their ball and animation
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		move.b	obHeight(a0),d0
		move.b	default_y_radius(a0),obHeight(a0)
		move.b	default_x_radius(a0),obWidth(a0)
		btst	#status.player.rolling,obStatus(a0)
		beq.s	.reset
		bclr	#status.player.rolling,obStatus(a0)
		sub.b	default_y_radius(a0),d0
		ext.w	d0
		move.w	d0,-(sp)
		move.b	obAngle(a0),d0
		addi.b	#$40,d0
		bpl.s	.adjustheight
		neg.w	(sp)			; standing radius extends the other way on ceilings
.adjustheight:
		move.w	(sp)+,d0
		add.w	d0,obY(a0)
.reset:
		bclr	#status.player.in_air,obStatus(a0)
		bclr	#status.player.pushing,obStatus(a0)
		; Roll-jump locking stays removed; rolling jumps retain air control.
		clr.b	jumping(a0)
		clr.w	(v_itembonus).w
		clr.b	flip_angle(a0)
		clr.b	flip_turned(a0)
		clr.b	flips_remaining(a0)
		clr.b	scroll_delay_counter(a0)
		rts

; ---------------------------------------------------------------------------

Obj01_Hurt:
		bsr.w	Player_ChkInvincibility
		bsr.w	Player_ChkSpeedShoes
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$30,obVelY(a0)
		btst	#6,obStatus(a0)
		beq.s	loc_1077E
		subi.w	#$20,obVelY(a0)

loc_1077E:
		tst.w	(Camera_Min_Y_pos).w
		bpl.s	.no_wrap
		andi.w	#Level_YWrapMask,obY(a0)
.no_wrap:
		bsr.w	Sonic_HurtStop
		bsr.w	Sonic_LevelBound
		bsr.w	Sonic_RecordPos
		bsr.w	Sonic_Water
		bsr.w	Sonic_Animate
		bsr.w	LoadSonicDynPLC
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


Sonic_HurtStop:
		; a2 needs to be set here, otherwise KillCharacter
		; will access a dangling pointer!
		movea.l	a0,a2
		move.w	(Camera_Max_Y_pos).w,d0
		; The original code does not consider that the camera boundary
		; may be in the middle of lowering itself, which is why going
		; down the S-tunnel in Green Hill Zone Act 1 fast enough can
		; kill Sonic.
		move.w	(Camera_Max_Y_pos_target).w,d1
		cmp.w	d0,d1
		blo.s	.skip
		move.w	d1,d0
.skip:
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		blo.w	KillCharacter
		bsr.w	Sonic_DoLevelCollision
		btst	#1,obStatus(a0)	; in_air
		bne.s	.return
		moveq	#0,d0
		move.w	d0,obVelY(a0)
		move.w	d0,obVelX(a0)
		move.w	d0,obInertia(a0)
		move.b	d0,obControl(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		move.w	#$100,obPriority(a0)
		subq.b	#2,obRoutine(a0)
		move.w	#Player_HurtFlashTime,flashtime(a0)
		move.b	d0,spindash_flag(a0)
.return:	rts
; End of function Sonic_HurtStop

; ---------------------------------------------------------------------------
; Obj01_Death:
Obj01_Dead:
		bsr.w	Sonic_GameOver
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		bsr.w	Sonic_RecordPos
		bsr.w	Sonic_Animate
		bsr.w	LoadSonicDynPLC
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


Sonic_GameOver:
		move.b	#1,(Deform_lock).w		; S3&K holds the camera during the death fall
		clr.b	spindash_flag(a0)
		move.w	(Camera_Y_pos).w,d0
		addi.w	#Sonic_DeathScreenMargin,d0
		cmp.w	obY(a0),d0
		bge.w	Obj01_ResetLevel.return
		move.w	#-$38,obVelY(a0)
		addq.b	#2,obRoutine(a0)
		clr.b	(f_timecount).w
		addq.b	#1,(f_lifecount).w
		subq.b	#1,(v_lives).w
		bne.s	+
		clr.w	restart_countdown(a0)
		_move.b	#id_Obj98,(v_gameovertext1).w
		_move.b	#id_Obj98,(v_gameovertext2).w
		move.b	#1,(v_gameovertext2+obFrame).w
		clr.b	(f_timeover).w
		move.w	#bgm_GameOver,d0
		jsr	(PlaySound).l
		move.b	#PlayerEffects_GameOverLoaded,(v_shieldobj+effect_loaded_frame).w
		moveq	#plcid_GameOver,d0
		jmp	(LoadPLC).l
; ---------------------------------------------------------------------------
+
		move.w	#60,restart_countdown(a0)
		tst.b	(f_timeover).w
		beq.s	Obj01_ResetLevel.return
		clr.w	restart_countdown(a0)
		_move.b	#id_Obj98,(v_gameovertext1).w
		_move.b	#id_Obj98,(v_gameovertext2).w
		move.b	#2,(v_gameovertext1+obFrame).w
		move.b	#3,(v_gameovertext2+obFrame).w
		move.w	#bgm_GameOver,d0
		jsr	(PlaySound).l
		move.b	#PlayerEffects_GameOverLoaded,(v_shieldobj+effect_loaded_frame).w
		moveq	#plcid_GameOver,d0
		jmp	(LoadPLC).l
; End of function Sonic_GameOver

; ---------------------------------------------------------------------------

Obj01_ResetLevel:
		tst.w	restart_countdown(a0)
		beq.s	.return
		subq.w	#1,restart_countdown(a0)
		bne.s	.return
		move.w	#1,(Level_Inactive_flag).w
.return:	rts

; =============== S U B R O U T I N E =======================================


Sonic_Animate:
		lea	SonicAniData(pc),a1	; Get animation script
	;	tst.b	(Super_Sonic_flag).w	; Are we Super?
	;	beq.s	+			; Skip if not
	;	lea	AniSuperSonic(pc),a1	; Get Super animation script
;+
		moveq	#0,d0			; Get current animation
		move.b	obAnim(a0),d0
		cmp.b	obPrevAni(a0),d0	; has animation changed?
		beq.s	SAnim_Do		; if not, branch
		move.b	d0,obPrevAni(a0)	; set previous animation
		clr.b	obAniFrame(a0)		; reset animation frame
		clr.b	obTimeFrame(a0)		; reset frame duration
		bclr	#5,obStatus(a0)		; clear pushing flag

SAnim_Do:
		add.w	d0,d0
		adda.w	(a1,d0.w),a1		; jump to appropriate animation	script
		move.b	(a1),d0
		bmi.s	SAnim_WalkRun		; if animation is walk/run/roll/jump, branch
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		subq.b	#1,obTimeFrame(a0)	; subtract 1 from frame duration
		bpl.s	SAnim_Delay		; if time remains, branch
		move.b	d0,obTimeFrame(a0)	; load frame duration
		; fall through
; -------------------------------------------------------------------------
SAnim_Do2:
		moveq	#0,d1
		move.b	obAniFrame(a0),d1	; load current frame number
		move.b	1(a1,d1.w),d0		; read sprite number from script
		beq.s	SAnim_Next		; If it's a frame ID, branch
		bpl.s	SAnim_Next
		cmpi.b	#afChange,d0			; is it a flag from FC to FF?
		bhs.s	SAnim_End_FF		; MJ: if so, branch to flag routines
	;	bge.s	SAnim_End_FF		; MJ: if so, branch to flag routines

SAnim_Next:
		move.b	d0,obFrame(a0)		; load sprite number
		addq.b	#1,obAniFrame(a0)	; next frame number
SAnim_Delay:	rts
; ---------------------------------------------------------------------------
SAnim_End_FF:
		addq.b	#1,d0			; is the end flag = $FF?
		bne.s	SAnim_End_FE		; if not, branch
		clr.b	obAniFrame(a0)		; restart the animation
		move.b	1(a1),d0		; read sprite number
		bra.s	SAnim_Next
; ---------------------------------------------------------------------------
SAnim_End_FE:
		addq.b	#1,d0			; is the end flag = $FE?
		bne.s	SAnim_End_FD		; if not, branch
		move.b	2(a1,d1.w),d0		; read the next byte in the script
		sub.b	d0,obAniFrame(a0)	; jump back d0 bytes in the script
		sub.b	d0,d1
		move.b	1(a1,d1.w),d0		; read sprite number
		bra.s	SAnim_Next
; ---------------------------------------------------------------------------
SAnim_End_FD:
		addq.b	#1,d0			; is the end flag = $FD?
		bne.s	SAnim_End		; if not, branch
		move.b	2(a1,d1.w),obAnim(a0)	; read next byte, run that animation
SAnim_End:	rts
; ---------------------------------------------------------------------------

SAnim_WalkRun:
		addq.b	#1,d0		; is the start flag = $FF?
		bne.w	SAnim_Roll	; if not, branch
		moveq	#0,d0		; is animation walking/running?
		move.b	flip_angle(a0),d0; if not, branch
		bne.w	SAnim_Tumble
		moveq	#0,d1
		move.b	obAngle(a0),d0	; get Sonic's angle
		ble.s	.notoffbyone
		subq.b	#1,d0
.notoffbyone:	move.b	obStatus(a0),d2
		andi.b	#1<<status.player.x_flip,d2	; is Sonic mirrored horizontally?
		bne.s	.flip				; if yes, branch
		not.b	d0				; reverse angle
.flip:
		addi.b	#$10,d0		; add $10 to angle
		bpl.s	.noinvert	; if angle is $0-$7F, branch
		moveq	#1<<render_flags.x_flip|1<<render_flags.y_flip,d1
.noinvert:
		andi.b	#~(1<<render_flags.x_flip|1<<render_flags.y_flip),obRender(a0)
		eor.b	d1,d2
		or.b	d2,obRender(a0)
		btst	#status.player.pushing,obStatus(a0)
		bne.w	SAnim_Push
		lsr.b	#4,d0
		andi.b	#6,d0
		mvabs.w	obInertia(a0),d2
		btst	#status_secondary.sliding,obStatusSecondary(a0)
		beq.s	+
		add.w	d2,d2
+
	;	tst.b	(Super_Sonic_flag).w
	;	bne.s	SAnim_Super
		lea	SonAni_Run(pc),a1
		cmpi.w	#$600,d2
		bhs.s	+
		lea	SonAni_Walk(pc),a1
		add.b	d0,d0
+
		add.b	d0,d0
		move.b	d0,d3
		moveq	#0,d1
		move.b	obAniFrame(a0),d1
		move.b	1(a1,d1.w),d0
		cmpi.b	#-1,d0
		bne.s	+
		clr.b	obAniFrame(a0)
		move.b	1(a1),d0
+
		move.b	d0,obFrame(a0)
		add.b	d3,obFrame(a0)
		subq.b	#1,obTimeFrame(a0)
		bpl.s	.return
		neg.w	d2
		addi.w	#$800,d2
		bpl.s	+
		moveq	#0,d2
+
		lsr.w	#8,d2
		move.b	d2,obTimeFrame(a0)
		addq.b	#1,obAniFrame(a0)
.return:	rts
; ---------------------------------------------------------------------------

SAnim_Tumble:
		move.b	flip_angle(a0),d0
		moveq	#0,d1
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	SAnim_Tumble_Left
		andi.b	#~(1<<render_flags.x_flip|1<<render_flags.y_flip),obRender(a0)
		addi.b	#$B,d0
		divu.w	#$16,d0
		addi.b	#$5F,d0
		move.b	d0,obFrame(a0)
		clr.b	obTimeFrame(a0)
		rts
; ---------------------------------------------------------------------------

SAnim_Tumble_Left:
		andi.b	#$FC,obRender(a0)
		tst.b	flip_turned(a0)
		beq.s	+
		ori.b	#1<<render_flags.x_flip,obRender(a0)
		addi.b	#$B,d0
		bra.s	++
; ===========================================================================

+
		ori.b	#1<<render_flags.x_flip|1<<render_flags.y_flip,obRender(a0)
		neg.b	d0
		addi.b	#$8F,d0

+
		divu.w	#$16,d0
		addi.b	#$5F,d0
		move.b	d0,obFrame(a0)
		clr.b	obTimeFrame(a0)
		rts
; ---------------------------------------------------------------------------

SAnim_Roll:
		subq.b	#1,obTimeFrame(a0)	; subtract 1 from frame duration
		bpl.w	SAnim_End		; if time remains, branch
		addq.b	#1,d0			; is the start flag = $FE?
		bne.s	SAnim_Push		; if not, branch
		mvabs.w	obInertia(a0),d2
		lea	SonAni_Roll2(pc),a1
		cmpi.w	#$600,d2
		bhs.s	+
		lea	SonAni_Roll(pc),a1
+
		neg.w	d2
		addi.w	#$400,d2
		bpl.s	+
		moveq	#0,d2
+
		lsr.w	#8,d2
		move.b	d2,obTimeFrame(a0)
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#~(1<<render_flags.x_flip|1<<render_flags.y_flip),obRender(a0)
		or.b	d1,obRender(a0)
		bra.w	SAnim_Do2
; ---------------------------------------------------------------------------

SAnim_Push:
		subq.b	#1,obTimeFrame(a0)	; subtract 1 from frame duration
		bpl.w	SAnim_End		; if time remains, branch
		move.w	obInertia(a0),d2
		bmi.s	+
		neg.w	d2
+
		addi.w	#$800,d2
		bpl.s	+
		moveq	#0,d2
+
		lsr.w	#6,d2
		move.b	d2,obTimeFrame(a0)
		lea	SonAni_Push(pc),a1
	;	tst.b	(Super_Sonic_flag).w
	;	beq.s	+
	;	lea	(SupSonAni_Push).l,a1
+
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#~(1<<render_flags.x_flip|1<<render_flags.y_flip),obRender(a0)
		or.b	d1,obRender(a0)
		bra.w	SAnim_Do2
; End of function Sonic_Animate
; ===========================================================================
; ---------------------------------------------------------------------------
; Animation script - Sonic
; ---------------------------------------------------------------------------
; off_1B618:
SonicAniData:			offsetTable
SonAni_Walk_ptr:		offsetTableEntry.w SonAni_Walk		;  0 ;   0
SonAni_Run_ptr:			offsetTableEntry.w SonAni_Run		;  1 ;   1
SonAni_Roll_ptr:		offsetTableEntry.w SonAni_Roll		;  2 ;   2
SonAni_Roll2_ptr:		offsetTableEntry.w SonAni_Roll2		;  3 ;   3
SonAni_Push_ptr:		offsetTableEntry.w SonAni_Push		;  4 ;   4
SonAni_Wait_ptr:		offsetTableEntry.w SonAni_Wait		;  5 ;   5
SonAni_Balance_ptr:		offsetTableEntry.w SonAni_Balance	;  6 ;   6
SonAni_LookUp_ptr:		offsetTableEntry.w SonAni_LookUp	;  7 ;   7
SonAni_Duck_ptr:		offsetTableEntry.w SonAni_Duck		;  8 ;   8
SonAni_Spindash_ptr:		offsetTableEntry.w SonAni_Spindash	;  9 ;   9
SonAni_Blink_ptr:		offsetTableEntry.w SonAni_Blink		; 10 ;  $A
SonAni_GetUp_ptr:		offsetTableEntry.w SonAni_GetUp		; 11 ;  $B
SonAni_Balance2_ptr:		offsetTableEntry.w SonAni_Balance2	; 12 ;  $C
SonAni_Stop_ptr:		offsetTableEntry.w SonAni_Stop		; 13 ;  $D
SonAni_Float_ptr:		offsetTableEntry.w SonAni_Float		; 14 ;  $E
SonAni_Float2_ptr:		offsetTableEntry.w SonAni_Float2	; 15 ;  $F
SonAni_Spring_ptr:		offsetTableEntry.w SonAni_Spring	; 16 ; $10
SonAni_Hang_ptr:		offsetTableEntry.w SonAni_Hang		; 17 ; $11
SonAni_Dash2_ptr:		offsetTableEntry.w SonAni_Dash2		; 18 ; $12
SonAni_Dash3_ptr:		offsetTableEntry.w SonAni_Dash3		; 19 ; $13
SonAni_Hang2_ptr:		offsetTableEntry.w SonAni_Hang2		; 20 ; $14
SonAni_Bubble_ptr:		offsetTableEntry.w SonAni_Bubble	; 21 ; $15
SonAni_DeathBW_ptr:		offsetTableEntry.w SonAni_DeathBW	; 22 ; $16
SonAni_Drown_ptr:		offsetTableEntry.w SonAni_Drown		; 23 ; $17
SonAni_Death_ptr:		offsetTableEntry.w SonAni_Death		; 24 ; $18
SonAni_Hurt_ptr:		offsetTableEntry.w SonAni_Hurt		; 25 ; $19
SonAni_Hurt2_ptr:		offsetTableEntry.w SonAni_Hurt		; 26 ; $1A
SonAni_Slide_ptr:		offsetTableEntry.w SonAni_Slide		; 27 ; $1B
SonAni_Blank_ptr:		offsetTableEntry.w SonAni_Blank		; 28 ; $1C
SonAni_Balance3_ptr:		offsetTableEntry.w SonAni_Balance3	; 29 ; $1D
SonAni_Balance4_ptr:		offsetTableEntry.w SonAni_Balance4	; 30 ; $1E
SupSonAni_Transform_ptr:	offsetTableEntry.w SupSonAni_Transform	; 31 ; $1F
SonAni_Lying_ptr:		offsetTableEntry.w SonAni_Lying		; 32 ; $20
SonAni_LieDown_ptr:		offsetTableEntry.w SonAni_LieDown	; 33 ; $21
SonAni_Peelout_ptr:		offsetTableEntry.w SonAni_Peelout	; 34 ; $22
SonAni_Carried_ptr:		offsetTableEntry.w SonAni_Carried	; 35 ; $23
; ---------------------------------------------------------------------------
; --- Special animations (walk/run/roll/push) ---
; Sonic handles animations with a start value of $80 or greater separately.
; All special animations need to have EXACTLY 6 frames (plus one afEnd),
; animations that are too short have extra afEnd to pad to the same length.
; This is because the special animation handler switches between these
; animations without resetting the animation positon.
; ---------------------------------------------------------------------------
SonAni_Walk:	dc.b $FF, $F,$10,$11,$12,$13,$14, $D, $E,afEnd
	even
SonAni_Run:	dc.b $FF,$2D,$2E,$2F,$30,afEnd,afEnd,afEnd,afEnd,afEnd
	even
SonAni_Roll:	dc.b $FE,$3D,$41,$3E,$41,$3F,$41,$40,$41,afEnd
	even
SonAni_Roll2:	dc.b $FE,$3D,$41,$3E,$41,$3F,$41,$40,$41,afEnd
	even
SonAni_Push:	dc.b $FD,$48,$49,$4A,$4B,afEnd,afEnd,afEnd,afEnd,afEnd
	even
; ---------------------------------------------------------------------------
; --- Normal animations ---
; First byte denotes number of frames between each animation.
; Overview of animation flags (examples):
; 	dc.b afEnd  		; return to beginning of animation
; 	dc.b afBack, 5		; go back specified number of frames
; 	dc.b afChange, id_Surf	; switch to a different animation
; ---------------------------------------------------------------------------
SonAni_Wait:
	dc.b   5,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
	dc.b   1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2
	dc.b   3,  3,  3,  3,  3,  4,  4,  4,  5,  5,  5,  4,  4,  4,  5,  5
	dc.b   5,  4,  4,  4,  5,  5,  5,  4,  4,  4,  5,  5,  5,  6,  6,  6
	dc.b   6,  6,  6,  6,  6,  6,  6,  4,  4,  4,  5,  5,  5,  4,  4,  4
	dc.b   5,  5,  5,  4,  4,  4,  5,  5,  5,  4,  4,  4,  5,  5,  5,  6
	dc.b   6,  6,  6,  6,  6,  6,  6,  6,  6,  4,  4,  4,  5,  5,  5,  4
	dc.b   4,  4,  5,  5,  5,  4,  4,  4,  5,  5,  5,  4,  4,  4,  5,  5
	dc.b   5,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  4,  4,  4,  5,  5
	dc.b   5,  4,  4,  4,  5,  5,  5,  4,  4,  4,  5,  5,  5,  4,  4,  4
	dc.b   5,  5,  5,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  7,  8,  8
	dc.b   8,  9,  9,  9,afBack,  6
	even
SonAni_Balance:	dc.b   9,$CC,$CD,$CE,$CD,afEnd
	even
SonAni_LookUp:	dc.b   5, $B, $C,afBack,  1
	even
SonAni_Duck:	dc.b   5,$4C,$4D,afBack,  1
	even
SonAni_Spindash:dc.b   0,$42,$43,$42,$44,$42,$45,$42,$46,$42,$47,afEnd
	even
SonAni_Blink:	dc.b   1,  2,afChange,  0
	even
SonAni_GetUp:	dc.b   3, $A,afChange,  0
	even
SonAni_Balance2:dc.b   3,$C8,$C9,$CA,$CB,afEnd
	even
SonAni_Stop:	dc.b   5,$D1,$D2,$D3,$D4,afChange,  0	; halt/skidding animation
	even
SonAni_Float:	dc.b   7,$54,$59,afEnd
	even
SonAni_Float2:	dc.b   7,$54,$55,$56,$57,$58,afEnd
	even
SonAni_Spring:	dc.b   3,$DA,$DB,$DC,$DD,$DE
		dc.b   $DA,$DB,$DC,$DD,$DE
		dc.b   $DA,$DB,$DC,$DD,$DE
		dc.b   afChange,  0
	even
SonAni_Hang:	dc.b   1,$50,$51,afEnd
	even
SonAni_Dash2:	dc.b  $F,$43,$43,$43,afBack,  1
	even
SonAni_Dash3:	dc.b  $F,$43,$44,afBack,  1
	even
SonAni_Hang2:	dc.b $13,$6B,$6C,afEnd
	even
SonAni_Bubble:	dc.b  $B,$5A,$5A,$11,$12,afChange,  0	; breathe
	even
SonAni_DeathBW:	dc.b $20,$5E,afEnd			; (Now victory pose, frame 2) CHANGE ME
	even
SonAni_Drown:	dc.b $20,$5D,afEnd
	even
SonAni_Death:	dc.b $20,$5C,afEnd
	even
SonAni_Hurt:	dc.b $40,$4E,afEnd
	even
SonAni_Slide:	dc.b   9,$4E,$4F,afEnd
	even
SonAni_Blank:	dc.b $77,  0,afChange,  0
	even
SonAni_Balance3:dc.b $13,$CF,$D0,afEnd
	even
SonAni_Balance4:dc.b   3,$C8,$C9,$CA,$CB,afBack,  4
	even
SonAni_Lying:	dc.b   9,  8,  9,afEnd
	even
SonAni_LieDown:	dc.b   3,  7,afChange,  0
	even
SonAni_Peelout:	dc.b $FF,$E2,$E3,$E4,$E5,afEnd,afEnd,afEnd,afEnd,afEnd	; TODO Implement
	even
; ---------------------------------------------------------------------------
; Animation script - Super Sonic
; (many of these point to the data above this)
; ---------------------------------------------------------------------------
SuperSonicAniData: offsetTable
	offsetTableEntry.w SupSonAni_Walk	;  0 ;   0
	offsetTableEntry.w SupSonAni_Run	;  1 ;   1
	offsetTableEntry.w SonAni_Roll		;  2 ;   2
	offsetTableEntry.w SonAni_Roll2		;  3 ;   3
	offsetTableEntry.w SupSonAni_Push	;  4 ;   4
	offsetTableEntry.w SupSonAni_Stand	;  5 ;   5
	offsetTableEntry.w SupSonAni_Balance	;  6 ;   6
	offsetTableEntry.w SonAni_LookUp	;  7 ;   7
	offsetTableEntry.w SupSonAni_Duck	;  8 ;   8
	offsetTableEntry.w SonAni_Spindash	;  9 ;   9
	offsetTableEntry.w SonAni_Blink		; 10 ;  $A
	offsetTableEntry.w SonAni_GetUp		; 11 ;  $B
	offsetTableEntry.w SonAni_Balance2	; 12 ;  $C
	offsetTableEntry.w SonAni_Stop		; 13 ;  $D
	offsetTableEntry.w SonAni_Float		; 14 ;  $E
	offsetTableEntry.w SonAni_Float2	; 15 ;  $F
	offsetTableEntry.w SonAni_Spring	; 16 ; $10
	offsetTableEntry.w SonAni_Hang		; 17 ; $11
	offsetTableEntry.w SonAni_Dash2		; 18 ; $12
	offsetTableEntry.w SonAni_Dash3		; 19 ; $13
	offsetTableEntry.w SonAni_Hang2		; 20 ; $14
	offsetTableEntry.w SonAni_Bubble	; 21 ; $15
	offsetTableEntry.w SonAni_DeathBW	; 22 ; $16
	offsetTableEntry.w SonAni_Drown		; 23 ; $17
	offsetTableEntry.w SonAni_Death		; 24 ; $18
	offsetTableEntry.w SonAni_Hurt		; 25 ; $19
	offsetTableEntry.w SonAni_Hurt		; 26 ; $1A
	offsetTableEntry.w SonAni_Slide		; 27 ; $1B
	offsetTableEntry.w SonAni_Blank		; 28 ; $1C
	offsetTableEntry.w SonAni_Balance3	; 29 ; $1D
	offsetTableEntry.w SonAni_Balance4	; 30 ; $1E
	offsetTableEntry.w SupSonAni_Transform	; 31 ; $1F
	offsetTableEntry.w SonAni_Peelout	; 32 ; $20

SupSonAni_Walk:		dc.b $FF,$77,$78,$79,$7A,$7B,$7C,$75,$76,afEnd
SupSonAni_Run:		dc.b $FF,$B5,$B9,afEnd,afEnd,afEnd,afEnd,afEnd,afEnd,afEnd
SupSonAni_Push:		dc.b $FD,$BD,$BE,$BF,$C0,afEnd,afEnd,afEnd,afEnd,afEnd
SupSonAni_Stand:	dc.b   7,$72,$73,$74,$73,afEnd
SupSonAni_Balance:	dc.b   9,$C2,$C3,$C4,$C3,$C5,$C6,$C7,$C6,afEnd
SupSonAni_Duck:		dc.b   5,$C1,afEnd
SupSonAni_Transform:	dc.b   2,$6D,$6D,$6E,$6E,$6F,$70,$71,$70,$71,$70,$71,$70,$71,afChange,  0
	even
; ---------------------------------------------------------------------------
; Sonic pattern loading subroutine
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


LoadSonicDynPLC:
		moveq	#0,d0
		move.b	obFrame(a0),d0
LoadSonicDynPLC_Frame:
		lea	(SonicDynPLC).l,a2
		lea	(Sonic_LastLoadedDPLC).w,a3
		move.w	#ArtTile_Sonic*tile_size,d4
		move.l	#Art_Sonic,d6
		jmp	(Load_DynamicPLC).l
; End of function LoadSonicDynPLC

