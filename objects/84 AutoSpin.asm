; ---------------------------------------------------------------------------
; Object $84 - auto-roll tunnel entrance.
; Adapted from S3&K AutoSpin's per-player line crossing and roll-only mode.
; ---------------------------------------------------------------------------

autospin_sides		equ objoff_2E	; two signed side bytes, initialized on first sample
autospin_half_span	equ objoff_30	; word

AutoSpin:
		move.l	#AutoSpin_Run,code(a0)
		move.l	#Map_Obj03,obMap(a0)
		move.b	#Map_Obj03_height,height_pixels(a0)
		move.b	#Map_Obj03_width,width_pixels(a0)
		move.w	#make_art_tile(ArtTile_Ring,1,0),obGfx(a0)
		move.w	#$280,obPriority(a0)
		move.b	#4,obRender(a0)
		move.w	#-1,autospin_sides(a0)
		move.w	obSubtype(a0),d0
		andi.w	#7,d0
		move.b	d0,obFrame(a0)
		andi.w	#3,d0
		moveq	#$20,d1
		lsl.w	d0,d1
		move.w	d1,autospin_half_span(a0)

AutoSpin_Run:
		lea	autospin_sides(a0),a2
		lea	(v_player).w,a1
		bsr.s	AutoSpin_Actor
		lea	autospin_sides+1(a0),a2
		lea	(v_player2).w,a1
		bsr.s	AutoSpin_Actor
		tst.b	(Debug_mode_flag).w
		bne.w	MarkObjGone
		bra.w	MarkObjGone2

AutoSpin_Actor:
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		move.w	obY(a1),d1
		sub.w	obY(a0),d1
		btst	#2,obFrame(a0)
		beq.s	.side
		exg	d0,d1
.side:
		tst.w	d0
		spl	d0				; right/down of the line (including the line)
		andi.b	#1,d0
		move.b	(a2),d2
		move.b	d0,(a2)
		tst.b	d2
		bmi.s	.return			; initialize without triggering
		cmp.b	d2,d0
		beq.s	.return			; still on the same side
		move.b	obStatus(a0),d2
		eor.b	d2,d0			; X-flip selects left/up as the entrance side
		btst	#0,d0
		beq.s	.return			; exiting through this mouth
		move.w	autospin_half_span(a0),d2
		add.w	d2,d1
		add.w	d2,d2
		cmp.w	d2,d1
		bhs.s	.return
		tst.w	(Debug_placement_mode).w
		bne.s	.return
		tst.b	(f_playerctrl).w
		bmi.s	.return
		bsr.w	Player_CanInteract
		bcc.s	.return
		tst.b	obControl(a1)
		bne.s	.return
		tst.b	tails_flight_flag(a1)
		bne.s	.return
		tst.b	spindash_flag(a1)
		bne.s	.return			; keep charge and scripted roll modes
		btst	#status.player.rolling,obStatus(a1)
		bne.s	.return
		btst	#5,obSubtype+1(a0)
		beq.s	.roll
		btst	#status.player.in_air,obStatus(a1)
		bne.s	.return
.roll:
		move.l	a0,-(sp)
		movea.l	a1,a0
		bsr.w	Player_EnterRoll
		move.w	#SndID_Roll,d0
		jsr	(PlaySound_Special).l
		movea.l	(sp)+,a0
.return:
		rts
