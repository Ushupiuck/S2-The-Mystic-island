; ---------------------------------------------------------------------------
; EHZ boss from Sonic 2 final (s2disasm 15e9fd52a65318bec3d5e746ce48dba6db6910db).
; One boss ID, eight object slots: shared S1 pod/cockpit, car, three wheels,
; drill and rear exhaust. Children use ordinary S3&K mappings, not packed composites.
; Stage/placement X,Y specify the landing anchor; origin deltas preserve the
; final choreography when this boss is used as the existing MZ placeholder.
; Display half-height uses height_pixels; collision radii are separate.
; ---------------------------------------------------------------------------
EHZBoss_flash_color = objoff_36	; original hit-flash color; unused word before child pointer
EHZBoss_origin_x = objoff_44
EHZBoss_origin_y = objoff_46
EHZBoss_LandingX = $29D0
EHZBoss_LandingY = $71E
EHZBoss_ApproachX = EHZBoss_LandingX+$120
EHZBoss_ApproachY = EHZBoss_LandingY-$120
EHZBoss_PodDrawY = -4
EHZBoss_EscapeHop = 8
EHZBoss_LeftTurn = $28A0
EHZBoss_RightTurn = $2B08
EHZBoss_CameraLeft = $28F0
EHZBoss_CameraFightRight = $2940
EHZBoss_CameraY = $690
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
		offsetTableEntry.w EHZBoss_Delete	; 4 - retired rotor routine
		offsetTableEntry.w EHZBoss_GroundVehicle	; 6 - Vehicle on ground
		offsetTableEntry.w EHZBoss_Wheel	; 8 - Wheels
		offsetTableEntry.w EHZBoss_Drill	; A - Spike
		offsetTableEntry.w EHZBoss_Delete	; C - retired rotor reload
		offsetTableEntry.w EHZBoss_Cockpit	; E - Flying vehicle, top
		offsetTableEntry.w EHZBoss_Exhaust	; 10 - shared S1 flight/escape thrust
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
	move.w	#make_art_tile(ArtTile_Eggman,0,0),obGfx(a0) ; vehicle with ability to fly, bottom part
	ori.b	#1<<obRender.level_fg,obRender(a0)
	move.w	#$81,obSubtype(a0)
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
	move.l	#Map_EHZBoss_Cockpit,obMap(a1)
	move.b	#Map_EHZBoss_Cockpit_height,height_pixels(a1)
	move.w	#make_art_tile(ArtTile_Eggman,0,0),obGfx(a1)
	move.b	#1<<obRender.level_fg,obRender(a1)
	move.b	#Map_EHZBoss_Cockpit_width,width_pixels(a1)
	move.w	#$200,obPriority(a1)
	move.l	obX(a0),obX(a1)
	move.l	obY(a0),obY(a1)
	move.b	#$E,obRoutine(a1)
	move.b	#BossFace_Normal,obAnim(a1)	; shared S1 pilot
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
	jsr	(FindNextFreeObj).l	; rear flame, retained throughout the fight
	bne.w	+

	move.l	#EHZBoss,code(a1)
	move.l	a0,objoff_38(a1)
	move.l	#Map_BossExhaust,obMap(a1)
	move.b	#Map_BossExhaust_height,height_pixels(a1)
	move.b	#Map_BossExhaust_width,width_pixels(a1)
	move.w	#make_art_tile(ArtTile_Eggman_Exhaust,0,0),obGfx(a1)
	move.b	#1<<obRender.level_fg,obRender(a1)
	move.w	#$200,obPriority(a1)	; behind the pod at the same queue tier
	move.w	#$22,BossChild_OffsetX(a1)
	move.w	#EHZBoss_PodDrawY,BossChild_OffsetY(a1)
	move.b	#BossExhaust_Cruise,obAnim(a1)
	move.b	#$FF,obPrevAni(a1)
	move.b	#$10,obRoutine(a1)
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
	move.w	#0,obSubtype(a1)
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
	move.w	#1,obSubtype(a1)
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
	move.w	#2,obSubtype(a1)
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
	bset	#0,objoff_31(a0)	; Robotnik on ground; stop approach flame
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
		offsetTableEntry.w EHZBoss_StartHop
		offsetTableEntry.w EHZBoss_HopBeforeIgnition
		offsetTableEntry.w EHZBoss_FlyAway

