; Imported from sonicretro/scddisasm f8cf3f0. Normal/damaged subtype: 0/1.
; Six-byte mappings, full code pointers, resident palette-0 art; SST private
; state is relocated from CD $2A-$3F to $30-$45. Both live actors can trigger attacks.
; -------------------------------------------------------------------------
; Sonic CD Disassembly
; -------------------------------------------------------------------------
; Taga-Taga object
; -------------------------------------------------------------------------

PP_TagaTaga:
	moveq	#0,d0
	move.b	obRoutine(a0),d0
	move.w	PP_TagaTaga_Index(pc,d0.w),d0
	jsr	PP_TagaTaga_Index(pc,d0.w)
	move.w	objoff_30(a0),d0
	jmp	(MarkObjGone3).l
; End of function PP_TagaTaga

; -------------------------------------------------------------------------
PP_TagaTaga_Index:dc.w	PP_TagaTaga_Init-PP_TagaTaga_Index
	dc.w	PP_TagaTaga_Init2-PP_TagaTaga_Index
	dc.w	PP_TagaTaga_Animate-PP_TagaTaga_Index
	dc.w	PP_TagaTaga_Jump-PP_TagaTaga_Index
	dc.w	PP_TagaTaga_Main-PP_TagaTaga_Index
; -------------------------------------------------------------------------

PP_TagaTaga_Init:
	addq.b	#2,obRoutine(a0)
	ori.b	#4,obRender(a0)
	move.w	#$180,obPriority(a0)
	move.b	#$10,obWidth(a0)
	move.b	#$10,obActWid(a0)
	move.b	#$16,obHeight(a0)
	move.w	obX(a0),objoff_30(a0)
	move.w	obY(a0),objoff_32(a0)
	move.w	#ArtTile_PP_TagaTaga,obGfx(a0)
	tst.w	obSubtype(a0)
	bne.w	.Damaged
	lea	Map_PP_TagaTaga1(pc),a1
	lea	Ani_PP_TagaTaga1(pc),a2
	move.l	#-$3C000,d0
	move.l	#$1000,d1
	bra.w	.SetInfo

; -------------------------------------------------------------------------

.Damaged:
	lea	Map_PP_TagaTaga2(pc),a1
	lea	Ani_PP_TagaTaga2(pc),a2
	move.l	#-$30000,d0
	move.l	#$1000,d1

.SetInfo:
	move.l	a1,obMap(a0)
	move.b	#Map_PP_TagaTaga2_height,height_pixels(a0)
	move.l	a2,objoff_42(a0)
	move.l	d0,objoff_36(a0)
	move.l	d1,objoff_3E(a0)
; End of function PP_TagaTaga_Init

; -------------------------------------------------------------------------

PP_TagaTaga_Init2:
	addq.b	#2,obRoutine(a0)
	move.w	#$FF,obAnim(a0)
	move.b	#0,obColType(a0)
	move.l	objoff_32(a0),obY(a0)
; End of function PP_TagaTaga_Init2

; -------------------------------------------------------------------------

PP_TagaTaga_Animate:
	movea.l	objoff_42(a0),a1
	jmp	(AnimateSprite).l
; End of function PP_TagaTaga_Animate

; -------------------------------------------------------------------------

PP_TagaTaga_Jump:
	addq.b	#2,obRoutine(a0)
	move.w	#$1FF,obAnim(a0)
	move.b	#6,obColType(a0)
	move.l	objoff_32(a0),obY(a0)
	move.l	objoff_36(a0),objoff_3A(a0)
	tst.b	obRender(a0)
	bpl.s	PP_TagaTaga_Main
	move.w	#sfx_Spring,d0
	jsr	(PlaySound_Special).l
; End of function PP_TagaTaga_Jump

; -------------------------------------------------------------------------

PP_TagaTaga_Main:
	move.l	objoff_3A(a0),d0
	add.l	d0,obY(a0)
	move.l	objoff_3E(a0),d0
	add.l	d0,objoff_3A(a0)
	move.w	obY(a0),d0
	cmp.w	objoff_32(a0),d0
	ble.s	PP_TagaTaga_DoAnim
	move.b	#2,obRoutine(a0)
	tst.b	obRender(a0)
	bpl.s	PP_TagaTaga_DoAnim
	move.w	#sfx_Spring,d0
	jsr	(PlaySound_Special).l

PP_TagaTaga_DoAnim:
	movea.l	objoff_42(a0),a1
	jmp	(AnimateSprite).l
; End of function PP_TagaTaga_Main

; -------------------------------------------------------------------------
Ani_PP_TagaTaga1:
	dc.w	PP_Anim_20BBC8-Ani_PP_TagaTaga1
	dc.w	PP_Anim_20BBCB-Ani_PP_TagaTaga1
PP_Anim_20BBC8:	dc.b	$59, 6, $FC
PP_Anim_20BBCB:	dc.b	7,	0, 0, 0, 1, 0, 1, 2, 3,	5, 5, 5, 5, 4, 5, 4, 5,	4, 5, $FF
	dc.b	0
	even
Ani_PP_TagaTaga2:
	dc.w	PP_Anim_20BBE4-Ani_PP_TagaTaga2
	dc.w	PP_Anim_20BBE7-Ani_PP_TagaTaga2
PP_Anim_20BBE4:	dc.b	$59, 6, $FC
PP_Anim_20BBE7:	dc.b	4,	0, 0, 0, 0, 0, 0, 0, 0,	2, 2, 3, 3, 4, 4, 4, 4,	4, 4, 4, 4, 4, 4, 4, $FF
	even
Map_PP_TagaTaga1:
	binclude "mappings/sprite/PP Taga-Taga Normal.bin"
	even
Map_PP_TagaTaga2:
	binclude "mappings/sprite/PP Taga-Taga Damaged.bin"
	even
	even

; -------------------------------------------------------------------------
