; MD CPU. Three independently descending panels, two harmful undersides.
; Later waves use the same controller and contact profiles.

spikecrusher_depth = platgroup_script
spikecrusher_panel = platgroup_script
spikecrusher_landed = objoff_3A
spikecrusher_blades = objoff_3B
spikecrusher_wave = objoff_48
spikecrusher_next = objoff_49

MMZ_SpikeCrusher:
		moveq	#4,d6
		jsr	(PlatformGroup_Preflight).l
		bne.w	.return
		moveq	#0,d0
		move.b	obSubtype+1(a0),d0
		cmpi.w	#4,d0
		bls.s	.wave
		moveq	#0,d0
.wave:
		move.b	d0,spikecrusher_wave(a0)
		move.w	d0,d2
		lsl.w	#3,d2
		; d2 = wave times 8; tripling it gives the extra probe depth.
		move.w	d2,d1
		add.w	d2,d2
		add.w	d1,d2
		moveq	#0,d1
		move.b	.wave_groups(pc,d0.w),d1
		lea	.groups(pc,d1.w),a2
		movea.l	a0,a1
		bsr.w	.panel
		jsr	(PlatformGroup_Allocate).l
		bsr.w	.panel
		move.l	#MMZ_SpikeCrusher_Center,platgroup_state(a1)
		jsr	(PlatformGroup_Allocate).l
		bsr.w	.panel
		move.l	#MMZ_SpikeCrusher_End,platgroup_state(a1)
		move.w	a1,d5
		jsr	(PlatformGroup_Allocate).l
		movea.l	a0,a2
		bsr.w	.underside
		jsr	(PlatformGroup_Allocate).l
		movea.w	d5,a2
		bsr.w	.underside
		move.b	#1,spikecrusher_next(a0)
		move.w	#300,platgroup_timer(a0)
		jmp	(PlatformGroup_Run).l
.return:	rts

.wave_groups:	dc.b	0,12,24,12,0,0

; [frame, X displacement, panel half-width, touch type], left to right.
.groups:
		dc.b	1,-52,28,$9C, 3,  0,24,0, 2,52,28,$9C
		dc.b	4,-68,12,$9B, 3,-32,24,0, 5,36,44,$9D
		dc.b	5,-36,44,$9D, 3, 32,24,0, 4,68,12,$9B

.panel:
		lea	MMZ_SpikeCrusher_Controller(pc),a4
		lea	.panel_profile(pc),a5
		jsr	(PlatformGroup_InitMember).l
		move.b	(a2)+,obFrame(a1)
		moveq	#0,d0
		move.b	(a2)+,d0
		ext.w	d0
		add.w	platgroup_x(a0),d0
		move.w	d0,obX(a1)
		move.w	platgroup_y(a0),obY(a1)
		move.b	(a2)+,width_pixels(a1)
		move.b	(a2)+,spikecrusher_blades(a1)
		move.w	d2,spikecrusher_depth(a1)
		rts
.panel_profile:
		dc.l	Map_MMZ_SpikeCrusher
		dc.w	ArtTile_MMZ_Atlas,$180
		dc.b	8,0,8,0

.underside:
		move.l	#MMZ_SpikeCrusher_Touch,code(a1)
		move.w	a2,spikecrusher_panel(a1)
		move.w	obX(a2),obX(a1)
		move.w	obY(a2),d0
		addi.w	#12,d0
		move.w	d0,obY(a1)
		move.b	spikecrusher_blades(a2),obColType(a1)
		move.b	#$84,obRender(a1)
		rts

MMZ_SpikeCrusher_Controller:
		tst.b	obRoutine(a0)
		bne.s	.active
		moveq	#48,d1
		tst.b	spikecrusher_wave(a0)
		beq.s	.trigger
		moveq	#80,d1
.trigger:
		move.w	#256,d2
		bsr.w	MMZ_SpikeCrusher_CheckPlayers
		bcc.w	MMZ_SpikeCrusher_Solid
		move.b	#2,obRoutine(a0)
