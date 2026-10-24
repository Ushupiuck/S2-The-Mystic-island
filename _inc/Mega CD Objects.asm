; ===========================================================================
; Mega-CD sub-68000 object placement manager and loader.
; S3&K Load_Sprites, sonicretro/skdisasm 73de97c6; RetroKoH/S1Fixed d29550bd.
; Resident placements, cursors and persistent state belong to CD. MD supplies
; free-slot bits and applies compact spawn records to its SSTs. Ordinary object
; behavior remains on MD. No SST or MD code pointer is dereferenced here.
; ===========================================================================

MCD_SubObjectsLoad:
		lea	(MCD_TerrainStage_Sub).l,a0
		lea	(MCD_ObjectBoundary_Sub).l,a1
		move.w	(MCD_SubMainArgument).l,d1
		cmpi.w	#MCD_ObjectPlacementCapacity,d1
		bhi.w	MCD_SubError
		lsr.w	#1,d1
		subq.w	#1,d1
.copy:
		move.w	(a0)+,(a1)+
		dbf	d1,.copy
		move.b	(MCD_SubMainCommand).l,(MCD_ObjectKeep_Sub).l
		clr.b	(MCD_ObjectRoutine_Sub).l
		st	(MCD_ObjectTimeZone_Sub).l
		bset	#0,(MCD_SubMemoryMode).l
		moveq	#0,d0
		rts

; Called as part of the terrain frame job, sharing its one Word-RAM handoff.
MCD_SubObjectsFrame:
		tst.b	(MCD_ObjectFrameEnabled_Sub).l
		beq.w	.return
		move.w	(MCD_ObjectFrameMinY_Sub).l,(MCD_ObjectMinY_Sub).l
		moveq	#0,d0
		move.b	(MCD_ObjectFrameTimeZone_Sub).l,d0
		cmp.b	(MCD_ObjectTimeZone_Sub).l,d0
		beq.s	.slots_ready
		cmpi.w	#4,d0
		bhs.w	MCD_SubError
		move.b	d0,(MCD_ObjectTimeZone_Sub).l
		lea	.time_masks(pc),a0
		move.b	(a0,d0.w),(MCD_ObjectTimeMask_Sub).l
		cmpi.w	#3,d0
		bne.s	.time_bank
		moveq	#2,d0			; good/bad Future share Sonic CD's Future state
.time_bank:
		mulu.w	#MCD_ObjectPlacementCount,d0
		lea	(MCD_ObjectRespawn_Sub).l,a0
		adda.w	d0,a0
		move.l	a0,(MCD_ObjectRespawnBase_Sub).l
		clr.b	(MCD_ObjectRoutine_Sub).l	; rescan this era even with a stationary camera
.slots_ready:
		lea	(MCD_ObjectFrameSlots_Sub).l,a2
		lea	(MCD_ObjectFreeSlots_Sub).l,a1
		moveq	#0,d0
		moveq	#0,d3
		move.w	#v_lvlobjspace,d2
.slots:
		move.w	d0,d1
		lsr.w	#3,d1
		btst	d0,(a2,d1.w)
		beq.s	.occupied
		move.w	d2,(a1)+
		addq.w	#1,d3
.occupied:
		addi.w	#object_size,d2
		addq.w	#1,d0
		cmpi.w	#MCD_ObjectSlotCount,d0
		blo.s	.slots
		move.w	d3,(MCD_ObjectFreeCount_Sub).l
		clr.w	(MCD_ObjectSpawnCount_Sub).l
		lea	(MCD_ObjectReply_Sub+4).l,a4
		bsr.w	MCD_SubObjects
		move.w	(MCD_ObjectSpawnCount_Sub).l,(MCD_ObjectReply_Sub).l
		moveq	#0,d0
		move.b	(MCD_ObjectRetry_Sub).l,d0
		move.w	d0,(MCD_ObjectReply_Sub+2).l
.return:
		rts
.time_masks:
		dc.b ObjectTime_Present,ObjectTime_Past,ObjectTime_Future,ObjectTime_Future

; Persistent-state service: index+1 in argument, operation in command high byte.
; 0 read, 1 set consumed bit, 2 release loaded bit, 3 capped bumper increment,
; 4 original placement X. Dynamic handle zero has no state and returns zero.
MCD_SubObjectState:
		moveq	#0,d0
		move.w	(MCD_SubMainArgument).l,d1
		beq.s	.return
		subq.w	#1,d1
		cmpi.w	#MCD_ObjectPlacementCount,d1
		bhs.w	MCD_SubError
		movea.l	(MCD_ObjectRespawnBase_Sub).l,a2
		move.b	(MCD_SubMainCommand).l,d2
		beq.s	.read
		subq.b	#1,d2
		beq.s	.consume
		subq.b	#1,d2
		beq.s	.release
		subq.b	#1,d2
		beq.s	.bump
		mulu.w	#omSize,d1
		lea	(MCD_ObjectPlacements_Sub).l,a2
		move.w	(a2,d1.w),d0
		rts
