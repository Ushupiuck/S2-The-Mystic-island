; ---------------------------------------------------------------------------
; Object 0A - drowning bubbles and countdown numbers
; ---------------------------------------------------------------------------

Obj0A:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj0A_Index(pc,d0.w),d1
		jmp	Obj0A_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj0A_Index:	dc.w Obj0A_Init-Obj0A_Index
		dc.w Obj0A_Animate-Obj0A_Index
		dc.w Obj0A_ChkWater-Obj0A_Index
		dc.w Obj0A_Display-Obj0A_Index
		dc.w Obj0A_Delete-Obj0A_Index
		dc.w Obj0A_Countdown-Obj0A_Index
		dc.w Obj0A_AirLeft-Obj0A_Index
		dc.w Obj0A_DisplayNumber-Obj0A_Index
		dc.w Obj0A_Delete-Obj0A_Index
; ---------------------------------------------------------------------------

Obj0A_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Bubbles,obMap(a0)
		move.b	#Map_Bubbles_height,height_pixels(a0)
		cmpi.w	#v_player2,obParent(a0)
		bne.s	.primary_map
		move.l	#Map_Bubbles2,obMap(a0)
.primary_map:
		move.w	#make_art_tile(ArtTile_Bubbles,0,0),obGfx(a0)
		move.b	#$84,obRender(a0)
		move.b	#sprite_bound($10,Map_Bubbles_width),obActWid(a0)
		move.w	#$80,obPriority(a0)
		move.w	obSubtype(a0),d0
		btst	#7,d0
		beq.s	loc_11ECC
		addq.b	#8,obRoutine(a0)
		andi.w	#$7F,d0
		move.b	d0,objoff_37(a0)
		bra.w	Obj0A_Countdown
; ---------------------------------------------------------------------------

loc_11ECC:
		move.b	d0,obAnim(a0)
		move.w	obX(a0),objoff_34(a0)
		move.w	#-$100,obVelY(a0)

Obj0A_Animate:
		lea	Ani_Obj0A(pc),a1
		bsr.w	AnimateSprite

Obj0A_ChkWater:
		move.w	(v_waterpos1).w,d0
		cmp.w	obY(a0),d0
		blo.s	loc_11F0A
		move.b	#6,obRoutine(a0)
		addq.b	#7,obAnim(a0)
		cmpi.b	#$D,obAnim(a0)
		bls.s	Obj0A_Display
		move.b	#$D,obAnim(a0)
		bra.s	Obj0A_Display
; ---------------------------------------------------------------------------

loc_11F0A:
		tst.b	(f_wtunnelmode).w
		beq.s	loc_11F14
		addq.w	#4,objoff_34(a0)

loc_11F14:
		move.b	obAngle(a0),d0
		addq.b	#1,obAngle(a0)
		andi.w	#$7F,d0
		lea	Drown_WobbleData(pc),a1
		move.b	(a1,d0.w),d0
		ext.w	d0
		add.w	objoff_34(a0),d0
		move.w	d0,obX(a0)
		bsr.s	Obj0A_ShowNumber
		bsr.w	ObjectMove
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bra.s	Obj0A_Draw
; ---------------------------------------------------------------------------

Obj0A_Display:
		bsr.s	Obj0A_ShowNumber
		lea	Ani_Obj0A(pc),a1
		bsr.w	AnimateSprite
Obj0A_Draw:
		bsr.w	Obj0A_LoadArt
		bcs.s	.return
		bra.w	DisplaySprite
.return:	rts

; S3&K separates this path so reaching the surface cannot turn a number
; back into a bubble. Resurfacing/refilling air removes either player's number.
Obj0A_DisplayNumber:
		bsr.w	Obj0A_GetAir
		cmpi.w	#12,d0
		bhi.w	DeleteObject
		bra.s	Obj0A_Display
; ---------------------------------------------------------------------------

Obj0A_Delete:
		bra.w	DeleteObject
; ---------------------------------------------------------------------------

Obj0A_AirLeft:
		bsr.w	Obj0A_GetAir
		cmpi.w	#$C,d0
		bhi.w	DeleteObject
		subq.w	#1,objoff_3C(a0)
		bne.s	loc_11F82
		move.b	#$E,obRoutine(a0)
		addq.b	#7,obAnim(a0)
		bsr.s	Obj0A_ShowNumber
		lea	Ani_Obj0A(pc),a1
		bsr.w	AnimateSprite
		bra.s	Obj0A_Draw
; ---------------------------------------------------------------------------

loc_11F82:
		lea	Ani_Obj0A(pc),a1
		bsr.w	AnimateSprite
		tst.b	obRender(a0)
		bpl.w	DeleteObject
		bra.s	Obj0A_Draw

; =============== S U B	R O U T	I N E =======================================


