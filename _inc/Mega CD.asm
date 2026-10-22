; Mega Drive main-68000 code, included by md-main.asm.
; Cartridge-side cold/warm startup with interrupts masked.
; Clobbers d0-d3/a0-a1. Absent/failed hardware leaves the game in MD RAM.
MCD_Init:
		clr.b	(MCD_status).w
		clr.b	(MCD_TerrainReady).l
		clr.w	(MCD_TerrainPending).l
		clr.w	(MCD_ObjectReplyPending).l
		clr.w	(MCD_RingEventCount).l
		clr.w	(MCD_RingActiveCount).l
		clr.w	(MCD_RingJobPending).l
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
		bsr.w	MCD_WaitReply
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

; Loading/scene code acquires bank 0 explicitly. During active levels the CD
; keeps PRG RAM, including the chunk table and every terrain executor. VBlank
; only acquires this bus for scenes that still use PRG-RAM scratch/DMA.
; d3 is scratch; carry reports failure. The caller masks interrupts.
MCD_AcquireProgramRAM:
		cmpi.b	#MCD_StatusReady,(MCD_status).w
		bne.s	.failed
		move.b	#3,(MCD_SubControl+1).l
		move.w	#MCD_WaitLimit,d3
.wait:
		btst	#1,(MCD_SubControl+1).l
		bne.s	.ready
		dbf	d3,.wait
.failed:
		ori	#1,ccr
		rts
.ready:
		andi.b	#$3F,(MCD_MemoryMode+1).l ; select PRG-RAM bank 0
		andi	#$FE,ccr
		rts

MCD_RequireProgramRAM:
		bsr.w	MCD_AcquireProgramRAM
		bcs.w	MCD_Unavailable
		rts

; Serialized main->sub request. Publish token last, acknowledge result last.
; Release PRG-RAM for the service; loading/scenes reacquire it on return.
; Active levels leave the CD running. Terrain calls use the compact caller
; in Mega CD Terrain Jobs.asm and never acquire PRG RAM.
; IRQs stay masked so VBlank cannot steal the bus during the handshake.
; In: d0.w command, d1.w argument. Out: d0.w result, carry on failure/busy.
; Clobbers d2-d3. The fresh token complements the previous acknowledgement.
MCD_Command:
		move.w	sr,-(sp)
		disable_ints
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
		move.b	#1,(MCD_SubControl+1).l
		move.w	#MCD_WaitLimit,d3
		bsr.s	MCD_WaitReply
		bcs.s	.reclaimFailed
		tst.b	(MCD_TerrainReady).l
		bne.s	.complete
		bsr.w	MCD_AcquireProgramRAM
		bcs.w	MCD_Unavailable
.complete:
		move.w	(sp)+,sr
		andi	#$FE,ccr
		rts
.reclaimFailed:
		bsr.w	MCD_AcquireProgramRAM
		bcs.w	MCD_Unavailable
.failed:
		move.w	(sp)+,sr
		ori	#1,ccr
		rts

; Also used during the initial boot, before MCD_status becomes ready.
MCD_WaitReply:
		cmp.w	(MCD_SubAck).l,d2
		beq.s	.acknowledged
		dbf	d3,MCD_WaitReply
.failed:
		ori	#1,ccr
		rts
.acknowledged:
		move.b	(MCD_SubFlags).l,d0
		andi.b	#MCD_ServiceReady|MCD_ServiceError,d0
		cmpi.b	#MCD_ServiceReady,d0
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
		bsr.w	MCD_Command
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

; This build uses CD RAM even for startup scratch maps. Fail before touching
; that storage if the hardware is missing or initialization failed.
MCD_Unavailable:
		disable_ints
		bsr.w	ClearScreen
		lea	(vdp_data_port).l,a6
		locVRAM ArtTile_Level_Select_Font*tile_size
		lea	(Art_Text).l,a0
		move.w	#bytesToWcnt(Art_Text_End-Art_Text),d1
.font:
		move.w	(a0)+,(a6)
		dbf	d1,.font
		move.l	#vdpComm($1E,CRAM,WRITE),(vdp_control_port).l
		move.w	#$0EEE,(a6)
		locVRAM vram_fg+12*128+12*2
		lea	.text(pc),a0
		moveq	#16-1,d1
.textLoop:
		moveq	#0,d0
		move.b	(a0)+,d0
		cmpi.b	#' ',d0
		beq.s	.blank
		addi.w	#ArtTile_Level_Select_Font-'0',d0
		bra.s	.write
.blank:
		moveq	#0,d0
.write:
		move.w	d0,(a6)
		dbf	d1,.textLoop
		move.w	#$8144,(vdp_control_port).l ; display on; IRQs stay masked
.halt:
		bra.s	.halt
.text:
		dc.b "MEGA CD REQUIRED"
		even

		include "_inc/Mega CD Ring Jobs.asm"
