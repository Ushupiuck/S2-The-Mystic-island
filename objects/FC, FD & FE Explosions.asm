; ---------------------------------------------------------------------------
; Object FC - explosion from a destroyed enemy or monitor
; ---------------------------------------------------------------------------

Explosion:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	ExItem_Index(pc,d0.w),d1
		jmp	ExItem_Index(pc,d1.w)
; ===========================================================================
ExItem_Index:	dc.w ExItem_Animal-ExItem_Index
		dc.w ExItem_Main-ExItem_Index
		dc.w ExItem_Animate-ExItem_Index
; ===========================================================================

ExItem_Animal:	; Routine 0
		addq.b	#2,obRoutine(a0)
		bsr.w	FindFreeObj
		bne.s	ExItem_Main
		move.l	#Flicky,code(a1) ; load animal object
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	enemy_combo(a0),enemy_combo(a1)	; Shared with Touch_KillEnemy & Animals for the chain hit bonus
		move.w	points_parent(a0),points_parent(a1)	; carry the attacking player's bank selection

ExItem_Main:	; Routine 2
		addq.b	#2,obRoutine(a0)
		move.w	#make_art_tile(ArtTile_Explosion,0,0),obGfx(a0)
		move.b	#7,obTimeFrame(a0)
ExItem_Setup:
		move.l	#Map_Explosion,obMap(a0)
		move.b	#Map_Explosion_height,height_pixels(a0)
		move.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		clr.b	obColType(a0)
		move.b	#sprite_bound($C,Map_Explosion_width),obActWid(a0)
		clr.b	obFrame(a0)
		move.w	#sfx_BreakItem,d0
		jsr	(PlaySound_Special).l	; play breaking enemy sound

ExItem_Animate:	; Routine 4 (2 for ExplosionBomb)
		subq.b	#1,obTimeFrame(a0) ; subtract 1 from frame duration
		bpl.s	.display
		move.b	#7,obTimeFrame(a0) ; set frame duration to 7 frames
		addq.b	#1,obFrame(a0)	; next frame
		cmpi.b	#5,obFrame(a0)	; is the final frame (05) displayed?
		beq.w	DeleteObject	; if yes, branch
.display:	bra.w	DisplaySprite
; ===========================================================================
; ---------------------------------------------------------------------------
; Object FD - explosion from a destroyed boss, bomb or cannonball
; ---------------------------------------------------------------------------

FieryExplosion:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	ExBom_Index(pc,d0.w),d1
		jmp	ExBom_Index(pc,d1.w)
; ===========================================================================
ExBom_Index:	dc.w ExBom_Main-ExBom_Index
		dc.w ExItem_Animate-ExBom_Index
; ===========================================================================

ExBom_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.l	#Map_FExplosion,obMap(a0)
		move.b	#Map_FExplosion_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_Explosion,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		clr.b	obColType(a0)
		move.b	#sprite_bound($C,Map_FExplosion_width),obActWid(a0)
		move.b	#7,obTimeFrame(a0)
		clr.b	obFrame(a0)
		move.w	#sfx_Bomb,d0
		jmp	(PlaySound_Special).l	; play exploding bomb sound
; ===========================================================================
; ---------------------------------------------------------------------------
; Object FE - BallHog's bomb explosion (From the Sonic 1 prototype)
; ---------------------------------------------------------------------------

GroundExplosion:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	MDis_Index(pc,d0.w),d1
		jmp	MDis_Index(pc,d1.w)
; ===========================================================================
MDis_Index:	dc.w MDis_Main-MDis_Index
		dc.w MDis_Animate-MDis_Index
; ===========================================================================

MDis_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.l	#Map_GExplosion,obMap(a0)
		move.b	#Map_GExplosion_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_Ground_Explosion,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		clr.b	obColType(a0)
		move.b	#sprite_bound($C,Map_GExplosion_width),obActWid(a0)
		move.b	#7,obTimeFrame(a0)
		clr.b	obFrame(a0)
		move.w	#sfx_Bomb,d0
		jsr	(PlaySound_Special).l		 ; play sound

MDis_Animate:	; Routine 2
		subq.b	#1,obTimeFrame(a0) ; subtract 1 from frame duration
		bpl.s	.display
		move.b	#7,obTimeFrame(a0) ; set frame duration to 9 frames
		addq.b	#1,obFrame(a0)	; next frame
		cmpi.b	#4,obFrame(a0)	; has animation completed?
		beq.w	DeleteObject	; if yes, branch
