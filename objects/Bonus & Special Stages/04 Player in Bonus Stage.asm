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
		dc.w BonusPlayer_Exit2-BonusPlayer_Index
; ===========================================================================

BonusPlayer_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.b	#$E,obHeight(a0)
		move.b	#7,obWidth(a0)
		move.l	#Map_Sonic,obMap(a0)
		move.w	#make_art_tile(ArtTile_Sonic,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#0,obPriority(a0)
		move.b	#2,obAnim(a0)
		bset	#2,obStatus(a0)
		bset	#1,obStatus(a0)

BonusPlayer_ChkDebug:	; Routine 2
		tst.b	(Debug_mode_flag).w		; is debug mode	cheat enabled?
		beq.s	BonusPlayer_NoDebug			; if not, branch
		btst	#bitB,(v_jpadpress1).w		; is button B pressed?
		beq.s	BonusPlayer_NoDebug			; if not, branch
		move.w	#1,(Debug_placement_mode).w	; change Sonic into a ring

BonusPlayer_NoDebug:
		move.b	#0,objoff_30(a0)
		moveq	#0,d0
		move.b	obStatus(a0),d0
		andi.w	#2,d0
		move.w	BonusPlayer_Modes(pc,d0.w),d1
		jsr	BonusPlayer_Modes(pc,d1.w)
		jsr	(LoadSonicDynPLC).l
		jmp	(DisplaySprite).l
; ===========================================================================
BonusPlayer_Modes:
		dc.w BonusPlayer_OnWall-BonusPlayer_Modes
		dc.w BonusPlayer_InAir-BonusPlayer_Modes
; ===========================================================================

BonusPlayer_OnWall:
		bclr	#7,obStatus(a0)		; clear "Sonic has jumped" flag
		bsr.w	BonusPlayer_Jump
		bsr.w	BonusPlayer_Move
		bsr.w	BonusPlayer_Fall
		bra.s	BonusPlayer_Display
; ===========================================================================

BonusPlayer_InAir:
		bsr.w	BonusPlayer_JumpHeight
		bsr.w	BonusPlayer_Move
		bsr.w	BonusPlayer_Fall

BonusPlayer_Display:
		bsr.w	BonusPlayer_ChkItems
		bsr.w	BonusPlayer_ChkItems2
		jsr	(ObjectMove).l
		bsr.w	S1SS_FixCamera
		move.w	(v_ssangle).w,d0
		add.w	(v_ssrotate).w,d0
		move.w	d0,(v_ssangle).w
		jmp	(Sonic_Animate).l

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


BonusPlayer_Move:
		btst	#bitL,(v_jpadhold2).w	; is left being pressed?
		beq.s	BonusPlayer_ChkRight		; if not, branch
		bsr.w	BonusPlayer_MoveLeft

BonusPlayer_ChkRight:
		btst	#bitR,(v_jpadhold2).w	; is right being pressed?
		beq.s	loc_1A4B0		; if not, branch
		bsr.w	BonusPlayer_MoveRight

loc_1A4B0:
		move.b	(v_jpadhold2).w,d0
		andi.b	#btnL+btnR,d0
		bne.s	loc_1A4E0
		move.w	obInertia(a0),d0
		beq.s	loc_1A4E0
		bmi.s	loc_1A4D2
		subi.w	#$C,d0
		bcc.s	loc_1A4CC
		move.w	#0,d0

loc_1A4CC:
		move.w	d0,obInertia(a0)
		bra.s	loc_1A4E0
; ===========================================================================

loc_1A4D2:
		addi.w	#$C,d0
		bcc.s	loc_1A4DC
		move.w	#0,d0

loc_1A4DC:
		move.w	d0,obInertia(a0)

loc_1A4E0:
		move.b	(v_ssangle).w,d0
		addi.b	#$20,d0
		andi.b	#$C0,d0
		neg.b	d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d1
		add.l	d1,obX(a0)
		muls.w	obInertia(a0),d0
		add.l	d0,obY(a0)
		movem.l	d0-d1,-(sp)
		move.l	obY(a0),d2
		move.l	obX(a0),d3
		bsr.w	sub_1A720
		beq.s	loc_1A52A
		movem.l	(sp)+,d0-d1
		sub.l	d1,obX(a0)
		sub.l	d0,obY(a0)
		move.w	#0,obInertia(a0)
		rts
; ===========================================================================

loc_1A52A:
		movem.l	(sp)+,d0-d1
		rts
