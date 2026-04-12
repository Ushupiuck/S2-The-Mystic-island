;----------------------------------------------------------------------------
; Object 02 - Tails
;----------------------------------------------------------------------------

Obj02:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj02_Index(pc,d0.w),d1
		jmp	Obj02_Index(pc,d1.w)
; ===========================================================================
Obj02_Index:	dc.w Obj02_Init-Obj02_Index		; 0
		dc.w Obj02_Control-Obj02_Index		; 2
		dc.w Obj02_Hurt-Obj02_Index		; 4
		dc.w Obj02_Dead-Obj02_Index		; 6
		dc.w Obj02_ResetLevel-Obj02_Index	; 8
; ===========================================================================
; Obj02_Main:
Obj02_Init:
		addq.b	#2,obRoutine(a0)
		move.b	#$F,obHeight(a0)
		move.b	#9,obWidth(a0)
		move.l	#Map_Tails,obMap(a0)
		move.w	#make_art_tile(ArtTile_Tails,0,0),obGfx(a0)
		move.w	#$100,obPriority(a0)
		move.b	#$18,obActWid(a0)
		move.b	#$84,obRender(a0)
		move.w	#$600,(Tails_top_speed).w
		move.w	#$C,(Tails_acceleration).w
		move.w	#$80,(Tails_deceleration).w
		move.b	#$C,obTopSolidBit(a0)
		move.b	#$D,obLRBSolidBit(a0)
		clr.b	objoff_2C(a0)
		move.b	#4,objoff_2D(a0)
		move.b	#id_Obj05,(v_player2tails).w		; load Tails' tails at $B1C0

; ---------------------------------------------------------------------------
; Normal state for Tails
; ---------------------------------------------------------------------------
Obj02_Control:
		bsr.w	Tails_Control
		btst	#0,(f_playerctrl).w		; is Tails interacting with another object that holds him in place or controls his movement somehow?
		bne.s	Obj02_ControlsLock		; if yes, branch to skip Tails' control
		moveq	#0,d0
		move.b	obStatus(a0),d0
		andi.w	#6,d0
		move.w	Obj02_Modes(pc,d0.w),d1
		jsr	Obj02_Modes(pc,d1.w)		; run Tails' movement code

Obj02_ControlsLock:
		bsr.s	Tails_Display
		bsr.w	RecordTailsMoves
		move.b	(Primary_Angle).w,objoff_36(a0)
		move.b	(Secondary_Angle).w,objoff_37(a0)
		bsr.w	Tails_Animate
		tst.b	(f_playerctrl).w
		bmi.s	loc_10CFC
		jsr	(TouchResponse).l

loc_10CFC:
		bra.w	LoadTailsDynPLC
; ===========================================================================
; secondary states under state Obj02_Control
Obj02_Modes:	dc.w Obj02_MdNormal-Obj02_Modes
		dc.w Obj02_MdJump-Obj02_Modes
		dc.w Obj02_MdRoll-Obj02_Modes
		dc.w Obj02_MdJump2-Obj02_Modes
; ===========================================================================
; Used for when invincibility wears off; same as Sonic's...
MusicList_Tails:
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


Tails_Display:
		move.w	flashtime(a0),d0
		beq.s	Obj02_Display
		subq.w	#1,flashtime(a0)
		lsr.w	#3,d0
		bhs.s	Obj02_ChkInvinc
; loc_10D1E:
Obj02_Display:
		jsr	(DisplaySprite).l
; loc_10D24:
Obj02_ChkInvinc:
		; checks if invincibility has expired and disables it if it has,
		; and unlike Sonic's version, functions normally...
		tst.b	(v_invinc).w
		beq.s	Obj02_ChkShoes
		tst.w	invtime(a0)
		beq.s	Obj02_ChkShoes
		subq.w	#1,invtime(a0)
		bne.s	Obj02_ChkShoes
		tst.b	(f_lockscreen).w
		bne.s	Obj02_RmvInvin
		cmpi.w	#12,(v_air).w
		blo.s	Obj02_RmvInvin
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
;		cmpi.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w
;		bne.s	loc_10D54
;		moveq	#5,d0

;loc_10D54:
		lea	MusicList_Tails(pc),a1
		move.b	(a1,d0.w),d0
		jsr	(PlaySound).l
; loc_10D62:
Obj02_RmvInvin:
		clr.b	(v_invinc).w
; loc_10D68:
Obj02_ChkShoes:
		; Checks if Speed Shoes have expired and disables them if they have
		tst.b	(v_shoes).w
		beq.s	Obj02_ExitChk
		tst.w	shoetime(a0)
		beq.s	Obj02_ExitChk
		subq.w	#1,shoetime(a0)
		bne.s	Obj02_ExitChk
		move.w	#$600,(Tails_top_speed).w
		move.w	#$C,(Tails_acceleration).w
		move.w	#$80,(Tails_deceleration).w
; Obj02_RmvSpeed:
		clr.b	(v_shoes).w
		move.w	#bgm_Slowdown,d0		; slow down tempo
		jmp	(PlaySound).l
; ===========================================================================
; locret_10D9C:
Obj02_ExitChk:
		rts
; End of function Tails_Display


; =============== S U B R O U T I N E =======================================


Tails_Control:
		move.b	(v_jpadhold2).w,d0
		andi.b	#btnUp+btnDn+btnL+btnR+btnABC,d0
		beq.s	TailsC_NoKeysPressed
		clr.w	(word_F700).w
		move.w	#$12C,(Tails_control_counter).w
		rts
; ---------------------------------------------------------------------------

TailsC_NoKeysPressed:
		tst.w	(Tails_control_counter).w
		beq.s	TailsC_DoControl
		subq.w	#1,(Tails_control_counter).w
		rts
; ---------------------------------------------------------------------------

TailsC_DoControl:
		move.w	(Tails_CPU_routine).w,d0
		move.w	TailsC_Index(pc,d0.w),d0
		jmp	TailsC_Index(pc,d0.w)