.display:	bra.w	DisplaySprite
; ===========================================================================
; ---------------------------------------------------------------------------
; Boss explosion controller, adapted from S3&K's Obj_CreateBossExplosion.
; Each boss keeps its defeat timer; a separate SST handles cadence and spread.
; Parent bosses reserve byte $4C as the controller-started flag. Repeated calls
; retry a full pool, then become no-ops after successful creation.
; ---------------------------------------------------------------------------
BossBurst_Started = objoff_4C	; parent only: byte
BossBurst_Count = objoff_2E	; controller: counter; large bursts use bit 7 = continuous
BossBurst_RangeX = objoff_2F	; byte: power-of-two half-width
BossBurst_RangeY = objoff_30	; byte: power-of-two half-height
BossBurst_ParentState = objoff_31	; byte: parent's exploding phase
BossBurst_Timer = objoff_32	; byte: burst countdown
BossBurst_ParentRoutine = objoff_33	; byte: parent's main routine
BossBurst_ParentCode = objoff_34	; long: expected parent code
BossBurst_Parent = objoff_38	; long: parent SST

BossExplosion_Start:	; a0 = boss, d0.w = parameter offset
		tst.b	BossBurst_Started(a0)
		bne.s	.return
		lea	BossExplosion_Parameters(pc,d0.w),a2
		jsr	(FindFreeObj).l
		bne.s	.return
		move.l	#BossExplosion_Controller,code(a1)
		bsr.s	BossExplosion_InitController
		move.b	#1,BossBurst_Started(a0)
.return:
		rts
; a0 = parent, a1 = allocated controller, a2 = four-byte parameters.
BossExplosion_InitController:
		move.l	(a2),BossBurst_Count(a1)
		move.b	obRoutine(a0),BossBurst_ParentRoutine(a1)
		move.l	code(a0),BossBurst_ParentCode(a1)
		move.l	a0,BossBurst_Parent(a1)
		rts
; ---------------------------------------------------------------------------
; Burst counter, X/Y half-ranges, parent phase. Both spreads are centered on the
; parent. Retain separate editable entries when bosses currently share a spread.
BossExplosion_Parameters:
BossExplosion_Parameters_GHZ:	dc.b $80,$20,$20,BGHZ_Explode
BossExplosion_Parameters_EHZ:	dc.b $80,$20,$20,6
BossExplosion_Parameters_WallLarge:	dc.b $80,$80,$80,0
BossExplosion_Parameters_WallSmall:	dc.b $80,$80,$80,0
BossExplosion_Parameters_End:
BossExplosion_GHZ = BossExplosion_Parameters_GHZ-BossExplosion_Parameters
BossExplosion_EHZ = BossExplosion_Parameters_EHZ-BossExplosion_Parameters
BossExplosion_WallLarge = BossExplosion_Parameters_WallLarge-BossExplosion_Parameters
BossExplosion_WallSmall = BossExplosion_Parameters_WallSmall-BossExplosion_Parameters
; ---------------------------------------------------------------------------

BossExplosion_Controller:
		moveq	#0,d3			; large: bit 7 of the count means continuous
		bra.s	BossExplosion_FollowParent
BossExplosion_NormalController:
		moveq	#1,d3			; ordinary: $80 counts down to 127 bursts
BossExplosion_FollowParent:
		movea.l	BossBurst_Parent(a0),a1
		move.l	code(a1),d0
		cmp.l	BossBurst_ParentCode(a0),d0
		bne.w	BossExplosion_Delete
		move.b	obRoutine(a1),d0
		cmp.b	BossBurst_ParentRoutine(a0),d0
		bne.w	BossExplosion_Delete
		move.b	ob2ndRout(a1),d0
		cmp.b	BossBurst_ParentState(a0),d0
		bne.w	BossExplosion_Delete
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		subq.b	#1,BossBurst_Timer(a0)
		bpl.s	.return
		tst.b	d3
		bne.s	.finite
		tst.b	BossBurst_Count(a0)
		bmi.s	.spawn
.finite:
		subq.b	#1,BossBurst_Count(a0)
		beq.w	BossExplosion_Delete
.spawn:
		move.b	#2,BossBurst_Timer(a0)
		jsr	(FindFreeObj).l
		bne.s	.return
		move.l	#BossExplosion,code(a1)
		tst.b	d3
		beq.s	.position
		move.l	#BossExplosion_Small,code(a1)
.position:
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		jsr	(RandomNumber).l
		moveq	#0,d1
		move.b	BossBurst_RangeX(a0),d1
		move.w	d1,d2
		add.w	d2,d2
		subq.w	#1,d2
		and.w	d2,d0
		sub.w	d1,d0
		add.w	d0,obX(a1)
		swap	d0			; independent Y bits, rather than another slice of X
		moveq	#0,d1
		move.b	BossBurst_RangeY(a0),d1
		move.w	d1,d2
		add.w	d2,d2
		subq.w	#1,d2
		and.w	d2,d0
		sub.w	d1,d0
		add.w	d0,obY(a1)
.return:
		rts
