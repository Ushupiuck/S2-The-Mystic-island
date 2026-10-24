; ---------------------------------------------------------------------------
; Object 60 - Caterkiller and Kemusi enemies (MZ, SBZ)
; ---------------------------------------------------------------------------

Caterkiller:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Cat_Index(pc,d0.w),d1
		jmp	Cat_Index(pc,d1.w)
; ===========================================================================
Cat_Index:	dc.w Cat_Main-Cat_Index
		dc.w Cat_Head-Cat_Index
		dc.w Cat_Body-Cat_Index
		dc.w Cat_Body-Cat_Index
		dc.w Cat_Body-Cat_Index
		dc.w Cat_Delete-Cat_Index
		dc.w Cat_Scatter-Cat_Index
; ===========================================================================
cat_wait_time	= obAniFrame		; 1 byte; delay between moves
cat_mode	= obAnim		; bit 4 = gait phase, bit 7 = animate
cat_path_credit	= obXSub		; grounded only: word of unspent trail distance (8.8)
cat_floormap	= objoff_30		; 8 bytes; 16 packed 4-bit path entries
cat_start_children = objoff_38		; head only: 3 word pointers, overlaps body-only links
cat_head	= objoff_38		; word; head pointer while a body piece is landing
cat_gait_max	= objoff_3A		; body only: word; full gait rate ($C0, or $60 damaged)
cat_parent	= objoff_3C		; word; preceding object, sign-extended when loaded
cat_segment_pos	= objoff_3E		; byte; next entry in the floor buffer
cat_landed	= objoff_3F		; head only: number of pieces that have landed
cat_next_step	= obPrevAni		; 1 byte; head's cached next step ($FF = not prepared)
cat_pending_y	= obVelY		; grounded head only: remaining vertical steps
cat_anchor_delta = obVelY		; grounded body only: parent radius minus this radius
cat_seed_index	= obAngle		; head only, before animation: next startup child (0/2/4)
cat_gait_rate	= obVelX		; grounded body only: its positive, unmirrored gait rate
cat_kemusi_body_col = $80+((Touch_Size_KemusiBody-Touch_Sizes)/2)+1
; ===========================================================================
; All private state fits the original $40-byte SST. The engine's larger stride
; is shared with other objects; Caterkiller does not use its bytes $40 onward.
; Word links require the object pool to remain in the upper 32K of work RAM.
; The packed RAM base is a forward size expression; validate after pass 1.
	if (MOMPASS>1)&&((v_objspace&$FF8000)<>$FF8000)
		fatal "Caterkiller word links require object RAM above $FF8000"
	endif
	if (MOMPASS>1)&&(((v_objend-1)&$FF8000)<>$FF8000)
		fatal "Caterkiller word links must stay in work RAM"
	endif
; ===========================================================================
; One entry now describes one small path step, rather than a potentially
; large Y change for one X pixel. Diagonals cost sqrt(2) pixels of distance;
; horizontal/vertical steps cost one. The original 8..12-pixel gait thus
; measures distance along the trail, even on steep curves.
cat_floor_flat	= 0			; one horizontal pixel
cat_floor_up	= 1			; one horizontal pixel and one pixel up
cat_floor_down	= 2			; one horizontal pixel and one pixel down
cat_floor_turn	= 3			; turn marker
cat_floor_vup	= 5			; one pixel up, no horizontal movement
cat_floor_vdown	= 6			; one pixel down, no horizontal movement
cat_step_cost	= $100			; one pixel in 8.8 fixed point
cat_diag_cost	= $16A			; sqrt(2) pixels, rounded to 8.8
; ===========================================================================

Cat_Main:	; Routine 0
		cmpi.w	#2,obSubtype(a0)	; 0 = Caterkiller, 1 = Kemusi, 2 = damaged Kemusi
		bls.s	.subtype
		move.w	#2,obSubtype(a0)
.subtype:
		move.b	#7,obHeight(a0)
		move.b	#8,obWidth(a0)
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Cat,obMap(a0)
		move.b	#Map_Cat_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_SBZ_Caterkiller,1,0),obGfx(a0)
		cmpi.b	#id_SMZ,(v_zone).w	; if level is SBZ, branch
		beq.s	.isscrapbrain
		move.w	#make_art_tile(ArtTile_MZ_SYZ_Caterkiller,1,0),obGfx(a0)

