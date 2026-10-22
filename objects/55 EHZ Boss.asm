; ---------------------------------------------------------------------------
; EHZ boss from Sonic 2 final (s2disasm 15e9fd52a65318bec3d5e746ce48dba6db6910db).
; One boss ID, eight object slots: ship bottom/top, car, three wheels, drill
; and propeller. Children use ordinary S3&K mappings, not packed composites.
; Stage/placement X,Y specify the landing anchor; origin deltas preserve the
; final choreography when this boss is used as the existing MZ placeholder.
; Display half-height uses height_pixels; collision radii are separate.
; ---------------------------------------------------------------------------
EHZBoss_flash_color = objoff_36	; original hit-flash color; unused word before child pointer
EHZBoss_origin_x = objoff_44
EHZBoss_origin_y = objoff_46
EHZBoss_LandingX = $29D0
EHZBoss_LandingY = $41E
EHZBoss_ApproachX = EHZBoss_LandingX+$120
EHZBoss_ApproachY = EHZBoss_LandingY-$126
EHZBoss_LeftTurn = $28A0
EHZBoss_RightTurn = $2B08
EHZBoss_CameraLeft = $28F0
EHZBoss_CameraFightRight = $2940
EHZBoss_CameraY = $390
EHZBoss_CameraExitRight = $2AB0

Obj55:
EHZBoss:
	moveq	#0,d0
	move.b	obRoutine(a0),d0
	move.w	EHZBoss_Index(pc,d0.w),d1
	jmp	EHZBoss_Index(pc,d1.w)
; ===========================================================================
; EHZBoss_off_2EF26:
EHZBoss_Index:	offsetTable
		offsetTableEntry.w EHZBoss_Init	; 0 - Init
		offsetTableEntry.w EHZBoss_VehicleMain	; 2 - Flying vehicle, bottom = main object
		offsetTableEntry.w EHZBoss_Propeller	; 4 - Propeller normal
		offsetTableEntry.w EHZBoss_GroundVehicle	; 6 - Vehicle on ground
		offsetTableEntry.w EHZBoss_Wheel	; 8 - Wheels
		offsetTableEntry.w EHZBoss_Drill	; A - Spike
		offsetTableEntry.w EHZBoss_PropellerReloaded	; C - Propeller after defeat
		offsetTableEntry.w EHZBoss_Cockpit	; E - Flying vehicle, top
; ===========================================================================

; #status.npc.no_balancing,status(ax) set via collision response routine (Touch_Enemy_Part2)
; when after a hit collision_property(ax) = hitcount has reached zero
; objoff_2E(ax)		used as timer (countdown)
; objoff_30(ax)		tertiary routine counter
; #0,objoff_31(ax)	set when Robotnik is on ground
; #1,objoff_31(ax)	set when Robotnik is active (moving back & forth)
; #2,objoff_31(ax)	set when Robotnik is flying off after being defeated
; #3,objoff_31(ax)	flag to separate spike from vehicle
; objoff_32(ax)		y_position of wheels
; objoff_38(ax)		parent object
; objoff_40(ax)		timer after defeat

; EHZBoss_loc_2EF36:
EHZBoss_Init:

	; All seven children are required, including both height-sampling wheels.
	; Retry initialization rather than creating a half boss under slot pressure.
	lea	object_size(a0),a1
	moveq	#7-1,d1
.free_slot:
	cmpa.w	#v_lvlobjend,a1
	bhs.w	EHZBoss_Return
	tst.l	code(a1)
	bne.s	.next_slot
	dbf	d1,.next_slot
	bra.s	.slots_ready
.next_slot:
	lea	object_size(a1),a1
	bra.s	.free_slot
.slots_ready:
	move.w	obX(a0),EHZBoss_origin_x(a0)
	subi.w	#EHZBoss_LandingX,EHZBoss_origin_x(a0)
	move.w	obY(a0),EHZBoss_origin_y(a0)
	subi.w	#EHZBoss_LandingY+8,EHZBoss_origin_y(a0)
	move.l	#Map_EHZBoss_Vehicle,obMap(a0)	; main object
	move.b	#Map_EHZBoss_Vehicle_height,height_pixels(a0)
	move.w	#make_art_tile(ArtTile_ArtNem_Eggpod_1,1,0),obGfx(a0) ; vehicle with ability to fly, bottom part
	ori.b	#1<<obRender.level_fg,obRender(a0)
	move.b	#$81,obSubtype(a0)
	move.w	EHZBoss_origin_x(a0),d0
	addi.w	#EHZBoss_LandingX,d0
	move.w	d0,obX(a0)
	move.w	EHZBoss_origin_y(a0),d0
	addi.w	#EHZBoss_LandingY+8,d0
	move.w	d0,obY(a0)
	move.b	#sprite_bound($20,Map_EHZBoss_Vehicle_width),width_pixels(a0)
	move.b	#$14,obHeight(a0)
	move.w	#$200,obPriority(a0)
	move.b	#$F,obColType(a0)
	move.b	#8,obColProp(a0)	; hitcount
	addq.b	#2,obRoutine(a0)
	move.w	obX(a0),objoff_34(a0)
	move.w	obY(a0),objoff_3C(a0)
	jsr	(FindNextFreeObj).l	; vehicle with ability to fly, top part
	bne.w	+

	move.l	#EHZBoss,code(a1) ; load EHZ boss child
	move.l	a0,objoff_38(a1)	; link top and bottom to each other
	move.w	EHZBoss_origin_x(a0),EHZBoss_origin_x(a1)
	move.w	EHZBoss_origin_y(a0),EHZBoss_origin_y(a1)
	move.l	a1,objoff_38(a0)	; i.e. addresses for cross references
	move.l	#Map_EHZBoss_Vehicle,obMap(a1)
	move.b	#Map_EHZBoss_Vehicle_height,height_pixels(a1)
	move.w	#make_art_tile(ArtTile_ArtNem_Eggpod_1,0,0),obGfx(a1)
	move.b	#1<<obRender.level_fg,obRender(a1)
	move.b	#sprite_bound($20,Map_EHZBoss_Vehicle_width),width_pixels(a1)
	move.w	#$200,obPriority(a1)
	move.l	obX(a0),obX(a1)
	move.l	obY(a0),obY(a1)
	move.b	#$E,obRoutine(a1)
	move.b	#1,obAnim(a1)	; normal animation
	move.b	obRender(a0),obRender(a1)
