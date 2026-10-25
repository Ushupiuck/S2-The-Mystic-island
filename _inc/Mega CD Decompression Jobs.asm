; ===========================================================================
; Mega Drive main-68000 decompression transport and prepared-art DMA.
; The codecs execute on CD; this file copies compressed cartridge input and
; applies results. Word-RAM input, general output and PLC output are disjoint.
; ===========================================================================
KosPlusDec:
		movem.l	d0-d7/a2-a6,-(sp)
		moveq	#MCD_CommandKosPlus,d6
		moveq	#0,d5
		bra.w	MCD_Decompress
MCD_KosToCD:
		movem.l	d0-d7/a2-a6,-(sp)
		moveq	#MCD_CommandKosPlus,d6
		moveq	#1,d5			; a1 is already a physical CD address
		bra.w	MCD_Decompress
EniDec:
		movem.l	d0-d7/a2-a6,-(sp)
		move.w	d0,d7			; base tile
		moveq	#MCD_CommandEnigma,d6
		moveq	#2,d5			; Enigma retains its original output pointer
		bra.w	MCD_Decompress
MCD_NemToCD:
		movem.l	d0-d7/a2-a6,-(sp)
		moveq	#MCD_CommandNemesis,d6
		moveq	#1,d5
		bra.w	MCD_Decompress
MCD_InitPLC:
		movem.l	d0-d7/a2-a6,-(sp)
		moveq	#MCD_CommandPLCInit,d6
		moveq	#1,d5
		bra.w	MCD_Decompress
MCD_NemToMD:
		movem.l	d0-d7/a2-a6,-(sp)
		moveq	#MCD_CommandNemesis,d6
		moveq	#0,d5
		bra.w	MCD_Decompress
NemDecToRAM:
		movem.l	d0-a6,-(sp)
		movea.l	a4,a1
		bsr.s	MCD_NemToMD
		movem.l	(sp)+,d0-a6
		rts

; Explicit VRAM destination in d2. Direct-loading scenes use the normal DMA
; queue and a DMA-only VBlank, retaining Word RAM until the queue is consumed.
NemDec:
		movem.l	d0-a6,-(sp)
		movea.w	d2,a6
		moveq	#0,d3
		move.w	(a0),d3
		andi.w	#$7FFF,d3
		lsl.l	#4,d3
		movea.l	d3,a5
		lea	(MCD_DecompOutput_Sub).l,a1
		bsr.s	MCD_NemToCD
.queue:
		move.l	#MCD_DecompOutput,d1
		move.w	a6,d2
		move.w	a5,d3
		move.w	(VDP_Command_Buffer_Slot).w,d4
		jsr	(QueueDMATransfer).l
		cmp.w	(VDP_Command_Buffer_Slot).w,d4
		bne.s	.queued
		bsr.w	MCD_FlushDecodeDMA
		bra.s	.queue
.queued:
		bsr.w	MCD_FlushDecodeDMA
		movem.l	(sp)+,d0-a6
		rts

; d6 codec, d5 flags, d7 Enigma base tile. Preserve the ordinary public ABI.
; A compressed archive remains cached across modules until another input uses
; the buffer, so subsequent modules do not recopy the archive unnecessarily.
MCD_Decompress:
		move.w	sr,-(sp)
		disable_ints
		movea.l	a0,a2
		movea.l	a1,a3
		jsr	(MCD_FinishRingJob).l
		jsr	(MCD_FinishTerrainJob).l
.flush:
		tst.b	(MCD_dma_pending).w
		bne.s	.flushDMA
		tst.w	(MCD_KosDMAWords).l
		beq.s	.owned
.flushDMA:
		bsr.w	MCD_FlushDecodeDMA
		bra.s	.flush
.owned:
		jsr	(MCD_AcquireWordRAM).l
		jcs	MCD_Unavailable
		tst.b	(MCD_TerrainReady).l
		beq.s	.inputOwned
		move.w	(sp),sr		; permit palette/deferred VDP work during input copies
		tst.b	(f_doupdatesinhblank).w
		beq.s	.inputOwned
		enable_ints
.deferredVDP:
		tst.b	(f_doupdatesinhblank).w
		bne.s	.deferredVDP
		move.w	(sp),sr
.inputOwned:
		move.l	a2,d0
		cmp.l	(MCD_DecompCachedStart).l,d0
		blo.s	.find
		cmp.l	(MCD_DecompCachedEnd).l,d0
		blo.s	.cached
