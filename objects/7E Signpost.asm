; ---------------------------------------------------------------------------
; Object 7E - End of level signpost
; Subtype bit 0: 0 = placed / run past, 1 = drop from above the camera.
; Airborne physics/hits/landing adapted from skdisasm
; 73de97c6b55055bcb8089c1d55d006b02136f163, Obj_EndSign.
; Both entry modes share the same airborne state after a fast crossing.
; Subtype bit 1 selects the SMZ2 Mecha trap instead of the usual finish.
; ---------------------------------------------------------------------------

Signpost:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Signpost_Index(pc,d0.w),d1
		jsr	Signpost_Index(pc,d1.w)
		lea	Ani_Signpost(pc),a1
		jsr	(AnimateSprite).l
		out_of_range2	UnloadObject
		moveq	#0,d0
		move.b	obFrame(a0),d0
		lea	(DPLC_Signpost).l,a2
		lea	signpost_loaded(a0),a3
		move.w	#ArtTile_Signpost*tile_size,d4
		move.l	#Art_Signpost,d6
		jsr	(Load_DynamicPLC).l
		bcs.s	.return
		jmp	(DisplaySprite).l
.return:
		rts

signpost_loaded = objoff_3A	; byte: DPLC cache
signpost_hit_delay = objoff_30	; byte: shared 32-update hit cooldown
signpost_previous_x = objoff_3C	; word: detect a crossing that skips the 32px window
Signpost_LaunchSpeed = $600	; 6px/update, rightward ground speed
Signpost_LaunchY = -$400		; upward launch in place; later hits may move it sideways
Signpost_Ani_MechaSpin = 6
Signpost_Ani_TailsSpin1 = 7
Signpost_Ani_TailsSpin2 = 8
; ===========================================================================

Signpost_Index:	dc.w Signpost_Init-Signpost_Index
		dc.w Signpost_Main-Signpost_Index
		dc.w Signpost_Spin-Signpost_Index
		dc.w Signpost_EndLevel-Signpost_Index
		dc.w Signpost_Sparkle.return-Signpost_Index
		dc.w Signpost_Fall-Signpost_Index
		dc.w Signpost_Landed-Signpost_Index
		dc.w Signpost_FallingResults-Signpost_Index
		dc.w Signpost_TrapSpin-Signpost_Index
		dc.w Signpost_Sparkle.return-Signpost_Index
; ===========================================================================
; loc_EFD6:
Signpost_Init:
		st	signpost_loaded(a0)
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Signpost,obMap(a0)
		move.b	#Map_Signpost_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_Signpost,0,0),obGfx(a0)
		cmpi.w	#(id_SMZ<<8)+1,(Current_ZoneAndAct).w
		bne.s	.priority_ready
		bset	#7,obGfx(a0)
.priority_ready:
		move.b	#4,obRender(a0)
		move.b	#sprite_bound($18,Map_Signpost_width),obActWid(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$1E,obHeight(a0)
		move.b	#$18,obWidth(a0)
		move.w	(v_player+obX).w,signpost_previous_x(a0)
		move.w	obSubtype(a0),d0
		btst	#0,d0
		beq.s	Signpost_Main
		move.w	(Camera_Y_pos).w,d0
		subi.w	#$20,d0
		move.w	d0,obY(a0)
		; A boss/event may spawn this anywhere, not only at the act's end.
		move.w	(Camera_X_pos).w,(Camera_Max_X_pos).w
		bsr.s	Signpost_Activate
		bra.s	Signpost_StartFall
; loc_EFFE:
Signpost_Main:
		move.w	(v_player+obX).w,d0
		move.w	signpost_previous_x(a0),d1
		move.w	d0,signpost_previous_x(a0)
		sub.w	obX(a0),d0
		blo.w	Signpost_Sparkle.return
		cmpi.w	#32,d0
		blo.s	.crossed
		cmp.w	obX(a0),d1
		bhs.w	Signpost_Sparkle.return
.crossed:
		move.w	obSubtype(a0),d0
		btst	#1,d0
		beq.s	.normal_crossing
		cmpi.w	#(id_SMZ<<8)+1,(Current_ZoneAndAct).w
		beq.w	Signpost_TrapTrigger
.normal_crossing:
		bsr.s	Signpost_Activate
		btst	#status.player.in_air,(v_player+obStatus).w
		bne.s	.classic
		cmpi.w	#Signpost_LaunchSpeed,(v_player+obInertia).w
		blt.s	.classic
		move.w	#Signpost_LaunchY,obVelY(a0)
		ori.w	#1,obSubtype(a0)		; enter the falling mode without respawning
		bra.s	Signpost_StartFall
