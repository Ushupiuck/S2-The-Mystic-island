; ===========================================================================
; Mega-CD sub-68000 terrain executor, included by mcd-main.asm.
; Resident blocks/layout/collision tables are in PRG RAM alongside the chunks.
; Complete object/sensor operations use the Gate Array mailbox. Tile streaming
; produces ordered VDP records in Word RAM; only the MD consumes those records.
; ===========================================================================

terrainshape: macro
		moveq	#0,d1
		move.b	obHeight(a0),d1
		movea.w	d1,a5			; normal radius, retained across tile scans
		move.b	obWidth(a0),d1
		movea.w	d1,a6			; tangent radius, retained across tile scans
		endm

terrainpath: macro solidfield
		move.l	(MCD_TerrainPath1_Sub).l,(MCD_TerrainPath_Sub).l
		cmpi.b	#$C,solidfield(a0)
		beq.s	.ready
		move.l	(MCD_TerrainPath2_Sub).l,(MCD_TerrainPath_Sub).l
.ready:
		endm

; ---------------------------------------------------------------------------
; Level-load transfer. MD prepared the shared collision bank once.
; CD decoding already wrote resident blocks, layout and chunks during loading.
MCD_SubTerrainLoad:
		lea	(MCD_SubWordRAM+(MCD_TerrainIndexStage-MCD_WordRAM)).l,a0
		lea	(MCD_TerrainIndex_Sub).l,a1
		move.w	#bytesToLcnt(MCD_TerrainData_SubEnd-MCD_TerrainIndex_Sub),d1
.copy:
		move.l	(a0)+,(a1)+
		dbf	d1,.copy
		move.l	#MCD_TerrainIndex_Sub,(MCD_TerrainPath1_Sub).l
		move.l	#MCD_TerrainIndex_Sub+1,(MCD_TerrainPath2_Sub).l
		move.l	#MCD_TerrainIndex_Sub,(MCD_TerrainPath_Sub).l

; Fold the upper row lookups onto the $800-pixel foreground in wrapping acts.
; Both rendering and every collision sensor use these same resident offsets.
; Ordinary acts retain all 32 authored rows; background dimensions stay separate.
MCD_SubTerrainInitLayout:
		tst.w	(MCD_SubMainArgument).w
		bpl.s	.ready
		lea	(MCD_TerrainLayout_Sub+PlaneLayout_FG).l,a0
		lea	((Level_YWrapMask+1)/$80)*2(a0),a1
		moveq	#PlaneLayout_Rows-(Level_YWrapMask+1)/$80-1,d0
.wrap:
		move.w	(a0)+,(a1)+
		dbf	d0,.wrap
.ready:
		bsr.w	Plane_Invalidate
		bset	#0,(MCD_SubMemoryMode).w
		moveq	#0,d0
		rts

; Indexed script access avoids exposing/stopping PRG RAM for a single word.
; Argument 1 = chunk row<<8 | column; argument 2 = word chunk ID.
MCD_SubTerrainLayout:
		move.w	(MCD_SubMainArgument).w,d1	; chunk row<<8 | column
		move.w	d1,d2
		lsr.w	#7,d2
		andi.w	#$3E,d2
		lea	(MCD_TerrainLayout_Sub+PlaneLayout_FG).l,a0
		move.w	(a0,d2.w),d2
		andi.w	#$FF,d1
		add.w	d1,d1
		add.w	PlaneLayout_ColumnTable(a0,d1.w),d2
		cmpi.w	#MCD_CommandLayoutWrite,d0
		bne.s	.read
		move.w	(MCD_SubMainArgument+2).w,(a0,d2.w)
.read:
		moveq	#0,d0
		move.w	(a0,d2.w),d0
		rts

; One complete floor/wall query, including its neighbour scan, flips and angle.
MCD_SubTerrainProbe:
		lea	(MCD_SubMainArgument).w,a2
		move.w	(a2)+,d3
		move.w	(a2)+,d2
		move.w	(a2)+,d5
		move.w	(a2)+,d6
		movea.w	(a2)+,a3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		move.b	1(a2),(a4)
		move.l	(MCD_TerrainPath1_Sub).l,(MCD_TerrainPath_Sub).l
		tst.b	(a2)
		beq.s	.path
		move.l	(MCD_TerrainPath2_Sub).l,(MCD_TerrainPath_Sub).l
.path:
		cmpi.w	#MCD_CommandTerrainWall,d0
		beq.s	.wall
		bsr.w	MCD_SubFindFloor
		bra.s	.result
.wall:
		bsr.w	MCD_SubFindWall
.result:
		bra.w	MCD_SubTerrainResult

; Common enemy/ring floor command: no generic command dispatch or X round trip.
; MCD_SubFindFloor supplies a1 before the normal result writer uses it.
MCD_SubTerrainObjectFloor:
		lea	(MCD_TerrainObject_Sub).l,a0
		move.w	(MCD_SubMainArgument).w,d3
		move.w	(MCD_SubMainArgument+2).w,obY(a0)
		move.w	(MCD_SubMainArgument+4).w,obHeight(a0)
		bsr.w	MCD_SubObjHitFloor2
		bra.w	MCD_SubTerrainResult