.find:
		lea	(MCD_CompressedAssets).l,a5
		move.w	#(MCD_CompressedAssets_End-MCD_CompressedAssets)/8-1,d2
.span:
		cmp.l	(a5),d0
		blo.s	.next
		cmp.l	4(a5),d0
		blo.s	.found
.next:
		addq.w	#8,a5
		dbf	d2,.span
		jmp	(MCD_Unavailable).l
.found:
		move.l	d0,(MCD_DecompCachedStart).l
		move.l	4(a5),(MCD_DecompCachedEnd).l
		move.l	4(a5),d1
		sub.l	d0,d1
		cmpi.l	#MCD_DecompInputSize,d1
		jhi	MCD_Unavailable
		lea	(MCD_DecompInput).l,a1
		movea.l	a2,a0
		btst	#0,d0
		bne.s	.copyBytes
		move.l	d1,d2
		lsr.l	#1,d2
		subq.w	#1,d2
		bmi.s	.tail
.copyWords:
		move.w	(a0)+,(a1)+
		dbf	d2,.copyWords
.tail:
		btst	#0,d1
		beq.s	.cached
		move.b	(a0)+,(a1)+
		bra.s	.cached
.copyBytes:
		subq.w	#1,d1
.copyByte:
		move.b	(a0)+,(a1)+
		dbf	d1,.copyByte
.cached:
		move.l	a2,d0
		sub.l	(MCD_DecompCachedStart).l,d0
		move.w	d0,(MCD_MainArgument+6).l
		movea.l	a3,a4
		btst	#0,d5
		bne.s	.target
		move.l	a3,d0
		andi.l	#$FFFFFF,d0
		cmpi.l	#MCD_ProgramRAM,d0
		blo.s	.ramOutput
		cmpi.l	#MCD_ProgramRAM+$20000,d0
		bhs.s	.wordOutput
		subi.l	#MCD_ProgramRAM,d0
		movea.l	d0,a4
		bra.s	.target
.wordOutput:
		cmpi.l	#MCD_WordRAM,d0
		blo.s	.ramOutput
		cmpi.l	#MCD_WordRAM+$40000,d0
		bhs.s	.ramOutput
		subi.l	#MCD_WordRAM-MCD_SubWordRAM,d0
		movea.l	d0,a4
		bra.s	.target
.ramOutput:
		lea	(MCD_DecompOutput_Sub).l,a4
		bset	#2,d5			; MD RAM / Z80 RAM needs a result copy
.target:
		disable_ints
		move.l	(MCD_DecompCachedEnd).l,d0
		sub.l	a2,d0
		move.w	d0,(MCD_MainArgument+8).l
		move.l	a4,(MCD_MainArgument).l
		move.w	d7,(MCD_MainArgument+4).l
		jsr	(MCD_ReleaseWordRAM).l
		jcs	MCD_Unavailable
		move.w	(MCD_MainToken).l,d2
		cmp.w	(MCD_SubAck).l,d2
		jne	MCD_Unavailable
		not.w	d2
		move.w	d6,(MCD_MainCommand).l
		move.w	d2,(MCD_MainToken).l
		move.b	#1,(MCD_SubControl+1).l
		tst.b	(MCD_TerrainReady).l
		beq.s	.wait
		move.w	(sp),sr		; water/palette IRQs may run during a long decode
.wait:
		move.w	#MCD_WaitLimit,d3
		jsr	(MCD_WaitReply).l
		disable_ints
		jcs	MCD_Unavailable
		tst.b	(MCD_TerrainReady).l
		bne.s	.result
		jsr	(MCD_RequireProgramRAM).l
.result:
		move.l	(MCD_SubResult+4).l,d2
		btst	#2,d5
		beq.s	.pointers
		lea	(MCD_DecompOutput).l,a0
		movea.l	a3,a1
		move.l	a3,d0
		andi.l	#$FFFFFF,d0
		cmpi.l	#Z80_RAM,d0
		blo.s	.copyResult
		cmpi.l	#Z80_RAM+$10000,d0
		blo.s	.copyResultBytes	; Z80 RAM requires byte writes
.copyResult:
		btst	#0,d0
		bne.s	.copyResultBytes
		move.l	d2,d1
		lsr.l	#1,d1
		subq.w	#1,d1
		bmi.s	.resultTail
.resultWord:
		move.w	(a0)+,(a1)+
		dbf	d1,.resultWord