; End of function Tails_Control

; ---------------------------------------------------------------------------
TailsC_Index:	dc.w TailsC_00-TailsC_Index		; 0
		dc.w TailsC_02-TailsC_Index		; 2
		dc.w TailsC_04-TailsC_Index		; 4
		dc.w TailsC_CopySonicMoves-TailsC_Index	; 6
; ---------------------------------------------------------------------------
 ; They're all dummy entries it seems
TailsC_00:
		move.w	#6,(Tails_CPU_routine).w
		rts
; ---------------------------------------------------------------------------

TailsC_02:
		move.w	#6,(Tails_CPU_routine).w
		rts
; ---------------------------------------------------------------------------
	;	move.w	#$40,(word_F706).w
	;	move.w	#4,(Tails_CPU_routine).w

TailsC_04:
		move.w	#6,(Tails_CPU_routine).w
		rts
; ---------------------------------------------------------------------------

TailsC_CopySonicMoves:
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		bpl.s	loc_10E38
		neg.w	d0

loc_10E38:
		cmpi.w	#$C0,d0
		blo.s	loc_10E40
		nop

loc_10E40:
		lea	(Sonic_Pos_Record_Buf).w,a1
		moveq	#$10,d1
		lsl.b	#2,d1
		addq.b	#4,d1
		move.w	(Sonic_Pos_Record_Index).w,d0
		sub.b	d1,d0
		lea	(Sonic_Stat_Record_Buf).w,a1
		move.w	(a1,d0.w),(v_jpadhold2).w
		rts

; =============== S U B R O U T I N E =======================================


RecordTailsMoves:
		move.w	(Tails_Pos_Record_Index).w,d0
		lea	(Tails_Pos_Record_Buf).w,a1
		lea	(a1,d0.w),a1
		move.w	obX(a0),(a1)+
		move.w	obY(a0),(a1)+
		addq.b	#4,(Tails_Pos_Record_Index+1).w
		rts
; End of function RecordTailsMoves

; ---------------------------------------------------------------------------

Obj02_MdNormal:
		bsr.w	Tails_CheckSpindash
		bsr.w	Tails_Jump
		bsr.w	Tails_SlopeResist
		bsr.w	Tails_Move
		bsr.w	Tails_Roll
		bsr.w	Tails_LevelBoundaries
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		bsr.w	AnglePos
		bra.w	Tails_SlopeRepel
; ---------------------------------------------------------------------------

Obj02_MdJump:
		bsr.w	Tails_JumpHeight
		bsr.w	Tails_ChgJumpDir
		bsr.w	Tails_LevelBoundaries
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		btst	#6,obStatus(a0)
		beq.s	loc_10EC0
		subi.w	#$28,obVelY(a0)

loc_10EC0:
		bsr.w	Tails_JumpAngle
		bra.w	Tails_DoLevelCollision
; ---------------------------------------------------------------------------

Obj02_MdRoll:
		bsr.w	Tails_Jump
		bsr.w	Tails_RollRepel
		bsr.w	Tails_RollSpeed
		bsr.w	Tails_LevelBoundaries
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		bsr.w	AnglePos
		bra.w	Tails_SlopeRepel
; ---------------------------------------------------------------------------

Obj02_MdJump2:
		bsr.w	Tails_JumpHeight
		bsr.w	Tails_ChgJumpDir
		bsr.w	Tails_LevelBoundaries
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		btst	#6,obStatus(a0)
		beq.s	loc_10F0A
		subi.w	#$28,obVelY(a0)

loc_10F0A:
		bsr.w	Tails_JumpAngle
		bra.w	Tails_DoLevelCollision

; =============== S U B R O U T I N E =======================================


Tails_Move:	; TODO: Uncomment these lines and implement this proper, alike Sonic 2
		move.w	(Tails_top_speed).w,d6
		move.w	(Tails_acceleration).w,d5
		move.w	(Tails_deceleration).w,d4
		tst.b	(f_slidemode).w
		bne.w	loc_11026
		tst.w	objoff_2E(a0)
		bne.w	loc_10FFA
		btst	#bitL,(v_jpadhold2).w
		beq.s	loc_10F3C
		bsr.w	Tails_MoveLeft

loc_10F3C:
		btst	#bitR,(v_jpadhold2).w
		beq.s	loc_10F48
		bsr.w	Tails_MoveRight

loc_10F48:
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0
		bne.w	loc_10FFA
		tst.w	obInertia(a0)
		bne.w	loc_10FFA
		bclr	#5,obStatus(a0)
		move.b	#AniIDSonAni_Wait,obAnim(a0)
		btst	#3,obStatus(a0)
		beq.s	Tails_Balance
		moveq	#0,d0
		move.b	standonobject(a0),d0
		lsl.w	#object_size_bits,d0
		lea	(v_player).w,a1
		lea	(a1,d0.w),a1
		tst.b	obStatus(a1)
		bmi.s	Tails_LookUp
		moveq	#0,d1
		move.b	obActWid(a1),d1
		move.w	d1,d2
		add.w	d2,d2
		subq.w	#4,d2
		add.w	obX(a0),d1
		sub.w	obX(a1),d1
		cmpi.w	#4,d1
		blt.s	loc_10FCE
		cmp.w	d2,d1
		bge.s	loc_10FBE
		bra.s	Tails_LookUp
; ---------------------------------------------------------------------------

Tails_Balance:
		jsr	(ObjHitFloor).l
		cmpi.w	#$C,d1
		blt.s	Tails_LookUp
		cmpi.b	#3,objoff_36(a0)
		bne.s	loc_10FC6

loc_10FBE:
		bclr	#0,obStatus(a0)
		bra.s	loc_10FD4
; ---------------------------------------------------------------------------

loc_10FC6:
		cmpi.b	#3,objoff_37(a0)
		bne.s	Tails_LookUp

loc_10FCE:
		bset	#0,obStatus(a0)

loc_10FD4:
		move.b	#AniIDSonAni_Balance,obAnim(a0)
		bra.s	loc_10FFA