; Common-height floor points share one dispatch/mailbox round trip. No SST
; copy is needed; a5/a6 retain the input/output cursors across tile scans.
MCD_SubTerrainFloorBatch:
		lea	(MCD_SubMainArgument).w,a5
		lea	(MCD_SubOwnResult+4).w,a6
		moveq	#0,d0
		move.b	(MCD_SubMainCommand).w,d0
		ext.w	d0
		movea.w	d0,a0			; common signed height survives every scan
		moveq	#0,d7
		move.b	(MCD_SubMainFlags).w,d7
.point:
		move.w	(a5)+,d3
		move.w	(a5)+,d2
		add.w	a0,d2
		lea	(MCD_TerrainPrimary_Sub).l,a4
		clr.b	(a4)
		movea.w	#$10,a3
		clr.w	d6
		moveq	#$C,d5
		bsr.w	MCD_SubFindFloor
		move.w	d1,(a6)+
		dbf	d7,.point
		moveq	#0,d0
		rts

; Six words supply only the fields used by terrain, rather than copying an SST.
; Player paired sensors, distance selection and ground attachment all run here.
MCD_SubTerrainObject:
		lea	(MCD_TerrainObject_Sub).l,a0
		lea	(MCD_SubMainArgument).w,a1
		move.w	(a1)+,obX(a0)
		move.w	(a1)+,obY(a0)
		move.w	(a1)+,obHeight(a0)
		move.b	(a1)+,obAngle(a0)
		move.b	(a1)+,obStatus(a0)
		move.w	(a1)+,obTopSolidBit(a0)
		move.b	(a1)+,stick_to_convex(a0)
		move.b	(a1)+,obPrevAni(a0)
		moveq	#0,d1
		move.b	(MCD_SubMainCommand+1).w,d1
		subi.w	#MCD_TerrainAnglePos,d1
		lsl.w	#2,d1
		movea.l	.entries(pc,d1.w),a2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	(MCD_SubMainCommand).w,d0
		jsr	(a2)
		bsr.w	MCD_SubTerrainResult
		cmpi.b	#MCD_TerrainAnglePos,(MCD_SubMainCommand+1).w
		bne.s	.return
		; Ground attachment is the operation that mutates the supplied object.
		move.w	d1,(MCD_SubOwnResult+$C).w
		move.w	obX(a0),d0
		move.w	obY(a0),(MCD_SubOwnResult+4).w
		move.b	obAngle(a0),(MCD_SubOwnResult+6).w
		move.b	obStatus(a0),(MCD_SubOwnResult+7).w
		move.b	obPrevAni(a0),(MCD_SubOwnResult+9).w
.return:
		rts
.entries:
		dc.l	MCD_SubAnglePos
		dc.l	0			; $21 reads its packet in the direct executor
		dc.l	MCD_SubCheckRoomOverhead
		dc.l	MCD_SubTerrainFloorPair
		dc.l	MCD_SubProbeCeiling
		dc.l	MCD_SubChkFloorEdge
		dc.l	MCD_SubChkFloorEdge_Part2
		dc.l	MCD_SubObjHitFloor
		dc.l	MCD_SubObjHitFloor2
		dc.l	MCD_SubTerrainRightSensor
		dc.l	MCD_SubTerrainLeftSensor
		dc.l	MCD_SubObjHitWallRight
		dc.l	MCD_SubObjHitWallLeft
		dc.l	MCD_SubObjHitCeiling

MCD_SubTerrainResult:
		move.w	d1,(MCD_SubOwnResult+4).w
		move.w	d2,(MCD_SubOwnResult+6).w
		move.w	d3,(MCD_SubOwnResult+8).w
		move.w	(MCD_TerrainPrimary_Sub).l,(MCD_SubOwnResult+$A).w
		move.w	(a1),(MCD_SubOwnResult+$C).w
		rts

; The MD hands over Word RAM only for building a changed-strip stream.
; Full initial planes use the same constructor with argument 1.
MCD_SubTerrainDraw:
		lea	(MCD_TerrainFrame_Sub).l,a0
		lea	(MCD_TerrainCamera_Sub).l,a1
		moveq	#bytesToLcnt(MCD_TerrainFrame_SubEnd-MCD_TerrainCamera_Sub),d0
.frame:
		move.l	(a0)+,(a1)+
		dbf	d0,.frame
		lea	(MCD_TerrainStream_Sub).l,a6
		tst.w	(MCD_SubMainArgument).w
		bne.s	.initial
		bsr.w	Plane_DrawFrame
		bra.s	.done
.initial:
		bsr.w	Plane_Invalidate
		bsr.w	Plane_DrawFrame
.done:
		move.l	a6,d0
		subi.l	#MCD_TerrainStream_Sub,d0
		move.w	d0,(MCD_ObjectStreamBytes_Sub).l
		bsr.w	MCD_SubObjectsFrame
		bsr.w	MCD_SubPLCStep
		moveq	#0,d0
		move.w	(MCD_ObjectStreamBytes_Sub).l,d0
		bset	#0,(MCD_SubMemoryMode).w
		rts

		if PlaneDraw_MaxRecordBytes>MCD_TerrainStreamCapacity-$40
		fatal "Plane constructor exceeds its Word RAM stream allocation"
		endif
		include "_inc/Mega CD Plane Drawing.asm"

