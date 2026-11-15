; ===========================================================================
; Bomb / Bigbom. MD CPU; S1 REV01 and scddisasm test 791253ba r8/bigbom.asm.
; Placement $AE: $0X small, $1X large. X=0 preserves the original speed;
; X=1..F selects quarter-pixel steps. Bigbom's upper byte selects its patrol:
; 0 normal, 1 short, 2 scripted charge. Helpers use direct entries, not subtypes.
; ===========================================================================
Bomb_speed:		equ objoff_30 ; root: positive 8.8 selected speed; debris: gravity
Bomb_timer:		equ objoff_32 ; root: state countdown; flash: remaining lifetime
Bomb_child:		equ objoff_34 ; root: reciprocal burning-fuse handle
Bomb_gait:		equ objoff_36 ; root: Bigbom gait hold
Bomb_parent:		equ objoff_2E ; fuse: reciprocal root handle

Bomb:
		move.w	obSubtype(a0),d0
		andi.w	#$F0,d0
		cmpi.w	#$10,d0
		beq.s	.big
		move.l	#Map_SMZ_Bomb,obMap(a0)
		move.b	#Map_SMZ_Bomb_height,height_pixels(a0)
		move.b	#Map_SMZ_Bomb_width,width_pixels(a0)
		move.w	#ArtTile_Bomb,obGfx(a0)
		cmpi.b	#$F,(Current_Zone).w
		bne.s	.small
		move.w	#ArtTile_Bomb_MMZ,obGfx(a0)
.small:
		move.b	#16,obHeight(a0)
		move.b	#12,obWidth(a0)
		move.b	#$9A,obColType(a0)
		moveq	#$10,d1
		bra.s	.setup
.big:
		move.l	#Map_Bigbom,obMap(a0)
		move.b	#Map_Bigbom_height,height_pixels(a0)
		move.b	#Map_Bigbom_width,width_pixels(a0)
		move.w	#ArtTile_MMZ_Atlas|$8000,obGfx(a0)
		move.b	#26,obHeight(a0)
		move.b	#20,obWidth(a0)
		move.b	#3,obFrame(a0)
		move.b	#$86,obColType(a0)
		cmpi.b	#2,obSubtype(a0)
		bne.s	.bigSpeed
		move.b	#Touch_Size_BigbomBody_ID|$C0,obColType(a0)
.bigSpeed:
		move.w	#$A0,d1
.setup:
		move.w	obSubtype(a0),d0
		andi.w	#$F,d0
		beq.s	.speed
		lsl.w	#6,d0
		move.w	d0,d1
.speed:
		move.w	d1,Bomb_speed(a0)
		move.w	#$180,obPriority(a0)
		ori.b	#4,obRender(a0)
		move.l	#Bomb_Fall,code(a0)
Bomb_Fall:
		moveq	#1,d0
		btst	#1,obStatus(a0)
		beq.s	.drop
		neg.w	d0
.drop:
		add.w	d0,obY(a0)
		bsr.w	Bomb_ProbeSurface
		tst.w	d1
		bpl.w	Bomb_Draw
		bsr.w	Bomb_AlignSurface
		cmpi.l	#Map_Bigbom,obMap(a0)
		beq.s	.bigLanded
		move.l	#Bomb_SmallWait,code(a0)
		bra.w	Bomb_SmallWait
.bigLanded:
		cmpi.b	#2,obSubtype(a0)
		beq.s	.charge
		bsr.w	Bomb_StartWalking
		move.l	#Bomb_BigWalk,code(a0)
		bra.w	Bomb_Draw
.charge:
		bchg	#0,obStatus(a0)
		move.l	#Bomb_BigWaitCharge,code(a0)
		bra.w	Bomb_Draw

; Both families follow floors or roofs. Reject the whole fixed-point X step
; at an edge or an impassable rise, then reverse; never drift over empty space.
Bomb_SurfaceMove:
		move.l	obX(a0),-(sp)
		jsr	(SpeedToPos).l
		bsr.s	Bomb_ProbeSurface
		cmpi.w	#-7,d1
		blt.s	Bomb_SurfaceEdge
		cmpi.w	#7,d1
		bgt.s	Bomb_SurfaceEdge
		addq.l	#4,sp
Bomb_AlignSurface:
		btst	#1,obStatus(a0)
		beq.s	.floor
		neg.w	d1
