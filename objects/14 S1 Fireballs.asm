; MD main CPU. S1 fireballs: s1disasm 2c51d46; maker flow: skdisasm 73de97c6
; Obj_LRZFireballLauncher. $14 is the maker; $15 is one projectile.
; Word settings: bits 0-1 arc strength, 2 straight flight, 3 horizontal straight
; flight, 4-7 maker interval (30..180, clamped); upper bits are preserved.
; Placement X flip selects left; Y flip selects down, including mirrored arcs.
S1Fireball_Interval:	equ objoff_2E	; maker: byte
S1Fireball_Timer:	equ objoff_2F	; maker: byte
S1Fireball_OriginY:	equ objoff_30	; projectile: word
S1Fireball_FromBoss:	equ objoff_32	; projectile: optional lower drawing tier

S1FireballSpawner:
		move.l	#Map_FireballMaker,obMap(a0)
		move.w	#make_art_tile(ArtTile_FireballMaker,0,0),obGfx(a0)
		move.b	obStatus(a0),d0
		andi.b	#3,d0
		ori.b	#4,d0
		move.b	d0,obRender(a0)
		move.b	#Map_FireballMaker_height,height_pixels(a0)
		move.b	#Map_FireballMaker_width,width_pixels(a0)
		move.w	#$100,obPriority(a0)
		moveq	#1,d0		; vertical, including arcing shots
		move.w	obSubtype(a0),d1
		andi.w	#$C,d1
		cmpi.w	#$C,d1
		bne.s	.frame_ready
		moveq	#0,d0		; horizontal straight shot
.frame_ready:
		move.b	d0,obFrame(a0)
		move.w	obSubtype(a0),d0
		lsr.w	#4,d0
		andi.w	#$F,d0
		cmpi.w	#5,d0
		bls.s	.rate_ready
		moveq	#5,d0
.rate_ready:
		lea	S1Fireball_Rates(pc),a1
		move.b	(a1,d0.w),d0
		move.b	d0,S1Fireball_Interval(a0)
		move.b	d0,S1Fireball_Timer(a0)
		move.l	#S1FireballSpawner_Wait,code(a0)
S1FireballSpawner_Wait:
		subq.b	#1,S1Fireball_Timer(a0)
		bne.s	.return
		move.b	S1Fireball_Interval(a0),S1Fireball_Timer(a0)
		jsr	(ChkObjectVisible).l
		bne.s	.return
		jsr	(AllocateObjectAfterCurrent).l
		beq.s	.allocated
		jsr	(FindFreeObj).l		; retain earlier free slots at the end of the pool
		bne.s	.return
.allocated:
		move.l	#S1Fireball,code(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	obSubtype(a0),obSubtype(a1)
		move.b	obStatus(a0),obStatus(a1)
		andi.b	#3,obStatus(a1)		; placement direction, not maker state
		moveq	#16,d0			; muzzle edge plus projectile collision radius
		tst.b	obFrame(a0)
		bne.s	.vertical
		btst	#0,obStatus(a0)
		beq.s	.horizontal_offset
		neg.w	d0
.horizontal_offset:
		add.w	d0,obX(a1)
		bra.s	.return
.vertical:
		btst	#1,obStatus(a0)
		bne.s	.vertical_offset
		neg.w	d0
.vertical_offset:
		add.w	d0,obY(a1)
.return:
		jmp	(MarkObjGone).l		; draw the housing and release unloaded placements

S1Fireball_Rates:
		dc.b 30,60,90,120,150,180
		even

S1Fireball:
		move.b	#8,obHeight(a0)
		move.b	#8,obWidth(a0)
		move.l	#Map_Fireballs,obMap(a0)
		move.b	#Map_Fireballs_height,height_pixels(a0)
		move.b	#Map_Fireballs_width,width_pixels(a0)
		move.w	#make_art_tile(ArtTile_Fireball,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$180,obPriority(a0)
		move.b	#$8B,obColType(a0)
		move.w	obY(a0),S1Fireball_OriginY(a0)
		tst.b	S1Fireball_FromBoss(a0)
		beq.s	.motion
		addi.w	#$100,obPriority(a0)
.motion:
		move.w	obSubtype(a0),d0
		btst	#2,d0
		bne.s	.straight
		andi.w	#3,d0
		lsl.w	#8,d0
		addi.w	#$400,d0
		neg.w	d0
		move.l	#S1Fireball_Arc,code(a0)
		btst	#1,obStatus(a0)
		beq.s	.arc_ready
		neg.w	d0
		move.l	#S1Fireball_ArcDown,code(a0)