+
	jsr	(FindNextFreeObj).l	; Vehicle on ground
	bne.w	+

	move.l	#EHZBoss,code(a1) ; load EHZ boss child
	move.l	a0,objoff_38(a1)	; linked to main object
	move.w	EHZBoss_origin_x(a0),EHZBoss_origin_x(a1)
	move.w	EHZBoss_origin_y(a0),EHZBoss_origin_y(a1)
	move.l	#Map_EHZBoss_Ground,obMap(a1)
	move.b	#Map_EHZBoss_Ground_height,height_pixels(a1)
	move.w	#make_art_tile(ArtTile_ArtNem_EHZBoss,0,0),obGfx(a1)
	move.b	#1<<obRender.level_fg,obRender(a1)
	move.b	#sprite_bound($30,Map_EHZBoss_Ground_width),width_pixels(a1)
	move.b	#$10,obHeight(a1)
	move.w	#$180,obPriority(a1)
	move.w	EHZBoss_origin_x(a1),d0
	addi.w	#EHZBoss_ApproachX,d0
	move.w	d0,obX(a1)
	move.l	obY(a0),obY(a1)
	move.b	#6,obRoutine(a1)
+
	bsr.w	EHZBoss_MakeGroundParts
	subq.w	#8,objoff_3C(a0)
	move.w	EHZBoss_origin_x(a0),d0
	addi.w	#EHZBoss_ApproachX,d0
	move.w	d0,obX(a0)
	move.w	EHZBoss_origin_y(a0),d0
	addi.w	#EHZBoss_ApproachY,d0
	move.w	d0,obY(a0)
	jsr	(FindNextFreeObj).l	; propeller normal
	bne.w	+	; rts

	move.l	#EHZBoss,code(a1) ; load EHZ boss child
	move.l	a0,objoff_38(a1)	; linked to main object
	move.w	EHZBoss_origin_x(a0),EHZBoss_origin_x(a1)
	move.w	EHZBoss_origin_y(a0),EHZBoss_origin_y(a1)
	move.l	#Map_EHZBoss_Propeller,obMap(a1)
	move.b	#Map_EHZBoss_Propeller_height,height_pixels(a1)
	move.w	#make_art_tile(ArtTile_ArtNem_EggChoppers,1,0),obGfx(a1)
	move.b	#1<<obRender.level_fg,obRender(a1)
	move.b	#sprite_bound($40,Map_EHZBoss_Propeller_width),width_pixels(a1)
	move.w	#$180,obPriority(a1)
	move.l	obX(a0),obX(a1)
	move.l	obY(a0),obY(a1)
	move.w	#$1E,objoff_2E(a1)
	move.b	#4,obRoutine(a1)
+
	rts
; ---------------------------------------------------------------------------

EHZBoss_MakeGroundParts:
	jsr	(FindNextFreeObj).l	; first foreground wheel
	bne.w	+

	move.l	#EHZBoss,code(a1) ; load EHZ boss child
	move.l	a0,objoff_38(a1)	; linked to main object
	move.w	EHZBoss_origin_x(a0),EHZBoss_origin_x(a1)
	move.w	EHZBoss_origin_y(a0),EHZBoss_origin_y(a1)
	move.l	#Map_EHZBoss_Ground,obMap(a1)
	move.b	#Map_EHZBoss_Ground_height,height_pixels(a1)
	move.w	#make_art_tile(ArtTile_ArtNem_EHZBoss,1,0),obGfx(a1)
	move.b	#1<<obRender.level_fg,obRender(a1)
	move.b	#sprite_bound($10,Map_EHZBoss_Ground_width),width_pixels(a1)
	move.w	#$100,obPriority(a1)
	move.b	#$10,obHeight(a1)
	move.b	#$10,obWidth(a1)
	move.w	EHZBoss_origin_x(a1),d0
	addi.w	#EHZBoss_ApproachX,d0
	move.w	d0,obX(a1)
	move.l	obY(a0),obY(a1)
	addi.w	#$1C,obX(a1)
	addi.w	#$C,obY(a1)
	move.b	#8,obRoutine(a1)
	move.b	#4,obFrame(a1)
	move.b	#1,obAnim(a1)
	move.w	#$A,objoff_2E(a1)
	move.b	#0,obSubtype(a1)
+
	jsr	(FindNextFreeObj).l	; second foreground wheel
	bne.w	+

	move.l	#EHZBoss,code(a1) ; load EHZ boss child
	move.l	a0,objoff_38(a1)	; linked to main object
	move.w	EHZBoss_origin_x(a0),EHZBoss_origin_x(a1)
	move.w	EHZBoss_origin_y(a0),EHZBoss_origin_y(a1)
	move.l	#Map_EHZBoss_Ground,obMap(a1)
	move.b	#Map_EHZBoss_Ground_height,height_pixels(a1)
	move.w	#make_art_tile(ArtTile_ArtNem_EHZBoss,1,0),obGfx(a1)
	move.b	#1<<obRender.level_fg,obRender(a1)
	move.b	#sprite_bound($10,Map_EHZBoss_Ground_width),width_pixels(a1)
	move.w	#$100,obPriority(a1)
	move.b	#$10,obHeight(a1)
	move.b	#$10,obWidth(a1)
	move.w	EHZBoss_origin_x(a1),d0
	addi.w	#EHZBoss_ApproachX,d0
	move.w	d0,obX(a1)
	move.l	obY(a0),obY(a1)
	addi.w	#-$C,obX(a1)
	addi.w	#$C,obY(a1)
	move.b	#8,obRoutine(a1)
	move.b	#4,obFrame(a1)
	move.b	#1,obAnim(a1)
	move.w	#$A,objoff_2E(a1)
	move.b	#1,obSubtype(a1)
