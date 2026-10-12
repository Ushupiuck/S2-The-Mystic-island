; ---------------------------------------------------------------------------
; Object 0E - spindash and skid dust. Water splash remains object 08.
; Each player owns one controller and one 16-tile bank; skid particles share
; their owner's bank only while it still contains the four skid frames.
; ---------------------------------------------------------------------------
dust_loaded_frame = objoff_30
dust_emit_timer = objoff_32
dust_vram_address = objoff_3C
dust_controller = objoff_40
Dust_SkidBankFrame = 12
Dust_MinAir = 12
Dust_SkidInterval = 4
Dust_SkidYOffset = 16

; Called at player initialization; a full object pool simply omits the effect.
CreatePlayerDust:
		move.w	player_dust_ptr(a0),d0
		beq.s	.allocate
		cmpi.w	#v_lvlobjspace,d0
		blo.s	.allocate
		cmpi.w	#v_lvlobjend,d0
		bhs.s	.allocate
		btst	#0,d0
		bne.s	.allocate
		movea.w	d0,a1
		cmpi.b	#id_Obj0E,obID(a1)
		bne.s	.allocate
		cmpa.w	obParent(a1),a0
		beq.s	.return
.allocate:
		clr.w	player_dust_ptr(a0)
		jsr	(FindFreeObj).l
		bne.s	.return
		move.b	#id_Obj0E,obID(a1)
		move.w	a0,obParent(a1)
		move.w	a1,player_dust_ptr(a0)
.return:
		rts

SpindashDust:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	.index(pc,d0.w),d1
		jmp	.index(pc,d1.w)
.index:
		dc.w Dust_Init-.index
		dc.w Dust_Main-.index
		dc.w Dust_Particle-.index
		dc.w Dust_Delete-.index

Dust_Init:
		move.b	#2,obRoutine(a0)
		move.l	#Map_SpindashDust,obMap(a0)
		move.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		move.b	#32,obActWid(a0)
		move.b	#-1,dust_loaded_frame(a0)
		move.w	#make_art_tile(ArtTile_Sonic_Dust,0,0),obGfx(a0)
		move.w	#ArtTile_Sonic_Dust*tile_size,dust_vram_address(a0)
		cmpi.w	#v_player,obParent(a0)
		beq.s	Dust_Main
		move.w	#make_art_tile(ArtTile_Tails_Dust,0,0),obGfx(a0)
		move.w	#ArtTile_Tails_Dust*tile_size,dust_vram_address(a0)

Dust_Main:
		movea.w	obParent(a0),a2
		cmpi.b	#id_Obj01,obID(a2)
		beq.s	.owner
		cmpi.b	#id_Obj02,obID(a2)
		bne.w	Dust_Delete
.owner:
		cmpa.w	player_dust_ptr(a2),a0
		bne.w	Dust_Delete
		cmpi.b	#4,obRoutine(a2)
		bhs.w	.idle
		tst.w	(Debug_placement_mode).w
		bne.w	.idle
		btst	#status.player.in_air,obStatus(a2)
		bne.w	.idle
		cmpi.b	#AniIDSonAni_Spindash,obAnim(a2)
		bne.s	.checkskid
		cmpi.b	#1,spindash_flag(a2)
		bne.w	.idle
		bsr.w	Dust_CheckAir
		blo.w	.idle
		cmpi.b	#1,obAnim(a0)
		beq.s	.follow
		move.b	#1,obAnim(a0)
		move.b	#-1,obPrevAni(a0)
.follow:
		move.w	obX(a2),obX(a0)
		move.w	obY(a2),obY(a0)
		cmpi.b	#id_Obj02,obID(a2)
		bne.s	.orientation
		subq.w	#sonic_height-tails_height,obY(a0)
.orientation:
		move.b	obStatus(a2),d0
		andi.b	#1,d0
		move.b	d0,obStatus(a0)
		bsr.w	Dust_CopyPriority
		lea	(Ani_SpindashDust).l,a1
		jsr	(AnimateSprite).l
		bsr.w	Dust_LoadArt
		bcs.s	.return
		jmp	(DisplaySprite).l
.checkskid:
		cmpi.b	#AniIDSonAni_Stop,obAnim(a2)
		beq.s	.skid
.idle:
		clr.b	obAnim(a0)
		clr.b	dust_emit_timer(a0)
.return:
		rts
