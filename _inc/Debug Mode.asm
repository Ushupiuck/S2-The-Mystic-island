; ---------------------------------------------------------------------------
; S3&K Debug controls, with routine-pointer SSTs and twelve-byte Debug entries.
; Only player 1 enters here. B: placement; hold C + press B: frame cycling.
; Placement: A next, hold A + press C previous, C place, B return to play.
; The existing full-height Debug travel range is retained for arena testing.
; ---------------------------------------------------------------------------
Debug_Begin:
		move.w	#DebugType_Placement,(Debug_placement_mode).w
		btst	#bitC,(v_jpadhold1).w
		beq.s	.placement
		move.w	#DebugType_FrameCycle,(Debug_placement_mode).w
		rts
.placement:
		clr.b	(f_lockctrl).w
		rts

DebugMode:
		cmpi.b	#DebugType_FrameCycle,(Debug_placement_type).w
		beq.w	Debug_FrameCycle
		moveq	#0,d0
		move.b	(Debug_placement_routine).w,d0
		move.w	DebugIndex(pc,d0.w),d1
		jmp	DebugIndex(pc,d1.w)
DebugIndex:
		dc.w Debug_Init-DebugIndex
		dc.w Debug_Main-DebugIndex

Debug_Init:
		addq.b	#2,(Debug_placement_routine).w
		move.l	obMap(a0),(Debug_saved_mappings).w
		move.w	obGfx(a0),(Debug_saved_art_tile).w
		move.b	width_pixels(a0),(Debug_saved_width).w
		move.b	height_pixels(a0),(Debug_saved_height).w
		move.w	(Camera_Min_Y_pos).w,(v_limittopdb).w
		move.w	(Camera_Max_Y_pos_target).w,(v_limitbtmdb).w
		clr.w	(Camera_Min_Y_pos).w
		move.w	#Level_YWrapMask-(224-1),(Camera_Max_Y_pos_target).w
		andi.w	#Level_YWrapMask,obY(a0)
		andi.w	#Level_YWrapMask,(Camera_Y_pos).w
		andi.w	#(Level_YWrapMask>>1),(Camera_BG_Y_pos).w
		clr.b	(Scroll_lock).w
		clr.b	(Deform_lock).w
		clr.b	(f_wtunnelmode).w
		bclr	#status.player.underwater,obStatus(a0)
		move.w	#30,(v_air).w
		move.b	#30,air_left(a0)
		movea.l	a0,a2
		jsr	(Player_UpdateSpeed).l
		jsr	(Tails_ReleaseCarry).l
		clr.b	obFrame(a0)
		clr.b	obAnim(a0)
		andi.b	#(1<<render_flags.x_flip)|(1<<render_flags.y_flip),obRender(a0)
		ori.b	#1<<render_flags.level_fg,obRender(a0)
		cmpi.w	#BonusStage,(v_gamemode).w
		bne.s	.select
		clr.w	(v_ssrotate).l
		clr.w	(v_ssangle).l
.select:
		bsr.w	Debug_SelectList
		cmp.b	(Debug_object).w,d6
		bhi.s	.noreset
		clr.b	(Debug_object).w
.noreset:
		bsr.w	LoadDebugObjectSprite
		move.b	#12,(Debug_Accel_Timer).w
		move.b	#1,(Debug_Speed).w

Debug_Main:
		bsr.w	Debug_SelectList
		bsr.s	Debug_Control
		jmp	(DisplaySprite).l

; The four-act index matches the layout/header tables. Bonus-stage previews
; use only art loaded by that stage and do not change the return zone/act.
Debug_SelectList:
		lea	Debug_SS(pc),a2
		cmpi.w	#BonusStage,(v_gamemode).w
		beq.s	.ready
		moveq	#0,d0
		move.w	(Current_ZoneAndAct).w,d0
		ror.b	#2,d0
		lsr.w	#5,d0			; Zone*8 + Act*2
		lea	(DebugList).l,a2
		adda.w	(a2,d0.w),a2
.ready:
		move.w	(a2)+,d6
		rts

Debug_Control:
		moveq	#0,d4
		move.b	(v_jpadpress1).w,d4
		andi.w	#btnUp|btnDn|btnL|btnR,d4
		bne.s	.dirpressed
		move.b	(v_jpadhold1).w,d0
		andi.w	#btnUp|btnDn|btnL|btnR,d0
		bne.s	.dirheld
		move.b	#12,(Debug_Accel_Timer).w
		move.b	#15,(Debug_Speed).w
		bra.w	Debug_ControlObjects
.dirheld:
		subq.b	#1,(Debug_Accel_Timer).w
		bne.s	Debug_TimerNotOver
		move.b	#1,(Debug_Accel_Timer).w
		addq.b	#1,(Debug_Speed).w
		bne.s	.dirpressed
		move.b	#-1,(Debug_Speed).w
.dirpressed:
		move.b	(v_jpadhold1).w,d4