+
	jsr	(FindNextFreeObj).l	; background wheel
	bne.w	+

	move.l	#EHZBoss,code(a1) ; load EHZ boss child
	move.l	a0,objoff_38(a1)	; linked to main object
	move.w	EHZBoss_origin_x(a0),EHZBoss_origin_x(a1)
	move.w	EHZBoss_origin_y(a0),EHZBoss_origin_y(a1)
	move.l	#Map_EHZBoss_Ground,obMap(a1)
	move.b	#Map_EHZBoss_Ground_height,height_pixels(a1)
	move.w	#make_art_tile(ArtTile_ArtNem_EHZBoss,1,0),obGfx(a1)
	move.b	#1<<obRender.level_fg,obRender(a1)
	move.b	#sprite_bound($10,Map_EHZBoss_Ground_width),width_pixels(a1)
	move.w	#$180,obPriority(a1)
	move.b	#$10,obHeight(a1)
	move.b	#$10,obWidth(a1)
	move.w	EHZBoss_origin_x(a1),d0
	addi.w	#EHZBoss_ApproachX,d0
	move.w	d0,obX(a1)
	move.l	obY(a0),obY(a1)
	addi.w	#-$2C,obX(a1)
	addi.w	#$C,obY(a1)
	move.b	#8,obRoutine(a1)
	move.b	#6,obFrame(a1)
	move.b	#2,obAnim(a1)
	move.w	#$A,objoff_2E(a1)
	move.b	#2,obSubtype(a1)
+
	jsr	(FindNextFreeObj).l	; Spike
	bne.w	+

	move.l	#EHZBoss,code(a1) ; load EHZ boss child
	move.l	a0,objoff_38(a1)	; linked to main object
	move.w	EHZBoss_origin_x(a0),EHZBoss_origin_x(a1)
	move.w	EHZBoss_origin_y(a0),EHZBoss_origin_y(a1)
	move.l	#Map_EHZBoss_Ground,obMap(a1)
	move.b	#Map_EHZBoss_Ground_height,height_pixels(a1)
	move.w	#make_art_tile(ArtTile_ArtNem_EHZBoss,1,0),obGfx(a1)
	move.b	#1<<obRender.level_fg,obRender(a1)
	move.b	#sprite_bound($20,Map_EHZBoss_Ground_width),width_pixels(a1)
	move.w	#$100,obPriority(a1)
	move.w	EHZBoss_origin_x(a1),d0
	addi.w	#EHZBoss_ApproachX,d0
	move.w	d0,obX(a1)
	move.l	obY(a0),obY(a1)
	addi.w	#-$36,obX(a1)
	addq.w	#8,obY(a1)
	move.b	#$A,obRoutine(a1)
	move.b	#1,obFrame(a1)
	move.b	#0,obAnim(a1)
+
	rts
; ===========================================================================

EHZBoss_VehicleMain:	; EHZBoss_VehicleMain:
	moveq	#0,d0
	move.b	ob2ndRout(a0),d0
	move.w	EHZBoss_off_2F270(pc,d0.w),d1
	jmp	EHZBoss_off_2F270(pc,d1.w)
; ---------------------------------------------------------------------------
EHZBoss_off_2F270:	offsetTable
		offsetTableEntry.w EHZBoss_Approach	; 0 - approaching diagonally
		offsetTableEntry.w EHZBoss_Landing	; 2 - final approaching stage (vertically/waiting)
		offsetTableEntry.w EHZBoss_Drive	; 4 - moving back and forth
		offsetTableEntry.w EHZBoss_FallDefeated	; 6 - boss defeated, falling/lying on ground
		offsetTableEntry.w EHZBoss_PauseDefeated	; 8 - boss idle for $C frames
		offsetTableEntry.w EHZBoss_Escape	; A - flying off, moving camera
; ===========================================================================

EHZBoss_Approach:	; EHZBoss_VehicleMain_Sub0:
	move.b	#0,obColType(a0)
	move.w	obX(a0),d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_LandingX,d0
	ble.s	EHZBoss_loc_2F29A
	subq.w	#1,obX(a0)
	addq.w	#1,obY(a0)	; move diagonally down
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F29A:
	move.w	EHZBoss_origin_x(a0),d0
	addi.w	#EHZBoss_LandingX,d0
	move.w	d0,obX(a0)
	addq.b	#2,ob2ndRout(a0)	; next routine
	jmp	(DisplaySprite).l
; ===========================================================================

EHZBoss_Landing:	; EHZBoss_VehicleMain_Sub2:
	moveq	#0,d0
	move.b	objoff_30(a0),d0	; tertiary routine
	move.w	EHZBoss_off_2F2B6(pc,d0.w),d1
	jmp	EHZBoss_off_2F2B6(pc,d1.w)
; ---------------------------------------------------------------------------
EHZBoss_off_2F2B6:	offsetTable
		offsetTableEntry.w EHZBoss_LandVertical	; 0 - moving down to ground vehicle vertically
		offsetTableEntry.w EHZBoss_WaitActivation	; 2 - not moving, delay until activation
; ---------------------------------------------------------------------------

EHZBoss_LandVertical:	; EHZBoss_VehicleMain_Sub2_0:
	move.w	obY(a0),d0
	sub.w	EHZBoss_origin_y(a0),d0
	cmpi.w	#EHZBoss_LandingY,d0
	bge.s	EHZBoss_loc_2F2CC
	addq.w	#1,obY(a0)	; move vertically (down)
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F2CC:
	addq.b	#2,objoff_30(a0)	; tertiary routine
	bset	#0,objoff_31(a0)	; Robotnik on ground (relevant for propeller)
	move.w	#60,objoff_2E(a0)	; timer for standing still
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_WaitActivation:	; EHZBoss_VehicleMain_Sub2_2:
	subq.w	#1,objoff_2E(a0)	; timer
	bpl.w	EHZBoss_Display
	move.w	#-$200,obVelX(a0)
	addq.b	#2,ob2ndRout(a0)
	move.b	#$F,obColType(a0)
	bset	#1,objoff_31(a0)	; boss now active and moving
	jmp	(DisplaySprite).l
; ===========================================================================

