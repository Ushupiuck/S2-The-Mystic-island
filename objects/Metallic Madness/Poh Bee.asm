; MD CPU. Poh Bee patrols with one or two swinging spiked tips.
; The visible links are packed into composite sprites, with real tips for touch.

poh_long_tip = platgroup_members
poh_long_links = platgroup_members+2
poh_short_tip = platgroup_members+6
poh_short_links = platgroup_members+8
poh_bob_phase = obVelY
poh_bob_step = objoff_38
poh_patrol_time = objoff_3A
poh_bob_shift = objoff_3E
poh_tip_angle = objoff_2E
poh_tip_speed = objoff_30
poh_tip_accel = objoff_32

MMZ_PohBee:
		cmpi.b	#2,(Current_Timezone).w
		beq.w	.delete
		moveq	#5,d6
		lea	.normal(pc),a2
		tst.b	obSubtype+1(a0)
		beq.s	.allocate
		moveq	#3,d6
		lea	.slow(pc),a2
.allocate:
		jsr	(PlatformGroup_Preflight).l
		bne.w	.return
		lea	MMZ_PohBee_Move(pc),a4
		movea.l	a2,a5
		movea.l	a0,a1
		jsr	(PlatformGroup_InitMember).l
		move.w	12(a2),obVelX(a0)
		move.w	14(a2),poh_patrol_time(a0)
		move.w	16(a2),poh_bob_step(a0)
		move.w	18(a2),poh_bob_shift(a0)
		move.b	#Touch_Size_PohBeeBody_ID,obColType(a0)
		lea	MMZ_PohBee_Part(pc),a4
		jsr	(PlatformGroup_Allocate).l
		bsr.s	.tip
		move.w	#$800,poh_tip_angle(a1)
		jsr	(PlatformGroup_Allocate).l
		bsr.s	.links
		jsr	(PlatformGroup_Allocate).l
		bsr.s	.links
		tst.b	obSubtype+1(a0)
		bne.s	.ready
		jsr	(PlatformGroup_Allocate).l
		bsr.s	.tip
		move.w	#$1000,poh_tip_angle(a1)
		jsr	(PlatformGroup_Allocate).l
		bsr.s	.links
		move.b	#3,mainspr_childsprites(a1)
.ready:
		jmp	(PlatformGroup_Run).l
.delete:
		jmp	(DeleteObject).l
.return:
		rts

.tip:
		bsr.s	.part
		move.w	#$100,obPriority(a1)
		move.b	#12,width_pixels(a1)
		move.b	#12,height_pixels(a1)
		move.b	#3,obFrame(a1)
		move.b	#$8B,obColType(a1)	; $08 x $08 harmful half-size
		move.w	#8,poh_tip_accel(a1)
		jmp	(Touch_RegisterEarlierObject).l

.links:
		bsr.s	.part
		move.w	#$180,obPriority(a1)
		move.b	#40,mainspr_width(a1)
		move.b	#40,mainspr_height(a1)
		move.b	#4,mainspr_childsprites(a1)
		move.b	#2,mainspr_mapframe(a1)
		move.b	#$44,obRender(a1)
		rts