.classic:
		move.b	#4,obRoutine(a0)
		rts

Signpost_Activate:
		clr.b	(f_timecount).w
		move.w	(Camera_Max_X_pos).w,(Camera_Min_X_pos).w
		move.w	#sfx_Signpost,d0
		jmp	(PlaySound).l

Signpost_StartFall:
		move.b	#10,obRoutine(a0)
		move.b	#1,obAnim(a0)
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.return
		move.b	#Signpost_Ani_TailsSpin1,obAnim(a0)
.return:
		rts
; ===========================================================================
Signpost_RingSparklePositions:
		dc.b -$18,-$10		; x-position, y-position
		dc.b	8,   8
		dc.b -$10,   0
		dc.b  $18,  -8
		dc.b	0,  -8
		dc.b  $10,   0
		dc.b -$18,   8
		dc.b  $18, $10
; ===========================================================================
; loc_F028:
Signpost_Spin:
		subq.w	#1,objoff_34(a0)
		bpl.s	Signpost_Sparkle
		move.w	#60,objoff_34(a0)
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.sonic
		cmpi.b	#Signpost_Ani_TailsSpin1,obAnim(a0)
		blo.s	.tails_first
		beq.s	.tails_second
		move.b	#6,obRoutine(a0)
		move.b	#4,obAnim(a0)
		bra.s	Signpost_Sparkle
.tails_first:
		move.b	#Signpost_Ani_TailsSpin1,obAnim(a0)
		bra.s	Signpost_Sparkle
.tails_second:
		move.b	#Signpost_Ani_TailsSpin2,obAnim(a0)
		bra.s	Signpost_Sparkle
.sonic:
		addq.b	#1,obAnim(a0)
		cmpi.b	#3,obAnim(a0)
		bne.s	Signpost_Sparkle
		addq.b	#2,obRoutine(a0)
; loc_F044:
Signpost_Sparkle:
		subq.w	#1,objoff_36(a0)
		bpl.s	.return
		move.w	#12-1,objoff_36(a0)
		moveq	#0,d0
		move.b	objoff_38(a0),d0
		addq.b	#2,objoff_38(a0)
		andi.b	#$E,objoff_38(a0)
		lea	Signpost_RingSparklePositions(pc,d0.w),a2
		jsr	(FindFreeObj).l
		bne.s	.return
		move.l	#Obj12,code(a1)
		move.b	#6,obRoutine(a1)
		move.b	(a2)+,d0
		ext.w	d0
		add.w	obX(a0),d0
		move.w	d0,obX(a1)
		move.b	(a2)+,d0
		ext.w	d0
		add.w	obY(a0),d0
		move.w	d0,obY(a1)
		move.l	#Map_Ring,obMap(a1)
		move.b	#Map_Ring_height,height_pixels(a1)
		move.w	#make_art_tile(ArtTile_Ring,1,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.w	#$100,obPriority(a1)
		move.b	#sprite_bound(8,Map_Ring_width),obActWid(a1)
.return:	rts
; ===========================================================================
; loc_F0C4:
Signpost_EndLevel:
		tst.w	(Debug_placement_mode).w
		bne.s	Signpost_Sparkle.return
		btst	#1,(v_player+obStatus).w
		bne.s	+
		move.b	#PlayerInputLock_Automatic,(f_lockctrl).w
		move.w	#btnR<<8,(v_jpadholdlogical).w
+
		; S1's giant-ring flash clears the primary player's routine pointer.
		tst.l	(v_player+code).w
		beq.s	+
		move.w	(v_player+obX).w,d0
		move.w	(Camera_Max_X_pos).w,d1
		addi.w	#320-24,d1
		cmp.w	d1,d0
		bcs.s	Signpost_Sparkle.return
+		addq.b	#2,obRoutine(a0)

