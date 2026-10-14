; ---------------------------------------------------------------------------
; Object 36 - S3&K spikes, adapted to Mystic Island's SSTs and player routines.
; High subtype: 0-3 = S3 floor rows, 4-7 = S3 side columns.
; 8-D = S1's six arrangements (three floor, three side, single floor,
; wide three floor, wide six floor, single side), using the same art.
; Low subtype: 0 = stationary, 1 = vertical, 2 = horizontal, 3 = pushable.
; Status flips select ceiling spikes or the direction of side spikes.
; ---------------------------------------------------------------------------
spikes_base_x_pos	= objoff_34
spikes_base_y_pos	= objoff_36
spikes_retract_offset	= objoff_38	; unsigned 8.8 displacement
spikes_retract_state	= objoff_3A	; 0 = extend, 1 = retract
spikes_retract_timer	= objoff_3C
spikes_push_timer	= objoff_3E
spikes_push_distance	= objoff_40
spikes_sonic_status	= objoff_42	; preceding frame's player pushing flags
spikes_tails_status	= objoff_43
spikes_travel		= $20
spikes_move_step		= $800
spikes_move_delay	= 60
spikes_push_delay	= $10

Obj36:
		tst.b	obRoutine(a0)
		beq.w	Spike_Init
		bsr.w	MoveSpikes
		; All three S3&K handlers use these same solid-object dimensions.
		moveq	#0,d1
		move.b	obActWid(a0),d1
		addi.w	#$B,d1
		moveq	#0,d2
		move.b	obHeight(a0),d2
		move.w	d2,d3
		addq.w	#1,d3
		move.w	obX(a0),d4
		bsr.w	SolidObject
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj36_Index-2(pc,d0.w),d1
		jmp	Obj36_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj36_Index:	dc.w Spike_Floor-Obj36_Index
		dc.w Spike_Side-Obj36_Index
		dc.w Spike_Ceiling-Obj36_Index

; Collision half-width and half-height; also the exact frame's display bounds.
Obj36_Conf:	dc.b $10,$10, $20,$10, $30,$10, Map_Obj36_width,$10
		dc.b $10,$10, $10,$20, $10,$30, $10,Map_Obj36_height
		dc.b $14,$10	; $8: three floor spikes, 16 pixels apart
		dc.b $10,$14	; $9: three side spikes, 16 pixels apart
		dc.b $04,$10	; $A: one floor spike
		dc.b $1C,$10	; $B: three floor spikes, 24 pixels apart
		dc.b $40,$10	; $C: six floor spikes, 24 pixels apart
		dc.b $10,$04	; $D: one side spike
; Routine 2 = floor, 4 = side. Y flip selects routine 6 (ceiling).
Obj36_Routines:	dc.b 2,2,2,2, 4,4,4,4, 2,4,2,2,2,4
; ---------------------------------------------------------------------------
Spike_Init:
		ori.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.l	#Map_Obj36,obMap(a0)
		move.b	obSubtype(a0),d0
		andi.w	#$F0,d0
		lsr.w	#3,d0
		lea	Obj36_Conf(pc,d0.w),a1
		move.b	(a1)+,obActWid(a0)
		move.b	(a1),obHeight(a0)
		move.b	(a1),height_pixels(a0)
		lsr.w	#1,d0
		move.b	d0,obFrame(a0)
		move.b	Obj36_Routines(pc,d0.w),obRoutine(a0)
		move.w	#make_art_tile(ArtTile_Spikes,0,0),obGfx(a0)
		btst	#render_flags.y_flip,obStatus(a0)
		beq.s	.position
		move.b	#6,obRoutine(a0)
.position:
		move.w	#spikes_travel,spikes_push_distance(a0)
		move.w	obX(a0),spikes_base_x_pos(a0)
		move.w	obY(a0),spikes_base_y_pos(a0)
		move.b	obSubtype(a0),d0
		andi.b	#3,d0
		add.b	d0,d0
		move.b	d0,obSubtype(a0)		; movement table byte offset
		rts
; ---------------------------------------------------------------------------
Spike_Floor:
		move.b	obStatus(a0),d6
		andi.b	#(1<<status.player.on_object)|(1<<status.sidekick.on_object),d6
		beq.s	Spike_Display
		btst	#status.player.on_object,d6
		beq.s	.partner
		lea	(v_player).w,a1
		bsr.w	Spike_HurtCharacter
.partner:
		btst	#status.sidekick.on_object,d6
		beq.s	Spike_Display
		lea	(v_player2).w,a1
		bsr.w	Spike_HurtCharacter
Spike_Display:
		move.w	spikes_base_x_pos(a0),d0
		bra.w	MarkObjGone3		; clear the respawn flag when the base goes out of range
; ---------------------------------------------------------------------------
Spike_Side:
		swap	d6			; SolidObject: side hits in bits 0/1
		andi.w	#3,d6
		beq.s	Spike_Display
		btst	#0,d6
		beq.s	.partner
		lea	(v_player).w,a1
		bsr.s	Spike_HurtCharacter
		bclr	#status.player.pushing,obStatus(a0)