Obj0A_ShowNumber:
		tst.w	objoff_3C(a0)
		beq.s	.return
		subq.w	#1,objoff_3C(a0)
		bne.s	.return
		cmpi.b	#7,obAnim(a0)
		bhs.s	.return
		move.w	#$F,objoff_3C(a0)
		clr.w	obVelY(a0)
		move.b	#$80,obRender(a0)
		move.w	obX(a0),d0
		sub.w	(Camera_RAM).w,d0
		addi.w	#$80,d0
		move.w	d0,obX(a0)
		move.w	obY(a0),d0
		sub.w	(Camera_Y_pos).w,d0
		addi.w	#$80,d0
		move.w	d0,obScreenY(a0)
		move.b	#$C,obRoutine(a0)
.return:	rts
; End of function Obj0A_ShowNumber

; ---------------------------------------------------------------------------

Obj0A_Countdown:
		bsr.w	Obj0A_GetAir
		tst.w	objoff_30(a0)
		bne.w	loc_121D6
		tst.b	obControl(a2)	; CPU catch-up and scripted absence do not consume air
		bmi.w	Obj0A_ShowNumber.return
		cmpi.b	#6,obRoutine(a2)
		bhs.w	Obj0A_ShowNumber.return
		btst	#6,obStatus(a2)
		beq.w	Obj0A_ShowNumber.return
		subq.w	#1,objoff_3C(a0)
		bpl.w	loc_121FC
		move.w	#60-1,objoff_3C(a0)
		move.w	#1,objoff_3A(a0)
		jsr	(RandomNumber).l
		andi.w	#1,d0
		move.b	d0,objoff_38(a0)
		bsr.w	Obj0A_GetAir
		cmpi.w	#25,d0
		beq.s	loc_12166
		cmpi.w	#20,d0
		beq.s	loc_12166
		cmpi.w	#15,d0
		beq.s	loc_12166
		cmpi.w	#12,d0
		bhi.s	loc_12170
		bne.s	loc_12152
		cmpa.w	#v_player,a2
		bne.s	loc_12152
		move.w	#bgm_Drowning,d0
		jsr	(PlaySound).l

loc_12152:
		subq.b	#1,objoff_36(a0)
		bpl.s	loc_12170
		move.b	objoff_37(a0),objoff_36(a0)
		bset	#7,objoff_3A(a0)
		bra.s	loc_12170
; ---------------------------------------------------------------------------

loc_12166:
		move.w	#sfx_Warning,d0
		jsr	(PlaySound_Special).l

loc_12170:
		cmpa.w	#v_player,a2
		beq.s	.primary_air
		subq.b	#1,air_left(a2)
		bhs.w	loc_1220C
		bra.s	.drown
.primary_air:
		subq.w	#1,(v_air).w
		bhs.w	loc_1220C
		bsr.w	ResumeMusic
		move.b	#$81,(f_playerctrl).w
		move.b	#PlayerInputLock_Drowning,(f_lockctrl).w
		clr.w	(v_jpadholdlogical).w
		clr.w	(v_jpadholdlogical2).w
.drown:
		move.b	#$81,obControl(a2)
		move.w	#sfx_Drown,d0
		jsr	(PlaySound_Special).l
		move.b	#$A,objoff_38(a0)
		move.w	#1,objoff_3A(a0)
		move.w	#60*2,objoff_30(a0)
		move.l	a0,-(sp)
		movea.l	a2,a0
		jsr	(Player_ClearPowerUps).l
		bsr.w	Sonic_ResetOnFloor
		move.b	#AniIDSonAni_Drown,obAnim(a0)
		bset	#1,obStatus(a0)
		bset	#7,obGfx(a0)
		clr.w	obVelY(a0)
		clr.w	obVelX(a0)
		clr.w	obInertia(a0)
		cmpa.w	#v_player,a0
		bne.s	+
		move.b	#1,(Deform_lock).w
+
		movea.l	(sp)+,a0
		rts
; ---------------------------------------------------------------------------

loc_121D6:
		subq.w	#1,objoff_30(a0)
		bne.s	loc_121E4
		move.b	#6,obRoutine(a2)
		rts
; ---------------------------------------------------------------------------

loc_121E4:
		move.l	a0,-(sp)
		movea.l	a2,a0
		bsr.w	ObjectMove
		addi.w	#$10,obVelY(a0)
		movea.l	(sp)+,a0
; ---------------------------------------------------------------------------

loc_121FC:
		tst.w	objoff_3A(a0)
		beq.w	loc_12242.return
		subq.w	#1,objoff_3E(a0)
		bpl.w	loc_12242.return

