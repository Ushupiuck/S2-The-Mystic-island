; ---------------------------------------------------------------------------
; Object 3D - Eggman (GHZ)
; S1 timed flight, pendulum and escape; staged weapon deployment and breakup
; adapted from S3&K's Sky Sanctuary boss.
; ---------------------------------------------------------------------------
BGHZ_FlashColor = objoff_2E	; word: palette color saved before a hit
BGHZ_WeaponReady = objoff_30	; byte: set by the fully extended chain
BGHZ_BaseX = objoff_34		; longs: ObjectMove_Reserved2's unbobbed position
BGHZ_Parent = objoff_38		; long: face/exhaust -> ship
BGHZ_BaseY = objoff_3C
BGHZ_Timer = objoff_40		; word: flight/wait/defeat/recovery timer
BGHZ_FlashTimer = objoff_42	; byte: remaining invulnerable frames
BGHZ_BobAngle = objoff_43		; byte: vertical sine phase

BGHZ_Approach = 2
BGHZ_Deploy = 4
BGHZ_Patrol = 6
BGHZ_Explode = 8
BGHZ_Recover = $A
BGHZ_Escape = $C
BGHZ_CenterX = boss_ghz_x+$A0

Obj3D:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	BGHZ_Index(pc,d0.w),d1
		jmp	BGHZ_Index(pc,d1.w)
; ===========================================================================
BGHZ_Index:	dc.w BGHZ_Main-BGHZ_Index
		dc.w BGHZ_ShipMain-BGHZ_Index
		dc.w BGHZ_FaceMain-BGHZ_Index
		dc.w BGHZ_FlameMain-BGHZ_Index

BGHZ_ObjData:	dc.b 2,0		; routine, animation
		dc.b 4,1
		dc.b 6,7
BGHZ_ObjData_End:
; ===========================================================================

BGHZ_Main:	; Routine 0
		; Reserve the face and exhaust together. A full pool retries next frame.
		lea	object_size(a0),a1
		moveq	#(BGHZ_ObjData_End-BGHZ_ObjData)/2-2,d1
.find_slot:
		cmpa.w	#v_lvlobjend,a1
		bhs.s	.return
		tst.l	code(a1)
		bne.s	.next_slot
		dbf	d1,.next_slot
		bra.s	.slots_ready
.next_slot:
		lea	object_size(a1),a1
		bra.s	.find_slot
.return:
		rts
.slots_ready:
		lea	BGHZ_ObjData(pc),a2
		movea.l	a0,a1
		moveq	#(BGHZ_ObjData_End-BGHZ_ObjData)/2-1,d1
		bra.s	BGHZ_LoadBoss

BGHZ_Loop:
		jsr	(FindNextFreeObj).l
BGHZ_LoadBoss:
		move.b	(a2)+,obRoutine(a1)
		move.l	#Obj3D,code(a1)
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		move.l	#Map_Eggman,obMap(a1)
		move.b	#Map_Eggman_height,height_pixels(a1)
		move.w	#make_art_tile(ArtTile_Eggman,0,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#sprite_bound($20,Map_Eggman_width),obActWid(a1)
		move.w	#$180,obPriority(a1)
		move.b	(a2)+,obAnim(a1)
		move.l	a0,BGHZ_Parent(a1)
		dbf	d1,BGHZ_Loop
		move.l	obX(a0),BGHZ_BaseX(a0)
		move.l	obY(a0),BGHZ_BaseY(a0)
		move.b	#$F,obColType(a0)
		move.b	#8,obColProp(a0)

BGHZ_ShipMain:	; Routine 2
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	BGHZ_ShipIndex(pc,d0.w),d1
		jsr	BGHZ_ShipIndex(pc,d1.w)
		tst.l	code(a0)		; the escape state may have deleted the ship
		beq.s	.return
		bsr.w	BGHZ_UpdatePosition
		bsr.w	BGHZ_CheckHits
		bra.w	BGHZ_Animate
.return:
		rts
; ===========================================================================
BGHZ_ShipIndex:	dc.w BGHZ_ShipStart-BGHZ_ShipIndex
		dc.w BGHZ_MakeBall-BGHZ_ShipIndex
		dc.w BGHZ_ShipWait-BGHZ_ShipIndex
		dc.w BGHZ_ShipMove-BGHZ_ShipIndex
		dc.w BGHZ_ShipExplode-BGHZ_ShipIndex
		dc.w BGHZ_ShipRecover-BGHZ_ShipIndex
		dc.w BGHZ_ShipEscape-BGHZ_ShipIndex
; ===========================================================================

BGHZ_ShipStart:
		move.w	#$100,obVelY(a0)
		jsr	(ObjectMove_Reserved2).l
		cmpi.w	#boss_ghz_y+$38,BGHZ_BaseY(a0)
		blo.s	.return
		clr.w	obVelY(a0)
		move.b	#BGHZ_Approach,ob2ndRout(a0)