.consume:
		bset	#0,(a2,d1.w)
		bra.s	.read
.release:
		bclr	#7,(a2,d1.w)
		bra.s	.read
.bump:
		cmpi.b	#$8A,(a2,d1.w)
		blo.s	.increment
		moveq	#-1,d0
		rts
.increment:
		addq.b	#1,(a2,d1.w)
.read:
		move.b	(a2,d1.w),d0
.return:
		rts

MCD_SubObjects:
		tst.b	(MCD_ObjectRoutine_Sub).l
		bne.w	MCD_SubObjects_Main

MCD_SubObjects_Init:
		move.b	#2,(MCD_ObjectRoutine_Sub).l
		sf	(MCD_ObjectRetry_Sub).l
		tst.b	(MCD_ObjectKeep_Sub).l
		bne.s	.layout
		lea	(MCD_ObjectRespawn_Sub).l,a0
		moveq	#0,d0
		move.w	#bytesToLcnt(MCD_ObjectRespawn_SubEnd-MCD_ObjectRespawn_Sub),d1
.clear:
		move.l	d0,(a0)+
		dbf	d1,.clear
.layout:
		st	(MCD_ObjectKeep_Sub).l	; subsequent era changes retain all three banks
		lea	(MCD_ObjectPlacements_Sub).l,a0
		move.l	a0,(MCD_ObjectFront_Sub).l
		move.l	a0,(MCD_ObjectBack_Sub).l
		movea.l	(MCD_ObjectRespawnBase_Sub).l,a3
		move.w	(MCD_TerrainCamera_Sub).l,d6
		subi.w	#Object_Load_XBehind,d6
		bcc.s	.front
		moveq	#0,d6
.front:
		andi.w	#Object_Load_CoarseMask,d6
.seek_front:
		cmp.w	(a0),d6
		bls.s	.front_ready
		addq.w	#omSize,a0
		addq.w	#1,a3
		bra.s	.seek_front
.front_ready:
		move.l	a0,(MCD_ObjectFront_Sub).l
		move.l	a3,(MCD_ObjectRespawnFront_Sub).l
		movea.l	(MCD_ObjectBack_Sub).l,a0
		movea.l	(MCD_ObjectRespawnBase_Sub).l,a3
		subi.w	#Object_Load_XBehind,d6
		bcs.s	.back_ready
.seek_back:
		cmp.w	(a0),d6
		bls.s	.back_ready
		addq.w	#omSize,a0
		addq.w	#1,a3
		bra.s	.seek_back
.back_ready:
		move.l	a0,(MCD_ObjectBack_Sub).l
		move.l	a3,(MCD_ObjectRespawnBack_Sub).l
		move.w	#-1,(MCD_ObjectCoarseX_Sub).l
		move.w	(MCD_TerrainCamera_Sub+4).l,d0
		andi.w	#Object_Load_CoarseMask,d0
		move.w	d0,(MCD_ObjectCoarseY_Sub).l
		; Fall through to load the starting window.

MCD_SubObjects_Main:
		move.w	(MCD_TerrainCamera_Sub).l,d6
		subi.w	#Object_Load_XBehind,d6
		andi.w	#Object_Load_CoarseMask,d6
		move.w	d6,(MCD_ObjectXBehind_Sub).l
		move.w	(MCD_TerrainCamera_Sub+4).l,d1
		subi.w	#Object_Load_YAbove,d1
		andi.w	#Object_Load_CoarseMask,d1
		move.w	d1,(MCD_ObjectYAbove_Sub).l
		move.w	(MCD_TerrainCamera_Sub).l,d6
		andi.w	#Object_Load_CoarseMask,d6
		cmp.w	(MCD_ObjectCoarseX_Sub).l,d6
		bne.s	.active
		move.w	(MCD_TerrainCamera_Sub+4).l,d1
		andi.w	#Object_Load_CoarseMask,d1
		cmp.w	(MCD_ObjectCoarseY_Sub).l,d1
		bne.s	.active
		tst.b	(MCD_ObjectRetry_Sub).l
		beq.w	MCD_SubObjects_CheckY.return