EHZBoss_Drive:	; EHZBoss_VehicleMain_Sub4:
	bsr.w	EHZBoss_CheckHits	; routine to handle hits
	bsr.w	EHZBoss_CheckDirection	; position check, sets direction
	move.w	objoff_32(a0),d0	; y_position of wheels
	lsr.w	#1,d0
	subi.w	#$14,d0
	move.w	d0,obY(a0)	; set y_pos depending on wheels
	move.w	#0,objoff_32(a0)
	move.l	obX(a0),d2
	move.w	obVelX(a0),d0
	ext.l	d0
	asl.l	#8,d0
	add.l	d0,d2
	move.l	d2,obX(a0)	; set x_pos depening on velocity
	jmp	(DisplaySprite).l
; ===========================================================================

EHZBoss_FallDefeated:	; EHZBoss_VehicleMain_Sub6:
	subq.w	#1,objoff_40(a0)	; timer set after defeat
	bmi.s	EHZBoss_loc_2F35C	; if countdown finished
	moveq	#BossExplosion_EHZ,d0
	jsr	(BossExplosion_Start).l
	jsr	(ObjectMoveAndFall).l
	jsr	(ObjHitFloor).l
	tst.w	d1
	bpl.w	EHZBoss_Display
	add.w	d1,obY(a0)
	move.w	#0,obVelY(a0)	; set to ground and stand still
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F35C:
	clr.w	obVelX(a0)
	addq.b	#2,ob2ndRout(a0)
	move.w	#-$26,objoff_40(a0)
	move.w	#$C,objoff_2E(a0)
	jmp	(DisplaySprite).l
; ===========================================================================

EHZBoss_PauseDefeated:	; EHZBoss_VehicleMain_Sub8:
	subq.w	#1,objoff_2E(a0)	; timer
	bpl.w	EHZBoss_Display
	addq.b	#2,ob2ndRout(a0)
	move.b	#0,objoff_30(a0)	; tertiary routine
	jmp	(DisplaySprite).l
; ===========================================================================

EHZBoss_Escape:	; EHZBoss_VehicleMain_SubA:
	moveq	#0,d0
	move.b	objoff_30(a0),d0	; tertiary routine
	move.w	EHZBoss_off_2F39C(pc,d0.w),d1
	jsr	EHZBoss_off_2F39C(pc,d1.w)
	jmp	(DisplaySprite).l
; ===========================================================================
EHZBoss_off_2F39C:	offsetTable
		offsetTableEntry.w EHZBoss_ReloadPropeller	; 0 - initialize propellor
		offsetTableEntry.w EHZBoss_WaitPropeller	; 2 - waiting
		offsetTableEntry.w EHZBoss_FlyAway	; 4 - flying off
; ===========================================================================

EHZBoss_ReloadPropeller:	; EHZBoss_VehicleMain_SubA_0:
	bclr	#0,objoff_31(a0)	; Robotnik off ground
	jsr	(FindNextFreeObj).l	; reload propeller after defeat
	bne.w	+	; rts

	move.l	#EHZBoss,code(a1) ; load EHZ boss child
	move.l	a0,objoff_38(a1)	; linked to main object
	move.w	EHZBoss_origin_x(a0),EHZBoss_origin_x(a1)
	move.w	EHZBoss_origin_y(a0),EHZBoss_origin_y(a1)
	move.l	#Map_EHZBoss_Propeller,obMap(a1)
	move.b	#Map_EHZBoss_Propeller_height,height_pixels(a1)
	move.w	#make_art_tile(ArtTile_ArtNem_EggChoppers,1,0),obGfx(a1)
	move.b	#1<<obRender.level_fg,obRender(a1)
	move.b	#sprite_bound($20,Map_EHZBoss_Propeller_width),width_pixels(a1)
	move.w	#$180,obPriority(a1)
	move.l	obX(a0),obX(a1)
	move.l	obY(a0),obY(a1)
	addi.w	#$C,obY(a1)
	move.b	obStatus(a0),obStatus(a1)
	move.b	obRender(a0),obRender(a1)
	move.b	#$C,obRoutine(a1)
	move.b	#2,obAnim(a1)
	move.w	#$10,objoff_2E(a1)	; timer
	move.w	#$32,objoff_2E(a0)	; timer
	addq.b	#2,objoff_30(a0)	; tertiary routine - increase
	jsr	(EHZBoss_PlayLevelMusic).l ; play level Music
	move.b	#1,(Boss_defeated_flag).w
+
	rts
; ===========================================================================

EHZBoss_WaitPropeller:	; EHZBoss_VehicleMain_SubA_2:
	subq.w	#1,objoff_2E(a0)	; timer
	bpl.s	+	; rts
	bset	#2,objoff_31(a0)	; Robotnik flying off
	move.w	#$60,objoff_2E(a0)	; timer
	addq.b	#2,objoff_30(a0)	; tertiary routine
	jsr	(EHZBoss_RestoreLevelArt).l ; PLC_Explosion
+
	rts
; ===========================================================================

EHZBoss_FlyAway:	; EHZBoss_VehicleMain_SubA_4:
	subq.w	#1,objoff_2E(a0)	; timer
	bpl.s	EHZBoss_loc_2F45C
	bset	#status.npc.x_flip,obStatus(a0)
	bset	#obRender.x_flip,obRender(a0)
	addq.w	#6,obX(a0)
	bra.s	EHZBoss_loc_2F460
; ===========================================================================

EHZBoss_loc_2F45C:
	subq.w	#1,obY(a0)

EHZBoss_loc_2F460:
	move.w	(Camera_Max_X_pos).w,d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_CameraExitRight,d0
	bhs.s	EHZBoss_loc_2F46E
	addq.w	#2,(Camera_Max_X_pos).w
	move.w	(Camera_Max_X_pos).w,(Tails_Max_X_pos).w
	bra.s	EHZBoss_return_2F482
; ===========================================================================

EHZBoss_loc_2F46E:
	btst	#obRender.on_screen,obRender(a0)
	bne.s	EHZBoss_return_2F482
	addq.w	#4,sp
	movea.l	objoff_38(a0),a1 ; parent address (vehicle)
	jsr	(DeleteObject2).l
	jmp	(DeleteObject).l
