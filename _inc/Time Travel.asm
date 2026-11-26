; ===========================================================================
; Same-act time travel. Gameplay runs on MD; use the normal Mode 1 loader for
; all destination data. Coordinates and collected flags survive the reload.
; ===========================================================================

TimeWarp_MinSpeed = $600
TimeWarp_CommitFrames = 210
TimeWarp_SpendPoleFrames = 90
TimeWarp_MaxFloorOverlap = 8

; Called after the object pass while a pole is armed. Use the primary actor's
; running speed even when the companion touched the pole. Z clear = reload.
TimeWarp_Tick:
		cmpi.w	#Level,(v_gamemode).w
		bne.w	.slow
		tst.b	(f_timecount).w
		beq.w	.slow
		tst.w	(Debug_placement_mode).w
		bne.w	.slow
		tst.b	(f_lockctrl).w
		bne.w	.slow
		tst.b	(f_playerctrl).w
		bne.w	.slow
		lea	(v_player).w,a0
		tst.l	code(a0)
		beq.s	.slow
		cmpi.b	#2,obRoutine(a0)
		bne.s	.slow
		tst.b	obControl(a0)
		bne.s	.slow
		move.w	obInertia(a0),d0
		bpl.s	.speed
		neg.w	d0
.speed:
		cmpi.w	#TimeWarp_MinSpeed,d0
		blo.s	.slow
		addq.b	#1,(TimeWarp_Frames).w
		cmpi.b	#TimeWarp_CommitFrames,(TimeWarp_Frames).w
		blo.s	.stars

		bsr.s	TimeWarp_Destination
		beq.s	.spent
		move.b	d0,(TimeWarp_Target).l
		move.w	obX(a0),(TimeWarp_ResumeX).l
		move.w	obY(a0),(TimeWarp_ResumeY).l
		move.l	obVelX(a0),(TimeWarp_Motion).l
		move.w	obInertia(a0),(TimeWarp_Inertia).l
		move.w	obTopSolidBit(a0),(TimeWarp_Path).l
		move.b	obStatus(a0),d1
		andi.b	#3,d1			; facing and in-air, without attached/roll state
		move.b	d1,(TimeWarp_Status).l
		jsr	(Player_SizeFlags).l
		move.b	d1,(TimeWarp_SizeFlags).l
		tst.b	d0
		rts

.slow:
		cmpi.b	#TimeWarp_SpendPoleFrames,(TimeWarp_Frames).w
		blo.s	.reset_charge
.spent:
		clr.b	(TimeWarp_Direction).w
.reset_charge:
		clr.b	(TimeWarp_Frames).w
.wait:
		moveq	#0,d0
		rts
.stars:
		tst.b	(Super_Sonic_flag).w
		bne.s	.wait
		tst.l	(v_starsobj+code).w
		bne.s	.wait
		move.l	#Obj35,(v_starsobj+code).w
		bra.s	.wait

; Return era + 1, or zero if the pole points beyond the first/last era.
TimeWarp_Destination:
		move.b	(Current_Timezone).w,d0
		beq.s	.from_present
		subq.b	#1,d0
		bne.s	.from_future
		tst.b	(TimeWarp_Direction).w
		bmi.s	.invalid
		moveq	#1,d0			; Past -> Present
		rts
.from_future:
		tst.b	(TimeWarp_Direction).w
		bpl.s	.invalid
		moveq	#1,d0			; either Future -> Present
		rts
.from_present:
		tst.b	(TimeWarp_Direction).w
		bmi.s	.past
		moveq	#4,d0			; Present -> Bad Future
		tst.b	(TimeWarp_GoodFuture).l
		beq.s	.return
		subq.b	#1,d0			; Present -> Good Future
.return:
		tst.b	d0
		rts
.past:
		moveq	#2,d0			; Present -> Past
		rts
.invalid:
		moveq	#0,d0
		rts

; The caller has drained outgoing CD terrain/ring jobs. Change the era only
; after storing the outgoing ring status. Old checkpoints do not span eras.
TimeWarp_PrepareLoad:
		tst.b	(TimeWarp_Target).l
		bne.s	.travel
		clearRAM TimeWarp_RingFlags,TimeWarp_RingFlags_End
		rts
.travel:
		bsr.s	TimeWarp_SaveRings
		move.b	(TimeWarp_Target).l,d0
		subq.b	#1,d0
		move.b	d0,(Current_Timezone).w
		move.b	#1,(Respawn_table_keep).w
		clr.w	(v_lastlamp).w
		rts