.active:
		move.w	(MCD_TerrainCamera_Sub+4).l,d3
		andi.w	#Object_Load_CoarseMask,d3
		move.w	d3,d4
		addi.w	#Object_Load_YBelow,d4
		subi.w	#Object_Load_YAbove,d3
		lea	MCD_SubObjects_LoadInRange(pc),a6
		tst.w	(MCD_ObjectMinY_Sub).l
		bpl.s	.no_wrap
		; The existing level camera wraps Y at $800 pixels.
		tst.w	d3
		bpl.s	.wrap_bottom
		andi.w	#Level_YWrapMask,d3
		lea	MCD_SubObjects_LoadWrapped(pc),a6
		bra.s	.bounds_ready
.wrap_bottom:
		cmpi.w	#Level_YWrapMask+1,d4
		bls.s	.bounds_ready
		andi.w	#Level_YWrapMask,d4
		lea	MCD_SubObjects_LoadWrapped(pc),a6
		bra.s	.bounds_ready
.no_wrap:
		tst.w	d3
		bpl.s	.bounds_ready
		moveq	#0,d3
.bounds_ready:
		move.w	#ObjectLayout_YCoordinateMask,d5
		move.w	(MCD_ObjectFreeCount_Sub).l,d0
		subq.w	#1,d0
		lea	(MCD_ObjectFreeSlots_Sub).l,a1
		cmp.w	(MCD_ObjectCoarseX_Sub).l,d6
		beq.w	MCD_SubObjects_CheckY
		bge.s	MCD_SubObjects_Forward

MCD_SubObjects_Backward:
		; First discard the right side. This also bounds large Debug jumps.
		movea.l	(MCD_ObjectFront_Sub).l,a0
		movea.l	(MCD_ObjectRespawnFront_Sub).l,a3
		addi.w	#Object_Load_XAhead,d6
.trim_front:
		cmp.w	-omSize(a0),d6
		bgt.s	.front_ready
		subq.w	#omSize,a0
		subq.w	#1,a3
		bra.s	.trim_front
.front_ready:
		move.l	a0,(MCD_ObjectFront_Sub).l
		move.l	a3,(MCD_ObjectRespawnFront_Sub).l
		movea.l	(MCD_ObjectBack_Sub).l,a2
		cmpa.l	a0,a2
		bls.s	.back_in_range
		; The old window lies entirely beyond the new right edge.
		move.l	a0,(MCD_ObjectBack_Sub).l
		move.l	a3,(MCD_ObjectRespawnBack_Sub).l
.back_in_range:
		movea.l	(MCD_ObjectBack_Sub).l,a0
		movea.l	(MCD_ObjectRespawnBack_Sub).l,a3
		subi.w	#Object_Load_XAhead+Object_Load_XBehind,d6
		bcs.s	.zero_left
.load:
		cmp.w	-omSize(a0),d6
		bgt.s	.done			; include placements exactly on the left edge
		subq.w	#omSize,a0
		subq.w	#1,a3
		jsr	(a6)
		subq.w	#omSize,a0		; helper consumed the record; continue backwards
		bra.s	.load
.zero_left:
		moveq	#0,d6
		bra.s	.load
.done:
		move.l	a0,(MCD_ObjectBack_Sub).l
		move.l	a3,(MCD_ObjectRespawnBack_Sub).l
		bra.s	MCD_SubObjects_XReady

MCD_SubObjects_Forward:
		; Advance the left side before spawning, so a teleport does not fill
		; the pool with objects from the skipped part of the level.
		movea.l	(MCD_ObjectBack_Sub).l,a0
		movea.l	(MCD_ObjectRespawnBack_Sub).l,a3
		subi.w	#Object_Load_XBehind,d6
		bcs.s	.back_ready
.trim_back:
		cmp.w	(a0),d6
		bls.s	.back_ready
		addq.w	#omSize,a0
		addq.w	#1,a3
		bra.s	.trim_back
.back_ready:
		move.l	a0,(MCD_ObjectBack_Sub).l
		move.l	a3,(MCD_ObjectRespawnBack_Sub).l
		movea.l	(MCD_ObjectFront_Sub).l,a2
		cmpa.l	a0,a2
		bhs.s	.front_in_range
		move.l	a0,(MCD_ObjectFront_Sub).l
		move.l	a3,(MCD_ObjectRespawnFront_Sub).l
.front_in_range:
		movea.l	(MCD_ObjectFront_Sub).l,a0
		movea.l	(MCD_ObjectRespawnFront_Sub).l,a3
		addi.w	#Object_Load_XBehind+Object_Load_XAhead,d6
.load:
		cmp.w	(a0),d6
		bls.s	.done
		jsr	(a6)
		addq.w	#1,a3
		bra.s	.load
.done:
		move.l	a0,(MCD_ObjectFront_Sub).l
		move.l	a3,(MCD_ObjectRespawnFront_Sub).l