; ---------------------------------------------------------------------------
; Subroutine to load the end of act results screen
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; GotThroughAct:
Load_EndOfAct:
		tst.l	(v_endcard+code).w
		bne.s	Signpost_Sparkle.return
		move.w	(Camera_Max_X_pos).w,(Camera_Min_X_pos).w
		bclr	#obStatusSecondary_isInvincible,(v_player+obStatusSecondary).w
		bclr	#obStatusSecondary_isInvincible,(v_player2+obStatusSecondary).w
		clr.w	(v_player+invtime).w
		clr.w	(v_player2+invtime).w
		clr.b	(f_timecount).w
		move.l	#GotThrough,(v_endcard).w
		moveq	#plcid_TitleCard,d0
		jsr	(NewPLC).l
		move.b	#1,(f_endactbonus).w
		moveq	#0,d0
		move.b	(v_timemin).w,d0
		add.w	d0,d0			; multiply by 60 frames (1 second)
		add.w	d0,d0
		move.w	d0,d1
		lsl.w	#4,d0
		sub.w	d1,d0
		moveq	#0,d1
		move.b	(v_timesec).w,d1
		add.w	d1,d0
		divu.w	#15,d0
		moveq	#$14,d1
		cmp.w	d1,d0
		blo.s	+
		move.w	d1,d0
+
		add.w	d0,d0
		move.w	TimeBonuses(pc,d0.w),(v_timebonus).w
		move.w	(v_rings).w,d0
		move.w	d0,d1			; multiply rings by 10
		lsl.w	#3,d0
		add.w	d1,d0
		add.w	d1,d0
		move.w	d0,(v_ringbonus).w
		move.w	#bgm_GotThrough,d0
		jmp	(PlaySound_Special).l
; End of function Load_EndOfAct

; ===========================================================================
TimeBonuses:	dc.w  5000, 5000, 1000,	 500
		dc.w   400,  400,  300,	 300
		dc.w   200,  200,  200,	 200
		dc.w   100,  100,  100,	 100
		dc.w	50,   50,   50,	  50
		dc.w	0
; ===========================================================================
Ani_Signpost:	dc.w	.eggman-Ani_Signpost
		dc.w	.spin1-Ani_Signpost
		dc.w	.spin2-Ani_Signpost
		dc.w	.sonic-Ani_Signpost
		dc.w	.tails-Ani_Signpost
		dc.w	.mecha-Ani_Signpost
		dc.w	.mecha_spin-Ani_Signpost
		dc.w	.tails_spin1-Ani_Signpost
		dc.w	.tails_spin2-Ani_Signpost
.eggman:	dc.b	$F,2,afEnd
.spin1:	dc.b	1,2,3,4,5,0,3,4,5,0,3,4,5,afEnd
.spin2:	dc.b	1,2,3,4,5,0,3,4,5,0,3,4,5,afEnd
.sonic:		dc.b	$F,0,afEnd
.tails:		dc.b	$F,1,afEnd
.mecha:		dc.b	$F,6,afEnd	; event-selected portrait; load palid_MechaSonic first
.mecha_spin:	dc.b 1,2,9,4,10,6,9,4,10,6,9,4,10,afEnd
.tails_spin1:	dc.b 1,2,7,4,8,1,7,4,8,1,7,4,8,afEnd
.tails_spin2:	dc.b 1,2,7,4,8,1,7,4,8,1,7,4,8,afEnd
		even

; ===========================================================================
; Airborne states use the existing art (its post is already in every frame).
; Unlike the S3&K event controller, normal placement owns no boss cleanup.
Signpost_Fall:
		move.b	(Vint_runcount+3).w,d0
		andi.b	#3,d0
		bne.s	.physics
		bsr.w	Signpost_SpawnAirSparkle
.physics:
		bsr.w	Signpost_CheckPlayerHit
		addi.w	#$C,obVelY(a0)
		jsr	(ObjectMove).l
		bsr.w	Signpost_CheckWall
		move.w	(Camera_Y_pos).w,d0
		addi.w	#$50,d0
		cmp.w	obY(a0),d0
		bhi.s	.return
		tst.w	obVelY(a0)
		bmi.s	.return
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	#12,obRoutine(a0)
		move.w	#$40,objoff_34(a0)
.return:
		rts

Signpost_Landed:
		subq.w	#1,objoff_34(a0)
		bpl.s	.return
		clr.l	obVelX(a0)
		move.b	#14,obRoutine(a0)
		move.b	#3,obAnim(a0)
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.lock
		addq.b	#1,obAnim(a0)
.lock:
		move.b	#PlayerInputLock_Automatic,(f_lockctrl).w
		clr.w	(v_jpadholdlogical).w
.return:
		rts

Signpost_FallingResults:
		tst.w	(Debug_placement_mode).w
		bne.s	.return
		btst	#status.player.in_air,(v_player+obStatus).w
		bne.s	.return
		move.b	#8,obRoutine(a0)
		jmp	(Load_EndOfAct).l
