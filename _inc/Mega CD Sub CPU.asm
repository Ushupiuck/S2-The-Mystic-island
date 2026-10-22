; Raw cartridge-resident program uploaded into PRG-RAM bank 0. No BIOS
; services are executed. This code occupies the conventional BIOS area;
; chunk/job allocations follow it. Disc/BRAM drivers come later.
MCD_SubProgram:
		phase	0
		dc.l	$80000,MCD_SubEntry
		rept	24
		dc.l	MCD_SubError
		endm
		dc.l	MCD_SubIRQ2
		rept	37
		dc.l	MCD_SubError
		endm
MCD_SubEntry:
		move.w	#$2700,sr
		clr.b	($FF8033).l		; mask Gate Array IRQ sources
		clr.w	($FF8030).l		; stop timer
		move.b	#$FF,($FF0011).l		; silence PCM channels
		bset	#0,(MCD_SubMemoryMode).l	; give main CPU 2M Word RAM
		move.w	#MCD_Ready,(MCD_SubOwnStatus).l
		move.w	(MCD_SubMainToken).l,d7
		not.w	d7			; process the staged boot request too
.wait:
		move.w	(MCD_SubMainToken).l,d6
		cmp.w	d6,d7
		beq.s	.wait
		move.w	(MCD_SubMainCommand).l,d0
		beq.s	.done
		cmpi.w	#MCD_CommandPing,d0
		beq.s	.ping
		cmpi.w	#MCD_CommandReturnRAM,d0
		beq.s	.returnRAM
		cmpi.w	#MCD_CommandRingTick,d0
		beq.s	.ringTick
		cmpi.w	#MCD_CommandRingReset,d0
		beq.s	.ringReset
		moveq	#-1,d0
		bra.s	.done
.ping:
		move.w	(MCD_SubMainArgument).l,d0
		bra.s	.done
.returnRAM:
		bset	#0,(MCD_SubMemoryMode).l
		moveq	#0,d0
		bra.s	.done
.ringTick:
		bsr.w	MCD_SubRingTick
		bra.s	.done
.ringReset:
		bsr.w	MCD_SubRingReset
.done:
		move.w	d0,(MCD_SubOwnResult).l
		move.w	d6,d7
		move.w	d7,(MCD_SubOwnAck).l
		bra.s	.wait
MCD_SubIRQ2:
		rte
MCD_SubError:
		move.w	#$FFFF,(MCD_SubOwnStatus).l
		bra.s	*

; Only animation state lives here. Ring coordinates, collision and rewards
; remain on the main CPU. d6/d7 belong to the mailbox and must be preserved.
MCD_SubRingReset:
		lea	(MCD_RingState_Sub).l,a0
		move.w	#bytesToLcnt(MCD_RingState_SubEnd-MCD_RingState_Sub),d1
.clear:
		clr.l	(a0)+
		dbf	d1,.clear
		clr.w	(MCD_RingUpdateCount_Sub).l
		clr.w	(MCD_RingActiveCount_Sub).l
		moveq	#0,d0
		rts

MCD_SubRingTick:
		lea	(MCD_RingState_Sub).l,a0
		lea	(MCD_RingEvents_Sub).l,a1
		lea	(MCD_RingActiveList_Sub).l,a3
		move.w	(MCD_RingActiveCount_Sub).l,d4
		move.w	(MCD_SubMainArgument).l,d1
		subq.w	#1,d1
		bmi.s	.tick
.event:
		move.w	(a1)+,d2
		move.w	#$601,(a0,d2.w)
		move.w	d4,d3
		add.w	d3,d3
		move.w	d2,(a3,d3.w)
		addq.w	#1,d4
		dbf	d1,.event
.tick:
		lea	(MCD_RingUpdates_Sub).l,a4
		moveq	#0,d5
		move.w	d4,d1
		subq.w	#1,d1
		bmi.s	.done
.active:
		move.w	(a3),d2
		move.w	(a0,d2.w),d3
		subi.w	#$100,d3		; timer byte--
		cmpi.w	#$100,d3
		bhs.s	.store
		addi.w	#$601,d3		; timer=6, frame++
		cmpi.b	#5,d3
		bne.s	.store
		moveq	#-1,d3
		subq.w	#1,d4
		move.w	d4,d0
		add.w	d0,d0
		; Remove by replacing this slot with the unprocessed last entry.
		lea	(MCD_RingActiveList_Sub).l,a2
		move.w	(a2,d0.w),(a3)
		bra.s	.output
.store:
		addq.w	#2,a3
.output:
		move.w	d3,(a0,d2.w)
		move.w	d2,(a4)+
		move.w	d3,(a4)+
		addq.w	#1,d5
		dbf	d1,.active
.done:
		move.w	d5,(MCD_RingUpdateCount_Sub).l
		move.w	d4,(MCD_RingActiveCount_Sub).l
		move.w	d4,d0
		rts
		even
		dephase
MCD_SubProgramEnd:
		if (MCD_SubProgramEnd-MCD_SubProgram)>MCD_BIOS_RAM_End
			fatal "Mode 1 bootstrap overlaps the first user PRG-RAM allocation"
		endif
