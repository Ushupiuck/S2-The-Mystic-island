; Imported from sonicretro/scddisasm f8cf3f0. Normal/damaged subtype: 0/1.
; Six-byte mappings, full code pointers, resident palette-0 art; SST private
; state is relocated from CD $2A-$3F to $30-$45. Both live actors can trigger attacks.
; -------------------------------------------------------------------------
; Sonic CD Disassembly
; -------------------------------------------------------------------------
; Tamabboh object
; -------------------------------------------------------------------------

PP_Tamabboh:
	moveq	#0,d0
	move.b	obRoutine(a0),d0
	move.w	PP_Tamabboh_Index(pc,d0.w),d0
	jsr	PP_Tamabboh_Index(pc,d0.w)
	move.w	objoff_30(a0),d0
	jmp	(MarkObjGone3).l
; End of function PP_Tamabboh

; -------------------------------------------------------------------------
PP_Tamabboh_Index:dc.w	PP_Tamabboh_Init-PP_Tamabboh_Index
	dc.w	PP_Tamabboh_Position-PP_Tamabboh_Index
	dc.w	PP_Tamabboh_Main-PP_Tamabboh_Index
	dc.w	PP_Tamabboh_Wait1-PP_Tamabboh_Index
	dc.w	PP_Tamabboh_Wait2-PP_Tamabboh_Index
	dc.w	PP_Tamabboh_Fire-PP_Tamabboh_Index
; -------------------------------------------------------------------------

PP_Tamabboh_Init:
	addq.b	#2,obRoutine(a0)
	ori.b	#4,obRender(a0)
	move.w	#$200,obPriority(a0)
	move.b	#6,obColType(a0)
	move.b	#$10,obWidth(a0)
	move.b	#sprite_bound($10,Map_PP_Tamabboh1_width),obActWid(a0)
	move.b	#$F,obHeight(a0)
	move.w	obX(a0),objoff_30(a0)
	move.w	#ArtTile_PP_Tamabboh,obGfx(a0)
	tst.w	obSubtype(a0)
	bne.w	.AltMaps
	lea	Map_PP_Tamabboh1(pc),a1
	lea	Ani_PP_Tamabboh1(pc),a2
	move.l	#-$A000,d0
	bra.w	.SetMaps

; -------------------------------------------------------------------------

.AltMaps:
	lea	Map_PP_Tamabboh2(pc),a1
	lea	Ani_PP_Tamabboh2(pc),a2
	move.l	#-$5000,d0

.SetMaps:
	move.l	a1,obMap(a0)
	move.b	#Map_PP_Tamabboh1_height,height_pixels(a0)
	move.l	a2,objoff_36(a0)
	move.l	d0,objoff_32(a0)
; End of function PP_Tamabboh_Init

; -------------------------------------------------------------------------

PP_Tamabboh_Position:
	move.l	#$10000,d0
	add.l	d0,obY(a0)
	jsr	(ObjHitFloor).l
	bpl.s	.End
	add.w	d1,obY(a0)
	addq.b	#2,obRoutine(a0)

.End:
	rts
; End of function PP_Tamabboh_Position

; -------------------------------------------------------------------------

PP_Tamabboh_Main:
	tst.w	(Debug_placement_mode).w
	bne.w	.SkipRange
	tst.w	obSubtype(a0)
	bne.w	.SkipRange
	tst.w	objoff_3A(a0)
	beq.w	.DoRange
	subq.w	#1,objoff_3A(a0)
	bra.w	.SkipRange

; -------------------------------------------------------------------------

.DoRange:
	lea	(v_player).w,a1
	bsr.w	PP_Tamabboh_CheckInRange
	bcs.w	.NextState
	lea	(v_player2).w,a1
	bsr.w	PP_Tamabboh_CheckInRange
	bcs.w	.NextState

.SkipRange:
	move.l	objoff_32(a0),d0
	add.l	d0,obX(a0)
	move.w	obX(a0),d0
	sub.w	objoff_30(a0),d0
	bpl.s	.ChlTirm
	neg.w	d0

.ChlTirm:
	cmpi.w	#$80,d0
	bge.w	.TurnAround
	jsr	(ObjHitFloor).l
	cmpi.w	#-7,d1
	blt.w	.TurnAround
	cmpi.w	#7,d1
	bgt.s	.TurnAround
	add.w	d1,obY(a0)
	movea.l	objoff_36(a0),a1
	jmp	(AnimateSprite).l

; -------------------------------------------------------------------------

.TurnAround:
	move.l	objoff_32(a0),d0
	sub.l	d0,obX(a0)
	neg.l	objoff_32(a0)
	bchg	#0,obRender(a0)
	bchg	#0,obStatus(a0)
	movea.l	objoff_36(a0),a1
	jmp	(AnimateSprite).l

; -------------------------------------------------------------------------

.NextState:
	addq.b	#2,obRoutine(a0)
	rts
; End of function PP_Tamabboh_Main

; -------------------------------------------------------------------------

PP_Tamabboh_CheckInRange:
	bsr.w	PP_ValidTarget
	bcc.w	.End
	move.w	obY(a1),d0
	sub.w	obY(a0),d0
	subi.w	#-$50,d0
	subi.w	#$A0,d0
	bcc.w	.End
	move.w	obX(a1),d0
	sub.w	obX(a0),d0
	move.w	d0,d1
	subi.w	#-$50,d1
	subi.w	#$A0,d1

.End:
	rts
; End of function PP_Tamabboh_CheckInRange

; -------------------------------------------------------------------------

PP_Tamabboh_Wait1:
	addq.b	#2,obRoutine(a0)
	move.b	#1,obAnim(a0)
