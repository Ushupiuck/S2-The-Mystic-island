; ---------------------------------------------------------------------------
; S3&K dynamic pattern loading: word count, then one packed word per run.
; d0 = frame, a2 = DPLC table, a3 = cached-frame byte, d4 = VRAM destination,
; d6 = uncompressed art. Preserve a0 and d7 (the object-loop counter).
; Carry is set if the queue cannot accept the complete frame; retry next time.
; ---------------------------------------------------------------------------
Load_DynamicPLC:
		cmp.b	(a3),d0
		beq.s	.return
		move.w	d0,-(sp)
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,d5
		beq.s	.ready
		; Each run can split at a 128 KB source boundary. Reserve both slots
		; before queuing anything, so a partial upload never becomes cached.
		move.w	d5,d1
		mulu.w	#DMAEntry.len*2,d1
		move.w	(VDP_Command_Buffer_Slot).w,d0
		add.w	d1,d0
		cmpi.w	#VDP_Command_Buffer_Slot,d0
		bhi.s	.full
		subq.w	#1,d5
.run:
		moveq	#0,d1
		move.w	(a2)+,d1
		move.w	d1,d3
		lsr.w	#8,d3
		andi.w	#$F0,d3
		addi.w	#$10,d3			; (count nibble + 1) * 16 words
		andi.w	#$FFF,d1
		lsl.l	#5,d1
		add.l	d6,d1
		move.w	d4,d2
		add.w	d3,d4
		add.w	d3,d4
		jsr	(QueueDMATransfer).l
		dbf	d5,.run
.ready:
		move.w	(sp)+,d0
		move.b	d0,(a3)
		andi.b	#$FE,ccr
.return:
		rts
.full:
		addq.w	#2,sp
		ori.b	#1,ccr
		rts