; ===========================================================================

EHZBoss_return_2F482:
	rts
; ===========================================================================

EHZBoss_CheckDirection:	; shared routine, checks positions and sets direction
	move.w	obX(a0),d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_LeftTurn,d0	; beyond left boundary?
	ble.s	EHZBoss_loc_2F494
	cmpi.w	#EHZBoss_RightTurn,d0
	blt.s	EHZBoss_return_2F4A4	; beyond right boundary?

EHZBoss_loc_2F494:	; beyond boundary
	bchg	#status.npc.x_flip,obStatus(a0)	; change direction
	bchg	#obRender.x_flip,obRender(a0)	; mirror sprite
	neg.w	obVelX(a0)	; change direction of velocity

EHZBoss_return_2F4A4:
	rts
; ===========================================================================

EHZBoss_CheckHits:	; routine to handle hits
	cmpi.b	#6,ob2ndRout(a0)	; is only called when value is 4?
	bhs.s	EHZBoss_return_2F4EC	; thus unnecessary? (return if greater or equal than 6)
	btst	#status.npc.no_balancing,obStatus(a0)
	bne.s	EHZBoss_Defeated	; Sonic has just defeated the boss (i.e. bit 7 set)
	tst.b	obColType(a0)	; set to 0 when boss was hit by Touch_Enemy_Part2
	bne.s	EHZBoss_return_2F4EC	; not 0, i.e. boss not hit
	tst.b	objoff_42(a0)
	bne.s	EHZBoss_loc_2F4D0	; boss already invincibile
	move.w	(v_palette+$22).w,EHZBoss_flash_color(a0)
	move.b	#$20,objoff_42(a0)	; boss invincibility timer
	move.w	#sfx_HitBoss,d0
	jsr	(PlaySound).l	; play boss hit sound

EHZBoss_loc_2F4D0:
	lea	(v_palette+$20+2).w,a1
	move.w	EHZBoss_flash_color(a0),d0
	btst	#0,objoff_42(a0)
	bne.s	EHZBoss_loc_2F4DE	; odd frames restore the original shade
	move.w	#$EEE,d0	; even frames flash white; final frame restores

EHZBoss_loc_2F4DE:
	move.w	d0,(a1)	; set respective color
	subq.b	#1,objoff_42(a0)	; decrease boss invincibility timer
	bne.s	EHZBoss_return_2F4EC
	move.b	#$F,obColType(a0)	; if invincibility ended, allow collision again

EHZBoss_return_2F4EC:
	rts
; ===========================================================================

EHZBoss_Defeated:	; boss defeated
	moveq	#100,d0
	jsr	(AddPoints).l	; add 1000 points, reward for defeating boss
	move.b	#6,ob2ndRout(a0)
	move.w	#0,obVelX(a0)
	move.w	#-$180,obVelY(a0)
	move.w	#$B3,objoff_40(a0)	; timer
	bset	#3,objoff_31(a0)	; flag to separate spike from vehicle
	movea.l	objoff_38(a0),a1 ; address top part
	move.b	#4,obAnim(a1)	; flying off animation
	move.b	#6,obFrame(a1)
	moveq	#plcid_Capsule,d0
	jmp	(LoadPLC).l	; load egg prison
; ===========================================================================

EHZBoss_PropellerReloaded:	; Propeller after defeat
	subq.w	#1,obY(a0)	; move up
	subq.w	#1,objoff_2E(a0)	; decrease timer
	bpl.w	EHZBoss_Display
	move.b	#4,obRoutine(a0)	; Propeller normal
	lea	(Ani_EHZBoss_Propeller).l,a1
	jsr	(AnimateSprite).l
	jmp	(DisplaySprite).l
; ===========================================================================

EHZBoss_Propeller:	; EHZBoss_Propeller:	; Propeller normal
	moveq	#0,d0
	move.b	ob2ndRout(a0),d0
	move.w	EHZBoss_off_2F55C(pc,d0.w),d1
	jmp	EHZBoss_off_2F55C(pc,d1.w)
; ---------------------------------------------------------------------------
EHZBoss_off_2F55C:	offsetTable
		offsetTableEntry.w EHZBoss_loc_2F560	; 0 - Robotnik in air
		offsetTableEntry.w EHZBoss_loc_2F5C6	; 2 - Robotnik on ground
; ---------------------------------------------------------------------------

EHZBoss_loc_2F560:	; EHZBoss_Propeller_Sub0
	movea.l	objoff_38(a0),a1 ; parent address (vehicle)
	cmpi.l	#EHZBoss,code(a1)
	bne.w	EHZBoss_Delete	; if boss non-existant
	btst	#0,objoff_31(a1)	; is Robotnik on ground?
	beq.s	EHZBoss_loc_2F58E	; if not, branch
	move.b	#1,obAnim(a0)
	move.w	#$18,objoff_2E(a0)	; timer until deletion
	addq.b	#2,ob2ndRout(a0)
	move.b	#MusID_StopSFX,d0
	jsr	(PlaySound).l
	bra.s	EHZBoss_loc_2F5A0
; ---------------------------------------------------------------------------

EHZBoss_loc_2F58E:	; not on ground
	move.b	(Vint_runcount+3).w,d0
	andi.b	#$1F,d0
	bne.s	EHZBoss_loc_2F5A0
	move.b	#SndID_Helicopter,d0
	jsr	(PlaySound).l

EHZBoss_loc_2F5A0:
	move.w	obX(a1),obX(a0)
	move.w	obY(a1),obY(a0)
	move.b	obStatus(a1),obStatus(a0)
	move.b	obRender(a1),obRender(a0)
	lea	(Ani_EHZBoss_Propeller).l,a1
	jsr	(AnimateSprite).l
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F5C6:	; EHZBoss_Propeller_Sub2
	subq.w	#1,objoff_2E(a0)	; timer
	bpl.s	EHZBoss_loc_2F5E8
	cmpi.w	#-$10,objoff_2E(a0)
	ble.w	EHZBoss_Delete
	move.w	#$200,obPriority(a0)
	addq.w	#1,obY(a0)	; move down
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F5E8:
	lea	(Ani_EHZBoss_Propeller).l,a1
	jsr	(AnimateSprite).l
	jmp	(DisplaySprite).l
