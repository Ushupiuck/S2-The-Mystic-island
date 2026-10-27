; ---------------------------------------------------------------------------
; Object 7E - End of level signpost
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

signpost_loaded = objoff_3A
; ===========================================================================

Signpost_Index:	dc.w Signpost_Init-Signpost_Index
		dc.w Signpost_Main-Signpost_Index
		dc.w Signpost_Spin-Signpost_Index
		dc.w Signpost_EndLevel-Signpost_Index
		dc.w Signpost_Sparkle.return-Signpost_Index
; ===========================================================================
; loc_EFD6:
Signpost_Init:
		st	signpost_loaded(a0)
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Signpost,obMap(a0)
		move.b	#Map_Signpost_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_Signpost,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#sprite_bound($18,Map_Signpost_width),obActWid(a0)
		move.w	#$200,obPriority(a0)
; loc_EFFE:
Signpost_Main:
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		blo.w	Signpost_Sparkle.return
		cmpi.w	#32,d0
		bhs.w	Signpost_Sparkle.return
		clr.b	(f_timecount).w
		move.w	(Camera_Max_X_pos).w,(Camera_Min_X_pos).w
		addq.b	#2,obRoutine(a0)
		move.w	#sfx_Signpost,d0
		jmp	(PlaySound).l
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
		addq.b	#1,obAnim(a0)
		cmpi.b	#3,obAnim(a0)
		bne.s	Signpost_Sparkle
		addq.b	#2,obRoutine(a0)
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	Signpost_Sparkle
		addq.b	#1,obAnim(a0)		; solo Tails finishes on his own portrait
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
		; Keep shield state, but stop effect uploads while act-clear bonus
		; digits reuse the auxiliary bank. A fresh level clears both caches.
		move.b	#PlayerEffects_ResultsLoaded,(v_shieldobj+effect_loaded_frame).w
		move.b	#PlayerEffects_ResultsLoaded,(v_shieldobj2+effect_loaded_frame).w
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
.eggman:	dc.b	$F,2,afEnd
.spin1:	dc.b	1,2,3,4,5,1,3,4,5,0,3,4,5,afEnd
.spin2:	dc.b	1,2,3,4,5,1,3,4,5,0,3,4,5,afEnd
.sonic:		dc.b	$F,0,afEnd
.tails:		dc.b	$F,1,afEnd
		even
