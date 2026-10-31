; ---------------------------------------------------------------------------
; MD CPU: standard Sky Sanctuary Mecha Sonic, skdisasm 73de97c6b55055bcb8089c1d55d006b02136f163.
; The original attack states, animation scripts, acceleration and hitboxes are
; retained outside the landing-camp and repeated-head-hit counters below.
; SMZ2 supplies a placed-sign ambush and falling-sign/results handoff.
; Knuckles's distinct Master Emerald rematch is not part of this entry point.
; ---------------------------------------------------------------------------
MS_timer = objoff_2E             ; word: wait counter
MS_script = objoff_30            ; long: raw animation
MS_callback = objoff_34          ; long: animation/floor continuation
MS_flags = objoff_38             ; byte: grounded/dive bits 0/1, original jet/turn bits 2/3
MS_history = objoff_39           ; byte: original landing history; defeat palette timer
MS_attack = objoff_3A            ; byte: attack selector; defeat palette index
MS_attack_count = objoff_3B      ; byte: original eight-jump sequence
MS_loaded = objoff_3C            ; byte: last body DPLC uploaded
MS_sign = objoff_3E              ; word: validated trap sign SST, then zero
MS_accel = objoff_40             ; word: horizontal acceleration
MS_left = objoff_42              ; word: left attack boundary
MS_right = objoff_44             ; word: right attack boundary
MS_top = objoff_46               ; word: camera-relative flight height
MS_hitbox = objoff_48            ; word: owned invisible head hitbox
MS_sign_y = objoff_4A            ; word: original sign height
MS_head_hits = objoff_4C         ; byte: consecutive grounded hits from above
MS_shot_pending = objoff_4D      ; byte: retry the third-hit shot if the pool is full
MS_grounded_bit = 0             ; MS_flags: landed until the next takeoff
MS_diving_bit = 1               ; MS_flags: rolling counter until touchdown
MS_phase = ob2ndRout             ; byte: scene lifecycle, independent of original AI
MS_flash = obAnim                ; byte: original 32-update hit flash
MS_jet_kind = obPrevAni          ; byte: 0 flying, 4 dash, 8 landing
MS_jet1 = obAngle                ; word: first owned jet
MS_jet2 = obSubtype              ; word: second jet; boss is event-spawned
MS_parent = objoff_38            ; word: child -> validated MechaSonic owner
MS_Fight = 4
MS_Defeat = 5
MS_RevealSeconds = 2		; hold the settled portrait before the entry dash
MS_HitPoints = 16
MS_CampRadius = $18             ; player centre within the rolling landing footprint
MS_CampHeight = $100            ; detect before the descent reaches the player
MS_CampMinDrop = $18            ; enough separation to commit the aimed dive
MS_EnergyFrame = 8              ; compact copy of the rematch's energy ball

; Called only after a crossing of subtype bit 1. A full pool retries without
; consuming the crossing or entering results. The sign owns its placement.
Signpost_TrapTrigger:
	jsr	(FindFreeObj).l
	bne.w	MS_Return
	move.l	#MechaSonic,code(a1)
	move.w	a0,MS_sign(a1)
	move.w	obX(a0),obX(a1)
	move.w	obY(a0),MS_sign_y(a1)
	move.w	#120,objoff_34(a0)
	move.b	#16,obRoutine(a0)
	move.b	#Signpost_Ani_MechaSpin,obAnim(a0)
	moveq	#palid_MechaSonic,d0
	move.l	d7,-(sp)
	jsr	(PalLoad2).l
	move.l	(sp)+,d7
	jsr	(Signpost_Activate).l
	move.b	#1,(f_timecount).w
	move.b	#1,(Dynamic_Resize_Routine).w
	rts

Signpost_TrapSpin:
	subq.w	#1,objoff_34(a0)
	bmi.s	.settled
	jmp	(Signpost_Sparkle).l
.settled:
	move.b	#5,obAnim(a0)
	move.b	#18,obRoutine(a0)
	rts

MechaSonic:
	moveq	#0,d0
	move.b	MS_phase(a0),d0
	add.w	d0,d0
	move.w	MS_Phases(pc,d0.w),d1
	jsr	MS_Phases(pc,d1.w)
	tst.l	code(a0)
	beq.w	MS_Return
	cmpi.b	#3,MS_phase(a0)
	blo.w	MS_Return
	bsr.w	MS_MaintainJets
	bsr.w	MS_UpdateHitbox
	moveq	#0,d0
	move.b	obFrame(a0),d0
	lea	(DPLC_MechaSonic).l,a2
	lea	MS_loaded(a0),a3
	move.w	#ArtTile_MechaSonic*tile_size,d4
	move.l	#Art_MechaSonic,d6
	jsr	(Load_DynamicPLC).l
	bcs.w	MS_Return
	jmp	(DisplaySprite).l
MS_Phases:
	dc.w MS_Init-MS_Phases,MS_Loading-MS_Phases,MS_AwaitPortrait-MS_Phases
	dc.w MS_Strike-MS_Phases,MS_RunFight-MS_Phases,MS_DefeatWait-MS_Phases
	dc.w MS_DefeatFall-MS_Phases,MS_Crumple-MS_Phases,MS_Reward-MS_Phases

MS_Init:
	jsr	(FindFreeObj).l
	bne.w	MS_Return
	move.l	#MS_HeadHitbox,code(a1)
	move.w	a0,MS_parent(a1)
	move.w	a1,MS_hitbox(a0)
	move.b	#4,obRender(a1)
	move.b	#16,obActWid(a1)
	move.b	#64,height_pixels(a1)
	move.l	#Map_MechaSonic,obMap(a0)
	move.w	#make_art_tile(ArtTile_MechaSonic,1,1),obGfx(a0)
	move.b	#4,obRender(a0)
	move.b	#Map_MechaSonic_height,height_pixels(a0)
	move.b	#Map_MechaSonic_width,obActWid(a0)
	move.w	#$280,obPriority(a0)
	move.b	#$1F,obHeight(a0)
	move.b	#$20,obWidth(a0)
	move.b	#MS_HitPoints,obColProp(a0)
	st	MS_loaded(a0)
	move.w	obX(a0),d0
	subi.w	#$80,d0
	move.w	d0,MS_left(a0)
	addi.w	#$100,d0
	move.w	d0,MS_right(a0)
	move.w	(Camera_Y_pos).w,d0
	addi.w	#$30,d0
	move.w	d0,MS_top(a0)
	moveq	#plcid_MechaSonic,d0
	jsr	(LoadPLC).l
	move.b	#1,MS_phase(a0)
	rts
