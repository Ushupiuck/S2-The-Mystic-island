; Cartridge-only collision backend. Shared SSTs, terrain and collision assets
; retain their normal format. Public distance calls retain the CD caller ABI.
mdterraincall macro routine
		movem.l	d4-d6,-(sp)
		pea	MD_TerrainReturn(pc)
		bra.w	routine
		endm
AnglePos:
		mdterraincall MD_AnglePos
CalcRoomInFront:
		mdterraincall MD_CalcRoomInFront
sub_13102:
		mdterraincall MD_CheckRoomOverhead
loc_13146:
		mdterraincall MD_FloorPair
Sonic_DontRunOnWalls:
		mdterraincall MD_CeilingPair
ChkFloorEdge:
		mdterraincall MD_ChkFloorEdge
ChkFloorEdge_Part2:
		mdterraincall MD_ChkFloorEdge_Part2
ObjHitFloor:
		mdterraincall MD_ObjHitFloor
ObjHitFloor2:
		mdterraincall MD_ObjHitFloor2
sub_132EE:
		mdterraincall MD_RightSensor
Sonic_HitWall:
		mdterraincall MD_LeftSensor
ObjHitWallRight:
		mdterraincall MD_ObjHitWallRight
ObjHitWallLeft:
		mdterraincall MD_ObjHitWallLeft
ObjHitCeiling:
		mdterraincall MD_ObjHitCeiling
FindFloor:
		mdterraincall MD_FindFloor
FindFloor2:
		mdterraincall MD_FindFloor2
FindWall:
		mdterraincall MD_FindWall
FindWall2:
		mdterraincall MD_FindWall2
MD_TerrainReturn:
		movem.l	(sp)+,d4-d6
		tst.w	d1
		rts

; Sonic/Tails push their own landing callback. A register flag replaces the
; mailbox's landed flag; no extra RAM or character-specific duplicate is needed.
Player_AirCollision:
		move.l	d7,-(sp)
		moveq	#0,d7
		bsr.w	MD_Air_Sonic_DoLevelCollision
		tst.b	d7
		movem.l	(sp)+,d7
		beq.s	.airborne
		movea.l	(sp)+,a1
		jmp	(a1)
.airborne:
		addq.w	#4,sp
		rts

MD_AnglePos:
		move.l	(v_colladdr1).l,(Collision_addr).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	MD_loc_12A14
		move.l	(v_colladdr2).l,(Collision_addr).l

MD_loc_12A14:
		move.b	obTopSolidBit(a0),d5
		btst	#3,obStatus(a0)
		beq.s	MD_loc_12A2C
		moveq	#0,d0
		move.b	d0,(Primary_Angle).l
		move.b	d0,(Secondary_Angle).l
		rts
; ---------------------------------------------------------------------------

MD_loc_12A2C:
		moveq	#3,d0
		move.b	d0,(Primary_Angle).l
		move.b	d0,(Secondary_Angle).l
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		bpl.s	MD_loc_12A4E
		move.b	obAngle(a0),d0
		bpl.s	MD_loc_12A48
		subq.b	#1,d0

MD_loc_12A48:
		addi.b	#$20,d0
		bra.s	MD_loc_12A5A
; ---------------------------------------------------------------------------

MD_loc_12A4E:
		move.b	obAngle(a0),d0
		bpl.s	MD_loc_12A56
		addq.b	#1,d0

MD_loc_12A56:
		addi.b	#$1F,d0