EHZBoss_StartHop:
	bclr	#0,objoff_31(a0)
	bset	#2,objoff_31(a0)	; detach the pod; keep the chassis on the ground
	move.w	#EHZBoss_EscapeHop,objoff_2E(a0)
	addq.b	#2,objoff_30(a0)
	bsr.w	EHZBoss_PlayLevelMusic
	move.b	#1,(Boss_defeated_flag).w
	bra.w	EHZBoss_RestoreLevelArt

EHZBoss_HopBeforeIgnition:
	subq.w	#1,objoff_2E(a0)
	bmi.s	.ignite
	subq.w	#1,obY(a0)	; eight unpowered pixels, then ignition
	rts
.ignite:
	bset	#status.npc.x_flip,obStatus(a0)
	bset	#obRender.x_flip,obRender(a0)
	move.w	#$400,obVelX(a0)
	move.w	#-$40,obVelY(a0)
	addq.b	#2,objoff_30(a0)
	rts

EHZBoss_FlyAway:
	jsr	(ObjectMove).l	; S1 escape: four pixels right, quarter pixel up

EHZBoss_loc_2F460:
	move.w	(Camera_Max_X_pos).w,d0
	sub.w	EHZBoss_origin_x(a0),d0
	cmpi.w	#EHZBoss_CameraExitRight,d0
	bhs.s	EHZBoss_loc_2F46E
	addq.w	#2,(Camera_Max_X_pos).w
	move.w	(Camera_Max_X_pos).w,(Tails_Max_X_pos).w
	rts
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
	move.w	#MusID_FadeOut,d0
	jsr	(PlayMusic).l
	moveq	#100,d0
	jsr	(AddPoints).l	; add 1000 points, reward for defeating boss
	move.b	#6,ob2ndRout(a0)
	move.w	#0,obVelX(a0)
	move.w	#-$180,obVelY(a0)
	move.w	#$B3,objoff_40(a0)	; timer
	bset	#3,objoff_31(a0)	; flag to separate spike from vehicle
	movea.l	objoff_38(a0),a1 ; address top part
	move.b	#BossFace_Defeated,obAnim(a1)	; shared S1 defeat expression
	moveq	#plcid_Capsule,d0
	jmp	(LoadPLC).l	; load egg prison
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
	cmpi.w	#1,obSubtype(a0)	; wheel number (0-2)
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

EHZBoss_Cockpit:	; Complete S1 cockpit on the EHZ chassis
	movea.l	objoff_38(a0),a1
	cmpi.l	#EHZBoss,code(a1)
	bne.w	EHZBoss_Delete
	cmpi.b	#2,obRoutine(a1)
	bne.w	EHZBoss_Delete
	moveq	#BossFace_Normal,d1
	cmpi.b	#6,ob2ndRout(a1)
	bhs.s	.defeated
	tst.b	objoff_42(a1)
	bne.s	.hurt
	cmpi.b	#4,(v_player+obRoutine).w
	bhs.s	.laugh
	tst.l	(v_player2+code).w
	beq.s	.animate
	cmpi.b	#4,(v_player2+obRoutine).w
	blo.s	.animate
.laugh:
	moveq	#BossFace_Laugh,d1
	bra.s	.animate
.hurt:
	moveq	#BossFace_Hurt,d1
	bra.s	.animate
.defeated:
	moveq	#BossFace_Defeated,d1
	cmpi.b	#8,ob2ndRout(a1)
	bne.s	.animate
	moveq	#BossFace_Recover,d1
.animate:
	move.b	d1,obAnim(a0)
	jmp	(BossFace_Display).l

EHZBoss_Exhaust:
	movea.l	objoff_38(a0),a1
	cmpi.l	#EHZBoss,code(a1)
	bne.w	EHZBoss_Delete
	cmpi.b	#2,obRoutine(a1)
	bne.w	EHZBoss_Delete
	move.b	#BossExhaust_Off,obAnim(a0)
	cmpi.b	#4,ob2ndRout(a1)
	blo.s	.approach
	cmpi.b	#$A,ob2ndRout(a1)
	bne.s	.display
	cmpi.b	#4,objoff_30(a1)
	bne.s	.display
	move.b	#BossExhaust_Escape,obAnim(a0)
	bra.s	.display
.approach:
	btst	#0,objoff_31(a1)
	bne.s	.display
	move.b	#BossExhaust_Cruise,obAnim(a0)
.display:
	jmp	(BossExhaust_Display).l

; ===========================================================================
; animation script
; EHZBoss_off_2F936:
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