.part:
		move.l	#PlatformGroup_Run,code(a1)
		move.l	a4,platgroup_state(a1)
		move.l	obMap(a0),obMap(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.b	#4,obRender(a1)
		rts

.normal:
		dc.l	Map_MMZ_PohBee
		dc.w	ArtTile_MMZ_Atlas,$180
		dc.b	20,28,14,12
		dc.w	-$100,128,$400,3	; patrol velocity, period, bob rate, bob shift
.slow:
		dc.l	Map_MMZ_PohBeeSlow
		dc.w	ArtTile_MMZ_Atlas,$180
		dc.b	20,28,14,12
		dc.w	-$80,256,$300,4

MMZ_PohBee_Part:
		rts

MMZ_PohBee_Move:
		move.w	obVelX(a0),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,obX(a0)
		subq.w	#1,platgroup_timer(a0)
		bpl.s	.bob
		move.w	poh_patrol_time(a0),platgroup_timer(a0)
		neg.w	obVelX(a0)
		bchg	#render_flags.x_flip,obRender(a0)
		bchg	#render_flags.x_flip,obStatus(a0)
.bob:
		move.w	poh_bob_step(a0),d0
		add.w	d0,poh_bob_phase(a0)
		moveq	#0,d0
		move.b	poh_bob_phase(a0),d0
		jsr	(CalcSine).l
		swap	d0
		clr.w	d0
		move.w	poh_bob_shift(a0),d1
		asr.l	d1,d0
		moveq	#0,d1
		move.w	platgroup_y(a0),d1
		swap	d1
		add.l	d1,d0
		move.l	d0,obY(a0)
		lea	Ani_MMZ_PohBee(pc),a1
		jsr	(AnimateSprite).l

		movea.w	poh_long_tip(a0),a4
		bsr.s	MMZ_PohBee_Pendulum
		movea.w	poh_long_links(a0),a5
		moveq	#3,d6
		bsr.w	MMZ_PohBee_Links
		movea.w	poh_long_links+2(a0),a5
		moveq	#3,d6
		bsr.w	MMZ_PohBee_Links
		bsr.w	MMZ_PohBee_TipPosition
		tst.b	obSubtype+1(a0)
		bne.s	.return
		movea.w	poh_short_tip(a0),a4
		bsr.s	MMZ_PohBee_Pendulum
		movea.w	poh_short_links(a0),a5
		moveq	#2,d6
		bsr.w	MMZ_PohBee_Links
		bra.w	MMZ_PohBee_TipPosition
.return:
		rts

; a4 = tip and angular state. d2/d3 are the 16.16 segment step in X/Y.
; The accumulator accelerates toward a quarter turn from either side.
MMZ_PohBee_Pendulum:
		move.w	poh_tip_accel(a4),d1
		add.w	d1,poh_tip_speed(a4)
		move.w	poh_tip_angle(a4),d0
		move.w	d0,d1
		add.w	poh_tip_speed(a4),d1
		move.w	d1,poh_tip_angle(a4)
		subi.w	#$4000,d1
		subi.w	#$4000,d0
		eor.w	d1,d0
		bpl.s	.angle
		neg.w	poh_tip_accel(a4)
.angle:
		moveq	#0,d0
		move.b	poh_tip_angle(a4),d0
		jsr	(CalcSine).l
		move.w	d1,d2
		move.w	d0,d3
		swap	d2
		swap	d3
		clr.w	d2
		clr.w	d3
		asr.l	#5,d2
		asr.l	#5,d3
		move.l	obX(a0),d4
		move.l	obY(a0),d5
		addi.l	#$C0000,d5
		rts

; The group's main sprite and its d6+1 children occupy adjacent links.
MMZ_PohBee_Links:
		add.l	d2,d4
		add.l	d3,d5
		move.l	d4,d0
		move.l	d5,d1
		swap	d0
		swap	d1
		move.w	d0,obX(a5)
		move.w	d1,obY(a5)
		lea	subspr_data(a5),a3
.link:
		add.l	d2,d4
		add.l	d3,d5
		move.l	d4,d0
		move.l	d5,d1
		swap	d0
		swap	d1
		move.w	d0,(a3)+
		move.w	d1,(a3)+
		move.w	#2,(a3)+
		dbf	d6,.link
		rts

MMZ_PohBee_TipPosition:
		add.l	d2,d4
		add.l	d3,d5
		move.l	d4,obX(a4)
		move.l	d5,obY(a4)
		rts

Map_MMZ_PohBee:
		binclude "mappings/sprite/MMZ PohBee.bin"
		even
Map_MMZ_PohBeeSlow:
		binclude "mappings/sprite/MMZ PohBee Alternate.bin"
		even

Ani_MMZ_PohBee:
		dc.w	.wings-Ani_MMZ_PohBee
.wings:		dc.b	2,0,1,$FF