; End of function PP_Tamabboh_Wait1

; -------------------------------------------------------------------------

PP_Tamabboh_Wait2:
	movea.l	objoff_36(a0),a1
	jmp	(AnimateSprite).l
; End of function PP_Tamabboh_Wait2

; -------------------------------------------------------------------------

PP_Tamabboh_Fire:
	move.b	#4,obRoutine(a0)
	move.b	#0,obAnim(a0)
	move.w	#$78,objoff_3A(a0)
	tst.w	obSubtype(a0)
	bne.w	.End
	jsr	(FindFreeObj).l
	bne.w	.End
	tst.b	obRender(a0)
	bpl.s	.SkipSound
	move.w	#sfx_Fireball,d0
	jsr	(PlaySound_Special).l

.SkipSound:
	bsr.s	PP_Tamabboh_InitMissile
	sf	objoff_45(a1)
	jsr	(FindFreeObj).l
	bne.w	.End
	bsr.s	PP_Tamabboh_InitMissile
	st	objoff_45(a1)

.End:
	rts
; End of function PP_Tamabboh_Fire

; -------------------------------------------------------------------------

PP_Tamabboh_InitMissile:
	move.l	#PP_TamabbohMissile,code(a1)
	move.w	#1,obSubtype(a1)
	move.w	obGfx(a0),obGfx(a1)
	move.w	obPriority(a0),obPriority(a1)
	addi.w	#$80,obPriority(a1)
	move.w	obX(a0),obX(a1)
	move.w	obY(a0),obY(a1)
	subi.w	#10,obY(a1)
	rts
; End of function PP_Tamabboh_InitMissile

; -------------------------------------------------------------------------
Ani_PP_Tamabboh1:
	dc.w	PP_Anim_20B946-Ani_PP_Tamabboh1
	dc.w	PP_Anim_20B94A-Ani_PP_Tamabboh1
PP_Anim_20B946:	dc.b	$1D, 0, 1,	$FF
PP_Anim_20B94A:	dc.b	$3B, 2, $FC, 0
	even
Ani_PP_Tamabboh2:
	dc.w	PP_Anim_20B952-Ani_PP_Tamabboh2
	dc.w	PP_Anim_20B964-Ani_PP_Tamabboh2
PP_Anim_20B952:	dc.b	5,	0, 1, 0, 1, 0, 1, 0, 1,	0, 1, 0, 1, 0, 1, 0, 1,	$FC
PP_Anim_20B964:	dc.b	$B, 2, $FC, 0
	even
Map_PP_Tamabboh1:
	binclude "mappings/sprite/PP Tamabboh Normal.bin"
	even
Map_PP_Tamabboh2:
	binclude "mappings/sprite/PP Tamabboh Damaged.bin"
	even
	even

; -------------------------------------------------------------------------

PP_TamabbohMissile:
	moveq	#0,d0
	move.b	obRoutine(a0),d0
	move.w	PP_TamabbohMissile_Index(pc,d0.w),d0
	jsr	PP_TamabbohMissile_Index(pc,d0.w)
	tst.l	code(a0)
	beq.w	.End
	jmp	(DisplaySprite).l
.End:
	rts
; End of function PP_TamabbohMissile

; -------------------------------------------------------------------------
PP_TamabbohMissile_Index:dc.w	PP_TamabbohMissile_Init-PP_TamabbohMissile_Index
	dc.w	PP_TamabbohMissile_Main-PP_TamabbohMissile_Index
; -------------------------------------------------------------------------

PP_TamabbohMissile_Init:
	addq.b	#2,obRoutine(a0)
	ori.b	#4,obRender(a0)
	move.b	#$98,obColType(a0)
	move.b	#8,obWidth(a0)
	move.b	#8,obActWid(a0)
	move.b	#8,obHeight(a0)
	move.l	#Map_PP_TamabbohMissile,obMap(a0)
	move.b	#Map_PP_TamabbohMissile_height,height_pixels(a0)
	tst.b	objoff_45(a0)
	bne.w	.FlipX
	move.l	#$20000,d0
	move.l	#-$40000,d1
	bra.w	.SetSpeeds

; -------------------------------------------------------------------------

.FlipX:
	move.l	#-$20000,d0
	move.l	#-$40000,d1

.SetSpeeds:
	move.l	d0,objoff_30(a0)
	move.l	d1,objoff_34(a0)
	rts
; End of function PP_TamabbohMissile_Init

; -------------------------------------------------------------------------

PP_TamabbohMissile_Main:
	tst.b	obRender(a0)
	bmi.s	.Action
	jmp	(DeleteObject).l

; -------------------------------------------------------------------------

.Action:
	jsr	(ObjHitFloor).l
	bpl.s	.MoveAnim
	jmp	(DeleteObject).l

; -------------------------------------------------------------------------

.MoveAnim:
	move.l	objoff_30(a0),d0
	add.l	d0,obX(a0)
	move.l	objoff_34(a0),d0
	add.l	d0,obY(a0)
	addi.l	#$2000,objoff_34(a0)	; fixed CD gravity; horizontal acceleration was always zero
	lea	Ani_PP_TamabbohMissile(pc),a1
	jmp	(AnimateSprite).l
; End of function PP_TamabbohMissile_Main

; -------------------------------------------------------------------------
Ani_PP_TamabbohMissile:
	dc.w	PP_Anim_20BA6A-Ani_PP_TamabbohMissile
PP_Anim_20BA6A:	dc.b	2,	0, 1, 2, 3, $FF
	even
Map_PP_TamabbohMissile:
	binclude "mappings/sprite/PP Tamabboh Missile.bin"
	even

; -------------------------------------------------------------------------