MCD_SubObjects_XReady:
		move.w	(MCD_TerrainCamera_Sub).l,d6
		andi.w	#Object_Load_CoarseMask,d6
		move.w	d6,(MCD_ObjectCoarseX_Sub).l

MCD_SubObjects_CheckY:
		; S3&K scans the retained X band when Y changes. Use the whole Y
		; interval for retries and large jumps; a single step needs one strip.
		move.w	(MCD_TerrainCamera_Sub+4).l,d6
		andi.w	#Object_Load_CoarseMask,d6
		tst.b	(MCD_ObjectRetry_Sub).l
		bne.s	.scan
		move.w	d6,d1
		sub.w	(MCD_ObjectCoarseY_Sub).l,d1
		beq.s	.done
		cmpi.w	#Object_Load_BandSize,d1
		beq.s	.down
		cmpi.w	#-Object_Load_BandSize,d1
		bne.s	.scan
		move.w	d6,d3
		subi.w	#Object_Load_YAbove,d3
		bpl.s	.strip
		tst.w	(MCD_ObjectMinY_Sub).l
		bpl.s	.done
		andi.w	#Level_YWrapMask,d3
		bra.s	.strip
.down:
		move.w	d6,d3
		addi.w	#Object_Load_YBelow-Object_Load_BandSize,d3
		tst.w	(MCD_ObjectMinY_Sub).l
		bpl.s	.strip
		andi.w	#Level_YWrapMask,d3
.strip:
		move.w	d3,d4
		addi.w	#Object_Load_BandSize,d4
		lea	MCD_SubObjects_LoadInRange(pc),a6
.scan:
		sf	(MCD_ObjectRetry_Sub).l		; a missed eligible placement sets it again
		movea.l	(MCD_ObjectBack_Sub).l,a0
		movea.l	(MCD_ObjectRespawnBack_Sub).l,a3
		movea.l	(MCD_ObjectFront_Sub).l,a2
.loop:
		cmpa.l	a2,a0
		bhs.s	.done
		jsr	(a6)
		addq.w	#1,a3
		bra.s	.loop
.done:
		move.w	d6,(MCD_ObjectCoarseY_Sub).l
.return:
		rts

; ---------------------------------------------------------------------------
; Helpers always consume one placement, even when already loaded or outside Y.
; Only an eligible placement without a slot sets the retry flag. Keep a3 paired
; with a0 in the caller, and leave d0/a1 as the continuing free-slot search.
; ---------------------------------------------------------------------------
MCD_SubObjects_LoadWrapped:
		move.b	omTimeZones(a0),d1
		and.b	(MCD_ObjectTimeMask_Sub).l,d1
		beq.w	MCD_SubObjects_Skip
		tst.b	(a3)
		bmi.w	MCD_SubObjects_Skip
		move.w	omY(a0),d2
		move.w	d2,d1
		and.w	d5,d1
		tst.w	d2
		bmi.s	MCD_SubObjects_Load
		cmp.w	d3,d1
		bhs.s	MCD_SubObjects_Load
		cmp.w	d4,d1
		bls.s	MCD_SubObjects_Load
		bra.s	MCD_SubObjects_Skip

MCD_SubObjects_LoadInRange:
		move.b	omTimeZones(a0),d1
		and.b	(MCD_ObjectTimeMask_Sub).l,d1
		beq.s	MCD_SubObjects_Skip
		tst.b	(a3)
		bmi.s	MCD_SubObjects_Skip
		move.w	omY(a0),d2
		move.w	d2,d1
		and.w	d5,d1
		tst.w	d2
		bmi.s	MCD_SubObjects_Load
		cmp.w	d3,d1
		blo.s	MCD_SubObjects_Skip
		cmp.w	d4,d1
		bhi.s	MCD_SubObjects_Skip
MCD_SubObjects_Load:
		tst.w	d0
		bmi.s	.no_slot
		bset	#7,(a3)
		move.w	(a1)+,(a4)+		; MD SST handle, never a CD pointer
		move.w	omX(a0),(a4)+
		move.w	d1,(a4)+
		rol.w	#3,d2
		andi.b	#3,d2
		move.b	d2,(a4)+
		move.b	omID(a0),(a4)+
		move.w	omSubtype(a0),(a4)+
		move.l	a3,d1
		sub.l	(MCD_ObjectRespawnBase_Sub).l,d1
		addq.w	#1,d1
		move.w	d1,(a4)+		; index + 1; zero denotes dynamic objects
		addq.w	#1,(MCD_ObjectSpawnCount_Sub).l
		addq.w	#omSize,a0
		subq.w	#1,d0
		rts
.no_slot:
		st	(MCD_ObjectRetry_Sub).l
MCD_SubObjects_Skip:
		addq.w	#omSize,a0
		rts