; ---------------------------------------------------------------------------
; DEZ3's advancing mixed explosion wall. Load plcid_ExplosionWall and let it
; finish before creating an SST with code = BossExplosion_Wall. No act starts
; it yet. The level owns the art lifetime; the normal bank replaces ship art.
; ---------------------------------------------------------------------------

BossExplosion_Wall:
		tst.b	obRoutine(a0)
		bne.w	.move
		; Reserve all four emitters before starting; full/fragmented pools retry.
		lea	(v_lvlobjspace).w,a1
		moveq	#BossExplosion_WallEmitterCount-1,d1
.find_slot:
		cmpa.w	#v_lvlobjend,a1
		bhs.s	.return
		tst.l	code(a1)
		bne.s	.next_slot
		dbf	d1,.next_slot
		bra.s	.ready
.next_slot:
		lea	object_size(a1),a1
		bra.s	.find_slot
.ready:
		move.b	#2,obRoutine(a0)
		move.w	(Camera_X_pos).w,d0
		subi.w	#$80,d0
		move.w	d0,obX(a0)
		move.w	(Camera_Y_pos).w,d0
		addi.w	#$80,d0
		move.w	d0,obY(a0)
		lea	BossExplosion_WallEmitters(pc),a3
		moveq	#BossExplosion_WallEmitterCount-1,d6
.make_emitter:
		move.w	(a3)+,d0
		lea	BossExplosion_Parameters(pc),a2
		adda.w	d0,a2
		jsr	(FindFreeObj).l
		move.l	(a3)+,code(a1)
		bsr.w	BossExplosion_InitController
		dbf	d6,.make_emitter
.return:
		rts
.move:
		addq.w	#2,obX(a0)
		move.w	obX(a0),d0
		sub.w	(Camera_X_pos).w,d0
		cmpi.w	#$80,d0
		ble.s	.return
		bra.w	BossExplosion_Delete	; emitters stop; existing visuals finish normally
; ---------------------------------------------------------------------------
; Parameter offset, controller. Original DEZ3 profiles $16/$18, twice each.
BossExplosion_WallEmitters:
		dc.w BossExplosion_WallLarge
		dc.l BossExplosion_Controller
		dc.w BossExplosion_WallLarge
		dc.l BossExplosion_Controller
		dc.w BossExplosion_WallSmall
		dc.l BossExplosion_NormalController
		dc.w BossExplosion_WallSmall
		dc.l BossExplosion_NormalController
BossExplosion_WallEmitters_End:
BossExplosion_WallEmitterCount = (BossExplosion_WallEmitters_End-BossExplosion_WallEmitters)/6
; ---------------------------------------------------------------------------
; Normal, animal-free wall burst. Shares the ordinary explosion initializer
; and animation; S3&K's short first frame and high-priority flag are retained.
BossExplosion_Small:
		tst.b	obRoutine(a0)
		bne.w	ExItem_Animate
		move.b	#2,obRoutine(a0)
		move.w	#make_art_tile(ArtTile_ExplosionWall_Small,0,1),obGfx(a0)
		move.b	#3,obTimeFrame(a0)
		bra.w	ExItem_Setup
; ---------------------------------------------------------------------------
; Shared S2 fiery art; ordinary bombs and enemy explosions keep theirs.
; Fit its seven frames into S3&K's 21-tick effect lifetime: 2,2,3,3,3,4,4.
; ---------------------------------------------------------------------------

BossExplosion:
		tst.b	obRoutine(a0)
		bne.s	.animate
		move.b	#2,obRoutine(a0)
		move.l	#Map_BossExplosion,obMap(a0)
		move.b	#Map_BossExplosion_height,height_pixels(a0)
		move.b	#Map_BossExplosion_width,width_pixels(a0)
		move.w	#make_art_tile(ArtTile_BossExplosion,0,1),obGfx(a0)
		move.b	#4,obRender(a0)
		clr.w	obPriority(a0)
		clr.b	obColType(a0)
		move.b	BossExplosion_Delays(pc),obTimeFrame(a0)
		clr.b	obFrame(a0)
		move.w	#SndID_BossExplosion,d0
		jsr	(PlaySound).l
		jmp	(DisplaySprite).l
.animate:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	.display
		addq.b	#1,obFrame(a0)
		moveq	#0,d0
		move.b	obFrame(a0),d0
		cmpi.w	#BossExplosion_Delays_End-BossExplosion_Delays,d0
		bhs.s	BossExplosion_Delete
		lea	BossExplosion_Delays(pc),a1
		move.b	(a1,d0.w),obTimeFrame(a0)
.display:
		jmp	(DisplaySprite).l

BossExplosion_Delete:
		jmp	(DeleteObject).l
; ---------------------------------------------------------------------------
BossExplosion_Delays:	dc.b 1,1,2,2,2,3,3
BossExplosion_Delays_End:
		even
		include "mappings/sprite/Boss Explosion.asm"
