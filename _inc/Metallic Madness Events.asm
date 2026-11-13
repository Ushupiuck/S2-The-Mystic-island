; Mega Drive main-68000: Metallic Madness plane events, palette and art.
; Based on scddisasm test 791253ba1922d7c4142a40975860d1b3bb37b9f7.
; The CD provider shares its row selectors with the MD hscroll writer.

BgScroll_MMZ1:
		; Derive parallax directly, including checkpoint/debug camera changes.
		; There is no incremental camera state or block-crossing work to maintain.
MMZ1_SetCameras:
		move.w	(Camera_Y_pos).w,d0
		lsr.w	#2,d0
		move.w	d0,(Camera_BG_Y_pos).w
		move.w	d0,(Camera_BG2_Y_pos).w
		move.w	d0,(Camera_BG3_Y_pos).w
		move.w	d0,(v_bgscrposy_vdp).w
MMZ_SetHorizontalCameras:
		move.w	(Camera_X_pos).w,d0
		lsr.w	#1,d0
		move.w	d0,(Camera_BG2_X_pos).w
		lsr.w	#1,d0
		move.w	d0,(Camera_BG3_X_pos).w
		moveq	#0,d0
		move.w	(Camera_X_pos).w,d0
		move.l	d0,d1
		add.l	d0,d0
		add.l	d1,d0
		lsr.l	#4,d0
		move.w	d0,(Camera_BG_X_pos).w
		rts

Deform_MMZ1:
		bsr.w	MMZ1_SetCameras
		bsr.w	MMZ_FillGradient
		lea	(MCD_SubProgram+Plane_MMZ1ScrollRows).l,a0
		cmpi.b	#1,(Current_Timezone).w
		bne.s	.rows
		lea	(MCD_SubProgram+Plane_MMZ1PastScrollRows).l,a0
.rows:
		bra.w	MMZ_DrawScrollRows

BgScroll_MMZ2:
MMZ2_SetCameras:
		move.w	(Camera_Y_pos).w,d0
		lsr.w	#3,d0
		move.w	d0,(Camera_BG_Y_pos).w
		move.w	d0,(Camera_BG2_Y_pos).w
		move.w	d0,(Camera_BG3_Y_pos).w
		move.w	d0,(v_bgscrposy_vdp).w
		bra.w	MMZ_SetHorizontalCameras

Deform_MMZ2:
		bsr.s	MMZ2_SetCameras
		bsr.w	MMZ2_UpdatePriority
		cmpi.b	#1,(Current_Timezone).w
		beq.s	.past
		bsr.s	MMZ_FillGradient
		lea	(MCD_SubProgram+Plane_MMZ2ScrollRows).l,a0
		bra.w	MMZ_DrawScrollRows
.past:
		lea	(v_bgscroll_buffer).w,a2
		move.w	(Camera_X_pos).w,d2
		sub.w	(Camera_BG_X_pos).w,d2
		; floor(delta*64/12)<<10, exact for delta <8192 (the whole act).
		; The reciprocal retains the original fixed-point quantization.
		mulu.w	#$AAAB,d2
		andi.l	#$FFFFE000,d2
		lsr.l	#3,d2
		moveq	#0,d3
		move.w	(Camera_BG_X_pos).w,d3
		swap	d3
		moveq	#12-1,d6
		bsr.s	MMZ_WriteGradient
		moveq	#0,d2
		move.w	(Camera_BG3_X_pos).w,d2
		sub.w	(Camera_BG_X_pos).w,d2
		lsl.l	#8,d2
		lsl.l	#5,d2	; delta*64/8 <<10 = delta<<13
		moveq	#0,d3
		move.w	(Camera_BG_X_pos).w,d3
		swap	d3
		moveq	#8-1,d6
		bsr.s	MMZ_WriteGradient
		move.w	(Camera_BG_X_pos).w,d0
		neg.w	d0
		move.w	d0,(a2)+
		move.w	(Camera_BG2_X_pos).w,d0
		neg.w	d0
		move.w	d0,(a2)+
		move.w	(Camera_BG3_X_pos).w,d0
		neg.w	d0
		move.w	d0,(a2)
		lea	(MCD_SubProgram+Plane_MMZ2PastScrollRows).l,a0
		bra.s	MMZ_DrawScrollRows