MS_Loading:
	tst.l	(v_plc_buffer).w
	bne.w	MS_Return
	move.b	#2,MS_phase(a0)
	clr.w	MS_timer(a0)
MS_AwaitPortrait:
	movea.w	MS_sign(a0),a1
	cmpi.l	#Signpost,code(a1)
	bne.w	MS_Delete
	cmpi.b	#18,obRoutine(a1)
	bne.w	MS_Return
		cmpi.b	#6,obFrame(a1)
		bne.w	MS_Return
		cmpi.b	#6,signpost_loaded(a1)
		bne.w	MS_Return
		tst.w	MS_timer(a0)
		bne.s	.reveal_wait
		; Arm only after the final portrait's complete DPLC is queued.
		; One extra update allows its first DMA/VBlank before the full hold.
		move.w	#MS_RevealSeconds*60+1,MS_timer(a0)
		btst	#6,(v_megadrive).w
		beq.w	MS_Return
		move.w	#MS_RevealSeconds*50+1,MS_timer(a0)
		rts

.reveal_wait:
		subq.w	#1,MS_timer(a0)
		bne.w	MS_Return
	move.b	#3,MS_phase(a0)
	move.b	#2,obFrame(a0)
	move.w	(Camera_X_pos).w,d0
	addi.w	#$168,d0
	move.w	d0,obX(a0)
	move.w	MS_sign_y(a0),obY(a0)
	subq.w	#4,obY(a0)
	move.w	#-$800,obVelX(a0)
	bset	#2,MS_flags(a0)
	clr.b	MS_jet_kind(a0)
	move.w	#MusID_Boss3,d0
	jmp	(PlaySound).l
MS_Strike:
	jsr	(ObjectMove).l
	tst.w	MS_sign(a0)
	beq.s	.passed
	movea.w	MS_sign(a0),a1
	cmpi.l	#Signpost,code(a1)
	bne.w	MS_Delete
	move.w	obX(a0),d0
	sub.w	obX(a1),d0
	cmpi.w	#$18,d0
	bgt.s	.passed
	bsr.w	MS_BreakSign
.passed:
	move.w	(Camera_X_pos).w,d0
	subi.w	#$20,d0
	cmp.w	obX(a0),d0
	blo.w	MS_Return
	bclr	#2,MS_flags(a0)
	move.b	#MS_Fight,MS_phase(a0)
	move.b	#6,obRoutine(a0)
	move.b	#9,obColType(a0)
	move.w	#$3F,MS_timer(a0)
	move.l	#MS_ReturnSweep,MS_callback(a0)
	rts
MS_RunFight:
	bsr.w	MS_FireCounterShot
	moveq	#0,d0
	move.b	obRoutine(a0),d0
	lea	MS_AIIndex(pc),a1
	move.w	(a1,d0.w),d1
	jsr	(a1,d1.w)
	bsr.w	MS_HitResponse
	cmpi.b	#MS_Fight,MS_phase(a0)
	bne.s	MS_Return
	btst	#6,obStatus(a0)
	bne.s	MS_Return
	moveq	#0,d0
	move.b	obFrame(a0),d0
	lea	MS_Collision(pc),a1
	move.b	(a1,d0.w),obColType(a0)
MS_Return:
	rts

MS_HitResponse:
        tst.b   obColType(a0)
        bne.s   MS_Return
        tst.b   obColProp(a0)
        beq.s   MS_Defeated
        tst.b   MS_flash(a0)
        bne.s   .flash
        move.b  #$20,MS_flash(a0)
        bset    #6,obStatus(a0)
        move.w  #sfx_HitBoss,d0
        jsr     (PlaySound_Special).l
.flash:
        lea     MS_HitColours(pc),a2
        btst    #0,MS_flash(a0)
        bne.s   .colours
        lea     10(a2),a2
.colours:
        bsr.w   MS_FlashColours
        subq.b  #1,MS_flash(a0)
        bne.s   MS_Return
        bclr    #6,obStatus(a0)
        rts
MS_Defeated:
        move.b  #MS_Defeat,MS_phase(a0)
        clr.b   obRoutine(a0)
        clr.b   MS_flags(a0)
        clr.w   MS_head_hits(a0)
        clr.b   obColType(a0)
        move.w  #$7F,MS_timer(a0)
        clr.b   (f_timecount).w
        moveq   #100,d0
        jsr     (AddPoints).l
        lea     (Pal_MechaSonic).l,a2
        bra.w   MS_CopyPalette
MS_DefeatWait:
        moveq   #BossExplosion_Mecha,d0
        jsr     (BossExplosion_Start).l
        subq.w  #1,MS_timer(a0)
        bpl.w   MS_Return
        move.b  #6,MS_phase(a0)
        move.b  #$E,obFrame(a0)
        move.b  #$1F,obHeight(a0)
        clr.l   obVelX(a0)
        rts
MS_DefeatFall:
        jsr     (ObjectMoveAndFall_LightGravity).l
        tst.w   obVelY(a0)
        bmi.w   MS_Return
        jsr     (ObjHitFloor).l
        tst.w   d1
        bgt.w   MS_Return
        add.w   d1,obY(a0)
        clr.l   obVelX(a0)
        move.b  #7,MS_phase(a0)
        move.b  #$23,obHeight(a0)
        lea     MS_AnimDefeat(pc),a1
        bsr.w   MS_SetRawAnimation
        move.w  #119,MS_timer(a0)
        clr.b   MS_attack(a0)
        move.b  #50,MS_history(a0)
        move.w  #SndID_MechaLand,d0
        jmp     (PlaySound_Special).l
