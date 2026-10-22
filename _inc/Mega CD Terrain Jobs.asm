; ===========================================================================
; Mega Drive main-68000 terrain callers, included by md-main.asm.
; Geometry and tilemap construction execute in Mega CD Terrain.asm on CD.
; Main retains player/object control and the actual VDP writes.
; ===========================================================================

; The MD supplies ROM data once per level. Resident CD tables then serve every
; frame without further block/layout/height copies.
MCD_LoadTerrain:
		lea	(MCD_TerrainIndexStage).l,a1
		move.w	#bytesToLcnt(MCD_TerrainIndexCapacity),d0
.clearIndex:
		clr.l	(a1)+
		dbf	d0,.clearIndex
		lea	(MCD_TerrainIndexStage).l,a1
		movea.l	(v_colladdr1).w,a0
		move.w	(MCD_TerrainIndexBytes).l,d0
		lsr.w	#1,d0
		subq.w	#1,d0
.index:
		move.w	(a0)+,(a1)+
		dbf	d0,.index
		lea	(ColArray1).l,a0
		lea	(ColArray2).l,a2
		lea	(AngleMap).l,a3
		cmpi.b	#id_SMZ,(Current_Zone).w
		beq.s	.s1
		cmpi.b	#id_LZ,(Current_Zone).w
		beq.s	.s1
		tst.b	(Current_Zone).w
		bne.s	.tables
.s1:
		lea	(S1_ColArray1).l,a0
		lea	(S1_ColArray2).l,a2
		lea	(S1_AngleMap).l,a3
.tables:
		lea	(MCD_TerrainHeightStage).l,a1
		move.w	#$1000,d0
		bsr.s	.copy
		movea.l	a2,a0
		move.w	#$1000,d0
		bsr.s	.copy
		movea.l	a3,a0
		move.w	#$100,d0
		bsr.s	.copy
		jsr	(MCD_ReleaseWordRAM).l
		jcs	MCD_Unavailable
		moveq	#MCD_CommandTerrainLoad,d0
		moveq	#0,d1
		jsr	(MCD_Command).l
		jcs	MCD_Unavailable
		move.b	#1,(MCD_TerrainReady).l
		move.b	#1,(MCD_SubControl+1).l
		rts
.copy:
		lsr.w	#2,d0
		subq.w	#1,d0
.long:
		move.l	(a0)+,(a1)+
		dbf	d0,.long
		rts

; Preserve d7, which was not scratch in the original collision ABI. Each entry
; submits one whole operation; paired player sensors never make separate calls.
; Sonic/Tails push their own landing callback before entering this shared pass.
MCD_PlayerAirCollision:
		move.l	a5,-(sp)
		move.w	sr,-(sp)
		disable_ints
		lea	(MCD_MainArgument).l,a5
		move.w	obX(a0),(a5)+
		move.w	obY(a0),(a5)+
		move.l	obVelX(a0),(a5)+
		move.w	obHeight(a0),(a5)+
		move.b	obAngle(a0),(a5)+
		move.b	obStatus(a0),(a5)+
		move.b	(f_wtunnelmode).w,(MCD_MainFlags).l
		moveq	#0,d0
		move.b	obTopSolidBit(a0),d0
		lsl.w	#4,d0
		or.b	obLRBSolidBit(a0),d0
		lsl.w	#8,d0
		ori.b	#MCD_CommandTerrainAir,d0
		bsr.w	MCD_TerrainRequest
		lea	(MCD_SubResult).l,a5
		move.w	(a5),obX(a0)
		move.w	2(a5),obY(a0)
		move.l	4(a5),obVelX(a0)
		btst	#MCD_ServiceInertia,(MCD_SubFlags).l
		beq.s	.inertia
		move.w	8(a5),obInertia(a0)
.inertia:
		move.w	$A(a5),obHeight(a0)
		move.b	$C(a5),obAngle(a0)
		move.b	$D(a5),obStatus(a0)
		move.b	obAngle(a0),d3
		btst	#MCD_ServiceLanded,(MCD_SubFlags).l
		beq.s	.airborne
		move.w	(sp)+,sr
		movea.l	(sp)+,a5
		movea.l	(sp)+,a1
		jmp	(a1)
