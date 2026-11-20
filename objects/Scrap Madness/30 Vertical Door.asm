; ===========================================================================
; $30 vertical door, shared by Scrap Madness and Metallic Madness.
; The placement is the center of the closed doorway. Both panels stay solid
; as they move, and either player can hold the doorway open.
; ===========================================================================

Door_MetalBit		equ 7
Door_PanelHalfHeight	equ 16
Door_PanelTravel	equ 33
Door_PanelSpeed		equ 2

door_center_y:	equ objoff_2E
door_range:	equ objoff_30	; closed/open horizontal windows, relative to X
door_travel:	equ objoff_34	; current panel displacement
door_opening:	equ objoff_36	; finish opening once a player triggers it
door_blink:	equ objoff_37	; only the metal mapping has lamp frames
door_partner:	equ objoff_3C	; lower panel/root only
door_parent:	equ objoff_3E	; upper panel only

Obj30:
		tst.w	door_partner(a0)
		bne.w	ADoor_Update
		out_of_range.w	UnloadObject
		jsr	(FindFreeObj).l
		bne.w	.return			; retry without leaving a partial pair

		move.w	a1,door_partner(a0)
		move.w	a0,door_parent(a1)
		move.l	#ADoor_Upper,code(a1)
		move.w	obY(a0),door_center_y(a0)

		move.b	obStatus(a0),d2
		move.w	obSubtype(a0),d0
		btst	#Door_MetalBit,d0
		bne.s	.metal
		move.l	#Map_Obj30,obMap(a0)
		move.w	#make_art_tile(ArtTile_SBZ_Door,2,0),obGfx(a0)
		cmpi.b	#id_SMZ,(Current_Zone).w
		bne.s	.configure
		move.l	#Map_SMZ_Door,obMap(a0)
		move.w	#ArtTile_SMZ_Atlas,obGfx(a0)
		bra.s	.configure
.metal:
		andi.w	#3,d0
		cmpi.w	#3,d0
		bne.s	.variant
		moveq	#0,d0
.variant:
		cmpi.w	#1,d0			; right-facing sensor
		bne.s	.mapping
		eori.b	#1,d2
.mapping:
		lsl.w	#2,d0
		move.l	ADoor_PanelMaps(pc,d0.w),obMap(a0)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		st	door_blink(a0)

.configure:
		lea	ADoor_Left(pc),a2
		btst	#0,d2
		beq.s	.sideReady
		lea	ADoor_Right(pc),a2
.sideReady:
		move.l	a2,door_range(a0)
		move.l	obMap(a0),obMap(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.w	#$200,obPriority(a0)
		move.w	obPriority(a0),obPriority(a1)
		move.w	#Door_PanelHalfHeight<<8|Map_MMZ_Door2_width,height_pixels(a0)
		move.w	height_pixels(a0),height_pixels(a1)
		ori.b	#4,obRender(a0)
		move.b	obRender(a0),obRender(a1)
		move.w	obX(a0),obX(a1)
		bra.s	ADoor_Update
.return:
		rts

ADoor_PanelMaps:
		dc.l Map_MMZ_Door1,Map_MMZ_Door2,Map_MMZ_Door3

; Closed approach window, followed by the wider hold-open window.
ADoor_Left:
		dc.w -72,-8,-72,40
ADoor_Right:
		dc.w 8,72,-40,72

ADoor_Update:
		movea.w	door_partner(a0),a2
		cmpi.l	#ADoor_Upper,code(a2)
		bne.w	UnloadObject
		move.w	a0,d0
		cmp.w	door_parent(a2),d0
		bne.w	UnloadObject
		out_of_range.w	ADoor_UnloadPair

		movea.l	door_range(a0),a2
		tst.w	door_travel(a0)
		beq.s	.closed
		addq.l	#4,a2
.closed:
		movem.w	(a2),d2-d3
		add.w	obX(a0),d2
		add.w	obX(a0),d3
		move.w	door_center_y(a0),d4
		subi.w	#$30,d4
		moveq	#$60,d5
		moveq	#0,d6
		lea	(v_player).w,a1
		bsr.s	ADoor_CheckPlayer
		lea	(v_player2).w,a1
		bsr.s	ADoor_CheckPlayer
		bra.s	ADoor_MovePanels

; d2/d3: horizontal bounds. d4/d5: top Y and height.
ADoor_CheckPlayer:
		tst.l	code(a1)
		beq.s	.return
		cmpi.b	#6,obRoutine(a1)
		bhs.s	.return
		tst.b	obControl(a1)
		bmi.s	.return
		move.w	obX(a1),d0
		cmp.w	d2,d0
		blt.s	.return
		cmp.w	d3,d0
		bge.s	.return
		move.w	obY(a1),d0
		sub.w	d4,d0
		cmp.w	d5,d0
		bhs.s	.return
		moveq	#1,d6
.return:
		rts

ADoor_Solid:
		moveq	#$11,d1
		move.w	d2,d3
		addq.w	#1,d3
		move.w	obX(a0),d4
		bra.w	SolidObject

ADoor_MovePanels:
		tst.b	d6
		beq.s	.target
		st	door_opening(a0)
.target:
		move.w	door_travel(a0),d0
		tst.b	door_opening(a0)
		beq.s	.close
		addq.w	#Door_PanelSpeed,d0
		cmpi.w	#Door_PanelTravel,d0
		blo.s	.place
		moveq	#Door_PanelTravel,d0
		clr.b	door_opening(a0)
		bra.s	.place
.close:
		subq.w	#Door_PanelSpeed,d0
		bcc.s	.place
		moveq	#0,d0
.place:
		move.w	d0,door_travel(a0)
		addi.w	#Door_PanelHalfHeight,d0
		move.w	door_center_y(a0),d1
		move.w	d1,d2
		add.w	d0,d1
		sub.w	d0,d2
		move.w	d1,obY(a0)
		movea.w	door_partner(a0),a2
		move.w	d2,obY(a2)

		move.w	a0,-(sp)
		movea.l	a2,a0
		moveq	#Door_PanelHalfHeight,d2
		bsr.w	ADoor_Solid
		movea.w	(sp)+,a0
		moveq	#Door_PanelHalfHeight,d2
		bsr.w	ADoor_Solid
		tst.b	door_blink(a0)
		beq.s	.draw
		lea	Ani_MMZDoor(pc),a1
		bsr.w	AnimateSprite
.draw:
		movea.w	door_partner(a0),a1
		move.b	obFrame(a0),obFrame(a1)
		jsr	(DisplaySprite2).l
		bra.w	DisplaySprite

ADoor_UnloadPair:
		movea.w	door_partner(a0),a1
		jsr	(DeleteObject2).l
		bra.w	UnloadObject

; The root positions and draws both panels together regardless of slot order.
ADoor_Upper:
		movea.w	door_parent(a0),a1
		cmpi.l	#Obj30,code(a1)
		bne.w	DeleteObject
		move.w	a0,d0
		cmp.w	door_partner(a1),d0
		bne.w	DeleteObject
		rts

Ani_MMZDoor:
		dc.w .flash-Ani_MMZDoor
.flash:
		dc.b 2,0,1,$FF
		even

Map_MMZ_Door1:	binclude "mappings/sprite/MMZ Door 1.bin"
		even
Map_MMZ_Door2:	binclude "mappings/sprite/MMZ Door 2.bin"
		even
Map_MMZ_Door3:	binclude "mappings/sprite/MMZ Door 3.bin"
		even