; ===========================================================================

EHZBoss_GroundVehicle:	; EHZBoss_GroundVehicle:
	tst.b	ob2ndRout(a0)
	bne.s	EHZBoss_loc_2F626
; EHZBoss_GroundVehicle_Sub0:
	move.w	(Camera_Min_X_pos).w,d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_CameraLeft,d0
	blo.w	EHZBoss_Display
	move.w	obX(a0),d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_LandingX,d0
	ble.s	EHZBoss_loc_2F618
	subq.w	#1,obX(a0)
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F618:
	move.w	EHZBoss_origin_x(a0),d0
	addi.w	#EHZBoss_LandingX,d0
	move.w	d0,obX(a0)
	addq.b	#2,ob2ndRout(a0)
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F626:	; EHZBoss_GroundVehicle_Sub2:
	movea.l	objoff_38(a0),a1 ; parent address (vehicle)
	btst	#1,objoff_31(a1)
	beq.w	EHZBoss_Display	; boss not moving yet (inactive)
	btst	#2,objoff_31(a1)	; Robotnik flying off flag
	bne.w	EHZBoss_Display
	move.w	obX(a1),obX(a0)
	move.w	obY(a1),obY(a0)
	addq.w	#8,obY(a0)
	move.b	obStatus(a1),obStatus(a0)
	bmi.w	EHZBoss_Display
	move.b	obRender(a1),obRender(a0)
	jmp	(DisplaySprite).l
; ===========================================================================

EHZBoss_Wheel:	; EHZBoss_Wheel:
	moveq	#0,d0
	move.b	ob2ndRout(a0),d0
	move.w	EHZBoss_off_2F672(pc,d0.w),d1
	jmp	EHZBoss_off_2F672(pc,d1.w)
; ---------------------------------------------------------------------------
EHZBoss_off_2F672:	offsetTable
		offsetTableEntry.w EHZBoss_loc_2F67C	; 0 - wheels moving towards start position
		offsetTableEntry.w EHZBoss_loc_2F714	; 2 - standing still (boss inactive)
		offsetTableEntry.w EHZBoss_loc_2F746	; 4 - normal mode (boss active)
		offsetTableEntry.w EHZBoss_loc_2F7A6	; 6 - inactive while defeat
		offsetTableEntry.w EHZBoss_loc_2F7D2	; 8 - wheels bouncing away after defeat
; ---------------------------------------------------------------------------

EHZBoss_loc_2F67C:	; EHZBoss_Wheel_Sub0:
	move.w	(Camera_Min_X_pos).w,d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_CameraLeft,d0
	blo.w	EHZBoss_Display
	move.w	#$100,obVelY(a0)
	cmpi.b	#1,obSubtype(a0)	; wheel number (0-2)
	bgt.s	EHZBoss_loc_2F6B6	; background wheel
	beq.s	EHZBoss_loc_2F6A6	; second foreground wheel
; ---------------------------------------------------------------------------
	move.w	obX(a0),d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_LandingX+$1C,d0
	ble.s	EHZBoss_loc_2F6C6
	subq.w	#1,obX(a0)
	bra.s	EHZBoss_loc_2F6E8

EHZBoss_loc_2F6A6:	; second foreground wheel
	move.w	obX(a0),d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_LandingX-$C,d0
	ble.s	EHZBoss_loc_2F6D2
	subq.w	#1,obX(a0)
	bra.s	EHZBoss_loc_2F6E8

EHZBoss_loc_2F6B6:	; background wheel
	move.w	obX(a0),d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_LandingX-$2C,d0
	ble.s	EHZBoss_loc_2F6DE
	subq.w	#1,obX(a0)
	bra.s	EHZBoss_loc_2F6E8
; ---------------------------------------------------------------------------

EHZBoss_loc_2F6C6:	; first foreground wheel
	move.w	EHZBoss_origin_x(a0),d0
	addi.w	#EHZBoss_LandingX+$1C,d0
	move.w	d0,obX(a0)
	addq.b	#2,ob2ndRout(a0)
	bra.s	EHZBoss_loc_2F6E8

EHZBoss_loc_2F6D2:	; second foreground wheel
	move.w	EHZBoss_origin_x(a0),d0
	addi.w	#EHZBoss_LandingX-$C,d0
	move.w	d0,obX(a0)
	addq.b	#2,ob2ndRout(a0)
	bra.s	EHZBoss_loc_2F6E8

EHZBoss_loc_2F6DE:	; background wheel
	move.w	EHZBoss_origin_x(a0),d0
	addi.w	#EHZBoss_LandingX-$2C,d0
	move.w	d0,obX(a0)
	addq.b	#2,ob2ndRout(a0)
; ---------------------------------------------------------------------------

EHZBoss_loc_2F6E8:	; routine for all wheels
	jsr	(ObjectMoveAndFall).l
	jsr	(ObjHitFloor).l
	tst.w	d1
	bpl.s	EHZBoss_loc_2F6FA
	add.w	d1,obY(a0)	; reset on floor

EHZBoss_loc_2F6FA:
	tst.b	ob2ndRout(a0)
	beq.s	EHZBoss_loc_2F706
	move.w	#-$200,obVelX(a0)	; if reached position, set velocity

EHZBoss_loc_2F706:
	lea	(Ani_EHZBoss_Ground).l,a1
	jsr	(AnimateSprite).l
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F714:	; EHZBoss_Wheel_Sub2:
	movea.l	objoff_38(a0),a1 ; parent address (vehicle)
	cmpi.l	#EHZBoss,code(a1)
	bne.w	EHZBoss_Delete	; if boss non-existant
	btst	#1,objoff_31(a1)
	beq.w	EHZBoss_Display	; boss not moving yet (inactive)
	addq.b	#2,ob2ndRout(a0)
	cmpi.w	#$100,obPriority(a0)
	bne.s	BranchTo_JmpTo35_DisplaySprite
	move.w	obY(a0),d0
	movea.l	objoff_38(a0),a1 ; parent address (vehicle)
	add.w	d0,objoff_32(a1)