MMZ_WriteGradient:
		move.l	d3,d0
		swap	d0
		neg.w	d0
		move.w	d0,(a2)+
		add.l	d2,d3
		dbf	d6,MMZ_WriteGradient
		rts

MMZ_FillGradient:
		; Nine gradient values cover Past's longer slopes as well as Present's.
		; Use an unsigned quotient: EXT.W would reverse the far-right gradient.
		moveq	#0,d2
		move.w	(Camera_BG2_X_pos).w,d2
		sub.w	(Camera_BG3_X_pos).w,d2
		lsl.l	#7,d2
		divu.w	#5,d2
		andi.l	#$FFFF,d2
		lsl.l	#8,d2
		add.l	d2,d2
		moveq	#0,d3
		move.w	(Camera_BG3_X_pos).w,d3
		swap	d3
		lea	(v_bgscroll_buffer).w,a2
		moveq	#9-1,d6
.gradient:
		move.l	d3,d0
		swap	d0
		neg.w	d0
		move.w	d0,(a2)+
		add.l	d2,d3
		dbf	d6,.gradient
		move.w	(Camera_BG_X_pos).w,d0
		neg.w	d0
		move.w	d0,(a2)+
		move.w	(Camera_BG2_X_pos).w,d0
		neg.w	d0
		move.w	d0,(a2)
		rts

MMZ_DrawScrollRows:
		lea	(v_bgscroll_buffer).w,a2
		move.w	(Camera_BG_Y_pos).w,d0
		move.w	d0,d2
		lsr.w	#3,d0
		adda.w	d0,a0
		andi.w	#7,d2
		add.w	d2,d2
		move.w	(Camera_X_pos).w,d7
		neg.w	d7
		swap	d7
		lea	(v_hscrolltablebuffer).w,a1
		moveq	#28,d6
		moveq	#0,d0
		move.b	(a0)+,d0
		move.w	(a2,d0.w),d7
		jmp	.write8(pc,d2.w)
.row:
		moveq	#0,d0
		move.b	(a0)+,d0
		move.w	(a2,d0.w),d7
.write8:
		; Up to eight spare lines use the declared hscroll padding. VBlank
		; uploads only 224. No per-line lookup, multiplication or branch.
		move.l	d7,(a1)+
		move.l	d7,(a1)+
		move.l	d7,(a1)+
		move.l	d7,(a1)+
		move.l	d7,(a1)+
		move.l	d7,(a1)+
		move.l	d7,(a1)+
		move.l	d7,(a1)+
		dbf	d6,.row
		rts

; CD's high layout bit affected each player independently. A 64-column ROM
; bitset keeps that presentation rule outside the collision mailbox/hot probes.
MMZ2_UpdatePriority:
		moveq	#0,d0
		move.b	(Current_Timezone).w,d0
		lsl.w	#6,d0
		lea	(MMZ2_LayerFlags).l,a2
		adda.w	d0,a2
		lea	(v_player).w,a1
		bsr.s	.actor
		lea	(v_player2).w,a1
.actor:
		tst.l	code(a1)
		beq.s	.return
		andi.w	#$7FFF,obGfx(a1)
		cmpi.b	#$C,obTopSolidBit(a1)
		bne.s	.return
		move.w	obY(a1),d0
		lsr.w	#8,d0
		cmpi.w	#8,d0
		bhs.s	.return
		lsl.w	#3,d0
		move.w	obX(a1),d1
		lsr.w	#8,d1
		cmpi.w	#64,d1
		bhs.s	.return
		move.w	d1,d2
		lsr.w	#3,d2
		add.w	d2,d0
		btst	d1,(a2,d0.w)
		beq.s	.return
		ori.w	#$8000,obGfx(a1)
.return:	rts

MMZ2_LayerFlags:	binclude "mappings/128x128/MMZ2 Layer Flags.bin"
		even