Debug_TimerNotOver:
		moveq	#0,d1
		move.b	(Debug_Speed).w,d1
		addq.w	#1,d1
		swap	d1
		asr.l	#4,d1
		move.l	obY(a0),d2
		move.l	obX(a0),d3
		btst	#bitUp,d4
		beq.s	.up_done
		sub.l	d1,d2
		moveq	#0,d0
		move.w	(Camera_Min_Y_pos).w,d0
		swap	d0
		cmp.l	d0,d2
		bge.s	.up_done
		move.l	d0,d2
.up_done:
		btst	#bitDn,d4
		beq.s	.down_done
		add.l	d1,d2
		moveq	#0,d0
		move.w	(Camera_Max_Y_pos_target).w,d0
		addi.w	#224-1,d0
		swap	d0
		cmp.l	d0,d2
		blt.s	.down_done
		move.l	d0,d2
.down_done:
		btst	#bitL,d4
		beq.s	.left_done
		sub.l	d1,d3
		bcc.s	.left_done
		moveq	#0,d3
.left_done:
		btst	#bitR,d4
		beq.s	.right_done
		add.l	d1,d3
.right_done:
		move.l	d2,obY(a0)
		move.l	d3,obX(a0)

Debug_ControlObjects:
		btst	#bitA,(v_jpadhold1).w
		beq.s	Debug_SpawnObject
		btst	#bitC,(v_jpadpress1).w
		beq.s	Debug_CycleObjects
		subq.b	#1,(Debug_object).w
		bcc.s	LoadDebugObjectSprite
		add.b	d6,(Debug_object).w
		bra.s	LoadDebugObjectSprite
Debug_CycleObjects:
		btst	#bitA,(v_jpadpress1).w
		beq.s	Debug_SpawnObject
		addq.b	#1,(Debug_object).w
		cmp.b	(Debug_object).w,d6
		bhi.s	LoadDebugObjectSprite
		clr.b	(Debug_object).w
LoadDebugObjectSprite:
		moveq	#0,d0
		move.b	(Debug_object).w,d0
		move.w	d0,d1
		add.w	d0,d0
		add.w	d1,d0
		lsl.w	#2,d0			; entry * 12
		move.l	DebugEntry_mappings(a2,d0.w),obMap(a0)
		move.w	DebugEntry_art_tile(a2,d0.w),obGfx(a0)
		move.b	DebugEntry_frame(a2,d0.w),obFrame(a0)
		bra.w	Set_SpriteBounds	; scan only when the selected preview changes

Debug_SpawnObject:
		btst	#bitC,(v_jpadpress1).w
		beq.s	Debug_ExitDebugMode
		jsr	(FindFreeObj).l
		bne.s	Debug_ExitDebugMode
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obRender(a0),d0
		andi.b	#(1<<render_flags.x_flip)|(1<<render_flags.y_flip),d0
		move.b	d0,obRender(a1)
		move.b	d0,obStatus(a1)
		moveq	#0,d0
		move.b	(Debug_object).w,d0
		move.w	d0,d1
		add.w	d0,d0
		add.w	d1,d0
		lsl.w	#2,d0			; entry * 12
		move.l	DebugEntry_code(a2,d0.w),code(a1)
		move.b	DebugEntry_subtype(a2,d0.w),obSubtype(a1)
		rts				; cleared SST => respawn_addr = 0

Debug_ExitDebugMode:
		btst	#bitB,(v_jpadpress1).w
		beq.w	.return
		clr.w	(Debug_placement_mode).w
		disable_ints
		jsr	(HUD_Base).l
		move.b	#1,(f_scorecount).w
		move.b	#$80,(f_ringcount).w
		enable_ints
		lea	(v_player).w,a1
		move.l	(Debug_saved_mappings).w,obMap(a1)
		move.w	(Debug_saved_art_tile).w,obGfx(a1)
		move.b	(Debug_saved_width).w,width_pixels(a1)
		move.b	(Debug_saved_height).w,height_pixels(a1)
		bsr.s	Debug_ResetPlayerStats
		move.w	(v_limittopdb).w,(Camera_Min_Y_pos).w
		move.w	(v_limitbtmdb).w,(Camera_Max_Y_pos_target).w
		cmpi.w	#BonusStage,(v_gamemode).w
		bne.s	.return
		clr.w	(v_ssangle).l
		move.w	#$40,(v_ssrotate).l
		move.b	#AniIDSonAni_Roll,obAnim(a1)
		bset	#status.player.rolling,obStatus(a1)
		move.b	#sonic_roll_height,obHeight(a1)
		move.b	#sonic_roll_width,obWidth(a1)
.return:
		rts

