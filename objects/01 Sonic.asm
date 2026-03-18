; ===========================================================================
; ---------------------------------------------------------------------------
; Object 01 - Sonic
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
		move.b	#$13,obHeight(a0)		; this sets Sonic's collision height (2*pixels)
		move.b	#9,obWidth(a0)
		move.l	#Map_Sonic,obMap(a0)
		move.w	#$100,obPriority(a0)
		move.b	#$18,obActWid(a0)
		move.b	#4,obRender(a0)
		move.w	#$600,(Sonic_top_speed).w	; set Sonic's top speed
		move.w	#$C,(Sonic_acceleration).w	; set Sonic's acceleration
		move.w	#$80,(Sonic_deceleration).w	; set Sonic's deceleration
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
		clr.b	objoff_2C(a0)			; flips_remaining
		move.b	#4,objoff_2D(a0)		; flip_speed
		clr.b	(Super_Sonic_flag).w
		move.b	#30,(v_air).w			; v_air(a0)
		subi.w	#$20,obX(a0)
		addq.w	#4,obY(a0)
		clr.w	(Sonic_Pos_Record_Index).w

		move.w	#$40-1,d2
-		bsr.w	Sonic_RecordPos
		clr.w	(a1,d0.w)
		dbf	d2,-
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
		move.w	#1,(Debug_placement_mode).w	; change Sonic into ring/item
		clr.b	(f_lockctrl).w			; unlock control
		rts
; -----------------------------------------------------------------------
loc_FAB0:
		tst.b	(f_lockctrl).w			; are controls locked?
		bne.s	loc_FABC			; if yes, branch
		move.w	(v_jpadhold1).w,(v_jpadholdlogical).w	; copy new held buttons, to enable joypad

loc_FABC:
		btst	#0,(f_playerctrl).w		; is Sonic interacting with another object that holds him in place or controls his movement somehow?
		bne.s	Obj01_ControlsLock		; if yes, branch to skip Sonic's control
		moveq	#0,d0
		move.b	obStatus(a0),d0
		andi.w	#6,d0
		move.w	Obj01_Modes(pc,d0.w),d1
		jsr	Obj01_Modes(pc,d1.w)		; run Sonic's movement control code

Obj01_ControlsLock:
		bsr.s	Sonic_Display
		bsr.w	Sonic_RecordPos
		bsr.w	Sonic_Water
		move.b	(Primary_Angle).w,objoff_36(a0)
		move.b	(Secondary_Angle).w,objoff_37(a0)
		tst.b	(f_wtunnelmode).w
		beq.s	loc_FAFE
		tst.b	obAnim(a0)
		bne.s	loc_FAFE
		move.b	obPrevAni(a0),obAnim(a0)

loc_FAFE:
		bsr.w	Sonic_Animate
		tst.b	(f_playerctrl).w
		bmi.w	LoadSonicDynPLC
		jsr	(TouchResponse).l
		bra.w	LoadSonicDynPLC

; ===========================================================================
; secondary states under state Obj01_Control
Obj01_Modes:	dc.w Obj01_MdNormal-Obj01_Modes
		dc.w Obj01_MdAir-Obj01_Modes
		dc.w Obj01_MdRoll-Obj01_Modes
		dc.w Obj01_MdJump-Obj01_Modes
; ===========================================================================
; Used for when invincibility wears off
MusicList_Sonic:
		dc.b bgm_GHZ
		dc.b bgm_LZ
		dc.b bgm_MZ
		dc.b bgm_SLZ
		dc.b bgm_SYZ
		dc.b bgm_SBZ
		dc.b MusID_MTZ
		even

; ===========================================================================

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


Sonic_Display:
		move.w	flashtime(a0),d0
		beq.s	Obj01_Display
		subq.w	#1,flashtime(a0)
		lsr.w	#3,d0
		bhs.s	Obj01_ChkInvin
; loc_FB2E:
Obj01_Display:
		jsr	(DisplaySprite).l
; loc_FB34:
Obj01_ChkInvin:						; Checks if invincibility has expired and (should) disables it if it has
		tst.b	(v_invinc).w
		beq.s	Obj01_ChkShoes
		tst.w	invtime(a0)
;		beq.s	Obj01_ChkShoes
		bra.s	Obj01_ChkShoes			; invincibility timer is currently disabled
		subq.w	#1,invtime(a0)
		bne.s	Obj01_ChkShoes
		tst.b	(f_lockscreen).w
		bne.s	Obj01_RmvInvin
		cmpi.w	#12,(v_air).w
		blo.s	Obj01_RmvInvin
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
;		cmpi.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w	; Leftover check from Sonic 1 for SBZ3
;		bne.s	loc_FB66
;		moveq	#5,d0

