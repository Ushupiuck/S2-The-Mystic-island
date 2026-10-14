; Imported from sonicretro/scddisasm f8cf3f0. Normal/damaged subtype: 0/1.
; Six-byte mappings, full code pointers, resident palette-0 art; SST private
; state is relocated from CD $2A-$3F to $30-$45. Both live actors can trigger attacks.
; -------------------------------------------------------------------------
; Sonic CD Disassembly
; -------------------------------------------------------------------------
; Mosqui object
; -------------------------------------------------------------------------

PP_Mosqui:
	moveq	#0,d0
	move.b	obRoutine(a0),d0
	move.w	PP_Mosqui_Index(pc,d0.w),d0
	jsr	PP_Mosqui_Index(pc,d0.w)
	move.w	objoff_30(a0),d0
	jmp	(MarkObjGone3).l
; End of function PP_Mosqui

; -------------------------------------------------------------------------
PP_Mosqui_Index:dc.w	PP_Mosqui_Init-PP_Mosqui_Index
	dc.w	PP_Mosqui_Main-PP_Mosqui_Index
	dc.w	PP_Mosqui_Animate-PP_Mosqui_Index
	dc.w	PP_Mosqui_Dive-PP_Mosqui_Index
	dc.w	PP_Mosqui_Wait-PP_Mosqui_Index
; -------------------------------------------------------------------------

PP_Mosqui_Init:
	addq.b	#2,obRoutine(a0)
	ori.b	#4,obRender(a0)
	move.w	#$180,obPriority(a0)
	move.b	#$10,obWidth(a0)
	move.b	#$10,obActWid(a0)
	move.b	#$10,obHeight(a0)
	move.b	#$1A,obColType(a0)
	move.w	obX(a0),objoff_30(a0)
	move.w	#ArtTile_PP_Mosqui,obGfx(a0)
	tst.b	obSubtype(a0)
	bne.w	.Damaged
	lea	Map_PP_Mosqui1(pc),a1
	lea	Ani_PP_Mosqui1(pc),a2
	move.l	#-$10000,d0
	bra.w	.SetInfo

; -------------------------------------------------------------------------

.Damaged:
	lea	Map_PP_Mosqui2(pc),a1
	lea	Ani_PP_Mosqui2(pc),a2
	move.l	#-$8000,d0

.SetInfo:
	move.l	a1,obMap(a0)
	move.b	#Map_PP_Mosqui2_height,height_pixels(a0)
	move.l	a2,objoff_36(a0)
	move.l	d0,objoff_32(a0)
; End of function PP_Mosqui_Init

; -------------------------------------------------------------------------

PP_Mosqui_Main:
	tst.w	(Debug_placement_mode).w
	bne.w	.SkipRange
	lea	(v_player).w,a1
	bsr.w	PP_Mosqui_CheckInRange
	bcs.w	.StartDive
	lea	(v_player2).w,a1
	bsr.w	PP_Mosqui_CheckInRange
	bcs.w	.StartDive

.SkipRange:
	move.l	objoff_32(a0),d0
	add.l	d0,obX(a0)
	move.w	obX(a0),d0
	sub.w	objoff_30(a0),d0
	bpl.s	.ChkTurn
	neg.w	d0

.ChkTurn:
	cmpi.w	#$80,d0
	blt.w	.Animate
	neg.l	objoff_32(a0)
	bchg	#0,obRender(a0)
	bchg	#0,obStatus(a0)
	bra.w	.SkipRange

; -------------------------------------------------------------------------

.Animate:
	movea.l	objoff_36(a0),a1
	jmp	(AnimateSprite).l

; -------------------------------------------------------------------------

.StartDive:
	addq.b	#2,obRoutine(a0)
	move.b	#1,obAnim(a0)
	rts
; End of function PP_Mosqui_Main

; -------------------------------------------------------------------------

PP_Mosqui_CheckInRange:
	bsr.w	PP_ValidTarget
	bcc.w	.End
	move.w	obY(a1),d0
	sub.w	obY(a0),d0
	subi.w	#-$30,d0
	subi.w	#$70,d0
	bcc.w	.End
	move.w	obX(a1),d0
	sub.w	obX(a0),d0
	move.w	d0,d1
	subi.w	#-$30,d1
	subi.w	#$60,d1

.End:
	rts
; End of function PP_Mosqui_CheckInRange

; -------------------------------------------------------------------------

PP_Mosqui_Animate:
	movea.l	objoff_36(a0),a1
	jmp	(AnimateSprite).l
; End of function PP_Mosqui_Animate

; -------------------------------------------------------------------------

PP_Mosqui_Dive:
	addq.w	#6,obY(a0)
	jsr	(ObjHitFloor).l
	cmpi.w	#-8,d1
	bgt.s	.End
	subi.w	#-8,d1
	add.w	d1,obY(a0)
	addq.b	#2,obRoutine(a0)
	tst.b	obRender(a0)
	bpl.s	.End
	move.w	#sfx_Collapse,d0
	jsr	(PlaySound_Special).l

.End:
	rts
; End of function PP_Mosqui_Dive

; -------------------------------------------------------------------------

PP_Mosqui_Wait:
	tst.b	obRender(a0)
	bmi.s	.End
	jmp	(UnloadObject).l

; -------------------------------------------------------------------------

.End:
	rts
; End of function PP_Mosqui_Wait

; -------------------------------------------------------------------------
Ani_PP_Mosqui1:
	dc.w	PP_Anim_20B6CE-Ani_PP_Mosqui1
	dc.w	PP_Anim_20B6D2-Ani_PP_Mosqui1
PP_Anim_20B6CE:	dc.b	1,	0, 1, $FF
PP_Anim_20B6D2:	dc.b	6,	2, 3, 4, $FC, 0
	even
Ani_PP_Mosqui2:
	dc.w	PP_Anim_20B6DC-Ani_PP_Mosqui2
	dc.w	PP_Anim_20B6E0-Ani_PP_Mosqui2
PP_Anim_20B6DC:	dc.b	4,	0, 1, $FF
PP_Anim_20B6E0:	dc.b	$E, 2, 3, 4, $FC
	even
Map_PP_Mosqui1:
	binclude "mappings/sprite/PP Mosqui Normal.bin"
	even
Map_PP_Mosqui2:
	binclude "mappings/sprite/PP Mosqui Damaged.bin"
	even

; -------------------------------------------------------------------------
