;----------------------------------------------------------------------------
; Object 36 - Spikes
; ---------------------------------------------------------------------------
; OST Variables:
spikes_base_x_pos	= objoff_30	; original x-position
spikes_base_y_pos	= objoff_32	; original y-position
spikes_retract_offset	= objoff_34	; actual position relative to base position
spikes_retract_state	= objoff_36	; 0 = positive offset, 1 = original position
spikes_retract_timer	= objoff_38	; delay, before spikes move again
; ---------------------------------------------------------------------------

Obj36:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj36_Index(pc,d0.w),d1
		jmp	Obj36_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj36_Index:	dc.w Spike_Init-Obj36_Index	; 0
		dc.w Spike_Solid-Obj36_Index	; 2	; Upright
		dc.w Spike_Solid-Obj36_Index	; 4	; Sideways
		dc.w Spike_Solid-Obj36_Index	; 6	; Upsidedown
; ---------------------------------------------------------------------------
Obj36_Conf:
		;    width_pixels
		;	 y_radius
		dc.b $10,$10	; 0	- Upright or ceiling spikes
		dc.b $20,$10	; 2
		dc.b $30,$10	; 4
		dc.b $40,$10	; 6
		dc.b $10,$10	; 8	- Sideways spikes
		dc.b $10,$20	; 10
		dc.b $10,$30	; 12
		dc.b $10,$40	; 14
; ---------------------------------------------------------------------------

Spike_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj36,obMap(a0)
		move.w	#make_art_tile(ArtTile_Spikes,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	obSubtype(a0),d0
		andi.b	#$F,obSubtype(a0)	; lower 4 bits determine behavior, upper bits need to be removed
		andi.w	#$F0,d0
		lea	Obj36_Conf(pc),a1	; upper 4 bits determine size and orientation
		lsr.w	#3,d0
		adda.w	d0,a1
		move.b	(a1)+,obActWid(a0)
		move.b	(a1)+,obHeight(a0)
		lsr.w	#1,d0			; use upper 4 bits to determine mappings frame
		move.b	d0,obFrame(a0)
		cmpi.b	#4,d0			; do spikes face sideways?
		blo.s	+			; if not, branch
		addq.b	#2,obRoutine(a0)	; => Obj36_Sideways
	;	move.w	#make_art_tile(ArtTile_ArtNem_HorizSpike,1,0),art_tile(a0)
+
		btst	#1,obStatus(a0)		; are spikes upside-down?
		beq.s	+			; if not, branch
		move.b	#6,obRoutine(a0)	; => Obj36_Upsidedown
+
		move.w	obX(a0),spikes_base_x_pos(a0)
		move.w	obY(a0),spikes_base_y_pos(a0)
		rts

; ===========================================================================
Spike_Solid:
		bsr.w	MoveSpikes
		move.w	#4,d2
		cmpi.b	#5,obFrame(a0)
		beq.s	loc_C6EA
		cmpi.b	#1,obFrame(a0)
		bne.s	loc_C70C
		move.w	#$14,d2

loc_C6EA:
		move.w	#$1B,d1
		move.w	d2,d3
		addq.w	#1,d3
		move.w	obX(a0),d4
		bsr.w	SolidObject
		btst	#3,obStatus(a0)
		bne.s	+
		swap	d6
		andi.w	#3,d6
		bne.s	loc_C736
+		out_of_range.w	DeleteObject,spikes_base_x_pos(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

loc_C70C:
		moveq	#0,d1
		move.b	obActWid(a0),d1
		addi.w	#$B,d1
		move.w	#$10,d2
		move.w	#$11,d3
		move.w	obX(a0),d4
		bsr.w	SolidObject
		btst	#3,obStatus(a0)
		bne.s	loc_C736
		swap	d6
		andi.w	#$C0,d6
		beq.s	loc_C766

loc_C736:
		tst.b	(v_invinc).w
		bne.s	loc_C766
		move.l	a0,-(sp)
		movea.l	a0,a2
		lea	(v_player).w,a0
		cmpi.b	#4,obRoutine(a0)
		bcc.s	loc_C764
		move.l	obY(a0),d3
		move.w	obVelY(a0),d0
		ext.l	d0
		asl.l	#8,d0
		sub.l	d0,d3
		move.l	d3,obY(a0)
		jsr	(HurtSonic).l

loc_C764:
		movea.l	(sp)+,a0

loc_C766:
		out_of_range.w	DeleteObject,spikes_base_x_pos(a0)
		bra.w	DisplaySprite

; =============== S U B	R O U T	I N E =======================================


MoveSpikes:
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		add.w	d0,d0
		move.w	off_C798(pc,d0.w),d1
		jmp	off_C798(pc,d1.w)
; End of function MoveSpikes

; ---------------------------------------------------------------------------
off_C798:	dc.w locret_C79E-off_C798
		dc.w loc_C7A0-off_C798
		dc.w loc_C7B4-off_C798
; ---------------------------------------------------------------------------

locret_C79E:
		rts
; ---------------------------------------------------------------------------

loc_C7A0:
		bsr.w	sub_C7C8
		moveq	#0,d0
		move.b	objoff_34(a0),d0
		add.w	spikes_base_y_pos(a0),d0
		move.w	d0,obY(a0)
		rts
; ---------------------------------------------------------------------------

loc_C7B4:
		bsr.w	sub_C7C8
		moveq	#0,d0
		move.b	objoff_34(a0),d0
		add.w	spikes_base_x_pos(a0),d0
		move.w	d0,obX(a0)
		rts

; =============== S U B	R O U T	I N E =======================================


sub_C7C8:
		tst.w	objoff_38(a0)
		beq.s	loc_C7E6
		subq.w	#1,objoff_38(a0)
		bne.s	locret_C828
		tst.b	obRender(a0)
		bpl.s	locret_C828
		move.w	#sfx_SpikesMove,d0
		jmp	(PlaySound_Special).l
; ---------------------------------------------------------------------------

loc_C7E6:
		tst.w	objoff_36(a0)
		beq.s	loc_C808
		subi.w	#$800,objoff_34(a0)
		bcc.s	locret_C828
		clr.w	objoff_34(a0)
		clr.w	objoff_36(a0)
		move.w	#60,objoff_38(a0)
		rts
; ---------------------------------------------------------------------------

loc_C808:
		addi.w	#$800,objoff_34(a0)
		cmpi.w	#$2000,objoff_34(a0)
		bcs.s	locret_C828
		move.w	#$2000,objoff_34(a0)
		move.w	#1,objoff_36(a0)
		move.w	#60,objoff_38(a0)

locret_C828:
		rts
; End of function sub_C7C8