.airborne:
		move.w	(sp)+,sr
		movea.l	(sp)+,a5
		addq.w	#4,sp		; discard the unused landing callback
		rts

terraincall: macro operation
		move.l	d7,-(sp)
		moveq	#operation,d7
		bra.w	MCD_TerrainObject
		endm

AnglePos:
		terraincall MCD_TerrainAnglePos
CalcRoomInFront:
		terraincall MCD_TerrainRoomInFront
sub_13102:
		terraincall MCD_TerrainRoomOverhead
loc_13146:
		terraincall MCD_TerrainFloorPair
Sonic_DontRunOnWalls:
		terraincall MCD_TerrainCeilingPair
ChkFloorEdge:
		terraincall MCD_TerrainFloorEdge
ChkFloorEdge_Part2:
		terraincall MCD_TerrainFloorEdgeX
ObjHitFloor:
		move.w	obX(a0),d3
ObjHitFloor2:
		; The common enemy/ring probe needs just X, Y and its radii. Keep the
		; six-byte packet separate from the player's twelve-byte contact state.
		move.w	sr,-(sp)
		disable_ints
		move.w	d3,(MCD_MainArgument).l
		move.w	obY(a0),(MCD_MainArgument+2).l
		move.w	obHeight(a0),(MCD_MainArgument+4).l
		moveq	#MCD_TerrainObjectFloorX,d0
		bsr.w	MCD_TerrainRequest
		move.w	(MCD_SubResult+4).l,d1
		move.w	(MCD_SubResult+8).l,d3
		move.b	(MCD_SubResult+$A).l,(Primary_Angle).w
		move.w	(sp)+,sr
		tst.w	d1
		rts
sub_132EE:
		terraincall MCD_TerrainRightSensor
Sonic_HitWall:
		terraincall MCD_TerrainLeftSensor
ObjHitWallRight:
		terraincall MCD_TerrainObjectRight
ObjHitWallLeft:
		terraincall MCD_TerrainObjectLeft
ObjHitCeiling:
		terraincall MCD_TerrainObjectCeiling

MCD_TerrainObject:
		movem.l	d4-d6/a5-a6,-(sp)
		move.w	sr,-(sp)
		disable_ints
		lea	(MCD_MainArgument).l,a5
		move.w	d0,d4
		lsl.w	#8,d4		; optional input angle in command high byte
		or.w	d7,d4
		cmpi.b	#MCD_TerrainFloorEdgeX,d7
		beq.s	.haveX
		cmpi.b	#MCD_TerrainObjectFloorX,d7
		beq.s	.haveX
		cmpi.b	#MCD_TerrainObjectRight,d7
		beq.s	.offsetX
		cmpi.b	#MCD_TerrainObjectLeft,d7
		beq.s	.offsetX
		move.w	obX(a0),d3
		bra.s	.haveX
.offsetX:
		add.w	obX(a0),d3
.haveX:
		move.w	obY(a0),d2
		cmpi.b	#MCD_TerrainRoomInFront,d7
		bne.s	.coordinates
		; Project on MD while velocities are already local; send the resulting
		; coordinates rather than extending the compact request with velocities.
		move.l	obX(a0),d3
		move.l	obY(a0),d2
		move.w	obVelX(a0),d1
		ext.l	d1
		asl.l	#8,d1
		add.l	d1,d3
		move.w	obVelY(a0),d1
		ext.l	d1
		asl.l	#8,d1
		add.l	d1,d2
		swap	d2
		swap	d3
.coordinates:
		move.w	d3,(a5)+
		move.w	d2,(a5)+
		move.w	obHeight(a0),(a5)+
		move.b	obAngle(a0),(a5)+
		move.b	obStatus(a0),(a5)+
		move.w	obTopSolidBit(a0),(a5)+
		move.b	stick_to_convex(a0),(a5)+
		move.b	obPrevAni(a0),(a5)+
		move.w	d4,d0
		bsr.w	MCD_TerrainRequest
		lea	(MCD_SubResult).l,a5
		cmpi.b	#MCD_TerrainAnglePos,d7
		beq.s	.attach
		move.w	(a5),d0
		move.w	4(a5),d1
		move.w	6(a5),d2
		move.w	8(a5),d3
		bra.s	.angles