; Cached a5/a6 are the active normal/tangent radii. Ground attachment,
; jump clearance and growth reuse the same four paired sensor implementations.
MCD_SubAnglePos:
		btst	#status.player.on_object,obStatus(a0)
		beq.s	.terrain
		clr.w	(MCD_TerrainPrimary_Sub).l
		rts
.terrain:
		terrainshape
		terrainpath obTopSolidBit
		move.w	#$0303,(MCD_TerrainPrimary_Sub).l
		moveq	#0,d0
		move.b	obAngle(a0),d0
		lea	MCD_SubTerrainQuadrants(pc),a1
		move.b	(a1,d0.w),d7
		move.b	obTopSolidBit(a0),d5
		bsr.w	MCD_SubDirectionalPair
		cmp.b	obAngle(a0),d3
		beq.s	.distance		; a matching normal needs no clamp or write
		tst.b	stick_to_convex(a0)
		bne.s	.set_angle
		move.b	d3,d0
		sub.b	obAngle(a0),d0
		bpl.s	.angle_delta
		neg.b	d0
.angle_delta:
		cmpi.b	#$20,d0
		blo.s	.set_angle
		move.b	obAngle(a0),d3
		addi.b	#$20,d3
		andi.b	#$C0,d3
.set_angle:
		move.b	d3,obAngle(a0)
.distance:
		tst.w	d1
		beq.s	.return
		bpl.s	.reach
		cmpi.w	#-$E,d1
		blt.s	.return
		bra.s	.attach
.reach:
		tst.b	stick_to_convex(a0)
		bne.s	.attach
		; S2/S3&K speed-dependent attachment, shared by all four normals.
		move.b	(MCD_SubMainCommand).w,d0
		btst	#6,d7
		beq.s	.speed
		move.b	(MCD_SubMainFlags).w,d0
.speed:
		bpl.s	.positive
		neg.b	d0
.positive:
		addq.b	#4,d0
		cmpi.b	#$E,d0
		blo.s	.limit
		move.b	#$E,d0
.limit:
		cmp.b	d0,d1
		bgt.s	.detach
.attach:
		tst.b	d7
		beq.s	.floor
		cmpi.b	#$C0,d7
		beq.s	.right
		cmpi.b	#$80,d7
		beq.s	.ceiling
		sub.w	d1,obX(a0)
		rts
.right:
		add.w	d1,obX(a0)
		rts
.ceiling:
		sub.w	d1,obY(a0)
		rts
.floor:
		add.w	d1,obY(a0)
.return:
		rts
.detach:
		bset	#status.player.in_air,obStatus(a0)
		bclr	#status.player.pushing,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts

; d7.b = outward normal. d5 remains the caller's top or L/R/B solidity.
MCD_SubDirectionalPair:
		tst.b	d7
		beq.w	MCD_SubFloorSensors
		cmpi.b	#$40,d7
		beq.w	MCD_SubLeftPair
		cmpi.b	#$80,d7
		beq.w	MCD_SubCeilingPair
		bra.w	MCD_SubRightPair

; =============== S U B R O U T I N E =======================================


MCD_SubFindTerrainBlock:
		move.w	d2,d0
		lsr.w	#6,d0
		andi.w	#$3E,d0
		lea	(MCD_TerrainLayout_Sub+PlaneLayout_FG).l,a1
		move.w	(a1,d0.w),d0
		move.w	d3,d1
		lsr.w	#3,d1
		move.w	d1,d4
		lsr.w	#3,d1
		andi.w	#$1FE,d1
		add.w	PlaneLayout_ColumnTable(a1,d1.w),d0
		move.w	(a1,d0.w),d1
		lsl.w	#2,d1
		lea	Plane_ChunkAddresses(pc),a1
		movea.l	(a1,d1.w),a1
		move.w	d2,d0
		andi.w	#$70,d0
		adda.w	d0,a1
		andi.w	#$E,d4
		adda.w	d4,a1
		rts
; ===========================================================================
; Scans vertically for up to 2 16x16 blocks to find solid ground or ceiling.
; d2 = y_pos
; d3 = x_pos
; d5 = ($c,$d) or ($e,$f) - solidity type bit (L/R/B or top)
; d6 = $0000 for no flip, $0800 for vertical flip
; a3 = delta-y for next location to check if current one is empty
; a4 = pointer to angle buffer
; returns relevant block ID in (a1)
; returns distance in d1
; returns angle in (a4)

MCD_SubFindFloor:
		bsr.w	MCD_SubFindTerrainBlock
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	MCD_Subloc_12DBE
		btst	d5,d4
		bne.s	MCD_Subloc_12DCC

MCD_Subloc_12DBE:
		add.w	a3,d2
		bsr.w	MCD_SubFindFloor2
		sub.w	a3,d2
		addi.w	#$10,d1
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12DCC:
		movea.l	(MCD_TerrainPath_Sub).l,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	MCD_Subloc_12DBE
		lea	(MCD_TerrainAngles_Sub).l,a2
		move.b	(a2,d0.w),(a4)
		lsl.w	#4,d0
		move.w	d3,d1
		btst	#$A,d4
		beq.s	+
		not.w	d1
		neg.b	(a4)