; End of function BonusPlayer_Move


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


BonusPlayer_MoveLeft:
		bset	#0,obStatus(a0)
		move.w	obInertia(a0),d0
		beq.s	loc_1A53E
		bpl.s	loc_1A552

loc_1A53E:
		subi.w	#$C,d0
		cmpi.w	#-$800,d0
		bgt.s	loc_1A54C
		move.w	#-$800,d0

loc_1A54C:
		move.w	d0,obInertia(a0)
		rts
; ===========================================================================

loc_1A552:
		subi.w	#$40,d0
		move.w	d0,obInertia(a0)
		rts
; End of function BonusPlayer_MoveLeft

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


BonusPlayer_MoveRight:
		bclr	#0,obStatus(a0)
		move.w	obInertia(a0),d0
		bmi.s	loc_1A580
		addi.w	#$C,d0
		cmpi.w	#$800,d0
		blt.s	loc_1A57A
		move.w	#$800,d0

loc_1A57A:
		move.w	d0,obInertia(a0)
		rts
; ===========================================================================

loc_1A580:
		addi.w	#$40,d0
		move.w	d0,obInertia(a0)
		rts
; End of function BonusPlayer_MoveRight

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


BonusPlayer_Jump:
		move.b	(v_jpadpress2).w,d0
		andi.b	#btnABC,d0		; is A, B or C pressed?
		beq.s	BonusPlayer_NoJump		; if not, branch
		move.b	(v_ssangle).w,d0
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

BonusPlayer_NoJump:
		rts
; End of function BonusPlayer_Jump

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to limit Sonic's upward vertical speed
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||

BonusPlayer_JumpHeight:
		move.b	(v_jpadhold2).w,d0	; is the jump button up?
		andi.b	#btnABC,d0
		bne.s	locret_1A5EC		; if not, branch to return
		btst	#7,obStatus(a0)		; did Sonic jump or is he just falling or hit by a bumper?
		beq.s	locret_1A5EC		; if not, branch to return
		move.b	(v_ssangle).w,d0	; get SS angle
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
		ble.s	locret_1A5EC		; if it's less, branch to return
		move.b	(v_ssangle).w,d0
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

locret_1A5EC:
		rts
; ---------------------------------------------------------------------------
; Subroutine to	fix the	camera on Sonic's position (special stage)
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


S1SS_FixCamera:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		move.w	(Camera_RAM).w,d0
		subi.w	#$A0,d3
		bcs.s	loc_1A606
		sub.w	d3,d0
		sub.w	d0,(Camera_RAM).w

loc_1A606:
		move.w	(Camera_Y_pos).w,d0
		subi.w	#$70,d2
		bcs.s	locret_1A616
		sub.w	d2,d0
		sub.w	d0,(Camera_Y_pos).w

locret_1A616:
		rts
; End of function S1SS_FixCamera

; ===========================================================================

BonusPlayer_ExitStage:
		addi.w	#$40,(v_ssrotate).w
		cmpi.w	#$1800,(v_ssrotate).w
		bne.s	loc_1A62C
		move.b	#GameModeID_Level,(v_gamemode).w

loc_1A62C:
		cmpi.w	#$3000,(v_ssrotate).w
		blt.s	loc_1A64A
		move.w	#0,(v_ssrotate).w
		move.w	#$4000,(v_ssangle).w
		addq.b	#2,obRoutine(a0)
		move.w	#$3C,objoff_38(a0)

loc_1A64A:
		move.w	(v_ssangle).w,d0
		add.w	(v_ssrotate).w,d0
		move.w	d0,(v_ssangle).w
		jsr	(Sonic_Animate).l
		jsr	(LoadSonicDynPLC).l
		bsr.s	S1SS_FixCamera
		jmp	(DisplaySprite).l
; ===========================================================================

BonusPlayer_Exit2:
		subq.w	#1,objoff_38(a0)
		bne.s	loc_1A678
		move.b	#GameModeID_Level,(v_gamemode).w

loc_1A678:
		jsr	(Sonic_Animate).l
		jsr	(LoadSonicDynPLC).l
		bsr.w	S1SS_FixCamera
		jmp	(DisplaySprite).l

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