; ---------------------------------------------------------------------------

Tails_LookUp:
		btst	#bitUp,(v_jpadhold2).w
		beq.s	Tails_Duck
		move.b	#AniIDSonAni_LookUp,obAnim(a0)
		bra.s	loc_10FFA
; ---------------------------------------------------------------------------

Tails_Duck:
		btst	#bitDn,(v_jpadhold2).w
		beq.s	loc_10FFA
		move.b	#AniIDSonAni_Duck,obAnim(a0)

loc_10FFA:
		move.b	(v_jpadhold2).w,d0
		andi.b	#btnL+btnR,d0
		bne.s	loc_11026
		move.w	obInertia(a0),d0
		beq.s	loc_11026
		bmi.s	loc_1101A
		sub.w	d5,d0
		bhs.s	loc_11014
		clr.w	d0

loc_11014:
		move.w	d0,obInertia(a0)
		bra.s	loc_11026
; ---------------------------------------------------------------------------

loc_1101A:
		add.w	d5,d0
		bhs.s	loc_11022
		clr.w	d0

loc_11022:
		move.w	d0,obInertia(a0)

loc_11026:
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		move.w	d1,obVelX(a0)
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)

loc_11044:
		move.b	obAngle(a0),d0
		addi.b	#$40,d0
		bmi.s	locret_110B4
		move.b	#$40,d1
		tst.w	obInertia(a0)
		beq.s	locret_110B4
		bmi.s	loc_1105C
		neg.w	d1

loc_1105C:
		move.b	obAngle(a0),d0
		add.b	d1,d0
		move.w	d0,-(sp)
		bsr.w	CalcRoomInFront
		move.w	(sp)+,d0
		tst.w	d1
		bpl.s	locret_110B4
		asl.w	#8,d1
		addi.b	#$20,d0
		andi.b	#$C0,d0
		beq.s	loc_110B0
		cmpi.b	#$40,d0
		beq.s	loc_1109E
		cmpi.b	#$80,d0
		beq.s	loc_11098
		add.w	d1,obVelX(a0)
		bset	#5,obStatus(a0)
		clr.w	obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_11098:
		sub.w	d1,obVelY(a0)
		rts
; ---------------------------------------------------------------------------

loc_1109E:
		sub.w	d1,obVelX(a0)
		bset	#5,obStatus(a0)
		clr.w	obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_110B0:
		add.w	d1,obVelY(a0)

locret_110B4:
		rts
; End of function Tails_Move


; =============== S U B R O U T I N E =======================================


Tails_MoveLeft:
		move.w	obInertia(a0),d0
		beq.s	+
		bpl.s	loc_110EA
+
		bset	#0,obStatus(a0)
		bne.s	+
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
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

loc_110EA:
		sub.w	d4,d0
		bhs.s	+
		move.w	#-$80,d0
+
		move.w	d0,obInertia(a0)
		move.b	obAngle(a0),d1
		addi.b	#$20,d1
		andi.b	#$C0,d1
		bne.s	Tails_MoveLeft.return
		cmpi.w	#$400,d0
		blt.s	Tails_MoveLeft.return
		move.b	#AniIDSonAni_Stop,obAnim(a0)
		bclr	#0,obStatus(a0)
		move.w	#sfx_Skid,d0
		jmp	(PlaySound_Special).l
; End of function Tails_MoveLeft


; =============== S U B R O U T I N E =======================================


Tails_MoveRight:
		move.w	obInertia(a0),d0
		bmi.s	loc_11150
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

loc_11150:
		add.w	d4,d0
		bhs.s	+
		move.w	#$80,d0
+
		move.w	d0,obInertia(a0)
		move.b	obAngle(a0),d1
		addi.b	#$20,d1
		andi.b	#$C0,d1
		bne.s	Tails_MoveRight.return
		cmpi.w	#-$400,d0
		bgt.s	Tails_MoveRight.return
		move.b	#AniIDSonAni_Stop,obAnim(a0)
		bset	#0,obStatus(a0)
		move.w	#sfx_Skid,d0
		jmp	(PlaySound_Special).l
; End of function Tails_MoveRight


; =============== S U B R O U T I N E =======================================


Tails_RollSpeed:
		move.w	(Tails_top_speed).w,d6
		asl.w	#1,d6
		move.w	(Tails_acceleration).w,d5
		asr.w	#1,d5
		moveq	#20,d4
		asr.w	#2,d4
		tst.b	(f_slidemode).w
		bne.w	loc_11204
		tst.w	objoff_2E(a0)
		bne.s	loc_111C0
		btst	#bitL,(v_jpadhold2).w
		beq.s	loc_111B4
		bsr.w	Tails_RollLeft

loc_111B4:
		btst	#bitR,(v_jpadhold2).w
		beq.s	loc_111C0
		bsr.w	Tails_RollRight

loc_111C0:
		move.w	obInertia(a0),d0
		beq.s	loc_111E2
		bmi.s	loc_111D6
		sub.w	d5,d0
		bhs.s	loc_111D0
		clr.w	d0

loc_111D0:
		move.w	d0,obInertia(a0)
		bra.s	loc_111E2
; ---------------------------------------------------------------------------

loc_111D6:
		add.w	d5,d0
		bhs.s	loc_111DE
		clr.w	d0

loc_111DE:
		move.w	d0,obInertia(a0)

loc_111E2:
		tst.w	obInertia(a0)
		bne.s	loc_11204
		bclr	#2,obStatus(a0)
		move.b	#$F,obHeight(a0)
		move.b	#9,obWidth(a0)
		move.b	#AniIDSonAni_Wait,obAnim(a0)
		subq.w	#5,obY(a0)

loc_11204:
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		cmpi.w	#$1000,d1
		ble.s	loc_11228
		move.w	#$1000,d1

loc_11228:
		cmpi.w	#-$1000,d1
		bge.s	loc_11232
		move.w	#-$1000,d1

loc_11232:
		move.w	d1,obVelX(a0)
		bra.w	loc_11044