.resultTail:
		btst	#0,d2
		beq.s	.pointers
		move.b	(a0)+,(a1)+
		bra.s	.pointers
.copyResultBytes:
		move.l	d2,d1
		subq.w	#1,d1
		bmi.s	.pointers
.resultByte:
		move.b	(a0)+,(a1)+
		dbf	d1,.resultByte
.pointers:
		movea.l	a2,a0
		adda.l	(MCD_SubResult+8).l,a0
		movea.l	a3,a1
		btst	#1,d5
		bne.s	.return
		adda.l	d2,a1
.return:
		move.w	(sp)+,sr
		movem.l	(sp)+,d0-d7/a2-a6
		rts

; May be called with IRQs masked. Preserve the caller's VBlank selection and
; interrupt mask; the DMA-only handler avoids touching an unfinished scene.
MCD_FlushDecodeDMA:
		move.w	sr,-(sp)
		move.w	(v_vbla_routine).w,-(sp)
		move.w	#Vint_CtrlDMA,(v_vbla_routine).w
		jsr	(WaitForVint).l
		move.w	(sp)+,(v_vbla_routine).w
		move.w	(sp)+,sr
		rts

; Called after CD frame work finishes, immediately before WaitForVint publishes
; its full-VBlank request. Queue pointers only while Word RAM is MD-owned, and
; never recycle their output banks before that VBlank consumes them.
MCD_PublishDecompressionDMA:
		movem.l	d0-d4/a1,-(sp)
		tst.w	(MCD_KosDMAWords).l
		beq.s	.plc
		move.l	#MCD_DecompOutput,d1
		move.w	(MCD_KosDMADest).l,d2
		move.w	(MCD_KosDMAWords).l,d3
		move.w	(VDP_Command_Buffer_Slot).w,d4
		jsr	(QueueDMATransfer).l
		cmp.w	(VDP_Command_Buffer_Slot).w,d4
		beq.s	.plc
		clr.w	(MCD_KosDMAWords).l
.plc:
		tst.w	(v_plc_framepatternsleft).w
		bne.s	.return
		move.w	(MCD_PLCPrepared).l,d3
		beq.s	.return
		move.w	d3,-(sp)
		lsl.w	#4,d3
		move.l	#MCD_DecompPLC,d1
		move.w	(v_plc_buffer+4).w,d2
		move.w	(VDP_Command_Buffer_Slot).w,d4
		jsr	(QueueDMATransfer).l
		move.w	(sp)+,d3
		cmp.w	(VDP_Command_Buffer_Slot).w,d4
		beq.s	.return
		move.w	d3,(v_plc_framepatternsleft).w
		clr.w	(MCD_PLCPrepared).l
		sub.w	d3,(v_plc_patternsleft).w
		lsl.w	#5,d3
		add.w	d3,(v_plc_buffer+4).w
.return:
		movem.l	(sp)+,d0-d4/a1
		rts

; Allow larger DMA batches, with a separate CD stopwatch budget so expensive
; tiles yield to the terrain/object service. A prepared or queued batch owns
; its output bank until DMA consumption; backpressure prevents overwrites.
MCD_PreparePLCBudget:
		clr.b	(MCD_PLCBudget).l
		clr.w	(MCD_PLCTimeLimit).l
		tst.w	(v_plc_patternsleft).w
		beq.s	.return
		tst.w	(MCD_PLCPrepared).l
		bne.s	.return
		tst.w	(v_plc_framepatternsleft).w
		bne.s	.return
		move.w	(v_vbla_routine).w,d0
		moveq	#MCD_PLCTilesLoading,d1
		move.w	#MCD_PLCTicksLoading,d2
		cmpi.w	#Vint_Level,d0
		beq.s	.small
		cmpi.w	#Vint_LevelLoad,d0
		beq.s	.small
		cmpi.w	#Vint_Pause,d0
		beq.s	.small
		cmpi.w	#Vint_Title,d0
		beq.s	.budget
		cmpi.w	#Vint_TitleCard,d0
		beq.s	.budget
		cmpi.w	#Vint_Fade,d0
		beq.s	.budget
		cmpi.w	#Vint_SSResults,d0
		bne.s	.return
		bra.s	.budget
.small:
		moveq	#MCD_PLCTilesLevel,d1
		move.w	#MCD_PLCTicksLevel,d2
.budget:
		move.b	d1,(MCD_PLCBudget).l
		move.w	d2,(MCD_PLCTimeLimit).l
.return:
		rts