BonusPlayer_Fall:
		move.l	obY(a0),d2
		move.l	obX(a0),d3
		move.b	(v_ssangle).w,d0
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
		bsr.w	sub_1A720
		beq.s	loc_1A6E8
		sub.l	d0,d3
		moveq	#0,d0
		move.w	d0,obVelX(a0)
		bclr	#1,obStatus(a0)
		add.l	d1,d2
		bsr.w	sub_1A720
		beq.s	loc_1A6FE
		sub.l	d1,d2
		moveq	#0,d1
		move.w	d1,obVelY(a0)
		rts
; ===========================================================================

loc_1A6E8:
		add.l	d1,d2
		bsr.w	sub_1A720
		beq.s	loc_1A70C
		sub.l	d1,d2
		moveq	#0,d1
		move.w	d1,obVelY(a0)
		bclr	#1,obStatus(a0)

loc_1A6FE:
		asr.l	#8,d0
		asr.l	#8,d1
		move.w	d0,obVelX(a0)
		move.w	d1,obVelY(a0)
		rts
; ===========================================================================

loc_1A70C:
		asr.l	#8,d0
		asr.l	#8,d1
		move.w	d0,obVelX(a0)
		move.w	d1,obVelY(a0)
		bset	#1,obStatus(a0)
		rts
; End of function BonusPlayer_Fall


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


sub_1A720:
		lea	(v_ssbuffer1).l,a1
		moveq	#0,d4
		swap	d2
		move.w	d2,d4
		swap	d2
		addi.w	#$44,d4
		divu.w	#$18,d4
		mulu.w	#$80,d4
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
		bsr.s	sub_1A768
		move.b	(a1)+,d4
		bsr.s	sub_1A768
		adda.w	#$7E,a1
		move.b	(a1)+,d4
		bsr.s	sub_1A768
		move.b	(a1)+,d4
		bsr.s	sub_1A768
		tst.b	d5
		rts
; End of function sub_1A720


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


sub_1A768:
		beq.s	locret_1A77C
		cmpi.b	#$28,d4
		beq.s	locret_1A77C
		cmpi.b	#$3A,d4
		bcs.s	loc_1A77E
		cmpi.b	#$4B,d4
		bcc.s	loc_1A77E

locret_1A77C:
		rts
; ===========================================================================

loc_1A77E:
		move.b	d4,$30(a0)
		move.l	a1,$32(a0)
		moveq	#-1,d5
		rts
; End of function sub_1A768


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


BonusPlayer_ChkItems:
		lea	(v_ssbuffer1).l,a1
		moveq	#0,d4
		move.w	obY(a0),d4
		addi.w	#$50,d4
		divu.w	#$18,d4
		mulu.w	#$80,d4
		adda.l	d4,a1
		moveq	#0,d4
		move.w	obX(a0),d4
		addi.w	#$20,d4
		divu.w	#$18,d4
		adda.w	d4,a1
		move.b	(a1),d4
		bne.s	BonusPlayer_ChkCont
		tst.b	objoff_3A(a0)
		bne.w	BonusPlayer_MakeGhostSolid
		moveq	#0,d4
		rts
; ===========================================================================

BonusPlayer_ChkCont:
		cmpi.b	#$3A,d4			; is the item a ring?
		bne.s	BonusPlayer_Chk1Up
		bsr.w	SS_RemoveCollectedItem
		bne.s	BonusPlayer_GetCont
		move.b	#1,(a2)
		move.l	a1,4(a2)

BonusPlayer_GetCont:
		jsr	(CollectRing).l
		cmpi.w	#50,(v_rings).w		; check if you have 50 rings
		bcs.s	BonusPlayer_NoCont
		bset	#0,(v_lifecount).w
		bne.s	BonusPlayer_NoCont
		addq.b	#1,(v_continues).w	; add 1 to the number of continues
		move.w	#sfx_Continue,d0
		jsr	(PlaySound).l		; play extra continue sound

BonusPlayer_NoCont:
		moveq	#0,d4
		rts
; ===========================================================================

BonusPlayer_Chk1Up:
		cmpi.b	#$28,d4			; is the item an extra life?
		bne.s	BonusPlayer_ChkEmer
		bsr.w	SS_RemoveCollectedItem
		bne.s	BonusPlayer_Get1Up
		move.b	#3,(a2)
		move.l	a1,4(a2)

BonusPlayer_Get1Up:
		addq.b	#1,(v_lives).w		; add 1 to number of lives
		addq.b	#1,(f_lifecount).w	; update the lives counter
		moveq	#0,d4
		move.w	#bgm_ExtraLife,d0
		jmp	(PlaySound).l		; play extra life music
; ===========================================================================