.partner:
		btst	#1,d6
		beq.s	Spike_Display
		lea	(v_player2).w,a1
		bsr.s	Spike_HurtCharacter
		bclr	#status.player.pushing+1,obStatus(a0)
		bra.s	Spike_Display
; ---------------------------------------------------------------------------
Spike_Ceiling:
		swap	d6			; SolidObject: underside hits in bits 2/3
		andi.w	#$C,d6
		beq.s	Spike_Display
		btst	#2,d6
		beq.s	.partner
		lea	(v_player).w,a1
		bsr.s	Spike_HurtCharacter
.partner:
		btst	#3,d6
		beq.s	Spike_Display
		lea	(v_player2).w,a1
		bsr.s	Spike_HurtCharacter
		bra.s	Spike_Display
; ---------------------------------------------------------------------------
Spike_HurtCharacter:
		btst	#obStatusSecondary_isInvincible,obStatusSecondary(a1)
		bne.s	.return
		tst.w	flashtime(a1)		; Mystic Island uses a word, unlike S3&K's byte
		bne.s	.return
		cmpi.b	#4,obRoutine(a1)
		bhs.s	.return
		move.l	obY(a1),d3
		move.w	obVelY(a1),d0
		ext.l	d0
		asl.l	#8,d0
		sub.l	d0,d3
		move.l	d3,obY(a1)
		movem.l	d6/a0,-(sp)		; preserve the other player's hit and the spikes
		movea.l	a0,a2
		movea.l	a1,a0
		jsr	(HurtSonic).l
		movem.l	(sp)+,d6/a0
.return:	rts
; ---------------------------------------------------------------------------
MoveSpikes:
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		move.w	.index(pc,d0.w),d1
		jmp	.index(pc,d1.w)
.index:	dc.w .return-.index, .vertical-.index, .horizontal-.index
		dc.w Spike_Pushable-.index
.return:	rts
.vertical:
		bsr.s	Spike_Retract
		moveq	#0,d0
		move.b	spikes_retract_offset(a0),d0
		add.w	spikes_base_y_pos(a0),d0
		move.w	d0,obY(a0)
		rts
.horizontal:
		bsr.s	Spike_Retract
		moveq	#0,d0
		move.b	spikes_retract_offset(a0),d0
		add.w	spikes_base_x_pos(a0),d0
		move.w	d0,obX(a0)
		rts
; ---------------------------------------------------------------------------
Spike_Retract:
		tst.w	spikes_retract_timer(a0)
		beq.s	.move
		subq.w	#1,spikes_retract_timer(a0)
		bne.s	.return
		tst.b	obRender(a0)
		bpl.s	.return
		move.w	#sfx_SpikesMove,d0
		jmp	(PlaySound_Special).l
.move:
		tst.w	spikes_retract_state(a0)
		beq.s	.extend
		subi.w	#spikes_move_step,spikes_retract_offset(a0)
		bcc.s	.return
		clr.w	spikes_retract_offset(a0)
		clr.w	spikes_retract_state(a0)
		move.w	#spikes_move_delay,spikes_retract_timer(a0)
		rts
.extend:
		addi.w	#spikes_move_step,spikes_retract_offset(a0)
		cmpi.w	#spikes_travel<<8,spikes_retract_offset(a0)
		blo.s	.return
		move.w	#spikes_travel<<8,spikes_retract_offset(a0)
		move.w	#1,spikes_retract_state(a0)
		move.w	#spikes_move_delay,spikes_retract_timer(a0)
.return:	rts
; ---------------------------------------------------------------------------
Spike_Pushable:
		move.b	obStatus(a0),d3
		andi.b	#(1<<status.player.pushing)|(1<<(status.player.pushing+1)),d3
		beq.s	.remember
		move.w	obX(a0),d2
		lea	(v_player).w,a1
		move.b	spikes_sonic_status(a0),d0
		moveq	#status.player.pushing,d6
		bsr.s	.push
		lea	(v_player2).w,a1
		move.b	spikes_tails_status(a0),d0
		moveq	#status.player.pushing+1,d6
		bsr.s	.push
.remember:
		move.b	(v_player+obStatus).w,spikes_sonic_status(a0)
		move.b	(v_player2+obStatus).w,spikes_tails_status(a0)
		rts
.push:
		btst	d6,d3
		beq.s	.return
		cmp.w	obX(a1),d2
		blo.s	.return
		btst	#status.player.pushing,d0
		beq.s	.return
		subq.w	#1,spikes_push_timer(a0)
		bpl.s	.return
		move.w	#spikes_push_delay,spikes_push_timer(a0)
		tst.w	spikes_push_distance(a0)
		beq.s	.return
		subq.w	#1,spikes_push_distance(a0)
		addq.w	#1,obX(a0)
		addq.w	#1,obX(a1)
.return:	rts