+
		btst	#$B,d4
		beq.s	+
		addi.b	#$40,(a4)
		neg.b	(a4)
		subi.b	#$40,(a4)
+
		andi.w	#$F,d1
		add.w	d0,d1
		lea	(MCD_TerrainHeights_Sub).l,a2
		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$B,d4
		beq.s	+
		neg.w	d0
+
		tst.w	d0
		beq.w	MCD_Subloc_12DBE
		bmi.s	MCD_Subloc_12E38
		cmpi.b	#$10,d0
		beq.s	MCD_Subloc_12E44
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12E38:
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	MCD_Subloc_12DBE

MCD_Subloc_12E44:
		sub.w	a3,d2
		bsr.w	MCD_SubFindFloor2
		add.w	a3,d2
		subi.w	#$10,d1
		rts
; End of function MCD_SubFindFloor


; =============== S U B R O U T I N E =======================================


MCD_SubFindFloor2:
		bsr.w	MCD_SubFindTerrainBlock
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	MCD_Subloc_12E64
		btst	d5,d4
		bne.s	MCD_Subloc_12E72

MCD_Subloc_12E64:
		move.w	#$F,d1
		move.w	d2,d0
		andi.w	#$F,d0
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12E72:
		movea.l	(MCD_TerrainPath_Sub).l,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	MCD_Subloc_12E64
		lea	(MCD_TerrainAngles_Sub).l,a2
		move.b	(a2,d0.w),(a4)
		lsl.w	#4,d0
		move.w	d3,d1
		btst	#$A,d4
		beq.s	MCD_Subloc_12E96
		not.w	d1
		neg.b	(a4)

MCD_Subloc_12E96:
		btst	#$B,d4
		beq.s	MCD_Subloc_12EA6
		addi.b	#$40,(a4)
		neg.b	(a4)
		subi.b	#$40,(a4)

MCD_Subloc_12EA6:
		andi.w	#$F,d1
		add.w	d0,d1
		lea	(MCD_TerrainHeights_Sub).l,a2
		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$B,d4
		beq.s	MCD_Subloc_12EC2
		neg.w	d0

MCD_Subloc_12EC2:
		tst.w	d0
		beq.w	MCD_Subloc_12E64
		bmi.s	MCD_Subloc_12ED8
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12ED8:
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	MCD_Subloc_12E64
		not.w	d1
		rts
; End of function MCD_SubFindFloor2


; =============== S U B R O U T I N E =======================================


MCD_SubFindWall:
		bsr.w	MCD_SubFindTerrainBlock
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	MCD_Subloc_12EFA
		btst	d5,d4
		bne.s	MCD_Subloc_12F08

MCD_Subloc_12EFA:
		add.w	a3,d3
		bsr.w	MCD_SubFindWall2
		sub.w	a3,d3
		addi.w	#$10,d1
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12F08:
		movea.l	(MCD_TerrainPath_Sub).l,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	MCD_Subloc_12EFA
		lea	(MCD_TerrainAngles_Sub).l,a2
		move.b	(a2,d0.w),(a4)
		lsl.w	#4,d0
		move.w	d2,d1
		btst	#$B,d4
		beq.s	MCD_Subloc_12F34
		not.w	d1
		addi.b	#$40,(a4)
		neg.b	(a4)
		subi.b	#$40,(a4)

MCD_Subloc_12F34:
		btst	#$A,d4
		beq.s	MCD_Subloc_12F3C
		neg.b	(a4)

MCD_Subloc_12F3C:
		andi.w	#$F,d1
		add.w	d0,d1
		lea	(MCD_TerrainWidths_Sub).l,a2
		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$A,d4
		beq.s	MCD_Subloc_12F58
		neg.w	d0

MCD_Subloc_12F58:
		tst.w	d0
		beq.w	MCD_Subloc_12EFA
		bmi.s	MCD_Subloc_12F74
		cmpi.b	#$10,d0
		beq.s	MCD_Subloc_12F80
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12F74:
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	MCD_Subloc_12EFA

MCD_Subloc_12F80:
		sub.w	a3,d3
		bsr.w	MCD_SubFindWall2
		add.w	a3,d3
		subi.w	#$10,d1
		rts
; End of function MCD_SubFindWall


; =============== S U B R O U T I N E =======================================


MCD_SubFindWall2:
		bsr.w	MCD_SubFindTerrainBlock
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	MCD_Subloc_12FA0
		btst	d5,d4
		bne.s	MCD_Subloc_12FAE

MCD_Subloc_12FA0:
		move.w	#$F,d1
		move.w	d3,d0
		andi.w	#$F,d0
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12FAE:
		movea.l	(MCD_TerrainPath_Sub).l,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	MCD_Subloc_12FA0
		lea	(MCD_TerrainAngles_Sub).l,a2
		move.b	(a2,d0.w),(a4)
		lsl.w	#4,d0
		move.w	d2,d1
		btst	#$B,d4
		beq.s	MCD_Subloc_12FDA
		not.w	d1
		addi.b	#$40,(a4)
		neg.b	(a4)
		subi.b	#$40,(a4)

MCD_Subloc_12FDA:
		btst	#$A,d4
		beq.s	MCD_Subloc_12FE2
		neg.b	(a4)