BranchTo_JmpTo35_DisplaySprite ; BranchTo
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F746:	; EHZBoss_Wheel_Sub4:
	movea.l	objoff_38(a0),a1 ; parent address (vehicle)
	cmpi.l	#EHZBoss,code(a1)
	bne.w	EHZBoss_Delete	; if boss non-existant
	move.b	obStatus(a1),obStatus(a0)
	move.b	obRender(a1),obRender(a0)
	btst	#status.npc.no_balancing,obStatus(a0)
	beq.s	EHZBoss_loc_2F768	; has Sonic just defeated the boss (i.e. bit 7 set)?
	addq.b	#2,ob2ndRout(a0)	; if yes, Sub6

EHZBoss_loc_2F768:
	bsr.w	EHZBoss_CheckDirection	; position check, sets direction
	jsr	(ObjectMoveAndFall).l
	jsr	(ObjHitFloor).l
	tst.w	d1
	bpl.s	EHZBoss_loc_2F77E
	add.w	d1,obY(a0)	; reset on floor

EHZBoss_loc_2F77E:
	move.w	#$100,obVelY(a0)
	cmpi.w	#$100,obPriority(a0)
	bne.s	EHZBoss_loc_2F798
	move.w	obY(a0),d0
	movea.l	objoff_38(a0),a1 ; parent address (vehicle)
	add.w	d0,objoff_32(a1)

EHZBoss_loc_2F798:
	lea	(Ani_EHZBoss_Ground).l,a1
	jsr	(AnimateSprite).l
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F7A6:	; EHZBoss_Wheel_Sub6:
	subq.w	#1,objoff_2E(a0)	; timer, initially set to $A (first delay until wheels rolling off)
	bpl.w	EHZBoss_Display
	addq.b	#2,ob2ndRout(a0)	; Sub8
	move.w	#$A,objoff_2E(a0)
	move.w	#-$300,obVelY(a0)	; first bounce higher
	cmpi.w	#$100,obPriority(a0)
	beq.w	EHZBoss_Display
	neg.w	obVelX(a0)	; into other direction
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F7D2:	; EHZBoss_Wheel_Sub8:
	subq.w	#1,objoff_2E(a0)	; timer, initially set to $A (second delay until wheels rolling off)
	bpl.w	EHZBoss_Display
	jsr	(ObjectMoveAndFall).l
	jsr	(ObjHitFloor).l
	tst.w	d1
	bpl.s	BranchTo_JmpTo36_MarkObjGone
	move.w	#-$200,obVelY(a0)	; negative velocity to have bouncing effect
	add.w	d1,obY(a0)	; reset on floor

BranchTo_JmpTo36_MarkObjGone ; BranchTo
	jmp	(MarkObjGone).l
; ===========================================================================

EHZBoss_Drill:	; EHZBoss_Spike:
	tst.b	ob2ndRout(a0)
	bne.s	EHZBoss_loc_2F824
; EHZBoss_Spike_Sub0:
	move.w	(Camera_Min_X_pos).w,d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_CameraLeft,d0
	blo.w	EHZBoss_Display
	move.w	obX(a0),d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_LandingX-$36,d0
	ble.s	EHZBoss_loc_2F816
	subq.w	#1,obX(a0)
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F816:
	move.w	EHZBoss_origin_x(a0),d0
	addi.w	#EHZBoss_LandingX-$36,d0
	move.w	d0,obX(a0)
	addq.b	#2,ob2ndRout(a0)
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F824:	; EHZBoss_Spike_Sub2:
	movea.l	objoff_38(a0),a1 ; parent address (vehicle)
	cmpi.l	#EHZBoss,code(a1)
	bne.w	EHZBoss_Delete	; if boss non-existant
	btst	#3,objoff_31(a1)
	bne.s	EHZBoss_loc_2F88A	; spike separated from vehicle
	bsr.w	EHZBoss_loc_2F8AA
	btst	#1,objoff_31(a1)
	beq.w	EHZBoss_Display	; boss not moving yet (inactive)
	move.b	#$8B,obColType(a0)	; spike still linked to vehicle
	move.w	obX(a1),obX(a0)
	move.w	obY(a1),obY(a0)
	move.b	obStatus(a1),obStatus(a0)	; transfer positions
	move.b	obRender(a1),obRender(a0)
	addi.w	#$10,obY(a0)	; vertical offset
	move.w	#-$36,d0
	btst	#status.npc.x_flip,obStatus(a0)
	beq.s	EHZBoss_loc_2F878
	neg.w	d0

EHZBoss_loc_2F878:
	add.w	d0,obX(a0)	; horizontal offset
	lea	(Ani_EHZBoss_Ground).l,a1
	jsr	(AnimateSprite).l
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F88A:	; spike separated from vehicle
	move.w	#-3,d0	; velocity of spike in pixels/frame
	btst	#status.npc.x_flip,obStatus(a0)	; check direction
	beq.s	EHZBoss_loc_2F898
	neg.w	d0

EHZBoss_loc_2F898:
	add.w	d0,obX(a0)
	lea	(Ani_EHZBoss_Ground).l,a1
	jsr	(AnimateSprite).l
	jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

EHZBoss_loc_2F8AA:
	cmpi.b	#1,obColProp(a1)	; hit counter, only 1 life left?
	beq.s	EHZBoss_loc_2F8B4
	rts
; ---------------------------------------------------------------------------

EHZBoss_loc_2F8B4:
	move.w	obX(a0),d0
	sub.w	(v_player+obX).w,d0
	bpl.s	EHZBoss_loc_2F8C8
	btst	#status.npc.x_flip,obStatus(a1)	; Sonic right from spike
	bne.s	EHZBoss_loc_2F8D2	; spike facing right
	rts
; ---------------------------------------------------------------------------

EHZBoss_loc_2F8C8:
	btst	#status.npc.x_flip,obStatus(a1)	; Sonic left from spike
	beq.s	EHZBoss_loc_2F8D2	; spike facing left
	rts
; ---------------------------------------------------------------------------

EHZBoss_loc_2F8D2:
	bset	#3,objoff_31(a1)	; flag to separate spike from vehicle
	rts
