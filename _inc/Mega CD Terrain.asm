; ===========================================================================
; Mega-CD sub-68000 terrain executor, included by mcd-main.asm.
; Resident blocks/layout/collision tables are in PRG RAM alongside the chunks.
; Complete object/sensor operations use the Gate Array mailbox. Tile streaming
; produces ordered VDP records in Word RAM; only the MD consumes those records.
; ===========================================================================

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
		bsr.w	Plane_Invalidate
		bset	#0,(MCD_SubMemoryMode).l
		moveq	#0,d0
		rts

; Indexed script access avoids exposing/stopping PRG RAM for a single word.
; Argument 1 = chunk row<<8 | column; argument 2 = word chunk ID.
MCD_SubTerrainLayout:
		move.w	(MCD_SubMainArgument).l,d1	; chunk row<<8 | column
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
		move.w	(MCD_SubMainArgument+2).l,(a0,d2.w)
.read:
		moveq	#0,d0
		move.w	(a0,d2.w),d0
		rts

; One complete floor/wall query, including its neighbour scan, flips and angle.
MCD_SubTerrainProbe:
		lea	(MCD_SubMainArgument).l,a2
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

; Six words supply only the fields used by terrain, rather than copying an SST.
; Player paired sensors, distance selection and ground attachment all run here.
MCD_SubTerrainObject:
		lea	(MCD_TerrainObject_Sub).l,a0
		lea	(MCD_SubMainArgument).l,a1
		move.w	(a1)+,obX(a0)
		move.w	(a1)+,obY(a0)
		move.w	(a1)+,obHeight(a0)
		cmpi.b	#MCD_TerrainObjectFloorX,(MCD_SubMainCommand+1).l
		beq.s	.floor
		move.b	(a1)+,obAngle(a0)
		move.b	(a1)+,obStatus(a0)
		move.w	(a1)+,obTopSolidBit(a0)
		move.b	(a1)+,stick_to_convex(a0)
		move.b	(a1)+,obPrevAni(a0)
		moveq	#0,d1
		move.b	(MCD_SubMainCommand+1).l,d1
		subi.w	#MCD_TerrainAnglePos,d1
		lsl.w	#2,d1
		movea.l	.entries(pc,d1.w),a2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	(MCD_SubMainCommand).l,d0
		jsr	(a2)
		bsr.w	MCD_SubTerrainResult
		cmpi.b	#MCD_TerrainAnglePos,(MCD_SubMainCommand+1).l
		bne.s	.return
		; Ground attachment is the operation that mutates the supplied object.
		move.w	d1,(MCD_SubOwnResult+$C).l
		move.w	obX(a0),d0
		move.w	obY(a0),(MCD_SubOwnResult+4).l
		move.b	obAngle(a0),(MCD_SubOwnResult+6).l
		move.b	obStatus(a0),(MCD_SubOwnResult+7).l
		move.b	obPrevAni(a0),(MCD_SubOwnResult+9).l
.return:
		rts
.floor:
		move.w	obX(a0),d3
		bsr.w	MCD_SubObjHitFloor2
		bra.w	MCD_SubTerrainResult
.entries:
		dc.l	MCD_SubAnglePos
		dc.l	MCD_SubCalcRoomInFront
		dc.l	MCD_SubCheckRoomOverhead
		dc.l	MCD_SubFloorPair
		dc.l	MCD_SubCeilingPair
		dc.l	MCD_SubChkFloorEdge
		dc.l	MCD_SubChkFloorEdge_Part2
		dc.l	MCD_SubObjHitFloor
		dc.l	MCD_SubObjHitFloor2
		dc.l	MCD_SubRightSensor
		dc.l	MCD_SubLeftSensor
		dc.l	MCD_SubObjHitWallRight
		dc.l	MCD_SubObjHitWallLeft
		dc.l	MCD_SubObjHitCeiling

MCD_SubTerrainResult:
		move.w	d1,(MCD_SubOwnResult+4).l
		move.w	d2,(MCD_SubOwnResult+6).l
		move.w	d3,(MCD_SubOwnResult+8).l
		move.w	(MCD_TerrainPrimary_Sub).l,(MCD_SubOwnResult+$A).l
		move.w	(a1),(MCD_SubOwnResult+$C).l
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
		tst.w	(MCD_SubMainArgument).l
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
		bset	#0,(MCD_SubMemoryMode).l
		rts

		if PlaneDraw_MaxRecordBytes>MCD_TerrainStreamCapacity-$40
		fatal "Plane constructor exceeds its Word RAM stream allocation"
		endif
		include "_inc/Mega CD Plane Drawing.asm"

MCD_SubAnglePos:
		move.l	(MCD_TerrainPath1_Sub).l,(MCD_TerrainPath_Sub).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	MCD_Subloc_12A14
		move.l	(MCD_TerrainPath2_Sub).l,(MCD_TerrainPath_Sub).l

