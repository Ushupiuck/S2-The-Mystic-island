; Cartridge-side cold/warm startup with interrupts masked.
; Clobbers d0-d3/a0-a1. Absent/failed hardware leaves the game in MD RAM.
MCD_Init:
		clr.b	(MCD_status).w
		btst	#5,(HW_Version).l
		beq.s	.present
		cmpi.l	#"SEGA",(MCD_BootROM+$100).l
		beq.s	.present
		rts
.present:
		move.w	#$FF00,(MCD_MemoryMode).l
		lea	(MCD_SubControl+1).l,a1
		move.b	#3,(a1)
		move.b	#2,(a1)
		clr.b	(a1)
		moveq	#$7F,d0
.settle:
		dbf	d0,.settle
		move.w	#MCD_WaitLimit,d3
.reset:
		btst	#0,(a1)
		beq.s	.request
		dbf	d3,.reset
		bra.w	.failed
.request:
		move.b	#3,(a1)
		move.w	#MCD_WaitLimit,d3
.bus:
		move.b	(a1),d0
		andi.b	#3,d0
		cmpi.b	#3,d0
		beq.s	.load
		dbf	d3,.bus
		bra.w	.failed
.load:
		clr.w	(MCD_MemoryMode).l	; bank 0, no protection, 2M Word RAM
		lea	(MCD_SubProgram).l,a0
		lea	(MCD_ProgramRAM).l,a1
		move.w	#(MCD_SubProgramEnd-MCD_SubProgram)/2-1,d3
.copy:
		move.w	(a0)+,(a1)+
		dbf	d3,.copy
		lea	(MCD_SubProgram).l,a0
		lea	(MCD_ProgramRAM).l,a1
		move.w	#(MCD_SubProgramEnd-MCD_SubProgram)/2-1,d3
.verify:
		cmpm.w	(a0)+,(a1)+
		bne.s	.failed
		dbf	d3,.verify
		; Hardware requires a second reset after the upload, even on cold boot.
		lea	(MCD_SubControl+1).l,a1
		clr.b	(a1)
		move.w	#MCD_WaitLimit,d3
.resetAgain:
		btst	#0,(a1)
		beq.s	.start
		dbf	d3,.resetAgain
		bra.s	.failed
.start:
		; Stage the first request before starting the CPU: an initial empty
		; acknowledgement must not race the first ping after a warm reset.
		moveq	#MCD_CommandPing,d0
		move.w	#MCD_Ready,d1
		move.w	(MCD_SubAck).l,d2
		not.w	d2
		move.w	d0,(MCD_MainCommand).l
		move.w	d1,(MCD_MainArgument).l
		move.w	d2,(MCD_MainToken).l
		move.b	#1,(a1)
		move.w	#MCD_WaitLimit,d3
		bsr.w	MCD_Command.wait
		bcs.s	.failed
		cmpi.w	#MCD_Ready,d0
		bne.s	.failed
		btst	#0,(MCD_MemoryMode+1).l
		beq.s	.failed
		move.b	#MCD_StatusReady,(MCD_status).w
		rts
.failed:
		clr.b	(MCD_SubControl+1).l
		move.b	#MCD_StatusFailed,(MCD_status).w
		rts

; Serialized main->sub request. Publish token last, acknowledge result last.
; In: d0.w command, d1.w argument. Out: d0.w result, carry on failure/busy.
; Clobbers d2-d3. The fresh token complements the previous acknowledgement.
MCD_Command:
		cmpi.b	#MCD_StatusReady,(MCD_status).w
		bne.s	.failed
		move.w	(MCD_MainToken).l,d2
		cmp.w	(MCD_SubAck).l,d2
		bne.s	.failed
		move.w	(MCD_SubAck).l,d2
		not.w	d2
		move.w	d0,(MCD_MainCommand).l
		move.w	d1,(MCD_MainArgument).l
		move.w	d2,(MCD_MainToken).l
		move.w	#MCD_WaitLimit,d3
.wait:
		cmp.w	(MCD_SubAck).l,d2
		beq.s	.acknowledged
		dbf	d3,.wait
.failed:
		ori	#1,ccr
		rts
.acknowledged:
		cmpi.w	#MCD_Ready,(MCD_SubStatus).l
		bne.s	.failed
		move.w	(MCD_SubResult).l,d0
		andi	#$FE,ccr
		rts

; 2M-mode ownership. Acquire before CPU access or queuing DMA; retain ownership
; until ProcessDMAQueue consumes it. No acquisition/wait occurs in VBlank.
MCD_AcquireWordRAM:
		cmpi.b	#MCD_StatusReady,(MCD_status).w
		bne.s	.failed
		btst	#2,(MCD_MemoryMode+1).l
		bne.s	.failed
		btst	#0,(MCD_MemoryMode+1).l
		bne.s	.ready
		moveq	#MCD_CommandReturnRAM,d0
		bsr.s	MCD_Command
		bcs.s	.failed
		btst	#0,(MCD_MemoryMode+1).l
		beq.s	.failed
.ready:
		andi	#$FE,ccr
		rts
.failed:
		ori	#1,ccr
		rts

MCD_ReleaseWordRAM:
		move.w	sr,-(sp)
		disable_ints
		cmpi.b	#MCD_StatusReady,(MCD_status).w
		bne.s	.failed
		tst.b	(MCD_dma_pending).w
		bne.s	.failed
		btst	#2,(MCD_MemoryMode+1).l
		bne.s	.failed
		bset	#1,(MCD_MemoryMode+1).l
		move.w	(sp)+,sr
		andi	#$FE,ccr
		rts
.failed:
		move.w	(sp)+,sr
		ori	#1,ccr
		rts