MS_Crumple:
        bsr.w   MS_RawAnimate
        bsr.w   MS_DefeatPalette
        subq.w  #1,MS_timer(a0)
        bpl.w   MS_Return
        move.b  #8,MS_phase(a0)
MS_Reward:
        jsr     (FindFreeObj).l
        bne.w   MS_Return
        move.l  #Signpost,code(a1)
        move.w  (Camera_X_pos).w,d0
        addi.w  #$A0,d0
        move.w  d0,obX(a1)
        move.w  #1,obSubtype(a1)
        moveq   #palid_SMZ2,d0
        move.l  d7,-(sp)
        jsr     (PalLoad2).l
        move.l  (sp)+,d7
        move.b  #2,(Dynamic_Resize_Routine).w
MS_Delete:
        ; An externally removed/reused trap must never delete its replacement.
        jmp     (DeleteObject).l

MS_UpdateHitbox:
        movea.w MS_hitbox(a0),a1
        cmpi.l  #MS_HeadHitbox,code(a1)
        bne.w   MS_Return
        clr.b   obColType(a1)
        cmpi.b  #MS_Fight,MS_phase(a0)
        bne.w   MS_Return
        moveq   #0,d0
        move.b  obFrame(a0),d0
        lsl.w   #2,d0
        lea     MS_HeadData(pc),a2
        adda.w  d0,a2
        move.b  (a2)+,d0
        ext.w   d0
        btst    #0,obRender(a0)
        beq.s   .x
        neg.w   d0
.x:     add.w   obX(a0),d0
        move.w  d0,obX(a1)
        move.b  (a2)+,d0
        ext.w   d0
        add.w   obY(a0),d0
        move.w  d0,obY(a1)
        move.b  (a2),obColType(a1)
        jmp     (Touch_RegisterEarlierObject).l
MS_HeadHitbox:
        movea.w MS_parent(a0),a1
        cmpi.l  #MechaSonic,code(a1)
        bne.w   MS_Delete
        cmpi.b  #MS_Defeat,MS_phase(a1)
        bhs.w   MS_Delete
        rts

; Jet references are validated and retried: a full pool cannot permanently
; remove an attack effect, and a reused SST is never mistaken for an owned jet.
MS_CreateJets:
        clr.b   MS_jet_kind(a0)
        cmpa.l  #MS_JetsDash,a2
        bne.s   .land
        move.b  #4,MS_jet_kind(a0)
.land:  cmpa.l  #MS_JetsLand,a2
        bne.s   MS_MaintainJets
        move.b  #8,MS_jet_kind(a0)
MS_MaintainJets:
        btst    #2,MS_flags(a0)
        beq.w   MS_Return
        lea     MS_jet1(a0),a3
        moveq   #0,d2
        move.b  MS_jet_kind(a0),d2
        bsr.s   .one
        cmpi.b  #8,MS_jet_kind(a0)
        beq.s   .done
        lea     MS_jet2(a0),a3
        moveq   #0,d2
        move.b  MS_jet_kind(a0),d2
        addq.w  #2,d2
        bsr.s   .one
.done:  moveq   #0,d0
        rts
.one:
        movea.w (a3),a1
        cmpi.l  #MS_Jet,code(a1)
        bne.s   .allocate
        move.w  a0,d0
        cmp.w   MS_parent(a1),d0
        beq.s   .ready
.allocate:
        movem.l d2/a3,-(sp)
        jsr     (FindFreeObj).l
        movem.l (sp)+,d2/a3
        bne.s   .return
        move.l  #MS_Jet,code(a1)
        move.b  #1,obFrame(a1)
        move.w  a0,MS_parent(a1)
        move.w  a1,(a3)
        move.l  #Map_MechaEffects,obMap(a1)
        move.w  #make_art_tile(ArtTile_MechaEffects,0,1),obGfx(a1)
        move.b  #4,obRender(a1)
        move.b  #Map_MechaEffects_width,obActWid(a1)
        move.b  #Map_MechaEffects_height,height_pixels(a1)
.ready: move.w  d2,obSubtype(a1)
.return:rts
MS_Jet:
        movea.w MS_parent(a0),a2
        cmpi.l  #MechaSonic,code(a2)
        bne.w   MS_Delete
        btst    #2,MS_flags(a2)
        beq.w   MS_Delete
        move.w  obSubtype(a0),d0
        add.w   d0,d0
        lea     MS_JetOffsets(pc,d0.w),a1
        move.b  (a1)+,d0
        ext.w   d0
        move.b  #4,obRender(a0)
        btst    #0,obRender(a2)
        beq.s   .x
        neg.w   d0
        bset    #0,obRender(a0)
.x:     add.w   obX(a2),d0
        move.w  d0,obX(a0)
        move.b  (a1)+,d0
        ext.w   d0
        add.w   obY(a2),d0
        move.w  d0,obY(a0)
        move.w  (a1),obPriority(a0)
        subq.b  #1,obTimeFrame(a0)
        bpl.s   .draw
        move.b  #1,obTimeFrame(a0)
        addq.b  #1,obFrame(a0)
        cmpi.b  #4,obFrame(a0)
        blo.s   .draw
        clr.b   obFrame(a0)
.draw:  jmp     (DisplaySprite).l
MS_JetsFly: dc.w 0
MS_JetsDash:dc.w 0
MS_JetsLand:dc.w 0
MS_JetOffsets:
        dc.b -4,$1C
        dc.w $300
        dc.b 8,$1C
        dc.w $200
        dc.b -8,$1C
        dc.w $200
        dc.b 4,$1C
        dc.w $300
        dc.b $C,$C
        dc.w $200

MS_BreakSign:
        ; The current DPLC bank remains resident until every fragment expires.
        movem.l d7/a0,-(sp)
        movea.l a1,a0
        moveq   #0,d7