.arc_ready:
		move.w	d0,obVelY(a0)
		bra.s	.begin
.straight:
		btst	#3,d0
		bne.s	.horizontal
		move.w	#-$200,obVelY(a0)
		move.l	#S1Fireball_Up,code(a0)
		btst	#1,obStatus(a0)
		bne.s	.down
		bset	#1,obStatus(a0)		; the vertical mapping's default points down
		bra.s	.begin
.down:
		neg.w	obVelY(a0)
		bclr	#1,obStatus(a0)
		move.l	#S1Fireball_Down,code(a0)
		bra.s	.begin
.horizontal:
		move.b	#2,obAnim(a0)
		move.w	#$200,obVelX(a0)
		move.l	#S1Fireball_Right,code(a0)
		btst	#0,obStatus(a0)
		beq.s	.begin
		neg.w	obVelX(a0)
		move.l	#S1Fireball_Left,code(a0)
.begin:
		move.w	#sfx_Fireball,d0
		jsr	(PlaySound_Special).l
		movea.l	code(a0),a1
		jmp	(a1)

S1Fireball_Arc:
		addi.w	#$18,obVelY(a0)
		move.w	S1Fireball_OriginY(a0),d0
		cmp.w	obY(a0),d0
		bhs.s	S1Fireball_ArcFacing
		bra.s	S1Fireball_ArcExpired
S1Fireball_ArcDown:
		subi.w	#$18,obVelY(a0)
		move.w	S1Fireball_OriginY(a0),d0
		cmp.w	obY(a0),d0
		bls.s	S1Fireball_ArcFacing
S1Fireball_ArcExpired:
		move.l	#S1Fireball_Delete,code(a0)
S1Fireball_ArcFacing:
		bclr	#1,obStatus(a0)
		tst.w	obVelY(a0)
		bpl.s	S1Fireball_Animate
		bset	#1,obStatus(a0)
		bra.s	S1Fireball_Animate

S1Fireball_Up:
		jsr	(ObjHitCeiling).l
		bra.s	S1Fireball_VerticalImpact
S1Fireball_Down:
		jsr	(ObjHitFloor).l
S1Fireball_VerticalImpact:
		tst.w	d1
		bpl.s	S1Fireball_Animate
		move.b	#1,obAnim(a0)
		clr.w	obVelY(a0)
		bra.s	S1Fireball_StartImpact

S1Fireball_Left:
		moveq	#-8,d3
		jsr	(ObjHitWallLeft).l
		bra.s	S1Fireball_HorizontalImpact
S1Fireball_Right:
		moveq	#8,d3
		jsr	(ObjHitWallRight).l
S1Fireball_HorizontalImpact:
		tst.w	d1
		bpl.s	S1Fireball_Animate
		move.b	#3,obAnim(a0)
		clr.w	obVelX(a0)
S1Fireball_StartImpact:
		move.l	#S1Fireball_Impact,code(a0)
		bra.s	S1Fireball_Draw
S1Fireball_Impact:
		tst.b	obRoutine(a0)		; animation's afRoutine signals completion
		bne.s	S1Fireball_Delete
		bra.s	S1Fireball_Draw		; stopped impact frames need no movement
S1Fireball_Animate:
		jsr	(ObjectMove).l
S1Fireball_Draw:
		lea	(Ani_S1Fireball).l,a1
		jsr	(AnimateSprite).l
		out_of_range.w	S1Fireball_Delete
		jmp	(DisplaySprite).l
S1Fireball_Delete:
		jmp	(UnloadObject).l		; emitted children have handle zero

Ani_S1Fireball:
		dc.w Ani_S1Fireball_Vertical-Ani_S1Fireball,Ani_S1Fireball_VerticalImpact-Ani_S1Fireball
		dc.w Ani_S1Fireball_Horizontal-Ani_S1Fireball,Ani_S1Fireball_HorizontalImpact-Ani_S1Fireball
Ani_S1Fireball_Vertical:
		dc.b 5,0,$20,1,$21,afEnd
Ani_S1Fireball_VerticalImpact:
		dc.b 5,2,afRoutine
		even
Ani_S1Fireball_Horizontal:
		dc.b 5,3,$43,4,$44,afEnd
Ani_S1Fireball_HorizontalImpact:
		dc.b 5,5,afRoutine
		even