MCD_Subloc_12FE2:
		andi.w	#$F,d1
		add.w	d0,d1
		lea	(MCD_TerrainWidths_Sub).l,a2
		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$A,d4
		beq.s	MCD_Subloc_12FFE
		neg.w	d0

MCD_Subloc_12FFE:
		tst.w	d0
		beq.w	MCD_Subloc_12FA0
		bmi.s	MCD_Subloc_13014
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_13014:
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	MCD_Subloc_12FA0
		not.w	d1
		rts
; End of function MCD_SubFindWall2

; =============== S U B R O U T I N E =======================================

; Projected forward probe: read its packet in place instead of copying an
; SST and entering the generic operation dispatch. The caller on MD still
; sends the ordinary twelve-byte snapshot; only the fields below are read.
MCD_SubTerrainForward:
		lea	(MCD_SubMainArgument).w,a0
		moveq	#0,d1
		move.b	MCD_TerrainPacketRadii+1(a0),d1
		movea.w	d1,a6
		terrainpath MCD_TerrainPacketSolidity
		move.b	MCD_TerrainPacketSolidity+1(a0),d5
		move.w	MCD_TerrainPacketX(a0),d3
		move.w	MCD_TerrainPacketY(a0),d2
		moveq	#0,d0
		move.b	(MCD_SubMainCommand).w,d0
		pea	MCD_SubTerrainResult(pc)
		move.b	d0,(MCD_TerrainPrimary_Sub).l
		move.b	d0,(MCD_TerrainSecondary_Sub).l
		; The request zero-extends its input angle. Place the shared table
		; within the PC-indexed range, avoiding a pointer and scratch copy.
		move.b	MCD_SubTerrainQuadrants(pc,d0.w),d7
		andi.b	#$38,d0
		bne.s	.front
		; A near-cardinal tangent samples the lower side of the current body.
		; Keep the sample inside its normal radius, including compact shapes.
		moveq	#0,d1
		move.b	MCD_TerrainPacketRadii(a0),d1
		sub.w	a6,d1
		subq.w	#1,d1
		ble.s	.front
		move.b	MCD_TerrainPacketAngle(a0),d0
		andi.b	#$C0,d0
		beq.s	.bias_floor
		cmpi.b	#$40,d0
		beq.s	.bias_left
		cmpi.b	#$80,d0
		beq.s	.bias_ceiling
		add.w	d1,d3
		bra.s	.front
.bias_left:
		sub.w	d1,d3
		bra.s	.front
.bias_ceiling:
		sub.w	d1,d2
		bra.s	.front
.bias_floor:
		add.w	d1,d2
.front:
		; Tangential reach is the live width plus one contact pixel in every
		; orientation. No full-size or miniature reach is stored here.
		tst.b	d7
		beq.w	MCD_SubForwardFloor
		cmpi.b	#$40,d7
		beq.w	MCD_SubForwardLeft
		cmpi.b	#$80,d7
		beq.w	MCD_SubForwardCeiling
		bra.w	MCD_SubForwardRight

; Match CD/S2/S3&K's asymmetric 45-degree boundary rounding exactly.
; Indexed reads replace the repeated sign/rounding branches in hot callers.
MCD_SubTerrainQuadrants:
		dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
		dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
		dc.b	$00,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40
		dc.b	$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40
		dc.b	$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40
		dc.b	$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40
		dc.b	$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80
		dc.b	$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80
		dc.b	$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80
		dc.b	$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80
		dc.b	$80,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0
		dc.b	$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0
		dc.b	$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0
		dc.b	$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0
		dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
		dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

MCD_SubCheckRoomOverhead:
		terrainshape
		terrainpath obTopSolidBit
		move.b	obLRBSolidBit(a0),d5
		move.b	d0,(MCD_TerrainPrimary_Sub).l
		move.b	d0,(MCD_TerrainSecondary_Sub).l
		addi.b	#$20,d0
		andi.b	#$C0,d0
		move.b	d0,d7
		bra.w	MCD_SubDirectionalPair

MCD_SubTerrainFloorPair:
		terrainshape
		terrainpath obTopSolidBit
MCD_SubFloorPair:
		move.b	obTopSolidBit(a0),d5
MCD_SubFloorSensors:
		move.w	obY(a0),d2
		add.w	a5,d2
		move.w	obX(a0),d3
		add.w	a6,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindFloor
		move.w	d1,-(sp)
		; Tile scans preserve both sensor coordinates, step and solidity.
		sub.w	a6,d3
		sub.w	a6,d3
		lea	(MCD_TerrainSecondary_Sub).l,a4
		bsr.w	MCD_SubFindFloor
		move.w	(sp)+,d0
		clr.b	d2
MCD_SubChoosePair:
		move.b	(MCD_TerrainSecondary_Sub).l,d3
		cmp.w	d0,d1
		ble.s	.angle
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		exg	d0,d1
.angle:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:
		rts

MCD_SubForwardFloor:
		add.w	a6,d2
		addq.w	#1,d2
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindFloor
		clr.b	d2
		bra.w	MCD_SubSingleAngle

; Sonic_HitFloor:
MCD_SubChkFloorEdge:
		move.w	obX(a0),d3
