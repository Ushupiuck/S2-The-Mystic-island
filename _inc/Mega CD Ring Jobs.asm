; Sparse ring animation service. Main RAM keeps the visible status words;
; sub PRG RAM owns the active timers. Collections are queued during physics,
; submitted after scrolling, and applied before sprite rendering that frame.
; Bank 1 is selected ONLY while interrupts are masked; every return restores
; bank 0 so collision, scrolling and PRG-RAM DMA keep their original contract.

; a1 = collected Ring_Positions entry. Preserve the collision loop registers.
; A status word prevents the second player queuing the same ring twice.
MCD_RecordRingCollection:
		move.l	a3,-(sp)
		lea	(MCD_RingEvents).l,a3
		move.w	(MCD_RingEventCount).l,d0
		add.w	d0,d0
		move.w	a1,(a3,d0.w)
		subi.w	#(Ring_Positions&$FFFF),(a3,d0.w)
		addq.w	#1,(MCD_RingEventCount).l
		movea.l	(sp)+,a3
		rts

MCD_ResetRingAnimations:
		bsr.w	MCD_FinishRingJob
		clr.w	(MCD_RingEventCount).l
		clr.w	(MCD_RingActiveCount).l
		moveq	#MCD_CommandRingReset,d0
		moveq	#0,d1
		bsr.w	MCD_Command
		bcs.w	MCD_Unavailable
		rts

; Clobbers d0-d3/a0-a1, as did the original timer pass.
MCD_BeginRingJob:
		move.w	(MCD_RingEventCount).l,d0
		or.w	(MCD_RingActiveCount).l,d0
		beq.s	.idle
		move.w	sr,-(sp)
		disable_ints
		bsr.w	MCD_AcquireProgramRAM
		bcs.w	MCD_Unavailable
		move.w	(MCD_MainToken).l,d2
		cmp.w	(MCD_SubAck).l,d2
		bne.w	MCD_Unavailable
		ori.b	#$40,(MCD_MemoryMode+1).l ; bank 1 ($20000-$3FFFF)
		lea	(MCD_RingEvents).l,a0
		lea	(MCD_RingEvents_Bank1).l,a1
		move.w	(MCD_RingEventCount).l,d1
		move.w	d1,d3
		subq.w	#1,d3
		bmi.s	.copied
.copy:
		move.w	(a0)+,(a1)+
		dbf	d3,.copy
.copied:
		andi.b	#$3F,(MCD_MemoryMode+1).l
		not.w	d2
		move.w	#MCD_CommandRingTick,(MCD_MainCommand).l
		move.w	d1,(MCD_MainArgument).l
		move.w	d2,(MCD_MainToken).l ; publish last
		clr.w	(MCD_RingEventCount).l
		move.w	#1,(MCD_RingJobPending).l
		move.b	#1,(MCD_SubControl+1).l ; run alongside the rest of the frame
		move.w	(sp)+,sr
.idle:
		rts

; Call before Render_Sprites. VBlank may have paused an in-flight service;
; release the sub CPU again before waiting, then reacquire for sparse output.
MCD_FinishRingJob:
		tst.w	(MCD_RingJobPending).l
		beq.s	.idle
		move.w	sr,-(sp)
		disable_ints
		move.w	(MCD_MainToken).l,d2
		move.b	#1,(MCD_SubControl+1).l
		move.w	#MCD_WaitLimit,d3
		bsr.w	MCD_WaitReply
		bcs.w	MCD_Unavailable
		bsr.w	MCD_AcquireProgramRAM
		bcs.w	MCD_Unavailable
		move.w	d0,(MCD_RingActiveCount).l
		ori.b	#$40,(MCD_MemoryMode+1).l
		lea	(MCD_RingUpdates_Bank1).l,a0
		lea	(Ring_Positions).w,a1
		move.w	(MCD_RingUpdateCount_Bank1).l,d1
		subq.w	#1,d1
		bmi.s	.copied
.copy:
		move.w	(a0)+,d0
		move.w	(a0)+,(a1,d0.w)
		dbf	d1,.copy
.copied:
		andi.b	#$3F,(MCD_MemoryMode+1).l
		clr.w	(MCD_RingJobPending).l
		move.w	(sp)+,sr
.idle:
		rts