.loop:  movem.l d7,-(sp)
        jsr     (FindFreeObj).l
        movem.l (sp)+,d7
        bne.s   .delete
        move.l  #MS_SignDebris,code(a1)
        move.l  #Map_MechaSignDebris,obMap(a1)
        move.w  #make_art_tile(ArtTile_Signpost,0,0),obGfx(a1)
        move.b  #4,obRender(a1)
        move.b  #Map_MechaSignDebris_width,obActWid(a1)
        move.b  #Map_MechaSignDebris_height,height_pixels(a1)
        move.w  #$200,obPriority(a1)
        move.w  obX(a0),obX(a1)
        move.w  obY(a0),obY(a1)
        move.b  d7,obFrame(a1)
        move.w  d7,d0
        subi.w  #6,d0
        asl.w   #6,d0
        move.w  d0,obVelX(a1)
        move.w  #-$400,obVelY(a1)
        move.w  #48,objoff_2E(a1)
        addq.w  #1,d7
        cmpi.w  #Map_MechaSignDebris_frames,d7
        blo.s   .loop
.delete:
        jsr     (DeleteObject).l
        movem.l (sp)+,d7/a0
        clr.w   MS_sign(a0)
        move.w  #SndID_Smash,d0
        jmp     (PlaySound_Special).l
MS_SignDebris:
        jsr     (ObjectMoveAndFall).l
        subq.w  #1,objoff_2E(a0)
        bmi.w   MS_Delete
        jmp     (DisplaySprite).l

MS_DefeatPalette:
        subq.b  #1,MS_history(a0)
        bpl.s   .sparks
        addq.b  #1,MS_attack(a0)
        cmpi.b  #12,MS_attack(a0)
        blo.s   .step
        clr.b   MS_attack(a0)
.step:  moveq   #0,d0
        move.b  MS_attack(a0),d0
        add.w   d0,d0
        lea     MS_DefeatColours(pc),a1
        adda.w  d0,a1
        move.b  (a1)+,MS_history(a0)
        moveq   #0,d0
        move.b  (a1),d0
        lea     (Pal_MechaSonic).l,a2
        cmpi.b  #1,d0
        bne.s   .flash2
        lea     (Pal_MechaFlash1).l,a2
.flash2:cmpi.b  #2,d0
        bne.s   .copy
        lea     (Pal_MechaFlash2).l,a2
.copy:  bsr.w   MS_CopyPalette
.sparks:
        cmpi.w  #$E88,(v_palette+$36).w
        bne.w   MS_Return
        jsr     (FindFreeObj).l
        bne.w   MS_Return
        move.l  #MS_Spark,code(a1)
        move.l  #Map_MechaEffects,obMap(a1)
        move.w  #make_art_tile(ArtTile_MechaEffects,1,1),obGfx(a1)
        move.w  #$200,obPriority(a1)
        move.b  #4,obRender(a1)
        move.b  #Map_MechaEffects_height,height_pixels(a1)
        move.b  #Map_MechaEffects_width,obActWid(a1)
        move.w  obX(a0),obX(a1)
        move.w  obY(a0),obY(a1)
        addi.w  #12,obY(a1)
        moveq   #-4,d0
        btst    #0,obRender(a0)
        beq.s   .spark_x
        neg.w   d0
.spark_x:
        add.w   d0,obX(a1)
        move.b  #4,obFrame(a1)
        move.b  #1,obTimeFrame(a1)
        bchg    #0,MS_attack_count(a0)
        beq.s   .sound
        move.b  #5,obFrame(a1)
        move.w  obX(a0),obX(a1)
        subq.w  #4,obY(a1)
.sound: move.w  #SndID_MechaSpark,d0
        jmp     (PlaySound_Special).l
MS_Spark:
        subq.b  #1,obTimeFrame(a0)
        bmi.w   MS_Delete
        jmp     (DisplaySprite).l
; Touch_Enemy calls this before reflecting the successful attacker's velocity.
; a0 = player, a1 = boss. Preserve the touch scanner's registers and pointers.
MS_RecordHit:
        move.l  d0,-(sp)
        cmpi.b  #MS_Fight,MS_phase(a1)
        bne.s   .reset
        btst    #MS_grounded_bit,MS_flags(a1)
        beq.s   .reset
        btst    #status.player.in_air,obStatus(a0)
        beq.s   .reset
        tst.w   obVelY(a0)
        ble.s   .reset
        move.w  obY(a0),d0
        sub.w   obY(a1),d0
        cmpi.w  #-$10,d0
        bgt.s   .reset
        move.w  obX(a0),d0
        sub.w   obX(a1),d0
        addi.w  #MS_CampRadius,d0
        cmpi.w  #MS_CampRadius*2,d0
        bhi.s   .reset
        addq.b  #1,MS_head_hits(a1)
        cmpi.b  #3,MS_head_hits(a1)
        blo.s   .return
        st      MS_shot_pending(a1)
.reset:
        clr.b   MS_head_hits(a1)
.return:
        move.l  (sp)+,d0
        rts

MS_FireCounterShot:
        tst.b   MS_shot_pending(a0)
        beq.w   MS_Return
        tst.b   obColProp(a0)
        beq.w   MS_Return
        jsr     (FindFreeObj).l
        bne.w   MS_Return
        clr.b   MS_shot_pending(a0)
        move.l  #MS_EnergyBall,code(a1)
        move.w  a0,MS_parent(a1)
        move.l  #Map_MechaEffects,obMap(a1)
        move.w  #make_art_tile(ArtTile_MechaEffects,1,1),obGfx(a1)
        move.w  #$280,obPriority(a1)
        move.b  #4,obRender(a1)
        move.b  #8,height_pixels(a1)
        move.b  #8,obActWid(a1)
        move.b  #MS_EnergyFrame,obFrame(a1)
        move.b  #$87,obColType(a1)
        move.w  obX(a0),obX(a1)
        move.w  obY(a0),obY(a1)
        subi.w  #$20,obY(a1)
        move.w  #-$400,obVelY(a1)
        move.w  #SndID_LaserBurst,d0
        jmp     (PlaySound_Special).l
