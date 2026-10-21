; ---------------------------------------------------------------------------
; S3&K level object manager, using longword routine pointers in the SSTs.
; Source: sonicretro/skdisasm, Load_Sprites (73de97c6).
; Also checked against ProjectFM's S1 port in RetroKoH/S1Fixed (d29550bd).
;
; Six-byte S3&K placements, sorted by X, with an ObjectLayoutBoundary before
; each list and an $FFFF X terminator. Every placement owns one respawn byte:
; bit 7 = loaded/consumed; bits 0-6 belong to the object.
;
; The front/back layout pointers and word respawn pointers always advance
; together. Loading is limited to S3&K's X/Y window; Y flag bit 15 bypasses
; the vertical filter. The ordinary object routines still own their lifetime.
;
; Differences from stock: continue the slot search instead of restarting it,
; retry a full pool with a stationary camera, and scan the whole Y window on
; a jump of more than one $80 band (Debug/arena settling).
;
; Clobbers d0-d7/a0-a4/a6. d0 = remaining slot-search count; a1 = free SST.
; d3/d4 = Y bounds, d5 = Y mask, d6 = camera X, a3 = placement respawn byte.
; ---------------------------------------------------------------------------
Load_Sprites:
ObjectsManager:
		tst.b	(Obj_placement_routine).w
		bne.w	ObjectsManager_Main

ObjectsManager_Init:
		move.b	#2,(Obj_placement_routine).w
		sf	(Object_load_retry).w
		tst.b	(Respawn_table_keep).w
		bne.s	.layout
		lea	(Object_Respawn_Table).w,a0
		moveq	#0,d0
		move.w	#bytesToLcnt(Object_Respawn_Table_end-Object_Respawn_Table),d1
.clear:
		move.l	d0,(a0)+
		dbf	d1,.clear
.layout:
		; Two-byte offsets, four acts per zone (including the unused acts).
		move.w	(Current_ZoneAndAct).w,d0
		move.w	d0,d1
		lsr.w	#5,d0
		andi.w	#$FF,d1
		add.w	d1,d1
		add.w	d1,d0
		lea	(ObjPos_Index).l,a0
		adda.w	(a0,d0.w),a0
		move.l	a0,(Object_load_addr_front).w
		move.l	a0,(Object_load_addr_back).w
		lea	(Object_Respawn_Table).w,a3
		move.w	(Camera_X_pos).w,d6
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
		move.l	a0,(Object_load_addr_front).w
		move.w	a3,(Object_respawn_index_front).w
		movea.l	(Object_load_addr_back).w,a0
		lea	(Object_Respawn_Table).w,a3
		subi.w	#Object_Load_XBehind,d6
		bcs.s	.back_ready
.seek_back:
		cmp.w	(a0),d6
		bls.s	.back_ready
		addq.w	#omSize,a0
		addq.w	#1,a3
		bra.s	.seek_back
.back_ready:
		move.l	a0,(Object_load_addr_back).w
		move.w	a3,(Object_respawn_index_back).w
		move.w	#-1,(Camera_X_pos_coarse).w
		move.w	(Camera_Y_pos).w,d0
		andi.w	#Object_Load_CoarseMask,d0
		move.w	d0,(Camera_Y_pos_coarse).w
		; Fall through to load the starting window.

ObjectsManager_Main:
		move.w	(Camera_X_pos).w,d6
		subi.w	#Object_Load_XBehind,d6
		andi.w	#Object_Load_CoarseMask,d6
		move.w	d6,(Camera_X_pos_coarse_back).w
		move.w	(Camera_Y_pos).w,d1
		subi.w	#Object_Load_YAbove,d1
		andi.w	#Object_Load_CoarseMask,d1
		move.w	d1,(Camera_Y_pos_coarse_back).w
		move.w	(Camera_X_pos).w,d6
		andi.w	#Object_Load_CoarseMask,d6
		cmp.w	(Camera_X_pos_coarse).w,d6
		bne.s	.active
		move.w	(Camera_Y_pos).w,d1
		andi.w	#Object_Load_CoarseMask,d1
		cmp.w	(Camera_Y_pos_coarse).w,d1
		bne.s	.active
		tst.b	(Object_load_retry).w
		beq.w	ObjectsManager_CheckY.return