.floor:
		add.w	d1,obY(a0)
		rts
Bomb_SurfaceEdge:
		move.l	(sp)+,obX(a0)
Bomb_Reverse:
		neg.w	obVelX(a0)
		bchg	#0,obStatus(a0)
		rts
Bomb_ProbeSurface:
		btst	#1,obStatus(a0)
		bne.s	.roof
		jmp	(ObjHitFloor).l
.roof:
		jmp	(ObjHitCeiling).l
Bomb_StartWalking:
		move.w	Bomb_speed(a0),d0
		btst	#0,obStatus(a0)
		bne.s	.right
		neg.w	d0
.right:
		move.w	d0,obVelX(a0)
		rts

Bomb_SmallWait:
		bsr.w	Bomb_SmallRange
		tst.w	d0
		bne.w	Bomb_SmallArm
		subq.w	#1,Bomb_timer(a0)
		bpl.w	Bomb_SmallDraw
		move.w	#1535,Bomb_timer(a0)
		move.b	#1,obAnim(a0)
		bsr.s	Bomb_StartWalking
		move.l	#Bomb_SmallWalk,code(a0)
		bra.w	Bomb_SmallDraw
Bomb_SmallWalk:
		bsr.w	Bomb_SmallRange
		tst.w	d0
		bne.s	Bomb_SmallArm
		subq.w	#1,Bomb_timer(a0)
		bmi.s	.stop
		bsr.w	Bomb_SurfaceMove
		bra.w	Bomb_SmallDraw
.stop:
		move.w	#179,Bomb_timer(a0)
		clr.w	obVelX(a0)
		clr.b	obAnim(a0)
		bchg	#0,obStatus(a0)
		move.l	#Bomb_SmallWait,code(a0)
		bra.w	Bomb_SmallDraw
Bomb_SmallArm:
		clr.w	obVelX(a0)
		move.b	#2,obAnim(a0)
		move.w	#144,Bomb_timer(a0)
		move.l	#Bomb_SmallBurn,code(a0)
		bsr.w	Bomb_SpawnFuse
		bra.w	Bomb_SmallDraw
Bomb_SmallBurn:
		subq.w	#1,Bomb_timer(a0)
		bne.w	Bomb_SmallDraw
		bsr.w	Bomb_DeleteFuse
		bsr.w	Bomb_SpawnFragments
		move.l	#FieryExplosion,code(a0)
		clr.b	obRoutine(a0)
		jmp	(FieryExplosion).l
Bomb_SmallDraw:
		lea	Ani_Bomb(pc),a1
		jsr	(AnimateSprite).l
		bra.w	Bomb_Draw

Bomb_BigWalk:
		bsr.w	Bomb_SurfaceMove
		subq.w	#1,Bomb_timer(a0)
		bpl.s	.gait
		bsr.w	Bomb_Reverse
		move.w	#204,d0
		tst.b	obSubtype(a0)
		beq.s	.turn
		moveq	#25,d0
.turn:
		move.w	d0,Bomb_timer(a0)
.gait:
		bsr.w	Bomb_BigGait
		tst.b	obFrame(a0)
		bne.w	Bomb_Draw
		bsr.w	Bomb_BigRange
		tst.w	d0
		beq.w	Bomb_Draw
		bra.s	Bomb_BigArm
Bomb_BigWaitCharge:
		bsr.w	Bomb_BigRange
		tst.w	d0
		beq.w	Bomb_Draw
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		bmi.w	Bomb_Draw
		move.w	#$280,obVelX(a0)
		move.w	obSubtype(a0),d0
		andi.w	#$F,d0
		beq.s	.original
		move.w	Bomb_speed(a0),obVelX(a0)
.original:
		move.w	#230,Bomb_timer(a0)
		move.w	#18,Bomb_gait(a0)
		move.l	#Bomb_BigCharge,code(a0)
Bomb_BigCharge:
		bsr.w	Bomb_SurfaceMove
		bsr.w	Bomb_BigGait
		subq.w	#1,Bomb_timer(a0)
		bpl.w	Bomb_Draw
		clr.w	obVelX(a0)
		move.l	#Bomb_BigWaitTarget,code(a0)
		bra.w	Bomb_Draw
Bomb_BigWaitTarget:
		bsr.w	Bomb_BigRange
		tst.w	d0
		beq.w	Bomb_Draw