MS_EnergyBall:
        movea.w MS_parent(a0),a1
        cmpi.l  #MechaSonic,code(a1)
        bne.w   MS_Delete
        cmpi.b  #MS_Fight,MS_phase(a1)
        bne.w   MS_Delete
        jsr     (ObjectMove).l
        move.w  obY(a0),d0
        sub.w   (Camera_Y_pos).w,d0
        cmpi.w  #-$10,d0
        blt.w   MS_Delete
        bchg    #0,obRender(a0)
        jmp     (DisplaySprite).l

MS_CopyPalette:
        lea     (v_palette+$20).w,a1
        moveq   #7,d0
.copy:  move.l  (a2)+,(a1)+
        dbf     d0,.copy
        rts
MS_FlashColours:
        lea     MS_FlashOffsets(pc),a1
        moveq   #4,d1
.loop:  moveq   #0,d0
        move.b  (a1)+,d0
        lea     (v_palette).w,a3
        move.w  (a2)+,(a3,d0.w)
        dbf     d1,.loop
        rts
MS_FlashOffsets:dc.b $28,$38,$30,$32,$22
        even
MS_HitColours:dc.w 8,$A24,$624,$422,$20,$888,$666,$888,$AAA,$EEE
MS_DefeatColours:dc.b 50,0,2,2,1,1,5,0,2,2,1,1,50,0,2,2,1,1,20,0,2,2,1,1
        even

; Original standard-fight state machine and animation data.
MS_AIIndex:
		dc.w MS_NoAI-MS_AIIndex
		dc.w MS_NoAI-MS_AIIndex
		dc.w MS_FlyPast-MS_AIIndex
		dc.w MS_Wait-MS_AIIndex
		dc.w MS_Sweep-MS_AIIndex
		dc.w MS_AnimateWait-MS_AIIndex
		dc.w MS_Landing-MS_AIIndex
		dc.w MS_Animate-MS_AIIndex
		dc.w MS_GroundDash-MS_AIIndex
		dc.w MS_Animate-MS_AIIndex
		dc.w MS_Animate-MS_AIIndex
		dc.w MS_JumpDashRise-MS_AIIndex
		dc.w MS_AirDash-MS_AIIndex
		dc.w MS_BounceApproach-MS_AIIndex
		dc.w MS_BounceFlight-MS_AIIndex
		dc.w MS_ReboundApproach-MS_AIIndex
		dc.w MS_ReboundWait-MS_AIIndex
		dc.w MS_BackoffMove-MS_AIIndex
		dc.w MS_ReboundDash-MS_AIIndex
		dc.w MS_ReboundWait-MS_AIIndex
		dc.w MS_ReboundRise-MS_AIIndex
; ---------------------------------------------------------------------------

MS_FlyPast:
		jsr	(ObjectMove).l
		move.w	(Camera_X_pos).w,d0
		subi.w	#$20,d0
		cmp.w	x_pos(a0),d0
		blo.s	.return
		move.b	#6,obRoutine(a0)
		bclr	#2,MS_flags(a0)
		move.w	#$3F,MS_timer(a0)
		move.l	#MS_ReturnSweep,MS_callback(a0)
.return:	rts
; ---------------------------------------------------------------------------

MS_Wait:
		jmp	MS_WaitCallback(pc)
; ---------------------------------------------------------------------------

MS_ReturnSweep:
		move.b	#8,obRoutine(a0)
		bset	#0,render_flags(a0)
		move.w	(Camera_Y_pos).w,d0
		addi.w	#$40,d0
		move.w	d0,y_pos(a0)
		move.w	#$400,obVelX(a0)
		move.b	#3,mapping_frame(a0)
		move.l	#MS_AnimRoll,MS_script(a0)
MS_NoAI:	rts
; ---------------------------------------------------------------------------

MS_Sweep:
		jsr	MS_RawAnimate(pc)
		jsr	(ObjectMove).l
		move.w	x_pos(a0),d0
		cmp.w	MS_right(a0),d0
		bhs.s	MS_PauseSweep
		rts
; ---------------------------------------------------------------------------

MS_PauseSweep:
		move.b	#$A,obRoutine(a0)
		move.w	#$1F,MS_timer(a0)
		move.l	#MS_SelectLanding,MS_callback(a0)
		rts
; ---------------------------------------------------------------------------

MS_AnimateWait:
		jsr	MS_RawAnimate(pc)
		jmp	MS_WaitCallback(pc)
; ---------------------------------------------------------------------------

MS_SelectLanding:
		move.b	#$C,obRoutine(a0)
		move.b	#$1F,obHeight(a0)
		clr.w	obVelX(a0)
		clr.w	obVelY(a0)
		clr.b	obAniFrame(a0)
		clr.b	obTimeFrame(a0)
		move.l	#MS_Landed,MS_callback(a0)
		jsr	(RandomNumber).l
		tst.w	d0
		bmi.s	MS_loc_7B4CA
		bclr	#4,MS_history(a0)
		bne.s	MS_loc_7B4CA
		move.l	#MS_AnimLandingRoll,MS_script(a0)
		bclr	#3,MS_flags(a0)
		rts
; ---------------------------------------------------------------------------

MS_loc_7B4CA:
		move.l	#MS_AnimLandingTurn,MS_script(a0)
		bset	#3,MS_flags(a0)
		rts
; ---------------------------------------------------------------------------

MS_Landing:
		bsr.w	MS_CheckLandingCamper
		btst	#MS_diving_bit,MS_flags(a0)
		bne.s	.counter
		jsr	MS_RawAnimate(pc)
		jsr	(ObjectMoveAndFall_LightGravity).l
		jmp	MS_FloorCallback(pc)
.counter:
		jsr	MS_RawAnimate(pc)
		jsr	(ObjectMove).l
		jmp	MS_FloorCallback(pc)

; Commit once, like the super rematch's aimed $800-speed rolling dive.
; Both active actors count, but released dashes, air rolls and dead actors do not.
MS_CheckLandingCamper:
		btst	#MS_diving_bit,MS_flags(a0)
		bne.w	MS_Return
		lea	(v_player).w,a1
		bsr.s	.player
		btst	#MS_diving_bit,MS_flags(a0)
		bne.w	MS_Return
		tst.w	(Player_mode).w
		bne.w	MS_Return
		lea	(v_player2).w,a1