.active:
		move.w	(Camera_Y_pos).w,d3
		andi.w	#Object_Load_CoarseMask,d3
		move.w	d3,d4
		addi.w	#Object_Load_YBelow,d4
		subi.w	#Object_Load_YAbove,d3
		lea	ObjectsManager_LoadInRange(pc),a6
		tst.w	(Camera_Min_Y_pos).w
		bpl.s	.no_wrap
		; The existing level camera wraps Y at $800 pixels.
		tst.w	d3
		bpl.s	.wrap_bottom
		andi.w	#Level_YWrapMask,d3
		lea	ObjectsManager_LoadWrapped(pc),a6
		bra.s	.bounds_ready
.wrap_bottom:
		cmpi.w	#Level_YWrapMask+1,d4
		bls.s	.bounds_ready
		andi.w	#Level_YWrapMask,d4
		lea	ObjectsManager_LoadWrapped(pc),a6
		bra.s	.bounds_ready
.no_wrap:
		tst.w	d3
		bpl.s	.bounds_ready
		moveq	#0,d3
.bounds_ready:
		move.w	#ObjectLayout_YCoordinateMask,d5
		bsr.w	FindFreeObj		; one search, then continue past each occupied SST
		cmp.w	(Camera_X_pos_coarse).w,d6
		beq.w	ObjectsManager_CheckY
		bge.s	ObjectsManager_Forward

ObjectsManager_Backward:
		; First discard the right side. This also bounds large Debug jumps.
		movea.l	(Object_load_addr_front).w,a0
		movea.w	(Object_respawn_index_front).w,a3
		addi.w	#Object_Load_XAhead,d6
.trim_front:
		cmp.w	-omSize(a0),d6
		bgt.s	.front_ready
		subq.w	#omSize,a0
		subq.w	#1,a3
		bra.s	.trim_front
.front_ready:
		move.l	a0,(Object_load_addr_front).w
		move.w	a3,(Object_respawn_index_front).w
		movea.l	(Object_load_addr_back).w,a2
		cmpa.l	a0,a2
		bls.s	.back_in_range
		; The old window lies entirely beyond the new right edge.
		move.l	a0,(Object_load_addr_back).w
		move.w	a3,(Object_respawn_index_back).w
.back_in_range:
		movea.l	(Object_load_addr_back).w,a0
		movea.w	(Object_respawn_index_back).w,a3
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
		move.l	a0,(Object_load_addr_back).w
		move.w	a3,(Object_respawn_index_back).w
		bra.s	ObjectsManager_XReady

ObjectsManager_Forward:
		; Advance the left side before spawning, so a teleport does not fill
		; the pool with objects from the skipped part of the level.
		movea.l	(Object_load_addr_back).w,a0
		movea.w	(Object_respawn_index_back).w,a3
		subi.w	#Object_Load_XBehind,d6
		bcs.s	.back_ready
.trim_back:
		cmp.w	(a0),d6
		bls.s	.back_ready
		addq.w	#omSize,a0
		addq.w	#1,a3
		bra.s	.trim_back
.back_ready:
		move.l	a0,(Object_load_addr_back).w
		move.w	a3,(Object_respawn_index_back).w
		movea.l	(Object_load_addr_front).w,a2
		cmpa.l	a0,a2
		bhs.s	.front_in_range
		move.l	a0,(Object_load_addr_front).w
		move.w	a3,(Object_respawn_index_front).w
.front_in_range:
		movea.l	(Object_load_addr_front).w,a0
		movea.w	(Object_respawn_index_front).w,a3
		addi.w	#Object_Load_XBehind+Object_Load_XAhead,d6
.load:
		cmp.w	(a0),d6
		bls.s	.done
		jsr	(a6)
		addq.w	#1,a3
		bra.s	.load
.done:
		move.l	a0,(Object_load_addr_front).w
		move.w	a3,(Object_respawn_index_front).w

ObjectsManager_XReady:
		move.w	(Camera_X_pos).w,d6
		andi.w	#Object_Load_CoarseMask,d6
		move.w	d6,(Camera_X_pos_coarse).w