.attach:
		move.w	(a5),obX(a0)
		move.w	4(a5),obY(a0)
		move.b	6(a5),obAngle(a0)
		move.b	7(a5),obStatus(a0)
		move.b	9(a5),obPrevAni(a0)
		move.w	$C(a5),d1
.angles:
		move.b	$A(a5),(Primary_Angle).w
		move.b	$B(a5),(Secondary_Angle).w
		move.w	(sp)+,sr
		movem.l	(sp)+,d4-d6/a5-a6
		move.l	(sp)+,d7
		tst.w	d1		; callers branch on distance immediately after returning
		rts

; Explicit-coordinate API retained for callers such as the terrain conveyor.
FindFloor:
		move.l	d7,-(sp)
		moveq	#MCD_CommandTerrainFloor,d7
		bra.s	MCD_TerrainProbe
FindWall:
		move.l	d7,-(sp)
		moveq	#MCD_CommandTerrainWall,d7
MCD_TerrainProbe:
		movem.l	d4-d6/a5,-(sp)
		move.w	sr,-(sp)
		disable_ints
		lea	(MCD_MainArgument).l,a5
		move.w	d3,(a5)+
		move.w	d2,(a5)+
		move.w	d5,(a5)+
		move.w	d6,(a5)+
		move.w	a3,(a5)+
		move.l	(Collision_addr).w,d0
		cmp.l	(v_colladdr2).w,d0
		seq	(a5)+
		move.b	(a4),(a5)
		move.w	d7,d0
		bsr.w	MCD_TerrainRequest
		lea	(MCD_SubResult).l,a5
		move.w	(a5),d0
		move.w	4(a5),d1
		move.w	6(a5),d2
		move.w	8(a5),d3
		move.b	$A(a5),(a4)
		move.w	(sp)+,sr
		movem.l	(sp)+,d4-d6/a5
		move.l	(sp)+,d7
		tst.w	d1
		rts

; All six argument words are staged. Publish the token last. PRG RAM remains
; with CD throughout the request and reply; no per-probe bus request occurs.
; Caller masks interrupts, preserves inputs that it needs, and drains async
; work before using this serial mailbox.
MCD_TerrainRequest:
		move.w	(MCD_MainToken).l,d2
		cmp.w	(MCD_SubAck).l,d2
		jne	MCD_Unavailable
		not.w	d2
		move.w	d0,(MCD_MainCommand).l
		move.w	d2,(MCD_MainToken).l
		move.b	#1,(MCD_SubControl+1).l
		move.w	#MCD_WaitLimit,d3
		jsr	(MCD_WaitReply).l
		jcs	MCD_Unavailable
		rts

; Level-script layout access. d0.w offset, d1.b new value for a write.
; d0.w returns the byte; d2-d3 are scratch, matching the mailbox service.
MCD_ReadLayout:
		move.w	sr,-(sp)
		disable_ints
		move.w	d0,(MCD_MainArgument).l
		moveq	#MCD_CommandLayoutRead,d0
		bra.s	MCD_LayoutRequest
MCD_WriteLayout:
		move.w	sr,-(sp)
		disable_ints
		move.w	d0,(MCD_MainArgument).l
		move.w	d1,(MCD_MainArgument+2).l
		moveq	#MCD_CommandLayoutWrite,d0
MCD_LayoutRequest:
		bsr.w	MCD_TerrainRequest
		move.w	(sp)+,sr
		rts

; Copy only a camera/flag snapshot. The CD uses resident geometry and returns
; an ordered strip stream. Main can render sprites and process loaders meanwhile.
MCD_BeginTerrainJob:
		tst.b	(MCD_TerrainReady).l
		beq.w	.return
		tst.w	(MCD_TerrainPending).l
		bne.w	.return
		jsr	(MCD_ObjectsNeedJob).l
		or.l	(Scroll_flags).w,d0
		or.l	(Scroll_flags_BG2).w,d0
		or.b	(Screen_redraw_flag).w,d0
		tst.l	d0			; scroll flags occupy high bytes of their words
		beq.w	.return
		move.w	sr,-(sp)
		disable_ints
		bsr.w	MCD_PrepareTerrainFrame
		moveq	#0,d1
		bsr.w	MCD_StartTerrainDraw
		move.w	(sp)+,sr