BonusPlayer_ChkEmer:
		cmpi.b	#$3B,d4			; is the item an emerald?
		bcs.s	BonusPlayer_ChkGhost
		cmpi.b	#$40,d4
		bhi.s	BonusPlayer_ChkGhost
		bsr.w	SS_RemoveCollectedItem
		bne.s	BonusPlayer_GetEmer
		move.b	#5,(a2)
		move.l	a1,4(a2)

BonusPlayer_GetEmer:
		cmpi.b	#6,(v_emeralds).w	; do you have all the emeralds?
		beq.s	BonusPlayer_NoEmer		; if yes, branch
		subi.b	#$3B,d4
		moveq	#0,d0
		move.b	(v_emeralds).w,d0
		lea	(v_emldlist).w,a2
		move.b	d4,(a2,d0.w)
		addq.b	#1,(v_emeralds).w	; add 1 to number of emeralds

BonusPlayer_NoEmer:
		moveq	#0,d4
		move.w	#bgm_Emerald,d0
		jmp	(PlaySound_Special).l	; play emerald music
; ===========================================================================

BonusPlayer_ChkGhost:
		cmpi.b	#$41,d4			; is the item a ghost block?
		bne.s	BonusPlayer_ChkGhostTag
		move.b	#1,objoff_3A(a0)	; mark the ghost block as "passed"

BonusPlayer_ChkGhostTag:
		cmpi.b	#$4A,d4			; is the item a switch for ghost blocks?
		bne.s	BonusPlayer_NoGhost
		cmpi.b	#1,objoff_3A(a0)	; have the ghost blocks been passed?
		bne.s	BonusPlayer_NoGhost		; if not, branch
		move.b	#2,objoff_3A(a0)	; mark the ghost blocks as "solid"

BonusPlayer_NoGhost:
		moveq	#-1,d4
		rts
; ===========================================================================

BonusPlayer_MakeGhostSolid:
		cmpi.b	#2,objoff_3A(a0)	; is the ghost marked as "solid"?
		bne.s	BonusPlayer_GhostNotSolid	; if not, branch
		lea	(v_ssblockbuffer).l,a1
		moveq	#(v_ssblockbuffer_end-v_ssblockbuffer)/$80-1,d1

BonusPlayer_GhostLoop2:
		moveq	#(v_ssblockbuffer_end-v_ssblockbuffer)/$80-1,d2

BonusPlayer_GhostLoop:
		cmpi.b	#$41,(a1)		; is the item a ghost block?
		bne.s	BonusPlayer_NoReplace		; if not, branch
		move.b	#$2C,(a1)		; replace ghost block with a solid block

BonusPlayer_NoReplace:
		addq.w	#1,a1
		dbf	d2,BonusPlayer_GhostLoop
		lea	$40(a1),a1
		dbf	d1,BonusPlayer_GhostLoop2

BonusPlayer_GhostNotSolid:
		clr.b	objoff_3A(a0)
		moveq	#0,d4
		rts
; End of function BonusPlayer_ChkItems


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


BonusPlayer_ChkItems2:
		move.b	objoff_30(a0),d0
		bne.s	BonusPlayer_ChkBumper
		subq.b	#1,objoff_36(a0)
		bpl.s	loc_1A8D8
		move.b	#0,objoff_36(a0)

loc_1A8D8:
		subq.b	#1,objoff_37(a0)
		bpl.s	locret_1A8E4
		move.b	#0,objoff_37(a0)

locret_1A8E4:
		rts
; ===========================================================================

BonusPlayer_ChkBumper:
		cmpi.b	#$25,d0			; is the item a bumper?
		bne.s	BonusPlayer_GOAL		; if not, branch
		move.l	$32(a0),d1
		subi.l	#$FFFF0001,d1
		move.w	d1,d2
		andi.w	#$7F,d1
		mulu.w	#$18,d1
		subi.w	#$14,d1
		lsr.w	#7,d2
		andi.w	#$7F,d2
		mulu.w	#$18,d2
		subi.w	#$44,d2
		sub.w	obX(a0),d1
		sub.w	obY(a0),d2
		jsr	(CalcAngle).l
		jsr	(CalcSine).l
		muls.w	#-$700,d1
		asr.l	#8,d1
		move.w	d1,obVelX(a0)
		muls.w	#-$700,d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)
		bset	#1,obStatus(a0)
		bclr	#7,obStatus(a0)		; clear "Sonic has jumped" flag
		bsr.w	SS_RemoveCollectedItem
		bne.s	BonusPlayer_BumpSnd
		move.b	#2,(a2)
		move.l	objoff_32(a0),d0
		subq.l	#1,d0
		move.l	d0,4(a2)

