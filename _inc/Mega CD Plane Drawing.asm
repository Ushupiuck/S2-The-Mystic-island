; Mega-CD sub-68000 plane constructor. Called outside VBlank by the terrain job.
; Independent per-act providers select source coordinates. Rounded-position caches
; detect exposed rows/columns; VBlank only consumes the completed VDP records.
; Row/column offsets and chunk addresses are precalculated; no in-game validation.

Plane_Invalidate:
		lea	(MCD_PlaneFGCache_Sub).l,a0
		moveq	#32-1,d0
.loop:
		move.l	#$80008000,(a0)+
		dbf	d0,.loop
		rts

Plane_DrawFrame:
		tst.b	(MCD_TerrainRedraw_Sub).l
		beq.s	.foreground
		bsr.s	Plane_Invalidate
.foreground:
		lea	(MCD_PlaneFGCache_Sub).l,a1
		lea	(MCD_TerrainLayout_Sub+PlaneLayout_FG).l,a4
		movea.l	(MCD_TerrainFGDraw_Sub).l,a2
		move.w	(MCD_TerrainCamera_Sub+4).l,d4
		move.w	#$4000,d2
		bsr.s	Plane_Draw
		lea	(MCD_PlaneBGCache_Sub).l,a1
		lea	(MCD_TerrainLayout_Sub+PlaneLayout_BG).l,a4
		movea.l	(MCD_TerrainBGDraw_Sub).l,a2
		move.w	(MCD_TerrainVScroll_Sub).l,d4
		move.w	#$6000,d2