MD_loc_12A5A:
		andi.b	#$C0,d0
		cmpi.b	#$40,d0
		beq.w	MD_Sonic_WalkVertL
		cmpi.b	#$80,d0
		beq.w	MD_Sonic_WalkCeiling
		cmpi.b	#$C0,d0
		beq.w	MD_Sonic_WalkVertR
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.b	obWidth(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(Primary_Angle).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MD_FindFloor
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
		lea	(Secondary_Angle).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MD_FindFloor
		move.w	(sp)+,d0
		bsr.w	MD_ChooseTerrainAngle
		tst.w	d1
		beq.s	.return
		bpl.s	MD_loc_12AE6
		cmpi.w	#-$E,d1
		blt.s	.return
		add.w	d1,obY(a0)
.return:	rts
; ---------------------------------------------------------------------------

MD_loc_12AE6:
		cmpi.w	#$E,d1
		bgt.s	MD_loc_12AF2

MD_loc_12AEC:
		add.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------

MD_loc_12AF2:
		tst.b	stick_to_convex(a0)
		bne.s	MD_loc_12AEC
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts
; End of function MD_AnglePos

; =============== S U B R O U T I N E =======================================

; MD_ChooseTerrainAngle:
MD_ChooseTerrainAngle:
		move.b	(Secondary_Angle).l,d2
		cmp.w	d0,d1
		ble.s	+
		move.b	(Primary_Angle).l,d2
		move.w	d0,d1
+
		btst	#0,d2
		bne.s	MD_loc_12B90
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
		bhs.s	MD_loc_12B90
.set_angle:
		move.b	d2,obAngle(a0)
		rts
; ---------------------------------------------------------------------------

MD_loc_12B90:
		move.b	obAngle(a0),d2
		addi.b	#$20,d2
		andi.b	#$C0,d2
		move.b	d2,obAngle(a0)
		rts
; End of function MD_ChooseTerrainAngle

; ---------------------------------------------------------------------------

MD_Sonic_WalkVertR:
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
		lea	(Primary_Angle).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MD_FindWall
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
		lea	(Secondary_Angle).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MD_FindWall
		move.w	(sp)+,d0
		bsr.w	MD_ChooseTerrainAngle
		tst.w	d1
		beq.s	.return
		bpl.s	MD_loc_12C14
		cmpi.w	#-$E,d1
		blt.s	.return
		add.w	d1,obX(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MD_loc_12C14:
		cmpi.w	#$E,d1
		bgt.s	MD_loc_12C20

MD_loc_12C1A:
		add.w	d1,obX(a0)
		rts
; ---------------------------------------------------------------------------

MD_loc_12C20:
		tst.b	stick_to_convex(a0)
		bne.s	MD_loc_12C1A
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts
; ---------------------------------------------------------------------------

MD_Sonic_WalkCeiling:
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
		lea	(Primary_Angle).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MD_FindFloor
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
		lea	(Secondary_Angle).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MD_FindFloor
		move.w	(sp)+,d0
		bsr.w	MD_ChooseTerrainAngle
		tst.w	d1
		beq.s	.return
		bpl.s	MD_loc_12CB2
		cmpi.w	#-$E,d1
		blt.s	.return
		sub.w	d1,obY(a0)
.return:	rts
; ---------------------------------------------------------------------------

MD_loc_12CB2:
		cmpi.w	#$E,d1
		bgt.s	MD_loc_12CBE

MD_loc_12CB8:
		sub.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------

MD_loc_12CBE:
		tst.b	stick_to_convex(a0)
		bne.s	MD_loc_12CB8
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts
; ---------------------------------------------------------------------------

MD_Sonic_WalkVertL:
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
		lea	(Primary_Angle).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MD_FindWall
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
		lea	(Secondary_Angle).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MD_FindWall
		move.w	(sp)+,d0
		bsr.w	MD_ChooseTerrainAngle
		tst.w	d1
		beq.s	.return
		bpl.s	MD_loc_12D50
		cmpi.w	#-$E,d1
		blt.s	.return
		sub.w	d1,obX(a0)
.return:	rts
; ---------------------------------------------------------------------------

MD_loc_12D50:
		cmpi.w	#$E,d1
		bgt.s	MD_loc_12D5C

MD_loc_12D56:
		sub.w	d1,obX(a0)
		rts
; ---------------------------------------------------------------------------

MD_loc_12D5C:
		tst.b	stick_to_convex(a0)
		bne.s	MD_loc_12D56
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		move.b	#1,obPrevAni(a0)
		rts

; =============== S U B R O U T I N E =======================================


MD_FindTerrainBlock:
		move.w	d2,d0		; y_pos
		add.w	d0,d0
		andi.w	#$F00,d0	; rounded 2*y_pos
		move.w	d3,d1		; x_pos
		lsr.w	#3,d1
		move.w	d1,d4
		lsr.w	#4,d1		; x_pos/128 = x_of_chunk
		andi.w	#$7F,d1
		add.w	d1,d0		; d0 is relevant chunk ID now
		moveq	#-1,d1
		clr.w	d1		; clear the chunk index before reading its byte
		lea	(v_lvllayout).l,a1
		move.b	(a1,d0.w),d1	; move 128*128 chunk ID to d1
		add.w	d1,d1
		move.w	.table(pc,d1.w),d1
		move.w	d2,d0		; y_pos
		andi.w	#$70,d0
		add.w	d0,d1
		andi.w	#$E,d4		; x_pos/8
		add.w	d4,d1
		lea	(Chunk_Table).l,a1
		adda.w	d1,a1		; offset within the cartridge chunk table
		rts
; End of function MD_FindTerrainBlock
; ===========================================================================
; precalculated values for Find_Tile
; (Sonic 1 calculated it every time instead of using a table)
.table:
c := 0
	rept 256
		dc.w	c
c := c+$80
	endm
; ===========================================================================

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

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

MD_FindFloor:
		bsr.w	MD_FindTerrainBlock
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	MD_loc_12DBE
		btst	d5,d4
		bne.s	MD_loc_12DCC

MD_loc_12DBE:
		add.w	a3,d2
		bsr.w	MD_FindFloor2
		sub.w	a3,d2
		addi.w	#$10,d1
		rts
; ---------------------------------------------------------------------------

MD_loc_12DCC:
		movea.l	(Collision_addr).l,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	MD_loc_12DBE
		lea	(AngleMap).l,a2
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
		lea	(ColArray1).l,a2
		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$B,d4
		beq.s	+
		neg.w	d0
+
		tst.w	d0
		beq.w	MD_loc_12DBE
		bmi.s	MD_loc_12E38
		cmpi.b	#$10,d0
		beq.s	MD_loc_12E44
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MD_loc_12E38:
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	MD_loc_12DBE

MD_loc_12E44:
		sub.w	a3,d2
		bsr.w	MD_FindFloor2
		add.w	a3,d2
		subi.w	#$10,d1
		rts
; End of function MD_FindFloor


; =============== S U B R O U T I N E =======================================


MD_FindFloor2:
		bsr.w	MD_FindTerrainBlock
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	MD_loc_12E64
		btst	d5,d4
		bne.s	MD_loc_12E72

MD_loc_12E64:
		move.w	#$F,d1
		move.w	d2,d0
		andi.w	#$F,d0
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MD_loc_12E72:
		movea.l	(Collision_addr).l,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	MD_loc_12E64
		lea	(AngleMap).l,a2
		move.b	(a2,d0.w),(a4)
		lsl.w	#4,d0
		move.w	d3,d1
		btst	#$A,d4
		beq.s	MD_loc_12E96
		not.w	d1
		neg.b	(a4)

MD_loc_12E96:
		btst	#$B,d4
		beq.s	MD_loc_12EA6
		addi.b	#$40,(a4)
		neg.b	(a4)
		subi.b	#$40,(a4)

MD_loc_12EA6:
		andi.w	#$F,d1
		add.w	d0,d1
		lea	(ColArray1).l,a2
		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$B,d4
		beq.s	MD_loc_12EC2
		neg.w	d0

MD_loc_12EC2:
		tst.w	d0
		beq.w	MD_loc_12E64
		bmi.s	MD_loc_12ED8
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MD_loc_12ED8:
		move.w	d2,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	MD_loc_12E64
		not.w	d1
		rts
; End of function MD_FindFloor2


; =============== S U B R O U T I N E =======================================


MD_FindWall:
		bsr.w	MD_FindTerrainBlock
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	MD_loc_12EFA
		btst	d5,d4
		bne.s	MD_loc_12F08

MD_loc_12EFA:
		add.w	a3,d3
		bsr.w	MD_FindWall2
		sub.w	a3,d3
		addi.w	#$10,d1
		rts
; ---------------------------------------------------------------------------

MD_loc_12F08:
		movea.l	(Collision_addr).l,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	MD_loc_12EFA
		lea	(AngleMap).l,a2
		move.b	(a2,d0.w),(a4)
		lsl.w	#4,d0
		move.w	d2,d1
		btst	#$B,d4
		beq.s	MD_loc_12F34
		not.w	d1
		addi.b	#$40,(a4)
		neg.b	(a4)
		subi.b	#$40,(a4)

MD_loc_12F34:
		btst	#$A,d4
		beq.s	MD_loc_12F3C
		neg.b	(a4)

MD_loc_12F3C:
		andi.w	#$F,d1
		add.w	d0,d1
		lea	(ColArray2).l,a2
		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$A,d4
		beq.s	MD_loc_12F58
		neg.w	d0

MD_loc_12F58:
		tst.w	d0
		beq.w	MD_loc_12EFA
		bmi.s	MD_loc_12F74
		cmpi.b	#$10,d0
		beq.s	MD_loc_12F80
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MD_loc_12F74:
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	MD_loc_12EFA

MD_loc_12F80:
		sub.w	a3,d3
		bsr.w	MD_FindWall2
		add.w	a3,d3
		subi.w	#$10,d1
		rts
; End of function MD_FindWall


; =============== S U B R O U T I N E =======================================


MD_FindWall2:
		bsr.w	MD_FindTerrainBlock
		move.w	(a1),d0
		move.w	d0,d4
		andi.w	#$3FF,d0
		beq.s	MD_loc_12FA0
		btst	d5,d4
		bne.s	MD_loc_12FAE

MD_loc_12FA0:
		move.w	#$F,d1
		move.w	d3,d0
		andi.w	#$F,d0
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MD_loc_12FAE:
		movea.l	(Collision_addr).l,a2
		add.w	d0,d0
		move.b	(a2,d0.w),d0
		andi.w	#$FF,d0
		beq.s	MD_loc_12FA0
		lea	(AngleMap).l,a2
		move.b	(a2,d0.w),(a4)
		lsl.w	#4,d0
		move.w	d2,d1
		btst	#$B,d4
		beq.s	MD_loc_12FDA
		not.w	d1
		addi.b	#$40,(a4)
		neg.b	(a4)
		subi.b	#$40,(a4)

MD_loc_12FDA:
		btst	#$A,d4
		beq.s	MD_loc_12FE2
		neg.b	(a4)

MD_loc_12FE2:
		andi.w	#$F,d1
		add.w	d0,d1
		lea	(ColArray2).l,a2
		move.b	(a2,d1.w),d0
		ext.w	d0
		eor.w	d6,d4
		btst	#$A,d4
		beq.s	MD_loc_12FFE
		neg.w	d0

MD_loc_12FFE:
		tst.w	d0
		beq.w	MD_loc_12FA0
		bmi.s	MD_loc_13014
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		move.w	#$F,d1
		sub.w	d0,d1
		rts
; ---------------------------------------------------------------------------

MD_loc_13014:
		move.w	d3,d1
		andi.w	#$F,d1
		add.w	d1,d0
		bpl.w	MD_loc_12FA0
		not.w	d1
		rts
; End of function MD_FindWall2

; =============== S U B R O U T I N E =======================================

; Sonic_WalkSpeed:
MD_CalcRoomInFront:
		move.l	(v_colladdr1).l,(Collision_addr).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	MD_loc_13094
		move.l	(v_colladdr2).l,(Collision_addr).l

MD_loc_13094:
		move.b	obLRBSolidBit(a0),d5
		; Mode 1 projects these coordinates in its MD caller before the packet.
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
		move.b	d0,(Primary_Angle).l
		move.b	d0,(Secondary_Angle).l
		move.b	d0,d1
		addi.b	#$20,d0
		bpl.s	MD_loc_130D4
		move.b	d1,d0
		bpl.s	MD_loc_130CE
		subq.b	#1,d0

MD_loc_130CE:
		addi.b	#$20,d0
		bra.s	MD_loc_130DE
; ---------------------------------------------------------------------------

MD_loc_130D4:
		move.b	d1,d0
		bpl.s	MD_loc_130DA
		addq.b	#1,d0

MD_loc_130DA:
		addi.b	#$1F,d0

MD_loc_130DE:
		andi.b	#$C0,d0
		beq.w	MD_loc_131DE
		cmpi.b	#$80,d0
		beq.w	MD_loc_133B0
		andi.b	#$38,d1
		bne.s	MD_loc_130F6
		addq.w	#8,d2

MD_loc_130F6:
		cmpi.b	#$40,d0
		beq.w	MD_loc_13478
		addi.w	#$A,d3
		lea	(Primary_Angle).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MD_FindWall
		move.b	#$C0,d2
		move.b	(Primary_Angle).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts
; End of function MD_CalcRoomInFront


; =============== S U B R O U T I N E =======================================


MD_CheckRoomOverhead:
		move.l	(v_colladdr1).l,(Collision_addr).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	MD_loc_1311A
		move.l	(v_colladdr2).l,(Collision_addr).l

MD_loc_1311A:
		move.b	obLRBSolidBit(a0),d5
		move.b	d0,(Primary_Angle).l
		move.b	d0,(Secondary_Angle).l
		addi.b	#$20,d0
		andi.b	#$C0,d0
		cmpi.b	#$40,d0
		beq.w	MD_loc_13408
		cmpi.b	#$80,d0
		beq.w	MD_CeilingPair
		cmpi.b	#$C0,d0
		beq.w	MD_loc_1328E

MD_FloorPair:
		move.l	(v_colladdr1).l,(Collision_addr).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	MD_loc_1315E
		move.l	(v_colladdr2).l,(Collision_addr).l

MD_loc_1315E:
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
		lea	(Primary_Angle).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MD_FindFloor
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
		lea	(Secondary_Angle).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MD_FindFloor
		move.w	(sp)+,d0
		clr.b	d2

MD_loc_131BE:
		move.b	(Secondary_Angle).l,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(Primary_Angle).l,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts
; End of function MD_CheckRoomOverhead

; ---------------------------------------------------------------------------
		; unused
	;	move.w	obY(a0),d2
	;	move.w	obX(a0),d3

MD_loc_131DE:
		addi.w	#$A,d2
		lea	(Primary_Angle).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MD_FindFloor
		clr.b	d2
		move.b	(Primary_Angle).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts

; =============== S U B R O U T I N E =======================================

; Sonic_HitFloor:
MD_ChkFloorEdge:
		move.w	obX(a0),d3
MD_ChkFloorEdge_Part2:			; S3&K edge balancing also probes an offset X in d3
		move.w	obY(a0),d2
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		move.l	(v_colladdr1).l,(Collision_addr).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	MD_loc_1322E
		move.l	(v_colladdr2).l,(Collision_addr).l

MD_loc_1322E:
		lea	(Primary_Angle).l,a4
		clr.b	(a4)
		movea.w	#$10,a3
		clr.w	d6
		move.b	obTopSolidBit(a0),d5
		bsr.w	MD_FindFloor
		move.b	(Primary_Angle).l,d3
		btst	#0,d3
		beq.s	.return
		clr.b	d3
.return:	rts
; End of function MD_ChkFloorEdge


; =============== S U B R O U T I N E =======================================

;  ObjGetFloorDist, ObjFloorDist:
MD_ObjHitFloor:
		move.w	obX(a0),d3


MD_ObjHitFloor2:
		move.w	obY(a0),d2
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d2
		lea	(Primary_Angle).l,a4
		clr.b	(a4)
		movea.w	#$10,a3
		clr.w	d6
		moveq	#$C,d5
		bsr.w	MD_FindFloor
		move.b	(Primary_Angle).l,d3
		btst	#0,d3
		beq.s	.return
		clr.b	d3
.return:	rts
; End of function MD_ObjHitFloor

; ---------------------------------------------------------------------------

MD_loc_1328E:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obWidth(a0),d0
		ext.w	d0
		sub.w	d0,d2
		move.b	obHeight(a0),d0
		ext.w	d0
		add.w	d0,d3
		lea	(Primary_Angle).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MD_FindWall
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
		lea	(Secondary_Angle).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MD_FindWall
		move.w	(sp)+,d0
		move.b	#$C0,d2
		move.b	(Secondary_Angle).l,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(Primary_Angle).l,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts

; =============== S U B R O U T I N E =======================================


MD_RightSensor:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		addi.w	#$A,d3
		lea	(Primary_Angle).l,a4
		movea.w	#$10,a3
		clr.w	d6
		bsr.w	MD_FindWall
		move.b	#$C0,d2
		move.b	(Primary_Angle).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts
; End of function MD_RightSensor

; =============== S U B R O U T I N E =======================================


MD_ObjHitWallRight:
		add.w	obX(a0),d3	; d3 supplies the caller's horizontal offset
		move.w	obY(a0),d2
		lea	(Primary_Angle).l,a4
		clr.b	(a4)
		movea.w	#$10,a3
		clr.w	d6
		moveq	#$D,d5
		bsr.w	MD_FindWall
		move.b	(Primary_Angle).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	#$C0,d3
.return:	rts
; End of function MD_ObjHitWallRight


; =============== S U B R O U T I N E =======================================


MD_CeilingPair:
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
		lea	(Primary_Angle).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MD_FindFloor
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
		lea	(Secondary_Angle).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MD_FindFloor
		move.w	(sp)+,d0
		move.b	#$80,d2
		move.b	(Secondary_Angle).l,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(Primary_Angle).l,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts
; End of function MD_CeilingPair

; ---------------------------------------------------------------------------
		; unused
	;	move.w	obY(a0),d2
	;	move.w	obX(a0),d3

MD_loc_133B0:
		subi.w	#$A,d2
		eori.w	#$F,d2
		lea	(Primary_Angle).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		bsr.w	MD_FindFloor
		move.b	#$80,d2
		move.b	(Primary_Angle).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3

.return:
		rts
; ---------------------------------------------------------------------------

MD_ObjHitCeiling:
		move.w	obY(a0),d2
		move.w	obX(a0),d3
		moveq	#0,d0
		move.b	obHeight(a0),d0
		ext.w	d0
		sub.w	d0,d2
		eori.w	#$F,d2
		lea	(Primary_Angle).l,a4
		movea.w	#-$10,a3
		move.w	#$800,d6
		moveq	#$D,d5
		bsr.w	MD_FindFloor
		move.b	(Primary_Angle).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	#$80,d3
.return:	rts
; ---------------------------------------------------------------------------

MD_loc_13408:
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
		lea	(Primary_Angle).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MD_FindWall
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
		lea	(Secondary_Angle).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MD_FindWall
		move.w	(sp)+,d0
		move.b	#$40,d2
		move.b	(Secondary_Angle).l,d3
		cmp.w	d0,d1
		ble.s	.skip
		move.b	(Primary_Angle).l,d3
		exg	d0,d1

.skip:
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts

; =============== S U B R O U T I N E =======================================


MD_LeftSensor:
		move.w	obY(a0),d2
		move.w	obX(a0),d3

MD_loc_13478:
		subi.w	#$A,d3
		eori.w	#$F,d3
		lea	(Primary_Angle).l,a4
		movea.w	#-$10,a3
		move.w	#$400,d6
		bsr.w	MD_FindWall
		move.b	#$40,d2
		move.b	(Primary_Angle).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	d2,d3
.return:	rts
; End of function MD_LeftSensor

; ---------------------------------------------------------------------------
; Subroutine to detect when an object hits a wall to its left
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


MD_ObjHitWallLeft:
		add.w	obX(a0),d3	; d3 supplies the caller's horizontal offset
		move.w	obY(a0),d2
		eori.w	#$F,d3
		lea	(Primary_Angle).l,a4
		clr.b	(a4)
		movea.w	#-$10,a3
		move.w	#$400,d6
		moveq	#$D,d5
		bsr.w	MD_FindWall
		move.b	(Primary_Angle).l,d3
		btst	#0,d3
		beq.s	.return
		move.b	#$40,d3
.return:	rts
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Whole airborne contact pass: both walls, ceiling and paired floor sensors.
; Direct SST updates and f_wtunnelmode replace the Mode 1 packet and reply.
MD_AirLand:
		moveq	#1,d7
		rts

MD_Air_Sonic_DoLevelCollision:
		move.l	(v_colladdr1).l,(Collision_addr).l
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	+
		move.l	(v_colladdr2).l,(Collision_addr).l
+
		move.b	obLRBSolidBit(a0),d5
		move.w	obVelX(a0),d0				; get X speed
		move.w	obVelY(a0),d1				; get Y speed
		bpl.s	MD_Air_SonAirCol_PosY				; if it's positive, branch
		cmp.w	d0,d1					; are we moving towards the left?
		bgt.w	MD_Air_Sonic_FloorLeft				; if so, branch
		neg.w	d0					; negate for right cheeck
		cmp.w	d0,d1					; are we moving towards the right?
		bge.w	MD_Air_Sonic_FloorRight			; if so, branch
		bra.w	MD_Air_Sonic_FloorUp				; we are moving upwards
; ===========================================================================

MD_Air_SonAirCol_PosY:
		cmp.w	d0,d1					; are we moving towards the right?
		blt.w	MD_Air_Sonic_FloorRight			; if so, branch
		neg.w	d0					; negate for left check
		cmp.w	d0,d1					; are we moving towards the left?
		ble.w	MD_Air_Sonic_FloorLeft				; if so, branch
		bsr.w	MD_LeftSensor
		tst.w	d1
		bpl.s	+
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
+
		bsr.w	MD_RightSensor
		tst.w	d1
		bpl.s	+
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
+
		bsr.w	MD_FloorPair
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
		bsr.w	MD_AirLand
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	MD_Air_loc_105C0
		move.b	d3,d0
		addi.b	#$10,d0
		andi.b	#$20,d0
		beq.s	MD_Air_loc_105B2
		asr	obVelY(a0)
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MD_Air_loc_105B2:
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

MD_Air_loc_105C0:
		clr.w	obVelX(a0)
		cmpi.w	#$FC0,obVelY(a0)
		ble.s	MD_Air_loc_105D4
		move.w	#$FC0,obVelY(a0)

MD_Air_loc_105D4:
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MD_Air_Sonic_FloorLeft:
		bsr.w	MD_LeftSensor
		tst.w	d1
		bpl.s	MD_Air_loc_105FE
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

MD_Air_loc_105FE:
		bsr.w	MD_CeilingPair
		tst.w	d1
		bpl.s	MD_Air_loc_10618
		neg.w	d1
		cmpi.w	#Sonic_CeilingPenetrationLimit,d1
		bhs.s	MD_Air_Sonic_FloorLeft_OppositeWall
		add.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MD_Air_Sonic_FloorLeft_OppositeWall:
		bsr.w	MD_RightSensor
		tst.w	d1
		bpl.s	.return
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
.return:
		rts

MD_Air_loc_10618:
		tst.b	(f_wtunnelmode).l
		bne.s	.checkfloor
		tst.w	obVelY(a0)
		bmi.s	.return
.checkfloor:
		bsr.w	MD_FloorPair
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	MD_AirLand
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MD_Air_Sonic_FloorUp:
		bsr.w	MD_LeftSensor
		tst.w	d1
		bpl.s	MD_Air_loc_10658
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)

MD_Air_loc_10658:
		bsr.w	MD_RightSensor
		tst.w	d1
		bpl.s	MD_Air_loc_1066A
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)

MD_Air_loc_1066A:
		bsr.w	MD_CeilingPair
		tst.w	d1
		bpl.s	.return
		sub.w	d1,obY(a0)
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	MD_Air_loc_1068A
		clr.w	obVelY(a0)
.return:	rts
; ---------------------------------------------------------------------------

MD_Air_loc_1068A:
		move.b	d3,obAngle(a0)
		bsr.w	MD_AirLand
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MD_Air_Sonic_FloorRight:
		bsr.w	MD_RightSensor
		tst.w	d1
		bpl.s	MD_Air_loc_106BC
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

MD_Air_loc_106BC:
		bsr.w	MD_CeilingPair
		tst.w	d1
		bpl.s	MD_Air_loc_106D6
		sub.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

MD_Air_loc_106D6:
		tst.b	(f_wtunnelmode).l
		bne.s	.checkfloor
		tst.w	obVelY(a0)
		bmi.s	.return
.checkfloor:
		bsr.w	MD_FloorPair
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	MD_AirLand
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
