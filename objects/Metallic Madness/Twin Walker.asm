; ===========================================================================
; Twin Walker. Either foot can carry both players on top. The seven chain
; links are a single visual composite between two real platform SSTs.
; ===========================================================================

twin_mate = platgroup_members
twin_links = platgroup_members+2
twin_steps = platgroup_timer
twin_pivot = platgroup_sequence
twin_angle = platgroup_phase
twin_previous_x = objoff_38
twin_radius = 64
twin_stride = $200
twin_foot_width = 24
twin_foot_height = 41

MMZ_TwinWalker:
		moveq	#2,d6
		jsr	(PlatformGroup_Preflight).l
		bne.w	.return
		move.l	#MMZ_TwinWalker_Run,code(a0)
		move.b	#2,obRoutine(a0)
		move.b	#12,twin_steps(a0)
		move.w	#$8000,twin_angle(a0)
		movea.l	a0,a1
		bsr.s	.init_foot
		jsr	(PlatformGroup_Allocate).l
		move.l	#MMZ_TwinWalker_Part,code(a1)
		bsr.s	.init_foot
		move.l	obX(a0),obX(a1)
		addi.w	#twin_radius,obX(a1)
		move.l	obY(a0),obY(a1)
		jsr	(PlatformGroup_Allocate).l
		move.l	#MMZ_TwinWalker_Part,code(a1)
		move.l	obMap(a0),obMap(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.w	#$280,obPriority(a1)
		move.b	#$44,obRender(a1)
		move.b	#twin_radius,mainspr_width(a1)
		move.b	#twin_radius,mainspr_height(a1)
		move.b	#1,mainspr_mapframe(a1)
		move.b	#6,mainspr_childsprites(a1)
		movea.l	a1,a5
		movea.l	a0,a2
		movea.w	twin_mate(a0),a4
		bsr.w	MMZ_TwinWalker_PositionLinks
		bra.s	MMZ_TwinWalker_Run
.return:	rts
.init_foot:
		move.l	#Map_MMZ_TwinWalker,obMap(a1)
		move.w	#ArtTile_MMZ2_TwinWalker,obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.b	#4,obRender(a1)
		move.b	#twin_foot_width,width_pixels(a1)
		move.b	#twin_foot_height,height_pixels(a1)
		move.b	#twin_foot_height,obHeight(a1)
		rts

MMZ_TwinWalker_Run:
		out_of_range.w	.unload_check
.step_visible:
		movea.w	twin_mate(a0),a1
		bsr.w	MMZ_TwinWalker_OwnsPart
		bne.w	MMZ_TwinWalker_Unload
		movea.l	a1,a4
		movea.w	twin_links(a0),a1
		bsr.w	MMZ_TwinWalker_OwnsPart
		bne.w	MMZ_TwinWalker_Unload
		movea.l	a1,a5
		move.w	obX(a0),twin_previous_x(a0)
		move.w	obX(a4),twin_previous_x(a4)
		clr.w	obVelX(a0)
		clr.w	obVelX(a4)
		movea.l	a0,a2
		tst.b	twin_pivot(a0)
		beq.s	.step
		exg	a2,a4
.step:
		cmpi.b	#4,obRoutine(a0)
		beq.s	.swing
		move.b	obStatus(a2),d0
		andi.b	#$18,d0
		beq.s	.draw
		tst.b	twin_steps(a0)
		beq.s	.draw
		subq.b	#1,twin_steps(a0)
		move.b	#4,obRoutine(a0)
.swing:
		bsr.w	MMZ_TwinWalker_Arc
		bsr.w	MMZ_TwinWalker_PositionLinks
.draw:
		tst.b	(TwinWalker_ArtFrame).w
		beq.s	.links
		bsr.w	MMZ_TwinWalker_ArtInView
		bcc.s	.contacts
		bsr.w	MMZ_TwinWalker_LoadArt
		bcs.s	.contacts
.links:
		exg	a0,a5
		jsr	(DisplaySprite).l
		exg	a0,a5
.contacts:
		; The object loop advances a0 itself. Return on the root even when
		; either helper occupies a lower slot.
		move.l	a0,-(sp)
		bsr.w	MMZ_TwinWalker_Foot
		movea.l	(sp),a0
		movea.w	twin_mate(a0),a0
		bsr.w	MMZ_TwinWalker_Foot
		movea.l	(sp)+,a0
		rts
.unload_check:
		jsr	(Object_CheckSpawnXRange).l
		bhi.w	MMZ_TwinWalker_Unload
		bra.w	MMZ_TwinWalker_Run.step_visible

; a2 swings from a4. Its floor probe can land only on the descending half.
MMZ_TwinWalker_Arc:
		addi.w	#twin_stride,twin_angle(a0)
		moveq	#0,d0
		move.b	twin_angle(a0),d0
		jsr	(CalcSine).l
		asl.w	#6,d0
		asl.w	#6,d1
		ext.l	d0
		ext.l	d1
		asl.l	#8,d0
		asl.l	#8,d1
		add.l	obX(a4),d1
		add.l	obY(a4),d0
		move.l	d1,d2
		sub.l	obX(a2),d2
		asr.l	#8,d2
		move.w	d2,obVelX(a2)
		move.l	d1,obX(a2)
		move.l	d0,obY(a2)
		move.w	twin_angle(a0),d0
		addi.w	#$4000,d0
		bmi.s	.return
		move.l	a0,-(sp)
		movea.l	a2,a0
		jsr	(ObjHitFloor).l
		movea.l	(sp)+,a0
		tst.w	d1
		bpl.s	.return
		addq.w	#2,d1
		add.w	d1,obY(a2)
		eori.w	#$8000,twin_angle(a0)
		eori.b	#1,twin_pivot(a0)
		move.b	#2,obRoutine(a0)
.return:	rts

; a5 owns the six child sprites plus the main link. All seven are spaced
; from the live ends, including the frame when the moving foot lands.
MMZ_TwinWalker_PositionLinks:
		move.l	obX(a2),d1
		sub.l	obX(a4),d1
		asr.l	#3,d1
		move.l	obY(a2),d0
		sub.l	obY(a4),d0
		asr.l	#3,d0
		move.l	obX(a4),d3
		move.l	obY(a4),d2
		lea	subspr_data(a5),a3
		moveq	#5,d6
.next:
		add.l	d1,d3
		add.l	d0,d2
		move.l	d3,d4
		move.l	d2,d5
		swap	d4
		swap	d5
		move.w	d4,(a3)+
		move.w	d5,(a3)+
		move.w	#1,(a3)+
		dbf	d6,.next
		add.l	d1,d3
		add.l	d0,d2
		swap	d3
		swap	d2
		move.w	d3,obX(a5)
		move.w	d2,obY(a5)
		rts

MMZ_TwinWalker_Foot:
		moveq	#twin_foot_width,d1
		moveq	#twin_foot_height,d2
		move.w	d2,d3
		move.w	twin_previous_x(a0),d4
		jsr	(PlatformObject).l
		tst.b	(TwinWalker_ArtFrame).w
		bne.s	.return
		jmp	(DisplaySprite).l
.return:	rts

; Carry means some part can be visible from the root's position.
MMZ_TwinWalker_ArtInView:
		move.w	obX(a0),d0
		sub.w	(Camera_X_pos).w,d0
		addi.w	#twin_radius+twin_foot_width,d0
		cmpi.w	#320+2*(twin_radius+twin_foot_width),d0
		bhs.s	.return
		move.w	obY(a0),d0
		sub.w	(Camera_Y_pos).w,d0
		addi.w	#twin_radius+twin_foot_height,d0
		tst.w	(Camera_Min_Y_pos).w
		bpl.s	.height
		andi.w	#Level_YWrapMask,d0
.height:
		cmpi.w	#224+2*(twin_radius+twin_foot_height),d0
.return:	rts

; The two feet and all seven links use the same pixels through the entire
; walk. Decode one Kosinski+ module on demand and share its complete cue.
; A full DMA queue leaves the decoded source ready for the next attempt.
MMZ_TwinWalker_LoadArt:
		tst.b	(TwinWalker_ArtFrame).w
		beq.s	.return
		cmpi.b	#-1,(TwinWalker_ArtFrame).w
		bne.s	.decoded
		move.l	a0,-(sp)
		lea	(Kospm_MMZ_TwinWalker+2).l,a0
		lea	(Art_TwinWalker).l,a1
		jsr	(KosPlusDec).l
		movea.l	(sp)+,a0
		move.b	#-2,(TwinWalker_ArtFrame).w
.decoded:
		moveq	#0,d0
		lea	DPLC_MMZ_TwinWalker(pc),a2
		lea	(TwinWalker_ArtFrame).w,a3
		move.w	#ArtTile_MMZ2_TwinWalker*tile_size,d4
		move.l	#Art_TwinWalker,d6
		jmp	(Load_DynamicPLC).l
.return:	rts

DPLC_MMZ_TwinWalker:
		dc.w	.all-DPLC_MMZ_TwinWalker
.all:		dc.w	2,$F000,((TwinWalker_ArtTiles-17)<<12)|16
		if (TwinWalker_ArtTiles<17)||(TwinWalker_ArtTiles>32)
			fatal	"Twin Walker cue assumes two tile runs"
		endif

; The allocator records reciprocal links. Never act on a recycled part.
MMZ_TwinWalker_OwnsPart:
		cmpi.l	#MMZ_TwinWalker_Part,code(a1)
		bne.s	.return
		move.w	a0,d0
		cmp.w	platgroup_owner(a1),d0
.return:	rts

MMZ_TwinWalker_Part:
		movea.w	platgroup_owner(a0),a1
		cmpi.l	#MMZ_TwinWalker_Run,code(a1)
		bne.s	.orphan
		move.w	platgroup_link(a0),d0
		move.w	a0,d1
		cmp.w	(a1,d0.w),d1
		bne.s	.orphan
		rts
.orphan:
		btst	#render_flags.multi_sprite,obRender(a0)
		bne.s	.delete
		jsr	(ReleaseObjectRiders).l
.delete:	jmp	(DeleteObject).l

MMZ_TwinWalker_Unload:
		movea.w	twin_links(a0),a1
		bsr.s	MMZ_TwinWalker_OwnsPart
		bne.s	.foot
		jsr	(DeleteObject2).l
.foot:
		movea.w	twin_mate(a0),a1
		bsr.s	MMZ_TwinWalker_OwnsPart
		bne.s	.root
		move.l	a0,-(sp)
		movea.l	a1,a0
		jsr	(ReleaseObjectRiders).l
		jsr	(DeleteObject).l
		movea.l	(sp)+,a0
.root:
		jsr	(ReleaseObjectRiders).l
		jmp	(UnloadObject).l

Map_MMZ_TwinWalker:	binclude "mappings/sprite/MMZ TwinWalker.bin"
		even
