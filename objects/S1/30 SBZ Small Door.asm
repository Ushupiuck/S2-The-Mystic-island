; ---------------------------------------------------------------------------
; Object 30 - small vertical door (SBZ)
; ---------------------------------------------------------------------------

Obj30:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	ADoor_Index(pc,d0.w),d1
		jmp	ADoor_Index(pc,d1.w)
; ===========================================================================
ADoor_Index:	dc.w ADoor_Main-ADoor_Index
		dc.w ADoor_OpenShut-ADoor_Index
; ===========================================================================

ADoor_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj30,obMap(a0)
		move.b	#Map_Obj30_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_SBZ_Door,2,0),obGfx(a0)
		cmpi.b #id_SMZ,(Current_Zone).w
		bne.s .doorAtlasReady
		move.l #Map_SMZ_Door,obMap(a0)
		move.b #Map_SMZ_Door_height,height_pixels(a0)
		move.w #ArtTile_SMZ_Atlas,obGfx(a0)
.doorAtlasReady:
		ori.b	#4,obRender(a0)
		move.b	#sprite_bound(8,Map_Obj30_width),obActWid(a0)
		move.w	#$200,obPriority(a0)

ADoor_OpenShut:	; Routine 2
		; S3&K's HCZ/CNZ/DEZ door checks both players and extends its
		; open range across the doorway until the crossing player clears it.
		move.w	obX(a0),d2
		move.w	d2,d3
		btst	#0,obStatus(a0)
		bne.s	.fromRight
		subi.w	#$40,d2		; retain the original approach distance
		tst.b	obAnim(a0)		; previous open request is the crossing latch
		beq.s	.rangeReady
		addi.w	#$18,d3		; keep an open door clear for either player
		bra.s	.rangeReady
.fromRight:
		addi.w	#$40,d3
		tst.b	obAnim(a0)
		beq.s	.rangeReady
		subi.w	#$18,d2
.rangeReady:
		clr.b	obAnim(a0)
		lea	(v_player).w,a1
		bsr.w	ADoor_CheckPlayer
		lea	(v_player2).w,a1
		bsr.w	ADoor_CheckPlayer

ADoor_Animate:
		lea	Ani_Obj30(pc),a1
		bsr.w	AnimateSprite
		tst.b	obFrame(a0)	; is the door open?
		bne.w	MarkObjGone	; if yes, branch
		move.w	#$11,d1
		move.w	#$20,d2
		move.w	d2,d3
		addq.w	#1,d3
		move.w	obX(a0),d4
		bsr.w	SolidObject
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
ADoor_CheckPlayer:
		tst.l	code(a1)
		beq.s	.return
		cmpi.b	#6,obRoutine(a1)
		bhs.s	.return
		tst.b	obControl(a1)		; ignore scripted/respawning players
		bmi.s	.return
		move.w	obX(a1),d0
		cmp.w	d2,d0
		blt.s	.return
		cmp.w	d3,d0
		bge.s	.return
		move.w	obY(a1),d0
		sub.w	obY(a0),d0
		addi.w	#$20,d0
		cmpi.w	#$40,d0		; player must be at the door's height
		bhs.s	.return
		move.b	#1,obAnim(a0)
.return:
		rts
; ---------------------------------------------------------------------------
Ani_Obj30:	dc.w byte_9590-Ani_Obj30
		dc.w byte_959C-Ani_Obj30
byte_9590:	dc.b   0,  8,  7,  6,  5,  4,  3,  2
		dc.b   1,  0,$FE,  1
byte_959C:	dc.b   0,  0,  1,  2,  3,  4,  5,  6
		dc.b   7,  8,$FE,  1
		even