.player:
		tst.l	code(a1)
		beq.w	MS_Return
		cmpi.b	#6,obRoutine(a1)
		bhs.w	MS_Return
		tst.b	spindash_flag(a1)
		beq.w	MS_Return
		cmpi.b	#AniIDSonAni_Spindash,obAnim(a1)
		bne.w	MS_Return
		btst	#status.player.in_air,obStatus(a1)
		bne.w	MS_Return
		tst.w	obVelX(a1)
		bne.w	MS_Return
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		addi.w	#MS_CampRadius,d0
		cmpi.w	#MS_CampRadius*2,d0
		bhi.w	MS_Return
		move.w	obY(a1),d1
		sub.w	obY(a0),d1
		cmpi.w	#MS_CampHeight,d1
		bhi.w	MS_Return
		; Aim at the rolling body's floor height, not the player's centre.
		moveq	#0,d0
		move.b	obHeight(a1),d0
		add.w	d0,d1
		subi.w	#$F,d1
		cmpi.w	#MS_CampMinDrop,d1
		blt.w	MS_Return
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		muls.w	#$800,d0
		divs.w	d1,d0
		move.w	d0,obVelX(a0)
		move.w	#$800,obVelY(a0)
		move.b	#$F,obHeight(a0)
		bset	#MS_diving_bit,MS_flags(a0)
		move.b	#3,obFrame(a0)
		lea	MS_AnimRoll(pc),a1
		bsr.w	MS_SetRawAnimation
		move.l	#MS_CounterLanded,MS_callback(a0)
		move.w	#sfx_Roll,d0
		jmp	(PlaySound_Special).l

MS_CounterLanded:
		bclr	#MS_diving_bit,MS_flags(a0)
		subi.w	#$10,obY(a0)
		move.b	#$1F,obHeight(a0)
		clr.l	obVelX(a0)
		move.b	#8,obFrame(a0)
		; Continue the ordinary landing, with feet fixed at the same floor.
; ---------------------------------------------------------------------------

MS_Landed:
		bset	#MS_grounded_bit,MS_flags(a0)
		move.b	#$E,obRoutine(a0)
		clr.w	obYSub(a0)
		clr.b	obAniFrame(a0)
		clr.b	obTimeFrame(a0)
		moveq	#signextendB(SndID_MechaLand),d0
		jsr	(PlaySound_Special).l
		btst	#3,MS_flags(a0)
		bne.s	MS_TurnLanding
		move.l	#MS_AnimGroundWindup,MS_script(a0)
		move.l	#MS_StartGroundDash,MS_callback(a0)
		rts
; ---------------------------------------------------------------------------

MS_TurnLanding:
		bchg	#0,render_flags(a0)
		move.b	#1,mapping_frame(a0)
		move.l	#MS_AnimTurnStand,MS_script(a0)
		move.l	#MS_PrepareJump,MS_callback(a0)
		rts
; ---------------------------------------------------------------------------

MS_Animate:
		jmp	MS_RawAnimate(pc)
; ---------------------------------------------------------------------------

MS_StartGroundDash:
		move.b	#$10,obRoutine(a0)
		move.w	#$820,d0
		move.w	#-$20,d1
		btst	#0,render_flags(a0)
		beq.s	MS_loc_7B55E
		neg.w	d0
		neg.w	d1

MS_loc_7B55E:
		move.w	d0,obVelX(a0)
		move.w	d1,MS_accel(a0)
		clr.w	obVelY(a0)
		bset	#2,MS_flags(a0)
		lea	MS_JetsDash(pc),a2
		jmp	MS_CreateJets(pc)
; ---------------------------------------------------------------------------

MS_PrepareJump:
		move.b	#$14,obRoutine(a0)
		move.l	#MS_AnimJumpCrouch,MS_script(a0)
		move.l	#MS_StartJump,MS_callback(a0)
		move.w	(Camera_X_pos).w,d0
		addi.w	#$A0,d0
		bset	#0,render_flags(a0)
		cmp.w	x_pos(a0),d0
		bhs.s	.return
		bclr	#0,render_flags(a0)
.return:	rts
; ---------------------------------------------------------------------------

MS_GroundDash:
		move.w	MS_accel(a0),d0
		add.w	d0,obVelX(a0)
		jsr	(ObjectMove).l
		lea	MS_StopGroundDash(pc),a1
		bra.w	MS_CheckBoundary
; ---------------------------------------------------------------------------

MS_StopGroundDash:
		move.b	#$12,obRoutine(a0)
		move.w	d0,x_pos(a0)
		clr.w	obXSub(a0)
		bclr	#2,MS_flags(a0)
		move.l	#MS_AnimDashStop,MS_script(a0)
		move.l	#MS_PrepareJump,MS_callback(a0)
		rts
; ---------------------------------------------------------------------------

MS_StartJump:
		bclr	#MS_grounded_bit,MS_flags(a0)
		clr.b	MS_head_hits(a0)
		move.b	#$F,obHeight(a0)
		lea	MS_AnimJumpRoll(pc),a1
		jsr	MS_SetRawAnimation(pc)
		move.w	#$200,d0
		btst	#0,render_flags(a0)
		bne.s	MS_loc_7B606
		neg.w	d0

MS_loc_7B606:
		move.w	d0,obVelX(a0)
		move.w	#-$600,obVelY(a0)
		move.b	MS_attack_count(a0),d0
		addq.b	#1,MS_attack_count(a0)
		andi.w	#7,d0
		moveq	#0,d1
		move.b	MS_byte_7B62E(pc,d0.w),d1
		move.b	d1,MS_attack(a0)
		move.b	MS_byte_7B636(pc,d1.w),obRoutine(a0)
		rts
; ---------------------------------------------------------------------------
MS_byte_7B62E:
		dc.b    0,   1,   2,   0,   1,   2,   0,   1
MS_byte_7B636:
		dc.b  $16, $1A, $1E
		even
; ---------------------------------------------------------------------------

