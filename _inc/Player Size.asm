; Miniature players keep the original animation IDs and DPLC destinations.
; Changing size updates both the shape and the art in the same object pass.

Player_SizeProfile:
		dc.w sonic_height<<8|sonic_width,Sonic_LastLoadedDPLC&$FFFF
		dc.l Map_Sonic,LoadSonicDynPLC
		dc.w tails_height<<8|tails_width,Tails_LastLoadedDPLC&$FFFF
		dc.l Map_Tails,LoadTailsDynPLC
		dc.w Player_MiniHeight<<8|Player_MiniWidth,Sonic_LastLoadedDPLC&$FFFF
		dc.l Map_MiniSonic,LoadSonicDynPLC
		dc.w Player_MiniHeight<<8|Player_MiniWidth,Tails_LastLoadedDPLC&$FFFF
		dc.l Map_MiniTails,LoadTailsDynPLC

; d0.b = 0 to grow, nonzero to shrink. Carry means defer this transition.
; Keep the feet anchored and the prior shape if the new art cannot queue.
Player_ChangeSize:
		lea	Player_SizeProfile(pc),a4
		tst.b	d0
		beq.s	.character
		lea	24(a4),a4
.character:
		cmpi.b	#CharacterID_Tails,character_id(a0)
		bne.s	.check
		lea	12(a4),a4
.check:
		move.w	(a4),d0
		cmp.w	default_y_radius(a0),d0
		beq.s	.done
		blo.s	.load
		jsr	(Player_ResizeRoom).l
		bmi.s	.defer
.load:
		movea.w	2(a4),a3
		move.b	(a3),d1
		move.w	d1,-(sp)
		move.l	a3,-(sp)
		move.l	obMap(a0),-(sp)
		move.w	(a4),-(sp)
		move.l	4(a4),obMap(a0)
		st	(a3)
		movea.l	8(a4),a2
		jsr	(a2)
		bcs.s	.restore
		move.w	(sp)+,d0
		move.w	d0,default_y_radius(a0)
		lea	10(sp),sp
		jsr	(Player_Resize).l
.done:
		andi	#$FE,ccr
		rts
.restore:
		addq.l	#2,sp
		move.l	(sp)+,obMap(a0)
		movea.l	(sp)+,a3
		move.w	(sp)+,d1
		move.b	d1,(a3)
.defer:
		ori	#1,ccr
		rts

; Preserve the two forms independently through checkpoints and era changes.
; The stage initializes at the saved coordinates, so no resize offset applies.
Player_SizeFlags:
		moveq	#0,d1
		cmpi.b	#Player_MiniHeight,(v_player2+default_y_radius).w
		bne.s	.primary
		moveq	#2,d1
.primary:
		cmpi.b	#Player_MiniHeight,(v_player+default_y_radius).w
		bne.s	.return
		addq.b	#1,d1
.return:
		rts

Player_RestoreSize:
		tst.b	(TimeWarp_Target).l
		beq.s	.checkpoint
		move.b	(TimeWarp_SizeFlags).l,d0
		bra.s	.actor
.checkpoint:
		tst.b	(v_lastlamp).w
		beq.s	.return
		move.b	(v_lamp_size_flags).w,d0
.actor:
		cmpa.w	#v_player,a0
		beq.s	.size
		lsr.b	#1,d0
.size:
		btst	#0,d0
		beq.s	.return
		move.w	#Player_MiniHeight<<8|Player_MiniWidth,default_y_radius(a0)
		move.w	default_y_radius(a0),obHeight(a0)
		move.l	#Map_MiniSonic,obMap(a0)
		cmpi.b	#CharacterID_Tails,character_id(a0)
		bne.s	.return
		move.l	#Map_MiniTails,obMap(a0)
.return:
		rts