;loc_FB66:
		lea	MusicList_Sonic(pc),a1
		move.b	(a1,d0.w),d0
		jsr	(PlaySound).l
; loc_FB74:
Obj01_RmvInvin:
		clr.b	(v_invinc).w
; loc_FB7A:
Obj01_ChkShoes:
		; Checks if Speed Shoes have expired and disables them if they have.
		tst.b	(v_shoes).w
		beq.s	Obj01_ExitChk
		tst.w	shoetime(a0)
		beq.s	Obj01_ExitChk
		subq.w	#1,shoetime(a0)
		bne.s	Obj01_ExitChk
		move.w	#$600,(Sonic_top_speed).w
		move.w	#$C,(Sonic_acceleration).w
		move.w	#$80,(Sonic_deceleration).w
; Obj01_RmvSpeed:
		clr.b	(v_shoes).w
		move.w	#bgm_Slowdown,d0
		jmp	(PlaySound).l
; ---------------------------------------------------------------------------
; locret_FBAE:
Obj01_ExitChk:
		rts
; End of function Sonic_Display


; ---------------------------------------------------------------------------
; Subroutine to record Sonic's previous positions for invincibility stars
; and input/status flags for Tails' AI to follow
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_FBB2: CopySonicMovesForTails:
Sonic_RecordPos:
		move.w	(Sonic_Pos_Record_Index).w,d0
		lea	(Sonic_Pos_Record_Buf).w,a1
		lea	(a1,d0.w),a1
		move.w	obX(a0),(a1)+
		move.w	obY(a0),(a1)+
		addq.b	#4,(Sonic_Pos_Record_Index+1).w
		lea	(Sonic_Stat_Record_Buf).w,a1
		lea	(a1,d0.w),a1
		move.w	(v_jpadhold1).w,(a1)+
		move.b	obStatus(a0),(a1)+
		move.b	obGfx(a0),(a1)+
		rts
; End of function Sonic_RecordPos

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine for Sonic when he's underwater
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_FC06:
Sonic_Water:
		tst.b	(Water_flag).w
		bne.s	Obj01_InWater
.return:	rts
; ---------------------------------------------------------------------------
; loc_FC0E: Obj01_InLevelWithWater:
Obj01_InWater:
		move.w	(v_waterpos1).w,d0
		cmp.w	obY(a0),d0			; is Sonic above water?
		bge.s	Obj01_OutWater			; if yes, branch

		bset	#6,obStatus(a0)			; set underwater flag
		bne.s	Sonic_Water.return		; if already underwater, branch

		bsr.w	ResumeMusic
		move.b	#id_Obj0A,(v_sonicbubbles).w		; load Obj0A (sonic's breathing bubbles) at $FFFFB340
		move.b	#$81,(v_sonicbubbles+obSubtype).w
		move.w	#$300,(Sonic_top_speed).w
		move.w	#6,(Sonic_acceleration).w
		move.w	#$40,(Sonic_deceleration).w
		asr	obVelX(a0)
		asr	obVelY(a0)			; memory oprands can only be shifted one at a time
		asr	obVelY(a0)
		beq.s	Sonic_Water.return
		move.b	#id_Obj08,(v_splash).w		; splash animation
		move.w	#sfx_Splash,d0			; splash sound
		jmp	(PlaySound_Special).l
; ---------------------------------------------------------------------------
; Obj01_NotInWater:
Obj01_OutWater:
		bclr	#6,obStatus(a0)			; unset underwater flag
		beq.s	Sonic_Water.return		; if already unset, branch

		bsr.w	ResumeMusic
		move.w	#$600,(Sonic_top_speed).w
		move.w	#$C,(Sonic_acceleration).w
		move.w	#$80,(Sonic_deceleration).w
		asl	obVelY(a0)
		tst.w	obVelY(a0)
		beq.w	Sonic_Water.return
		move.b	#id_Obj08,(v_splash).w		; splash animation
		cmpi.w	#-$1000,obVelY(a0)
		bgt.s	loc_FC98
		move.w	#-$1000,obVelY(a0)		; limit upward y velocity exiting the water

loc_FC98:
		move.w	#sfx_Splash,d0			; splash sound
		jmp	(PlaySound_Special).l
; End of function Sonic_Water

; ===========================================================================
; ---------------------------------------------------------------------------
; Start of subroutine Obj01_MdNormal
; Called if Sonic is neither airborne nor rolling this frame
; ---------------------------------------------------------------------------

Obj01_MdNormal:
		bsr.w	Sonic_CheckSpindash
		bsr.w	Sonic_Jump
		bsr.w	Sonic_SlopeResist
		bsr.w	Sonic_Move
		bsr.w	Sonic_Roll
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
		bsr.w	Sonic_ChgJumpDir
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
		bsr.w	Sonic_Jump
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
		bsr.w	Sonic_ChgJumpDir
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
		bne.w	Obj01_Traction
		tst.w	objoff_2E(a0)
		bne.w	Obj01_UpdateSpeedOnGround
		btst	#bitL,(v_jpadholdlogical).w	; is left being pressed?
		beq.s	loc_FD66			; if not, branch
		bsr.w	Sonic_MoveLeft

