; Imported from sonicretro/scddisasm f8cf3f0. Normal/damaged subtype: 0/1.
; Six-byte mappings, full code pointers, resident palette-0 art; SST private
; state is relocated from CD $2A-$3F to $30-$45. Both live actors can trigger attacks.
; -------------------------------------------------------------------------
; Sonic CD Disassembly
; -------------------------------------------------------------------------
; Pata-Bata object
; -------------------------------------------------------------------------

PP_PataBata:
	tst.b	obRoutine(a0)
	bne.w	PP_PataBata_Main
	addq.b	#2,obRoutine(a0)
	ori.b	#4,obRender(a0)
	move.w	#$180,obPriority(a0)
	move.b	#6,obColType(a0)
	move.b	#$10,obWidth(a0)
	move.b	#$10,obActWid(a0)
	move.b	#$10,obHeight(a0)
	move.w	obX(a0),objoff_30(a0)
	move.w	obY(a0),objoff_32(a0)
	move.w	#$8000,objoff_34(a0)
	move.w	#ArtTile_PP_PataBata,obGfx(a0)
	tst.w	obSubtype(a0)
	bne.w	.Damaged
	move.l	#-$8000,d0
	move.w	#-$200,d1
	moveq	#3,d2
	moveq	#0,d3
	lea	Map_PP_PataBata1(pc),a1
	bra.w	.SetInfo

; -------------------------------------------------------------------------

.Damaged:
	move.l	#-$4000,d0
	move.w	#-$100,d1
	moveq	#4,d2
	moveq	#1,d3
	lea	Map_PP_PataBata2(pc),a1

.SetInfo:
	move.l	d0,objoff_36(a0)
	move.w	d1,objoff_3C(a0)
	move.w	d2,objoff_3E(a0)
	move.b	d3,obAnim(a0)
	move.l	a1,obMap(a0)
	move.b	#Map_PP_PataBata2_height,height_pixels(a0)

PP_PataBata_Main:
	move.l	objoff_36(a0),d0
	add.l	d0,obX(a0)
	move.w	obX(a0),d0
	sub.w	objoff_30(a0),d0
	bpl.s	.AbsDX
	neg.w	d0

.AbsDX:
	cmpi.w	#$80,d0
	blt.w	.NoFlip
	neg.l	objoff_36(a0)
	move.l	objoff_36(a0),d0
	add.l	d0,obX(a0)
	bchg	#0,obRender(a0)
	bchg	#0,obStatus(a0)
	clr.w	objoff_3A(a0)

.NoFlip:
	move.w	objoff_3C(a0),d0
	add.w	d0,objoff_3A(a0)
	move.b	objoff_3A(a0),d0
	jsr	(CalcSine).l
	swap	d0
	move.w	objoff_3E(a0),d1
	asr.l	d1,d0
	add.l	objoff_32(a0),d0
	move.l	d0,obY(a0)
	lea	Ani_PP_PataBata(pc),a1
	jsr	(AnimateSprite).l
	move.w	objoff_30(a0),d0
	jmp	(MarkObjGone3).l
; End of function PP_PataBata

; -------------------------------------------------------------------------
Ani_PP_PataBata:
	dc.w	PP_Anim_20B520-Ani_PP_PataBata
	dc.w	PP_Anim_20B527-Ani_PP_PataBata
PP_Anim_20B520:	dc.b	7,	0, 0, 1, 2, 1, $FF
PP_Anim_20B527:	dc.b	3,	0, 0, 1, 2, 1, $FF
	even
Map_PP_PataBata1:
	binclude "mappings/sprite/PP Pata-Bata Normal.bin"
	even
Map_PP_PataBata2:
	binclude "mappings/sprite/PP Pata-Bata Damaged.bin"
	even

; -------------------------------------------------------------------------