.isscrapbrain:
		andi.b	#3,obRender(a0)
		ori.b	#4,obRender(a0)
		move.b	obRender(a0),obStatus(a0)
		move.w	#$200,obPriority(a0)
		cmpi.b	#id_SMZ,(Current_Zone).w
		bne.s	.catAtlasReady
		move.l	#Map_SMZ_Cat,obMap(a0)
		move.b	#Map_SMZ_Cat_height,height_pixels(a0)
		move.w	#ArtTile_SMZ_Atlas,obGfx(a0)
.catAtlasReady:
		move.b	#sprite_bound(8,Map_Cat_width),obActWid(a0)
		move.b	#$B,obColType(a0)
		tst.w	obSubtype(a0)
		beq.s	.artready
		move.l	#Map_Kemusi,obMap(a0)
		move.b	#Map_Kemusi_height,height_pixels(a0)
		move.b	#sprite_bound(8,Map_Kemusi_width),obActWid(a0)
		move.w	#make_art_tile(ArtTile_SMZ_Kemusi,1,0),obGfx(a0)
		move.b	#12,obHeight(a0)
		move.b	#1,obFrame(a0)
.artready:

		; airborne / dormant start
		clr.b	cat_mode(a0)
		clr.w	obVelX(a0)
		clr.w	obVelY(a0)
		clr.w	obXSub(a0)
		clr.w	obYSub(a0)
		clr.l	cat_floormap(a0)
		clr.l	cat_floormap+4(a0)
		clr.b	cat_landed(a0)
		move.b	#$FF,cat_next_step(a0)

		move.w	obX(a0),d2
		moveq	#$C,d5
		btst	#0,obStatus(a0)
		beq.s	.noflip
		neg.w	d5

.noflip:
		lea	cat_start_children(a0),a3
		moveq	#4,d4
		moveq	#4,d6			; starting routine (Cat_BodySeg1)
		movea.l	a0,a2			; a2 = current parent (starts as head)
		moveq	#2,d1			; spawn 3 segments