Bomb_BigArm:
		clr.w	obVelX(a0)
		move.w	#30,Bomb_timer(a0)
		move.l	#Bomb_BigPreFuse,code(a0)
		bra.w	Bomb_Draw
Bomb_BigPreFuse:
		subq.w	#1,Bomb_timer(a0)
		bne.w	Bomb_Draw
		move.b	#4,obFrame(a0)
		move.w	#138,Bomb_timer(a0)
		move.l	#Bomb_BigBurn,code(a0)
		bsr.w	Bomb_SpawnFuse
		bra.w	Bomb_Draw
Bomb_BigBurn:
		subq.w	#1,Bomb_timer(a0)
		bne.w	Bomb_Draw
		bsr.w	Bomb_DeleteFuse
		move.w	#30,Bomb_timer(a0)
		move.l	#Bomb_BigDetonate,code(a0)
		bra.w	Bomb_Draw
Bomb_BigDetonate:
		subq.w	#1,Bomb_timer(a0)
		bne.w	Bomb_Draw
		jsr	(FindFreeObj).l
		bne.s	.next
		move.l	#Bomb_BigFlash,code(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.l	#Map_FExplosion,obMap(a1)
		move.w	#ArtTile_Explosion|$8000,obGfx(a1)
		move.b	#Map_FExplosion_height,height_pixels(a1)
		move.b	#Map_FExplosion_width,width_pixels(a1)
		move.w	#$80,obPriority(a1)
		move.b	#4,obRender(a1)
		move.w	#40,Bomb_timer(a1)
.next:
		move.w	#SndID_BossExplosion,d0
		jsr	(PlaySound_Special).l
		move.l	#Bomb_BigScatter,code(a0)
		bra.w	Bomb_Draw
Bomb_BigScatter:
		bsr.w	Bomb_SpawnFragments
		move.l	#Bomb_BigRemove,code(a0)
		bra.w	Bomb_Draw
Bomb_BigRemove:
		jmp	(DeleteObject).l
Bomb_BigFlash:
		subq.w	#1,Bomb_timer(a0)
		bmi.s	Bomb_BigRemove
		moveq	#39,d0
		sub.w	Bomb_timer(a0),d0
		lsr.w	#2,d0
		cmpi.w	#5,d0
		blo.s	.frame
		subq.w	#5,d0
.frame:
		move.b	d0,obFrame(a0)
		jmp	(DisplaySprite).l
Bomb_BigGait:
		subq.w	#1,Bomb_gait(a0)
		bpl.s	.return
		addq.b	#1,obFrame(a0)
		andi.b	#3,obFrame(a0)
		moveq	#0,d0
		move.b	obFrame(a0),d0
		add.w	d0,d0
		move.w	.holds(pc,d0.w),Bomb_gait(a0)
.return:	rts
.holds:		dc.w 25,15,25,18

; The fuse is visual only: the root owns the countdown and always detonates,
; even when allocation fails. Reciprocal links reject recycled same-family slots.
Bomb_SpawnFuse:
		jsr	(FindFreeObj).l
		bne.s	.return
		move.w	a1,Bomb_child(a0)
		move.w	a0,Bomb_parent(a1)
		move.l	#Bomb_Fuse,code(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obStatus(a0),obRender(a1)
		ori.b	#4,obRender(a1)
		move.w	#$100,obPriority(a1)
		move.l	#Map_SMZ_Bomb,obMap(a1)
		move.b	#Map_SMZ_Bomb_height,height_pixels(a1)
		move.b	#Map_SMZ_Bomb_width,width_pixels(a1)
		move.b	#3,obAnim(a1)
		cmpi.l	#Map_Bigbom,obMap(a0)
		bne.s	.pose
		move.l	#Map_BigbomFuse,obMap(a1)
		move.b	#Map_BigbomFuse_height,height_pixels(a1)
		move.b	#Map_BigbomFuse_width,width_pixels(a1)
		clr.b	obAnim(a1)
.pose:
		movem.l	a0-a1,-(sp)
		movea.l	a1,a0
		bsr.s	Bomb_FusePose
		movem.l	(sp)+,a0-a1
.return:	rts
Bomb_Fuse:
		movea.w	Bomb_parent(a0),a1
		cmpi.l	#Bomb_SmallBurn,code(a1)
		beq.s	.owner
		cmpi.l	#Bomb_BigBurn,code(a1)
		bne.w	Bomb_BigRemove