.return:
		rts

; Check both actors independently. The S3&K FixBugs version preserves the
; second address across the first award; here each player is explicit instead.
Signpost_CheckPlayerHit:
		tst.b	signpost_hit_delay(a0)
		beq.s	.players
		subq.b	#1,signpost_hit_delay(a0)
		rts
.players:
		lea	(v_player).w,a2
		bsr.s	Signpost_HitCharacter
		lea	(v_player2).w,a2
Signpost_HitCharacter:
		tst.l	code(a2)
		beq.s	.return
		cmpi.b	#4,obRoutine(a2)
		bhs.s	.return
		cmpi.b	#AniIDSonAni_Roll,obAnim(a2)
		bne.s	.return
		tst.w	obVelY(a2)
		bpl.s	.return
		move.w	obX(a2),d0
		sub.w	obX(a0),d0
		addi.w	#$20,d0
		cmpi.w	#$40,d0
		bhs.s	.return
		move.w	obY(a2),d0
		sub.w	obY(a0),d0
		addi.w	#$18,d0
		cmpi.w	#$30,d0
		blo.s	.hit
.return:
		rts
.hit:
		move.b	#$20,signpost_hit_delay(a0)
		move.w	obX(a0),d0
		sub.w	obX(a2),d0
		bne.s	.offset
		moveq	#8,d0
.offset:
		lsl.w	#4,d0
		move.w	d0,obVelX(a0)
		move.w	#-$200,obVelY(a0)
		; Allocation and sound/score services may clobber a1-a3 and d0-d3.
		move.l	a2,-(sp)
		jsr	(FindFreeObj).l
		bne.s	.score
		move.l	#Points,code(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	2(sp),points_parent(a1)	; low word of saved player address
.score:
		move.w	#sfx_Signpost,d0
		jsr	(PlaySound).l
		moveq	#10,d0			; score counter stores tens: 100 points
		jsr	(AddPoints).l
		movea.l	(sp)+,a2
		rts

Signpost_CheckWall:
		move.w	(Camera_X_pos).w,d0
		tst.w	obVelX(a0)
		bmi.s	.left
		addi.w	#$128,d0
		cmp.w	obX(a0),d0
		blo.s	.bounce
		moveq	#$20,d3
		jsr	(ObjHitWallRight).l
		tst.w	d1
		bmi.s	.bounce
		rts
.left:
		addi.w	#$18,d0
		cmp.w	obX(a0),d0
		bhi.s	.bounce
		moveq	#-$20,d3
		jsr	(ObjHitWallLeft).l
		tst.w	d1
		bpl.s	.return
.bounce:
		neg.w	obVelX(a0)
.return:
		rts

Signpost_SpawnAirSparkle:
		jsr	(FindFreeObj).l
		bne.s	.return
		move.l	#Signpost_AirSparkle,code(a1)
		move.w	obX(a0),obX(a1)
		move.w	obX(a0),objoff_34(a1)
		move.w	obY(a0),obY(a1)
		jsr	(RandomNumber).l
		andi.w	#$1F,d0
		subi.w	#$10,d0
		add.w	d0,obY(a1)
		move.l	#Map_Ring,obMap(a1)
		move.b	#Map_Ring_height,height_pixels(a1)
		move.b	#sprite_bound(8,Map_Ring_width),obActWid(a1)
		move.w	#make_art_tile(ArtTile_Ring,1,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.w	#$1000,obVelX(a1)
		move.w	#$20,objoff_36(a1)
.return:
		rts

Signpost_AirSparkle:
		move.w	#$400,d0
		move.w	obX(a0),d1
		cmp.w	objoff_34(a0),d1
		blo.s	.accelerate
		neg.w	d0
.accelerate:
		move.w	#$280,d1
		add.w	d0,obVelX(a0)
		bpl.s	.move
		move.w	#$380,d1
.move:
		move.w	d1,obPriority(a0)
		jsr	(ObjectMove).l
		lea	Ani_SignpostAirSparkle(pc),a1
		jsr	(AnimateSprite).l
		subq.w	#1,objoff_36(a0)
		jmi	(DeleteObject).l
		jmp	(DisplaySprite).l

Ani_SignpostAirSparkle:
		dc.w	.frames-Ani_SignpostAirSparkle
.frames:
		dc.b	1,1,2,3,4,afEnd
		even
; ===========================================================================