MS_JumpDashRise:
		jsr	MS_RawAnimate(pc)
		jsr	(ObjectMoveAndFall).l
		tst.w	obVelY(a0)
		bpl.s	MS_StartAirDash
		rts
; ---------------------------------------------------------------------------

MS_StartAirDash:
		move.b	#$18,obRoutine(a0)
		move.w	#$780,d0
		moveq	#-$20,d1
		btst	#0,render_flags(a0)
		bne.s	MS_loc_7B666
		neg.w	d0
		neg.w	d1

MS_loc_7B666:
		move.w	d0,obVelX(a0)
		move.w	d1,MS_accel(a0)
		clr.w	obVelY(a0)
		moveq	#signextendB(sfx_Dash),d0
		jmp	(PlaySound_Special).l
; ---------------------------------------------------------------------------

MS_AirDash:
		jsr	MS_RawAnimate(pc)
		move.w	MS_accel(a0),d0
		add.w	d0,obVelX(a0)
		jsr	(ObjectMove).l
		lea	MS_StopAirDash(pc),a1
		bra.w	MS_CheckBoundary
; ---------------------------------------------------------------------------

MS_StopAirDash:
		move.w	d0,x_pos(a0)
		bra.w	MS_PauseSweep
; ---------------------------------------------------------------------------

MS_BounceApproach:
		jsr	MS_RawAnimate(pc)
		jsr	(ObjectMoveAndFall).l
		tst.w	obVelY(a0)
		bmi.s	.return
		jsr	(ObjHitFloor).l
		tst.w	d1
		bmi.s	MS_Bounce
		beq.s	MS_Bounce
.return:	rts
; ---------------------------------------------------------------------------

MS_Bounce:
		add.w	d1,y_pos(a0)
		move.b	#$1C,obRoutine(a0)
		move.w	#-$900,obVelY(a0)
		moveq	#signextendB(SndID_Thump),d0
		jmp	(PlaySound_Special).l
; ---------------------------------------------------------------------------

MS_BounceFlight:
		jsr	MS_RawAnimate(pc)
		jsr	(ObjectMoveAndFall).l
		lea	MS_PauseSweep(pc),a1
		bra.w	MS_CheckBoundary
; ---------------------------------------------------------------------------

MS_ReboundApproach:
		jsr	MS_RawAnimate(pc)
		jsr	(ObjectMoveAndFall).l
		tst.w	obVelY(a0)
		bmi.s	MS_locret_7B70C
		jsr	(ObjHitFloor).l
		tst.w	d1
		bmi.s	MS_ReboundLand
		beq.s	MS_ReboundLand

MS_locret_7B70C:
		rts
; ---------------------------------------------------------------------------

MS_ReboundLand:
		bset	#MS_grounded_bit,MS_flags(a0)
		add.w	d1,y_pos(a0)
		move.b	#$20,obRoutine(a0)
		move.w	#$F,MS_timer(a0)
		move.l	#MS_ReboundBackoff,MS_callback(a0)
		bset	#2,MS_flags(a0)
		moveq	#signextendB(SndID_MechaLand),d0
		jsr	(PlaySound_Special).l
		lea	MS_JetsLand(pc),a2
		jmp	MS_CreateJets(pc)
; ---------------------------------------------------------------------------

MS_ReboundWait:
		jsr	MS_RawAnimate(pc)
		jmp	MS_WaitCallback(pc)
; ---------------------------------------------------------------------------

MS_ReboundBackoff:
		move.b	#$22,obRoutine(a0)
		move.w	#$100,d0
		tst.w	obVelX(a0)
		bmi.s	MS_loc_7B766
		neg.w	d0

MS_loc_7B766:
		move.w	d0,obVelX(a0)
		clr.w	obVelY(a0)
		move.w	#7,MS_timer(a0)
		move.l	#MS_ReboundDashStart,MS_callback(a0)
		rts
; ---------------------------------------------------------------------------

MS_BackoffMove:
		jsr	MS_RawAnimate(pc)
		jsr	(ObjectMove).l
		jmp	MS_WaitCallback(pc)
; ---------------------------------------------------------------------------

MS_ReboundDashStart:
		move.b	#$24,obRoutine(a0)
		move.w	#$640,d0
		move.w	#-$20,d1
		tst.w	obVelX(a0)
		bmi.s	MS_loc_7B7A8
		neg.w	d0
		neg.w	d1

MS_loc_7B7A8:
		move.w	d0,obVelX(a0)
		move.w	d1,MS_accel(a0)
		moveq	#signextendB(sfx_Dash),d0
		jmp	(PlaySound_Special).l
; ---------------------------------------------------------------------------

MS_ReboundDash:
		jsr	MS_RawAnimate(pc)
		move.w	MS_accel(a0),d0
		add.w	d0,obVelX(a0)
		jsr	(ObjectMove).l
		lea	MS_ReboundDashStop(pc),a1
		bra.w	MS_CheckBoundary
; ---------------------------------------------------------------------------

MS_ReboundDashStop:
		move.b	#$26,obRoutine(a0)
		move.w	#$F,MS_timer(a0)
		move.l	#MS_ReboundJump,MS_callback(a0)
		rts
; ---------------------------------------------------------------------------

MS_ReboundJump:
		bclr	#MS_grounded_bit,MS_flags(a0)
		clr.b	MS_head_hits(a0)
		move.b	#$28,obRoutine(a0)
		bclr	#2,MS_flags(a0)
		clr.w	obVelX(a0)
		move.w	#-$640,obVelY(a0)
		rts
; ---------------------------------------------------------------------------

MS_ReboundRise:
		jsr	MS_RawAnimate(pc)
		jsr	(ObjectMoveAndFall).l
		tst.w	obVelY(a0)
		bpl.w	MS_PauseSweep
		rts
; ---------------------------------------------------------------------------

MS_AnimLandingRoll:
		dc.b    3,   0
		dc.b    4,   1
		dc.b    5,   2
		dc.b    6,   3
		dc.b    7,   4
		dc.b    8,   5
		dc.b  $F8, .jump-MS_AnimLandingRoll

