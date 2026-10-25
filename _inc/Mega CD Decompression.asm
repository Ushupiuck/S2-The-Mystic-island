; ===========================================================================
; Mega-CD sub-68000 asset decompression.
; MD stages compressed cartridge bytes once. Decode directly to resident CD
; terrain or to the disjoint Word-RAM output banks, then return ownership.
; Mailbox result +4 = output bytes (long), +8 = consumed input bytes (long).
; ===========================================================================
MCD_SubDecompress:
		movea.l	(MCD_SubMainArgument).l,a1
		move.l	a1,(MCD_DecompOutBase_Sub).l
		lea	(MCD_DecompInput_Sub).l,a0
		moveq	#0,d1
		move.w	(MCD_SubMainArgument+6).l,d1
		adda.l	d1,a0
		cmpi.b	#MCD_CommandPLCInit,d0
		beq.w	MCD_SubPLCInit
		cmpi.b	#MCD_CommandNemesis,d0
		beq.s	.nemesis
		cmpi.b	#MCD_CommandEnigma,d0
		beq.s	.enigma
		bsr.w	MCD_SubKosPlusDec
		bra.s	.size
.enigma:
		move.w	(MCD_SubMainArgument+4).l,d0
		bsr.w	MCD_SubEniDec
.size:
		move.l	a1,d0
		sub.l	(MCD_DecompOutBase_Sub).l,d0
		bra.s	.done
.nemesis:
		moveq	#0,d0
		move.w	(a0),d0
		andi.w	#$7FFF,d0
		lsl.l	#5,d0
		move.l	d0,(MCD_DecompOutSize_Sub).l
		movea.l	a1,a4
		bsr.w	MCD_SubNemDecToRAM
		move.l	(MCD_DecompOutSize_Sub).l,d0
.done:
		move.l	d0,(MCD_SubOwnResult+4).l
		move.l	a0,d1
		subi.l	#MCD_DecompInput_Sub,d1
		moveq	#0,d2
		move.w	(MCD_SubMainArgument+6).l,d2
		sub.l	d2,d1
		move.l	d1,(MCD_SubOwnResult+8).l
		bset	#0,(MCD_SubMemoryMode).l
		moveq	#0,d0
		rts

		include "_inc/KosinskiPlus.asm"
		include "_inc/Nemesis Decompression.asm"
		include "_inc/Enigma Decompression.asm"

; Resident compressed input and decoder state let PLC work yield between tiles.
; Other codecs may use the general input/table between these bounded batches.
MCD_SubPLCInit:
		movea.l	a0,a2
		lea	(MCD_PLCInput_Sub).l,a1
		moveq	#0,d1
		move.w	(MCD_SubMainArgument+8).l,d1
		move.w	d1,d3
		lsr.w	#1,d1
		subq.w	#1,d1
.copy:
		move.w	(a0)+,(a1)+
		dbf	d1,.copy
		btst	#0,d3
		beq.s	.copied
		move.b	(a0)+,(a1)+
.copied:
		lea	(MCD_PLCInput_Sub).l,a0
		lea	(MCD_PLCTable_Sub).l,a1
		lea	MCD_SubNemDec_WriteAndAdvance(pc),a3
		move.w	(a0)+,d2
		bpl.s	.mode
		adda.w	#MCD_SubNemDec_WriteAndAdvance_XOR-MCD_SubNemDec_WriteAndAdvance,a3
.mode:
		andi.w	#$7FFF,d2
		move.w	d2,(MCD_PLCRemaining_Sub).l
		bsr.w	MCD_SubNemDec_BuildCodeTable
		move.b	(a0)+,d5
		lsl.w	#8,d5
		move.b	(a0)+,d5
		moveq	#16,d6
		moveq	#0,d0
		moveq	#0,d1
		moveq	#0,d2
		bsr.w	MCD_SubPLCSave
		movea.l	a2,a0
		moveq	#0,d0
		bra.w	MCD_SubDecompress.done

MCD_SubPLCStep:
		moveq	#0,d3
		move.b	(MCD_PLCBudget_Sub).l,d3
		cmp.w	(MCD_PLCRemaining_Sub).l,d3
		bls.s	.count
		move.w	(MCD_PLCRemaining_Sub).l,d3
.count:
		clr.w	(MCD_PLCProduced_Sub).l
		clr.w	(MCD_SubOwnResult+4).l
		tst.w	d3
		beq.w	.return
		movea.w	d3,a2
		movea.w	(MCD_SubStopwatch).l,a6
		lea	(MCD_DecompPLC_Sub).l,a4
		lea	(MCD_PLCTable_Sub).l,a1
		movea.l	(MCD_PLCSource_Sub).l,a0
		movea.l	(MCD_PLCWriter_Sub).l,a3
		move.l	(MCD_PLCRepeat_Sub).l,d0
		move.l	(MCD_PLCPalette_Sub).l,d1
		move.l	(MCD_PLCPrevious_Sub).l,d2
		move.l	(MCD_PLCData_Sub).l,d5
		move.l	(MCD_PLCShift_Sub).l,d6
.tile:
		movea.w	#8,a5
		bsr.w	MCD_SubNemPCD_NewRow
		addq.w	#1,(MCD_PLCProduced_Sub).l
		subq.w	#1,a2
		move.w	a2,d3
		beq.s	.done
		tst.w	(MCD_PLCTimeLimit_Sub).l
		beq.s	.tile		; explicit tile-only jobs, including native fixtures
		move.w	(MCD_SubStopwatch).l,d3
		sub.w	a6,d3
		andi.w	#$FFF,d3		; the free-running counter wraps after 4096 ticks
		cmp.w	(MCD_PLCTimeLimit_Sub).l,d3
		blo.s	.tile
.done:
		bsr.s	MCD_SubPLCSave
		move.w	(MCD_PLCProduced_Sub).l,d3
		sub.w	d3,(MCD_PLCRemaining_Sub).l
		move.w	d3,(MCD_SubOwnResult+4).l
.return:
		rts

MCD_SubPLCSave:
		move.l	a0,(MCD_PLCSource_Sub).l
		move.l	a3,(MCD_PLCWriter_Sub).l
		move.l	d0,(MCD_PLCRepeat_Sub).l
		move.l	d1,(MCD_PLCPalette_Sub).l
		move.l	d2,(MCD_PLCPrevious_Sub).l
		move.l	d5,(MCD_PLCData_Sub).l
		move.l	d6,(MCD_PLCShift_Sub).l
		rts

MCD_SubArtFrame:
		bsr.w	MCD_SubPLCStep
		bset	#0,(MCD_SubMemoryMode).l
		moveq	#0,d0
		rts