MCD_SubChkFloorEdge_Part2:			; S3&K edge balancing also probes an offset X in d3
		move.w	obY(a0),d2
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.l	(MCD_TerrainPath1_Sub).l,(MCD_TerrainPath_Sub).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	MCD_Subloc_1322E
		move.l	(MCD_TerrainPath2_Sub).l,(MCD_TerrainPath_Sub).l

MCD_Subloc_1322E:
		lea	(MCD_TerrainPrimary_Sub).l,a4
		clr.b	(a4)
		movea.w	#$10,a3
		clr.w	d6
		move.b	obTopSolidBit(a0),d5
		bsr.w	MCD_SubFindFloor
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		btst	#0,d3
		beq.s	.return
		clr.b	d3
.return:	rts
; End of function MCD_SubChkFloorEdge


; =============== S U B R O U T I N E =======================================

;  ObjGetFloorDist, ObjFloorDist:
MCD_SubObjHitFloor:
		move.w	obX(a0),d3


MCD_SubObjHitFloor2:
		move.w	obY(a0),d2
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		lea	(MCD_TerrainPrimary_Sub).l,a4
		clr.b	(a4)
		movea.w	#$10,a3
		clr.w	d6
		moveq	#$C,d5
		bsr.w	MCD_SubFindFloor
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		btst	#0,d3
		beq.s	.return
		clr.b	d3
.return:	rts
; End of function MCD_SubObjHitFloor

; ---------------------------------------------------------------------------

MCD_SubRightPair:
		move.w	obY(a0),d2
		sub.w	a6,d2
		move.w	obX(a0),d3
		add.w	a5,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindWall
		move.w	d1,-(sp)
		add.w	a6,d2
		add.w	a6,d2
		lea	(MCD_TerrainSecondary_Sub).l,a4
		bsr.w	MCD_SubFindWall
		move.w	(sp)+,d0
		move.b	#$C0,d2
		bra.w	MCD_SubChoosePair


MCD_SubTerrainRightSensor:
		terrainpath obTopSolidBit
		moveq	#0,d1
		move.b	obWidth(a0),d1
		movea.w	d1,a6
		move.b	obLRBSolidBit(a0),d5
MCD_SubRightSensor:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
MCD_SubForwardRight:
		add.w	a6,d3
		addq.w	#1,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindWall
		move.b	#$C0,d2
MCD_SubSingleAngle:
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:
		rts


MCD_SubObjHitWallRight:
		move.w	obX(a0),d3
		move.w	obY(a0),d2
		lea	(MCD_TerrainPrimary_Sub).l,a4
		clr.b	(a4)
		movea.w	#$10,a3
		clr.w	d6
		moveq	#$D,d5
		bsr.w	MCD_SubFindWall
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	#$C0,d3
.return:	rts
; End of function MCD_SubObjHitWallRight


; =============== S U B R O U T I N E =======================================


; Proposed X/Y and radii, both solidity bits, outward direction in the
; command high byte. Test the pair and center with one retained shape/path.
MCD_SubTerrainHeadroom:
		lea	(MCD_TerrainObject_Sub).l,a0
		lea	(MCD_SubMainArgument).w,a1
		move.w	(a1)+,obX(a0)
		move.w	(a1)+,obY(a0)
		move.w	(a1)+,obHeight(a0)
		move.w	(a1),obTopSolidBit(a0)
		terrainshape
		terrainpath obTopSolidBit
		move.b	obLRBSolidBit(a0),d5
		move.b	(MCD_SubMainCommand).w,d7
		pea	.paired(pc)
		cmpi.b	#$80,d7
		beq.w	MCD_SubCeilingPair	; ordinary headroom avoids the other normals
		bra.w	MCD_SubDirectionalPair
.paired:
		tst.w	d1
		bmi.s	.done
		bsr.s	MCD_SubNormalCenter
.done:
		move.w	d1,d0
		rts

; Ordinary ceiling/era probes use the same pair. Nonzero d0 also checks the
; center; angle buffers are private to CD unless the normal result publishes.
MCD_SubProbeCeiling:
		terrainshape
		terrainpath obTopSolidBit
		move.b	obLRBSolidBit(a0),d5
		tst.b	d0
		beq.w	MCD_SubCeilingPair
		bsr.w	MCD_SubCeilingPair
		tst.w	d1
		bmi.s	.return
		move.b	#$80,d7
		bra.s	MCD_SubNormalCenter
.return:
		rts

MCD_SubNormalCenter:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		cmpi.b	#$80,d7
		beq.s	.ceiling
		tst.b	d7
		beq.s	.floor
		cmpi.b	#$40,d7
		beq.s	.left
		add.w	a5,d3
		movea.w	#$10,a3
		clr.w	d6
		bra.w	MCD_SubFindWall
.left:
		sub.w	a5,d3
		eori.w	#$F,d3
		movea.w	#-$10,a3
		move.w	#$400,d6
		bra.w	MCD_SubFindWall
.ceiling:
		sub.w	a5,d2
		eori.w	#$F,d2
		movea.w	#-$10,a3
		move.w	#$800,d6
		bra.w	MCD_SubFindFloor