loc_FD66:
		btst	#bitR,(v_jpadholdlogical).w	; is right being pressed?
		beq.s	loc_FD72			; if not, branch
		bsr.w	Sonic_MoveRight

loc_FD72:
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0				; is Sonic on a slope?
		bne.w	Obj01_UpdateSpeedOnGround	; if yes, branch
		tst.w	obInertia(a0)			; is Sonic moving?
		bne.w	Obj01_UpdateSpeedOnGround	; if yes, branch
		bclr	#5,obStatus(a0)
		cmpi.b	#AniIDSonAni_WallRecoil2,obAnim(a0)
		beq.s	loc_FD9E
		move.b	#AniIDSonAni_Wait,obAnim(a0)	; use "standing" animation

loc_FD9E:
		btst	#3,obStatus(a0)
		beq.s	Sonic_Balance
		moveq	#0,d0
		move.b	standonobject(a0),d0
		lsl.w	#object_size_bits,d0
		lea	(v_player).w,a1			; a1=character
		lea	(a1,d0.w),a1			; a1=object
		tst.b	obStatus(a1)
		bmi.s	Sonic_LookUp
		moveq	#0,d1
		move.b	obActWid(a1),d1
		move.w	d1,d2
		add.w	d2,d2
		subq.w	#4,d2
		add.w	obX(a0),d1
		sub.w	obX(a1),d1
		cmpi.w	#4,d1
		blt.s	loc_FE00
		cmp.w	d2,d1
		bge.s	loc_FDF0
		bra.s	Sonic_LookUp
; ---------------------------------------------------------------------------

Sonic_Balance:
		jsr	(ChkFloorEdge).l
		cmpi.w	#$C,d1
		blt.s	Sonic_LookUp
		cmpi.b	#3,objoff_36(a0)
		bne.s	loc_FDF8

loc_FDF0:
		bclr	#0,obStatus(a0)
		move.b	#AniIDSonAni_Balance,obAnim(a0)
		bra.s	Obj01_UpdateSpeedOnGround
; ---------------------------------------------------------------------------

loc_FDF8:
		cmpi.b	#3,objoff_37(a0)
		bne.s	Sonic_LookUp

loc_FE00:
		bset	#0,obStatus(a0)
		move.b	#AniIDSonAni_Balance,obAnim(a0)
		bra.s	Obj01_UpdateSpeedOnGround
; ---------------------------------------------------------------------------

Sonic_LookUp:
		btst	#bitUp,(v_jpadholdlogical).w	; is up being pressed?
		beq.s	Sonic_Duck			; if not, branch
		move.b	#AniIDSonAni_LookUp,obAnim(a0)	; use "looking up" animation
		bra.s	Obj01_UpdateSpeedOnGround
; ---------------------------------------------------------------------------

Sonic_Duck:
		btst	#bitDn,(v_jpadholdlogical).w	; is down being pressed?
		beq.s	Obj01_UpdateSpeedOnGround	; if not, branch
		move.b	#AniIDSonAni_Duck,obAnim(a0)	; use "ducking" animation

; ---------------------------------------------------------------------------
; updates Sonic's speed on the ground
; ---------------------------------------------------------------------------
; loc_FE2C:
Obj01_UpdateSpeedOnGround:
		move.b	(v_jpadholdlogical).w,d0
		andi.b	#btnL|btnR,d0	; is left/right being pressed?
		bne.s	Obj01_Traction			; if yes, branch
		move.w	obInertia(a0),d0
		beq.s	Obj01_Traction
		bmi.s	Obj01_SettleLeft

; slow down when facing right and not pressing a direction
; Obj01_SettleRight:
		sub.w	d5,d0
		bhs.s	loc_FE46
		clr.w	d0

loc_FE46:
		move.w	d0,obInertia(a0)
		bra.s	Obj01_Traction
; ---------------------------------------------------------------------------
; slow down when facing left and not pressing a direction
; loc_FE4C:
Obj01_SettleLeft:
		add.w	d5,d0
		bhs.s	+
		clr.w	d0
+
		move.w	d0,obInertia(a0)

