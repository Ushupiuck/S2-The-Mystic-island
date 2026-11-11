; MD main CPU. From s1disasm 2c51d46, objects 13/14 (FixBugs path).
; Placement $14 is the invisible spawner; children use full code pointers.
; Subtype: low nibble 0-3 arcs (-$400..-$700), 4 up, 5 down, 6 left,
; 7 right, 8 stationary. High nibble 0-5 selects 30..180-update intervals.
; Reserved word bits survive initialization/child creation; invalid nibbles
; clamp to the last table entry. Placement flips do not change launch type.
S1Fireball_Interval:	equ objoff_2E	; spawner: byte
S1Fireball_Timer:	equ objoff_2F	; spawner: byte
S1Fireball_Type:		equ objoff_2E	; projectile: byte, 0-8
S1Fireball_OriginY:	equ objoff_30	; projectile: word
S1Fireball_FromBoss:	equ objoff_32	; projectile: byte, optional lower drawing tier

S1FireballSpawner:
		move.w	obSubtype(a0),d0
		lsr.w	#4,d0
		andi.w	#$F,d0
		cmpi.w	#5,d0
		bls.s	.rate_ready
		moveq	#5,d0
.rate_ready:
		move.b	S1Fireball_Rates(pc,d0.w),S1Fireball_Interval(a0)
		move.b	S1Fireball_Interval(a0),S1Fireball_Timer(a0)
		move.l	#S1FireballSpawner_Wait,code(a0)
S1FireballSpawner_Wait:
		subq.b	#1,S1Fireball_Timer(a0)
		bne.s	.return
		move.b	S1Fireball_Interval(a0),S1Fireball_Timer(a0)
		jsr	(ChkObjectVisible).l
		bne.s	.return
		jsr	(FindFreeObj).l
		bne.s	.return
		move.l	#S1Fireball,code(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	obSubtype(a0),obSubtype(a1)
.return:
		jmp	(MarkObjGone2).l	; invisible; unload releases its placement handle

S1Fireball_Rates:
		dc.b 30,60,90,120,150,180
		even

S1Fireball:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	S1Fireball_Index(pc,d0.w),d1
		jmp	S1Fireball_Index(pc,d1.w)
S1Fireball_Index:
		dc.w S1Fireball_Init-S1Fireball_Index
		dc.w S1Fireball_Move-S1Fireball_Index
		dc.w S1Fireball_Delete-S1Fireball_Index

S1Fireball_Init:
		addq.b	#2,obRoutine(a0)
		move.b	#8,obHeight(a0)
		move.b	#8,obWidth(a0)
		move.l	#Map_Fireballs,obMap(a0)
		move.b	#Map_Fireballs_height,height_pixels(a0)
		move.b	#Map_Fireballs_width,width_pixels(a0)
		move.w	#make_art_tile(ArtTile_Fireball,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$180,obPriority(a0)
		move.b	#$8B,obColType(a0)	; S1's 8px collision radii, harmful to either player
		move.w	obY(a0),S1Fireball_OriginY(a0)
		tst.b	S1Fireball_FromBoss(a0)
		beq.s	.type
		addi.w	#$100,obPriority(a0)
.type:
		move.w	obSubtype(a0),d0
		andi.w	#$F,d0
		cmpi.w	#8,d0
		bls.s	.type_ready
		moveq	#8,d0
.type_ready:
		move.b	d0,S1Fireball_Type(a0)
		add.w	d0,d0
		move.w	S1Fireball_Speeds(pc,d0.w),obVelY(a0)
		cmpi.w	#6*2,d0
		blo.s	.sound
		move.b	#2,obAnim(a0)
		move.w	obVelY(a0),obVelX(a0)
		clr.w	obVelY(a0)
.sound:
		move.w	#sfx_Fireball,d0
		jsr	(PlaySound_Special).l
S1Fireball_Move:
		moveq	#0,d0
		move.b	S1Fireball_Type(a0),d0
		add.w	d0,d0
		move.w	S1Fireball_Types(pc,d0.w),d1
		jsr	S1Fireball_Types(pc,d1.w)
		jsr	(ObjectMove).l
		lea	(Ani_S1Fireball).l,a1
		jsr	(AnimateSprite).l
		out_of_range.w	S1Fireball_Delete
		jmp	(DisplaySprite).l

S1Fireball_Speeds:
		dc.w -$400,-$500,-$600,-$700,-$200,$200,-$200,$200,0
S1Fireball_Types:
		dc.w S1Fireball_Arc-S1Fireball_Types,S1Fireball_Arc-S1Fireball_Types
		dc.w S1Fireball_Arc-S1Fireball_Types,S1Fireball_Arc-S1Fireball_Types
		dc.w S1Fireball_Up-S1Fireball_Types,S1Fireball_Down-S1Fireball_Types
		dc.w S1Fireball_Left-S1Fireball_Types,S1Fireball_Right-S1Fireball_Types
		dc.w S1Fireball_Still-S1Fireball_Types

S1Fireball_Arc:
		addi.w	#$18,obVelY(a0)
		move.w	S1Fireball_OriginY(a0),d0
		cmp.w	obY(a0),d0
		bhs.s	.facing
		addq.b	#2,obRoutine(a0)
.facing:
		bclr	#1,obStatus(a0)
		tst.w	obVelY(a0)
		bpl.s	S1Fireball_Still
		bset	#1,obStatus(a0)
S1Fireball_Still:
		rts

S1Fireball_Up:
		bset	#1,obStatus(a0)
		jsr	(ObjHitCeiling).l
		bra.s	S1Fireball_VerticalImpact
S1Fireball_Down:
		bclr	#1,obStatus(a0)
		jsr	(ObjHitFloor).l
S1Fireball_VerticalImpact:
		tst.w	d1
		bpl.s	S1Fireball_Still
		move.b	#8,S1Fireball_Type(a0)
		move.b	#1,obAnim(a0)
		clr.w	obVelY(a0)
		rts

S1Fireball_Left:
		bset	#0,obStatus(a0)
		moveq	#-8,d3
		jsr	(ObjHitWallLeft).l
		bra.s	S1Fireball_HorizontalImpact
S1Fireball_Right:
		bclr	#0,obStatus(a0)
		moveq	#8,d3
		jsr	(ObjHitWallRight).l
S1Fireball_HorizontalImpact:
		tst.w	d1
		bpl.s	S1Fireball_Still
		move.b	#8,S1Fireball_Type(a0)
		move.b	#3,obAnim(a0)
		clr.w	obVelX(a0)
		rts

S1Fireball_Delete:
		jmp	(DeleteObject).l

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