.owner:
		move.w	a0,d0
		cmp.w	Bomb_child(a1),d0
		bne.w	Bomb_BigRemove
		bsr.s	Bomb_FusePose
		lea	Ani_Bomb(pc),a1
		cmpi.l	#Map_BigbomFuse,obMap(a0)
		bne.s	.animate
		lea	Ani_BigbomFuse(pc),a1
.animate:
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l
Bomb_FusePose:
		movea.w	Bomb_parent(a0),a1
		move.l	obX(a1),obX(a0)
		move.l	obY(a1),obY(a0)
		move.w	#144,d0
		sub.w	Bomb_timer(a1),d0
		lsl.w	#4,d0
		moveq	#0,d1
		cmpi.l	#Map_BigbomFuse,obMap(a0)
		bne.s	.offset
		moveq	#78,d0
		sub.w	Bomb_timer(a1),d0
		bpl.s	.burning
		moveq	#0,d0
.burning:
		mulu.w	#$50,d0
		moveq	#-31,d1
.offset:
		ext.l	d0
		lsl.l	#8,d0
		swap	d1
		clr.w	d1
		add.l	d1,d0
		btst	#1,obStatus(a0)
		beq.s	.position
		neg.l	d0
.position:
		add.l	d0,obY(a0)
		rts
Bomb_DeleteFuse:
		move.w	Bomb_child(a0),d0
		beq.s	.return
		clr.w	Bomb_child(a0)
		movea.w	d0,a1
		cmpi.l	#Bomb_Fuse,code(a1)
		bne.s	.return
		move.w	a0,d0
		cmp.w	Bomb_parent(a1),d0
		bne.s	.return
		jmp	(DeleteObject2).l
.return:	rts

; A failed allocation still consumes its velocity pair. No writes through a
; failed allocator result, and no placement ownership passes to the fragments.
Bomb_SpawnFragments:
		lea	Bomb_SmallSpeeds(pc),a2
		moveq	#3,d6
		cmpi.l	#Map_Bigbom,obMap(a0)
		bne.s	.loop
		lea	Bomb_BigSpeeds(pc),a2
		moveq	#6,d6
.loop:
		jsr	(FindFreeObj).l
		bne.w	.next
		move.l	#Bomb_Debris,code(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.w	obSubtype(a0),obSubtype(a1)
		move.w	(a2),obVelX(a1)
		move.w	2(a2),obVelY(a1)
		move.b	#$84,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.l	#Map_SMZ_Bomb,obMap(a1)
		move.b	#Map_SMZ_Bomb_height,height_pixels(a1)
		move.b	#Map_SMZ_Bomb_width,width_pixels(a1)
		move.b	#$A,obFrame(a1)
		move.b	#$98,obColType(a1)
		move.w	#$18,Bomb_speed(a1)
		cmpi.l	#Map_Bigbom,obMap(a0)
		bne.w	.next
		move.l	#Map_BigbomDebris,obMap(a1)
		move.b	#Map_BigbomDebris_height,height_pixels(a1)
		move.b	#Map_BigbomDebris_width,width_pixels(a1)
		clr.b	obFrame(a1)
		move.b	#1,obAnim(a1)
		move.w	#$20,Bomb_speed(a1)
		move.b	#$87,obColType(a1)
		cmpi.b	#2,obSubtype(a0)
		bne.w	.next
		move.b	#Touch_Size_BigbomDebris_ID|$C0,obColType(a1)
.next:
		addq.l	#4,a2
		dbf	d6,.loop
		rts
Bomb_Debris:
		jsr	(SpeedToPos).l
		move.w	Bomb_speed(a0),d0
		add.w	d0,obVelY(a0)
		lea	Ani_BombDebris(pc),a1
		jsr	(AnimateSprite).l
		tst.b	obRender(a0)
		bpl.w	Bomb_BigRemove
		jmp	(DisplaySprite).l
Bomb_SmallSpeeds:
		dc.w -$200,-$300,-$100,-$200,$200,-$300,$100,-$200
Bomb_BigSpeeds:
		dc.w -$100,-$420,-$200,-$520,-$300,-$620
		dc.w $100,-$420,$200,-$520,$300,-$620,0,-$320