; ===========================================================================

EHZBoss_Cockpit:	; EHZBoss_VehicleTop:
	movea.l	objoff_38(a0),a1 ; parent address (vehicle)
	move.l	obX(a1),obX(a0)
	move.l	obY(a1),obY(a0)
	move.b	obStatus(a1),obStatus(a0)	; update position and status
	move.b	obRender(a1),obRender(a0)
	move.b	objoff_42(a1),d0	; boss invincibility timer
	cmpi.b	#$1F,d0	; boss just got hit?
	bne.s	EHZBoss_loc_2F906
	move.b	#2,obAnim(a0)	; Robotnik animation when hit

EHZBoss_loc_2F906:
	cmpi.b	#4,(v_player+obRoutine).w	; Sonic = ball
	beq.s	EHZBoss_loc_2F916
	cmpi.b	#4,(v_player2+obRoutine).w	; Tails = ball
	bne.s	EHZBoss_loc_2F924

EHZBoss_loc_2F916:
	cmpi.b	#2,obAnim(a0)	; check Eggman animation (when hit)
	beq.s	EHZBoss_loc_2F924
	move.b	#3,obAnim(a0)	; Eggman animation when hurting Sonic

EHZBoss_loc_2F924:
	lea	(Ani_EHZBoss_Vehicle).l,a1	; animation script
	jsr	(AnimateSprite).l
	jmp	(DisplaySprite).l

; ===========================================================================
; animation script
; EHZBoss_off_2F936:
Ani_EHZBoss_Propeller:	offsetTable
		offsetTableEntry.w EHZBoss_byte_2F93C	; 0
		offsetTableEntry.w EHZBoss_byte_2F940	; 1
		offsetTableEntry.w EHZBoss_byte_2F956	; 2
EHZBoss_byte_2F93C:
	dc.b   1,  5,  6,$FF
EHZBoss_byte_2F940:
	dc.b   1,  1,  1,  1,  2,  2,  2,  3,  3,  3,  4,  4,  4,  0,  0,  0
	dc.b   0,  0,  0,  0,  0,$FF; 16
EHZBoss_byte_2F956:
	dc.b   1,  0,  0,  0,  0,  0,  0,  0,  0,  4,  4,  4,  3,  3,  3,  2
	dc.b   2,  2,  1,  1,  1,  5,  6,$FE,  2
	even
; ----------------------------------------------------------------------------
; sprite mappings
; ----------------------------------------------------------------------------
	include "mappings/sprite/EHZ Boss Propeller.asm"
	; propeller
	; 7 frames

; animation script
; EHZBoss_off_2FA44:
Ani_EHZBoss_Ground:	offsetTable
		offsetTableEntry.w EHZBoss_byte_2FA4A	; 0
		offsetTableEntry.w EHZBoss_byte_2FA4F	; 1
		offsetTableEntry.w EHZBoss_byte_2FA53	; 2
EHZBoss_byte_2FA4A:
	dc.b   5,  1,  2,  3,$FF	; spike

EHZBoss_byte_2FA4F:
	dc.b   1,  4,  5,$FF	; foreground wheel

EHZBoss_byte_2FA53:
	dc.b   1,  6,  7,$FF	; background wheel
	even

; ----------------------------------------------------------------------------
; sprite mappings
; ----------------------------------------------------------------------------
	include "mappings/sprite/EHZ Boss Ground.asm"
	; ground vehicle
	; frame 0 = vehicle itself
	; frame 1-3 = spike
	; frame 4-5 = foreground wheel
	; frame 6-7 = background wheel

; animation script
; EHZBoss_off_2FAC8:
Ani_EHZBoss_Vehicle:	offsetTable
		offsetTableEntry.w EHZBoss_byte_2FAD2	; 0
		offsetTableEntry.w EHZBoss_byte_2FAD5	; 1
		offsetTableEntry.w EHZBoss_byte_2FAD9	; 2
		offsetTableEntry.w EHZBoss_byte_2FAE2	; 3
		offsetTableEntry.w EHZBoss_byte_2FAEB	; 4
EHZBoss_byte_2FAD2:	dc.b  $F,  0,$FF	; bottom

EHZBoss_byte_2FAD5:	dc.b   7,  1,  2,$FF	; top, normal

EHZBoss_byte_2FAD9:	dc.b   7,  5,  5,  5,  5,  5,  5,$FD,  1	; top, when hit

EHZBoss_byte_2FAE2:	dc.b   7,  3,  4,  3,  4,  3,  4,$FD,  1	; top, laughter (when hurting Sonic)

EHZBoss_byte_2FAEB:	dc.b  $F,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,$FD,  1	; top, when flying off
	even	; for top part, after end of special animations always return to normal one ($FD->1)

; ----------------------------------------------------------------------------
; sprite mappings
; ----------------------------------------------------------------------------
	include "mappings/sprite/EHZ Boss Vehicle.asm"
	; flying vehicle
	; frame 0 = bottom
	; frame 1-2 = top, normal
	; frame 3-4 = top, laughter
	; frame 5 = top, when hit
	; frame 6 = top, when flying off
; ===========================================================================

; Local branch targets avoid indirect jump trampolines in every child update.
EHZBoss_Display:
	jmp	(DisplaySprite).l
EHZBoss_Delete:
	jmp	(DeleteObject).l
EHZBoss_Return:
	rts

EHZBoss_PlayLevelMusic:
	clr.b	(f_lockscreen).w
	jsr	(GetLevelMusic).l
	jmp	(PlayMusic).l

EHZBoss_RestoreLevelArt:
	moveq	#0,d0
	move.b	(Current_Zone).w,d0
	lea	EHZBoss_AnimalCues(pc),a1
	move.b	(a1,d0.w),d0
	jsr	(LoadPLC).l
	moveq	#plcid_Explode,d0
	jmp	(LoadPLC).l
EHZBoss_AnimalCues:
	dc.b plcid_GHZAnimals,plcid_LZAnimals,plcid_CPZAnimals,plcid_EHZAnimals
	dc.b plcid_HPZAnimals,plcid_HTZAnimals,plcid_GHZAnimals
	even