; End of function Tails_RollSpeed


; =============== S U B R O U T I N E =======================================


Tails_RollLeft:
		move.w	obInertia(a0),d0
		beq.s	loc_11242
		bpl.s	loc_11250

loc_11242:
		bset	#0,obStatus(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_11250:
		sub.w	d4,d0
		bhs.s	loc_11258
		move.w	#-$80,d0

loc_11258:
		move.w	d0,obInertia(a0)
		rts
; End of function Tails_RollLeft


; =============== S U B R O U T I N E =======================================


Tails_RollRight:
		move.w	obInertia(a0),d0
		bmi.s	loc_11272
		bclr	#0,obStatus(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

loc_11272:
		add.w	d4,d0
		bhs.s	loc_1127A
		move.w	#$80,d0

loc_1127A:
		move.w	d0,obInertia(a0)
		rts
; End of function Tails_RollRight


; =============== S U B R O U T I N E =======================================


Tails_ChgJumpDir:
		move.w	(Tails_top_speed).w,d6
		move.w	(Tails_acceleration).w,d5
		asl.w	#1,d5
		btst	#4,obStatus(a0)
		bne.s	loc_112CA
		move.w	obVelX(a0),d0
		btst	#bitL,(v_jpadhold2).w
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
		btst	#bitR,(v_jpadhold2).w
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

loc_112CA:
		cmpi.w	#$60,(Camera_Y_pos_bias).w
		beq.s	loc_112DC
		bhs.s	loc_112D8
		addq.w	#4,(Camera_Y_pos_bias).w

loc_112D8:
		subq.w	#2,(Camera_Y_pos_bias).w

loc_112DC:
		cmpi.w	#-$400,obVelY(a0)
		blo.s	locret_1130A
		move.w	obVelX(a0),d0
		move.w	d0,d1
		asr.w	#5,d1
		beq.s	locret_1130A
		bmi.s	loc_112FE
		sub.w	d1,d0
		bhs.s	loc_112F8
		clr.w	d0

loc_112F8:
		move.w	d0,obVelX(a0)
		rts
; ---------------------------------------------------------------------------

loc_112FE:
		sub.w	d1,d0
		blo.s	loc_11306
		clr.w	d0

loc_11306:
		move.w	d0,obVelX(a0)

locret_1130A:
		rts
; End of function Tails_ChgJumpDir


; =============== S U B R O U T I N E =======================================


Tails_LevelBoundaries:
		move.l	obX(a0),d1
		move.w	obVelX(a0),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,d1
		swap	d1
		move.w	(Camera_Min_X_pos).w,d0
		addi.w	#$10,d0
		cmp.w	d1,d0
		bhi.s	loc_11374
		move.w	(Camera_Max_X_pos).w,d0
		addi.w	#$128,d0
		tst.b	(f_lockscreen).w
		bne.s	loc_1133A
		addi.w	#$40,d0

loc_1133A:
		cmp.w	d1,d0
		bls.s	loc_11374
; loc_1133E:
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
		blt.s	loc_1134E
		rts
; ---------------------------------------------------------------------------

loc_1134E:
		; a2 needs to be set here, otherwise KillCharacter
		; will access a dangling pointer!
		movea.l	a0,a2
		cmpi.w	#(id_SBZ<<8)+1,(Current_ZoneAndAct).w
		bne.w	KillCharacter
		cmpi.w	#$2000,obX(a0)
		blo.w	KillCharacter
		clr.b	(v_lastlamp).w
		move.w	#1,(Level_Inactive_flag).w
		move.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w
		rts
; ---------------------------------------------------------------------------

loc_11374:
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
		blt.s	loc_1134E
		rts
; End of function Tails_LevelBoundaries


; =============== S U B R O U T I N E =======================================


Tails_Roll:
		tst.b	(f_slidemode).w
		bne.s	Obj02_NoRoll
		move.w	obInertia(a0),d0
		bpl.s	Obj02_DoRoll
		neg.w	d0

Obj02_DoRoll:
		cmpi.w	#$80,d0
		blo.s	Obj02_NoRoll
		move.b	(v_jpadhold2).w,d0
		andi.b	#btnL|btnR,d0
		bne.s	Obj02_NoRoll
		btst	#bitDn,(v_jpadhold2).w
		beq.s	Obj02_NoRoll
		btst	#2,obStatus(a0)
		bne.s	Obj02_NoRoll
		bset	#2,obStatus(a0)
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		addq.w	#5,obY(a0)
		move.w	#sfx_Roll,d0
		jsr	(PlaySound_Special).l
		tst.w	obInertia(a0)
		bne.s	Obj02_NoRoll
		move.w	#$200,obInertia(a0)

Obj02_NoRoll:
		rts
; End of function Tails_Roll


; =============== S U B R O U T I N E =======================================


Tails_Jump:
		move.b	(v_jpadpress2).w,d0
		andi.b	#btnABC,d0
		beq.s	Obj02_NoRoll
		moveq	#0,d0
		move.b	obAngle(a0),d0
		addi.b	#$80,d0
		bsr.w	sub_13102
		cmpi.w	#6,d1
		blt.s	Obj02_NoRoll
		move.w	#$680,d2
		btst	#6,obStatus(a0)
		beq.s	+
		move.w	#$380,d2
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
		move.b	#1,objoff_3C(a0)
		clr.b	objoff_38(a0)
		move.w	#sfx_Jump,d0
		jsr	(PlaySound_Special).l
		btst	#2,obStatus(a0)
		bne.s	loc_11498
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		bset	#2,obStatus(a0)
		addq.w	#5,obY(a0)
		rts
; ---------------------------------------------------------------------------

loc_11498:
		bset	#4,obStatus(a0)
		rts
; End of function Tails_Jump


; =============== S U B R O U T I N E =======================================


Tails_JumpHeight:
		tst.b	objoff_3C(a0)
		beq.s	loc_114CC
		move.w	#-$400,d1
		btst	#6,obStatus(a0)
		beq.s	loc_114B6
		move.w	#-$200,d1