MCD_Subloc_12A14:
		move.b	obTopSolidBit(a0),d5
		btst	#3,obStatus(a0)
		beq.s	MCD_Subloc_12A2C
		moveq	#0,d0
		move.b	d0,(MCD_TerrainPrimary_Sub).l
		move.b	d0,(MCD_TerrainSecondary_Sub).l
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12A2C:
		moveq	#3,d0
		move.b	d0,(MCD_TerrainPrimary_Sub).l
		move.b	d0,(MCD_TerrainSecondary_Sub).l
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		bpl.s	MCD_Subloc_12A4E
		move.b	obAngle(a0),d0
		bpl.s	MCD_Subloc_12A48
		subq.b	#1,d0

MCD_Subloc_12A48:
		addi.b	#$20,d0
		bra.s	MCD_Subloc_12A5A
; ---------------------------------------------------------------------------

MCD_Subloc_12A4E:
		move.b	obAngle(a0),d0
		bpl.s	MCD_Subloc_12A56
		addq.b	#1,d0

MCD_Subloc_12A56:
		addi.b	#$1F,d0

MCD_Subloc_12A5A:
		andi.b	#$C0,d0
		cmpi.b	#$40,d0
		beq.w	MCD_SubSonic_WalkVertL
		cmpi.b	#$80,d0
		beq.w	MCD_SubSonic_WalkCeiling
		cmpi.b	#$C0,d0
		beq.w	MCD_SubSonic_WalkVertR
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindFloor
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		neg.w	d0
		add.w	d0,d3
		lea	(MCD_TerrainSecondary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindFloor
		move.w	(sp)+,d0
		bsr.w	MCD_SubChooseTerrainAngle
		tst.w	d1
		beq.s	.return
		bpl.s	MCD_Subloc_12AE6
		cmpi.w	#-$E,d1
		blt.s	.return
		add.w	d1,obY(a0)
.return:	rts
; ---------------------------------------------------------------------------

MCD_Subloc_12AE6:
		cmpi.w	#$E,d1
		bgt.s	MCD_Subloc_12AF2

MCD_Subloc_12AEC:
		add.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12AF2:
		tst.b	stick_to_convex(a0)
		bne.s	MCD_Subloc_12AEC
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts
; End of function MCD_SubAnglePos

; =============== S U B R O U T I N E =======================================

; MCD_SubChooseTerrainAngle:
MCD_SubChooseTerrainAngle:
		move.b	(MCD_TerrainSecondary_Sub).l,d2
		cmp.w	d0,d1
		ble.s	+
		move.b	(MCD_TerrainPrimary_Sub).l,d2
		move.w	d0,d1
+
		btst	#0,d2
		bne.s	MCD_Subloc_12B90
		; Running discs need S1's valid angles around their tight curves.
		; Keep the angle-change limit for ordinary terrain.
		tst.b	stick_to_convex(a0)
		bne.s	.set_angle
		move.b	d2,d0
		sub.b	obAngle(a0),d0
		bpl.s	+
		neg.b	d0
+
		cmpi.b	#$20,d0
		bhs.s	MCD_Subloc_12B90
.set_angle:
		move.b	d2,obAngle(a0)
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12B90:
		move.b	obAngle(a0),d2
		addi.b	#$20,d2
		andi.b	#$C0,d2
		move.b	d2,obAngle(a0)
		rts
; End of function MCD_SubChooseTerrainAngle

; ---------------------------------------------------------------------------

MCD_SubSonic_WalkVertR:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		neg.w	d0
		add.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindWall
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(MCD_TerrainSecondary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindWall
		move.w	(sp)+,d0
		bsr.w	MCD_SubChooseTerrainAngle
		tst.w	d1
		beq.s	.return
		bpl.s	MCD_Subloc_12C14
		cmpi.w	#-$E,d1
		blt.s	.return
		add.w	d1,obX(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12C14:
		cmpi.w	#$E,d1
		bgt.s	MCD_Subloc_12C20

MCD_Subloc_12C1A:
		add.w	d1,obX(a0)
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12C20:
		tst.b	stick_to_convex(a0)
		bne.s	MCD_Subloc_12C1A
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts
; ---------------------------------------------------------------------------

MCD_SubSonic_WalkCeiling:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d2
		eori.w	#$F,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MCD_SubFindFloor
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d2
		eori.w	#$F,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d3
		lea	(MCD_TerrainSecondary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MCD_SubFindFloor
		move.w	(sp)+,d0
		bsr.w	MCD_SubChooseTerrainAngle
		tst.w	d1
		beq.s	.return
		bpl.s	MCD_Subloc_12CB2
		cmpi.w	#-$E,d1
		blt.s	.return
		sub.w	d1,obY(a0)
.return:	rts
; ---------------------------------------------------------------------------

MCD_Subloc_12CB2:
		cmpi.w	#$E,d1
		bgt.s	MCD_Subloc_12CBE

MCD_Subloc_12CB8:
		sub.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12CBE:
		tst.b	stick_to_convex(a0)
		bne.s	MCD_Subloc_12CB8
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts
; ---------------------------------------------------------------------------

MCD_SubSonic_WalkVertL:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d3
		eori.w	#$F,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MCD_SubFindWall
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d3
		eori.w	#$F,d3
		lea	(MCD_TerrainSecondary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MCD_SubFindWall
		move.w	(sp)+,d0
		bsr.w	MCD_SubChooseTerrainAngle
		tst.w	d1
		beq.s	.return
		bpl.s	MCD_Subloc_12D50
		cmpi.w	#-$E,d1
		blt.s	.return
		sub.w	d1,obX(a0)
.return:	rts
; ---------------------------------------------------------------------------

MCD_Subloc_12D50:
		cmpi.w	#$E,d1
		bgt.s	MCD_Subloc_12D5C

MCD_Subloc_12D56:
		sub.w	d1,obX(a0)
		rts
; ---------------------------------------------------------------------------

MCD_Subloc_12D5C:
		tst.b	stick_to_convex(a0)
		bne.s	MCD_Subloc_12D56
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts

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

; Sonic_WalkSpeed:
MCD_SubCalcRoomInFront:
		move.l	(MCD_TerrainPath1_Sub).l,(MCD_TerrainPath_Sub).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	MCD_Subloc_13094
		move.l	(MCD_TerrainPath2_Sub).l,(MCD_TerrainPath_Sub).l

MCD_Subloc_13094:
		move.b	obLRBSolidBit(a0),d5
		move.w	obX(a0),d3
		move.w	obY(a0),d2
		move.b	d0,(MCD_TerrainPrimary_Sub).l
		move.b	d0,(MCD_TerrainSecondary_Sub).l
		move.b	d0,d1
		addi.b	#$20,d0
		bpl.s	MCD_Subloc_130D4
		move.b	d1,d0
		bpl.s	MCD_Subloc_130CE
		subq.b	#1,d0

MCD_Subloc_130CE:
		addi.b	#$20,d0
		bra.s	MCD_Subloc_130DE
; ---------------------------------------------------------------------------

MCD_Subloc_130D4:
		move.b	d1,d0
		bpl.s	MCD_Subloc_130DA
		addq.b	#1,d0

MCD_Subloc_130DA:
		addi.b	#$1F,d0

MCD_Subloc_130DE:
		andi.b	#$C0,d0
		beq.w	MCD_Subloc_131DE
		cmpi.b	#$80,d0
		beq.w	MCD_Subloc_133B0
		andi.b	#$38,d1
		bne.s	MCD_Subloc_130F6
		addq.w	#8,d2

MCD_Subloc_130F6:
		cmpi.b	#$40,d0
		beq.w	MCD_Subloc_13478
		addi.w	#$A,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindWall
		move.b	#$C0,d2
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts
; End of function MCD_SubCalcRoomInFront


; =============== S U B R O U T I N E =======================================


MCD_SubCheckRoomOverhead:
		move.l	(MCD_TerrainPath1_Sub).l,(MCD_TerrainPath_Sub).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	MCD_Subloc_1311A
		move.l	(MCD_TerrainPath2_Sub).l,(MCD_TerrainPath_Sub).l

MCD_Subloc_1311A:
		move.b	obLRBSolidBit(a0),d5
		move.b	d0,(MCD_TerrainPrimary_Sub).l
		move.b	d0,(MCD_TerrainSecondary_Sub).l
		addi.b	#$20,d0
		andi.b	#$C0,d0
		cmpi.b	#$40,d0
		beq.w	MCD_Subloc_13408
		cmpi.b	#$80,d0
		beq.w	MCD_SubCeilingPair
		cmpi.b	#$C0,d0
		beq.w	MCD_Subloc_1328E

MCD_SubFloorPair:
		move.l	(MCD_TerrainPath1_Sub).l,(MCD_TerrainPath_Sub).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	MCD_Subloc_1315E
		move.l	(MCD_TerrainPath2_Sub).l,(MCD_TerrainPath_Sub).l

MCD_Subloc_1315E:
		move.b	obTopSolidBit(a0),d5
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindFloor
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d3
		lea	(MCD_TerrainSecondary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindFloor
		move.w	(sp)+,d0
		clr.b	d2

MCD_Subloc_131BE:
		move.b	(MCD_TerrainSecondary_Sub).l,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts
; End of function MCD_SubCheckRoomOverhead

; ---------------------------------------------------------------------------
		; unused
	;	move.w	obY(a0),d2
	;	move.w	obX(a0),d3

MCD_Subloc_131DE:
		addi.w	#$A,d2
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindFloor
		clr.b	d2
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts

; =============== S U B R O U T I N E =======================================

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

MCD_Subloc_1328E:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindWall
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(MCD_TerrainSecondary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindWall
		move.w	(sp)+,d0
		move.b	#$C0,d2
		move.b	(MCD_TerrainSecondary_Sub).l,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts

; =============== S U B R O U T I N E =======================================


MCD_SubRightSensor:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		addi.w	#$A,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MCD_SubFindWall
		move.b	#$C0,d2
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts
; End of function MCD_SubRightSensor

; =============== S U B R O U T I N E =======================================


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


MCD_SubCeilingPair:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d2
		eori.w	#$F,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MCD_SubFindFloor
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d2
		eori.w	#$F,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d3
		lea	(MCD_TerrainSecondary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MCD_SubFindFloor
		move.w	(sp)+,d0
		move.b	#$80,d2
		move.b	(MCD_TerrainSecondary_Sub).l,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts
; End of function MCD_SubCeilingPair

; ---------------------------------------------------------------------------
		; unused
	;	move.w	obY(a0),d2
	;	move.w	obX(a0),d3

MCD_Subloc_133B0:
		subi.w	#$A,d2
		eori.w	#$F,d2
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MCD_SubFindFloor
		move.b	#$80,d2
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts
; ---------------------------------------------------------------------------

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

MCD_Subloc_13408:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d3
		eori.w	#$F,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MCD_SubFindWall
		move.w	d1,-(sp)
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d3
		eori.w	#$F,d3
		lea	(MCD_TerrainSecondary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MCD_SubFindWall
		move.w	(sp)+,d0
		move.b	#$40,d2
		move.b	(MCD_TerrainSecondary_Sub).l,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts

; =============== S U B R O U T I N E =======================================


MCD_SubLeftSensor:
		move.w	obY(a0),d2
		move.w	obX(a0),d3

MCD_Subloc_13478:
		subi.w	#$A,d3
		eori.w	#$F,d3
		lea	(MCD_TerrainPrimary_Sub).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MCD_SubFindWall
		move.b	#$40,d2
		move.b	(MCD_TerrainPrimary_Sub).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts
; End of function MCD_SubLeftSensor

; ---------------------------------------------------------------------------
; Subroutine to detect when an object hits a wall to its left
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


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
		lea	(MCD_SubMainArgument).l,a1
		move.w	(a1)+,obX(a0)
		move.w	(a1)+,obY(a0)
		move.l	(a1)+,obVelX(a0)
		move.w	(a1)+,obHeight(a0)
		move.b	(a1)+,obAngle(a0)
		move.b	(a1)+,obStatus(a0)
		move.b	(MCD_SubMainCommand).l,d0
		move.b	d0,d1
		lsr.b	#4,d0
		andi.b	#$F,d1
		move.b	d0,obTopSolidBit(a0)
		move.b	d1,obLRBSolidBit(a0)
		bsr.w	MCD_Air_Sonic_DoLevelCollision
		move.w	obY(a0),(MCD_SubOwnResult+2).l
		move.l	obVelX(a0),(MCD_SubOwnResult+4).l
		move.w	obInertia(a0),(MCD_SubOwnResult+8).l
		move.w	obHeight(a0),(MCD_SubOwnResult+$A).l
		move.b	obAngle(a0),(MCD_SubOwnResult+$C).l
		move.b	obStatus(a0),(MCD_SubOwnResult+$D).l
		move.w	obX(a0),d0
		rts

; Player landing bookkeeping changes animation, radii and ancillary state,
; but no later terrain probe uses them in this pass. Apply that callback on MD
; after the coherent contact result, preserving each character's own behavior.
MCD_SubAirLand:
		bset	#MCD_ServiceLanded,(MCD_SubOwnFlags).l
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
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
+
		bsr.w	MCD_SubRightSensor
		tst.w	d1
		bpl.s	+
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
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).l
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MCD_Air_loc_105B2:
		clr.w	obVelY(a0)
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).l
		move.w	obVelX(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

MCD_Air_loc_105C0:
		clr.w	obVelX(a0)
		cmpi.w	#$FC0,obVelY(a0)
		ble.s	MCD_Air_loc_105D4
		move.w	#$FC0,obVelY(a0)

MCD_Air_loc_105D4:
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).l
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
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).l
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
		tst.b	(MCD_SubMainFlags).l
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
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).l
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
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).l
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
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).l
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
		tst.b	(MCD_SubMainFlags).l
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
		bset	#MCD_ServiceInertia,(MCD_SubOwnFlags).l
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