loc_1220C:
		jsr	(RandomNumber).l
		andi.w	#$F,d0
		move.w	d0,objoff_3E(a0)
		bsr.w	FindFreeObj
		bne.s	loc_12242.return
		move.l	#Obj0A,code(a1)
		move.w	a2,obParent(a1)
		move.w	obX(a2),obX(a1)
		moveq	#6,d0
		btst	#0,obStatus(a2)
		beq.s	loc_12242
		neg.w	d0
		move.b	#$40,obAngle(a1)

loc_12242:
		add.w	d0,obX(a1)
		move.w	obY(a2),obY(a1)
		move.w	#6,obSubtype(a1)
		tst.w	objoff_30(a0)
		beq.s	loc_1228E
		andi.w	#7,objoff_3E(a0)
		move.w	obY(a2),d0
		subi.w	#$C,d0
		move.w	d0,obY(a1)
		jsr	(RandomNumber).l
		move.b	d0,obAngle(a1)
		move.w	(Timer_frames).w,d0
		andi.b	#3,d0
		bne.s	+
		move.w	#$E,obSubtype(a1)
+
		subq.b	#1,objoff_38(a0)
		bpl.s	.return
		clr.w	objoff_3A(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_1228E:
		btst	#7,objoff_3A(a0)
		beq.s	loc_122D2
		bsr.w	Obj0A_GetAir
		move.w	d0,d2
		lsr.w	#1,d2
		jsr	(RandomNumber).l
		andi.w	#3,d0
		bne.s	loc_122BA
		bset	#6,objoff_3A(a0)
		bne.s	loc_122D2
		move.w	d2,obSubtype(a1)
		move.w	#$1C,objoff_3C(a1)

loc_122BA:
		tst.b	objoff_38(a0)
		bne.s	loc_122D2
		bset	#6,objoff_3A(a0)
		bne.s	loc_122D2
		move.w	d2,obSubtype(a1)
		move.w	#$1C,objoff_3C(a1)

loc_122D2:
		subq.b	#1,objoff_38(a0)
		bpl.s	.return
		clr.w	objoff_3A(a0)
.return:	rts
; ---------------------------------------------------------------------------
; Return the parent's air in d0 and pointer in a2. Older/scripted bubbles
; with no parent default to the primary player, retaining their original ABI.
Obj0A_GetAir:
		lea	(v_player).w,a2
		tst.w	obParent(a0)
		beq.s	.primary
		movea.w	obParent(a0),a2
		cmpa.w	#v_player,a2
		beq.s	.primary
		moveq	#0,d0
		move.b	air_left(a2),d0
		rts
.primary:
		move.w	(v_air).w,d0
		rts

; Six streamed tiles per countdown frame, in the owner's dust/splash bank.
Obj0A_LoadArt:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		cmpi.w	#9,d0
		blo.s	.return
		cmpi.w	#$13,d0
		bhs.s	.return
		subq.w	#8,d0
		lea	DPLC_AirCountdown(pc),a2
		move.w	#ArtTile_Sonic_Dust*tile_size,d4
		cmpi.w	#v_player2,obParent(a0)
		bne.s	.load
		move.w	#ArtTile_Tails_Dust*tile_size,d4
.load:
		moveq	#WaterArt_Countdown,d5
		move.l	#Art_AirCountdown,d6
		bra.w	PlayerWaterArt_LoadDPLC
.return:
		andi.b	#$FE,ccr
		rts

DPLC_AirCountdown:
		dc.w .empty-DPLC_AirCountdown
		dc.w .runs+0*4-DPLC_AirCountdown,.runs+1*4-DPLC_AirCountdown
		dc.w .runs+2*4-DPLC_AirCountdown,.runs+3*4-DPLC_AirCountdown
		dc.w .runs+4*4-DPLC_AirCountdown,.runs+5*4-DPLC_AirCountdown
		dc.w .runs+6*4-DPLC_AirCountdown,.runs+7*4-DPLC_AirCountdown
		dc.w .runs+8*4-DPLC_AirCountdown,.runs+9*4-DPLC_AirCountdown
.empty:	dc.w 0
.runs:
		dc.w 1,$5000+0*6,1,$5000+1*6,1,$5000+2*6,1,$5000+3*6,1,$5000+4*6
		dc.w 1,$5000+5*6,1,$5000+6*6,1,$5000+7*6,1,$5000+8*6,1,$5000+9*6

Ani_Obj0A:
		include "animations/Drowning countdown.asm"
; ---------------------------------------------------------------------------
Drown_WobbleData:
		rept 2
		dc.b 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2
		dc.b 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3
		dc.b 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2
		dc.b 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0
		dc.b 0, -1, -1, -1, -1, -1, -2, -2, -2, -2, -2, -3, -3, -3, -3, -3
		dc.b -3, -3, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4
		dc.b -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -3
		dc.b -3, -3, -3, -3, -3, -3, -2, -2, -2, -2, -2, -1, -1, -1, -1, -1
		endm
		even