; a1 = 16 (source Y, source X) cache records, a2 = source provider,
; a4 = plane lookup base, a6 = outgoing record cursor, d4 = source camera Y.
; Providers return d5 = source X and d7 = 0 scrolling, 1 fixed 512-pixel row,
; or 2 scrolling upper/fixed lower 8-pixel halves (GHZ's hill/water boundary).
Plane_Draw:
		subi.w	#16,d4
		andi.w	#$FFF0,d4
		moveq	#16-1,d6
.row:
		move.w	d4,d0
		andi.w	#$F0,d0
		lsr.w	#2,d0
		lea	(a1,d0.w),a0
		move.l	a0,-(sp)
		jsr	(a2)	; d5 = source X, d7 = fixed 512-pixel band flag
		movea.l	(sp)+,a0
		andi.w	#$FFF0,d5
		move.w	2(a0),d1
		move.w	d5,2(a0)
		cmp.w	(a0),d4
		bne.s	.full
		sub.w	d5,d1	; previous X - current X
		beq.w	.next
		cmpi.w	#2,d7
		beq.w	.split
		move.w	d1,d0
		bpl.s	.left
		neg.w	d0
		add.w	d1,d5
		addi.w	#$150,d5	; first new right-hand column
		bra.s	.columns
.left:
		subi.w	#16,d5
.columns:
		cmpi.w	#32,d0
		bhi.s	.teleport
		movem.l	d0-d7/a0-a5,-(sp)
		lsr.w	#4,d0
		subq.w	#1,d0
		move.w	d0,d6
.column:
		movem.l	d0-d7/a0-a5,-(sp)
		lea	Plane_ZeroCamera(pc),a3
		bsr.w	Plane_GetBlockData
		movem.w	d4-d5,-(sp)
		bsr.w	Plane_Calc_VRAM_Pos
		movem.w	(sp)+,d4-d5
		move.l	#$800000,d7
		bsr.w	Plane_WriteBlock
		movem.l	(sp)+,d0-d7/a0-a5
		addi.w	#16,d5
		dbf	d6,.column
		movem.l	(sp)+,d0-d7/a0-a5
		bra.s	.next
.teleport:
		move.w	2(a0),d5
.full:
		cmpi.w	#2,d7
		beq.s	.split
		move.w	d4,(a0)
		movem.l	d0-d7/a0-a5,-(sp)
		tst.w	d7
		bne.s	.fixed
		subi.w	#16,d5	; seed the left margin used by later exposed columns
.fixed:
		lea	Plane_ZeroCamera(pc),a3
		movem.w	d4-d5,-(sp)
		bsr.w	Plane_Calc_VRAM_Pos
		movem.w	(sp)+,d4-d5
		moveq	#32-1,d6
		bsr.w	Plane_DrawRow
		movem.l	(sp)+,d0-d7/a0-a5
		bra.s	.next
.split:
		; GHZ's final hill row: scrolling upper 8 pixels, fixed water below.
		move.w	d4,(a0)
		movem.l	d0-d7/a0-a5,-(sp)
		lea	Plane_ZeroCamera(pc),a3
		subi.w	#16,d5
		movem.w	d4-d5,-(sp)
		bsr.w	Plane_Calc_VRAM_Pos
		movem.w	(sp)+,d4-d5
		moveq	#32-1,d6
		bsr.w	Plane_DrawRow	; d7=2 retains only the upper tile row
		moveq	#3,d7
		moveq	#0,d5
		movem.w	d4-d5,-(sp)
		bsr.w	Plane_Calc_VRAM_Pos
		movem.w	(sp)+,d4-d5
		moveq	#32-1,d6
		bsr.w	Plane_DrawRow	; d7=3 retains only the lower tile row
		movem.l	(sp)+,d0-d7/a0-a5
.next:
		addi.w	#16,d4
		dbf	d6,.row
		rts

Plane_SourceForeground:
		moveq	#0,d7
		move.w	(MCD_TerrainCamera_Sub).l,d5
		rts
Plane_SourceFixed:
		moveq	#1,d7
		moveq	#0,d5
		rts
Plane_SourcePlain:
		moveq	#0,d7
		move.w	(MCD_TerrainBG_Sub).l,d5
		rts
Plane_SourceGHZ:
		move.w	d4,d0
		andi.w	#$F0,d0
		lsr.w	#4,d0
		lea	.rows(pc),a0
		bsr.w	Plane_SourceBand
		cmpi.w	#9,d0
		bne.s	.return
		moveq	#2,d7
.return:
		rts
.rows:		dc.b 0,0,0,0,12,12,12,8,8,8,0,0,0,0,0,0
Plane_SourceSMZ:
		move.w	d4,d0
		andi.w	#$1F0,d0
		lsr.w	#4,d0
		lea	.rows(pc),a0
		bra.w	Plane_SourceBand
.rows:		dc.b 0,0,0,0,12,12,12,12,12,12,12,12,12,12,8,8
		dc.b 8,8,8,8,8,4,4,4,4,4,4,4,4,4,4,4
Plane_SourceBand:
		moveq	#0,d7
		moveq	#0,d5
		move.b	(a0,d0.w),d5
		bne.s	.scrolling
		moveq	#1,d7	; cloud/water bands cover fixed source X 0..511
.scrolling:
		lea	.cameras(pc),a0
		movea.l	(a0,d5.w),a0
		move.w	(a0),d5
		rts
.cameras:	dc.l Plane_ZeroCamera,MCD_TerrainBG_Sub,MCD_TerrainBG2_Sub,MCD_TerrainBG3_Sub
Plane_ZeroCamera:	dc.l 0,0

; d4/d5 = absolute world pixels, a4 = selected plane's relative lookup table.
; Returns a0 = chunk block address. d0/d3 scratch; all coordinates preserved.
Plane_FindChunkBlock:
		move.w	d4,d3
		lsr.w	#6,d3
		andi.w	#$3E,d3
		move.w	(a4,d3.w),d3
		move.w	d5,d0
		lsr.w	#6,d0
		andi.w	#$1FE,d0
		add.w	PlaneLayout_ColumnTable(a4,d0.w),d3
		move.w	(a4,d3.w),d3
		lsl.w	#2,d3
		lea	Plane_ChunkAddresses(pc),a0
		movea.l	(a0,d3.w),a0
		move.w	d4,d3
		andi.w	#$70,d3
		adda.w	d3,a0
		move.w	d5,d3
		lsr.w	#3,d3
		andi.w	#$E,d3
		adda.w	d3,a0
		rts
Plane_ChunkAddresses:
chunkAddress := MCD_ChunkTable_SubStart
		rept PlaneLayout_ChunkCount
		dc.l chunkAddress
chunkAddress := chunkAddress+$80
		endm

Plane_DrawRow:
		add.w	(a3),d5
		add.w	4(a3),d4
		move.l	a2,-(sp)
		move.l	a6,-(sp)	; lower-only rows discard their temporary upper records
		move.w	d6,-(sp)
		lea	(MCD_TerrainCache_Sub).l,a2
		move.l	d0,d1
		or.w	d2,d1
		swap	d1
		move.l	d1,-(sp)
		move.l	d1,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		swap	d1
		movem.l	d4-d5,-(sp)
		bsr.w	Plane_FindChunkBlock
		movem.l	(sp)+,d4-d5

Plane_RowBlock:
		move.w	(a0),d3
		andi.w	#$3FF,d3
		lsl.w	#3,d3
		lea	(MCD_TerrainBlocks_Sub).l,a1
		adda.w	d3,a1
		btst	#3,(a0)
		bne.w	Plane_RowFlipY
		btst	#2,(a0)
		bne.w	Plane_RowFlipX
		move.l	(a1)+,(a6)+
		addq.w	#1,(a5)
		move.l	(a1)+,(a2)+
.continue:	addq.w	#2,a0
		addq.b	#4,d1
		bpl.s	Plane_RowAdvance
		andi.b	#$7F,d1
		swap	d1
		move.l	d1,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		swap	d1

Plane_RowAdvance:
		addi.w	#$10,d5
		move.w	d5,d0
		andi.w	#$70,d0
		bne.s	Plane_RowNext
		movem.l	d4-d5,-(sp)
		bsr.w	Plane_FindChunkBlock
		movem.l	(sp)+,d4-d5

Plane_RowNext:
		dbf	d6,Plane_RowBlock
		cmpi.w	#2,d7
		beq.s	Plane_RowUpperOnly
		move.l	(sp)+,d1
		addi.l	#$800000,d1
		lea	(MCD_TerrainCache_Sub).l,a2
		move.l	d1,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		swap	d1
		move.w	(sp)+,d6
		; The lower row header was emitted above; discard/recreate it when
		; keeping only the lower half of a split band.
		cmpi.w	#3,d7
		bne.s	Plane_RowBottom
		movea.l	(sp),a6
		swap	d1
		move.l	d1,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		swap	d1

Plane_RowBottom:
		move.l	(a2)+,(a6)+
		addq.w	#1,(a5)
		addq.b	#4,d1
		bmi.s	Plane_RowBottomNext
		ori.b	#$80,d1
		swap	d1
		move.l	d1,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		swap	d1

Plane_RowBottomNext:
		dbf	d6,Plane_RowBottom
		addq.w	#4,sp
		movea.l	(sp)+,a2
		rts
Plane_RowUpperOnly:
		addq.w	#6,sp	; saved VDP command and row count
		addq.w	#4,sp	; temporary upper-record start
		movea.l	(sp)+,a2
		rts


; ---------------------------------------------------------------------------

Plane_RowFlipX:
		move.l	(a1)+,d3
		eori.l	#$8000800,d3
		swap	d3
		move.l	d3,(a6)+
		addq.w	#1,(a5)
		move.l	(a1)+,d3
		eori.l	#$8000800,d3
		swap	d3
		move.l	d3,(a2)+
		bra.w	Plane_RowBlock.continue
; ---------------------------------------------------------------------------

Plane_RowFlipY:
		btst	#2,(a0)
		bne.s	Plane_RowFlipXY
		move.l	(a1)+,d0
		move.l	(a1)+,d3
		eori.l	#$10001000,d3
		move.l	d3,(a6)+
		addq.w	#1,(a5)
		eori.l	#$10001000,d0
		move.l	d0,(a2)+
		bra.w	Plane_RowBlock.continue
; ---------------------------------------------------------------------------

Plane_RowFlipXY:
		move.l	(a1)+,d0
		move.l	(a1)+,d3
		eori.l	#$18001800,d3
		swap	d3
		move.l	d3,(a6)+
		addq.w	#1,(a5)
		eori.l	#$18001800,d0
		swap	d0
		move.l	d0,(a2)+
		bra.w	Plane_RowBlock.continue


; =============== S U B R O U T I N E =======================================


Plane_WriteBlock:
		or.w	d2,d0
		swap	d0
		btst	#3,(a0)
		bne.s	Plane_BlockFlipY
		btst	#2,(a0)
		bne.s	Plane_BlockFlipX
		move.l	d0,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		move.l	(a1)+,(a6)+
		addq.w	#1,(a5)
		add.l	d7,d0
		move.l	d0,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		move.l	(a1)+,(a6)+
		addq.w	#1,(a5)
		rts
; ---------------------------------------------------------------------------

Plane_BlockFlipX:
		move.l	d0,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		move.l	(a1)+,d3
		eori.l	#$8000800,d3
		swap	d3
		move.l	d3,(a6)+
		addq.w	#1,(a5)
		add.l	d7,d0
		move.l	d0,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		move.l	(a1)+,d3
		eori.l	#$8000800,d3
		swap	d3
		move.l	d3,(a6)+
		addq.w	#1,(a5)
		rts
; ---------------------------------------------------------------------------

Plane_BlockFlipY:
		btst	#2,(a0)
		bne.s	Plane_BlockFlipXY
		move.l	d5,-(sp)
		move.l	d0,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		move.l	(a1)+,d5
		move.l	(a1)+,d3
		eori.l	#$10001000,d3
		move.l	d3,(a6)+
		addq.w	#1,(a5)
		add.l	d7,d0
		move.l	d0,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		eori.l	#$10001000,d5
		move.l	d5,(a6)+
		addq.w	#1,(a5)
		move.l	(sp)+,d5
		rts
; ---------------------------------------------------------------------------

Plane_BlockFlipXY:
		move.l	d5,-(sp)
		move.l	d0,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		move.l	(a1)+,d5
		move.l	(a1)+,d3
		eori.l	#$18001800,d3
		swap	d3
		move.l	d3,(a6)+
		addq.w	#1,(a5)
		add.l	d7,d0
		move.l	d0,(a6)+
		movea.l	a6,a5
		clr.w	(a6)+
		eori.l	#$18001800,d5
		swap	d5
		move.l	d5,(a6)+
		addq.w	#1,(a5)
		move.l	(sp)+,d5
		rts

Plane_GetBlockData:
		add.w	(a3),d5
		add.w	4(a3),d4
		lea	(MCD_TerrainBlocks_Sub).l,a1
		bsr.w	Plane_FindChunkBlock
		move.w	(a0),d3
		andi.w	#$3FF,d3
		lsl.w	#3,d3
		adda.w	d3,a1
		rts


; =============== S U B R O U T I N E =======================================
Plane_Calc_VRAM_Pos:
		add.w	(a3),d5

Plane_Calc_VRAM_Pos_2:
		add.w	4(a3),d4
		andi.w	#$F0,d4
		andi.w	#$1F0,d5
		lsl.w	#4,d4
		lsr.w	#2,d5
		add.w	d5,d4
		moveq	#3,d0
		swap	d0
		move.w	d4,d0
		rts