loc_114B6:
		cmp.w	obVelY(a0),d1
		ble.s	.return
		move.b	(v_jpadhold2).w,d0
		andi.b	#btnABC,d0
		bne.s	.return
		move.w	d1,obVelY(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_114CC:
		cmpi.w	#-$FC0,obVelY(a0)
		bge.s	.return
		move.w	#-$FC0,obVelY(a0)
.return:	rts
; End of function Tails_JumpHeight

; ---------------------------------------------------------------------------
; Subroutine to check for starting to charge a spindash
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; Tails_Spindash:
Tails_CheckSpindash:
		tst.b	spindash_flag(a0)
		bne.s	Tails_UpdateSpindash
		cmpi.b	#AniIDSonAni_Duck,obAnim(a0)
		bne.s	locret_1150E
		move.b	(v_jpadpress2).w,d0
		andi.b	#btnABC,d0
		beq.w	locret_1150E
		move.b	#AniIDSonAni_Spindash,obAnim(a0)
		move.w	#sfx_Roll,d0
		jsr	(PlaySound_Special).l
		addq.l	#4,sp
		move.b	#1,spindash_flag(a0)

locret_1150E:
		rts
; ---------------------------------------------------------------------------

Tails_UpdateSpindash:
		move.b	(v_jpadhold2).w,d0
		btst	#bitDn,d0
		bne.s	Tails_ChargingSpindash

		; unleash the charged spindash and start rolling quickly:
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		addq.w	#5,obY(a0)
		clr.b	spindash_flag(a0)
	if FixBugs
		; To fix a bug in 'ScrollHoriz', we need an extra variable, so this
		; code has been modified to make the delay value only a single byte.
		; This is used by the fixed 'ScrollHoriz'.
		move.b	#$20,(Horiz_scroll_delay_val).w
		; Back up the position array index for later.
		move.b	(Tails_Pos_Record_Index+1).w,(Horiz_scroll_delay_val+1).w
	else
		move.w	#$2000,(Horiz_scroll_delay_val).w
	endif
		move.w	#$800,obInertia(a0)
		btst	#0,obStatus(a0)
		beq.s	loc_1154E
		neg.w	obInertia(a0)

loc_1154E:
		bset	#2,obStatus(a0)
		rts
; ---------------------------------------------------------------------------

Tails_ChargingSpindash:
		move.b	(v_jpadpress2).w,d0
		andi.b	#btnABC,d0
		beq.w	loc_11564
		nop

loc_11564:
		addq.l	#4,sp
		rts
; End of function Tails_CheckSpindash


; =============== S U B R O U T I N E =======================================


Tails_SlopeResist:
		move.b	obAngle(a0),d0
		addi.b	#$60,d0
		cmpi.b	#$C0,d0
		bhs.s	locret_1159C
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	#$20,d0
		asr.l	#8,d0
		tst.w	obInertia(a0)
		beq.s	locret_1159C
		bmi.s	loc_11598
		tst.w	d0
		beq.s	locret_11596
		add.w	d0,obInertia(a0)

locret_11596:
		rts
; ---------------------------------------------------------------------------

loc_11598:
		add.w	d0,obInertia(a0)

locret_1159C:
		rts
; End of function Tails_SlopeResist


; =============== S U B R O U T I N E =======================================


Tails_RollRepel:
		move.b	obAngle(a0),d0
		addi.b	#$60,d0
		cmpi.b	#$C0,d0
		bhs.s	locret_115D8
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	#$50,d0
		asr.l	#8,d0
		tst.w	obInertia(a0)
		bmi.s	loc_115CE
		tst.w	d0
		bpl.s	loc_115C8
		asr.l	#2,d0

loc_115C8:
		add.w	d0,obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_115CE:
		tst.w	d0
		bmi.s	loc_115D4
		asr.l	#2,d0

loc_115D4:
		add.w	d0,obInertia(a0)

locret_115D8:
		rts
; End of function Tails_RollRepel


; =============== S U B R O U T I N E =======================================


Tails_SlopeRepel:
		nop
		tst.b	objoff_38(a0)
		bne.s	locret_11614
		tst.w	objoff_2E(a0)
		bne.s	loc_11616
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0
		beq.s	locret_11614
		move.w	obInertia(a0),d0
		bpl.s	loc_115FE
		neg.w	d0

loc_115FE:
		cmpi.w	#$280,d0
		bhs.s	locret_11614
		clr.w	obInertia(a0)
		bset	#1,obStatus(a0)
		move.w	#$1E,objoff_2E(a0)

locret_11614:
		rts
; ---------------------------------------------------------------------------

loc_11616:
		subq.w	#1,objoff_2E(a0)
		rts
; End of function Tails_SlopeRepel


; =============== S U B R O U T I N E =======================================


Tails_JumpAngle:
		move.b	obAngle(a0),d0	; get Tails's angle
		beq.s	loc_11636	; if already 0, branch
		bpl.s	loc_1162C	; if higher than 0, branch
		addq.b	#2,d0		; increase angle
		bhs.s	loc_11632
		moveq	#0,d0
		bra.s	loc_11632
; ---------------------------------------------------------------------------

loc_1162C:
		subq.b	#2,d0		; decrease angle
		bhs.s	loc_11632
		moveq	#0,d0

loc_11632:
		move.b	d0,obAngle(a0)

loc_11636:
		move.b	objoff_27(a0),d0
		beq.s	.return
		tst.w	obInertia(a0)
		bmi.s	loc_1165A
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

loc_1165A:
		move.b	objoff_2D(a0),d1
		sub.b	d1,d0
		bhs.s	loc_11670
		subq.b	#1,objoff_2C(a0)
		bhs.s	loc_11670
		moveq	#0,d0
		move.b	d0,objoff_2C(a0)

loc_11670:
		move.b	d0,objoff_27(a0)
		rts
; End of function Tails_JumpAngle


; =============== S U B R O U T I N E =======================================

; Tails_Floor:
Tails_DoLevelCollision:
		move.l	(v_colladdr1).w,(Collision_addr).w
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	+
		move.l	(v_colladdr2).w,(Collision_addr).w
+
		move.b	obLRBSolidBit(a0),d5
		move.w	obVelX(a0),d0				; get X speed
		move.w	obVelY(a0),d1				; get Y speed
		bpl.s	TaiAirCol_PosY				; if it's positive, branch
		cmp.w	d0,d1					; are we moving towards the left?
		bgt.w	Tails_FloorLeft				; if so, branch
		neg.w	d0					; negate for right cheeck
		cmp.w	d0,d1					; are we moving towards the right?
		bge.w	Tails_FloorRight			; if so, branch
		bra.w	Tails_FloorUp				; we are moving upwards
; ===========================================================================

TaiAirCol_PosY:
		cmp.w	d0,d1					; are we moving towards the right?
		blt.w	Tails_FloorRight			; if so, branch
		neg.w	d0					; negate for left check
		cmp.w	d0,d1					; are we moving towards the left?
		ble.w	Tails_FloorLeft				; if so, branch
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
		bsr.w	Tails_ResetOnFloor
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	loc_11722
		move.b	d3,d0
		addi.b	#$10,d0
		andi.b	#$20,d0
		beq.s	loc_11714
		asr	obVelY(a0)
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_11714:
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_11722:
		clr.w	obVelX(a0)
		cmpi.w	#$FC0,obVelY(a0)
		ble.s	loc_11736
		move.w	#$FC0,obVelY(a0)

loc_11736:
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Tails_FloorLeft:
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	loc_11760
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_11760:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	loc_1177A
		sub.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_1177A:
		tst.w	obVelY(a0)
		bmi.s	.return
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Tails_ResetOnFloor
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Tails_FloorUp:
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	loc_117BA
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)