Debug_ResetPlayerStats:
		moveq	#0,d0			; HUD_Base is allowed to destroy d0
		move.b	d0,obAnim(a1)
		move.b	#-1,obPrevAni(a1)
		move.b	d0,obAniFrame(a1)
		move.b	d0,obFrame(a1)
		move.w	d0,obXSub(a1)
		move.w	d0,obYSub(a1)
		move.b	d0,obControl(a1)
		move.b	d0,spindash_flag(a1)
		move.w	d0,spindash_counter(a1)
		move.w	d0,move_lock(a1)
		move.b	d0,stick_to_convex(a1)
		move.b	d0,jumping(a1)
		move.b	d0,standonobject(a1)
		move.b	d0,scroll_delay_counter(a1)
		move.b	d0,obAngle(a1)
		move.b	d0,flip_angle(a1)
		move.b	d0,flip_turned(a1)
		move.b	d0,flips_remaining(a1)
		move.w	d0,obVelX(a1)
		move.w	d0,obVelY(a1)
		move.w	d0,obInertia(a1)
		andi.b	#1<<status.player.x_flip,obStatus(a1)
		ori.b	#1<<status.player.in_air,obStatus(a1)
		move.b	obStatus(a1),d1
		andi.b	#1<<render_flags.x_flip,d1
		ori.b	#1<<render_flags.level_fg,d1
		move.b	d1,obRender(a1)
		move.b	#2,obRoutine(a1)
		move.b	d0,ob2ndRout(a1)
		move.b	default_y_radius(a1),obHeight(a1)
		move.b	default_x_radius(a1),obWidth(a1)
		move.b	d0,(f_playerctrl).w
		move.b	d0,(f_lockctrl).w
		move.b	d0,(Deform_lock).w
		move.b	d0,(Horiz_scroll_delay_val).w
		move.w	#Camera_LookCenter,(Camera_Y_pos_bias).w
		cmpi.b	#CharacterID_Tails,character_id(a1)
		bne.s	.return
		move.b	d0,tails_flight_flag(a1)
		move.b	d0,tails_flight_energy(a1)
		move.b	d0,tails_hidden(a1)
.return:
		rts

Debug_FrameCycle:
		btst	#bitB,(v_jpadpress1).w
		beq.s	.next
		clr.w	(Debug_placement_mode).w
.next:
		addq.b	#1,obFrame(a0)
		cmpi.b	#CharacterID_Tails,character_id(a0)
		beq.s	.tails
		cmpi.b	#Map_Sonic_frames,obFrame(a0)
		blo.s	.sonic_art
		clr.b	obFrame(a0)
.sonic_art:
		jsr	(LoadSonicDynPLC).l
		jmp	(DisplaySprite).l
.tails:
		cmpi.b	#Map_Tails_frames,obFrame(a0)
		blo.s	.tails_art
		clr.b	obFrame(a0)
.tails_art:
		jsr	(LoadTailsDynPLC).l
		jmp	(DisplaySprite).l

; Bonus-stage Debug has no level PLCs. Its ring and sparkle art share the stage
; bank; the rotating layout itself still uses its dedicated S1 mapping ABI.
Debug_SS:
		dc.w 1
		dc.l Obj12,Map_Ring
		dc.b 0,0
		dc.w make_art_tile(ArtTile_SS_Rings,1,0)

; ---------------------------------------------------------------------------
; Initialize a dynamically selected debug mapping. Normal objects use constant
; bounds at setup; this scan never runs from Render_Sprites or DisplaySprite.
; Preserve the debug selector's registers and its object/list pointers.
; ---------------------------------------------------------------------------
Set_SpriteBounds:
		movem.l	d0-d4/a1,-(sp)
		movea.l	obMap(a0),a1
		moveq	#0,d0
		move.b	obFrame(a0),d0
		add.w	d0,d0
		adda.w	(a1,d0.w),a1
		move.w	(a1)+,d4
		moveq	#0,d2
		moveq	#0,d3
		subq.w	#1,d4
		bmi.s	.done
.piece:
		move.b	(a1)+,d0
		ext.w	d0
		moveq	#0,d1
		move.b	(a1)+,d1
		andi.w	#3,d1
		addq.w	#1,d1
		lsl.w	#3,d1
		add.w	d0,d1		; bottom edge
		tst.w	d0
		bpl.s	.bottom
		neg.w	d0			; the top is above the origin
		cmp.w	d1,d0
		bge.s	.height
.bottom:
		move.w	d1,d0
.height:
		cmp.w	d2,d0
		bls.s	.width
		move.w	d0,d2
.width:
		moveq	#0,d1
		move.b	-1(a1),d1
		lsr.w	#2,d1
		addq.w	#1,d1
		lsl.w	#3,d1
		addq.w	#2,a1
		move.w	(a1)+,d0
		add.w	d0,d1		; right edge
		tst.w	d0
		bpl.s	.right
		neg.w	d0
		cmp.w	d1,d0
		bge.s	.extent
.right:
		move.w	d1,d0
.extent:
		cmp.w	d3,d0
		bls.s	.next
		move.w	d0,d3
.next:
		dbf	d4,.piece
.done:
		cmpi.w	#$FF,d2
		bls.s	.height_ready
		move.w	#$FF,d2
.height_ready:
		cmpi.w	#$FF,d3
		bls.s	.width_ready
		move.w	#$FF,d3
.width_ready:
		move.b	d2,height_pixels(a0)
		move.b	d3,width_pixels(a0)
		movem.l	(sp)+,d0-d4/a1
		rts