Bomb_Draw:
		out_of_range.s .origin
		bra.s	.sync
.origin:
		jsr	(Object_CheckSpawnXRange).l
		bhi.s	Bomb_Unload
.sync:
		move.b	obStatus(a0),d0
		andi.b	#3,d0
		andi.b	#$FC,obRender(a0)
		or.b	d0,obRender(a0)
		move.w	Bomb_child(a0),d0
		beq.s	.draw
		movea.w	d0,a1
		cmpi.l	#Bomb_Fuse,code(a1)
		bne.s	.draw
		move.w	a0,d0
		cmp.w	Bomb_parent(a1),d0
		bne.s	.draw
		movem.l	a0-a1,-(sp)
		movea.l	a1,a0
		bsr.w	Bomb_FusePose
		movem.l	(sp)+,a0-a1
.draw:
		jmp	(DisplaySprite).l
Bomb_Unload:
		bsr.w	Bomb_DeleteFuse
		jmp	(UnloadObject).l

; Range helpers return d0=1 and a1=the actual triggering actor, or d0=0.
; The charge variant checks each actor's own primary collision path.
Bomb_SmallRange:
		lea	(v_player).w,a1
		bsr.s	Bomb_SmallActor
		tst.w	d0
		bne.w	Bomb_RangeReturn
		lea	(v_player2).w,a1
Bomb_SmallActor:
		bsr.w	Bomb_ActorLive
		beq.s	.return
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		addi.w	#96,d0
		cmpi.w	#192,d0
		bhs.w	Bomb_NoActor
		move.w	obY(a1),d0
		sub.w	obY(a0),d0
		addi.w	#96,d0
		cmpi.w	#192,d0
		bhs.w	Bomb_NoActor
		moveq	#1,d0
.return:	rts
Bomb_BigRange:
		lea	(v_player).w,a1
		bsr.s	Bomb_BigActor
		tst.w	d0
		bne.w	Bomb_RangeReturn
		lea	(v_player2).w,a1
Bomb_BigActor:
		bsr.s	Bomb_ActorLive
		beq.s	.return
		cmpi.b	#2,obSubtype(a0)
		bne.s	.range
		cmpi.b	#$C,obTopSolidBit(a1)
		bne.w	Bomb_NoActor
.range:
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		addi.w	#96,d0
		cmpi.w	#192,d0
		bhs.w	Bomb_NoActor
		move.w	obY(a1),d0
		sub.w	obY(a0),d0
		btst	#1,obStatus(a0)
		beq.s	.upright
		neg.w	d0
.upright:
		addi.w	#160,d0
		cmpi.w	#240,d0
		bhs.w	Bomb_NoActor
		moveq	#1,d0
.return:	rts
Bomb_RangeReturn:
		rts
Bomb_ActorLive:
		tst.w	(Debug_placement_mode).w
		bne.w	Bomb_NoActor
		tst.l	code(a1)
		beq.w	Bomb_NoActor
		cmpi.b	#6,obRoutine(a1)
		bhs.w	Bomb_NoActor
		moveq	#1,d0
		rts
Bomb_NoActor:
		moveq	#0,d0
		rts

Ani_Bomb:
		dc.w .stand-Ani_Bomb,.walk-Ani_Bomb,.armed-Ani_Bomb,.fuse-Ani_Bomb
.stand:		dc.b 19,1,0,$FF
.walk:		dc.b 19,5,4,3,2,$FF
.armed:		dc.b 19,7,6,$FF
.fuse:		dc.b 3,8,9,$FF
		even
Ani_BigbomFuse:
		dc.w .fuse-Ani_BigbomFuse
.fuse:		dc.b 2,0,1,$FF
		even
Ani_BombDebris:
		dc.w .small-Ani_BombDebris,.big-Ani_BombDebris
.small:		dc.b 3,$A,$B,$FF
.big:		dc.b 1,0,1,$FF
		even
Map_SMZ_Bomb:
		binclude "mappings/sprite/SMZ Bomb.bin"
		even
Map_Bigbom:
		binclude "mappings/sprite/MMZ BigBom 1.bin"
		even
Map_BigbomFuse:
		binclude "mappings/sprite/MMZ BigBom 2.bin"
		even
Map_BigbomDebris:
		binclude "mappings/sprite/MMZ BigBom 3.bin"
		even
