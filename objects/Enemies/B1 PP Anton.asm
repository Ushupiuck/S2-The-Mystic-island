; Imported from sonicretro/scddisasm f8cf3f0. Normal/damaged subtype: 0/1.
; Six-byte mappings, full code pointers, resident palette-0 art; SST private
; state is relocated from CD $2A-$3F to $30-$45. Both live actors can trigger attacks.
; -------------------------------------------------------------------------
; Sonic CD Disassembly
; -------------------------------------------------------------------------
; Anton object
; -------------------------------------------------------------------------

PP_Anton:
	moveq	#0,d0
	move.b	obRoutine(a0),d0
	move.w	PP_Anton_Index(pc,d0.w),d0
	jsr	PP_Anton_Index(pc,d0.w)
	move.w	objoff_34(a0),d0
	jmp	(MarkObjGone3).l
; End of function PP_Anton

; -------------------------------------------------------------------------
PP_Anton_Index:	dc.w	PP_Anton_Init-PP_Anton_Index
	dc.w	PP_Anton_Place-PP_Anton_Index
	dc.w	PP_Anton_Main-PP_Anton_Index
; -------------------------------------------------------------------------

PP_Anton_Init:
	ori.b	#4,obRender(a0)
	move.w	#$200,obPriority(a0)
	move.l	#Map_PP_Anton,obMap(a0)
	move.b	#Map_PP_Anton_height,height_pixels(a0)
	move.b	#$18,obWidth(a0)
	move.b	#sprite_bound($18,Map_PP_Anton_width),obActWid(a0)
	move.b	#$13,obHeight(a0)
	move.b	#$12,obColType(a0)
	move.w	obX(a0),objoff_34(a0)
	move.w	#ArtTile_PP_Anton,obGfx(a0)
	tst.b	obSubtype(a0)
	bne.w	.Damaged
	move.l	#-$10000,d0
	moveq	#0,d1
	bra.w	.SetInfo

; -------------------------------------------------------------------------

.Damaged:
	move.l	#-$8000,d0
	moveq	#1,d1

.SetInfo:
	move.l	d0,objoff_30(a0)
	move.b	d1,obAnim(a0)
; End of function PP_Anton_Init

; -------------------------------------------------------------------------

PP_Anton_Place:
	move.l	#$10000,d0
	add.l	d0,obY(a0)
	jsr	(ObjHitFloor).l
	tst.w	d1
	bpl.s	.End
	add.w	d1,obY(a0)
	addq.b	#2,obRoutine(a0)

.End:
	rts
; End of function PP_Anton_Place

; -------------------------------------------------------------------------

PP_Anton_Main:
	move.l	objoff_30(a0),d0
	add.l	d0,obX(a0)
	move.w	obX(a0),d0
	sub.w	objoff_34(a0),d0
	bpl.s	.AbsDX
	neg.w	d0

.AbsDX:
	cmpi.w	#$80,d0
	bge.w	.TurnAround
	jsr	(ObjHitFloor).l
	cmpi.w	#-7,d1
	blt.w	.TurnAround
	cmpi.w	#7,d1
	bgt.s	.TurnAround
	add.w	d1,obY(a0)
	lea	Ani_PP_Anton(pc),a1
	jmp	(AnimateSprite).l

; -------------------------------------------------------------------------

.TurnAround:
	move.l	objoff_30(a0),d0
	sub.l	d0,obX(a0)
	neg.l	objoff_30(a0)
	bchg	#0,obRender(a0)
	bchg	#0,obStatus(a0)
	lea	Ani_PP_Anton(pc),a1
	jmp	(AnimateSprite).l
; End of function PP_Anton_Main

; -------------------------------------------------------------------------
Ani_PP_Anton:
	dc.w	PP_Anim_20B3A2-Ani_PP_Anton
	dc.w	PP_Anim_20B3A6-Ani_PP_Anton
PP_Anim_20B3A2:	dc.b	3,	0, 1, $FF
PP_Anim_20B3A6:	dc.b	7,	2, 3, $FF
	even
Map_PP_Anton:
	binclude "mappings/sprite/PP Anton.bin"
	even

; -------------------------------------------------------------------------