.return:
		rts
; ---------------------------------------------------------------------------

BGHZ_MakeBall:
		cmpi.w	#BGHZ_CenterX,BGHZ_BaseX(a0)
		bls.s	.make_ball
		move.w	#-$100,obVelX(a0)
		move.w	#-$40,obVelY(a0)
		jsr	(ObjectMove_Reserved2).l
		cmpi.w	#BGHZ_CenterX,BGHZ_BaseX(a0)
		bhi.s	.return
.make_ball:
		move.w	#BGHZ_CenterX,BGHZ_BaseX(a0)
		clr.w	obVelX(a0)
		clr.w	obVelY(a0)
		jsr	(FindNextFreeObj).l
		bne.s	.return			; stay at the anchor and retry
		move.l	#Obj48,code(a1)
		move.w	BGHZ_BaseX(a0),obX(a1)
		move.w	BGHZ_BaseY(a0),obY(a1)
		move.l	a0,BGHZ_Parent(a1)
		move.b	#BGHZ_Deploy,ob2ndRout(a0)
		move.w	#120-1,BGHZ_Timer(a0)	; S1's opening pause includes weapon deployment
.return:
		rts
; ---------------------------------------------------------------------------

BGHZ_ShipWait:
		subq.w	#1,BGHZ_Timer(a0)
		bpl.s	.return
		tst.b	BGHZ_WeaponReady(a0)
		bne.s	.start_pass
		clr.w	BGHZ_Timer(a0)		; a full chain pool can retry indefinitely
		rts
.start_pass:
		move.b	#BGHZ_Patrol,ob2ndRout(a0)
		move.w	#64-1,BGHZ_Timer(a0)
		move.w	#$100,obVelX(a0)
		cmpi.w	#BGHZ_CenterX,BGHZ_BaseX(a0)
		bne.s	.face_direction
		move.w	#128-1,BGHZ_Timer(a0)	; first pass: quarter speed from the center
		move.w	#$40,obVelX(a0)
.face_direction:
		btst	#0,obStatus(a0)
		bne.s	.return
		neg.w	obVelX(a0)
.return:
		rts
; ---------------------------------------------------------------------------

BGHZ_ShipMove:
		subq.w	#1,BGHZ_Timer(a0)
		bmi.s	.turn
		jmp	(ObjectMove_Reserved2).l
.turn:
		bchg	#0,obStatus(a0)
		move.w	#64-1,BGHZ_Timer(a0)
		move.b	#BGHZ_Deploy,ob2ndRout(a0)
		clr.w	obVelX(a0)
		rts
; ---------------------------------------------------------------------------

BGHZ_UpdatePosition:
		move.b	BGHZ_BobAngle(a0),d0
		jsr	(CalcSine).l
		asr.w	#6,d0
		add.w	BGHZ_BaseY(a0),d0
		move.w	d0,obY(a0)
		move.w	BGHZ_BaseX(a0),obX(a0)
		addq.b	#2,BGHZ_BobAngle(a0)
		rts
; ---------------------------------------------------------------------------

BGHZ_CheckHits:
		cmpi.b	#BGHZ_Explode,ob2ndRout(a0)
		bhs.s	.return
		tst.b	obStatus(a0)
		bmi.s	BGHZ_Defeat
		tst.b	obColType(a0)
		bne.s	.return
		tst.b	BGHZ_FlashTimer(a0)
		bne.s	.flash
		move.w	(v_palette+$22).w,BGHZ_FlashColor(a0)
		move.b	#$20,BGHZ_FlashTimer(a0)
		move.w	#sfx_HitBoss,d0
		jsr	(PlaySound_Special).l
.flash:
		move.w	BGHZ_FlashColor(a0),d0
		btst	#0,BGHZ_FlashTimer(a0)
		bne.s	.set_color
		move.w	#cWhite,d0
.set_color:
		move.w	d0,(v_palette+$22).w
		subq.b	#1,BGHZ_FlashTimer(a0)
		bne.s	.return
		move.b	#$F,obColType(a0)	; final flash frame restored the saved color
.return:
		rts
; ---------------------------------------------------------------------------

BGHZ_Defeat:
		; A lethal hit or forced defeat must not leave the level palette white.
		tst.b	BGHZ_FlashTimer(a0)
		beq.s	.palette_ready
		move.w	BGHZ_FlashColor(a0),(v_palette+$22).w
		clr.b	BGHZ_FlashTimer(a0)
.palette_ready:
		clr.b	obColType(a0)
		clr.w	obVelX(a0)
		clr.w	obVelY(a0)
		moveq	#100,d0
		jsr	(AddPoints).l
		move.b	#BGHZ_Explode,ob2ndRout(a0)
		move.w	#$B3,BGHZ_Timer(a0)
		rts