; increase or decrease speed on the ground
; loc_FE58:
Obj01_Traction:
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
Obj01_CheckWallsOnGround:
		move.b	obAngle(a0),d0
		addi.b	#$40,d0
		bmi.s	.return
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
		bset	#5,obStatus(a0)
		clr.w	obInertia(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_FED2:
		sub.w	d1,obVelY(a0)
		rts
; ---------------------------------------------------------------------------

loc_FED8:
		sub.w	d1,obVelX(a0)
		bset	#5,obStatus(a0)
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
		move.w	(Sonic_top_speed).w,d6
		asl.w	#1,d6
		move.w	(Sonic_acceleration).w,d5
		asr.w	#1,d5
		moveq	#20,d4
		asr.w	#2,d4
		tst.b	(f_slidemode).w
		bne.w	loc_1008A
		tst.w	objoff_2E(a0)
		bne.s	loc_10046
		btst	#bitL,(v_jpadholdlogical).w
		beq.s	loc_1003A
		bsr.w	Sonic_RollLeft

loc_1003A:
		btst	#bitR,(v_jpadholdlogical).w
		beq.s	loc_10046
		bsr.w	Sonic_RollRight

loc_10046:
		move.w	obInertia(a0),d0
		beq.s	loc_10068
		bmi.s	loc_1005C
		sub.w	d5,d0
		bhs.s	loc_10056
		clr.w	d0

loc_10056:
		move.w	d0,obInertia(a0)
		bra.s	loc_10068
; ---------------------------------------------------------------------------

loc_1005C:
		add.w	d5,d0
		bhs.s	loc_10064
		clr.w	d0

loc_10064:
		move.w	d0,obInertia(a0)

loc_10068:
		tst.w	obInertia(a0)
		bne.s	loc_1008A
		bclr	#2,obStatus(a0)
		move.b	#$13,obHeight(a0)
		move.b	#9,obWidth(a0)
		move.b	#5,obAnim(a0)
		subq.w	#5,obY(a0)

loc_1008A:
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		cmpi.w	#$1000,d1
		ble.s	loc_100AE
		move.w	#$1000,d1

loc_100AE:
		cmpi.w	#-$1000,d1
		bge.s	loc_100B8
		move.w	#-$1000,d1

loc_100B8:
		move.w	d1,obVelX(a0)
		bra.w	Obj01_CheckWallsOnGround
; End of function Sonic_RollSpeed


; =============== S U B R O U T I N E =======================================


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


Sonic_ChgJumpDir:
		move.w	(Sonic_top_speed).w,d6
		move.w	(Sonic_acceleration).w,d5
		asl.w	#1,d5
		btst	#4,obStatus(a0)
		bne.s	loc_10150
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

loc_10150:
		cmpi.w	#$60,(Camera_Y_pos_bias).w
		beq.s	loc_10162
		bhs.s	loc_1015E
		addq.w	#4,(Camera_Y_pos_bias).w

loc_1015E:
		subq.w	#2,(Camera_Y_pos_bias).w

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
; End of function Sonic_ChgJumpDir


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
		move.w	obInertia(a0),d0
		bpl.s	loc_10220
		neg.w	d0

loc_10220:
		cmpi.w	#$80,d0
		blo.s	Obj01_NoRoll
		move.b	(v_jpadholdlogical).w,d0
		andi.b	#btnL|btnR,d0
		bne.s	Obj01_NoRoll
		btst	#bitDn,(v_jpadholdlogical).w
		bne.s	loc_1023A

Obj01_NoRoll:
		rts
; ---------------------------------------------------------------------------

loc_1023A:
		btst	#2,obStatus(a0)
		beq.s	Obj01_DoRoll
		rts
; ---------------------------------------------------------------------------

Obj01_DoRoll:
		bset	#2,obStatus(a0)
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		addq.w	#5,obY(a0)
		move.w	#sfx_Roll,d0
		jsr	(PlaySound_Special).l
		tst.w	obInertia(a0)
		bne.s	locret_10276
		move.w	#$200,obInertia(a0)

locret_10276:
		rts
; End of function Sonic_Roll


; =============== S U B R O U T I N E =======================================


Sonic_Jump:
		move.b	(v_jpadpresslogical).w,d0
		andi.b	#btnABC,d0
		beq.w	locret_1031C
		moveq	#0,d0
		move.b	obAngle(a0),d0
		addi.b	#$80,d0
		bsr.w	sub_13102
		cmpi.w	#6,d1
		blt.w	locret_1031C
		move.w	#$680,d2
		btst	#6,obStatus(a0)
		beq.s	loc_102AA
		move.w	#$380,d2

loc_102AA:
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
		move.b	#1,objoff_3C(a0)
		clr.b	objoff_38(a0)
		move.w	#sfx_Jump,d0
		jsr	(PlaySound_Special).l
		move.b	#$13,obHeight(a0)
		move.b	#9,obWidth(a0)
		btst	#2,obStatus(a0)
		bne.s	loc_1031E
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		bset	#2,obStatus(a0)
		addq.w	#5,obY(a0)

locret_1031C:
		rts
; ---------------------------------------------------------------------------

loc_1031E:
		bset	#4,obStatus(a0)
		rts
; End of function Sonic_Jump


; =============== S U B R O U T I N E =======================================


Sonic_JumpHeight:
		tst.b	objoff_3C(a0)
		beq.s	loc_10352
		move.w	#-$400,d1
		btst	#6,obStatus(a0)
		beq.s	loc_1033C
		move.w	#-$200,d1

loc_1033C:
		cmp.w	obVelY(a0),d1
		ble.s	locret_10350
		move.b	(v_jpadholdlogical).w,d0
		andi.b	#btnABC,d0
		bne.s	locret_10350
		move.w	d1,obVelY(a0)

locret_10350:
		rts
; ---------------------------------------------------------------------------

loc_10352:
		cmpi.w	#-$FC0,obVelY(a0)
		bge.s	locret_10360
		move.w	#-$FC0,obVelY(a0)

locret_10360:
		rts
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
		bne.s	locret_10394
		move.b	(v_jpadpresslogical).w,d0
		andi.b	#btnABC,d0
		beq.w	locret_10394
		move.b	#AniIDSonAni_Spindash,obAnim(a0)
		move.w	#sfx_Roll,d0
		jsr	(PlaySound_Special).l
		addq.l	#4,sp
		move.b	#1,spindash_flag(a0)

locret_10394:
		rts
; ===========================================================================
; loc_10396:
Sonic_UpdateSpindash:
		move.b	(v_jpadholdlogical).w,d0
		btst	#bitDn,d0
		bne.s	Sonic_ChargingSpindash

		; unleash the charged spindash and start rolling quickly:
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		addq.w	#5,obY(a0)			; add the difference between Sonic's rolling and standing heights
		clr.b	spindash_flag(a0)
	if FixBugs
		; To fix a bug in 'ScrollHoriz', we need an extra variable, so this
		; code has been modified to make the delay value only a single byte.
		; This is used by the fixed 'ScrollHoriz'.
		move.b	#$20,(Horiz_scroll_delay_val).w
		; Back up the position array index for later.
		move.b	(Sonic_Pos_Record_Index+1).w,(Horiz_scroll_delay_val+1).w
	else
		move.w	#$2000,(Horiz_scroll_delay_val).w
	endif
		move.w	#$800,obInertia(a0)
		btst	#0,obStatus(a0)
		beq.s	loc_103D4
		neg.w	obInertia(a0)

loc_103D4:
		bset	#2,obStatus(a0)
		rts
; ===========================================================================
; loc_103DC:
Sonic_ChargingSpindash:
		move.b	(v_jpadpresslogical).w,d0
		andi.b	#btnABC,d0
		beq.w	loc_103EA
		nop

loc_103EA:
		addq.l	#4,sp
		rts
; End of function Sonic_CheckSpindash


; =============== S U B R O U T I N E =======================================


Sonic_SlopeResist:
		move.b	obAngle(a0),d0
		addi.b	#$60,d0
		cmpi.b	#$C0,d0
		bhs.s	locret_10422
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	#$20,d0
		asr.l	#8,d0
		tst.w	obInertia(a0)
		beq.s	locret_10422
		bmi.s	loc_1041E
		tst.w	d0
		beq.s	locret_1041C
		add.w	d0,obInertia(a0)

locret_1041C:
		rts
; ---------------------------------------------------------------------------

loc_1041E:
		add.w	d0,obInertia(a0)

locret_10422:
		rts
; End of function Sonic_SlopeResist


; =============== S U B R O U T I N E =======================================


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
		nop
		tst.b	objoff_38(a0)
		bne.s	locret_1049A
		tst.w	objoff_2E(a0)
		bne.s	loc_1049C
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0
		beq.s	locret_1049A
		move.w	obInertia(a0),d0
		bpl.s	loc_10484
		neg.w	d0

loc_10484:
		cmpi.w	#$280,d0
		bhs.s	locret_1049A
		clr.w	obInertia(a0)
		bset	#1,obStatus(a0)
		move.w	#$1E,objoff_2E(a0)

locret_1049A:
		rts
; ---------------------------------------------------------------------------

loc_1049C:
		subq.w	#1,objoff_2E(a0)
		rts
; End of function Sonic_SlopeRepel


; =============== S U B R O U T I N E =======================================


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
		move.b	objoff_27(a0),d0
		beq.s	.return
		tst.w	obInertia(a0)
		bmi.s	loc_104E0
		move.b	objoff_2D(a0),d1
		add.b	d1,d0
		bhs.s	+
		subq.b	#1,objoff_2C(a0)
		bhs.s	+
		moveq	#0,d0
		move.b	d0,objoff_2C(a0)
+
		move.b	d0,objoff_27(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_104E0:
		move.b	objoff_2D(a0),d1
		sub.b	d1,d0
		bhs.s	loc_104F6
		subq.b	#1,objoff_2C(a0)
		bhs.s	loc_104F6
		moveq	#0,d0
		move.b	d0,objoff_2C(a0)

loc_104F6:
		move.b	d0,objoff_27(a0)
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
		move.w	obVelX(a0),d1
		move.w	obVelY(a0),d2
		jsr	(CalcAngle).l
		subi.b	#$20,d0
		andi.b	#$C0,d0
		cmpi.b	#$40,d0
		beq.w	loc_105E4
		cmpi.b	#$80,d0
		beq.w	loc_10646
		cmpi.b	#$C0,d0
		beq.w	loc_106A2
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
		move.b	#AniIDSonAni_Walk,obAnim(a0)
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

loc_105E4:
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
		sub.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_10618:
		tst.w	obVelY(a0)
		bmi.s	.return
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Sonic_ResetOnFloor
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_10646:
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

loc_106A2:
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
		tst.w	obVelY(a0)
		bmi.s	.return
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Sonic_ResetOnFloor
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; End of function Sonic_DoLevelCollision


; =============== S U B R O U T I N E =======================================


Sonic_ResetOnFloor:
		btst	#4,obStatus(a0)
		beq.s	loc_10712
		nop
		nop
		nop

loc_10712:
		bclr	#5,obStatus(a0)
		bclr	#1,obStatus(a0)
		bclr	#4,obStatus(a0)
		btst	#2,obStatus(a0)
		beq.s	loc_10748
		bclr	#2,obStatus(a0)
		move.b	#$13,obHeight(a0)
		move.b	#9,obWidth(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		subq.w	#5,obY(a0)

loc_10748:
		clr.b	objoff_3C(a0)
		clr.w	(v_itembonus).w
		clr.b	objoff_27(a0)
		rts
; End of function Sonic_ResetOnFloor

; ---------------------------------------------------------------------------

Obj01_Hurt:
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
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		subq.b	#2,obRoutine(a0)
		move.w	#120,flashtime(a0)
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
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#$100,d0
		cmp.w	obY(a0),d0
		bge.w	Obj01_ResetLevel.return
		move.w	#-$38,obVelY(a0)
		addq.b	#2,obRoutine(a0)
		clr.b	(f_timecount).w
		addq.b	#1,(f_lifecount).w
		subq.b	#1,(v_lives).w
		bne.s	+
		clr.w	objoff_3A(a0)
		_move.b	#id_Obj98,(v_gameovertext1).w
		_move.b	#id_Obj98,(v_gameovertext2).w
		move.b	#1,(v_gameovertext2+obFrame).w
		clr.b	(f_timeover).w
		move.w	#bgm_GameOver,d0
		jsr	(PlaySound).l
		moveq	#plcid_GameOver,d0
		jmp	(LoadPLC).l
; ---------------------------------------------------------------------------
+
		move.w	#60,objoff_3A(a0)
		tst.b	(f_timeover).w
		beq.s	Obj01_ResetLevel.return
		clr.w	objoff_3A(a0)
		_move.b	#id_Obj98,(v_gameovertext1).w
		_move.b	#id_Obj98,(v_gameovertext2).w
		move.b	#2,(v_gameovertext1+obFrame).w
		move.b	#3,(v_gameovertext2+obFrame).w
		move.w	#bgm_GameOver,d0
		jsr	(PlaySound).l
		moveq	#plcid_GameOver,d0
		jmp	(LoadPLC).l
; End of function Sonic_GameOver

; ---------------------------------------------------------------------------

Obj01_ResetLevel:
		tst.w	objoff_3A(a0)
		beq.s	.return
		subq.w	#1,objoff_3A(a0)
		bne.s	.return
		move.w	#1,(Level_Inactive_flag).w

.return:
		rts

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
		bmi.s	SAnim_Do2		; if animation is walk/run/roll/jump, branch
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		subq.b	#1,obTimeFrame(a0)	; subtract 1 from frame duration
		bpl.s	SAnim_Delay		; if time remains, branch
		move.b	d0,obTimeFrame(a0)	; load frame duration
		; fall through
; -------------------------------------------------------------------------

SAnim_WalkRun:
		moveq	#0,d1
		move.b	obAniFrame(a0),d1	; load current frame number
		move.b	1(a1,d1.w),d0		; read sprite number from script
		beq.s	SAnim_Next		; If it's a frame ID, branch
		bpl.s	SAnim_Next
		cmpi.b	#$FD,d0			; is it a flag from FC to FF?
;		bhs.s	SAnim_End_FF		; MJ: if so, branch to flag routines
		bge.s	SAnim_End_FF		; MJ: if so, branch to flag routines

SAnim_Next:
		move.b	d0,obFrame(a0)		; load sprite number
		addq.b	#1,obAniFrame(a0)	; next frame number

SAnim_Delay:
		rts
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

SAnim_End:
		rts
; ---------------------------------------------------------------------------

SAnim_Do2:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	SAnim_End
		addq.b	#1,d0
		bne.w	loc_10A44
		moveq	#0,d0
		move.b	objoff_27(a0),d0
		bne.w	loc_109EA
		moveq	#0,d1
		move.b	obAngle(a0),d0
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	loc_10984
		not.b	d0

loc_10984:
		addi.b	#$10,d0
		bpl.s	loc_1098C
		moveq	#3,d1

loc_1098C:
		andi.b	#$FC,obRender(a0)
		eor.b	d1,d2
		or.b	d2,obRender(a0)
		btst	#5,obStatus(a0)
		bne.w	loc_10A88
		lsr.b	#4,d0
		andi.b	#6,d0
		move.w	obInertia(a0),d2
		bpl.s	loc_109B0
		neg.w	d2

loc_109B0:
		lea	SonicAni_Run(pc),a1
		cmpi.w	#$600,d2
		bhs.s	loc_109C2
		lea	SonicAni_Walk(pc),a1

loc_109C2:
		move.b	d0,d1
		lsr.b	#1,d1
		add.b	d1,d0
		add.b	d0,d0
		add.b	d0,d0
		move.b	d0,d3
		neg.w	d2
		addi.w	#$800,d2
		bpl.s	loc_109D8
		moveq	#0,d2

loc_109D8:
		lsr.w	#8,d2
		lsr.w	#1,d2	; divide by 512
		move.b	d2,obTimeFrame(a0)
		bsr.w	SAnim_WalkRun
		add.b	d3,obFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_109EA:
		move.b	objoff_27(a0),d0
		moveq	#0,d1
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	loc_10A1E
		andi.b	#$FC,obRender(a0)
		moveq	#0,d2
		or.b	d2,obRender(a0)
		addi.b	#$B,d0
		divu.w	#$16,d0
		addi.b	#$9B,d0
		move.b	d0,obFrame(a0)
		clr.b	obTimeFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_10A1E:
		moveq	#3,d2
		andi.b	#$FC,obRender(a0)
		or.b	d2,obRender(a0)
		neg.b	d0
		addi.b	#$8F,d0
		divu.w	#$16,d0
		addi.b	#$9B,d0
		move.b	d0,obFrame(a0)
		clr.b	obTimeFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_10A44:
		addq.b	#1,d0
		bne.s	loc_10A88
		move.w	obInertia(a0),d2
		bpl.s	loc_10A50
		neg.w	d2

loc_10A50:
		lea	SonicAni_Roll2(pc),a1
		cmpi.w	#$600,d2
		bhs.s	loc_10A62
		lea	SonicAni_Roll(pc),a1

loc_10A62:
		neg.w	d2
		addi.w	#$400,d2
		bpl.s	loc_10A6C
		moveq	#0,d2

loc_10A6C:
		lsr.w	#8,d2
		move.b	d2,obTimeFrame(a0)
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		bra.w	SAnim_WalkRun
; ---------------------------------------------------------------------------

loc_10A88:
		move.w	obInertia(a0),d2
		bmi.s	loc_10A90
		neg.w	d2

loc_10A90:
		addi.w	#$800,d2
		bpl.s	loc_10A98
		moveq	#0,d2

loc_10A98:
		lsr.w	#6,d2
		move.b	d2,obTimeFrame(a0)
		lea	SonicAni_Push(pc),a1
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		bra.w	SAnim_WalkRun
; End of function Sonic_Animate
; ===========================================================================
; ---------------------------------------------------------------------------
; Animation script - Sonic
; ---------------------------------------------------------------------------
SonicAniData:	dc.w SonicAni_Walk-SonicAniData
		dc.w SonicAni_Run-SonicAniData
		dc.w SonicAni_Roll-SonicAniData
		dc.w SonicAni_Roll2-SonicAniData
		dc.w SonicAni_Push-SonicAniData
		dc.w SonicAni_Wait-SonicAniData
		dc.w SonicAni_Balance-SonicAniData
		dc.w SonicAni_LookUp-SonicAniData
		dc.w SonicAni_Duck-SonicAniData
		dc.w SonicAni_Spindash-SonicAniData
		dc.w SonicAni_WallRecoil1-SonicAniData
		dc.w SonicAni_WallRecoil2-SonicAniData
		dc.w SonicAni_0C-SonicAniData
		dc.w SonicAni_Stop-SonicAniData
		dc.w SonicAni_Float1-SonicAniData
		dc.w SonicAni_Float2-SonicAniData
		dc.w SonicAni_Spring-SonicAniData
		dc.w SonicAni_S1LZHang-SonicAniData
		dc.w SonicAni_Unused12-SonicAniData
		dc.w SonicAni_Unused13-SonicAniData
		dc.w SonicAni_Unused14-SonicAniData
		dc.w SonicAni_Bubble-SonicAniData
		dc.w SonicAni_DeathBW-SonicAniData
		dc.w SonicAni_Drown-SonicAniData
		dc.w SonicAni_Death-SonicAniData
		dc.w SonicAni_Unused19-SonicAniData
		dc.w SonicAni_Hurt-SonicAniData
		dc.w SonicAni_S1LZSlide-SonicAniData
		dc.w SonicAni_Blank-SonicAniData
		dc.w SonicAni_Float3-SonicAniData
		dc.w SonicAni_1E-SonicAniData
SonicAni_Walk:		dc.b $FF,$10,$11,$12,$13,$14,$15,$16,$17, $C, $D, $E, $F,$FF
SonicAni_Run:		dc.b $FF,$3C,$3D,$3E,$3F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
SonicAni_Roll:		dc.b $FE,$6C,$70,$6D,$70,$6E,$70,$6F,$70,$FF
SonicAni_Roll2:		dc.b $FE,$6C,$70,$6D,$70,$6E,$70,$6F,$70,$FF
SonicAni_Push:		dc.b $FD,$77,$78,$79,$7A,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
SonicAni_Wait:		dc.b   7,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
			dc.b   1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2
			dc.b   3,  3,  3,  4,  4,  5,  5,$FE,  4
SonicAni_Balance:	dc.b	7,$89,$8A,$FF
SonicAni_LookUp:	dc.b   5,  6,  7,$FE,  1
SonicAni_Duck:		dc.b   5,$7F,$80,$FE,  1
SonicAni_Spindash:	dc.b	 0,$71,$72,$71,$73,$71,$74,$71,$75,$71,$76,$71,$FF
SonicAni_WallRecoil1:	dc.b $3F,$82,$FF
SonicAni_WallRecoil2:	dc.b   7, 8, 8, 9,$FD,	5
SonicAni_0C:		dc.b   7,  9,$FD,  5
SonicAni_Stop:		dc.b   3,$81,$82,$83,$84,$85,$86,$87,$88,$FE,  2
SonicAni_Float1:	dc.b   7,$94,$96,$FF
SonicAni_Float2:	dc.b   7,$91,$92,$93,$94,$95,$FF
SonicAni_Spring:	dc.b $2F,$7E,$FD,  0
SonicAni_S1LZHang:	dc.b	 5,$8F,$90,$FF
SonicAni_Unused12:	dc.b	$F,$43,$43,$43,$FE,  1
SonicAni_Unused13:	dc.b	$F,$43,$44,$FE,	 1
SonicAni_Unused14:	dc.b $3F,$49,$FF
SonicAni_Bubble:	dc.b  $B,$97,$97,$12,$13,$FD,  0
SonicAni_DeathBW:	dc.b $20,$9A,$FF
SonicAni_Drown:		dc.b $20,$99,$FF
SonicAni_Death:		dc.b $20,$98,$FF
SonicAni_Unused19:	dc.b	 3,$4E,$4F,$50,$51,$52,	 0,$FE,	 1
SonicAni_Hurt:		dc.b $40,$8D,$FF
SonicAni_S1LZSlide:	dc.b	  9,$8D,$8E,$FF
SonicAni_Blank:		dc.b $77,  0,$FD,  0
SonicAni_Float3:	dc.b   3,$91,$92,$93,$94,$95,$FF
SonicAni_1E:		dc.b   3,$3C,$FD,  0
		even
; ---------------------------------------------------------------------------
; Sonic pattern loading subroutine
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


LoadSonicDynPLC:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		cmp.b	(Sonic_LastLoadedDPLC).w,d0
		beq.s	LoadSonicDynPLC.return
		move.b	d0,(Sonic_LastLoadedDPLC).w
		lea	(SonicDynPLC).l,a2
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d5
		subq.w	#1,d5
		bmi.s	LoadSonicDynPLC.return
		move.w	#ArtTile_Sonic*tile_size,d4

.SPLC_ReadEntry:
		moveq	#0,d1
		move.w	(a2)+,d1
		move.w	d1,d3
		lsr.w	#8,d3
		andi.w	#$F0,d3
		addi.w	#$10,d3
		andi.w	#$FFF,d1
		lsl.l	#5,d1
		addi.l	#Art_Sonic,d1
		move.w	d4,d2
		add.w	d3,d4
		add.w	d3,d4
		jsr	(QueueDMATransfer).l
		dbf	d5,.SPLC_ReadEntry

.return:
		rts
; End of function LoadSonicDynPLC