; The ring manager sorts the same layout identically when an era is revisited.
; A ring still sparkling at departure is already collected. Each era uses its
; own bank, including the two Futures even when their object presence is shared.
TimeWarp_SaveRings:
		bsr.s	TimeWarp_RingBank
.loop:
		cmpi.w	#-1,2(a1)
		beq.s	.return
		tst.w	(a1)
		beq.s	.next
		move.w	d1,d0
		lsr.w	#3,d0
		bset	d1,(a0,d0.w)
.next:
		lea	6(a1),a1
		addq.w	#1,d1
		bra.s	.loop
.return:
		rts

TimeWarp_RestoreRings:
		tst.b	(TimeWarp_Target).l
		beq.s	.return
		bsr.s	TimeWarp_RingBank
.loop:
		cmpi.w	#-1,2(a1)
		beq.s	.return
		move.w	d1,d0
		lsr.w	#3,d0
		btst	d1,(a0,d0.w)
		beq.s	.next
		move.w	#-1,(a1)
.next:
		lea	6(a1),a1
		addq.w	#1,d1
		bra.s	.loop
.return:
		rts

TimeWarp_RingBank:
		moveq	#0,d0
		move.b	(Current_Timezone).w,d0
		mulu.w	#TimeWarp_RingBankBytes,d0
		lea	(TimeWarp_RingFlags).l,a0
		adda.w	d0,a0
		lea	(Ring_Positions+6).w,a1
		moveq	#0,d1
		rts

; Validate the arrival pose against the new era before the CD renders it.
; A shallow floor overlap can be resolved up. If both collision paths place
; the player inside the terrain, use the normal act start with zero momentum.
TimeWarp_ResolveEntry:
		tst.b	(TimeWarp_Target).l
		beq.s	.return
		lea	(v_player).w,a0
		move.w	#sonic_height<<8|sonic_width,obHeight(a0)
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.primary
		move.w	#tails_height<<8|tails_width,obHeight(a0)
.primary:
		btst	#0,(TimeWarp_SizeFlags).l
		beq.s	.path
		move.w	#Player_MiniHeight<<8|Player_MiniWidth,obHeight(a0)
.path:
		move.w	(TimeWarp_Path).l,obTopSolidBit(a0)
		bsr.s	.check
		bcc.s	.return
		eori.w	#$0202,obTopSolidBit(a0)
		bsr.s	.check
		bcc.s	.return
		clr.l	(TimeWarp_Motion).l
		clr.w	(TimeWarp_Inertia).l
		clr.b	(TimeWarp_Status).l
		move.w	#$0C0D,(TimeWarp_Path).l
		bsr.w	LevelSize_StartLoc
		bsr.w	DeformBGLayer
		bset	#2,(Scroll_flags).w
.return:
		rts
.check:
		move.w	(TimeWarp_ResumeY).l,obY(a0)
		moveq	#0,d0
		jsr	(loc_13146).l
		cmpi.w	#-TimeWarp_MaxFloorOverlap,d1
		blt.s	.blocked
		tst.w	d1
		bpl.s	.ceiling
		add.w	d1,obY(a0)
.ceiling:
		move.w	d1,d4
		moveq	#0,d0
		jsr	(Sonic_DontRunOnWalls).l
		tst.w	d1
		bmi.s	.blocked
		tst.w	d4
		ble.s	.clear
		bset	#status.player.in_air,(TimeWarp_Status).l
.clear:
		move.w	obTopSolidBit(a0),(TimeWarp_Path).l
		andi	#$FE,ccr
		rts
.blocked:
		ori	#1,ccr
		rts

; Retain the selected collision path when initializing the primary actor.
TimeWarp_SetPath:
		tst.b	(TimeWarp_Target).l
		beq.s	.return
		move.w	(TimeWarp_Path).l,obTopSolidBit(a0)
.return:
		rts

; Player initialization prepares character art/sensors/history. Reinstate only
; the movement fields once that's complete and before the first playable frame.
TimeWarp_RestoreMotion:
		tst.b	(TimeWarp_Target).l
		beq.s	.return
		move.l	(TimeWarp_Motion).l,(v_player+obVelX).w
		move.w	(TimeWarp_Inertia).l,(v_player+obInertia).w
		move.b	(TimeWarp_Status).l,(v_player+obStatus).w
.return:
		rts
