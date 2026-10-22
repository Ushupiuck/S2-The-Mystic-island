; ===========================================================================
; Mega Drive main-68000 object-loader transport and SST creation.
; Selection, placement cursors and respawn state execute on the CD CPU in
; Mega CD Objects.asm. Ordinary SST behavior and MD code pointers remain here.
; ===========================================================================

Load_Sprites:
ObjectsManager:
		tst.b	(Obj_placement_routine).w
		bne.s	.loaded
		bsr.w	MCD_LoadObjectPlacements
.loaded:
		; Lifetime macros still use the current MD camera's retained X band.
		move.w	(Camera_X_pos).w,d0
		subi.w	#Object_Load_XBehind,d0
		andi.w	#Object_Load_CoarseMask,d0
		move.w	d0,(Camera_X_pos_coarse_back).w
		jsr	(MCD_BeginTerrainJob).l
		jsr	(MCD_FinishTerrainJob).l
		bra.w	MCD_ApplyObjectReply

MCD_LoadObjectPlacements:
		move.w	(Current_ZoneAndAct).w,d0
		move.w	d0,d1
		lsr.w	#5,d0
		andi.w	#$FF,d1
		add.w	d1,d1
		add.w	d1,d0
		lea	(ObjPos_Index).l,a0
		adda.w	(a0,d0.w),a0
		subq.w	#omSize,a0		; include the backward boundary
		lea	(MCD_TerrainStage).l,a1
		move.w	#MCD_ObjectPlacementCount+1,d2
		moveq	#0,d1
.copy:
		move.w	(a0)+,d0
		move.w	d0,(a1)+
		move.l	(a0)+,(a1)+
		addq.w	#omSize,d1
		cmpi.w	#omSize,d1		; the first $FFFF is the backward boundary
		beq.s	.next
		cmpi.w	#-1,d0
		beq.s	.copied
.next:
		dbf	d2,.copy
		jmp	(MCD_Unavailable).l
.copied:
		jsr	(MCD_ReleaseWordRAM).l
		jcs	MCD_Unavailable
		moveq	#0,d0
		move.b	(Respawn_table_keep).w,d0
		lsl.w	#8,d0
		ori.w	#MCD_CommandObjectsLoad,d0
		jsr	(MCD_Command).l
		jcs	MCD_Unavailable
		move.b	#2,(Obj_placement_routine).w
		move.w	#-1,(Camera_X_pos_coarse).w
		move.w	#-1,(Camera_Y_pos_coarse).w
		clr.b	(Object_load_retry).w
		rts

; Cheap request cache only: the authoritative cursors and loading bands are CD
; state. Return nonzero when CD must consider new placements or retry a full pool.
MCD_ObjectsNeedJob:
		moveq	#0,d0
		tst.b	(Obj_placement_routine).w
		beq.s	.return
		move.w	(Camera_X_pos).w,d1
		andi.w	#Object_Load_CoarseMask,d1
		cmp.w	(Camera_X_pos_coarse).w,d1
		bne.s	.needed
		move.w	(Camera_Y_pos).w,d1
		andi.w	#Object_Load_CoarseMask,d1
		cmp.w	(Camera_Y_pos_coarse).w,d1
		bne.s	.needed
		tst.b	(Object_load_retry).w
		beq.s	.return
.needed:
		moveq	#1,d0
.return:
		rts

; At most twelve free-slot bytes, only on an actual object-loading frame. Share
; the terrain snapshot and its single Word-RAM handoff; never copy 90 SSTs.
MCD_PrepareObjectFrame:
		bsr.s	MCD_ObjectsNeedJob
		move.b	d0,(MCD_ObjectFrameEnabled).l
		beq.s	.return
		move.w	(Camera_Min_Y_pos).w,(MCD_ObjectFrameMinY).l
		move.w	(Camera_X_pos).w,d0
		andi.w	#Object_Load_CoarseMask,d0
		move.w	d0,(Camera_X_pos_coarse).w
		move.w	(Camera_Y_pos).w,d0
		andi.w	#Object_Load_CoarseMask,d0
		move.w	d0,(Camera_Y_pos_coarse).w
		lea	(MCD_ObjectFrameSlots).l,a0
		moveq	#MCD_ObjectSlotBytes/4-1,d0
.clear:
		clr.l	(a0)+
		dbf	d0,.clear
		lea	(MCD_ObjectFrameSlots).l,a0
		lea	(v_lvlobjspace).w,a1
		moveq	#0,d0
.slots:
		tst.l	code(a1)
		bne.s	.occupied
		move.w	d0,d1
		lsr.w	#3,d1
		bset	d0,(a0,d1.w)
.occupied:
		lea	object_size(a1),a1
		addq.w	#1,d0
		cmpi.w	#MCD_ObjectSlotCount,d0
		blo.s	.slots
		move.w	#1,(MCD_ObjectReplyPending).l
.return:
		rts

; The CD returns slot/X/Y/flags/subtype/ID/handle. Resolving an MD code pointer
; and writing the SST are the only creation work performed on the main CPU.
MCD_ApplyObjectReply:
		tst.w	(MCD_ObjectReplyPending).l
		beq.s	.return
		clr.w	(MCD_ObjectReplyPending).l
		lea	(MCD_ObjectReply).l,a2
		move.w	(a2)+,d7
		move.w	(a2)+,d0
		move.b	d0,(Object_load_retry).w
		subq.w	#1,d7
		bmi.s	.return
		lea	(Obj_Index-4).l,a3
.spawn:
		movea.w	(a2)+,a1
		move.w	(a2)+,obX(a1)
		move.w	(a2)+,obY(a1)
		move.b	(a2)+,d0
		move.b	d0,obRender(a1)
		move.b	d0,obStatus(a1)
		move.b	(a2)+,obSubtype(a1)
		move.w	(a2)+,d0
		lsl.w	#2,d0
		move.l	(a3,d0.w),code(a1)
		move.w	(a2)+,respawn_addr(a1)
		dbf	d7,.spawn
.return:
		rts

; Rare persistent-state operations. Preserve the object's registers; d0 is the
; only result. No PRG-RAM bus request or state-table mirror is needed on MD.
MCD_RespawnRead:
		move.l	d1,-(sp)
		move.w	#MCD_CommandObjectState,d1
		bra.s	MCD_RespawnRequest
MCD_RespawnConsume:
		move.l	d1,-(sp)
		move.w	#$100|MCD_CommandObjectState,d1
		bra.s	MCD_RespawnRequest
MCD_RespawnRelease:
		move.l	d1,-(sp)
		move.w	#$200|MCD_CommandObjectState,d1
		bra.s	MCD_RespawnRequest
MCD_RespawnBump:
		move.l	d1,-(sp)
		move.w	#$300|MCD_CommandObjectState,d1
		bra.s	MCD_RespawnRequest
MCD_ReadPlacementX:
		move.l	d1,-(sp)
		move.w	#$400|MCD_CommandObjectState,d1
MCD_RespawnRequest:
		movem.l	d2-d3,-(sp)
		move.w	sr,-(sp)
		disable_ints
		move.w	d0,(MCD_MainArgument).l
		move.w	d1,d0
		jsr	(MCD_TerrainRequest).l
		move.w	(sp)+,sr
		movem.l	(sp)+,d2-d3
		move.l	(sp)+,d1
		tst.w	d0
		rts