; ---------------------------------------------------------------------------

BGHZ_ShipExplode:
		subq.w	#1,BGHZ_Timer(a0)
		bmi.s	.recover
		moveq	#BossExplosion_GHZ,d0
		jmp	(BossExplosion_Start).l
.recover:
		bset	#0,obStatus(a0)
		bclr	#7,obStatus(a0)
		move.b	#BGHZ_Recover,ob2ndRout(a0)
		move.w	#-$26,BGHZ_Timer(a0)
		move.b	#1,(Boss_defeated_flag).w
		rts
; ---------------------------------------------------------------------------

BGHZ_ShipRecover:
		addq.w	#1,BGHZ_Timer(a0)
		beq.s	.stop
		bpl.s	.rise
		addi.w	#$18,obVelY(a0)
		jmp	(ObjectMove_Reserved2).l
.rise:
		cmpi.w	#$30,BGHZ_Timer(a0)
		blo.s	.accelerate
		beq.s	.music
		cmpi.w	#$38,BGHZ_Timer(a0)
		blo.s	.move
		move.b	#BGHZ_Escape,ob2ndRout(a0)
		bra.s	.move
.accelerate:
		subq.w	#8,obVelY(a0)
		bra.s	.move
.music:
		moveq	#plcid_Explode,d0
		jsr	(LoadPLC).l		; capsule explosions reuse the ordinary bank
		moveq	#plcid_GHZAnimals,d0
		jsr	(LoadPLC).l		; the large effect also overlaps animal bank 1
		clr.b	(f_lockscreen).w
		jsr	(GetLevelMusic).l
		jsr	(PlayMusic).l
.stop:
		clr.w	obVelY(a0)
.move:
		jmp	(ObjectMove_Reserved2).l
; ---------------------------------------------------------------------------

BGHZ_ShipEscape:
		move.w	#$400,obVelX(a0)
		move.w	#-$40,obVelY(a0)
		cmpi.w	#boss_ghz_end,(v_limitright2).w
		bhs.s	.check_visible
		addq.w	#2,(v_limitright2).w
		jmp	(ObjectMove_Reserved2).l
.check_visible:
		tst.b	obRender(a0)
		bpl.w	BGHZ_Delete
		jmp	(ObjectMove_Reserved2).l
; ===========================================================================

BGHZ_FaceMain:	; Routine 4
		movea.l	BGHZ_Parent(a0),a1
		cmpi.l	#Obj3D,code(a1)
		bne.w	BGHZ_Delete
		cmpi.b	#2,obRoutine(a1)
		bne.w	BGHZ_Delete
		moveq	#1,d1			; idle
		cmpi.b	#BGHZ_Explode,ob2ndRout(a1)
		bhs.s	.defeated
		tst.b	BGHZ_FlashTimer(a1)
		bne.s	.hurt
		cmpi.b	#BGHZ_Deploy,ob2ndRout(a1)
		bne.s	.check_player
		cmpi.w	#BGHZ_CenterX,BGHZ_BaseX(a1)
		beq.s	.laugh			; laugh during the opening pause, not every turn
.check_player:
		cmpi.b	#4,(v_player+obRoutine).w
		bhs.s	.laugh
		tst.l	(v_player2+code).w
		beq.s	.animate
		cmpi.b	#4,(v_player2+obRoutine).w
		blo.s	.animate
.laugh:
		moveq	#4,d1
		bra.s	.animate
.hurt:
		moveq	#5,d1
		bra.s	.animate
.defeated:
		moveq	#6,d1
		cmpi.b	#BGHZ_Recover,ob2ndRout(a1)
		bne.s	.animate
		moveq	#$A,d1
.animate:
		move.b	d1,obAnim(a0)
		bra.s	BGHZ_Display
; ---------------------------------------------------------------------------

BGHZ_FlameMain:	; Routine 6
		movea.l	BGHZ_Parent(a0),a1
		cmpi.l	#Obj3D,code(a1)
		bne.s	BGHZ_Delete
		cmpi.b	#2,obRoutine(a1)
		bne.s	BGHZ_Delete
		move.b	#7,obAnim(a0)		; no thrust
		cmpi.b	#BGHZ_Escape,ob2ndRout(a1)
		beq.s	.escape
		tst.w	obVelX(a1)
		beq.s	BGHZ_Display
		move.b	#8,obAnim(a0)
		bra.s	BGHZ_Display
.escape:
		move.b	#$B,obAnim(a0)

BGHZ_Display:
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		move.b	obStatus(a1),obStatus(a0)
BGHZ_Animate:
		lea	Ani_Eggman(pc),a1
		jsr	(AnimateSprite).l
		move.b	obStatus(a0),d0
		andi.b	#3,d0
		andi.b	#$FC,obRender(a0)
		or.b	d0,obRender(a0)
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

BGHZ_Delete:
		jmp	(DeleteObject).l