Cat_Loop:
		jsr	(FindNextFreeObj).l
		bne.w	Cat_ChkGone
		move.l	#Caterkiller,code(a1)
		move.b	d6,obRoutine(a1)	; goto Cat_BodySeg1 or Cat_BodySeg2
		addq.b	#2,d6			; alternate between the two
		move.l	obMap(a0),obMap(a1)
		move.b	height_pixels(a0),height_pixels(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.w	#$280,obPriority(a1)
		move.b	obActWid(a0),obActWid(a1)
		move.b	#7,obHeight(a1)
		move.b	#8,obWidth(a1)
		move.b	#$CB,obColType(a1)

		clr.w	obVelX(a1)
		clr.w	obVelY(a1)
		clr.b	cat_mode(a1)
		move.b	#$80,ob2ndRout(a1)	; negative secondary state = independent landing
		clr.w	obXSub(a1)
		clr.w	obYSub(a1)

		add.w	d5,d2
		move.w	d2,obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obStatus(a0),obRender(a1)
		move.b	#8,obFrame(a1)
		move.w	obSubtype(a0),obSubtype(a1)
		beq.s	.bodyready
		move.b	#3,obFrame(a1)
		move.b	#$B,obColType(a1)	; the damaged, unarmored body can be attacked
		cmpi.w	#2,obSubtype(a1)
		beq.s	.bodyready
		move.b	#2,obFrame(a1)
		move.b	#11,obHeight(a1)
		move.b	#cat_kemusi_body_col,obColType(a1)	; intact spikes hurt without S1 fragmentation
.bodyready:
		move.w	a0,cat_head(a1)
		move.w	a2,cat_parent(a1)
		move.w	a1,(a3)+
		move.b	d4,cat_segment_pos(a1)
		clr.l	cat_floormap(a1)
		clr.l	cat_floormap+4(a1)

		addq.b	#4,d4
		movea.l	a1,a2
		dbf	d1,Cat_Loop

		move.b	#7,cat_wait_time(a0)
		clr.b	cat_segment_pos(a0)
		; start Cat_Head in airborne state
		clr.b	ob2ndRout(a0)

Cat_Head:	; Routine 2
		tst.w	obSubtype(a0)
		beq.s	.head
		; Kemusi's damaged body is also a weak point. A defeat anywhere
		; consumes the group, while a lost/unloaded piece releases its owner.
		lea	cat_start_children(a0),a2
		moveq	#2,d0
.checkgroup:
		movea.w	(a2)+,a1
		cmpi.l	#Explosion,code(a1)
		beq.w	Cat_Delete
		cmpi.l	#Caterkiller,code(a1)
		bne.w	Cat_ChkGone
		dbf	d0,.checkgroup
.head:
		tst.b	obStatus(a0)
		bmi.w	loc_16C96
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		lea	Cat_Index2(pc),a1
		move.w	(a1,d0.w),d1
		jsr	(a1,d1.w)
		tst.w	obSubtype(a0)
		bne.s	.kemusianim
		move.b	cat_mode(a0),d1
		bpl.s	.display
		lea	Ani_Cat(pc),a1
		move.b	obAngle(a0),d0
		andi.w	#$7F,d0
		addq.b	#4,obAngle(a0)
		move.b	(a1,d0.w),d0
		bmi.s	.stopanim

.animate:
		andi.b	#$10,d1
		add.b	d1,d0
		move.b	d0,obFrame(a0)

.display:
		out_of_range.w	Cat_ChkGone
		bra.w	DisplaySprite

.stopanim:
		bclr	#7,cat_mode(a0)
		out_of_range.w	Cat_ChkGone
		bra.w	DisplaySprite

.kemusianim:
		move.b	cat_mode(a0),d0
		lsr.b	#4,d0
		andi.b	#1,d0
		eori.b	#1,d0
		move.b	d0,obFrame(a0)
		bra.s	.display

Cat_ChkGone:
		move.w	respawn_addr(a0),d0
		beq.s	.delete
		jsr	(MCD_RespawnRelease).l

.delete:	move.b	#$A,obRoutine(a0)	; goto Cat_Delete next
		rts
; ===========================================================================

Cat_Delete:	; Routine $A
		bra.w	DeleteObject
; ===========================================================================
Cat_Index2:
		dc.w .airborne-Cat_Index2
		dc.w .wait-Cat_Index2
		dc.w loc_16B02-Cat_Index2
		dc.w .settle-Cat_Index2
		dc.w .settle-Cat_Index2
; ===========================================================================
.endmove:
		subq.b	#2,ob2ndRout(a0)
		move.b	#7,cat_wait_time(a0)
		clr.w	obVelX(a0)
		rts
; ===========================================================================
.airborne:
		cmpi.w	#$7FF,obY(a0)	; a piece over a pit must not wrap around the level
		bhi.w	Cat_ChkGone
		bsr.w	Cat_FallPart
		tst.w	d1
		bpl.s	.return
		addq.b	#1,cat_landed(a0)
		move.b	#6,ob2ndRout(a0)
.return:	rts
; ===========================================================================
.settle:
		; Like Kemusi, every piece finds its own floor before crawling.
		; Check the startup links too, so a lost child cannot leave us waiting.
		lea	cat_start_children(a0),a2
		moveq	#2,d0
.checkchild:
		movea.w	(a2)+,a1
		cmpi.l	#Caterkiller,code(a1)
		bne.w	Cat_ChkGone
		cmpi.b	#$A,obRoutine(a1)
		bhs.w	Cat_ChkGone
		dbf	d0,.checkchild
		cmpi.b	#4,cat_landed(a0)
		bne.s	.return
		cmpi.b	#8,ob2ndRout(a0)
		beq.w	Cat_StartCrawl
		move.b	#8,ob2ndRout(a0)
		clr.b	cat_seed_index(a0)
		bra.w	Cat_StartCrawl
; ===========================================================================
.wait:
		subq.b	#1,cat_wait_time(a0)
		bpl.s	.return

.move:
		addq.b	#2,ob2ndRout(a0)
		move.b	#$10,cat_wait_time(a0)
		move.w	#-$C0,obVelX(a0)
		cmpi.w	#2,obSubtype(a0)
		bne.s	.phase
		move.w	#-$60,obVelX(a0)
.phase:
		bchg	#4,cat_mode(a0)
		bne.s	loc_16AFC
		clr.w	obVelX(a0)

loc_16AFC:
		bset	#7,cat_mode(a0)

loc_16B02:
		subq.b	#1,cat_wait_time(a0)
		bmi.w	Cat_Index2.endmove
		move.w	obVelX(a0),d0
		beq.w	Cat_Index2.return
; Spend the head's crawl speed as distance along a trail of small steps.
; A floor delta of e.g. +5 becomes one down-diagonal followed by four
; vertical steps. Each child replays those steps with the same distance
; costs, so horizontal separation shrinks naturally as the slope steepens.
; obVelY is gravity while airborne, and pending Y only after landing.
.path:
		neg.w	d0
		add.w	d0,cat_path_credit(a0)
		cmpi.w	#cat_step_cost,cat_path_credit(a0)
		blo.w	Cat_Index2.return
		moveq	#0,d1
		move.b	cat_next_step(a0),d1
		cmpi.b	#$FF,d1
		bne.w	.spend
		tst.w	cat_pending_y(a0)
		beq.w	.probe
		bmi.s	.verticalup
		moveq	#cat_floor_vdown,d1
		bra.s	.cache
.verticalup:
		moveq	#cat_floor_vup,d1
		bra.s	.cache

.probe:
		move.w	obX(a0),d3
		subq.w	#1,d3
		btst	#0,obStatus(a0)
		beq.s	.floor
		addq.w	#2,d3
.floor:
		jsr	(ObjHitFloor2).l		; probe next X without moving the head yet
		cmpi.w	#-8,d1
		blt.s	.turn
		cmpi.w	#$C,d1
		bge.s	.turn
		move.w	d1,cat_pending_y(a0)
		beq.s	.flat
		bmi.s	.up
		moveq	#cat_floor_down,d1
		bra.s	.cache
.up:
		moveq	#cat_floor_up,d1
		bra.s	.cache
.flat:
		moveq	#cat_floor_flat,d1
		bra.s	.cache
.turn:
		moveq	#cat_floor_turn,d1
.cache:
		move.b	d1,cat_next_step(a0)
.spend:
		move.w	#cat_step_cost,d2
		cmpi.w	#cat_floor_up,d1
		beq.s	.diagonal
		cmpi.w	#cat_floor_down,d1
		bne.s	.costready
.diagonal:
		move.w	#cat_diag_cost,d2
.costready:
		cmp.w	cat_path_credit(a0),d2
		bhi.s	.return
		sub.w	d2,cat_path_credit(a0)
		moveq	#0,d0
		move.b	cat_segment_pos(a0),d0
		bsr.w	Cat_WriteFloor
		bsr.w	Cat_ApplyPathStep
		addq.w	#1,d0
		andi.w	#$F,d0
		move.b	d0,cat_segment_pos(a0)
		move.b	#$FF,cat_next_step(a0)
		tst.w	cat_pending_y(a0)
		beq.s	.return
		bmi.s	.pendingup
		subq.w	#1,cat_pending_y(a0)
		rts
.pendingup:
		addq.w	#1,cat_pending_y(a0)
.return:	rts
; ===========================================================================

Cat_Body:	; Routines 4, 6, 8
		; Validate the link before reading animation, phase or trail data.
		; A destroyed/reused parent is not ours to modify or delete.
		movea.w	cat_parent(a0),a1
		cmpi.l	#Caterkiller,code(a1)
		bne.w	Cat_Delete
		cmpi.b	#$A,obRoutine(a1)
		bhs.w	Cat_ParentInactive
		tst.b	obStatus(a0)
		bmi.w	loc_16C90
		tst.b	ob2ndRout(a0)
		bmi.w	Cat_BodyLanding
		move.b	cat_mode(a1),cat_mode(a0)
		move.b	ob2ndRout(a1),ob2ndRout(a0)
		cmpi.b	#6,obRoutine(a0)
		bne.s	Cat_BodySeg1

Cat_BodySeg2:
		tst.w	obSubtype(a0)
		bne.s	Cat_BodySeg1
		tst.b	cat_mode(a0)
		bpl.s	Cat_BodySeg1
		lea	Ani_Cat(pc),a2
		move.b	obAngle(a0),d0
		andi.w	#$7F,d0
		addq.b	#4,obAngle(a0)
		tst.b	4(a2,d0.w)
		bpl.s	Cat_AniBody
		addq.b	#4,obAngle(a0)

Cat_AniBody:
		move.b	(a2,d0.w),d0
		addq.b	#8,d0
		move.b	d0,obFrame(a0)

Cat_BodySeg1:
		cmpi.b	#2,ob2ndRout(a0)
		beq.w	DisplaySprite
		; The index-derived rate is prepared once after landing. Mirroring
		; it reproduces both gait phases without propagating inertia fields.
		move.w	cat_gait_rate(a0),d0
		btst	#4,cat_mode(a0)
		bne.s	.rate
		move.w	cat_gait_max(a0),d1
		sub.w	d0,d1
		move.w	d1,d0
.rate:
		add.w	cat_path_credit(a0),d0
		move.w	d0,d6
.path:
		; Deferred credits remain spendable even in the zero-speed phase.
		cmpi.w	#cat_step_cost,d6
		blo.s	.display
		moveq	#0,d0
		move.b	cat_segment_pos(a0),d0
		cmp.b	cat_segment_pos(a1),d0	; never consume unwritten trail
		beq.s	.display
		bsr.w	Cat_ReadFloor
		move.w	d1,d2
		add.w	d2,d2
		move.w	Cat_StepCosts(pc,d2.w),d5
		cmp.w	d6,d5
		bhi.s	.display		; do not check spacing before we can afford the step
		bsr.w	Cat_CheckSpacing
		blo.s	.display
		sub.w	d5,d6
		bsr.w	Cat_WriteFloor
		bsr.w	Cat_ApplyPathStep
		addq.w	#1,d0
		andi.w	#$F,d0
		move.b	d0,cat_segment_pos(a0)
		bra.s	.path
.display:
		move.w	d6,cat_path_credit(a0)
		bra.w	DisplaySprite
Cat_ParentInactive:
		beq.w	Cat_Delete
		bra.w	loc_16C90
; ===========================================================================
Cat_StepCosts:
		dc.w cat_step_cost,cat_diag_cost,cat_diag_cost,cat_step_cost
		dc.w 0,cat_step_cost,cat_step_cost

Cat_BodyLanding:
		btst	#1,ob2ndRout(a0)
		bne.w	DisplaySprite
		cmpi.w	#$7FF,obY(a0)
		bhi.w	Cat_Delete
		bsr.w	Cat_FallPart
		tst.w	d1
		bpl.w	DisplaySprite
		move.b	#$82,ob2ndRout(a0)
		movea.w	cat_head(a0),a1
		addq.b	#1,cat_landed(a1)
		bra.w	DisplaySprite
; ===========================================================================
; Independent landing uses the existing 16.16 position pairs and gravity.
; out: d1 < 0 on contact; d0-d6/a1-a4 are scratch, as with ObjHitFloor.
Cat_FallPart:
		cmpi.w	#$800,obVelY(a0)
		bls.s	.floor
		move.w	#$800,obVelY(a0)
.floor:
		bsr.w	ObjectFall
		jsr	(ObjHitFloor).l
		bpl.s	.return
		add.w	d1,obY(a0)
		clr.w	obYSub(a0)
		clr.w	obVelY(a0)
.return:
		rts
; ===========================================================================
; Seed a real trail behind the settled head, at most four floor probes per
; frame. The group stays landed until all three links are ready. Spreading
; this startup work avoids a CPU spike; crawling adds no body floor probes.
Cat_StartCrawl:
		movem.l	d7/a0/a5-a6,-(sp)
		movea.l	a0,a5
		moveq	#0,d0
		move.b	cat_seed_index(a5),d0
		movea.w	cat_start_children(a5,d0.w),a0
		movea.w	cat_parent(a0),a6
		moveq	#3,d7
		bsr.s	Cat_SeedTrail
		tst.w	d0
		bmi.s	.failed
		beq.s	.done
		addq.b	#2,cat_seed_index(a5)
		cmpi.b	#6,cat_seed_index(a5)
		blo.s	.done
		lea	cat_start_children(a5),a2
		moveq	#2,d0
		move.w	#$C0,d2
		cmpi.w	#2,obSubtype(a5)
		bne.s	.startbody
		lsr.w	#1,d2
.startbody:
		movea.w	(a2)+,a1
		move.b	#2,ob2ndRout(a1)
		movea.w	cat_parent(a1),a3
		moveq	#0,d1
		move.b	obHeight(a3),d1
		sub.b	obHeight(a1),d1
		ext.w	d1
		move.w	d1,cat_anchor_delta(a1)
		move.w	d2,cat_gait_max(a1)
		moveq	#0,d1
		move.b	obRoutine(a1),d1
		subq.w	#2,d1
		lsl.w	#5,d1
		cmpi.w	#$C0,d2
		beq.s	.storerate
		lsr.w	#1,d1
.storerate:
		move.w	d1,cat_gait_rate(a1)
		dbf	d0,.startbody
		move.b	#2,ob2ndRout(a5)
		move.b	#7,cat_wait_time(a5)
		clr.b	obAngle(a5)
		bra.s	.done
.failed:
		movea.l	a5,a0
		bsr.w	Cat_ChkGone
.done:
		movem.l	(sp)+,d7/a0/a5-a6
		rts
; ===========================================================================
; Walk backward up to 12 pixels of terrain arc, recording forward commands
; in reverse order. Commit whole floor steps: stopping halfway through a
; vertical run would place a piece above/below its actual floor.
; in: a0 = child, a6 = parent, d7 = probe budget minus one; preserves a0/a5-a6
; out: d0 = -1 unsafe spacing / 0 unfinished / 1 finished
Cat_SeedTrail:
		cmpi.b	#$86,ob2ndRout(a0)
		beq.s	.probe
		move.b	#$86,ob2ndRout(a0)
		move.l	obX(a6),obX(a0)
		move.l	obY(a6),obY(a0)
		; Recorded deltas follow the floor. Different sprite radii need a
		; constant center offset, not a different movement/history format.
		moveq	#0,d0
		moveq	#0,d1
		move.b	obHeight(a6),d0
		move.b	obHeight(a0),d1
		sub.w	d1,d0
		add.w	d0,obY(a0)
		move.b	cat_segment_pos(a6),cat_segment_pos(a0)
		move.w	#12*cat_step_cost,cat_path_credit(a0)
		clr.l	cat_floormap(a0)
		clr.l	cat_floormap+4(a0)
.probe:
		cmpi.w	#cat_step_cost,cat_path_credit(a0)
		blo.w	.done
		dbf	d7,.next
		moveq	#0,d0
		rts
.next:
		move.w	obX(a0),d3
		addq.w	#1,d3
		btst	#0,obStatus(a0)
		beq.s	.floor
		subq.w	#2,d3
.floor:
		jsr	(ObjHitFloor2).l
		cmpi.w	#-8,d1
		blt.w	.done
		cmpi.w	#$C,d1
		bge.w	.done
		move.w	#cat_step_cost,d2
		tst.w	d1
		beq.s	.cost
		move.w	d1,d2
		bpl.s	.positive
		neg.w	d2
.positive:
		subq.w	#1,d2
		lsl.w	#8,d2
		addi.w	#cat_diag_cost,d2
.cost:
		cmp.w	cat_path_credit(a0),d2
		bhi.w	.done
		sub.w	d2,cat_path_credit(a0)
		addq.w	#1,obX(a0)
		btst	#0,obStatus(a0)
		beq.s	.positioned
		subq.w	#2,obX(a0)
.positioned:
		add.w	d1,obY(a0)
		move.w	d1,cat_pending_y(a0)
		beq.s	.flat
		bmi.s	.down
		moveq	#cat_floor_up,d1
		subq.w	#1,cat_pending_y(a0)
		bra.s	.diagonal
.down:
		moveq	#cat_floor_down,d1
		addq.w	#1,cat_pending_y(a0)
.diagonal:
		bsr.s	.write
.vertical:
		tst.w	cat_pending_y(a0)
		beq.w	.probe
		bmi.s	.vdown
		moveq	#cat_floor_vup,d1
		subq.w	#1,cat_pending_y(a0)
		bra.s	.vwrite
.vdown:
		moveq	#cat_floor_vdown,d1
		addq.w	#1,cat_pending_y(a0)
.vwrite:
		bsr.s	.write
		bra.s	.vertical
.flat:
		moveq	#cat_floor_flat,d1
		bsr.s	.write
		bra.w	.probe
.done:
		clr.w	cat_path_credit(a0)
		clr.w	obVelY(a0)
		move.b	#$82,ob2ndRout(a0)
		; A narrow ledge may offer less than 12px of floor behind us.
		; Require the same 8px minimum floor-anchor spacing as the crawl.
		move.w	obX(a6),d2
		sub.w	obX(a0),d2
		muls.w	d2,d2
		move.w	obY(a6),d3
		sub.w	obY(a0),d3
		moveq	#0,d4
		move.b	obHeight(a6),d4
		sub.b	obHeight(a0),d4
		ext.w	d4
		add.w	d4,d3
		muls.w	d3,d3
		add.l	d3,d2
		cmpi.l	#8*8,d2
		blo.s	.failed
		moveq	#1,d0
		rts
.failed:
		moveq	#-1,d0
		rts
.write:
		subq.b	#1,cat_segment_pos(a0)
		andi.b	#$F,cat_segment_pos(a0)
		moveq	#0,d0
		move.b	cat_segment_pos(a0),d0
		exg	a0,a6
		bsr.w	Cat_WriteFloor
		exg	a0,a6
		rts
; ===========================================================================
Cat_FragSpeed:
		dc.w -$200				; head x speed
		dc.w -$180				; body x speed
		dc.w $180				; body x speed
		dc.w $200				; body x speed
; ===========================================================================

loc_16C90:
		bset	#7,obStatus(a1)

loc_16C96:
		clr.w	obXSub(a0)		; retire the grounded distance budget before 16.16 motion
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Cat_FragSpeed-2(pc,d0.w),d0
		btst	#0,obStatus(a0)
		beq.s	loc_16CAA
		neg.w	d0

loc_16CAA:
		move.w	d0,obVelX(a0)
		move.w	#-$400,obVelY(a0)
		move.b	#$C,obRoutine(a0)
		andi.b	#$F8,obFrame(a0)

Cat_Scatter:	; Routine $C
		bsr.w	ObjectFall
		tst.w	obVelY(a0)
		bmi.s	loc_16CE0
		jsr	(ObjHitFloor).l
		bpl.s	loc_16CE0
		add.w	d1,obY(a0)
		move.w	#-$400,obVelY(a0)

loc_16CE0:
		tst.b	obRender(a0)
		bpl.w	Cat_ChkGone
		bra.w	DisplaySprite
; ===========================================================================
; Check the proposed body position before consuming a trail entry.
; A curved/stepped trail can be eight pixels long while its endpoints are
; closer together. Keep at least eight pixels between like-facing floor
; anchors; equal radii reduce this to the original center-distance check.
; During a reversal, retain the original delayed turn through the chain.
; in: d1.w = step, a1 = parent; out: carry set if the step is too close
; preserves d0/d1/a0/a1; clobbers d2/d3/a2
Cat_CheckSpacing:
		cmpi.w	#cat_floor_turn,d1
		beq.s	.allow
		move.b	obStatus(a1),d2
		move.b	obStatus(a0),d3
		eor.b	d3,d2
		btst	#0,d2
		bne.s	.allow
		move.w	obX(a1),d2
		sub.w	obX(a0),d2
		btst	#2,d1			; vertical-only command
		bne.s	.xdistance
		addq.w	#1,d2
		btst	#0,obStatus(a0)
		beq.s	.xdistance
		subq.w	#2,d2
.xdistance:
		tst.w	d2
		bpl.s	.xpositive
		neg.w	d2
.xpositive:
		cmpi.w	#8,d2
		bhs.s	.allow
		; Most flat steps already have enough horizontal separation.
		; Only fetch/test Y when X alone cannot establish the minimum.
		move.w	obY(a1),d3
		sub.w	obY(a0),d3
		add.w	cat_anchor_delta(a0),d3
		tst.w	d1
		beq.s	.distance
		btst	#0,d1			; up/down is shared by diagonal and vertical commands
		bne.s	.up
		subq.w	#1,d3
		bra.s	.distance
.up:
		addq.w	#1,d3
.distance:
		tst.w	d3
		bpl.s	.ypositive
		neg.w	d3
.ypositive:
		cmpi.w	#8,d3
		bhs.s	.allow
		lea	.squares(pc),a2
		move.b	(a2,d2.w),d2
		move.b	(a2,d3.w),d3
		add.b	d3,d2
		cmpi.b	#8*8,d2
		rts
.allow:
		moveq	#0,d2			; clear carry
		rts
.squares:
		dc.b 0,1,4,9,16,25,36,49
; ===========================================================================
; Apply one recorded step, preserving d0/d1/a1 for cursor and parent handling.
; Grounded X subpixels hold cat_path_credit, rather than a position fraction.
; Turn markers consume one step's time but no movement, and propagate just
; like terrain. No X-subpixel mirroring is needed for distance-based motion.
Cat_ApplyPathStep:
		cmpi.w	#cat_floor_turn,d1
		beq.s	.turn
		btst	#2,d1
		bne.s	.vertical
		subq.w	#1,obX(a0)
		btst	#0,obStatus(a0)
		beq.s	.vertical
		addq.w	#2,obX(a0)
.vertical:
		tst.w	d1
		beq.s	.return
		btst	#0,d1
		bne.s	.up
		addq.w	#1,obY(a0)
.return:
		rts
.up:
		subq.w	#1,obY(a0)
		rts
.turn:
		bchg	#0,obStatus(a0)
		move.b	obStatus(a0),obRender(a0)
		rts
; ---------------------------------------------------------------------------
; Animation script - Caterkiller enemy (uses non-standard format)
; ---------------------------------------------------------------------------
Ani_Cat:	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 1
		dc.b 1,	1, 1, 1, 1, 1, 2, 2, 2,	2, 2, 3, 3, 3, 3, 3
		dc.b 4,	4, 4, 4, 4, 4, 5, 5, 5,	5, 5, 6, 6, 6, 6, 6
		dc.b 6,	6, 7, 7, 7, 7, 7, 7, 7,	7, 7, 7, $FF, 7, 7, $FF
		dc.b 7,	7, 7, 7, 7, 7, 7, 7, 7,	7, 7, 7, 7, 7, 7, 6
		dc.b 6,	6, 6, 6, 6, 6, 5, 5, 5,	5, 5, 4, 4, 4, 4, 4
		dc.b 4,	3, 3, 3, 3, 3, 2, 2, 2,	2, 2, 1, 1, 1, 1, 1
		dc.b 1,	1, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, $FF, 0, 0, $FF
		even
; ===========================================================================
; Read one of 16 packed path commands. Even entries use the high nibble.
; in: a1 = parent, d0.w = cursor; out: d1.w = command
; preserves d0/a0/a1; clobbers d2/a2
Cat_ReadFloor:
		move.w	d0,d2
		lsr.w	#1,d2
		lea	cat_floormap(a1),a2
		moveq	#0,d1
		move.b	(a2,d2.w),d1
		btst	#0,d0
		bne.s	.low
		lsr.b	#4,d1
.low:
		andi.w	#$F,d1
		rts
; ===========================================================================
; Write a command without disturbing its neighbour. Commands are 0..6.
; in: a0 = object, d0.w = cursor, d1.w = command
; preserves d0/d1/a1; clobbers d2-d3/a2
Cat_WriteFloor:
		move.w	d0,d2
		lsr.w	#1,d2
		lea	cat_floormap(a0),a2
		adda.w	d2,a2
		move.b	(a2),d2
		btst	#0,d0
		bne.s	.low
		andi.b	#$F,d2
		move.b	d1,d3
		lsl.b	#4,d3
		or.b	d3,d2
		move.b	d2,(a2)
		rts
.low:
		andi.b	#$F0,d2
		or.b	d1,d2
		move.b	d2,(a2)
		rts