.skid:
		btst	#status.player.underwater,obStatus(a2)
		bne.w	.idle
		bsr.w	Dust_CheckAir
		blo.w	.idle
		move.b	#Dust_SkidBankFrame,obFrame(a0)
		bsr.w	Dust_LoadArt
		bcs.s	.return
		subq.b	#1,dust_emit_timer(a0)
		bpl.s	.return
		move.b	#Dust_SkidInterval-1,dust_emit_timer(a0)
		jsr	(FindFreeObj).l
		bne.s	.return
		movea.w	obParent(a0),a2
		move.b	#id_Obj0E,obID(a1)
		move.b	#4,obRoutine(a1)
		move.w	a0,dust_controller(a1)
		move.w	obX(a2),obX(a1)
		move.w	obY(a2),obY(a1)
		addi.w	#Dust_SkidYOffset,obY(a1)
		cmpi.b	#id_Obj02,obID(a2)
		bne.s	.particle
		subq.w	#sonic_height-tails_height,obY(a1)
.particle:
		move.l	obMap(a0),obMap(a1)
		move.b	#4,obRender(a1)
		move.w	#$80,obPriority(a1)
		move.b	#8,obActWid(a1)
		move.b	#2,obAnim(a1)
		move.w	obGfx(a0),obGfx(a1)
		andi.w	#drawing_mask,obGfx(a1)
		tst.w	obGfx(a2)
		bpl.w	.return
		ori.w	#high_priority,obGfx(a1)
		rts

Dust_Particle:
		movea.w	dust_controller(a0),a1
		cmpi.b	#id_Obj0E,obID(a1)
		bne.s	.delete
		cmpi.b	#Dust_SkidBankFrame,dust_loaded_frame(a1)
		bne.s	.delete
		movea.w	obParent(a1),a2
		cmpi.b	#id_Obj01,obID(a2)
		beq.s	.owner
		cmpi.b	#id_Obj02,obID(a2)
		bne.s	.delete
.owner:
		cmpa.w	player_dust_ptr(a2),a1
		bne.s	.delete
		cmpi.b	#4,obRoutine(a2)
		bhs.s	.delete
		; Check the owner's mode too: a particle may execute before its
		; controller after a freed earlier SST has been reused.
		cmpi.b	#AniIDSonAni_Spindash,obAnim(a2)
		beq.s	.delete
		lea	(Ani_SpindashDust).l,a1
		jsr	(AnimateSprite).l
		cmpi.b	#6,obRoutine(a0)
		beq.s	.delete
		jmp	(DisplaySprite).l
.delete:
		jmp	(DeleteObject).l

Dust_Delete:
		movea.w	obParent(a0),a2
		cmpi.b	#id_Obj01,obID(a2)
		beq.s	.owner
		cmpi.b	#id_Obj02,obID(a2)
		bne.s	Dust_Particle.delete
.owner:
		cmpa.w	player_dust_ptr(a2),a0
		bne.s	Dust_Particle.delete
		clr.w	player_dust_ptr(a2)
		bra.s	Dust_Particle.delete

Dust_CheckAir:
		cmpi.b	#id_Obj02,obID(a2)
		bne.s	.primary
		cmpi.b	#Dust_MinAir,air_left(a2)
		rts
.primary:
		cmpi.w	#Dust_MinAir,(v_air).w
		rts

Dust_CopyPriority:
		andi.w	#drawing_mask,obGfx(a0)
		tst.w	obGfx(a2)
		bpl.s	.return
		ori.w	#high_priority,obGfx(a0)
.return:
		rts

Dust_LoadArt:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		lea	(DPLC_SpindashDust).l,a2
		lea	dust_loaded_frame(a0),a3
		move.w	dust_vram_address(a0),d4
		move.l	#Art_SpindashDust,d6
		bra.w	Load_DynamicPLC

Ani_SpindashDust:
		dc.w .idle-Ani_SpindashDust
		dc.w .charge-Ani_SpindashDust
		dc.w .skid-Ani_SpindashDust
.idle:
		dc.b $1F,0,afEnd
.charge:
		dc.b 1,1,2,3,4,5,6,7,afEnd
.skid:
		dc.b 3,8,9,10,11,afRoutine
		even

Map_SpindashDust:
		include "mappings/sprite/Spindash Dust.asm"
DPLC_SpindashDust:
		include "mappings/spriteDPLC/Spindash Dust.asm"