.active:
		tst.b	spikecrusher_wave(a0)
		bne.s	.drop
		cmpi.b	#5,spikecrusher_next(a0)
		bhs.s	.drop
		moveq	#80,d1
		moveq	#-128,d2
		bsr.w	MMZ_SpikeCrusher_CheckPlayers
		bcc.s	.drop
		tst.w	platgroup_timer(a0)
		beq.s	.spawn
		subq.w	#1,platgroup_timer(a0)
		bne.s	.drop
.spawn:
		jsr	(FindFreeObj).l
		bne.s	.drop
		move.l	#MMZ_SpikeCrusher,code(a1)
		move.w	platgroup_x(a0),obX(a1)
		moveq	#0,d0
		move.b	spikecrusher_next(a0),d0
		move.w	d0,obSubtype(a1)
		lsl.w	#4,d0
		neg.w	d0
		add.w	platgroup_y(a0),d0
		move.w	d0,obY(a1)
		addq.b	#1,spikecrusher_next(a0)
		move.w	#240,platgroup_timer(a0)
		cmpi.b	#2,spikecrusher_next(a0)
		bne.s	.drop
		move.w	#300,platgroup_timer(a0)
.drop:
		bsr.s	MMZ_SpikeCrusher_MovePanel
		bra.s	MMZ_SpikeCrusher_Solid

MMZ_SpikeCrusher_End:
		bsr.s	MMZ_SpikeCrusher_Center
		bra.s	MMZ_SpikeCrusher_Solid

MMZ_SpikeCrusher_Center:
		movea.w	platgroup_owner(a0),a1
		tst.b	obRoutine(a1)
		bne.s	MMZ_SpikeCrusher_MovePanel
		rts

MMZ_SpikeCrusher_MovePanel:
		tst.b	spikecrusher_landed(a0)
		bmi.s	.return
		move.w	spikecrusher_depth(a0),d0
		add.w	d0,obY(a0)
		jsr	(ObjHitFloor).l
		move.w	spikecrusher_depth(a0),d0
		sub.w	d0,obY(a0)
		tst.w	d1
		bmi.s	.landed
		addi.l	#$8000,obY(a0)
		move.w	#$80,obVelY(a0)
.return:	rts
.landed:
		clr.w	obVelY(a0)
		st	spikecrusher_landed(a0)
		rts

MMZ_SpikeCrusher_Solid:
		jmp	(Spike_BackSolidPair).l

; Carry means the active player or partner lies in [left,right) and below
; the threshold. Inactive, carried and placement-mode players cannot start it.
MMZ_SpikeCrusher_CheckPlayers:
		lea	(v_player).w,a1
		bsr.s	.player
		bcs.s	.return
		lea	(v_player2).w,a1
.player:
		tst.l	code(a1)
		beq.s	.miss
		tst.b	obControl(a1)
		bmi.s	.miss
		cmpi.b	#6,obRoutine(a1)
		bhs.s	.miss
		tst.w	(Debug_placement_mode).w
		bne.s	.miss
		move.w	obY(a1),d0
		sub.w	obY(a0),d0
		cmp.w	d2,d0
		blt.s	.miss
		move.w	obX(a1),d0
		sub.w	platgroup_x(a0),d0
		add.w	d1,d0
		bmi.s	.miss
		move.w	d1,d3
		add.w	d3,d3
		cmp.w	d3,d0
.return:	rts
.miss:
		andi	#$FE,ccr
		rts

MMZ_SpikeCrusher_Touch:
		movea.w	platgroup_owner(a0),a1
		cmpi.l	#PlatformGroup_Run,code(a1)
		bne.s	.delete
		cmpi.l	#MMZ_SpikeCrusher_Controller,platgroup_state(a1)
		bne.s	.delete
		move.w	platgroup_link(a0),d1
		move.w	a0,d0
		cmp.w	(a1,d1.w),d0
		bne.s	.delete
		movea.w	spikecrusher_panel(a0),a2
		cmpi.l	#PlatformGroup_Run,code(a2)
		bne.s	.detach
		tst.b	spikecrusher_landed(a2)
		bmi.s	.detach
		move.w	obY(a2),d0
		addi.w	#12,d0
		move.w	d0,obY(a0)
		rts
.detach:
		clr.w	(a1,d1.w)
.delete:
		jmp	(DeleteObject).l

Map_MMZ_SpikeCrusher:
		binclude "mappings/sprite/MMZ SpikeCrusher.bin"
		even