ObjectsManager_CheckY:
		; S3&K scans the retained X band when Y changes. Use the whole Y
		; interval for retries and large jumps; a single step needs one strip.
		move.w	(Camera_Y_pos).w,d6
		andi.w	#Object_Load_CoarseMask,d6
		tst.b	(Object_load_retry).w
		bne.s	.scan
		move.w	d6,d1
		sub.w	(Camera_Y_pos_coarse).w,d1
		beq.s	.done
		cmpi.w	#Object_Load_BandSize,d1
		beq.s	.down
		cmpi.w	#-Object_Load_BandSize,d1
		bne.s	.scan
		move.w	d6,d3
		subi.w	#Object_Load_YAbove,d3
		bpl.s	.strip
		tst.w	(Camera_Min_Y_pos).w
		bpl.s	.done
		andi.w	#Level_YWrapMask,d3
		bra.s	.strip
.down:
		move.w	d6,d3
		addi.w	#Object_Load_YBelow-Object_Load_BandSize,d3
		tst.w	(Camera_Min_Y_pos).w
		bpl.s	.strip
		andi.w	#Level_YWrapMask,d3
.strip:
		move.w	d3,d4
		addi.w	#Object_Load_BandSize,d4
		lea	ObjectsManager_LoadInRange(pc),a6
.scan:
		sf	(Object_load_retry).w		; a missed eligible placement sets it again
		movea.l	(Object_load_addr_back).w,a0
		movea.w	(Object_respawn_index_back).w,a3
		movea.l	(Object_load_addr_front).w,a2
.loop:
		cmpa.l	a2,a0
		bhs.s	.done
		jsr	(a6)
		addq.w	#1,a3
		bra.s	.loop
.done:
		move.w	d6,(Camera_Y_pos_coarse).w
.return:
		rts

; ---------------------------------------------------------------------------
; Helpers always consume one placement, even when already loaded or outside Y.
; Only an eligible placement without a slot sets the retry flag. Keep a3 paired
; with a0 in the caller, and leave d0/a1 as the continuing free-slot search.
; ---------------------------------------------------------------------------
ObjectsManager_LoadWrapped:
		tst.b	(a3)
		bmi.w	ObjectsManager_Skip
		move.w	omY(a0),d2
		move.w	d2,d1
		and.w	d5,d1
		tst.w	d2
		bmi.s	ObjectsManager_Load
		cmp.w	d3,d1
		bhs.s	ObjectsManager_Load
		cmp.w	d4,d1
		bls.s	ObjectsManager_Load
		bra.s	ObjectsManager_Skip

ObjectsManager_LoadInRange:
		tst.b	(a3)
		bmi.s	ObjectsManager_Skip
		move.w	omY(a0),d2
		move.w	d2,d1
		and.w	d5,d1
		tst.w	d2
		bmi.s	ObjectsManager_Load
		cmp.w	d3,d1
		blo.s	ObjectsManager_Skip
		cmp.w	d4,d1
		bhi.s	ObjectsManager_Skip
ObjectsManager_Load:
		tst.w	d0
		bmi.s	.no_slot
		bset	#7,(a3)
		move.w	omX(a0),obX(a1)
		move.w	d1,obY(a1)
		rol.w	#3,d2			; S3&K Y word: bit 13 = X flip, bit 14 = Y flip
		andi.b	#3,d2
		move.b	d2,obRender(a1)
		move.b	d2,obStatus(a1)
		moveq	#0,d1
		move.b	omID(a0),d1			; compact placement ID stays a byte
		add.w	d1,d1
		add.w	d1,d1
		lea	(Obj_Index-4).l,a4
		move.l	(a4,d1.w),code(a1)		; resolve only at creation
		move.b	omSubtype(a0),obSubtype(a1)
		move.w	a3,respawn_addr(a1)
		addq.w	#omSize,a0
		; Continue S3&K's CreateNewSprite4 search using the SST stride.
		subq.w	#1,d0
		bmi.s	.return
.next_slot:
		lea	object_size(a1),a1
		tst.l	code(a1)
		dbeq	d0,.next_slot
.return:
		rts
.no_slot:
		st	(Object_load_retry).w
ObjectsManager_Skip:
		addq.w	#omSize,a0
		rts