loc_117BA:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	loc_117CC
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)

loc_117CC:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	.return
		sub.w	d1,obY(a0)
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	loc_117EC
		clr.w	obVelY(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_117EC:
		move.b	d3,obAngle(a0)
		bsr.w	Tails_ResetOnFloor
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Tails_FloorRight:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	loc_1181E
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_1181E:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	loc_11838
		sub.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

loc_11838:
		tst.w	obVelY(a0)
		bmi.s	.return
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Tails_ResetOnFloor
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; End of function Tails_DoLevelCollision


; =============== S U B R O U T I N E =======================================


Tails_ResetOnFloor:
		btst	#4,obStatus(a0)
		beq.s	loc_11874
		nop
		nop
		nop

loc_11874:
		bclr	#5,obStatus(a0)
		bclr	#1,obStatus(a0)
		bclr	#4,obStatus(a0)
		btst	#2,obStatus(a0)
		beq.s	loc_118AA
		bclr	#2,obStatus(a0)
		move.b	#$F,obHeight(a0)
		move.b	#9,obWidth(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		subq.w	#1,obY(a0)

loc_118AA:
		clr.b	objoff_3C(a0)
		clr.w	(v_itembonus).w
		clr.b	objoff_27(a0)
		rts
; End of function Tails_ResetOnFloor

; ---------------------------------------------------------------------------

Obj02_Hurt:
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$30,obVelY(a0)
		btst	#6,obStatus(a0)
		beq.s	loc_118D8
		subi.w	#$20,obVelY(a0)

loc_118D8:
		bsr.w	Tails_HurtStop
		bsr.w	Tails_LevelBoundaries
		bsr.w	Tails_Animate
		bsr.w	LoadTailsDynPLC
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


Tails_HurtStop:
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
		bsr.w	Tails_DoLevelCollision
		btst	#1,obStatus(a0)
		bne.s	.return
		moveq	#0,d0
		move.w	d0,obVelY(a0)
		move.w	d0,obVelX(a0)
		move.w	d0,obInertia(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		move.b	#2,obRoutine(a0)
		move.w	#120,flashtime(a0)
.return:	rts
; End of function Tails_HurtStop

; ---------------------------------------------------------------------------

Obj02_Dead:
		bsr.w	Tails_GameOver
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		bsr.w	Tails_Animate
		bsr.w	LoadTailsDynPLC
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


Tails_GameOver:
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#$100,d0
		cmp.w	obY(a0),d0
		bge.s	.return
		move.w	(v_player+obX).w,d0
		subi.w	#$40,d0
		move.w	d0,obX(a0)
		move.w	(v_player+obY).w,d0
		subi.w	#$80,d0
		move.w	d0,obY(a0)
		move.b	#2,obRoutine(a0)
		andi.w	#$7FFF,obGfx(a0)
		move.b	#$C,obTopSolidBit(a0)
		move.b	#$D,obLRBSolidBit(a0)
		nop

.return:
		rts
; End of function Tails_GameOver

; ---------------------------------------------------------------------------

Obj02_ResetLevel:
		tst.w	objoff_3A(a0)
		beq.s	.return
		subq.w	#1,objoff_3A(a0)
		bne.s	.return
		move.w	#1,(Level_Inactive_flag).w

.return:
		rts

; =============== S U B R O U T I N E =======================================


Tails_Animate:
		lea	TailsAniData(pc),a1

Tails_Animate2:
		moveq	#0,d0
		move.b	obAnim(a0),d0
		cmp.b	obPrevAni(a0),d0
		beq.s	loc_119BE
		move.b	d0,obPrevAni(a0)
		clr.b	obAniFrame(a0)
		clr.b	obTimeFrame(a0)

loc_119BE:
		add.w	d0,d0
		adda.w	(a1,d0.w),a1
		move.b	(a1),d0
		bmi.s	loc_11A2E
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		subq.b	#1,obTimeFrame(a0)
		bpl.s	locret_119FC
		move.b	d0,obTimeFrame(a0)
; End of function Tails_Animate


; =============== S U B R O U T I N E =======================================


sub_119E4:
		moveq	#0,d1
		move.b	obAniFrame(a0),d1
		move.b	1(a1,d1.w),d0
		cmpi.b	#$F0,d0
		bhs.s	loc_119FE

loc_119F4:
		move.b	d0,obFrame(a0)
		addq.b	#1,obAniFrame(a0)

locret_119FC:
		rts
; ---------------------------------------------------------------------------

loc_119FE:
		addq.b	#1,d0
		bne.s	loc_11A0E
		sf	obAniFrame(a0)
		move.b	1(a1),d0
		bra.s	loc_119F4
; ---------------------------------------------------------------------------

loc_11A0E:
		addq.b	#1,d0
		bne.s	loc_11A22
		move.b	2(a1,d1.w),d0
		sub.b	d0,obAniFrame(a0)
		sub.b	d0,d1
		move.b	1(a1,d1.w),d0
		bra.s	loc_119F4
; ---------------------------------------------------------------------------

loc_11A22:
		addq.b	#1,d0
		bne.s	locret_11A2C
		move.b	2(a1,d1.w),obAnim(a0)

locret_11A2C:
		rts
; End of function sub_119E4

; ---------------------------------------------------------------------------

loc_11A2E:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	locret_119FC
		addq.b	#1,d0
		bne.w	loc_11B0E
		moveq	#0,d0
		move.b	objoff_27(a0),d0
		bne.w	loc_11AB4
		moveq	#0,d1
		move.b	obAngle(a0),d0
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	loc_11A56
		not.b	d0

loc_11A56:
		addi.b	#$10,d0
		bpl.s	loc_11A5E
		moveq	#3,d1

loc_11A5E:
		andi.b	#$FC,obRender(a0)
		eor.b	d1,d2
		or.b	d2,obRender(a0)
		lsr.b	#4,d0
		andi.b	#6,d0
		move.w	obInertia(a0),d2
		bpl.s	loc_11A78
		neg.w	d2

loc_11A78:
		move.b	d0,d3
		add.b	d3,d3
		add.b	d3,d3
		lea	(TailsAni_Walk).l,a1
		cmpi.w	#$600,d2
		blo.s	loc_11A9A
		lea	(TailsAni_Run).l,a1
		move.b	d0,d1
		lsr.b	#1,d1
		add.b	d1,d0
		add.b	d0,d0
		move.b	d0,d3

loc_11A9A:
		neg.w	d2
		addi.w	#$800,d2
		bpl.s	loc_11AA4
		moveq	#0,d2

loc_11AA4:
		lsr.w	#8,d2
		move.b	d2,obTimeFrame(a0)
		bsr.w	sub_119E4
		add.b	d3,obFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_11AB4:
		move.b	objoff_27(a0),d0
		moveq	#0,d1
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	loc_11AE8
		andi.b	#$FC,obRender(a0)
		moveq	#0,d2
		or.b	d2,obRender(a0)
		addi.b	#$B,d0
		divu.w	#$16,d0
		addi.b	#$75,d0
		move.b	d0,obFrame(a0)
		sf	obTimeFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_11AE8:
		moveq	#3,d2
		andi.b	#$FC,obRender(a0)
		or.b	d2,obRender(a0)
		neg.b	d0
		addi.b	#$8F,d0
		divu.w	#$16,d0
		addi.b	#$75,d0
		move.b	d0,obFrame(a0)
		sf	obTimeFrame(a0)
		rts
; ---------------------------------------------------------------------------

loc_11B0E:
		addq.b	#1,d0
		bne.s	loc_11B52
		move.w	obInertia(a0),d2
		bpl.s	loc_11B1A
		neg.w	d2

loc_11B1A:
		lea	(TailsAni_Roll2).l,a1
		cmpi.w	#$600,d2
		bhs.s	loc_11B2C
		lea	(TailsAni_Roll).l,a1

loc_11B2C:
		neg.w	d2
		addi.w	#$400,d2
		bpl.s	loc_11B36
		moveq	#0,d2

loc_11B36:
		lsr.w	#8,d2
		move.b	d2,obTimeFrame(a0)
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		bra.w	sub_119E4
; ---------------------------------------------------------------------------

loc_11B52:
		addq.b	#1,d0
		bne.s	loc_11B88
		move.w	obInertia(a0),d2
		bmi.s	loc_11B5E
		neg.w	d2

loc_11B5E:
		addi.w	#$800,d2
		bpl.s	loc_11B66
		moveq	#0,d2

loc_11B66:
		lsr.w	#6,d2
		move.b	d2,obTimeFrame(a0)
		lea	(TailsAni_Push_NoArt).l,a1
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		bra.w	sub_119E4
; ---------------------------------------------------------------------------

loc_11B88:
		move.w	(v_player2+obVelX).w,d1
		move.w	(v_player2+obVelY).w,d2
		jsr	(CalcAngle).l
		moveq	#0,d1
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	loc_11BA6
		not.b	d0
		bra.s	loc_11BAA
; ---------------------------------------------------------------------------

loc_11BA6:
		addi.b	#$80,d0

loc_11BAA:
		addi.b	#$10,d0
		bpl.s	loc_11BB2
		moveq	#3,d1

loc_11BB2:
		andi.b	#$FC,obRender(a0)
		eor.b	d1,d2
		or.b	d2,obRender(a0)
		lsr.b	#3,d0
		andi.b	#$C,d0
		move.b	d0,d3
		lea	(byte_11E3C).l,a1
		move.b	#3,obTimeFrame(a0)
		bsr.w	sub_119E4
		add.b	d3,obFrame(a0)
		rts
; ---------------------------------------------------------------------------
TailsAniData:	dc.w TailsAni_Walk-TailsAniData
		dc.w TailsAni_Run-TailsAniData
		dc.w TailsAni_Roll-TailsAniData
		dc.w TailsAni_Roll2-TailsAniData
		dc.w TailsAni_Push_NoArt-TailsAniData
		dc.w TailsAni_Wait-TailsAniData
		dc.w TailsAni_Balance_NoArt-TailsAniData
		dc.w TailsAni_LookUp-TailsAniData
		dc.w TailsAni_Duck-TailsAniData
		dc.w TailsAni_Spindash-TailsAniData
		dc.w TailsAni_0A-TailsAniData
		dc.w TailsAni_0B-TailsAniData
		dc.w TailsAni_0C-TailsAniData
		dc.w TailsAni_Stop-TailsAniData
		dc.w TailsAni_Fly-TailsAniData
		dc.w TailsAni_0F-TailsAniData
		dc.w TailsAni_Jump-TailsAniData
		dc.w TailsAni_11-TailsAniData
		dc.w TailsAni_12-TailsAniData
		dc.w TailsAni_13-TailsAniData
		dc.w TailsAni_14-TailsAniData
		dc.w TailsAni_15-TailsAniData
		dc.w TailsAni_Death1-TailsAniData
		dc.w TailsAni_UnusedDrown-TailsAniData
		dc.w TailsAni_Death2-TailsAniData
		dc.w TailsAni_19-TailsAniData
		dc.w TailsAni_1A-TailsAniData
		dc.w TailsAni_1B-TailsAniData
		dc.w TailsAni_1C-TailsAniData
		dc.w TailsAni_1D-TailsAniData
		dc.w TailsAni_1E-TailsAniData
TailsAni_Walk:	dc.b $FF,$10,$11,$12,$13,$14,$15, $E, $F,$FF
TailsAni_Run:	dc.b $FF,$2E,$2F,$30,$31,$FF,$FF,$FF,$FF,$FF
TailsAni_Roll:	dc.b   1,$48,$47,$46,$FF
TailsAni_Roll2:	dc.b   1,$48,$47,$46,$FF
TailsAni_Push_NoArt:dc.b $FD,  9, $A, $B, $C, $D, $E,$FF
TailsAni_Wait:	dc.b   7,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  3,  2,  1,  1,  1
		dc.b   1,  1,  1,  1,  1,  3,  2,  1,  1,  1,  1,  1,  1,  1,  1,  1
		dc.b   5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5
		dc.b   6,  7,  8,  7,  8,  7,  8,  7,  8,  7,  8,  6,$FE,$1C
TailsAni_Balance_NoArt:dc.b $1F,  1,  2,  3,  4,  5,  6,  7,  8,$FF
TailsAni_LookUp:dc.b $3F,  4,$FF
TailsAni_Duck:	dc.b $3F,$5B,$FF
TailsAni_Spindash:dc.b	 0,$60,$61,$62,$FF
TailsAni_0A:	dc.b $3F,$82,$FF
TailsAni_0B:	dc.b   7,  8,  8,  9,$FD,  5
TailsAni_0C:	dc.b   7,  9,$FD,  5
TailsAni_Stop:	dc.b   7,  1,  2,$FF
TailsAni_Fly:	dc.b   7,$5E,$5F,$FF
TailsAni_0F:	dc.b   7,  1,  2,  3,  4,  5,$FF
TailsAni_Jump:	dc.b   3,$59,$5A,$59,$5A,$59,$5A,$59,$5A,$59,$5A,$59,$5A,$FD,  0
TailsAni_11:	dc.b   4,  1,  2,$FF
TailsAni_12:	dc.b  $F,  1,  2,  3,$FE,  1
TailsAni_13:	dc.b  $F,  1,  2,$FE,  1
TailsAni_14:	dc.b $3F,  1,$FF
TailsAni_15:	dc.b  $B,  1,  2,  3,  4,$FD,  0
TailsAni_Death1:dc.b $20,$5D,$FF
TailsAni_UnusedDrown:dc.b $2F,$5D,$FF
TailsAni_Death2:dc.b   3,$5D,$FF
TailsAni_19:	dc.b   3,$5D,$FF
TailsAni_1A:	dc.b   3,$5C,$FF
TailsAni_1B:	dc.b   7,  1,  1,$FF
TailsAni_1C:	dc.b $77,  0,$FD,  0
TailsAni_1D:	dc.b   3,  1,  2,  3,  4,  5,  6,  7,  8,$FF
TailsAni_1E:	dc.b   3,  1,  2,  3,  4,  5,  6,  7,  8,$FF
		even
; ---------------------------------------------------------------------------
; Tails' Tails pattern loading subroutine
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; LoadTailsDynPLC_F600:
LoadTailsTailsDynPLC:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		cmp.b	(TailsTails_LastLoadedDPLC).w,d0
		beq.s	LoadTailsDynPLC.return
		move.b	d0,(TailsTails_LastLoadedDPLC).w
		lea	(TailsDynPLC).l,a2
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d5
		subq.w	#1,d5
		bmi.s	LoadTailsDynPLC.return
		move.w	#ArtTile_TailsTails*tile_size,d4
		bra.s	LoadTailsDynPLC.TPLC_ReadEntry
; End of function LoadTailsTailsDynPLC

; ---------------------------------------------------------------------------
; Tails pattern loading subroutine
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


LoadTailsDynPLC:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		cmp.b	(Tails_LastLoadedDPLC).w,d0
		beq.s	LoadTailsDynPLC.return
		move.b	d0,(Tails_LastLoadedDPLC).w
		lea	(TailsDynPLC).l,a2
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d5
		subq.w	#1,d5
		bmi.s	LoadTailsDynPLC.return
		move.w	#ArtTile_Tails*tile_size,d4
; loc_11D50:
.TPLC_ReadEntry:
		moveq	#0,d1
		move.w	(a2)+,d1
		move.w	d1,d3
		lsr.w	#8,d3
		andi.w	#$F0,d3
		addi.w	#$10,d3
		andi.w	#$FFF,d1
		lsl.l	#5,d1
		addi.l	#Art_Tails,d1
		move.w	d4,d2
		add.w	d3,d4
		add.w	d3,d4
		jsr	(QueueDMATransfer).l
		dbf	d5,.TPLC_ReadEntry

.return:
		rts
; End of function LoadTailsDynPLC
; ===========================================================================