.return:
		rts

MCD_PrepareTerrainFrame:
		lea	(MCD_TerrainFrame).l,a0
		lea	(Camera_RAM).w,a1
		moveq	#bytesToLcnt(Camera_Positions_End-Camera_Positions),d0
.camera:
		move.l	(a1)+,(a0)+
		dbf	d0,.camera
		move.l	(Scroll_flags).w,(a0)+
		move.l	(Scroll_flags_BG2).w,(a0)+
		move.w	(Camera_BG_Y_pos).w,(a0)+
		move.b	(Current_Zone).w,(a0)+
		move.b	(Screen_redraw_flag).w,(a0)+
		jsr	(MCD_PrepareObjectFrame).l
		clr.l	(Scroll_flags).w
		clr.l	(Scroll_flags_BG2).w
		clr.b	(Screen_redraw_flag).w
		rts

MCD_StartTerrainDraw:
		jsr	(MCD_ReleaseWordRAM).l
		jcs	MCD_Unavailable
		move.w	(MCD_SubAck).l,d2
		not.w	d2
		move.w	#MCD_CommandTerrainDraw,(MCD_MainCommand).l
		move.w	d1,(MCD_MainArgument).l
		move.w	d2,(MCD_MainToken).l
		move.w	#1,(MCD_TerrainPending).l
		move.b	#1,(MCD_SubControl+1).l
		rts

; Finish before requesting a full VBlank, never wait for CD in the VDP handler.
MCD_FinishTerrainJob:
		cmpi.w	#1,(MCD_TerrainPending).l
		bne.s	.return
		move.w	sr,-(sp)
		disable_ints
		move.w	(MCD_MainToken).l,d2
		move.b	#1,(MCD_SubControl+1).l
		move.w	#MCD_WaitLimit,d3
		jsr	(MCD_WaitReply).l
		jcs	MCD_Unavailable
		move.w	d0,(MCD_TerrainStreamBytes).l
		move.w	#2,(MCD_TerrainPending).l
		move.w	(sp)+,sr
.return:
		rts

; Output-only VDP boundary: command, data-long count, data. The buffer is stable
; and MD-owned from FinishTerrainJob until the last record has been consumed.
LoadTilesAsYouMove:
		cmpi.w	#2,(MCD_TerrainPending).l
		bne.s	.return
		lea	(MCD_TerrainStream).l,a0
		movea.l	a0,a1
		moveq	#0,d0
		move.w	(MCD_TerrainStreamBytes).l,d0
		adda.l	d0,a1
		lea	(vdp_control_port).l,a5
		lea	(vdp_data_port).l,a6
		bra.s	.check
.record:
		move.l	(a0)+,(a5)
		move.w	(a0)+,d0
		subq.w	#1,d0
		bmi.s	.check
.data:
		move.l	(a0)+,(a6)
		dbf	d0,.data
.check:
		cmpa.l	a0,a1
		bhi.s	.record
		clr.w	(MCD_TerrainPending).l
.return:
		rts

LoadTilesFromStart:
		move.w	sr,-(sp)
		disable_ints
		bsr.w	MCD_PrepareTerrainFrame
		moveq	#1,d1
		bsr.w	MCD_StartTerrainDraw
		bsr.w	MCD_FinishTerrainJob
		bsr.w	LoadTilesAsYouMove
		move.w	(sp)+,sr
		rts

; Drain jobs before another scene reuses PRG/Word RAM. Level restarts call this
; before any RAM clear, so an in-flight job cannot lose its ownership state.
MCD_StopTerrain:
		bsr.w	MCD_FinishTerrainJob
		jsr	(MCD_FinishRingJob).l
		clr.b	(MCD_TerrainReady).l
		clr.w	(MCD_TerrainPending).l
		clr.w	(MCD_ObjectReplyPending).l
		jsr	(MCD_AcquireWordRAM).l
		jcs	MCD_Unavailable
		jmp	(MCD_RequireProgramRAM).l