.floor:
		add.w	a5,d2
		movea.w	#$10,a3
		clr.w	d6
		bra.w	MCD_SubFindFloor

MCD_SubCeilingPair:
		move.w	obY(a0),d2
		sub.w	a5,d2
		eori.w	#$F,d2
		move.w	obX(a0),d3
		add.w	a6,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MCD_SubFindFloor
		move.w	d1,-(sp)
		sub.w	a6,d3
		sub.w	a6,d3
		lea	(MCD_TerrainSecondary_Sub).l,a4
		bsr.w	MCD_SubFindFloor
		move.w	(sp)+,d0
		move.b	#$80,d2
		bra.w	MCD_SubChoosePair

MCD_SubForwardCeiling:
		sub.w	a6,d2
		subq.w	#1,d2
		eori.w	#$F,d2
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MCD_SubFindFloor
		move.b	#$80,d2
		bra.w	MCD_SubSingleAngle


MCD_SubObjHitCeiling:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d2
		eori.w	#$F,d2
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		moveq	#$D,d5
		bsr.w	MCD_SubFindFloor
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	#$80,d3
.return:	rts
; ---------------------------------------------------------------------------

MCD_SubLeftPair:
		move.w	obY(a0),d2
		sub.w	a6,d2
		move.w	obX(a0),d3
		sub.w	a5,d3
		eori.w	#$F,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MCD_SubFindWall
		move.w	d1,-(sp)
		add.w	a6,d2
		add.w	a6,d2
		lea	(MCD_TerrainSecondary_Sub).l,a4
		bsr.w	MCD_SubFindWall
		move.w	(sp)+,d0
		move.b	#$40,d2
		bra.w	MCD_SubChoosePair


MCD_SubTerrainLeftSensor:
		terrainpath obTopSolidBit
		moveq	#0,d1
		move.b	obWidth(a0),d1
		movea.w	d1,a6
		move.b	obLRBSolidBit(a0),d5
MCD_SubLeftSensor:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
MCD_SubForwardLeft:
		sub.w	a6,d3
		subq.w	#1,d3
		eori.w	#$F,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MCD_SubFindWall
		move.b	#$40,d2
		bra.w	MCD_SubSingleAngle

; Subroutine to detect when an object hits a wall to its left.

MCD_SubObjHitWallLeft:
		move.w	obX(a0),d3
		move.w	obY(a0),d2
		eori.w	#$F,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		clr.b	(a4)
		movea.w	#-$10,a3
		move.w	#$400,d6
		moveq	#$D,d5
		bsr.w	MCD_SubFindWall
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	#$40,d3
.return:	rts
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Whole airborne contact pass: both walls, ceiling and paired floor sensors.
; The request is twelve bytes plus the solidity nibbles in the command byte.
; MD's communication flag supplies the wind-tunnel condition. No Word-RAM or
; PRG-RAM handoff is needed. Only actual inertia changes are applied by MD.
MCD_SubTerrainAir:
		lea	(MCD_TerrainObject_Sub).l,a0
		lea	(MCD_SubMainArgument).w,a1
		move.w	(a1)+,obX(a0)
		move.w	(a1)+,obY(a0)
		move.l	(a1)+,obVelX(a0)
		move.w	(a1)+,obHeight(a0)
		move.b	(a1)+,obAngle(a0)
		move.b	(a1)+,obStatus(a0)
		move.b	(MCD_SubMainCommand).w,d0
		move.b	d0,d1
		lsr.b	#4,d0
		andi.b	#$F,d1
		move.b	d0,obTopSolidBit(a0)
		move.b	d1,obLRBSolidBit(a0)
		terrainshape
		bsr.w	MCD_Air_Sonic_DoLevelCollision
		move.w	obY(a0),(MCD_SubOwnResult+2).w
		move.l	obVelX(a0),(MCD_SubOwnResult+4).w
		move.w	obInertia(a0),(MCD_SubOwnResult+8).w
		move.w	obHeight(a0),(MCD_SubOwnResult+$A).w
		move.b	obAngle(a0),(MCD_SubOwnResult+$C).w
		move.b	obStatus(a0),(MCD_SubOwnResult+$D).w
		move.w	obX(a0),d0
		rts

; Player landing bookkeeping changes animation, radii and ancillary state,
; but no later terrain probe uses them in this pass. Apply that callback on MD
; after the coherent contact result, preserving each character's own behavior.
MCD_SubAirLand:
		bset	#MCD_ServiceLanded,(MCD_SubOwnFlags).w
		rts

MCD_Air_Sonic_DoLevelCollision:
		move.l	(MCD_TerrainPath1_Sub).l,(MCD_TerrainPath_Sub).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	+
		move.l	(MCD_TerrainPath2_Sub).l,(MCD_TerrainPath_Sub).l
+
		move.b	obLRBSolidBit(a0),d5
		move.w	obVelX(a0),d0				; get X speed
		move.w	obVelY(a0),d1				; get Y speed
		bpl.s	MCD_Air_SonAirCol_PosY				; if it's positive, branch
		cmp.w	d0,d1					; are we moving towards the left?
		bgt.w	MCD_Air_Sonic_FloorLeft				; if so, branch
		neg.w	d0					; negate for right cheeck
		cmp.w	d0,d1					; are we moving towards the right?
		bge.w	MCD_Air_Sonic_FloorRight			; if so, branch
		bra.w	MCD_Air_Sonic_FloorUp				; we are moving upwards