BonusPlayer_BumpSnd:
		move.w	#sfx_Bumper,d0
		jmp	(PlaySound_Special).l	; play bumper sound
; ===========================================================================

BonusPlayer_GOAL:
		cmpi.b	#$27,d0			; is the item a "GOAL"?
		bne.s	BonusPlayer_UPblock
		addq.b	#2,obRoutine(a0)	; run routine "BonusPlayer_ExitStage"
		move.w	#sfx_SSGoal,d0
		jmp	(PlaySound_Special).l	; play "GOAL" sound
; ===========================================================================

BonusPlayer_UPblock:
		cmpi.b	#$29,d0			; is the item an "UP" block?
		bne.s	BonusPlayer_DOWNblock
		tst.b	objoff_36(a0)
		bne.w	BonusPlayer_NoGlass
		move.b	#$1E,objoff_36(a0)
		btst	#6,(v_ssrotate+1).w
		beq.s	BonusPlayer_UPsnd
		asl	(v_ssrotate).w		; increase stage rotation speed
		movea.l	objoff_32(a0),a1
		subq.l	#1,a1
		move.b	#$2A,(a1)		; change item to a "DOWN" block

BonusPlayer_UPsnd:
		move.w	#sfx_SSItem,d0
		jmp	(PlaySound_Special).l	; play up/down sound
; ===========================================================================

BonusPlayer_DOWNblock:
		cmpi.b	#$2A,d0			; is the item a "DOWN" block?
		bne.s	BonusPlayer_Rblock
		tst.b	objoff_36(a0)
		bne.w	BonusPlayer_NoGlass
		move.b	#$1E,objoff_36(a0)
		btst	#6,(v_ssrotate+1).w
		bne.s	BonusPlayer_DOWNsnd
		asr	(v_ssrotate).w		; reduce stage rotation speed
		movea.l	objoff_32(a0),a1
		subq.l	#1,a1
		move.b	#$29,(a1)		; change item to an "UP" block

BonusPlayer_DOWNsnd:
		move.w	#sfx_SSItem,d0
		jmp	(PlaySound_Special).l	; play up/down sound
; ===========================================================================

BonusPlayer_Rblock:
		cmpi.b	#$2B,d0			; is the item an "R" block?
		bne.s	BonusPlayer_ChkGlass
		tst.b	objoff_37(a0)
		bne.w	BonusPlayer_NoGlass
		move.b	#$1E,objoff_37(a0)
		bsr.w	SS_RemoveCollectedItem
		bne.s	BonusPlayer_RevStage
		move.b	#4,(a2)
		move.l	objoff_32(a0),d0
		subq.l	#1,d0
		move.l	d0,4(a2)

BonusPlayer_RevStage:
		neg.w	(v_ssrotate).w		; reverse stage rotation
		move.w	#sfx_SSItem,d0
		jmp	(PlaySound_Special).l	; play sound
; ===========================================================================

BonusPlayer_ChkGlass:
		cmpi.b	#$2D,d0			; is the item a glass block?
		beq.s	BonusPlayer_Glass		; if yes, branch
		cmpi.b	#$2E,d0
		beq.s	BonusPlayer_Glass
		cmpi.b	#$2F,d0
		beq.s	BonusPlayer_Glass
		cmpi.b	#$30,d0
		bne.s	BonusPlayer_NoGlass		; if not, branch

BonusPlayer_Glass:
		bsr.w	SS_RemoveCollectedItem
		bne.s	BonusPlayer_GlassSnd
		move.b	#6,(a2)
		movea.l	objoff_32(a0),a1
		subq.l	#1,a1
		move.l	a1,4(a2)
		move.b	(a1),d0
		addq.b	#1,d0			; change glass type when touched
		cmpi.b	#$30,d0
		bls.s	BonusPlayer_GlassUpdate	; if glass is still there, branch
		clr.b	d0			; remove the glass block when it's destroyed

BonusPlayer_GlassUpdate:
		move.b	d0,4(a2)		; update the stage layout

BonusPlayer_GlassSnd:
		move.w	#sfx_SSGlass,d0
		jmp	(PlaySound_Special).l	; play glass block sound
; ===========================================================================

BonusPlayer_NoGlass:
		rts
; End of function BonusPlayer_ChkItems2