.jump:
		dc.b    8, $7F
		dc.b  $FC
MS_AnimLandingTurn:
		dc.b    3,   0
		dc.b    4,   1
		dc.b    5,   2
		dc.b    6,   3
		dc.b    7,   4
		dc.b    8,   4
		dc.b    9,   4
		dc.b   $A,   4
		dc.b   $B,   4
		dc.b   $C,   4
		dc.b  $F8, .jump-MS_AnimLandingTurn

.jump:
		dc.b   $C, $7F
		dc.b  $FC
MS_AnimRoll:
		dc.b    3,   0
		dc.b    4,   0
		dc.b    5,   0
		dc.b  $FC
MS_AnimJumpCrouch:
		dc.b    0,   0
		dc.b    1,   5
		dc.b    2,   9
		dc.b    1,   0
		dc.b  $F4
MS_AnimJumpRoll:
		dc.b    1,   0
		dc.b    1,   1
		dc.b    3,   1
		dc.b    4,   1
		dc.b    5,   1
		dc.b  $F8, MS_AnimRoll-MS_AnimJumpRoll
MS_AnimGroundWindup:
		dc.b    1,   5
		dc.b    2, $1F
		dc.b  $F4
MS_AnimDashStop:
		dc.b    2,   0
		dc.b    1,   5
		dc.b    0, $3F
		dc.b  $F4
MS_AnimTurnStand:
		dc.b    1,   5
		dc.b    2,   9
		dc.b    1,   5
		dc.b    0, $3F
		dc.b  $F4
MS_AnimDefeat:
		dc.b   $E,   5
		dc.b   $E,   5
		dc.b   $F,   3
		dc.b  $F8, .jump-MS_AnimDefeat

.jump:
		dc.b   $F, $7F
		dc.b  $FC

MS_Collision:
		dc.b  $23
		dc.b  $23
		dc.b    9
		dc.b  $86
		dc.b  $86
		dc.b  $86
		dc.b  $86
		dc.b  $1A
		dc.b  $23
		dc.b  $23
		dc.b  $23
		dc.b  $23
		dc.b  $23
		dc.b  $23
		dc.b    9
		dc.b    0
		dc.b    9
		dc.b  $23
		dc.b    6
		dc.b  $23
		dc.b  $23
		dc.b  $23
		even


MS_HeadData:
		dc.b  $10, -$C, ($80|Touch_Size_MechaHead_ID),   2
		dc.b  $10,  -4, ($80|Touch_Size_MechaHead_ID),   2
		dc.b  $10,   0, ($80|Touch_Size_MechaHead_ID),   2
		dc.b    0,   0,   0,   0
		dc.b    0,   0,   0,   0
		dc.b    0,   0,   0,   0
		dc.b    0,   0,   0,   0
		dc.b  $14,  -8, $9E,   1
		dc.b  $10, -$C, $9E,   1
		dc.b   $C,-$14, $98,   0
		dc.b    0,-$14, ($80|Touch_Size_MechaFront_ID),   8
		dc.b  -$C,-$14, $98,   0
		dc.b -$10, -$C, ($80|Touch_Size_MechaHead_ID),   2
		dc.b  $10, -$C, ($80|Touch_Size_MechaHead_ID),   2
		dc.b  $10,   4, ($80|Touch_Size_MechaHead_ID),   2
		dc.b  $14,  $C, ($80|Touch_Size_MechaHead_ID),   2
		dc.b  $17,   5, ($80|Touch_Size_MechaHead_ID),   2
		dc.b  $10, -$C, ($80|Touch_Size_MechaHead_ID),   2
		dc.b   $C, -$C, $9E,   1
		dc.b  $10, -$C, ($80|Touch_Size_MechaHead_ID),   2
		dc.b  $10, -$C, ($80|Touch_Size_MechaHead_ID),   2
		dc.b  $10, -$C, ($80|Touch_Size_MechaHead_ID),   2
		even


; Shared raw-script operations retain S3&K's delay-before-advance semantics.
MS_SetRawAnimation:
        move.l  a1,MS_script(a0)
        clr.b   obAniFrame(a0)
        clr.b   obTimeFrame(a0)
        rts
MS_RawAnimate:
        movea.l MS_script(a0),a1
        subq.b  #1,obTimeFrame(a0)
        bpl.w   MS_Return
        moveq   #0,d0
        move.b  obAniFrame(a0),d0
        addq.w  #2,d0
        move.b  d0,obAniFrame(a0)
        move.b  (a1,d0.w),d1
        bmi.s   .command
        move.b  d1,obFrame(a0)
        move.b  1(a1,d0.w),obTimeFrame(a0)
        rts
.command:
        cmpi.b  #$F4,d1
        beq.s   .callback
        cmpi.b  #$F8,d1
        bne.s   .loop
        move.b  1(a1,d0.w),d1
        ext.w   d1
        lea     (a1,d1.w),a1
        move.l  a1,MS_script(a0)
.loop:
        move.b  (a1),obFrame(a0)
        move.b  1(a1),obTimeFrame(a0)
        clr.b   obAniFrame(a0)
        rts
.callback:
        clr.b   obTimeFrame(a0)
        movea.l MS_callback(a0),a1
        jsr     (a1)
        clr.b   obAniFrame(a0)
        rts
MS_WaitCallback:
        subq.w  #1,MS_timer(a0)
        bpl.w   MS_Return
        movea.l MS_callback(a0),a1
        jmp     (a1)
MS_FloorCallback:
        tst.w   obVelY(a0)
        bmi.w   MS_Return
        jsr     (ObjHitFloor).l
        tst.w   d1
        bgt.w   MS_Return
        add.w   d1,obY(a0)
        movea.l MS_callback(a0),a1
        jmp     (a1)
MS_CheckBoundary:
        tst.w   obVelX(a0)
        bmi.s   .left
        move.w  MS_right(a0),d0
        cmp.w   obX(a0),d0
        bls.s   .reached
        rts
.left:
        move.w  MS_left(a0),d0
        cmp.w   obX(a0),d0
        bhs.s   .reached
        rts
.reached:
        jmp     (a1)