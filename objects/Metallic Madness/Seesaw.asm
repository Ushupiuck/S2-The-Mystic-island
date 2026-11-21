; MD CPU. The seesaw trap's cap lowers while its ball flies upward.
; The cap and the ball share placement lifetime with the animated base.

MMZ_Seesaw:
		moveq	#2,d6
		jsr	(PlatformGroup_Preflight).l
		bne.s	.return
		lea	MMZ_Seesaw_Base(pc),a4
		lea	.profiles(pc),a5
		movea.l	a0,a1
		jsr	(PlatformGroup_InitMember).l
		move.b	#1,platgroup_dwell(a0)
		jsr	(PlatformGroup_Allocate).l
		lea	MMZ_Seesaw_BallWait(pc),a4
		lea	12(a5),a5
		bsr.s	.member
		move.b	#5,obFrame(a1)
		jsr	(PlatformGroup_Allocate).l
		lea	MMZ_Seesaw_Cap(pc),a4
		lea	12(a5),a5
		bsr.s	.member
		move.b	#8,obFrame(a1)
		move.w	obY(a0),d0
		subi.w	#44,d0
		move.w	d0,obY(a1)
		jmp	(PlatformGroup_Run).l
.return:	rts

.member:
		move.l	obX(a0),obX(a1)
		move.l	obY(a0),obY(a1)
		jmp	(PlatformGroup_InitMember).l

.profiles:
		dc.l	Map_MMZ_Seesaw
		dc.w	ArtTile_MMZ_Atlas,$280
		dc.b	56,40,0,0
		dc.l	Map_MMZ_Seesaw
		dc.w	ArtTile_MMZ_Atlas,$300
		dc.b	32,32,0,0
		dc.l	Map_MMZ_Seesaw
		dc.w	ArtTile_MMZ_Atlas,$180
		dc.b	16,40,12,40

; The cap sets routine 2 on first contact. Once lowered, it cycles while
; the cap is empty and returns to the lowered pose under either rider.
MMZ_Seesaw_Base:
		tst.b	obRoutine(a0)
		beq.s	.return
		subq.b	#1,platgroup_dwell(a0)
		bcc.s	.return
		move.b	#5,platgroup_dwell(a0)
		addq.b	#1,obFrame(a0)
		cmpi.b	#4,obFrame(a0)
		blo.s	.return
		move.b	#10,platgroup_dwell(a0)
		move.l	#MMZ_Seesaw_Cycle,platgroup_state(a0)
.return:	rts

MMZ_Seesaw_Cycle:
		movea.w	platgroup_members+2(a0),a1
		move.b	obStatus(a1),d0
		andi.b	#$18,d0
		bne.s	.loaded
		subq.b	#1,platgroup_dwell(a0)
		bcc.s	.return
		moveq	#0,d0
		move.b	platgroup_sequence(a0),d0
		addq.b	#1,platgroup_sequence(a0)
		andi.b	#3,platgroup_sequence(a0)
		move.b	.poses(pc,d0.w),obFrame(a0)
		move.b	#10,platgroup_dwell(a0)
.return:	rts
.loaded:
		cmpi.b	#4,obFrame(a0)
		beq.s	.return
		addq.b	#1,obFrame(a0)
		move.b	#10,platgroup_dwell(a0)
		rts
.poses:		dc.b	2,1,2,3

MMZ_Seesaw_Cap:
		movea.w	platgroup_owner(a0),a2
		moveq	#0,d0
		move.b	obFrame(a2),d0
		add.w	d0,d0
		move.w	.offsets(pc,d0.w),d0
		add.w	obY(a2),d0
		move.w	d0,d1
		sub.w	obY(a0),d1
		lsl.w	#8,d1
		move.w	d1,obVelY(a0)
		move.w	d0,obY(a0)
		moveq	#40+sonic_solid_width,d1
		moveq	#12,d2
		moveq	#13,d3
		move.w	obX(a0),d4
		jsr	(SolidObject).l
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		bne.s	.activate
		swap	d6
		andi.w	#$C,d6
		beq.s	.return
.activate:
		movea.w	platgroup_owner(a0),a1
		move.b	#2,obRoutine(a1)
.return:	rts
.offsets:	dc.w	-44,-28,-12,12,28

MMZ_Seesaw_BallWait:
		movea.w	platgroup_owner(a0),a1
		tst.b	obRoutine(a1)
		beq.s	.return
		move.l	#MMZ_Seesaw_BallFlight,platgroup_state(a0)
		move.w	#-$C00,obVelY(a0)
		jmp	(ObjectMove).l
.return:	rts

MMZ_Seesaw_BallFlight:
		addi.w	#$40,obVelY(a0)
		bmi.s	.rise
		bne.s	.land_check
		move.b	#7,obFrame(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$80|Touch_Size_MMZSaw_ID,obColType(a0)	; 28px half-size
.land_check:
		movea.w	platgroup_owner(a0),a1
		move.w	obY(a1),d0
		cmp.w	obY(a0),d0
		bhi.s	.move
		addq.w	#4,d0
		move.w	d0,obY(a0)
		clr.w	obVelY(a0)
		move.b	#4,obFrame(a1)
		move.l	#MMZ_Seesaw_Idle,platgroup_state(a1)
		move.l	#MMZ_Seesaw_Idle,platgroup_state(a0)
		rts
.rise:
		cmpi.w	#-$800,obVelY(a0)
		bne.s	.move
		move.b	#6,obFrame(a0)
.move:
		jmp	(ObjectMove).l

MMZ_Seesaw_Idle:
		rts

Map_MMZ_Seesaw:
		binclude "mappings/sprite/MMZ Seesaw.bin"
		even