; ===========================================================================

MCD_Air_SonAirCol_PosY:
		cmp.w	d0,d1					; are we moving towards the right?
		blt.w	MCD_Air_Sonic_FloorRight			; if so, branch
		neg.w	d0					; negate for left check
		cmp.w	d0,d1					; are we moving towards the left?
		ble.w	MCD_Air_Sonic_FloorLeft				; if so, branch
		bsr.w	MCD_SubLeftSensor
		tst.w	d1
		bpl.s	+
		; A shallow floor sampled at the waist belongs to the landing pair.
		; Clipping it as a side wall first would erase horizontal momentum.
		move.b	d3,d0
		addi.b	#$20,d0
		cmpi.b	#$40,d0
		blo.s	+
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
+
		bsr.w	MCD_SubRightSensor
		tst.w	d1
		bpl.s	+
		; A shallow floor sampled at the waist belongs to the landing pair.
		; Clipping it as a side wall first would erase horizontal momentum.
		move.b	d3,d0
		addi.b	#$20,d0
		cmpi.b	#$40,d0
		blo.s	+
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
+
		bsr.w	MCD_SubFloorPair
		tst.w	d1
		bpl.s	.return
		move.b	obVelY(a0),d2
		addq.b	#8,d2
		neg.b	d2
		cmp.b	d2,d1
		bge.s	+
		cmp.b	d2,d0
		blt.s	.return
+
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	MCD_SubAirLand
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	MCD_Air_loc_105C0
		move.b	d3,d0
		addi.b	#$10,d0
		andi.b	#$20,d0
		beq.s	MCD_Air_loc_105B2
		asr	obVelY(a0)
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).w
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MCD_Air_loc_105B2:
		clr.w	obVelY(a0)
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).w
		move.w	obVelX(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

MCD_Air_loc_105C0:
		clr.w	obVelX(a0)
		cmpi.w	#$FC0,obVelY(a0)
		ble.s	MCD_Air_loc_105D4
		move.w	#$FC0,obVelY(a0)

MCD_Air_loc_105D4:
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).w
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MCD_Air_Sonic_FloorLeft:
		bsr.w	MCD_SubLeftSensor
		tst.w	d1
		bpl.s	MCD_Air_loc_105FE
		tst.w	obVelY(a0)
		bmi.s	.wall
		move.b	d3,d0
		addi.b	#$20,d0
		cmpi.b	#$40,d0
		blo.s	MCD_Air_loc_105FE
.wall:
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).w
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

MCD_Air_loc_105FE:
		bsr.w	MCD_SubCeilingPair
		tst.w	d1
		bpl.s	MCD_Air_loc_10618
		neg.w	d1
		cmpi.w	#Sonic_CeilingPenetrationLimit,d1
		bhs.s	MCD_Air_Sonic_FloorLeft_OppositeWall
		add.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MCD_Air_Sonic_FloorLeft_OppositeWall:
		bsr.w	MCD_SubRightSensor
		tst.w	d1
		bpl.s	.return
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
.return:
		rts

MCD_Air_loc_10618:
		tst.b	(MCD_SubMainFlags).w
		bne.s	.checkfloor
		tst.w	obVelY(a0)
		bmi.s	.return
.checkfloor:
		bsr.w	MCD_SubFloorPair
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	MCD_SubAirLand
		clr.w	obVelY(a0)
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).w
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MCD_Air_Sonic_FloorUp:
		bsr.w	MCD_SubLeftSensor
		tst.w	d1
		bpl.s	MCD_Air_loc_10658
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)

MCD_Air_loc_10658:
		bsr.w	MCD_SubRightSensor
		tst.w	d1
		bpl.s	MCD_Air_loc_1066A
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)

MCD_Air_loc_1066A:
		bsr.w	MCD_SubCeilingPair
		tst.w	d1
		bpl.s	.return
		sub.w	d1,obY(a0)
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	MCD_Air_loc_1068A
		clr.w	obVelY(a0)
.return:	rts
; ---------------------------------------------------------------------------

MCD_Air_loc_1068A:
		move.b	d3,obAngle(a0)
		bsr.w	MCD_SubAirLand
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).w
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MCD_Air_Sonic_FloorRight:
		bsr.w	MCD_SubRightSensor
		tst.w	d1
		bpl.s	MCD_Air_loc_106BC
		tst.w	obVelY(a0)
		bmi.s	.wall
		move.b	d3,d0
		addi.b	#$20,d0
		cmpi.b	#$40,d0
		blo.s	MCD_Air_loc_106BC
.wall:
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).w
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

MCD_Air_loc_106BC:
		bsr.w	MCD_SubCeilingPair
		tst.w	d1
		bpl.s	MCD_Air_loc_106D6
		sub.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MCD_Air_loc_106D6:
		tst.b	(MCD_SubMainFlags).w
		bne.s	.checkfloor
		tst.w	obVelY(a0)
		bmi.s	.return
.checkfloor:
		bsr.w	MCD_SubFloorPair
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	MCD_SubAirLand
		clr.w	obVelY(a0)
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).w
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
