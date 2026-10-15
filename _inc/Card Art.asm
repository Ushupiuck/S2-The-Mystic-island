; ---------------------------------------------------------------------------
; Card DPLCs use the same packed tile runs as Load_DynamicPLC. A complete card
; can exceed the DMA queue's run count, so its owner resumes on the next frame.
; The owner creates its visible children only after the final DMA has executed.
; d0 = scene (0-63 intro, 64-71 act results, 72-77 special-stage results)
; d4 = destination in VRAM bytes. Preserves a0/d7; clobbers d0-d6/a1-a3.
; Carry set: wait for another VBlank. Carry clear: all art is available.
; ---------------------------------------------------------------------------
card_dplc_ptr = objoff_28
card_dplc_left = objoff_2C
card_dplc_dest = objoff_2E

Load_CardDPLC:
		tst.l	card_dplc_ptr(a0)
		bne.s	.resume
		lea	(DPLC_Cards).l,a2
		add.w	d0,d0
		adda.w	(a2,d0.w),a2
		move.w	(a2)+,card_dplc_left(a0)
		move.l	a2,card_dplc_ptr(a0)
		move.w	d4,card_dplc_dest(a0)
.resume:
		tst.w	card_dplc_left(a0)
		beq.s	.ready
.run:
		; Reserve both entries in case this run crosses a ROM 128KB boundary.
		move.w	(VDP_Command_Buffer_Slot).w,d0
		cmpi.w	#VDP_Command_Buffer_Slot-2*DMAEntry.len,d0
		bhi.s	.wait
		movea.l	card_dplc_ptr(a0),a2
		moveq	#0,d1
		move.w	(a2)+,d1
		move.l	a2,card_dplc_ptr(a0)
		move.w	d1,d3
		lsr.w	#8,d3
		andi.w	#$F0,d3
		addi.w	#$10,d3		; tile count -> word count
		andi.w	#$FFF,d1
		lsl.l	#5,d1
		addi.l	#Art_CardFont,d1
		move.w	card_dplc_dest(a0),d2
		add.w	d3,card_dplc_dest(a0)
		add.w	d3,card_dplc_dest(a0)
		jsr	(QueueDMATransfer).l
		subq.w	#1,card_dplc_left(a0)
		bne.s	.run
.wait:
		ori.b	#1,ccr
		rts
.ready:
		andi.b	#$FE,ccr
		rts

Get_NormalCardScene:
		lea	(Map_Obj3A).l,a3
		moveq	#0,d0
		move.b	(Current_Act).w,d0
		add.w	d0,d0
		addi.w	#64,d0
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.return
		addq.w	#1,d0
		lea	(Map_Got_Tails).l,a3
.return:
		rts

Get_SpecialCardScene:
		moveq	#0,d0
		tst.b	(v_emeralds).w
		beq.s	.character
		moveq	#2,d0
		cmpi.b	#6,(v_emeralds).w
		bne.s	.character
		moveq	#4,d0
.character:
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.map
		addq.w	#1,d0
.map:
		move.w	d0,d1
		lsl.w	#2,d1
		lea	(Card_SS_MapPointers).l,a3
		movea.l	(a3,d1.w),a3
		addi.w	#72,d0
		rts

; Preserve Sonic's portrait for Sonic monitors. Only the name strip is
; replaced for Tails; his HUD portrait refers to the final monitor-art tiles.
Load_LifeArtPLC:
		moveq	#plcid_LivesSonic,d0
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
		bne.s	.load
		moveq	#plcid_LivesTails,d0
.load:
		jmp	(LoadPLC).l
